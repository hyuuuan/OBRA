extends SceneTree
## Mayon's summit, played: the world goes white and still; the brush refuses her twice -- raised
## by itself if she does not -- and the third time she lowers it; the page opens for the places
## and whatever she draws blooms what she saved; her voice is the run's leaning and the ending is
## the flowers'; lola turns around and the level is finished.
##
##   godot --headless --path game --script res://tests/run_level5_summit_probe.gd

## Every check this probe makes. A script error that skips them must not pass as quiet.
const CHECKS := 8

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
	preload("res://tests/level5_journey_fixture.gd").summit(level)
	_the_voice_and_the_ending_are_the_runs()
	await _the_summit_waits_for_lolo_to_go()
	await _the_summit_goes_white_and_still()
	await _walked_up_to_lola_she_stands_and_the_brush_key_stays()
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
	await _put(21810.0, 98.0)
	var held: String = level.call("summit_state")
	lolo.vanish()
	level.set("_lolo_moment", "gone")
	await _frames(4)
	_check(held == "" and level.call("summit_state") == "quiet",
		"the summit waits until lolo has gone",
		"while he waits: '%s'; once gone: '%s'" % [held, level.call("summit_state")])


func _the_summit_goes_white_and_still() -> void:
	await _put(21810.0, 98.0)
	await create_timer(5.0).timeout
	var sky := level.get_node("EnvironmentBaseplate/SkyBand/Drainable") as Drainable
	var tremor := level.get_node("Eruption") as ScreenTremor
	_check(sky != null and sky.drain >= 0.8 and not sky.is_blank() and not tremor.enabled
		and level.call("summit_state") == "quiet",
		"at the summit the world goes white and still",
		"sky %.2f, rumbling %s, %s" % [sky.drain if sky != null else -1.0, tremor.enabled, level.call("summit_state")])


## Kent, 2026-11-05: "when i approach lola the game freezes". She is stopped in front of Lola for
## the beat, and her pose comes from her physics: she hung mid-stride or mid-jump, with every key
## gone, for the seconds before the brush raised itself. Walked up with the keys, jumping as she
## arrives, she stands, and Draw is still on screen.
func _walked_up_to_lola_she_stands_and_the_brush_key_stays() -> void:
	var player := level.get("player") as Node2D
	var speak_x: float = (level.call("_anchor", "summit_speak") as Vector2).x
	# The check above stood lolo at "waiting" by hand, which raises a page at once; put it down.
	var page := level.get("draw_panel") as DrawPanel
	if page.is_open():
		page.close_panel()
	await _frames(2)
	Input.action_press("move_right")
	var jumped := false
	var until := Time.get_ticks_msec() + 8000
	while String(level.call("summit_state")) == "quiet" and Time.get_ticks_msec() < until:
		if not jumped and player.global_position.x > speak_x - 90.0:
			Input.action_press("jump")
			jumped = true
		await physics_frame
	Input.action_release("move_right")
	Input.action_release("jump")
	call_group(DialogueBox.GROUP, &"hide_line")
	paused = false
	await _frames(12)
	var pose := String((player.get_node("Figure") as Node).get("pose"))
	var draw := level.get("draw_button") as Button
	var panel := level.get("draw_panel") as DrawPanel
	_check(String(level.call("summit_state")) == "trying" and jumped and pose == "idle"
			and draw.is_visible_in_tree() and not panel.is_open(),
		"walked up to lola she stands still in front of her, and the brush's key stays on screen",
		"%s, jumped on arrival %s, her pose %s, draw key shown %s, page open %s" % [
			level.call("summit_state"), jumped, pose, draw.is_visible_in_tree(), panel.is_open()])


func _the_brush_refuses_her_twice_then_she_lowers_it() -> void:
	await _put(22110.0, 98.0)
	var panel := level.get("draw_panel") as DrawPanel
	var refused := 0
	for attempt in range(2):
		level.set("_raise_left", 0.05)
		var raised := await _until(func() -> bool: return panel.is_open() and panel.is_refusing(), 4.0)
		if raised:
			_ink_stroke(panel)
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
	_ink_stroke(panel)
	panel.call("_on_transform_pressed")
	var bloomed := await _until(func() -> bool: return int(level.call("bloomed")) == 2, 6.0)
	_check(opened and bloomed, "the page opens for the places, and what she draws blooms what she saved",
		"page opened by itself %s, bloomed %d" % [opened, level.call("bloomed")])


func _lola_turns_and_the_level_is_finished() -> void:
	var profile := root.get_node("PlayerProfile")
	var lola := level.get_node("EnvironmentBaseplate/GameplayPlane/Lola") as Lola2D
	var turned := [false]
	# Her last page, at her easel: seen open, after she turned, before the level is over.
	var page := [false, false, false]
	var diary := level.get("diary_overlay") as DiaryOverlay
	var finished := await _until(func() -> bool:
		if is_instance_valid(lola) and (lola.is_turned() or lola.has_flowers()):
			turned[0] = true
		if not page[0] and diary.is_open() and diary.book().entry_on_show() == "mayon":
			page[0] = true
			page[1] = turned[0]
			page[2] = not bool(profile.call("is_level_completed", "level_5"))
		return bool(profile.call("is_level_completed", "level_5")), 30.0)
	_check(turned[0] and finished, "lola turns around, and the level is finished",
		"turned %s, finished %s" % [turned[0], finished])
	_check(page[0] and page[1] and page[2] and bool(profile.call("has_diary_page", "mayon")),
		"her last page is found at her easel, after she turns and before it ends",
		"open %s, after she turned %s, before the end %s" % [page[0], page[1], page[2]])


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


func _ink_stroke(panel: DrawPanel) -> void:
	var middle := panel.canvas.size * 0.5
	panel.canvas.call("_start_stroke", middle - Vector2(50, 0))
	panel.canvas.call("_append_point", middle + Vector2(50, 0), true)
