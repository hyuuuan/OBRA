class_name TutorialCallout
extends Control
## A lesson that POINTS AT THE THING IT IS ABOUT.
##
## The tutorial already had a voice and no finger. Every lesson went to the `HintBar` at the
## top of the screen -- correct for the ones about the world ("that word at the top is what
## the place is asking for") and wrong for the ones about a control, because "R opens it"
## printed in the sky asks the player to find R and then find the thing R opens. A tutorial
## that names a button should be standing next to the button.
##
## SO THIS IS THE HINT BAR'S POINTING HALF, not its replacement. A lesson with an `anchor`
## in `tutorial.json` comes here; everything else still goes to the bar, and a lesson whose
## anchor is missing or off screen FALLS BACK to the bar rather than being swallowed --
## see `TutorialDirector._teach`. An unteachable lesson is worse than an unpointed one.
##
## ⚠ IT ARRIVES IN THE CANVAS'S IDIOM. `UIFeedback` and the drawing panel already share one
## motion -- a scale that overshoots through TRANS_BACK and settles -- and a third kind of
## entrance would make the interface read as assembled from parts. It pops in from 0.86 on
## the same curve, off the beak, so it looks like it grew out of the thing it points at.

## Where the bubble sits relative to its target. AUTO flips to whichever side has room,
## which is the only setting a lesson should normally name: the bag is at the bottom of the
## screen and the level badge is at the top, and a fixed side is wrong for one of them.
enum Side { AUTO, ABOVE, BELOW, LEFT, RIGHT }

## How far the bubble stands off the thing it points at, before the beak.
const GAP := 14.0
## The beak. Wide enough to read as a direction at a glance, short enough not to become an
## arrow -- this points, it does not instruct.
const BEAK := 13.0
## How long a nudge stays up when nothing dismisses it. Long enough to read twice.
const DWELL := 7.0
const FADE := 0.22
## Never nearer the screen edge than this, so a bubble at the bag does not lose its corner.
const MARGIN := 12.0

signal dismissed()

var _panel: PanelContainer
var _row: HBoxContainer
var _label: Label
var _beak_from := Vector2.ZERO
var _beak_to := Vector2.ZERO
var _side := Side.ABOVE
var _life := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Over the HUD it points at, under a conversation. A callout on top of the dialogue box
	# would be the tutorial talking across Lolo, which is the one thing it must never do.
	z_index = 40
	_build()
	modulate.a = 0.0


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override(&"panel", _bubble_style())
	add_child(_panel)

	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override(&"separation", 9)
	_panel.add_child(_row)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(268.0, 0.0)
	_label.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	_label.add_theme_color_override(&"font_color", UISkin.CREAM_TEXT)
	_label.add_theme_color_override(&"font_outline_color", UISkin.INK)
	_label.add_theme_constant_override(&"outline_size", 4)
	_row.add_child(_label)


## The dialogue box's own panel, so a callout reads as the game speaking rather than as a
## tooltip the engine put there.
func _bubble_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.06, 0.05, 0.95)
	style.border_color = UISkin.GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


## Point at a rect in SCREEN space, and say something.
##
## ⚠ A RECT, NOT A NODE. The caller resolves the target and hands over its
## `get_global_rect()`, so this class never holds a reference to a HUD element that can be
## freed under it -- and a test can aim it at a rectangle with no HUD at all.
func point_at(target: Rect2, text: String, caps: String = "",
		side: int = Side.AUTO) -> void:
	_label.text = text
	for child in _row.get_children():
		if child != _label:
			_row.remove_child(child)
			child.queue_free()
	if not caps.is_empty():
		_row.add_child(_key_cap(caps))
	# The panel has to be measured before it can be placed, and a Control measures nothing
	# until it has been laid out -- the trap HUD_SKIN.md keeps a note about.
	await get_tree().process_frame
	_place(target, side)
	_life = DWELL
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, FADE)
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.86, 0.86)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	set_process(true)


func _key_cap(caps: String) -> Control:
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override(&"panel", UISkin.action_key(UISkin.GOLD))
	var letter := Label.new()
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	letter.text = caps
	letter.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	letter.add_theme_color_override(&"font_color", UISkin.INK)
	badge.add_child(letter)
	return badge


## Put the bubble beside the target and aim the beak at it.
##
## ⚠ AUTO PICKS THE SIDE WITH ROOM, and then the position is CLAMPED to the screen. Both are
## needed: the DRAW prompt sits at the very bottom-left, so a bubble authored "below" it
## hangs off the screen, and one merely flipped above it still loses its left corner unless
## it is pushed back in. The beak is aimed after the clamp, at the target's own edge, so
## sliding the bubble along the screen never leaves the beak pointing at nothing.
func _place(target: Rect2, side: int) -> void:
	var box := _panel.size
	var screen := get_viewport_rect().size
	var chosen := side
	if chosen == Side.AUTO:
		if target.position.y - (box.y + GAP + BEAK) >= MARGIN:
			chosen = Side.ABOVE
		elif target.end.y + box.y + GAP + BEAK <= screen.y - MARGIN:
			chosen = Side.BELOW
		elif target.position.x - (box.x + GAP + BEAK) >= MARGIN:
			chosen = Side.LEFT
		else:
			chosen = Side.RIGHT
	_side = chosen

	var at := Vector2.ZERO
	match chosen:
		Side.ABOVE:
			at = Vector2(target.get_center().x - box.x * 0.5,
				target.position.y - GAP - BEAK - box.y)
		Side.BELOW:
			at = Vector2(target.get_center().x - box.x * 0.5, target.end.y + GAP + BEAK)
		Side.LEFT:
			at = Vector2(target.position.x - GAP - BEAK - box.x,
				target.get_center().y - box.y * 0.5)
		_:
			at = Vector2(target.end.x + GAP + BEAK, target.get_center().y - box.y * 0.5)
	at.x = clampf(at.x, MARGIN, maxf(MARGIN, screen.x - box.x - MARGIN))
	at.y = clampf(at.y, MARGIN, maxf(MARGIN, screen.y - box.y - MARGIN))
	_panel.position = at

	var edge := Vector2.ZERO
	match chosen:
		Side.ABOVE:
			edge = Vector2(clampf(target.get_center().x, at.x + 16.0, at.x + box.x - 16.0),
				at.y + box.y)
		Side.BELOW:
			edge = Vector2(clampf(target.get_center().x, at.x + 16.0, at.x + box.x - 16.0), at.y)
		Side.LEFT:
			edge = Vector2(at.x + box.x,
				clampf(target.get_center().y, at.y + 16.0, at.y + box.y - 16.0))
		_:
			edge = Vector2(at.x, clampf(target.get_center().y, at.y + 16.0, at.y + box.y - 16.0))
	_beak_from = edge
	_beak_to = target.get_center()
	queue_redraw()


func _draw() -> void:
	if _beak_from.is_equal_approx(_beak_to):
		return
	# A triangle from the bubble's edge toward the target. Filled in the bubble's own body
	# colour with the same gold edge, so it reads as part of the panel rather than as a
	# separate mark that happens to be nearby.
	var toward := (_beak_to - _beak_from).normalized()
	var across := Vector2(-toward.y, toward.x) * (BEAK * 0.62)
	var tip := _beak_from + toward * BEAK
	var points := PackedVector2Array([_beak_from + across, _beak_from - across, tip])
	draw_colored_polygon(points, Color(0.055, 0.06, 0.05, 0.95))
	draw_line(_beak_from + across, tip, UISkin.GOLD, 2.0, true)
	draw_line(_beak_from - across, tip, UISkin.GOLD, 2.0, true)


func _process(delta: float) -> void:
	if _life <= 0.0:
		return
	_life -= delta
	if _life <= 0.0:
		dismiss()


## Taken down early, which is what should happen the moment the player does the thing. A
## callout still up after its lesson is learned is the tutorial talking over the game.
func dismiss() -> void:
	if _life < 0.0:
		return
	_life = -1.0
	set_process(false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE)
	tween.tween_callback(func() -> void:
		dismissed.emit()
		queue_free())
