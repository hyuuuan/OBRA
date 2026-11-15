extends SceneTree
## Windowed: Dilim's morning clock through the night, from crescent to sun, cropped and doubled.
## Writes /tmp/obra_dawn_clock.png. The reviewed sheet is docs/screenshots/dilim_morning_clock.png.
##
##   godot -t --path game --resolution 1600x900 --script res://tests/run_visual_level4_clock.gd

const OUT := "/tmp/obra_dawn_clock.png"
const SECONDS := [0.0, 13.0, 27.0, 45.0, 60.0, 72.0, 84.0, 90.0]
const COLUMNS := 2
const ZOOM := 2

var level: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(100.0).timeout.connect(func() -> void:
		push_error("HARNESS FAULT: no frame drawn in time")
		quit(2))
	level = (load("res://level_4.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(40)
	(level.get("player_health") as PlayerHealth).call("_start_grace", 600.0)
	(level.get("player") as Node2D).call("apply_morph_state",
		{"position": Vector2(21700.0, 596.0), "linear_velocity": Vector2.ZERO})
	await _frames(40)
	var finale := level.get("_finale") as DilimFinale2D
	var clock := level.get("dawn_clock") as DawnClockHud
	if not finale.is_running() or not clock.visible:
		push_error("HARNESS FAULT: the night never started")
		quit(1)
		return
	finale.set_physics_process(false)
	for foe in finale.alive():
		foe.process_mode = Node.PROCESS_MODE_DISABLED
	var crop := Rect2i(Vector2i(clock.global_position) - Vector2i.ONE * 8,
		Vector2i(DawnClockHud.SIZE) + Vector2i.ONE * 16)
	var cell := crop.size * ZOOM
	var sheet := Image.create(cell.x * COLUMNS, cell.y * ceili(SECONDS.size() / float(COLUMNS)), false,
		Image.FORMAT_RGBA8)
	var index := 0
	for second: float in SECONDS:
		finale.elapsed = second
		if second >= DilimFinale2D.DAWN_SECONDS:
			clock.morning()
		await _frames(8)
		await RenderingServer.frame_post_draw
		# Frames come back at about 2.1x on a Retina Mac.
		var shot := root.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		shot.resize(1600, 900, Image.INTERPOLATE_NEAREST)
		var piece := shot.get_region(crop)
		piece.resize(cell.x, cell.y, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(piece, Rect2i(Vector2i.ZERO, cell), Vector2i((index % COLUMNS) * cell.x, (index / COLUMNS) * cell.y))
		index += 1
	sheet.save_png(OUT)
	print("OBRA_DAWN_CLOCK_VISUAL_OK")
	quit(0)


func _frames(count: int) -> void:
	for _i in range(count):
		await physics_frame
		if paused:
			call_group(DialogueBox.GROUP, &"hide_line")
			paused = false
