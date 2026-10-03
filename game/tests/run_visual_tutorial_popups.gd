extends SceneTree
## Eyes on the tutorial: every lesson card, over the dim, with its hole where it points.
## Needs a real viewport:
##   godot --path game --script res://tests/run_visual_tutorial_popups.gd
## Frames land in /tmp/obra_tut_<lesson>.png (and _b for a second moment of the animation).
##
## ⚠ THE WHOLE POINT IS WHAT IT LOOKS LIKE, so nothing headless can check it: a card whose
## keys are drawn off its own edge, a hole lit around empty sky, a caption under the dim --
## every one of those passes every assertion about the lesson's text.

const OUTPUT_DIR := "/tmp"
const BRIDGE := [Vector2(10, 40), Vector2(54, 40)]

var level: Node2D
var tutorial
var spot


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	level = (load("res://game_level.tscn") as PackedScene).instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.5)
	tutorial = level.get("tutorial")
	spot = level.get("tutorial_spotlight")
	# The level's own lessons would fire while this stages things; this shows them by hand.
	tutorial.call("set_enabled", false)
	await _wait(0.6)
	# Off again, so each card is the one a player sees: a `look` card stops the world and
	# carries its click-to-continue mouse.
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", false)
	await _capture("none")

	for id in ["move", "jump", "draw", "requirement", "checkpoint", "ink"]:
		await _card(id)

	# Something in the bag, for the bag's two lessons.
	_draw("bridge", "Bridge")
	await _wait(0.4)
	await _card("bag")
	await _card("bag_open")

	# The three placement cards, lit around the drawing on the end of the mouse.
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	level.call("_on_inventory_slot_pressed", int(level.call("_slot_holding", "bridge")))
	var placement := level.get("placement_controller") as PlacementController
	placement.set_process(false)
	var player := level.get("player") as Node2D
	placement.update_target(player.global_position + Vector2(220.0, -60.0))
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", false)
	await _wait(0.3)
	for id in ["place", "resize", "rotate"]:
		await _card(id, true)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	placement.confirm_placement()
	placement.set_process(true)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", false)
	await _wait(0.4)
	await _card("undo")

	# A drawing worn: the change-back key and the clock.
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	_draw("frog", "Frog")
	await _wait(1.0)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", false)
	await _card("revert")
	await _card("clock")

	# And the canvas: the page while it is empty, the button once there is ink on it.
	var panel = level.get("draw_panel")
	panel.call("open_panel")
	await _wait(0.9)
	await _card("canvas", true)
	(panel.get("transform_button") as Button).disabled = false
	await _card("transform", true)
	print("OBRA_VISUAL_TUTORIAL_POPUPS_DONE")
	quit(0)


func _card(id: String, twice := false) -> void:
	var lesson: Dictionary = tutorial.call("_find", id)
	if lesson.is_empty():
		print("no lesson %s" % id)
		return
	tutorial.call("_show", lesson)
	await _wait(0.9)
	await _capture(id)
	if twice:
		await _wait(0.8)
		await _capture(id + "_b")
	print("%-12s card %s  hole %s  caption '%s'  kind %s" % [id, spot.call("card_rect"),
		spot.call("hole_rect"), spot.call("caption_text"), spot.call("visual_kind")])
	spot.call("finish", "seen")
	await _wait(0.5)


func _draw(entity: String, display: String) -> void:
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	level.call("_on_drawing_ready", entity, display, sheet, {"confidence": 0.9},
		[{"points": PackedVector2Array(BRIDGE), "width": 6.0, "color": Color.BLACK}], 1.0)


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/obra_tut_%s.png" % [OUTPUT_DIR, label])


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout
