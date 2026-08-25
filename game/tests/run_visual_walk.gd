extends SceneTree
## Photographs the apo through his walk, all six cells at once, so the gait can be judged.
##
##   godot --path game --script res://tests/run_visual_walk.gd
##
## Needs a REAL viewport -- no --headless -- like every other visual runner here. It exists
## because the walk was wrong for months in a way no assertion could see: the delivered
## sheet has no passing pose, so the legs never came together and the character slid, and
## the sheet that replaced it planted the same foot in all six of its frames, so he hopped
## instead. Both pass every test in this project. Neither survives being looked at.
##
## Six figures side by side rather than one photographed six times: the strip is then a
## single frame, and whether the feet alternate is a question you can answer by looking
## along a row instead of by flipping between files.

const FigureScript = preload("res://scripts/wanderer_figure.gd")
const POSES: Array[StringName] = [&"walk", &"run"]
const CELLS := 6
## Drawn at double, and cropped to the strip: the point of the shot is the legs, and
## at 1:1 in a window this size they are eleven pixels in a field of grass.
const ZOOM := 2
const PITCH := 190
const GROUND := 250


func _init() -> void:
	root.set_content_scale_size(Vector2i(PITCH * CELLS, GROUND + 40))
	_run.call_deferred()


func _run() -> void:
	var ground := ColorRect.new()
	ground.color = Color(0.47, 0.55, 0.43)
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ground)

	var figures: Array[Node2D] = []
	for cell in range(CELLS):
		var figure := Node2D.new()
		figure.set_script(FigureScript)
		figure.position = Vector2(float(cell) * PITCH + PITCH * 0.5, GROUND)
		figure.scale = Vector2(ZOOM, ZOOM)
		root.add_child(figure)
		figures.append(figure)

	for pose in POSES:
		for cell in range(CELLS):
			figures[cell].set("pose", pose)
			# A hair inside the cell, so flooring the phase never lands on the seam.
			figures[cell].set("stride", (float(cell) + 0.01) / float(CELLS))
			figures[cell].call("refresh")
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		shot = shot.get_region(Rect2i(0, GROUND - 100 * ZOOM, PITCH * CELLS, 110 * ZOOM))
		shot.save_png("/tmp/obra_walk_%s.png" % pose)
	print("OBRA_VISUAL_WALK_DONE")
	quit()
