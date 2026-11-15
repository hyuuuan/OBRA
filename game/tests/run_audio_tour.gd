extends SceneTree
## LISTENING TO THE GAME, headless: a tour through every place's music and its changes, recorded off
## the Master bus as the game mixes it (the dummy driver mixes in real time), with a mark at every
## event. ⚠ AudioEffectCapture, pulled every frame into a 5 s buffer, NOT AudioEffectRecord: the
## recorder drains its ring on a thread of its own, and under a scene's load it lost stretches and
## filled them with silence -- a 3 s "gap" that was never mixed. The capture counts what it had to
## throw away, and the tour says so. Kent (2026-11-15): "you listen it yourself since it feels so weird like the
## transitioning of different music and then the buttons". Claude cannot hear, so this is how a
## change of music, a click or a jingle is checked: tools/audio_lab/tour.py measures the recording
## around each mark, and an MP3 of it goes to Kent.
##
## A diagnostic, not a pass/fail probe: it is deliberately not in tools/run_suites.sh.
##
##   godot --headless --path game --script res://tests/run_audio_tour.gd [-- only=menu,dagat]
##   .venv/bin/python tools/audio_lab/tour.py build/capture/tour.wav
##
## The scenes change through LevelManager, as a player's do; a level's music moments (the church,
## the dive, the race, the night, the memories, the summit) are driven through its own handlers.

const OUT_WAV := "res://../build/capture/tour.wav"
const OUT_MARKS := "res://../build/capture/tour.json"
const STOPS := ["menu", "house", "terraces", "piyesta", "dagat", "dilim", "mayon"]

var director: Node
var manager: Node
var capture: AudioEffectCapture
var frames := PackedVector2Array()
var started_ms := 0
var marks: Array = []
var only: Array[String] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only.assign(arg.trim_prefix("only=").split(","))
	# ⚠ Before _ready: a level's recogniser must not be launched by a tour.
	node_added.connect(func(node: Node) -> void:
		if node is BackendSupervisor:
			(node as BackendSupervisor).auto_start_backend = false)
	call_deferred("_run")


func _run() -> void:
	director = root.get_node(^"AudioDirector")
	manager = root.get_node(^"LevelManager")
	capture = AudioEffectCapture.new()
	capture.buffer_length = 5.0
	AudioServer.add_bus_effect(0, capture)
	capture.clear_buffer()
	started_ms = Time.get_ticks_msec()
	for stop: String in STOPS:
		if only.is_empty() or stop in only:
			await call(&"_tour_" + stop)
	await _wait(2.0)
	_drain()
	_mark("end")
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = true
	wav.mix_rate = int(AudioServer.get_mix_rate())
	var bytes := PackedByteArray()
	bytes.resize(frames.size() * 4)
	for i in range(frames.size()):
		bytes.encode_s16(i * 4, int(clampf(frames[i].x, -1.0, 1.0) * 32767.0))
		bytes.encode_s16(i * 4 + 2, int(clampf(frames[i].y, -1.0, 1.0) * 32767.0))
	wav.data = bytes
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../build/capture"))
	wav.save_to_wav(ProjectSettings.globalize_path(OUT_WAV))
	print("OBRA_AUDIO_TOUR discarded %d frames" % capture.get_discarded_frames())
	var file := FileAccess.open(ProjectSettings.globalize_path(OUT_MARKS), FileAccess.WRITE)
	file.store_string(JSON.stringify({"marks": marks, "mix_rate": AudioServer.get_mix_rate()}, "  "))
	file.close()
	print("OBRA_AUDIO_TOUR wrote %.1f s, %d marks" % [wav.get_length(), marks.size()])
	quit(0)


# --- the stops ---------------------------------------------------------------------------------

func _tour_menu() -> void:
	await _go(LevelManager.SELECTOR_SCENE, "", "the menu")
	await _wait(6.0)
	var menu := current_scene
	_mark("click: Settings")
	(menu.get(&"settings_button") as Button).pressed.emit()
	await _wait(1.5)
	_mark("close Settings")
	_close_overlays()
	await _wait(1.5)
	_mark("click: Controls")
	(menu.get(&"controls_button") as Button).pressed.emit()
	await _wait(1.2)
	_close_overlays()
	await _wait(2.0)


func _tour_house() -> void:
	_mark("to the house")
	manager.call(&"open_house")
	await _until_scene("hub.tscn")
	_mark("the house")
	await _wait(8.0)


func _tour_terraces() -> void:
	await _level("level_1", "Terraces")
	await _wait(8.0)
	var level := current_scene
	_mark("click: the brush (draw panel)")
	var draw := level.get(&"draw_button") as Button
	if draw != null:
		draw.pressed.emit()
	await _wait(1.5)
	var panel := level.get(&"draw_panel") as Node
	if panel != null and panel.has_method(&"close"):
		_mark("close the draw panel")
		panel.call(&"close")
	paused = false
	await _wait(2.0)
	_mark("jingle: level complete")
	director.call(&"play_sfx", &"level_complete")
	await _wait(5.0)
	await _home()


func _tour_piyesta() -> void:
	await _level("level_2", "Piyesta")
	await _wait(8.0)
	var level := current_scene
	_mark("into the church")
	level.call(&"_enter_room", level.get(&"church"), (level.get(&"player") as Node2D).global_position)
	await _wait(7.0)
	_mark("out of the church")
	level.call(&"_leave_room", level.get(&"church"))
	await _wait(6.0)
	_mark("the dance begins")
	level.call(&"_on_route_committed_here", "L2_N1", "artist")
	await _wait(8.0)
	_mark("the dance ends")
	var overlay := level.get(&"dance_screen") as Node
	if overlay != null and overlay.has_method(&"close"):
		overlay.call(&"close")
	level.call(&"_on_dance_screen_finished", true, true)
	await _wait(6.0)
	await _home()


func _tour_dagat() -> void:
	await _level("level_3", "Dagat")
	await _wait(8.0)
	var level := current_scene
	level.set_physics_process(false)
	var line := float(level.get(&"_waterline_y"))
	var x := (level.get(&"player") as Node2D).global_position.x
	_mark("dive")
	level.call(&"_refresh_the_place_audio", Vector2(x, line + 200.0))
	await _wait(8.0)
	_mark("surface")
	level.call(&"_refresh_the_place_audio", Vector2(x, line - 40.0))
	await _wait(6.0)
	_mark("the Bakunawa met")
	level.call(&"_on_obstacle_entered", "L3_N2")
	level.call(&"_refresh_the_place_audio", Vector2(x, line - 40.0))
	await _wait(9.0)
	_mark("the Bakunawa answered")
	(level.get(&"director") as Node).call(&"solve_with_item", "L3_N2", "the dark")
	level.call(&"_refresh_the_place_audio", Vector2(x, line - 40.0))
	await _wait(6.0)
	level.set_physics_process(true)
	await _home()


func _tour_dilim() -> void:
	await _level("level_4", "Dilim")
	await _wait(10.0)
	var level := current_scene
	var tikbalang := level.get(&"_tikbalang") as Node
	_mark("the race")
	tikbalang.call(&"start_race")
	await _wait(9.0)
	_mark("the race lost")
	tikbalang.call(&"_end_race", false)
	await _wait(7.0)
	var finale := level.get(&"_finale") as Node
	_mark("the night begins")
	finale.call(&"_begin")
	await _wait(8.0)
	for wave: int in [1, 2]:
		_mark("night wave %d" % (wave + 1))
		finale.set(&"elapsed", float((finale.get(&"WAVES") as Array)[wave]["at"]))
		finale.call(&"_open_waves")
		await _wait(7.0)
	_mark("dawn")
	level.call(&"_on_dawn")
	await _wait(5.0)
	await _home()


func _tour_mayon() -> void:
	await _level("level_5", "Mayon")
	await _wait(9.0)
	var level := current_scene
	level.set_physics_process(false)
	level.set(&"_phase", "memories")
	for vignette: String in ["payyo_terraces", "piyesta_plaza", "dagat_sea", "dilim_forest"]:
		_mark("memory: " + vignette)
		level.set(&"_active_cluster", vignette)
		level.call(&"_refresh_the_place_audio")
		await _wait(7.0)
	_mark("Lolo vanishes")
	level.call(&"_vanish_lolo")
	await _wait(3.0)
	_mark("Lola found")
	level.set(&"_summit", "quiet")
	level.call(&"_refresh_the_place_audio")
	await _wait(9.0)
	_mark("the bloom")
	level.set(&"_summit", "blooming")
	level.call(&"_refresh_the_place_audio")
	await _wait(8.0)


# --- helpers -----------------------------------------------------------------------------------

func _process(_delta: float) -> bool:
	_drain()
	return false


func _drain() -> void:
	if capture != null and capture.get_frames_available() > 0:
		frames.append_array(capture.get_buffer(capture.get_frames_available()))

func _level(level_id: String, label: String) -> void:
	_mark("to " + label)
	var path := String((manager.call(&"get_level", level_id) as Dictionary).get("scene_path", ""))
	manager.call(&"_queue_transition", path, level_id)
	await _until_scene(path.get_file())
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	_mark(label)


func _home() -> void:
	_mark("back to the house")
	paused = false
	manager.call(&"return_to_house")
	await _until_scene("hub.tscn")
	_mark("the house")
	await _wait(5.0)


func _go(path: String, level_id: String, label: String) -> void:
	manager.call(&"_queue_transition", path, level_id)
	await _until_scene(path.get_file())
	_mark(label)


func _close_overlays() -> void:
	for node in root.find_children("*", "", true, false):
		if is_instance_valid(node) and node is ModalOverlay and bool(node.get(&"visible")):
			node.call(&"close")


func _until_scene(file: String) -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		if current_scene != null and current_scene.scene_file_path.get_file() == file \
				and not bool(manager.call(&"is_transitioning")):
			return
		await process_frame
	print("tour: never reached ", file)


## A mark's time is the capture's own clock: the frames taken so far.
func _mark(label: String) -> void:
	_drain()
	var at := frames.size() / AudioServer.get_mix_rate()
	marks.append({"t": at, "label": label, "music": String(director.call(&"current_music")),
		"ambience": String(director.call(&"current_ambience"))})
	print("MARK %7.2f  %s  [%s / %s]" % [at, label, director.call(&"current_music"), director.call(&"current_ambience")])


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout
