extends SceneTree
## CliffDressing2D: Mayon's painted ground on Levels 1-4 (tools/build_cliff_kits.py).
##
## The contract, on ground built here so the answer is known: an end beside ground as high or
## higher is closed; beside lower ground -- on either side, mud included -- it is a riser as tall
## as the step, for the cap to be enlarged over; with nothing beside it, a free end; thin pieces
## are loose shelves; and tile phase is the world's, so neighbours carry the strip straight on.
## Then each dressed level: its bodies stood their own art down and were all handed over.
##
##   godot --headless --path game --script res://tests/run_cliff_dressing_probe.gd

const Dressing = preload("res://scripts/cliff_dressing_2d.gd")
const KITS := ["res://assets/Level1/cliff"]
const CHECKS := 10 + 1 * 1 + 6

var checked := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_contract()
	for kit: String in KITS:
		_kit_is_whole(kit)
	await _payyo()
	if failures == 0 and checked == CHECKS:
		print("OBRA_CLIFF_DRESSING_OK checks=%d" % checked)
		quit(0)
	else:
		print("OBRA_CLIFF_DRESSING_FAILED=%d checked=%d/%d" % [failures, checked, CHECKS])
		quit(1)


func _contract() -> void:
	var dressing := Dressing.new()
	dressing.kit = KITS[0]
	root.add_child(dressing)
	var low := Rect2(0, 560, 500, 120)
	var step := Rect2(500, 340, 240, 340)       # 220 over `low`
	var high := Rect2(740, 280, 300, 400)       # 60 over `step`
	var level := Rect2(1040, 280, 200, 400)     # level with `high`
	var island := Rect2(1300, 240, 200, 440)    # nothing to its left; mud to its right
	var mud := Rect2(1500, 400, 200, 280)
	var bank := Rect2(1700, 240, 200, 440)
	var ledge := Rect2(1320, 120, 104, 28)
	dressing.dress([low, step, high, level, island, bank, ledge] as Array[Rect2], [mud] as Array[Rect2])
	var ends := {}
	for end: Dictionary in dressing.exposed_ends():
		ends["%s %d" % [end.rect, end.side]] = float(end.rise)
	_check(ends.has("%s -1" % low) and is_zero_approx(ends["%s -1" % low]),
		"an end with nothing beside it is a free end", str(ends.get("%s -1" % low)))
	_check(not ends.has("%s 1" % low), "an end beside higher ground is closed")
	_check(is_equal_approx(ends.get("%s -1" % step, -1.0), 220.0) and is_equal_approx(ends.get("%s -1" % high, -1.0), 60.0),
		"a step up is a riser as tall as the step", "%s, %s" % [ends.get("%s -1" % step), ends.get("%s -1" % high)])
	_check(not ends.has("%s 1" % high) and not ends.has("%s -1" % level),
		"two level neighbours close each other's ends")
	_check(ends.has("%s -1" % island) and ends.has("%s 1" % level),
		"a gap between two pieces of ground caps both of them")
	_check(is_equal_approx(ends.get("%s 1" % island, -1.0), 160.0) and is_equal_approx(ends.get("%s -1" % bank, -1.0), 160.0),
		"mud beside ground lowers its ends to risers down to it, on either side",
		"%s, %s" % [ends.get("%s 1" % island), ends.get("%s -1" % bank)])
	var ledge_capped := false
	for key: String in ends:
		ledge_capped = ledge_capped or key.begins_with(str(ledge))
	_check(not ledge_capped, "a ledge is a loose shelf, not a wall with caps")
	_check(dressing.get("_ledges").size() == 1 and dressing.get("_ground").size() == 6,
		"thin pieces are ledges, the rest walls", "%d ledges, %d walls" % [
		dressing.get("_ledges").size(), dressing.get("_ground").size()])
	# Tile phase is the world's: where two neighbours meet, the strip carries straight on.
	var width := 1536.0
	var left_pieces: Array[Vector3] = dressing.tiles_across(high, width, 0.0)
	var right_pieces: Array[Vector3] = dressing.tiles_across(level, width, 0.0)
	var left_end := left_pieces[left_pieces.size() - 1]
	var right_start := right_pieces[0]
	_check(is_equal_approx(fmod(left_end.y + left_end.z, width - dressing.tile_overlap),
		fmod(right_start.y, width - dressing.tile_overlap)),
		"the strip carries straight on across two neighbours", "%s / %s" % [left_end, right_start])
	var moved := Dressing.new()
	root.add_child(moved)
	moved.position = Vector2(300, 0)
	var shifted: Array[Vector3] = moved.tiles_across(Rect2(level.position - Vector2(300, 0), level.size), width, 0.0)
	_check(shifted[0].y == right_start.y, "tile phase belongs to the world, not to the node",
		"%s vs %s" % [shifted[0], right_start])
	dressing.free()
	moved.free()


## Every picture the runtime asks for is there, wider than a screen so its repeat is not seen.
func _kit_is_whole(kit: String) -> void:
	var face := load(kit.path_join("face.png")) as Texture2D
	var edge := load(kit.path_join("edge.png")) as Texture2D
	_check(face != null and edge != null and face.get_width() > 1600,
		"%s: a strip and an end cap" % kit.get_base_dir().get_file())


func _payyo() -> void:
	var level := (load("res://game_level.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await create_timer(0.4).timeout
	var env := level.get_node("EnvironmentBaseplate")
	var dressing := env.get_node_or_null("GameplayPlane/Terrain/CliffDressing")
	_check(dressing != null and dressing.get("_face") != null, "Payyo is dressed")
	if dressing == null:
		level.queue_free()
		return
	var walls := 0
	var ledges := 0
	var bare := []
	for body in get_nodes_in_group(&"terrace_ground"):
		if not env.is_ancestor_of(body):
			continue
		var mud: bool = body.get("surface_style") == TerraceSegment2D.SurfaceStyle.MUD
		var wall := body.get_node_or_null(^"RetainingWall") as CanvasItem
		var top := body.get_node_or_null(^"TerraceTop") as CanvasItem
		if (wall != null and wall.visible) or (top != null and top.visible):
			bare.append(body.name)
		if not mud:
			if (body.get("segment_size") as Vector2).y <= Dressing.LEDGE_MAX:
				ledges += 1
			else:
				walls += 1
	_check(bare.is_empty(), "every terrace stood its own wall and cap down", "still drawn: %s" % [bare])
	_check(dressing.get("_ground").size() == walls and dressing.get("_ledges").size() == ledges
		and dressing.get("_others").size() == 1,
		"every terrace, ledge and the paddy bed were handed over",
		"%d/%d walls, %d/%d ledges, %d mud" % [dressing.get("_ground").size(), walls,
		dressing.get("_ledges").size(), ledges, dressing.get("_others").size()])
	var ends := {}
	for end: Dictionary in dressing.call("exposed_ends"):
		ends[Vector2((end.rect as Rect2).position.x if int(end.side) < 0 else (end.rect as Rect2).end.x,
			(end.rect as Rect2).position.y)] = float(end.rise)
	# Ang Hagdan is a 220 px riser: its cap is enlarged to cover the wall down to the ground.
	var hagdan: float = ends.get(Vector2(1180, 340), -1.0)
	_check(is_equal_approx(hagdan, 220.0), "Ang Hagdan's wall is capped down to the ground under it",
		"rise %.0f" % hagdan)
	_check(not ends.has(Vector2(2220, 240)),
		"Terrace3 and CentralLeft, level with each other, are one wall")
	_check(ends.has(Vector2(3080, 240)) and ends.has(Vector2(3520, 240)),
		"both lips of the gorge are capped")
	call_group(DialogueBox.GROUP, &"skip_all")
	level.queue_free()
	for _frame in range(4):
		await process_frame


func _check(ok: bool, what: String, detail: String = "") -> void:
	checked += 1
	if ok:
		print("  ok    %s" % what)
	else:
		failures += 1
		print("  FAIL  %s -- %s" % [what, detail])
