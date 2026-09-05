extends SceneTree
## Eyes on the pointing tutorial. Needs a real viewport:
##   godot --path game --script res://tests/run_visual_tutorial_popups.gd
## Frames land in /tmp/obra_tut_*.png
##
## ⚠ THE WHOLE POINT IS WHERE THINGS ARE, so nothing headless can check it. A callout that
## says the right sentence with its beak pointing at empty sky, or one clipped off the
## bottom of the screen because the prompt it belongs to sits in the corner, passes every
## assertion about its text.

const OUTPUT_DIR := "/tmp"

var level: Node2D
var tutorial


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	level = (load("res://game_level.tscn") as PackedScene).instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.4)
	tutorial = level.get("tutorial")

	# THE DRAW BUTTON, bottom-left. The hardest placement in the level: a bubble authored
	# "above" it is right, and one authored "below" would hang off the screen entirely.
	_teach("draw")
	await _wait(0.6)
	await _capture("00_points_at_draw")

	# ⚠ THE BAG HAS TO HAVE SOMETHING IN IT. `InventoryHUD` is hidden while empty, so its
	# rect is empty, so the anchor does not resolve and the lesson correctly falls back to
	# the bar -- which is right in the game (the `bag` lesson fires at `item_stored`) and
	# useless in a test that forced it early. Give it an item first, as the level would.
	_dismiss()
	var bagged := DrawnItemData.new()
	bagged.entity_id = "square"
	bagged.display_name = "Square"
	(level.get("inventory_manager") as Node).call("add_item", bagged)
	await _wait(0.4)
	_teach("bag")
	await _wait(0.6)
	await _capture("01_points_at_bag")

	_dismiss()
	_teach("ink")
	await _wait(0.6)
	await _capture("02_points_at_ink")

	# AND THEN LOLO EXPLAINS THE SCREEN. The panel is a modal, so the world is already
	# stopped; this is the one lesson that is allowed to be a conversation.
	_dismiss()
	var panel = level.get("draw_panel")
	panel.call("open_panel")
	await _wait(0.9)
	await _capture("03_lolo_explains_the_canvas")

	var briefing = panel.get_node_or_null("CanvasBriefing")
	if briefing != null:
		briefing.call("_input", _accept())
		await _wait(0.5)
		await _capture("04_second_line")
		briefing.call("_input", _accept())
		briefing.call("_input", _accept())
		await _wait(0.7)
		await _capture("05_canvas_is_free")
	print("briefing present: %s" % (briefing != null))
	print("OBRA_VISUAL_TUTORIAL_POPUPS_DONE")
	quit(0)


func _accept() -> InputEvent:
	var event := InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	return event


func _teach(lesson_id: String) -> void:
	var lesson: Dictionary = tutorial.call("_find", lesson_id)
	if lesson.is_empty():
		print("no lesson %s" % lesson_id)
		return
	tutorial.call("_teach", lesson)


func _dismiss() -> void:
	tutorial.call("dismiss_callout")


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/obra_tut_%s.png" % [OUTPUT_DIR, label])


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout
