extends "res://tests/run_visual_dilim_creatures.gd"
## Windowed review of the supplied trees in the real level, at night and in clear light.
## godot --path game --resolution 1600x900 --script res://tests/run_visual_dilim_trees.gd
## Captures /tmp/obra_trees_<subject>_<night|lit>.png and /tmp/obra_trees_review.png.


func _run() -> void:
	level = (load("res://level_4.tscn") as PackedScene).instantiate()
	level.get_node("BackendSupervisor").auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(40)
	(level.get("player_health") as PlayerHealth).set_flicker_target(null)
	var world := level.get_node("EnvironmentBaseplate")
	var kapre := world.get_node("GameplayPlane/Encounters/Kapre") as Kapre2D
	var dead := world.get_node("GameplayPlane/Finale/DeadTree") as DeadTree2D
	var forest := world.get_node("ForestBand") as MakilingBackdrop2D
	if not kapre.tree_art.texture.resource_path.begins_with("res://assets/Level4/trees/") \
			or dead.art_folder != "res://assets/Level4/trees/" \
			or forest.plate_texture == null:
		push_error("HARNESS FAULT: level is not using all three supplied tree replacements")
		quit(1)
		return
	var sheet := Image.create(1600, 1800, false, Image.FORMAT_RGBA8)
	var index := 0
	for subject in [{"name": "forest", "at": 11500.0}, {"name": "kapre", "at": 13640.0},
			{"name": "clearing", "at": 21750.0}]:
		await _put_her(subject.at)
		var finale := level.get("_finale") as DilimFinale2D
		finale.set_physics_process(false)
		for foe in get_nodes_in_group(Enemy2D.FOES):
			if foe != kapre:
				foe.set_physics_process(false)
		level.set_physics_process(false)
		for lit in [false, true]:
			level.call("_apply_dawn_visuals", 1.0 if lit else 0.0)
			await process_frame
			await RenderingServer.frame_post_draw
			var shot := root.get_texture().get_image()
			shot.save_png("/tmp/obra_trees_%s_%s.png" % [subject.name, "lit" if lit else "night"])
			shot.convert(Image.FORMAT_RGBA8)
			shot.resize(800, 450, Image.INTERPOLATE_NEAREST)
			sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), Vector2i((index % 2) * 800, (index / 2) * 450))
			index += 1
		level.set_physics_process(true)
	# The same supplied bark after the chop, with the Kapre dropping from its perch.
	await _put_her(13640.0)
	while not kapre.is_felled():
		kapre.chop()
	level.set_physics_process(false)
	level.call("_apply_dawn_visuals", 1.0)
	await RenderingServer.frame_post_draw
	var fallen := root.get_texture().get_image()
	fallen.save_png("/tmp/obra_trees_kapre_felled.png")
	fallen.convert(Image.FORMAT_RGBA8)
	fallen.resize(800, 450, Image.INTERPOLATE_NEAREST)
	sheet.blit_rect(fallen, Rect2i(Vector2i.ZERO, fallen.get_size()), Vector2i(0, 1350))
	await _put_her(21750.0)
	while not dead.is_open():
		dead.apply_tool_hit("axe", 420.0, level.get("player") as Node2D)
	level.call("_apply_dawn_visuals", 1.0)
	await RenderingServer.frame_post_draw
	fallen = root.get_texture().get_image()
	fallen.save_png("/tmp/obra_trees_clearing_felled.png")
	fallen.convert(Image.FORMAT_RGBA8)
	fallen.resize(800, 450, Image.INTERPOLATE_NEAREST)
	sheet.blit_rect(fallen, Rect2i(Vector2i.ZERO, fallen.get_size()), Vector2i(800, 1350))
	sheet.save_png("/tmp/obra_trees_review.png")
	print("OBRA_DILIM_TREES_VISUAL_OK")
	quit(0)
