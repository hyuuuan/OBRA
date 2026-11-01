extends SceneTree
## Mayon's last shot is the house (DIARY.md; Kent, 2026-11-01): "Lolo. Let's go home." -- and she
## is home, where Lolo is in every painting and Lola is waiting. The first time, Lola takes the apo
## for him, asks where he is, and walks the length of the house to an empty easel at the far end;
## after that she is at her easel, and the paintings keep him. (It was the frame's return, a
## separate painted room; the name of this probe is the beat's, not the room's.)
##
##   godot --headless --path game --script res://tests/run_level5_frame_probe.gd

## Every check this probe makes. A script error that skips them must not pass as quiet.
const CHECKS := 7
const HUB := "res://levels/hub/hub.tscn"
## What is said in the house, and by whom, in order -- Kent's own words, near enough.
const LINES := [
	["lola", "Mahal! You look so young!"],
	["apo", "Lola, I'm your apo. I'm not Lolo."],
	["lola", "Where is he, then?"],
	["apo", "He's right here. In all your works."],
	["lola", "Oh."],
	["lola", "Who are you? Will you watch me paint?"],
]

var failures := 0
var checked := 0
var _played := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile := root.get_node("PlayerProfile")
	profile.call("reset_progress")
	await _mayon_says_lets_go_home_and_goes()
	profile.call("reset_progress")
	await _before_mayon_the_house_is_as_it_was()
	profile.call("mark_level_completed", "level_5")
	await _the_first_time_lola_mistakes_her_for_him(profile)
	await _after_that_she_is_at_her_easel(profile)
	profile.call("reset_progress")
	if failures == 0 and checked == CHECKS:
		print("OBRA_LEVEL5_FRAME_OK")
		quit(0)
	else:
		if checked != CHECKS:
			print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
		print("OBRA_LEVEL5_FRAME_FAILED=%d" % maxi(1, failures))
		quit(1)


func _mayon_says_lets_go_home_and_goes() -> void:
	var level := await _open_level()
	level.call("_play_own_ending")
	var home := await _until(func() -> bool: return not is_instance_valid(level) or bool(level.call("went_home")), 10.0)
	var said := is_instance_valid(level) and bool((level.get("script_lines") as Object).call("has_heard", "APO.home"))
	_check(home and said, "Mayon ends on \"Lolo. Let's go home.\" and goes home",
		"said %s, home %s" % [said, home])
	# The house it asked for is the current scene now; the checks below open their own.
	await _frames(30)
	if is_instance_valid(level):
		level.queue_free()
	if current_scene != null:
		current_scene.queue_free()
	await _frames(4)


func _before_mayon_the_house_is_as_it_was() -> void:
	var hub := await _open_hub()
	var plain := true
	for painting in _paintings(hub):
		plain = plain and not String((painting.get("art") as Texture2D).resource_path).ends_with("_lolo.png")
	_check(hub.call("epilogue") == null and plain and hub.find_child("Lola", true, false) == null,
		"before Mayon is finished the house is as it was: no Lola, no Lolo in the paintings",
		"epilogue %s, paintings plain %s" % [hub.call("epilogue") != null, plain])
	hub.queue_free()
	await _frames(4)


func _the_first_time_lola_mistakes_her_for_him(profile: Node) -> void:
	var hub := await _open_hub(false)
	var epilogue := hub.call("epilogue") as HouseEpilogue
	var lolo := 0
	for painting in _paintings(hub):
		if String((painting.get("art") as Texture2D).resource_path).ends_with("_lolo.png"):
			lolo += 1
	var apo := hub.get_node("Apo") as Node2D
	var lola := epilogue.lola if epilogue != null else null
	var held := bool(hub.call("is_revealing"))
	epilogue.finished.connect(_on_played)
	var done := await _until(func() -> bool: return _played, 40.0)
	# Waiting beside her and facing her as she speaks -- read off the first line as it was said: an
	# unattended run drops the lines at once, and by the next frame she is walking.
	var waiting := done and not epilogue.said.is_empty() and bool(epilogue.said[0]["facing"]) \
		and float(epilogue.said[0]["x"]) > apo.global_position.x
	_check(epilogue != null and lolo == 5 and waiting and held,
		"after Mayon Lolo is in all five paintings, and Lola is waiting beside her, facing her",
		"%d of 5 paintings, lola waiting %s, apo held %s" % [lolo, waiting, held])
	var lines: Array = []
	for entry: Dictionary in epilogue.said:
		lines.append([String(entry["speaker"]), String(entry["text"])])
	_check(done and lines == LINES, "she takes her for him, asks where he is, and is told: in all her works",
		"said %s" % [lines])
	var easel := epilogue.easel.global_position.x
	var at_easel := absf(lola.global_position.x - (easel - HouseEpilogue.AT_EASEL)) < 1.0
	var far := easel < float((_paintings(hub)[0] as Node2D).global_position.x)
	var last_there := epilogue.said.size() == LINES.size() \
		and absf(float(epilogue.said[-1]["x"]) - lola.global_position.x) < 1.0 \
		and float(epilogue.said[0]["x"]) > apo.global_position.x
	_check(done and at_easel and far and last_there,
		"then she walks the length of the house to an empty easel, and asks there who she is",
		"at the easel %s, at the far end %s, last line said there %s" % [at_easel, far, last_there])
	_check(done and not bool(hub.call("is_revealing")) and int(profile.call("dialogue_heard_count", "house_epilogue")) == 1,
		"and the house is hers again, and it is remembered",
		"held %s, heard %d" % [hub.call("is_revealing"), int(profile.call("dialogue_heard_count", "house_epilogue"))])
	hub.queue_free()
	await _frames(4)


func _after_that_she_is_at_her_easel(_profile: Node) -> void:
	var hub := await _open_hub(false)
	var epilogue := hub.call("epilogue") as HouseEpilogue
	await create_timer(2.0).timeout
	var lola := epilogue.lola
	var at_easel := absf(lola.global_position.x - (epilogue.easel.global_position.x - HouseEpilogue.AT_EASEL)) < 1.0
	var lolo := 0
	for painting in _paintings(hub):
		if String((painting.get("art") as Texture2D).resource_path).ends_with("_lolo.png"):
			lolo += 1
	_check(epilogue.said.is_empty() and at_easel and not lola.is_turned() and lolo == 5
			and not bool(hub.call("is_revealing")),
		"after that she is at her easel, painting, and the paintings keep him",
		"said %d, at the easel %s, turned %s, %d paintings" % [epilogue.said.size(), at_easel,
			lola.is_turned(), lolo])
	hub.queue_free()
	await _frames(4)


func _on_played() -> void:
	_played = true


func _paintings(hub: Node) -> Array:
	return hub.get("_paintings")


func _open_hub(settle: bool = true) -> Node:
	var hub := (load(HUB) as PackedScene).instantiate()
	root.add_child(hub)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(10 if settle else 3)
	return hub


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
