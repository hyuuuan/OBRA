extends SceneTree
## Payyo's near scenery plate never shows its cut edge.
##
## The plate (terraces_near_background, NearSceneryLayer/NearA) is a hill of terraces whose right
## edge is a straight vertical cut through stone walls. It stood 182 px short of Ang Hagdan's
## wall, so once the old steps faded the cut showed above the ground as a seam in the picture.
## This walks the climb from the spawn to the gorge and, at every stop and at the top of a jump
## there, checks that every point of the cut the camera can see is behind solid terrace.
##
##   godot --headless --path game --script res://tests/run_level1_backdrop_probe.gd

## Where she stands, as (x, ground top): the lower ground under Ang Hagdan, the two terraces
## above it, and on toward the gorge while the plate slides right behind them.
const STOPS := [
	Vector2(300, 560), Vector2(700, 560), Vector2(1000, 560), Vector2(1150, 560),
	Vector2(1250, 340), Vector2(1380, 340),
	Vector2(1500, 280), Vector2(1800, 280), Vector2(2100, 280),
	Vector2(2190, 240), Vector2(2950, 240), Vector2(3800, 240), Vector2(4700, 80),
]
## A running jump's apex is ~94 px; a little more, so a tuning pass does not have to come back.
const JUMP := 110.0
## The plate's source rows from which its right-hand column is opaque.
const CUT_FROM_ROW := 268.0
const CHECKS := 2 * 13 + 1

var checked := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := (load("res://game_level.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await create_timer(0.6).timeout
	var env := level.get_node("EnvironmentBaseplate") as Node2D
	var plate := env.get_node("NearSceneryLayer/NearA") as Sprite2D
	var camera := level.call("_world_camera") as Camera2D
	var player := level.get("player") as Node2D
	var ground := _solid_terraces(env)
	_check(ground.size() >= 9, "the terraces are found",
		"%d solid terrace segments" % ground.size())
	for stop: Vector2 in STOPS:
		player.call("apply_morph_state", {"position": Vector2(stop.x, stop.y - 60.0),
			"linear_velocity": Vector2.ZERO})
		await create_timer(0.5).timeout
		camera.call("snap_to_target")
		await physics_frame
		var at := camera.get_screen_center_position()
		_check(_cut_hidden(env, plate, camera, ground, at), "standing at x %.0f, the cut is hidden" % stop.x,
			_last_seen)
		# The jump moves the view up and the plate up at its own rate; measure the layer there.
		var apex := at - Vector2(0.0, JUMP)
		_check(_cut_hidden(env, plate, camera, ground, apex), "jumping at x %.0f, the cut is hidden" % stop.x,
			_last_seen)
		env.call("_update_layers", at)
	call_group(DialogueBox.GROUP, &"skip_all")
	level.queue_free()
	for _frame in range(4):
		await process_frame
	if failures == 0 and checked == CHECKS:
		print("OBRA_LEVEL1_BACKDROP_OK checks=%d" % checked)
		quit(0)
	else:
		print("OBRA_LEVEL1_BACKDROP_FAILED=%d checked=%d/%d" % [failures, checked, CHECKS])
		quit(1)


var _last_seen := ""


## Every point of the plate's cut that is on screen with the camera at `center` lies inside a
## solid terrace, which is drawn in front of the plate.
func _cut_hidden(env: Node2D, plate: Sprite2D, camera: Camera2D,
		ground: Array[Rect2], center: Vector2) -> bool:
	env.call("_update_layers", center)
	var size := plate.texture.get_size()
	var top := plate.global_transform * Vector2(size.x * 0.5, -size.y * 0.5 + CUT_FROM_ROW)
	var bottom := plate.global_transform * Vector2(size.x * 0.5, size.y * 0.5)
	var view_size := root.get_visible_rect().size / camera.zoom
	var view := Rect2(center - view_size * 0.5, view_size)
	_last_seen = "cut at x %.0f, y %.0f..%.0f; view %s" % [top.x, top.y, bottom.y, view]
	var y := top.y
	while y <= bottom.y:
		var point := Vector2(top.x - 1.0, y)
		if view.has_point(point) and not _inside_any(ground, point):
			_last_seen = "the cut shows at (%.0f, %.0f); %s" % [point.x, point.y, _last_seen]
			return false
		y += 2.0
	return true


func _inside_any(rects: Array[Rect2], point: Vector2) -> bool:
	for rect in rects:
		if rect.has_point(point):
			return true
	return false


func _solid_terraces(env: Node) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for node in get_nodes_in_group(&"terrace_ground"):
		if not env.is_ancestor_of(node) or bool(node.get("one_way_platform")):
			continue
		var body := node as Node2D
		out.append(Rect2(body.global_position, node.get("segment_size")))
	return out


func _check(ok: bool, what: String, detail: String = "") -> void:
	checked += 1
	if ok:
		print("  ok    %s" % what)
	else:
		failures += 1
		print("  FAIL  %s -- %s" % [what, detail])
