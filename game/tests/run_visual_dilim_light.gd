extends SceneTree
## Look at the dark: Payyo told it is dark, captured at each lantern stage.
##
##   godot -t --path game --script res://tests/run_visual_dilim_light.gd
##
## Windowed (headless draws nothing). Writes /tmp/obra_light_<stage>.png and
## /tmp/obra_light_sheet.png, the four side by side, for a person to look at -- run_darkness_probe
## is what checks the numbers.

var level: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var dark := GDScript.new()
	dark.source_code = "extends \"res://scripts/game_level.gd\"\n" \
		+ "func _darkness() -> float:\n\treturn 0.9\n" \
		+ "func _has_player_health() -> bool:\n\treturn true\n"
	dark.reload()
	level = (load("res://game_level.tscn") as PackedScene).instantiate()
	level.set_script(dark)
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.5)
	call_group(DialogueBox.GROUP, &"hide_line")
	paused = false
	var health := level.get("player_health") as PlayerHealth
	health.invulnerable_seconds = 0.0
	var shots: Array[Image] = []
	for stage in ["full", "dim", "low", "guttering"]:
		await _wait(0.4)
		shots.append(await _capture(stage))
		health.take_hit()
	var sheet := Image.create(shots[0].get_width() * 2, shots[0].get_height() * 2, false,
		Image.FORMAT_RGBA8)
	for index in range(shots.size()):
		var shot := shots[index]
		shot.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()),
			Vector2i((index % 2) * shot.get_width(), (index / 2) * shot.get_height()))
	sheet.save_png("/tmp/obra_light_sheet.png")
	print("OBRA_LIGHT_SHOTS_DONE")
	quit(0)


func _capture(label: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("/tmp/obra_light_%s.png" % label)
	return image


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout
