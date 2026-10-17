extends SceneTree
## Dilim's last clearing, headless: the night begins when she steps in, two aswang at most, one
## back after one falls, a knockout starting it over, and the morning ending it.
##
##   godot --headless --path game --script res://tests/run_level4_finale_probe.gd
##
## She is kept in her grace throughout, so the dogs cannot knock her out of the check: what is
## measured here is the night, not the fight.

const GROUND_Y := 600.0
const CLEARING_WEST := 21400.0

var failures := 0
## Every check that ran, so one skipped by a script error is a failure rather than a silence.
var checked := 0
const CHECKS := 11
var level: Node
var finale: DilimFinale2D
## The most of them alive at once, seen on every frame of the night.
var most_alive := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(180.0).timeout.connect(func() -> void:
		print("OBRA_L4_FINALE_FAILED=watchdog")
		quit(2))
	level = await _open_level()
	finale = _the_finale()
	await _nothing_before_the_clearing()
	await _stepping_in_begins_the_night()
	_the_clock_comes_with_the_night()
	await _one_falls_and_another_comes()
	await _never_more_than_two()
	await _a_knockout_starts_the_night_over()
	await _morning_ends_it()
	await _the_dark_lifts_and_she_is_through()
	_check(not (level.get("dawn_clock") as Control).visible, "and the night's clock is gone",
		"visible %s" % (level.get("dawn_clock") as Control).visible)
	level.queue_free()
	await _frames(3)
	if checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_L4_FINALE_OK")
		quit(0)
	else:
		print("OBRA_L4_FINALE_FAILED=%d" % failures)
		quit(1)


## The scene's own, or one at the clearing's middle until the scene has it.
func _the_finale() -> DilimFinale2D:
	for node in level.find_children("*", "Node2D", true, false):
		if node is DilimFinale2D:
			return node
	var made := DilimFinale2D.new()
	made.position = Vector2(21900.0, GROUND_Y)
	made.arena_west = CLEARING_WEST
	(level.get("entity_root") as Node2D).add_child(made)
	return made


func _nothing_before_the_clearing() -> void:
	await _put_her_at(CLEARING_WEST - 600.0)
	await _seconds(1.0)
	_check(not finale.is_running() and finale.alive().is_empty(),
		"short of the last clearing, nothing has begun", "running %s" % finale.is_running())
	set_meta(&"clock_before", (level.get("dawn_clock") as Control).visible)


func _stepping_in_begins_the_night() -> void:
	var ink := level.get("ink_manager") as InkManager
	ink.drain(ink.remaining() - 1.0)
	var low := ink.remaining()
	await _put_her_at(CLEARING_WEST + 120.0)
	_check(low < 1.5 and is_equal_approx(ink.remaining(), ink.capacity),
		"the last clearing's edge fills her ink", "%.1f -> %.1f" % [low, ink.remaining()])
	await _seconds(0.5)
	_check(finale.is_running() and finale.alive().size() == DilimFinale2D.WAVE_SIZE,
		"stepping in begins the night, two aswang on her",
		"running %s, %d alive" % [finale.is_running(), finale.alive().size()])


## Through the start, a fall and its replacement, and three seconds more.
func _never_more_than_two() -> void:
	await _seconds(3.0)
	_check(most_alive == 2, "never more than two at once", "at most %d" % most_alive)


## Hidden before the night, up once it begins, and following it -- a share of the night, no numbers --
## within a tick or two: the level reads it before the night has counted its own.
func _the_clock_comes_with_the_night() -> void:
	var clock := level.get("dawn_clock") as DawnClockHud
	_check(not bool(get_meta(&"clock_before", true)) and clock.visible
			and absf(clock.progress() - finale.progress()) < 2.0 / (60.0 * DilimFinale2D.DAWN_SECONDS)
			and clock.progress() > 0.0,
		"the night's clock comes up with it, and follows it",
		"before %s, now %s at %.3f of %.3f" % [get_meta(&"clock_before", true), clock.visible,
			clock.progress(), finale.progress()])


func _one_falls_and_another_comes() -> void:
	var foe: Enemy2D = finale.alive()[0]
	var apo := level.get("player") as Node2D
	for _blow in range(foe.max_hp):
		foe.apply_tool_hit("sword", 0.0, apo)
	# Read now: a fallen one is cleared away once it has faded.
	var fell := foe.is_dead()
	await _seconds(1.0)
	var one := finale.alive().size()
	# The design's six seconds, not the script's constant: a shorter one would move the wait too.
	await _seconds(6.0 - 1.6)
	var still_one := finale.alive().size()
	await _seconds(1.0)
	_check(fell and one == 1 and still_one == 1 and finale.alive().size() == 2,
		"one falls, and another comes 6 s later",
		"%d, then %d just short of it, then %d" % [one, still_one, finale.alive().size()])


func _a_knockout_starts_the_night_over() -> void:
	var before := finale.elapsed
	level.call("_knockout")
	await _frames(4)
	_grace()
	await _seconds(0.5)
	_check(before > 5.0 and finale.is_running() and finale.elapsed < 1.0
			and finale.alive().size() == DilimFinale2D.WAVE_SIZE,
		"a knockout starts the night over", "%.1f s in, then %.1f s, %d alive"
			% [before, finale.elapsed, finale.alive().size()])


func _morning_ends_it() -> void:
	var said := [false]
	var box := level.get("dialogue_box") as Node
	# After the level's own answer to it has begun -- connected later, so called later.
	finale.dawned.connect(func() -> void:
		said[0] = true
		set_meta(&"dawn_line", String(box.call("current_line"))))
	# Lines left up for the dawn's to be read: the probe otherwise dismisses each as it comes.
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", false)
	finale.elapsed = DilimFinale2D.DAWN_SECONDS - 0.5
	await _seconds(0.8)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _seconds(DilimFinale2D.FLEE_FADE + 0.4)
	var left := 0
	for node in finale.find_children("*", "", true, false):
		if node is Enemy2D and not node.is_queued_for_deletion():
			left += 1
	_check(said[0] and finale.has_dawned() and not finale.is_running() and left == 0,
		"morning ends it, and they go", "dawned %s, %d still in the clearing" % [said[0], left])


## Her line, then the dark gone and the level finished: the majority route settled.
func _the_dark_lifts_and_she_is_through() -> void:
	var line := String(get_meta(&"dawn_line", ""))
	_check(line.begins_with("Morning. Lola named every one"), "at dawn she says what the night was for",
		"\"%s\"" % line)
	await _seconds(3.5)
	var dark := float((level.get("darkness_layer") as Node).get(&"darkness"))
	_check(dark < 0.05 and bool(level.get("_level_completed")), "the dark lifts, and the level is done",
		"dark %.2f, completed %s" % [dark, level.get("_level_completed")])


# --- Helpers -------------------------------------------------------------------------------

func _open_level() -> Node:
	var scene := (load("res://level_4.tscn") as PackedScene).instantiate()
	(scene.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(scene)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(30)
	return scene


func _put_her_at(x: float) -> void:
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": Vector2(x, GROUND_Y - 4.0), "linear_velocity": Vector2.ZERO})
	_grace()
	await _frames(6)


## A long grace: the dogs reach her and land nothing.
func _grace() -> void:
	(level.get("player_health") as PlayerHealth).call("_start_grace", 600.0)


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		if finale != null and is_instance_valid(finale):
			most_alive = maxi(most_alive, finale.alive().size())
		if paused:
			call_group(DialogueBox.GROUP, &"hide_line")
			paused = false


func _seconds(seconds: float) -> void:
	await _frames(int(ceil(seconds * 60.0)))


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
