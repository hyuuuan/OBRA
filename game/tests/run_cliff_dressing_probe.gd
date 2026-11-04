extends SceneTree
## CliffDressing2D: Mayon's painted ground on Levels 1-4 (tools/build_cliff_kits.py).
##
## The contract, on ground built here so the answer is known: an end beside ground as high or
## higher is closed; beside lower ground -- on either side, mud included -- it is a riser as tall
## as the step, shaded down to the lower step; with nothing beside it, a free end; thin pieces are
## loose shelves; tile phase and plants are the world's, so neighbours carry the strip straight on.
## Then each dressed level: its bodies stood their own art down and were all handed over.
##
##   godot --headless --path game --script res://tests/run_cliff_dressing_probe.gd

const Dressing = preload("res://scripts/cliff_dressing_2d.gd")
const KITS := ["res://assets/Level1/cliff", "res://assets/Level4/cliff", "res://assets/Level4/cliff_stone"]
const CHECKS := 11 + 1 * 3 + 6 + 5

var checked := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_contract()
	for kit: String in KITS:
		_kit_is_whole(kit)
	await _payyo()
	await _dilim()
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
	var width := 1808.0
	var left_pieces: Array[Vector3] = dressing.tiles_across(high, width, 0.0)
	var right_pieces: Array[Vector3] = dressing.tiles_across(level, width, 0.0)
	var left_end := left_pieces[left_pieces.size() - 1]
	var right_start := right_pieces[0]
	_check(is_equal_approx(fmod(left_end.y + left_end.z, width), right_start.y),
		"the strip carries straight on across two neighbours", "%s / %s" % [left_end, right_start])
	var moved := Dressing.new()
	moved.kit = KITS[0]
	root.add_child(moved)
	moved.position = Vector2(300, 0)
	var shifted_rect := Rect2(level.position - Vector2(300, 0), level.size)
	var shifted: Array[Vector3] = moved.tiles_across(shifted_rect, width, 0.0)
	_check(shifted[0].y == right_start.y, "tile phase belongs to the world, not to the node",
		"%s vs %s" % [shifted[0], right_start])
	# Plants: the same world spots wherever the node is, and none crowding an end.
	var here: Array[Vector2] = dressing.plant_spots(low)
	var there: Array[Vector2] = moved.plant_spots(Rect2(low.position - Vector2(300, 0), low.size))
	var same := here.size() == there.size() and here.size() > 0
	var clear := true
	for index in range(here.size()):
		same = same and is_equal_approx(here[index].x, there[index].x + 300.0) and here[index].y == there[index].y
		clear = clear and here[index].x >= low.position.x + Dressing.PLANT_MARGIN \
			and here[index].x <= low.end.x - Dressing.PLANT_MARGIN
	_check(same and clear, "plants stand at world spots, clear of the ends", "%s / %s" % [here, there])
	dressing.free()
	moved.free()


## Every picture the runtime asks for is there, wider than a screen so its repeat is not seen,
## and kit.json was read: the walk line above the band, the band above the stone.
func _kit_is_whole(kit: String) -> void:
	var dressing := Dressing.new()
	dressing.kit = kit
	root.add_child(dressing)
	var face := dressing.get("_face") as Texture2D
	var plants: Array = dressing.get("_plants")
	_check(face != null and dressing.get("_edge") != null and face.get_width() > 1600
		and plants.size() >= 2 and dressing.lip < dressing.band and dressing.band < dressing.skip,
		"%s: strip, spill, plants and kit.json" % kit.get_base_dir().get_file(),
		"lip %s band %s skip %s plants %d" % [dressing.lip, dressing.band, dressing.skip, plants.size()])
	dressing.free()


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
	# Ang Hagdan is a 220 px riser: its open side is shaded down to the ground under it.
	var hagdan: float = ends.get(Vector2(1180, 340), -1.0)
	_check(is_equal_approx(hagdan, 220.0), "Ang Hagdan's wall is an open side down to the ground under it",
		"rise %.0f" % hagdan)
	_check(not ends.has(Vector2(2220, 240)),
		"Terrace3 and CentralLeft, level with each other, are one wall")
	_check(ends.has(Vector2(3080, 240)) and ends.has(Vector2(3520, 240)),
		"both lips of the gorge are open ends")
	call_group(DialogueBox.GROUP, &"skip_all")
	level.queue_free()
	for _frame in range(4):
		await process_frame


## Dilim: the mud and the rocks are two dressings over one group, each drawing its own kind and
## closing its ends against the other's; the one-way raised paths stay with the terrain.
func _dilim() -> void:
	var level := (load("res://level_4.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await create_timer(0.4).timeout
	var terrain := level.get_node("EnvironmentBaseplate/GameplayPlane/Terrain")
	var mud := terrain.get_node_or_null("CliffDressing")
	var stone := terrain.get_node_or_null("CliffDressingStone")
	_check(mud != null and stone != null and mud.get("_face") != null and stone.get("_face") != null,
		"Dilim is dressed in its mud and its stone")
	if mud == null or stone == null:
		level.queue_free()
		return
	var counts := {"mud": 0, "stone": 0}
	var undressed := []
	var branches := 0
	for body in get_nodes_in_group(&"makiling_ground"):
		if not terrain.is_ancestor_of(body):
			continue
		var platforms: Array = body.get("platforms")
		branches += (body.get("branches") as Array).size()
		if platforms.is_empty():
			continue
		counts[String(body.get("body"))] += platforms.size()
		if not bool(body.get("_dressed")):
			undressed.append(body.name)
	var drawn := func(dressing: Node) -> int:
		return (dressing.get("_ground") as Array).size() + (dressing.get("_ledges") as Array).size()
	_check(undressed.is_empty() and drawn.call(mud) == counts["mud"] and drawn.call(stone) == counts["stone"],
		"each kind is drawn by its own dressing, and every platform stood its fill down",
		"mud %d/%d, stone %d/%d, still drawing: %s" % [drawn.call(mud), counts["mud"],
		drawn.call(stone), counts["stone"], undressed])
	_check(branches > 0 and (mud.get("_neighbours") as Array).size() == counts["stone"],
		"the raised paths stay with the terrain, and the mud knows where the rocks are",
		"%d branches, %d neighbours" % [branches, (mud.get("_neighbours") as Array).size()])
	# The ravine's top step ends against the far bank's mud wall, which is higher: closed.
	var open_against_mud := false
	for end: Dictionary in stone.call("exposed_ends"):
		var rect: Rect2 = end.rect
		open_against_mud = open_against_mud or (int(end.side) > 0 and is_equal_approx(rect.end.x, 19450.0))
	_check(not open_against_mud, "a rock against a higher mud wall is closed, not an open end")
	_check(mud.modulate.is_equal_approx(Color.WHITE) and stone.modulate == mud.modulate,
		"both retain the supplied kit's baked moonlight without a second night tint", str(mud.modulate))
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
