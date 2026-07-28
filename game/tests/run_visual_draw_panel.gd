extends SceneTree
## Drives the real level's drawing panel end to end so the live guess, the placement
## preview and the reach ring can be inspected by eye. Needs a real viewport:
##   godot --path game --script res://tests/run_visual_draw_panel.gd
## Frames land in /tmp/obra_<round>_*.png

const OUTPUT_DIR := "/tmp"

var level: Node2D
var panel: DrawPanel
var canvas: Control
var placement: PlacementController
var status: Label


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://game_level.tscn") as PackedScene
	level = scene.instantiate() as Node2D
	root.add_child(level)
	await _wait(1.5)

	panel = level.get_node("DrawPanel") as DrawPanel
	canvas = panel.get_node("PanelRoot/SubViewportContainer/SubViewport/Canvas") as Control
	placement = level.get_node("PlacementController") as PlacementController
	status = level.get_node("CanvasLayer/StatusLabel") as Label

	# Different aim points so the first round's object is not sitting in the second's way.
	await _round("circle", _draw_circle_stroke, Vector2(170.0, 80.0))
	await _round("ladder", _draw_ladder_strokes, Vector2(-190.0, 80.0))

	print("OBRA_VISUAL_PANEL_DONE")
	quit(0)


func _round(label: String, draw_it: Callable, aim: Vector2) -> void:
	print("--- %s ---" % label)
	panel.open_panel()
	await _wait(0.4)
	draw_it.call()
	await _wait(1.4)
	await _capture("%s_guess" % label)
	print("  guess:  '%s'" % (panel.get_node("PanelRoot/GuessLabel") as Label).text)
	print("  button: '%s'" % (panel.get_node("PanelRoot/TransformButton") as Button).text)

	# Nothing transforms on its own: the player presses the button, always.
	print("  panel still open before pressing Transform (must be true): %s" % panel.is_open())
	panel.call("_on_transform_pressed")
	await _wait(2.2)
	print("  after pressing Transform: '%s'" % status.text)

	# Drawing an object no longer forces a placement: it goes in the bag, and taking it
	# out again is what starts one.
	print("  placing straight after drawing (should be false): %s" % placement.is_placing())
	var inventory = level.get_node("InventoryManager")
	print("  inventory holds: %d" % inventory.call("items").size())
	level.call("_on_inventory_slot_pressed", 0)
	await _wait(0.3)
	if not placement.is_placing():
		print("  NOT PLACING after taking slot 1 (recognised a morph, or nothing stored)")
		await _capture("%s_result" % label)
		return
	placement.set_process(false)
	var actor: Node2D = level.get("player")
	placement.update_target(actor.global_position + aim)
	await _wait(0.3)
	await _capture("%s_aim_ground" % label)
	print("  aimed at ground: valid=%s  '%s'" % [placement.get("_valid"), status.text])
	placement.update_target(actor.global_position + Vector2(2000.0, 0.0))
	await _wait(0.3)
	await _capture("%s_aim_far" % label)
	print("  aimed past reach: valid=%s at_limit=%s  '%s'" % [
		placement.get("_valid"), placement.is_at_reach_limit(), status.text
	])
	placement.update_target(actor.global_position + aim)
	await _wait(0.2)
	print("  confirmed: %s" % placement.confirm_placement())
	await _wait(1.0)
	await _capture("%s_placed" % label)
	print("  after placing: '%s'" % status.text)
	placement.set_process(true)


## A closed round scribble, drawn in the canvas's own 512x512 space.
func _draw_circle_stroke() -> void:
	var center := Vector2(256.0, 256.0)
	var radius := 150.0
	canvas.call("_start_stroke", center + Vector2(radius, 0.0))
	for step in range(1, 49):
		var angle := TAU * float(step) / 48.0
		canvas.call("_append_point", center + Vector2(cos(angle), sin(angle)) * radius)
	canvas.call("_append_point", center + Vector2(radius, 0.0), true)
	canvas.set("_current_line", null)


## Two rails and four rungs.
func _draw_ladder_strokes() -> void:
	_stroke([Vector2(180.0, 70.0), Vector2(180.0, 440.0)])
	_stroke([Vector2(330.0, 70.0), Vector2(330.0, 440.0)])
	for y in [140.0, 220.0, 300.0, 380.0]:
		_stroke([Vector2(180.0, y), Vector2(330.0, y)])


func _stroke(points: Array) -> void:
	canvas.call("_start_stroke", points[0])
	var from: Vector2 = points[0]
	var to: Vector2 = points[1]
	for step in range(1, 25):
		canvas.call("_append_point", from.lerp(to, float(step) / 24.0))
	canvas.call("_append_point", to, true)
	canvas.set("_current_line", null)


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/obra_%s.png" % [OUTPUT_DIR, label])


func _wait(seconds: float) -> void:
	# process_always, so the panel's own pause of the world does not stall the probe.
	await create_timer(seconds, true).timeout
