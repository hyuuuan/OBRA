extends "res://tests/run_visual_dilim_creatures.gd"
## Windowed review of intact foliage and clear encounter art.
## open -n -a Godot --args --path game --script res://tests/run_visual_moonlit_foliage.gd
## Writes /tmp/obra_moonlit_<foliage|nuno|fork|aswang>.png; exits on an invalid capture premise.


func _run() -> void:
	level = (load("res://level_4.tscn") as PackedScene).instantiate()
	level.get_node("BackendSupervisor").auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(40)
	for spot: Dictionary in [{"at": 260.0, "name": "start"}, {"at": 1580.0, "name": "forest"}]:
		await _put_her(float(spot["at"]))
		await _frames(50)
		(await _capture()).save_png("/tmp/obra_moonlit_background_%s.png" % spot["name"])
	var bushes := level.get_node("EnvironmentBaseplate/GameplayPlane/BackgroundBushes")
	var chosen: Sprite2D
	for bush in bushes.get_children():
		if bush is Sprite2D and bush.global_position.x > 10000 and bush.global_position.x < 13000:
			chosen = bush
			if bush.texture.resource_path.ends_with("plant_2.png"):
				break
	if chosen == null:
		push_error("HARNESS FAULT: no quiet-path bush to photograph")
		quit(1)
		return
	await _put_her(chosen.global_position.x + chosen.texture.get_width() * 0.5 - 70)
	await _frames(50)
	(await _capture()).save_png("/tmp/obra_moonlit_foliage.png")
	await _put_her(3310)
	await _frames(50)
	(await _capture()).save_png("/tmp/obra_moonlit_nuno.png")
	await _put_her(8750)
	await _frames(50)
	(await _capture()).save_png("/tmp/obra_moonlit_fork.png")
	for spot: Dictionary in [
		{"at": 16980.0, "y": 526.0, "name": "tiyanak_path"},
		{"at": 19000.0, "y": 396.0, "name": "high_path"},
		{"at": 20820.0, "name": "hollow_shelf"}]:
		await _put_her(float(spot["at"]))
		if spot.has("y"):
			(level.get("player") as Node2D).call("apply_morph_state", {
				"position": Vector2(float(spot["at"]), float(spot["y"])),
				"linear_velocity": Vector2.ZERO})
		await _frames(50)
		if spot.has("y") and absf((level.get("player") as Node2D).global_position.y - float(spot["y"]) - 4.0) > 2.0:
			push_error("HARNESS FAULT: player did not land on %s" % spot["name"])
			quit(1)
			return
		(await _capture()).save_png("/tmp/obra_moonlit_%s.png" % spot["name"])
	await _put_her(21750)
	var crawler := _send("aswang_pig", Vector2(125, 0))
	var lady := _send("aswang_dog", Vector2(-130, 0))
	await _frames(50)
	(await _capture()).save_png("/tmp/obra_moonlit_aswang.png")
	crawler.queue_free()
	lady.queue_free()
	print("OBRA_MOONLIT_VISUAL_OK")
	quit(0)
