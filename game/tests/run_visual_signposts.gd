extends SceneTree
## Photographs the four signposts, so the glyphs can be checked against each other.
##
##   godot --path game --script res://tests/run_visual_signposts.gd
##
## Needs a REAL viewport -- no --headless. The thing being judged is whether five marks on
## a board the size of a fist are five DIFFERENT shapes at the distance a player sees them
## from, and there is no way to assert that.

const CARD := preload("res://scripts/signpost_2d.gd")
const MARKS := [0, 1, 2, 3, 4]       # STORY, HINT, CHOICE, MEMORY, FIND
const PITCH := 150
const GROUND := 210
const ZOOM := 3


func _init() -> void:
	root.set_content_scale_size(Vector2i(PITCH * MARKS.size(), GROUND + 40))
	_run.call_deferred()


func _run() -> void:
	var ground := ColorRect.new()
	ground.color = Color(0.24, 0.42, 0.18)
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ground)

	for index in range(MARKS.size()):
		var post := Node2D.new()
		post.set_script(CARD)
		post.set("mark", MARKS[index])
		# Nothing to stand on in here, so the ray finds nothing and it keeps its height.
		post.position = Vector2(float(index) * PITCH + PITCH * 0.5, GROUND)
		post.scale = Vector2(ZOOM, ZOOM)
		root.add_child(post)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	shot.get_region(Rect2i(0, GROUND - 60 * ZOOM, PITCH * MARKS.size(), 62 * ZOOM)) \
		.save_png("/tmp/obra_signposts.png")
	print("OBRA_VISUAL_SIGNPOSTS_DONE")
	quit()
