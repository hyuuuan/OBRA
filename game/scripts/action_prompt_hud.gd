class_name ActionPromptHUD
extends Control
## Four verbs, four separate pieces of interface.
##
## R is a standing invitation at the bottom left. Q joins it only while the player is a
## drawing. E and F exist only while their actions exist, and follow the current player in
## screen space with the same delayed ease Lolo uses in world space. Screen space is
## intentional: Ang Bale and the straw room change the camera zoom, but a readable key cap
## must not double or triple in size when the player walks indoors.

signal interact_requested
signal use_requested
signal revert_requested

const BOTTOM_MARGIN := Vector2(24.0, 18.0)
const BOTTOM_GAP := 12.0
const FOLLOW_OFFSET := Vector2(0.0, -118.0)
const FOLLOW_SPEED := 6.2
const TELEPORT_DISTANCE := 620.0
const EDGE_GUARD := 18.0
const REVEAL_SPEED := 7.5

var _draw: Button
var _revert: Button
var _pickup: Button
var _use: Button
var _floating_row: HBoxContainer
var _target: Node2D
var _follow_position := Vector2.ZERO
var _follow_ready := false
var _time := 0.0
## Button -> {wanted, amount, pulse, accent}. Keeping animation here means visibility can
## change every physics frame without spawning and killing a tween every frame.
var _states: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false

	_revert = _make_prompt(&"ChangeBackPrompt", "Q", "CHANGE BACK", UISkin.RED_FILL, 198.0)
	add_child(_revert)
	_register(_revert, false, 0.018, UISkin.RED_LIT)
	_revert.pressed.connect(func() -> void: revert_requested.emit())

	_floating_row = HBoxContainer.new()
	_floating_row.name = "FloatingActions"
	_floating_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floating_row.add_theme_constant_override(&"separation", 10)
	add_child(_floating_row)

	_pickup = _make_prompt(&"PickupPrompt", "E", "PICK UP", UISkin.PICKUP, 158.0)
	_floating_row.add_child(_pickup)
	_register(_pickup, false, 0.028, UISkin.PICKUP_LIT)
	_pickup.pressed.connect(func() -> void: interact_requested.emit())

	_use = _make_prompt(&"UsePrompt", "F", "USE", UISkin.USE, 116.0)
	_floating_row.add_child(_use)
	_register(_use, false, 0.032, UISkin.USE_LIT)
	_use.pressed.connect(func() -> void: use_requested.emit())


## The authored DrawButton stays at CanvasLayer/DrawButton because mouse and regression
## tests address that stable path. This controller restyles and animates it in place.
func bind_draw_button(button: Button) -> void:
	_draw = button
	_style_prompt(_draw, "R", "DRAW", UISkin.GOLD, 138.0)
	_register(_draw, true, 0.022, UISkin.GOLD_PALE)
	_draw.visible = true


func follow(target: Node2D) -> void:
	if target == _target:
		return
	_target = target
	# A body swap can move the player a whole room in one frame. Like Lolo, the prompt
	# appears with them rather than spending several seconds flying through scenery.
	_follow_ready = false


func set_pickup_available(available: bool, object_name: String = "") -> void:
	_set_wanted(_pickup, available)
	_pickup.tooltip_text = "Pick up %s" % object_name if not object_name.is_empty() else "Pick up"


func set_use_available(available: bool, object_name: String = "") -> void:
	_set_wanted(_use, available)
	_use.tooltip_text = "Use %s" % object_name if not object_name.is_empty() else "Use held object"


func set_revert_available(available: bool) -> void:
	_set_wanted(_revert, available)


func pickup_is_available() -> bool:
	return _wanted(_pickup)


func use_is_available() -> bool:
	return _wanted(_use)


func revert_is_available() -> bool:
	return _wanted(_revert)


func _process(delta: float) -> void:
	_time += delta
	_update_animations(delta)
	_place_bottom_actions()
	_follow_player(delta)


func _make_prompt(prompt_name: StringName, key: String, verb: String,
		accent: Color, width: float) -> Button:
	var button := Button.new()
	button.name = prompt_name
	_style_prompt(button, key, verb, accent, width)
	return button


func _style_prompt(button: Button, key: String, verb: String,
		accent: Color, width: float) -> void:
	for child in button.get_children():
		if child.name == &"PromptKey":
			child.queue_free()
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(width, 42.0)
	button.text = verb
	button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	button.add_theme_color_override(&"font_color", accent)
	button.add_theme_color_override(&"font_hover_color", accent.lightened(0.18))
	button.add_theme_color_override(&"font_pressed_color", UISkin.CREAM_TEXT)
	button.add_theme_color_override(&"font_focus_color", accent)
	button.add_theme_stylebox_override(&"normal", UISkin.action_prompt(accent, UISkin.State.NORMAL))
	button.add_theme_stylebox_override(&"hover", UISkin.action_prompt(accent, UISkin.State.HOVER))
	button.add_theme_stylebox_override(&"pressed", UISkin.action_prompt(accent, UISkin.State.PRESSED))
	button.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	button.add_theme_constant_override(&"outline_size", 0)

	var badge := PanelContainer.new()
	badge.name = "PromptKey"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2(8.0, 7.0)
	badge.add_theme_stylebox_override(&"panel", UISkin.action_key(accent))
	var letter := Label.new()
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	letter.text = key
	letter.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	letter.add_theme_color_override(&"font_color", UISkin.INK)
	letter.add_theme_constant_override(&"shadow_offset_x", 0)
	letter.add_theme_constant_override(&"shadow_offset_y", 0)
	badge.add_child(letter)
	button.add_child(badge)


func _register(button: Button, shown: bool, pulse: float, accent: Color) -> void:
	_states[button] = {
		"wanted": shown,
		"amount": 1.0 if shown else 0.0,
		"pulse": pulse,
		"accent": accent,
	}
	button.visible = shown


func _set_wanted(button: Button, wanted: bool) -> void:
	if button == null or not _states.has(button):
		return
	var state: Dictionary = _states[button]
	if bool(state["wanted"]) == wanted:
		return
	state["wanted"] = wanted
	_states[button] = state
	if wanted:
		button.visible = true


func _wanted(button: Button) -> bool:
	return button != null and _states.has(button) and bool((_states[button] as Dictionary)["wanted"])


func _update_animations(delta: float) -> void:
	for value: Variant in _states.keys():
		var button := value as Button
		if button == null or not is_instance_valid(button):
			continue
		var state: Dictionary = _states[button]
		var wanted := bool(state["wanted"])
		var amount := float(state["amount"])
		amount = move_toward(amount, 1.0 if wanted else 0.0, REVEAL_SPEED * delta)
		state["amount"] = amount
		_states[button] = state
		if amount <= 0.0 and not wanted:
			button.visible = false
			continue
		button.visible = true
		button.pivot_offset = button.size * 0.5
		# Cubic ease gives the arrival a small lift without overshooting far enough to make
		# a pixel key look soft. A quieter sine remains after it settles, so R keeps asking
		# to be discovered and the two world prompts feel alive rather than pasted on.
		var reveal := 1.0 - pow(1.0 - amount, 3.0)
		var pulse := (0.5 + 0.5 * sin(_time * TAU * 1.15 + float(button.get_instance_id() % 7))) \
			* float(state["pulse"]) * reveal
		var scale_amount := (0.82 + reveal * 0.18) * (1.0 + pulse)
		button.scale = Vector2.ONE * scale_amount
		button.modulate.a = reveal


func _place_bottom_actions() -> void:
	if _draw == null or not is_instance_valid(_draw):
		return
	var view := get_viewport_rect().size
	_draw.size = _draw.get_combined_minimum_size()
	_draw.position = Vector2(BOTTOM_MARGIN.x, view.y - BOTTOM_MARGIN.y - _draw.size.y)
	_revert.size = _revert.get_combined_minimum_size()
	_revert.position = Vector2(
		_draw.position.x + _draw.size.x + BOTTOM_GAP,
		view.y - BOTTOM_MARGIN.y - _revert.size.y)


func _follow_player(delta: float) -> void:
	if _floating_row == null:
		return
	var anchor: Variant = _target_position()
	if anchor == null:
		_floating_row.visible = false
		_follow_ready = false
		return
	_floating_row.visible = _pickup.visible or _use.visible
	var row_size := _floating_row.get_combined_minimum_size()
	_floating_row.size = row_size
	var desired := get_viewport().get_canvas_transform() * (anchor as Vector2)
	desired += FOLLOW_OFFSET - Vector2(row_size.x * 0.5, row_size.y)
	var view := get_viewport_rect().size
	desired.x = clampf(desired.x, EDGE_GUARD, maxf(EDGE_GUARD, view.x - row_size.x - EDGE_GUARD))
	desired.y = clampf(desired.y, EDGE_GUARD, maxf(EDGE_GUARD, view.y - row_size.y - EDGE_GUARD))
	if not _follow_ready or _follow_position.distance_to(desired) > TELEPORT_DISTANCE:
		_follow_position = desired
		_follow_ready = true
	else:
		var weight := 1.0 - exp(-FOLLOW_SPEED * delta)
		_follow_position = _follow_position.lerp(desired, weight)
	var context_amount := maxf(_amount(_pickup), _amount(_use))
	var bob := sin(_time * TAU * 0.72) * 2.0 * context_amount
	# Whole-pixel placement keeps Geist Pixel sharp even though the underlying ease is
	# continuous. It reads as smooth motion but never lands the type between pixels.
	_floating_row.position = (_follow_position + Vector2(0.0, bob)).round()


func _amount(button: Button) -> float:
	if button == null or not _states.has(button):
		return 0.0
	return float((_states[button] as Dictionary)["amount"])


## Nullable Vector2 is not a GDScript type, so null is returned as Variant when there is
## no current body to follow.
func _target_position() -> Variant:
	if _target == null or not is_instance_valid(_target):
		return null
	if _target.has_method("get_physics_anchor"):
		var anchor := _target.call("get_physics_anchor") as Node2D
		if anchor != null:
			return anchor.global_position
	return _target.global_position
