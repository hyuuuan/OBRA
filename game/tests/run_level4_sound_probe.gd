extends SceneTree
## Dilim's sounds, headless: each asked for where the level shows it, as loud as it shows it.
##
##   godot --headless --path game --script res://tests/run_level4_sound_probe.gd
##
## There are no sound files yet (CONTENT_NEEDED.md §4), so what is checked is the asking:
## AudioDirector.sfx_requested fires for every play_sfx, file or none. The design's rule is that
## every audio cue has a visual, so where a sound has a ripple the ripple is checked to be there
## too, at the same strength. A fresh level for each.
##
## `-- <words>` runs only the scenarios whose name holds them (for a mutant); the every-check-ran
## guard stands down for such a run.

const GROUND_Y := 600.0
const CLEARING_X := 21900.0

var failures := 0
var checked := 0
const CHECKS := 5
var level: Node
## Every sound asked for during the current scenario: [id, loudness].
var heard: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(300.0).timeout.connect(func() -> void:
		print("OBRA_L4_SOUND_FAILED=watchdog")
		quit(2))
	root.get_node(^"AudioDirector").connect(&"sfx_requested", func(id: StringName, loudness: float) -> void:
		heard.append([String(id), loudness]))
	var only := " ".join(OS.get_cmdline_user_args())
	for scenario in [_the_tiktik_is_heard_as_it_is_shown, _the_tiyanak_is_heard_as_it_is_shown,
			_a_hit_on_the_lantern_is_heard, _the_morning_is_heard, _loudness_stays_between_nothing_and_full]:
		if not only.is_empty() and not String((scenario as Callable).get_method()).contains(only):
			continue
		level = await _open_level()
		heard.clear()
		await scenario.call()
		level.queue_free()
		await _frames(3)
	if only.is_empty() and checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_L4_SOUND_OK")
		quit(0)
	else:
		print("OBRA_L4_SOUND_FAILED=%d" % failures)
		quit(1)


## Far off -- so loud -- its call is asked for as loud as its ripple shows it.
func _the_tiktik_is_heard_as_it_is_shown() -> void:
	await _put_her(CLEARING_X - 900.0)
	var finale := _the_finale()
	finale.call("_send_flier", "tiktik")
	var tiktik := finale.tiktik()
	tiktik.global_position = PlayerHurtbox2D.middle_of(level.get("player") as Node2D) + Vector2(700.0, -100.0)
	tiktik.stun(600.0)
	var loudness := await _next("tiktik_call", Tiktik2D.CALL_EVERY + 0.5)
	var shown := _ripple("tiktik")
	_check(loudness > 0.3 and absf(loudness - shown) < 0.01, "the tik-tik's call is asked for as loud as it is shown",
		"call %.2f, ripple %.2f" % [loudness, shown])


func _the_tiyanak_is_heard_as_it_is_shown() -> void:
	await _put_her(16700.0)
	var loudness := await _next("tiyanak_cry", 5.0)
	var shown := _ripple("tiyanak")
	_check(loudness > 0.0 and absf(loudness - shown) < 0.01, "the tiyanak's cry is asked for as loud as it is shown",
		"cry %.2f, ripple %.2f" % [loudness, shown])


func _a_hit_on_the_lantern_is_heard() -> void:
	await _put_her(CLEARING_X - 900.0, false)
	(level.get("player_health") as PlayerHealth).take_hit()
	await _frames(2)
	_check(_asked("lantern_hit") == 1.0, "a hit on her lantern is asked for", "%s" % [heard])


func _the_morning_is_heard() -> void:
	await _put_her(CLEARING_X - 900.0)
	level.call("_on_dawn")
	await _frames(2)
	_check(_asked("dawn") == 1.0, "the morning is asked for", "%s" % [heard])


## Nothing louder than full, and nothing under silence -- linear_to_db(0) is -inf.
func _loudness_stays_between_nothing_and_full() -> void:
	var director := root.get_node(^"AudioDirector")
	director.call("play_sfx", &"dawn", 2.5)
	director.call("play_sfx", &"dawn", -1.0)
	director.call("play_sfx", &"dawn")
	var levels: Array = heard.slice(heard.size() - 3).map(func(entry: Array) -> float: return entry[1])
	_check(levels == [1.0, 0.0, 1.0], "a sound's loudness stays between nothing and full", "%s" % [levels])


# --- Helpers -------------------------------------------------------------------------------

## The loudness of the next request for `id` within `seconds`, or -1.
func _next(id: String, seconds: float) -> float:
	var from := heard.size()
	for _frame in range(int(seconds * 60.0)):
		await _frames(1)
		for index in range(from, heard.size()):
			if heard[index][0] == id:
				return float(heard[index][1])
	return -1.0


## The loudness the scenario asked `id` at, or -1 if it did not.
func _asked(id: String) -> float:
	for entry: Array in heard:
		if entry[0] == id:
			return float(entry[1])
	return -1.0


## The strength of the newest ripple of `kind` on the screen's edge, or -1.
func _ripple(kind: String) -> float:
	var strength := -1.0
	for entry: Dictionary in (level.get("edge_ripple") as EdgeRipple).get("_ripples"):
		if String(entry.get("kind", "")) == kind:
			strength = float(entry.get("strength", -1.0))
	return strength


func _the_finale() -> DilimFinale2D:
	for node in level.find_children("*", "Node2D", true, false):
		if node is DilimFinale2D:
			return node
	return null


func _put_her(x: float, graced: bool = true) -> void:
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": Vector2(x, GROUND_Y - 4.0), "linear_velocity": Vector2.ZERO})
	if graced:
		(level.get("player_health") as PlayerHealth).call("_start_grace", 600.0)
	await _frames(6)


func _open_level() -> Node:
	var scene := (load("res://level_4.tscn") as PackedScene).instantiate()
	(scene.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(scene)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(30)
	return scene


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		if paused:
			call_group(DialogueBox.GROUP, &"hide_line")
			paused = false


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
