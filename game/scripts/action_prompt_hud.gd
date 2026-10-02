class_name ActionPromptHUD
extends Control
## Five verbs, five separate pieces of interface.
##
## R is a standing invitation at the bottom left. Q joins it only while the player is a
## drawing. E, F and the climb exist only while their actions exist, and follow the current
## player in screen space with the same delayed ease Lolo uses in world space. Screen space
## is intentional: Ang Bale and the straw room change the camera zoom, but a readable key cap
## must not double or triple in size when the player walks indoors.
##
## ⚠ THE CLIMB IS AN INDICATOR, NOT A BUTTON. The other four each emit a signal a mouse can
## fire; you cannot click "hold up". It is built the same way so it sits in the same row and
## reads as the same kind of thing, and then it is made unclickable, because a prompt that
## depresses under the cursor and does nothing is worse than no prompt at all.

const ControlsKeys = preload("res://scripts/controls_overlay.gd")

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
## The row's top, this far below the player's feet, when over their head would put it behind
## the HUD along the top.
const UNDER_THE_FEET := 14.0
## How clear of that HUD over the head has to be before the row goes back up. Without it the
## row turns over at the line itself, and a hop on the line turns it every frame.
const BACK_OVER_CLEARANCE := 24.0
## So Lolo's hint bar can find the row and stand clear of it. See `keys_below_feet`.
const GROUP := &"key_prompts"
## The room one prompt needs, for deciding over or under while none is showing.
const ROOM := Vector2(160.0, 42.0)
## How often over-or-under is decided. It walks the HUD, and the apo does not cross the line
## between them in a tenth of a second.
const JUDGE_EVERY := 0.1

var _draw: Button
var _revert: Button
var _pickup: Button
var _use: Button
var _climb: Button
var _floating_row: HBoxContainer
var _target: Node2D
var _follow_position := Vector2.ZERO
var _follow_ready := false
var _time := 0.0
## Button -> {wanted, amount, pulse, accent}. Keeping animation here means visibility can
## change every physics frame without spawning and killing a tween every frame.
var _states: Dictionary = {}
## How much of the HUD the level's letterbox has left showing, 0..1. The prompts write their
## own alpha every frame for the reveal, so a fade applied from outside was undone on the next
## frame -- and the Draw key sat solid under the CHECKPOINT caption while everything around it
## had gone.
var _curtain_alpha := 1.0
## Whether the row has gone under the player's feet. See `_follow_player`.
var _under := false
var _judge_in := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	add_to_group(GROUP)

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

	# Named off the live InputMap rather than hardcoded, for the same reason tutorial.json
	# refuses to spell its keys: a rebinding must not leave the HUD naming a key that no
	# longer does anything.
	_climb = _make_prompt(&"ClimbPrompt", ControlsKeys.key_cap_for("move_up"),
		"CLIMB", UISkin.CLIMB, 148.0)
	_climb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_climb.mouse_default_cursor_shape = Control.CURSOR_ARROW
	_floating_row.add_child(_climb)
	_register(_climb, false, 0.030, UISkin.CLIMB_LIT)


## The authored DrawButton stays at CanvasLayer/DrawButton because mouse and regression
## tests address that stable path. This controller restyles and animates it in place.
func set_curtain_alpha(alpha: float) -> void:
	_curtain_alpha = clampf(alpha, 0.0, 1.0)


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
	_judge_in = 0.0


## `verb` is what E will actually do. It is PICK UP almost everywhere, and it was PICK UP over
## a boat in the water too -- where E boards it, and E again gets off. A prompt that names the
## wrong action is worse than none: the one thing a player would not press to get into a boat
## is the key that says it will put the boat away.
func set_pickup_available(available: bool, object_name: String = "",
		verb: String = "PICK UP") -> void:
	_set_wanted(_pickup, available)
	# ⚠ A PROMPT GOING AWAY KEEPS ITS WORDS. Taken down, it was handed the default verb and
	# restyled with it while it faded, so the moment a rower left the shallows -- where E gets
	# off -- the prompt over their head read PICK UP for a frame on its way out.
	if not available:
		return
	var action := verb.capitalize()
	_pickup.tooltip_text = "%s %s" % [action, object_name] if not object_name.is_empty() \
		else action
	if verb != _pickup.text:
		_style_prompt(_pickup, "E", verb, UISkin.PICKUP,
			maxf(158.0, 74.0 + float(verb.length()) * 13.0))


func set_use_available(available: bool, object_name: String = "", verb: String = "USE") -> void:
	_set_wanted(_use, available)
	# The same as the pick-up prompt: going away, it keeps the word it was showing.
	if not available:
		return
	_use.tooltip_text = "Use %s" % object_name if not object_name.is_empty() else "Use held object"
	# Restyled only when the word changes: the key cap is rebuilt by `_style_prompt`, and doing
	# that every frame would churn a node a frame.
	if verb != _use.text:
		_style_prompt(_use, "F", verb, UISkin.USE, maxf(116.0, 74.0 + float(verb.length()) * 13.0))


func set_climb_available(available: bool, object_name: String = "") -> void:
	_set_wanted(_climb, available)
	_climb.tooltip_text = "Climb %s" % object_name if not object_name.is_empty() else "Climb"


func set_revert_available(available: bool) -> void:
	_set_wanted(_revert, available)


func pickup_is_available() -> bool:
	return _wanted(_pickup)


func use_is_available() -> bool:
	return _wanted(_use)


func climb_is_available() -> bool:
	return _wanted(_climb)


## Where the climb cap actually is on screen; empty if the player cannot see it.
##
## `climb_is_available` reports what the LEVEL decided. This reports what is on the glass,
## and the two come apart the moment anything between them forgets the prompt exists -- a
## row that hides itself, a layout that puts it off the edge. A test that only ever asks the
## first question cannot tell a working prompt from an invisible one.
func climb_prompt_rect() -> Rect2:
	if _climb == null or not _climb.is_visible_in_tree():
		return Rect2()
	return _climb.get_global_rect()


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
	# ⚠ OUT OF THE TREE NOW, NOT AT THE END OF THE FRAME. A queued free leaves the old key cap
	# standing until the frame is over, so a verb that changed twice before then -- USE, CUT,
	# USE -- drew three key caps on one prompt, one over the other, and the new cap could not
	# even take the name "PromptKey" while the old one still held it.
	for child in button.get_children():
		if child.name == &"PromptKey":
			button.remove_child(child)
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
		button.modulate.a = reveal * _curtain_alpha


## R and Q, bottom RIGHT.
##
## Thesis §4.5.3.5, on the gameplay wireframe: "the Draw button sits at the lower-right,
## within reach of the pointer that will be used to draw." They sat bottom-left, which put
## the one button in this game that is pressed with a MOUSE at the opposite corner from the
## hand that is about to draw with it -- and directly under the toolbelt, so the two things
## the lower-left holds were stacked on each other.
##
## Q keeps its place beside R rather than moving to the far side: they are the two standing
## verbs and they read as a pair. R is the outermost because it is the one always available.
func _place_bottom_actions() -> void:
	if _draw == null or not is_instance_valid(_draw):
		return
	var view := get_viewport_rect().size
	_draw.size = _draw.get_combined_minimum_size()
	_draw.position = Vector2(
		view.x - BOTTOM_MARGIN.x - _draw.size.x,
		view.y - BOTTOM_MARGIN.y - _draw.size.y)
	_revert.size = _revert.get_combined_minimum_size()
	_revert.position = Vector2(
		_draw.position.x - BOTTOM_GAP - _revert.size.x,
		view.y - BOTTOM_MARGIN.y - _revert.size.y)


func _follow_player(delta: float) -> void:
	if _floating_row == null:
		return
	var anchor: Variant = _target_position()
	if anchor == null:
		_floating_row.visible = false
		_follow_ready = false
		return
	# ⚠ EVERY PROMPT IN THE ROW, not the two that were in it when this line was written.
	# The row is the climb cap's parent, so a row hidden because E and F are both away takes
	# the climb with it -- the prompt would be wanted, lit, laid out, and inside an invisible
	# container. LATENT rather than live: E reaches 96px from an object's surface and the
	# climb reaches its half-diagonal from the centre, and for anything drawn at this game's
	# sizes the second is inside the first. It stops being true the moment either number
	# moves, and the failure would be silent.
	_floating_row.visible = _pickup.visible or _use.visible or _climb.visible
	var row_size := _floating_row.get_combined_minimum_size()
	_floating_row.size = row_size
	var feet := get_viewport().get_canvas_transform() * (anchor as Vector2)
	# ⚠ OVER THE HEAD, UNLESS THAT IS BEHIND THE HUD. Ang Bale is the top of Payyo, and the
	# camera follows a climb by only three quarters of it, so at the door the apo stands high
	# on the screen -- and F UNLOCK, 118px over her, went up behind the objective line and was
	# clamped there, a sliver of gold under the banner (Kent, of prompts at the top: "it cant
	# be seen"). It goes under her feet instead, as Lolo's bar does, and back over her head
	# only once there is clear room there again.
	#
	# ⚠ AND IT IS DECIDED WHILE THE ROW IS AWAY, at the size a prompt would be. A prompt
	# appears where the row already is, and the lesson that points at it is taught that same
	# frame -- decided only once something was showing, the key came up behind the banner,
	# slid down past "F uses it." and left the bubble's beak aimed at the banner.
	_judge_in -= delta
	if _judge_in <= 0.0:
		_judge_in = JUDGE_EVERY
		var room := Vector2(maxf(row_size.x, ROOM.x), maxf(row_size.y, ROOM.y))
		var panels := _hud_panels()
		var over_room := Rect2(_over(feet, room), room)
		if _under:
			_under = _lands_on(over_room.grow(BACK_OVER_CLEARANCE), panels)
		else:
			_under = _lands_on(over_room, panels) \
				and not _lands_on(Rect2(_under_feet(feet, room), room), panels)
	var desired := _under_feet(feet, row_size) if _under else _over(feet, row_size)
	if not _follow_ready or _follow_position.distance_to(desired) > TELEPORT_DISTANCE:
		_follow_position = desired
		_follow_ready = true
	else:
		var weight := 1.0 - exp(-FOLLOW_SPEED * delta)
		_follow_position = _follow_position.lerp(desired, weight)
	var context_amount := maxf(maxf(_amount(_pickup), _amount(_use)), _amount(_climb))
	var bob := sin(_time * TAU * 0.72) * 2.0 * context_amount
	# Whole-pixel placement keeps Geist Pixel sharp even though the underlying ease is
	# continuous. It reads as smooth motion but never lands the type between pixels.
	_floating_row.position = (_follow_position + Vector2(0.0, bob)).round()


## How far below the player's feet the row reaches while it is down there, and 0 while it is
## over their head or away. Lolo's hint bar asks, so that under her feet it stands below the
## keys rather than across them: the keys are what she can do right here, and nearer to her.
func keys_below_feet() -> float:
	if not _under or _floating_row == null or not _floating_row.visible:
		return 0.0
	return UNDER_THE_FEET + _floating_row.size.y


func _over(feet: Vector2, row_size: Vector2) -> Vector2:
	return _on_screen(feet + FOLLOW_OFFSET - Vector2(row_size.x * 0.5, row_size.y), row_size)


func _under_feet(feet: Vector2, row_size: Vector2) -> Vector2:
	return _on_screen(Vector2(feet.x - row_size.x * 0.5, feet.y + UNDER_THE_FEET), row_size)


func _on_screen(at: Vector2, row_size: Vector2) -> Vector2:
	var view := get_viewport_rect().size
	return Vector2(
		clampf(at.x, EDGE_GUARD, maxf(EDGE_GUARD, view.x - row_size.x - EDGE_GUARD)),
		clampf(at.y, EDGE_GUARD, maxf(EDGE_GUARD, view.y - row_size.y - EDGE_GUARD)))


func _lands_on(rect: Rect2, panels: Array[Rect2]) -> bool:
	for panel in panels:
		if rect.intersects(panel):
			return true
	return false


## The rest of the HUD on this layer: every framed panel, and what draws its own ground.
##
## Not Lolo's bar and not a lesson's bubble. The bar stands clear of these keys (see
## `keys_below_feet`), and a bubble is placed against them -- moving for either would leave
## the bar dodging back and the bubble's beak aimed at where the keys used to be.
func _hud_panels() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var layer := get_parent()
	if layer != null:
		_gather_panels(layer, out)
	for node in get_tree().get_nodes_in_group(&"hud_blockers"):
		var control := node as Control
		if control != null and control.is_visible_in_tree() and control.modulate.a > 0.05 \
				and not _yields_to_the_keys(control):
			out.append(control.get_global_rect())
	return out


func _gather_panels(node: Node, into: Array[Rect2]) -> void:
	if node == self or node is HintBar or node is TutorialCallout:
		return
	var panel := node as PanelContainer
	if panel != null and panel.is_visible_in_tree() and panel.modulate.a > 0.05 \
			and panel.size.x > 8.0 and panel.size.y > 8.0 \
			and panel.has_theme_stylebox_override(&"panel"):
		into.append(panel.get_global_rect())
		return
	for child in node.get_children():
		_gather_panels(child, into)


func _yields_to_the_keys(control: Control) -> bool:
	var cursor: Node = control
	while cursor != null:
		if cursor is HintBar or cursor is TutorialCallout:
			return true
		cursor = cursor.get_parent()
	return false


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
