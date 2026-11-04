extends SceneTree
## Isolated regression probe for the contextual action HUD:
##   godot --headless --path game --script res://tests/run_action_prompt_probe.gd

## Every check this probe makes, so a crash part-way cannot print OK.
const CHECKS := 24
const ControlsKeys = preload("res://scripts/controls_overlay.gd")

var failures: Array[String] = []
var checked := 0
var level: Node2D
var prompts: ActionPromptHUD


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://game_level.tscn") as PackedScene
	_check(packed != null, "game level scene loads")
	if packed == null:
		_finish()
		return
	level = packed.instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	var dialogue := level.get("dialogue_box") as DialogueBox
	if dialogue != null:
		dialogue.hide_line()
	await process_frame
	await physics_frame

	prompts = level.get("action_prompts") as ActionPromptHUD
	_check(prompts != null, "individual action HUD is built")
	if prompts == null:
		_finish()
		return
	var draw := level.get_node_or_null("CanvasLayer/DrawButton") as Button
	_check(draw != null and draw.visible, "R Draw stands at level start")
	_check(not prompts.pickup_is_available(), "E is hidden with no pickup in range")
	_check(not prompts.use_is_available(), "F is hidden with no held tool")
	_check(not prompts.revert_is_available(), "Q is hidden while the player is themselves")

	var registry := level.get("registry") as EntityRegistry
	var world_items := level.get("world_item_root") as Node2D
	var placed := registry.instantiate_entity("square") as PhysicsShapeObject
	world_items.add_child(placed)
	var placed_item := DrawnItemData.new()
	placed_item.entity_id = "square"
	placed_item.display_name = "Square"
	placed.apply_item_data(placed_item)
	placed.set_preview(true)
	placed.global_position = _player_position() + Vector2(48.0, -20.0)
	placed.confirm_placement()
	placed.freeze = true
	await _physics_frames(2)
	_check(prompts.pickup_is_available(), "E appears for a placed drawing inside reach")

	placed.global_position = _player_position() + Vector2(320.0, 0.0)
	await _physics_frames(2)
	_check(not prompts.pickup_is_available(), "E hides after the drawing leaves reach")

	placed.global_position = _player_position() + Vector2(48.0, -20.0)
	var axe := registry.instantiate_entity("axe") as UtilityObject
	world_items.add_child(axe)
	var axe_item := DrawnItemData.new()
	axe_item.entity_id = "axe"
	axe_item.display_name = "Axe"
	axe.apply_item_data(axe_item)
	axe.equip_to(level.get("player") as Node2D)
	level.set("_equipped_utility", axe)
	await _physics_frames(2)
	_check(prompts.use_is_available(), "F appears for the held tool")
	_check(prompts.pickup_is_available(), "held F tool does not hide a separate E pickup")

	placed.queue_free()
	await process_frame
	await physics_frame
	_check(not prompts.pickup_is_available(), "held tool does not advertise E after pickup leaves")
	_check(prompts.use_is_available(), "F remains while the tool stays in hand")

	# Q is driven by the active body type. A lightweight stand-in is enough here because
	# this probe tests prompt state, not ragdoll adoption (covered by the morph tests).
	var wanderer := level.get("player") as Node2D
	var stand_in := Node2D.new()
	level.set("player", stand_in)
	await physics_frame
	_check(prompts.revert_is_available(), "Q appears when the active body is not Wanderer")
	level.set("player", wanderer)
	await physics_frame
	_check(not prompts.revert_is_available(), "Q hides after returning to Wanderer")
	stand_in.free()

	# ⚠ ONE KEY CAP, HOWEVER OFTEN THE VERB CHANGES IN A FRAME. The old cap used to be queued
	# for deletion and left standing until the frame ended, so USE, CUT, USE wore three caps on
	# one prompt, one over another. Found by run_play_level2's overlap watch in Piyesta's alleys.
	prompts.set_use_available(true, "", "CUT")
	prompts.set_use_available(true, "", "USE")
	prompts.set_use_available(true, "", "CUT")
	var use_prompt := prompts.find_child("UsePrompt", true, false)
	var caps := 0
	if use_prompt != null:
		for child in use_prompt.get_children():
			if child is PanelContainer:
				caps += 1
	_check(caps == 1, "a verb changed three times in one frame wears one key cap (%d)" % caps)

	prompts.set_use_available(false)
	await _movement_keys()
	_finish()


## WALK AND JUMP STAND BESIDE R IN PAYYO. Kent: "the R at the button should also be paired with
## the WASD buttons for like guidance as well as the jump".
func _movement_keys() -> void:
	# ⚠ NOTHING TALKING. Payyo's tutorial says its walk lead about now, and a line in the story
	# box pauses the tree -- the row stops being laid out and every rect below goes stale.
	level.get("tutorial").call("set_enabled", false)
	call_group(TutorialSpotlight.GROUP, &"close")
	(level.get("dialogue_box") as DialogueBox).hide_line()
	await _physics_frames(30)
	var move := prompts.find_child("MovePrompt", true, false) as Button
	var jump := prompts.find_child("JumpPrompt", true, false) as Button
	var draw := level.get_node("CanvasLayer/DrawButton") as Button
	_check(prompts.movement_keys_shown() and move != null and move.visible and jump != null
		and jump.visible, "walk and jump stand beside R in Payyo")
	var caps: Dictionary = prompts.movement_key_caps()
	var want_move: Array[String] = [ControlsKeys.key_cap_for("move_left"),
		ControlsKeys.key_cap_for("move_right")]
	_check(caps["move"] == want_move, "MOVE's caps are the InputMap's (%s)" % ", ".join(caps["move"]))
	var want_jump: Array[String] = [ControlsKeys.key_cap_for("jump")]
	_check(caps["jump"] == want_jump, "JUMP's cap is the InputMap's (%s)" % ", ".join(caps["jump"]))

	# ⚠ READ OFF THE INPUTMAP, NOT TYPED. A cap that matched the default binding proves nothing,
	# so jump is rebound to K and a fresh row has to say K.
	var saved := InputMap.action_get_events(&"jump")
	InputMap.action_erase_events(&"jump")
	var rebound := InputEventKey.new()
	rebound.physical_keycode = KEY_K
	InputMap.action_add_event(&"jump", rebound)
	var fresh := ActionPromptHUD.new()
	root.add_child(fresh)
	var fresh_caps: Array = fresh.movement_key_caps()["jump"]
	_check(fresh_caps == ["K"], "a rebound jump key is what the cap says (%s)" % ", ".join(fresh_caps))
	fresh.free()
	InputMap.action_erase_events(&"jump")
	for event in saved:
		InputMap.action_add_event(&"jump", event)

	var move_rect := move.get_global_rect()
	var jump_rect := jump.get_global_rect()
	var draw_rect := draw.get_global_rect()
	# Within two pixels: R breathes (its pulse scales it about its centre) and the others do not.
	_check(absf(move_rect.end.y - draw_rect.end.y) <= 2.0 and absf(jump_rect.end.y - draw_rect.end.y)
		<= 2.0 and move_rect.end.x <= jump_rect.position.x
		and jump_rect.end.x <= draw_rect.position.x + 2.0,
		"in R's row, left of it, walk then jump (%s, %s, R %s)" % [move_rect, jump_rect, draw_rect])
	_check(move.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and jump.mouse_filter == Control.MOUSE_FILTER_IGNORE, "and neither can be clicked")

	# Q comes in between them and R, and they step aside rather than being stood on. The level is
	# held still: its own refresh would take Q away again, the apo being herself.
	level.set_physics_process(false)
	prompts.set_revert_available(true)
	await create_timer(0.6).timeout
	var revert := prompts.find_child("ChangeBackPrompt", true, false) as Button
	var row: Array[Rect2] = [move.get_global_rect(), jump.get_global_rect(),
		revert.get_global_rect(), draw.get_global_rect()]
	var in_order := true
	for index in range(row.size() - 1):
		in_order = in_order and row[index].end.x <= row[index + 1].position.x + 2.0
	_check(prompts.revert_is_available() and revert.visible and in_order,
		"Q comes in beside R and walk and jump step aside (%s)" % [row])
	var goal := level.get("goal_label") as Control
	var goal_panel := goal.get_parent() as Control if goal != null else null
	var goal_rect := goal_panel.get_global_rect() if goal_panel != null else Rect2()
	_check(goal_panel != null and goal_panel.is_visible_in_tree()
		and row[0].position.x >= goal_rect.end.x,
		"and MOVE stays clear of the goal readout (%s, goal %s)" % [row[0], goal_rect])
	prompts.set_revert_available(false)
	level.set_physics_process(true)

	# The other four do not ask for them.
	var asked: Array[String] = []
	for number in [2, 3, 4, 5]:
		var other: Node = (load("res://scripts/level_%d.gd" % number) as GDScript).new()
		if bool(other.call("_shows_movement_keys")):
			asked.append("level_%d" % number)
		other.free()
	_check(asked.is_empty(), "and no other level shows them (%s)"
		% ("none" if asked.is_empty() else ", ".join(asked)))


func _player_position() -> Vector2:
	return Vector2(level.call("_player_anchor_position"))


func _physics_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func _check(condition: bool, label: String) -> void:
	checked += 1
	print("  %s  %s" % ["OK" if condition else "FAIL", label])
	if not condition:
		failures.append(label)


func _finish() -> void:
	if level != null and is_instance_valid(level):
		level.free()
	if checked != CHECKS:
		failures.append("ran %d of %d checks" % [checked, CHECKS])
		print("  FAIL  ran %d of %d checks -- something stopped the probe part-way" % [checked, CHECKS])
	if failures.is_empty():
		print("OBRA_ACTION_PROMPT_PROBE_OK")
		quit(0)
	else:
		print("OBRA_ACTION_PROMPT_PROBE_FAILED=%d" % failures.size())
		quit(1)
