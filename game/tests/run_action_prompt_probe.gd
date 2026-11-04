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
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
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
	await _placement_replaces_draw(draw)

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
	await _physics_frames(2)
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

	_finish()


func _placement_replaces_draw(draw: Button) -> void:
	var placement := level.get("placement_controller") as PlacementController
	var inventory := level.get("inventory_manager") as InventoryManager
	var panel := level.get("draw_panel") as DrawPanel
	var item := DrawnItemData.new()
	item.entity_id = "square"
	item.display_name = "Square"
	var slot := inventory.add_item(item)
	level.call("_on_inventory_slot_pressed", slot)
	_check(placement.is_placing(), "a bag drawing starts placement")
	if not placement.is_placing():
		return
	placement.set_process(false)
	# Clear ground beside the spawn; aiming and input routing are separate concerns here.
	placement.update_target(_player_position() + Vector2(160.0, -30.0))
	var preview := placement.get("_preview") as PhysicsShapeObject
	await create_timer(0.2).timeout
	_check(draw.disabled and not draw.visible, "Draw is disabled and hidden while holding a placeable")
	var rotate := prompts.get_node("RotatePlacementPrompt") as Button
	var resize := prompts.get_node("ScalePlacementPrompt") as Button
	_check(rotate.is_visible_in_tree() and resize.is_visible_in_tree(),
		"rotate and scale controls replace Draw")
	_check((rotate.get_node("PromptKey").get_child(0) as Label).text == "Z / X"
		and (resize.get_node("PromptKey").get_child(0) as Label).text == "C / V",
		"placement controls show Z/X rotate and C/V scale")
	_check(rotate.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and resize.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"placement key indicators let clicks reach the world")
	var screen := root.get_visible_rect()
	_check(screen.encloses(rotate.get_global_rect()) and screen.encloses(resize.get_global_rect())
		and rotate.get_global_rect().end.x < resize.get_global_rect().position.x
		and resize.get_global_rect().end.y > screen.end.y - 80.0,
		"placement controls fit side by side in the lower-right corner")
	await _capture("holding")

	await _press_key(KEY_R)
	await _press_key(KEY_R)
	_check(not panel.is_open() and placement.is_placing()
		and placement.get("_preview") == preview and inventory.peek_item(slot) == null,
		"pressing R leaves the held object intact and the canvas closed")
	# Also exercise the button handler, guarding queued or programmatic button activation.
	draw.pressed.emit()
	_check(not panel.is_open() and placement.get("_preview") == preview,
		"Draw activation cannot interrupt placement")

	_check(placement.confirm_placement(), "the held object can still be placed after R")
	preview.freeze = true
	await create_timer(0.2).timeout
	_check(not draw.disabled and draw.visible and not rotate.visible and not resize.visible,
		"placing the object restores Draw and removes placement controls")
	await _press_key(KEY_R)
	_check(panel.is_open(), "R opens the canvas again after placement")
	panel.close_panel()
	preview.queue_free()
	await create_timer(0.3).timeout

	# A second hold ends by right-clicking, using the same input path as the player.
	var second := DrawnItemData.new()
	second.entity_id = "square"
	second.display_name = "Square"
	slot = inventory.add_item(second)
	level.call("_on_inventory_slot_pressed", slot)
	var cancel := InputEventMouseButton.new()
	cancel.button_index = MOUSE_BUTTON_RIGHT
	cancel.position = Vector2(1000.0, 500.0)
	cancel.pressed = true
	root.push_input(cancel, true)
	cancel = cancel.duplicate() as InputEventMouseButton
	cancel.pressed = false
	root.push_input(cancel, true)
	await create_timer(0.2).timeout
	_check(not placement.is_placing() and inventory.peek_item(slot) == second
		and not draw.disabled and draw.visible and not rotate.visible and not resize.visible,
		"putting the object away restores Draw and removes placement controls")
	await _press_key(KEY_R)
	_check(panel.is_open(), "R opens the canvas again after storing the object")
	panel.close_panel()
	await create_timer(0.3).timeout
	await _capture("released")
	placement.set_process(true)


func _press_key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _capture(state: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/obra_placement_controls_%s.png" % state)


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
