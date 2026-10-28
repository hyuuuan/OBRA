extends SceneTree
## Mayon's summit, played: the world goes white and still; the brush refuses her twice -- raised
## by itself if she does not -- and the third time she lowers it; the page opens for the places
## and whatever she draws blooms what she saved; her voice is the run's leaning and the ending is
## the flowers'; lola turns around and the level is finished.
##
##   godot --headless --path game --script res://tests/run_level5_summit_probe.gd

## Every check this probe makes. A script error that skips them must not pass as quiet.
const CHECKS := 6

var failures := 0
var checked := 0
var level: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	level = await _open_level()
	# Lolo has gone by the time she reaches the top, as he must have.
	(level.get("lolo") as Lolo).vanish()
	level.set("_lolo_moment", "gone")
	_the_voice_and_the_ending_are_the_runs()
	await _the_summit_waits_for_lolo_to_go()
	await _the_summit_goes_white_and_still()
	await _the_brush_refuses_her_twice_then_she_lowers_it()
	await _she_draws_the_places_and_they_bloom()
	await _lola_turns_and_the_level_is_finished()
	if checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_LEVEL5_SUMMIT_OK")
		quit(0)
	else:
		print("OBRA_LEVEL5_SUMMIT_FAILED=%d" % failures)
		quit(1)


func _the_voice_and_the_ending_are_the_runs() -> void:
	var profile := root.get_node("PlayerProfile")
	profile.call("reset_progress")
	var nobody: String = level.call("voice_hook")
	for route in ["protector", "artist", "protector"]:
		profile.call("record_route", "level_1", route)
	var leaned: String = level.call("voice_hook")
	for id: String in ["flower_1", "L2_HF", "L3_HF", "L4_HF"]:
		profile.call("record_collectible", id)
	var four: String = level.call("ending_hook")
	profile.call("record_collectible", "L5_HF")
	var five: String = level.call("ending_hook")
	_check(nobody == "SUMMIT.voice.artist" and leaned == "SUMMIT.voice.protector"
		and four == "ENDING.standard" and five == "ENDING.perfect",
		"her voice is the run's leaning, and five flowers are the perfect ending",
		"nobody %s, leaned %s; four flowers %s, five %s" % [nobody, leaned, four, five])


func _the_summit_waits_for_lolo_to_go() -> void:
	# Lolo not yet gone: the summit holds still until he is.
	var lolo := level.get("lolo") as Lolo
	level.set("_lolo_moment", "waiting")
	lolo.set("_vanished", false)
	await _put(14500.0, -400.0)
	var held: String = level.call("summit_state")
	lolo.vanish()
	level.set("_lolo_moment", "gone")
	await _frames(4)
	_check(held == "" and level.call("summit_state") == "quiet",
		"the summit waits until lolo has gone",
		"while he waits: '%s'; once gone: '%s'" % [held, level.call("summit_state")])


func _the_summit_goes_white_and_still() -> void:
	await _put(14500.0, -400.0)
	await create_timer(5.0).timeout
	var sky := level.get_node("EnvironmentBaseplate/SkyBand/Drainable") as Drainable
	var tremor := level.get_node("Eruption") as ScreenTremor
	_check(sky != null and sky.drain >= 0.8 and not sky.is_blank() and not tremor.enabled
		and level.call("summit_state") == "quiet",
		"at the summit the world goes white and still",
		"sky %.2f, rumbling %s, %s" % [sky.drain if sky != null else -1.0, tremor.enabled, level.call("summit_state")])


func _the_brush_refuses_her_twice_then_she_lowers_it() -> void:
	await _put(15000.0, -400.0)
	var panel := level.get("draw_panel") as DrawPanel
	var refused := 0
	for attempt in range(2):
		level.set("_raise_left", 0.05)
		var raised := await _until(func() -> bool: return panel.is_open() and panel.is_refusing(), 4.0)
		if raised:
			panel.call("_on_transform_pressed")
			await _until(func() -> bool: return not panel.is_open(), 4.0)
			refused += 1
	var lola := level.get_node("EnvironmentBaseplate/GameplayPlane/Lola") as Lola2D
	_check(refused == 2 and level.call("summit_state") == "lowering" and not lola.is_turned(),
		"the brush refuses her twice, raised by itself, and the third time she lowers it",
		"refused %d, %s, lola turned %s" % [refused, level.call("summit_state"), lola.is_turned()])


func _she_draws_the_places_and_they_bloom() -> void:
	for id in ["kubo", "church"]:
		var fragment := level.call("_fragment", id) as MemoryFragment2D
		fragment.restore_to("saved", [[0.0, 0.0, 30.0, 30.0]])
	var panel := level.get("draw_panel") as DrawPanel
	var opened := await _until(func() -> bool: return panel.is_open() and panel.is_refusing(), 6.0)
	panel.call("_on_transform_pressed")
	var bloomed := await _until(func() -> bool: return int(level.call("bloomed")) == 2, 6.0)
	_check(opened and bloomed, "the page opens for the places, and what she draws blooms what she saved",
		"page opened by itself %s, bloomed %d" % [opened, level.call("bloomed")])


func _lola_turns_and_the_level_is_finished() -> void:
	var profile := root.get_node("PlayerProfile")
	var lola := level.get_node("EnvironmentBaseplate/GameplayPlane/Lola") as Lola2D
	var turned := [false]
	var finished := await _until(func() -> bool:
		if is_instance_valid(lola) and lola.is_turned():
			turned[0] = true
		return bool(profile.call("is_level_completed", "level_5")), 30.0)
	_check(turned[0] and finished, "lola turns around, and the level is finished",
		"turned %s, finished %s" % [turned[0], finished])


func _put(x: float, y: float) -> void:
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": Vector2(x, y), "linear_velocity": Vector2.ZERO})
	await _frames(30)
	call_group(DialogueBox.GROUP, &"hide_line")
	paused = false


func _until(done: Callable, seconds: float) -> bool:
	var left := seconds
	while left > 0.0:
		if done.call():
			return true
		call_group(DialogueBox.GROUP, &"hide_line")
		await create_timer(0.1).timeout
		left -= 0.1
	return bool(done.call())


func _open_level() -> Node:
	var scene := (load("res://level_5.tscn") as PackedScene).instantiate()
	(scene.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(scene)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(40):
		await physics_frame
	call_group(DialogueBox.GROUP, &"hide_line")
	paused = false
	await _frames(4)
	return scene


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
