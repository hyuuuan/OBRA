extends SceneTree
## Regression: dark leaf interiors survive export; decoration cannot hide an encounter.
## godot --headless --path game --script res://tests/run_moonlit_foliage_probe.gd
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var fern := Image.load_from_file(ProjectSettings.globalize_path("res://assets/Level4/foliage_moonlit/plant_2.png"))
	_check(fern != null, "foliage is exported separately from the ground")
	if fern == null:
		quit(1)
		return
	for point: Vector2i in [Vector2i(110, 85), Vector2i(110, 105)]:
		_check(fern.get_pixelv(point).a == 1.0, "the fern's central leaf/stem is intact at %s" % point)
	_check(fern.get_pixel(110, 105).is_equal_approx(Color8(1, 22, 26)),
		"the restored navy shadow keeps the source RGB, rather than a painted replacement")
	_check(fern.get_pixel(0, 0).a == 0.0, "outside the fern remains transparent")
	var ground := Image.load_from_file(ProjectSettings.globalize_path("res://assets/Level4/ground_moonlit/face.png"))
	_check(ground != null and not ground.detect_alpha(), "the ground remains an opaque tile, with no cutout pixels")
	var level := (load("res://level_4.tscn") as PackedScene).instantiate()
	level.get_node("BackendSupervisor").auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await create_timer(0.5, true).timeout
	var plane := level.get_node("EnvironmentBaseplate/GameplayPlane")
	var platform_art := load("res://assets/Level4/ground_moonlit/platform.png") as Texture2D
	var branches := 0
	var inconsistent: Array[String] = []
	for body in plane.get_node("Terrain").get_children():
		if not body is MakilingTerrain2D or body.branches.is_empty():
			continue
		branches += body.branches.size()
		if body.branch_texture != platform_art or body.modulate != Color.WHITE or body.z_index >= 0:
			inconsistent.append(String(body.name))
	_check(branches == 6 and inconsistent.is_empty(),
		"all six one-way floating blocks share the Tikbalang art, tint and draw order: " + str(inconsistent))
	var stone := plane.get_node("Terrain/CliffDressingStone")
	var hollow := plane.get_node("Terrain/Hollow")
	var landmark := plane.get_node("Terrain/LandmarkRock")
	_check(stone.get("_shelf") == platform_art
		and stone.call("uses_floating_shelf", hollow.platforms[0])
		and not stone.call("uses_floating_shelf", landmark.platforms[0]),
		"the floating hollow shelf shares that art; the grounded landmark keeps its rock depth")
	for name: String in ["CliffDressing", "CliffDressingStone"]:
		var dressing := plane.get_node(NodePath("Terrain/" + name))
		_check(dressing.get("_plants").is_empty() and dressing.get("_vines").is_empty(),
			"%s draws ground only" % name)
	var nuno := plane.get_node("Hazards/NunoMound")
	for name: String in ["BackgroundBushes", "GroundVines"]:
		var decoration := plane.get_node(NodePath(name))
		var rects: Array[Rect2] = decoration.call("decoration_rects")
		var reserved: Array[Rect2] = decoration.call("reserved_regions")
		_check(rects.size() >= 3, "%s actually places decoration outside encounters" % name)
		var overlaps := 0
		for rect in rects:
			for region in reserved:
				overlaps += int(rect.intersects(region))
		_check(overlaps == 0, "%s leaves encounter volumes and supplies clear" % name)
		_check(_effective_z(decoration) < _effective_z(nuno.get_node("Nuno")),
			"%s draws behind Nuno, including his emerging spirit" % name)
		var foes_in_front := true
		for foe in get_nodes_in_group(&"dilim_foes"):
			if foe is CanvasItem:
				foes_in_front = foes_in_front and _effective_z(decoration) < _effective_z(foe)
		_check(foes_in_front, "%s draws behind every placed foe" % name)
		# The finale creates aswang at runtime; their parent differs from placed encounters.
		var aswang := GroundEnemy2D.new()
		aswang.kind = "aswang_pig"
		plane.add_child(aswang)
		aswang.global_position = Vector2(22000, 585)
		_check(_effective_z(decoration) < _effective_z(aswang.art),
			"%s also draws behind a spawned aswang" % name)
		aswang.queue_free()
	call_group(DialogueBox.GROUP, &"skip_all")
	level.queue_free()
	await process_frame
	if failures == 0:
		print("OBRA_MOONLIT_FOLIAGE_OK")
	else:
		print("OBRA_MOONLIT_FOLIAGE_FAILED=%d" % failures)
	quit(0 if failures == 0 else 1)


func _effective_z(node: CanvasItem) -> int:
	var z := node.z_index
	var parent := node.get_parent() as CanvasItem
	return z + _effective_z(parent) if node.z_as_relative and parent != null else z


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %s" % ["OK" if ok else "FAIL", message])
