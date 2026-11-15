extends SceneTree
## The apo's body, headless: each movement sound asked for where the screen already shows it.
##
##   godot --headless --path game --script res://tests/run_sfx_moves_probe.gd
##
## Headless hears nothing, so what is checked is the ASKING (AudioDirector.sfx_requested) and,
## at that moment, the visual the sound plays beside (Dilim's rule). AUDIO_PLAN.md's table C: a
## footfall with its dust, a landing with its cloud, a jump, a swim stroke as its cycle comes
## round, a ladder's rungs, and a splash. These come constantly, so their spacing is checked to
## be authored and to hold a too-quick repeat back. (`hurt` is Dilim's `lantern_hit`, already
## probed by run_level4_sound_probe: it is the only level with health.)
##
## `-- <words>` runs only the scenarios whose name holds them (for a mutant); the every-check-ran
## guard stands down for such a run.

const MOVES := [&"step", &"jump", &"land", &"swim", &"splash", &"ladder"]
const CONSTANT := [&"step", &"land", &"swim", &"ladder"]
const FLOOR_Y := 600.0

var failures := 0
var checked := 0
const CHECKS := 8
var world: Node2D
var apo: Wanderer
## Every sound asked for in the current scenario: [id, snapshot, loudness]. ⚠ A member, not a
## local: a lambda captures locals by value.
var heard: Array = []
## What a scenario wants recorded beside each sound, read the moment it is asked for.
var snapshot: Callable = func() -> Dictionary: return {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(240.0).timeout.connect(func() -> void:
		print("OBRA_SFX_MOVES_FAILED=watchdog")
		quit(2))
	root.get_node(^"AudioDirector").connect(&"sfx_requested", _on_sfx_requested)
	await _build_the_world()
	var only := " ".join(OS.get_cmdline_user_args())
	for scenario: Callable in [_every_move_sound_has_a_file, _constant_sounds_are_spaced,
			_a_footfall_is_heard_with_its_dust, _a_landing_is_heard_with_its_cloud, _a_jump_is_heard,
			_a_stroke_is_heard_as_it_comes_round, _a_ladder_is_heard_rung_by_rung,
			_a_splash_is_heard_as_hard_as_it_went_in]:
		if not only.is_empty() and not String(scenario.get_method()).contains(only):
			continue
		await _frames(30)
		heard.clear()
		snapshot = func() -> Dictionary: return {}
		await scenario.call()
	if only.is_empty() and checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_SFX_MOVES_OK")
		quit(0)
	else:
		print("OBRA_SFX_MOVES_FAILED=%d" % failures)
		quit(1)


func _on_sfx_requested(id: StringName, loudness: float) -> void:
	heard.append([String(id), snapshot.call(), loudness])


# --- The scenarios -------------------------------------------------------------------------

func _every_move_sound_has_a_file() -> void:
	var sfx: Dictionary = _catalog().get("sfx", {})
	var silent: Array[String] = []
	for id: StringName in MOVES:
		var path := String(sfx.get(String(id), ""))
		if path.is_empty() or not (load(path) is AudioStreamWAV):
			silent.append(String(id))
	_check(silent.is_empty(), "every movement sound has a file", "%d of %d" % [MOVES.size() - silent.size(),
		MOVES.size()] if silent.is_empty() else "silent: " + ", ".join(silent))


## Footsteps, strokes, rungs and landings come constantly. Spaced, a repeat inside its spacing is
## held back, so they cannot take every voice from the sounds that carry information.
func _constant_sounds_are_spaced() -> void:
	var spacing: Dictionary = _catalog().get("spacing", {})
	var unspaced := CONSTANT.filter(func(id: StringName) -> bool: return float(spacing.get(String(id), 0.0)) <= 0.0)
	var director := root.get_node(^"AudioDirector")
	await create_timer(0.5).timeout
	var first := bool(director.call(&"play_sfx", &"step", 1.0))
	var again := bool(director.call(&"play_sfx", &"step", 1.0))
	_check(unspaced.is_empty() and first and not again,
		"the constant sounds are spaced, and a step repeated at once is held back",
		"unspaced %s, first played %s, repeat played %s" % [unspaced, first, again])


func _a_footfall_is_heard_with_its_dust() -> void:
	await _stand()
	snapshot = _puffs
	apo.velocity = Vector2(Wanderer.SPEED, 0.0)
	apo.call(&"_leave_a_mark", 1.0, false, 0.0)
	var step := _first("step")
	_check(_count("step") == 1 and int(step[0].get("puffs", 0)) > 0 and float(step[1]) >= 0.4,
		"a footfall is heard with its dust, never too soft to hear", "%s" % [heard])


func _a_landing_is_heard_with_its_cloud() -> void:
	await _stand()
	snapshot = _puffs
	apo.call(&"_leave_a_mark", 1.0 / 60.0, true, 900.0)
	var landing := _first("land")
	_check(_ids() == ["land"] and int(landing[0].get("puffs", 0)) > 0 and is_equal_approx(float(landing[1]), 1.0),
		"a hard landing is heard with its cloud, at its force", "%s" % [heard])


func _a_jump_is_heard() -> void:
	await _stand()
	snapshot = func() -> Dictionary: return {"rising": apo.velocity.y < 0.0}
	apo.call(&"_jump")
	_check(_count("jump") == 1 and bool(_first("jump")[0].get("rising", false)),
		"a jump is heard as she leaves the ground", "%s" % [heard])


## In water, her stroke cycle comes round once per SWIM_STROKE travelled: one sound each time.
func _a_stroke_is_heard_as_it_comes_round() -> void:
	apo.set_meta(&"water_overlap_count", 1)
	apo.can_swim = true
	apo.global_position = Vector2(900.0, FLOOR_Y - 300.0)
	var figure := apo.get(&"_figure") as Node
	snapshot = func() -> Dictionary: return {"pose": String(figure.get(&"pose"))}
	apo.velocity = Vector2(Wanderer.SWIM_SPEED, 0.0)
	# Swimming is a held direction, as she plays it.
	Input.action_press(&"move_right")
	var wraps := 0
	var last := 0.0
	for _step in range(40):
		apo.call(&"_advance_stride", 0.05, Wanderer.SWIM_SPEED)
		var phase := float(apo.get(&"_phase"))
		if String(figure.get(&"pose")) == "swim" and phase < last:
			wraps += 1
		last = phase
	Input.action_release(&"move_right")
	var strokes := heard.filter(func(entry: Array) -> bool: return entry[0] == "swim")
	var posed := strokes.all(func(entry: Array) -> bool: return (entry[1] as Dictionary).get("pose", "") == "swim")
	_check(wraps > 1 and strokes.size() == wraps and posed, "a swim stroke is heard each time it comes round",
		"%d strokes drawn, %d heard" % [wraps, strokes.size()])
	apo.set_meta(&"water_overlap_count", 0)
	apo.can_swim = false
	apo.velocity = Vector2.ZERO


## Taking hold, and then a rung for every RUNG_STRIDE climbed.
func _a_ladder_is_heard_rung_by_rung() -> void:
	await _stand()
	var ladder := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(40.0, 600.0)
	shape.shape = box
	ladder.add_child(shape)
	world.add_child(ladder)
	ladder.global_position = apo.global_position + Vector2(0.0, -260.0)
	await _frames(2)
	var figure := apo.get(&"_figure") as Node
	snapshot = func() -> Dictionary: return {"pose": String(figure.get(&"pose"))}
	apo.begin_ladder(ladder)
	var held := _count("ladder")
	var from := apo.global_position
	Input.action_press(&"move_up")
	await create_timer(1.0).timeout
	Input.action_release(&"move_up")
	var climbed := from.distance_to(apo.global_position)
	var rungs := _count("ladder") - held
	var expected := int(climbed / Wanderer.RUNG_STRIDE)
	_check(held == 1 and expected >= 3 and absi(rungs - expected) <= 1
			and heard.slice(1).all(func(entry: Array) -> bool: return (entry[1] as Dictionary).get("pose", "") == "climb"),
		"a ladder is heard as she takes hold and at each rung she climbs",
		"held %d, %.0f px climbed, %d rungs heard (%d expected)" % [held, climbed, rungs, expected])
	apo.end_ladder()
	ladder.queue_free()


func _a_splash_is_heard_as_hard_as_it_went_in() -> void:
	var water := WaterArea2D.new()
	world.add_child(water)
	water.global_position = Vector2(1400.0, FLOOR_Y - 100.0)
	await _frames(2)
	snapshot = func() -> Dictionary:
		var puffs := water.get_children().filter(func(child: Node) -> bool: return child is SceneryPuff2D)
		return {"rings": puffs.size()}
	apo.velocity = Vector2(0.0, 700.0)
	water.call(&"_splash_for", apo)
	var splash := _first("splash")
	_check(_ids() == ["splash"] and int(splash[0].get("rings", 0)) > 0 and is_equal_approx(float(splash[1]), 1.0),
		"a splash is heard with its rings, as hard as it went in", "%s" % [heard])
	water.queue_free()
	apo.velocity = Vector2.ZERO


# --- Fixture -------------------------------------------------------------------------------

func _build_the_world() -> void:
	world = Node2D.new()
	root.add_child(world)
	var ground := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(4000.0, 40.0)
	shape.shape = box
	ground.add_child(shape)
	world.add_child(ground)
	ground.global_position = Vector2(600.0, FLOOR_Y + 20.0)
	apo = (load("res://creatures/wanderer.tscn") as PackedScene).instantiate() as Wanderer
	world.add_child(apo)
	apo.global_position = Vector2(600.0, FLOOR_Y)
	await _frames(30)


## On her feet on the floor, still, with a frame of physics to know it.
func _stand() -> void:
	apo.velocity = Vector2.ZERO
	apo.global_position = Vector2(600.0, FLOOR_Y - 2.0)
	await _frames(20)
	heard.clear()


func _puffs() -> Dictionary:
	var puffs := world.find_children("*", "", true, false).filter(func(node: Node) -> bool:
		return node is SceneryPuff2D)
	return {"puffs": puffs.size()}


func _catalog() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://config/audio.json"))


func _ids() -> Array:
	return heard.map(func(entry: Array) -> String: return entry[0])


func _count(id: String) -> int:
	return _ids().count(id)


## [snapshot, loudness] when `id` was first asked for, or [{}, -1].
func _first(id: String) -> Array:
	for entry: Array in heard:
		if entry[0] == id:
			return [entry[1], entry[2]]
	return [{}, -1.0]


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
