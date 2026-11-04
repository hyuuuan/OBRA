extends SceneTree
## Mayon's Act One, played: the ash takes the old bridge before she can reach it and the steps
## before she is at the wall; it thickens as she climbs and is gone at the summit; the eruption
## rumbles and the ash surges with it, and never at the summit; lolo forgets three times, once
## each; the apo works out why it is all going white, once each; a fall gives back what the ash
## had not yet taken.
##
##   godot --headless --path game --script res://tests/run_level5_act_one_probe.gd

## Every check this probe makes. A script error that skips them must not pass as quiet.
const CHECKS := 7
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
	await _the_ink_card_waits_for_lolo_at_the_span()
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
	var corridor: float = level.call("ash_at", 4800.0)
	var summit: float = level.call("ash_at", 30000.0)
	_check(foot < slope and slope < corridor and is_zero_approx(summit),
		"the ash thickens as she climbs and is gone at the summit",
		"foot %.1f, slope %.1f, corridor %.1f, summit %.1f" % [foot, slope, corridor, summit])


func _the_eruption_rumbles_and_the_ash_surges() -> void:
	var tremor := level.get_node("Eruption") as ScreenTremor
	var ash := level.get_node("EnvironmentBaseplate/WorldCamera/Ash") as AshFall2D
	tremor.tremble(1.0)
	await _frames(2)
	var surged := ash.pulse_left() > 0.0
	await _put(21810.0, 98.0)
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
	for x: float in [1700.0, 2200.0, 3600.0, 6200.0, 2200.0]:
		await _put(x, 0.0)
		var now := "%d%d%d" % [int(lines.call("has_heard", "APO.why.1")), int(lines.call("has_heard", "APO.why.2")),
			int(lines.call("has_heard", "APO.why.3"))]
		heard.append("%s/%d" % [now, int(level.get("_wondered"))])
	_check(heard == ["000/0", "100/1", "110/2", "111/2", "111/2"],
		"the apo works out why it is going white, in order, once each",
		"after each stop (why 1,2,3 / counted): %s" % [heard])


## ONE THING AT A TIME, AT THE SPAN. The bridge there is most players' first unit of ink, and it
## solves the gate in the same frame: the lesson about the ink ("No ink comes back here") opened
## at once and Lolo's "There. Back where it was. Nearly." came up under it, the card over his
## words. With nobody pressing a key, the card must wait for him -- and still come after.
func _the_ink_card_waits_for_lolo_at_the_span() -> void:
	level.queue_free()
	await _frames(2)
	level = await _open_level()
	await _put(2200.0, 400.0)
	await create_timer(1.5).timeout
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", false)
	var spotlight := get_first_node_in_group(TutorialSpotlight.GROUP) as TutorialSpotlight
	var box := get_first_node_in_group(DialogueBox.GROUP) as DialogueBox
	# The bridge through the bag and the placement, as a drawn answer arrives.
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	level.call("_on_drawing_ready", "bridge", "Bridge", image, {"confidence": .95},
		[{"points": PackedVector2Array([Vector2(0, 0), Vector2(340, 0)]), "width": 6.0, "color": Color.BLACK}], 1.0)
	await process_frame
	level.call("_on_inventory_slot_pressed", int(level.call("_slot_holding", "bridge")))
	var placement := level.get("placement_controller") as PlacementController
	placement.set_process(false)
	for i in range(4):
		placement.update_target(Vector2(2450, 420))
		await physics_frame
	var placed := placement.confirm_placement()
	placement.set_process(true)
	var spoke := false
	var together := false
	for i in range(60):
		spoke = spoke or (box != null and box.is_open())
		together = together or (spotlight != null and spotlight.is_open() and box != null and box.is_open())
		await process_frame
	# She reads his line; the lesson still comes, after it.
	call_group(DialogueBox.GROUP, &"hide_line")
	var taught := false
	var until := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < until and not taught:
		taught = spotlight != null and spotlight.is_open() and not box.is_open()
		await process_frame
	_check(placed and spoke and not together and taught,
		"the ink is taught after lolo's line at the span, never over it",
		"placed %s, he spoke %s, card over his line %s, card after it %s" % [placed, spoke, together, taught])


func _put(x: float, y: float) -> void:
	var player := level.get("player") as Node2D
	preload("res://tests/level5_journey_fixture.gd").prepare(level,Vector2(x,y))
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
