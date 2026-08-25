extends SceneTree
## Photographs the house: the wall of paintings, and the prompt when the apo stands at one.
##
## Needs a REAL viewport -- no --headless -- like every other visual runner here. Four
## defects in this project passed green suites and were caught only by looking at frames.

const HUB := "res://levels/hub/hub.tscn"

var hub: Node2D


func _init() -> void:
	root.set_content_scale_size(Vector2i(1600, 900))
	_run.call_deferred()


func _run() -> void:
	hub = (load(HUB) as PackedScene).instantiate()
	root.add_child(hub)
	for _frame in range(20):
		await process_frame
	await _shot("00_arrival")

	# Along the wall, stopping in front of each painting.
	var room: Node2D = hub.get_node("Room")
	for index in range(5):
		var at: Vector2 = room.call("painting_anchor", index)
		var apo: Node2D = hub.get_node("Apo")
		apo.set("velocity", Vector2.ZERO)
		apo.global_position = Vector2(at.x, room.call("ground_y"))
		for _frame in range(24):
			await process_frame
		await _shot("%02d_%s" % [index + 1, String(hub.WALL[index]["plate"]).to_lower()])
	print("OBRA_VISUAL_HUB_DONE")
	quit()


## WAITS FOR THE DRAW, not for two more frames of logic. Every other visual runner here
## already does; this one did not, and the last frame it wrote was always a copy of the one
## before it, because the tree had moved the apo on and the renderer had not yet been asked
## for a picture of that. It photographed a room the apo had already left -- which is a
## particularly bad failure in a runner whose whole job is that four defects in this project
## passed green suites and were caught only by looking at frames.
func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("/tmp/obra_hub_%s.png" % name)
