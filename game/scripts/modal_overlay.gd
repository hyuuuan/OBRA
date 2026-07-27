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


func _ready() -> void:
	# Must keep processing while the tree is paused, or the overlay that DID the
	# pausing cannot receive the input that closes it again.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	visible = false


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	visible = true
	_grab_default_focus()
	UIRouter.refresh_pause(get_tree())
	_on_opened()
	opened.emit()
	var director := get_node_or_null(^"/root/AudioDirector")
	if director != null:
		director.play_sfx(&"ui_open")


func close() -> void:
	if not visible:
		return
	visible = false
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
