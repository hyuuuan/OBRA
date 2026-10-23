class_name ModalOverlay
extends CanvasLayer
## Shared behaviour for anything that covers the game and takes over input: the pause
## menu, settings, controls, the level-complete screen.
##
## Behaviour only. Each overlay's scene owns its own dim and panel, because they do
## not all want the same look and a base class that reaches into children to build
## them is a base class that fights every scene that already has them.
##
## PAUSE IS DERIVED, NEVER TOGGLED. An overlay that set `paused = false` on close
## would unpause the game when Settings closes back onto the pause menu underneath.
## Instead every overlay registers in the `modal_overlays` group and UIRouter
## recomputes the tree's pause state from whoever is open. Nothing here writes
## get_tree().paused directly, and nothing else should either.
##
## IT COMES AND GOES, BUT IS OPEN OR SHUT AT ONCE (Motion, 2026-10-23). Opening, its scrim fades
## in and its panel pops (the canvas's own entrance); closing, the panel and scrim go before it
## hides. `is_open()` answers at once either way -- pause, the cancel chain and every caller see
## the decision, not the animation -- so a close is never half a close. An overlay that animates
## itself says so (`_animates_itself`) and is left alone.
##
## CanvasLayer budget, so layers stop being picked ad hoc:
##   5 HUD · 10 DrawPanel · 50 Pause · 60 Settings/Controls · 65 OutOfInk
##   70 LevelComplete · 80 Confirm · 1000 scene transition (LevelManager)

const GROUP := &"modal_overlays"

signal opened
signal closed

## Whether this overlay freezes the game while it is up. A purely informational
## overlay can leave the world running.
@export var pauses_game: bool = true

## Whether the cancel key closes it. The level-complete screen sets this false: it is
## a decision point, and dismissing it would strand the player with no way back.
@export var closes_on_cancel: bool = true

## Control to focus when this opens, so the keyboard lands somewhere useful.
@export var default_focus_path: NodePath


## Open or shut as decided, whatever the animation is still showing.
var _open := false


func _ready() -> void:
	# Must keep processing while the tree is paused, or the overlay that DID the
	# pausing cannot receive the input that closes it again.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	visible = false


func is_open() -> bool:
	return _open


func open() -> void:
	if _open:
		return
	_open = true
	visible = true
	_animate_in()
	_grab_default_focus()
	UIRouter.refresh_pause(get_tree())
	_on_opened()
	opened.emit()
	var director := get_node_or_null(^"/root/AudioDirector")
	if director != null:
		director.play_sfx(&"ui_open")


func close() -> void:
	if not _open:
		return
	_open = false
	_animate_out()
	# Recomputed rather than set false: another overlay may still be up underneath.
	UIRouter.refresh_pause(get_tree())
	_on_closed()
	closed.emit()
	var director := get_node_or_null(^"/root/AudioDirector")
	if director != null:
		director.play_sfx(&"ui_close")


## True when this overlay consumed the cancel key. UIRouter walks an authored chain
## and stops at the first overlay that says yes, so an overlay that is not up simply
## answers no and the key falls through to whatever is behind it.
func handle_cancel() -> bool:
	if not is_open():
		return false
	if closes_on_cancel:
		close()
	# Consumed either way: a modal that is up must not let the key reach past it.
	return true


## True for an overlay that plays its own entrance and exit (the inventory, the found-thing card):
## the base then shows and hides it at once and animates nothing.
func _animates_itself() -> bool:
	return false


func _animate_in() -> void:
	if _animates_itself():
		return
	var scrim := _motion_scrim()
	var panel := _motion_panel()
	if scrim != null:
		Motion.fade_in(scrim, 0.34)
	if panel != null:
		Motion.pop_in(panel, 0.03)
	elif scrim == null and _motion_root() != null:
		Motion.fade_in(_motion_root())


func _animate_out() -> void:
	if _animates_itself():
		visible = false
		return
	var scrim := _motion_scrim()
	var panel := _motion_panel()
	var last: CanvasItem = panel if panel != null else (scrim if scrim != null else _motion_root())
	if last == null:
		visible = false
		return
	for item: CanvasItem in [scrim, panel]:
		if item != null and item != last:
			Motion.leave(item)
	Motion.leave(last, func() -> void:
		if not _open:
			visible = false)


## The overlay's own pieces, as its scene has them: the first Control under it, the full-screen
## ColorRect that dims what is behind (its scrim), and the first panel (what pops).
func _motion_root() -> Control:
	for child in get_children():
		if child is Control:
			return child
	return null


func _motion_scrim() -> ColorRect:
	for node in find_children("*", "ColorRect", true, false):
		var rect := node as ColorRect
		if rect.anchor_right >= 1.0 and rect.anchor_bottom >= 1.0 and rect.anchor_left <= 0.0 and rect.anchor_top <= 0.0:
			return rect
	return null


func _motion_panel() -> Control:
	for node in find_children("*", "", true, false):
		if node is PanelContainer or node is Panel:
			return node
	return null


## Overridable hooks, so subclasses do not have to remember to call super().
func _on_opened() -> void:
	pass


func _on_closed() -> void:
	pass


func _grab_default_focus() -> void:
	if default_focus_path.is_empty():
		return
	var target := get_node_or_null(default_focus_path) as Control
	if target != null:
		target.grab_focus()
