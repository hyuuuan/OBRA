extends SceneTree
## Mayon's Act One, played: the ash takes the old bridge before she can reach it and the steps
## before she is at the wall; it thickens as she climbs and is gone at the summit; the eruption
## rumbles and the ash surges with it, and never at the summit; lolo forgets three times, once
## each; the apo works out why it is all going white, once each; a fall gives back what the ash
## had not yet taken.
##
##   godot --headless --path game --script res://tests/run_level5_act_one_probe.gd

## Every check this probe makes. A script error that skips them must not pass as quiet.
const CHECKS := 6
## The apo's running speed (Wanderer), to time the bridge against.
const RUN := 260.0

var failures := 0
var checked := 0
var level: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	level = await _open_level()
	await _a_fall_gives_back_what_the_ash_had_not_taken()
	await _the_bridge_is_gone_before_she_can_reach_it()
	_the_ash_thickens_as_she_climbs()
	await _the_eruption_rumbles_and_the_ash_surges()
	await _lolo_forgets_three_times_once_each()
	await _she_works_out_why_it_is_going_white()
	if checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_LEVEL5_ACT_ONE_OK")
		quit(0)
	else:
		print("OBRA_LEVEL5_ACT_ONE_FAILED=%d" % failures)
		quit(1)


func _taken(name: String) -> Drainable:
	return level.get_node("EnvironmentBaseplate/GameplayPlane/AshTakes/%s/Drainable" % name) as Drainable


func _a_fall_gives_back_what_the_ash_had_not_taken() -> void:
	await _put(400.0, 400.0)
	level.call("_write_checkpoint", "CP1")
	await _put(3400.0, 200.0)
	await create_timer(3.0).timeout
	var taken_then := _taken("OldBridge").is_blank() and _taken("OldSteps").is_blank()
	level.call("_restore_checkpoint")
	await _frames(4)
	_check(taken_then and is_zero_approx(_taken("OldBridge").drain) and is_zero_approx(_taken("OldSteps").drain),
		"a fall back to a checkpoint below them gives back what the ash had not taken by then",
		"taken on the way up %s; after the fall bridge %.2f, steps %.2f" % [taken_then,
			_taken("OldBridge").drain, _taken("OldSteps").drain])


func _the_bridge_is_gone_before_she_can_reach_it() -> void:
	var bridge := level.get_node("EnvironmentBaseplate/GameplayPlane/AshTakes/OldBridge") as Node2D
	var at := float(bridge.get_meta("taken_at"))
	var over := float(bridge.get_meta("taken_over"))
	var soonest := (2290.0 - at) / RUN
	await _put(at + 10.0, 400.0)
	await create_timer(over + 0.4).timeout
	_check(_taken("OldBridge").is_blank() and over < soonest,
		"the old bridge goes white and blank before she can reach it",
		"blank after %.1f s; at a run she needs %.1f s to get there" % [over, soonest])


func _the_ash_thickens_as_she_climbs() -> void:
	var foot: float = level.call("ash_at", 500.0)
	var slope: float = level.call("ash_at", 3000.0)
	var corridor: float = level.call("ash_at", 8000.0)
	var summit: float = level.call("ash_at", 14000.0)
	_check(foot < slope and slope < corridor and is_zero_approx(summit),
		"the ash thickens as she climbs and is gone at the summit",
		"foot %.1f, slope %.1f, corridor %.1f, summit %.1f" % [foot, slope, corridor, summit])


func _the_eruption_rumbles_and_the_ash_surges() -> void:
	var tremor := level.get_node("Eruption") as ScreenTremor
	var ash := level.get_node("EnvironmentBaseplate/WorldCamera/Ash") as AshFall2D
	tremor.tremble(1.0)
	await _frames(2)
	var surged := ash.pulse_left() > 0.0
	await _put(14000.0, -400.0)
	_check(surged and not tremor.enabled,
		"the eruption rumbles and the ash surges with it, and the summit is still",
		"surged %s, rumbling at the summit %s" % [surged, tremor.enabled])


func _lolo_forgets_three_times_once_each() -> void:
	level.set("_forgot", 0)
	var counts: Array[int] = []
	for x: float in [1100.0, 3000.0, 4800.0, 1100.0]:
		await _put(x, 0.0)
		counts.append(int(level.get("_forgot")))
	_check(counts == [1, 2, 3, 3], "lolo forgets three times on the way up, in order, once each",
		"after each stop: %s" % [counts])


## Kent, 2026-11-01: "the apo should have dialogue on why everything is disappearing". Once the
## first thing has gone white, once she has heard him lose a word, and in the corridor among every
## painting of hers: once each, in order, and never before she has seen it happen.
func _she_works_out_why_it_is_going_white() -> void:
	# On a mountain of its own: a line once heard stays heard, and the checks above walked her past
	# every place these are said (and walking up first would take the bridge before theirs).
	level.queue_free()
	await _frames(2)
	level = await _open_level()
	var lines: Object = level.get("script_lines")
	var heard: Array[String] = []
	for x: float in [1700.0, 2200.0, 3600.0, 5500.0, 2200.0]:
		await _put(x, 0.0)
		var now := "%d%d%d" % [int(lines.call("has_heard", "APO.why.1")), int(lines.call("has_heard", "APO.why.2")),
			int(lines.call("has_heard", "APO.why.3"))]
		heard.append("%s/%d" % [now, int(level.get("_wondered"))])
	_check(heard == ["000/0", "100/1", "110/2", "111/2", "111/2"],
		"the apo works out why it is going white, in order, once each",
		"after each stop (why 1,2,3 / counted): %s" % [heard])


func _put(x: float, y: float) -> void:
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": Vector2(x, y), "linear_velocity": Vector2.ZERO})
	await _frames(30)
	call_group(DialogueBox.GROUP, &"hide_line")
	paused = false


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
