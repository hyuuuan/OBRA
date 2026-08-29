extends SceneTree
## Isolated regression probe for the contextual action HUD:
##   godot --headless --path game --script res://tests/run_action_prompt_probe.gd

var failures: Array[String] = []
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

	_finish()


func _player_position() -> Vector2:
	return Vector2(level.call("_player_anchor_position"))


func _physics_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func _check(condition: bool, label: String) -> void:
	print("  %s  %s" % ["OK" if condition else "FAIL", label])
	if not condition:
		failures.append(label)


func _finish() -> void:
	if level != null and is_instance_valid(level):
		level.free()
	if failures.is_empty():
		print("OBRA_ACTION_PROMPT_PROBE_OK")
		quit(0)
	else:
		print("OBRA_ACTION_PROMPT_PROBE_FAILED=%d" % failures.size())
		quit(1)
