extends SceneTree
## Dilim's far side, headless: the tiyanak, the bungisngis, the manananggal, and the lights.
##
##   godot --headless --path game --script res://tests/run_level4_seg3_probe.gd
##
## Each encounter three ways, the way a player answers it -- drawings handed in as the recogniser
## would, keys held, salt thrown from the satchel -- and read back off what the level and the things
## in it say happened. A fresh level for each, so no answer leaks into the next.
##
## `-- <words>` runs only the scenarios whose name holds them (for a mutant, which needs only the
## check that guards it); the every-check-ran guard stands down for such a run.

const GROUND_Y := 600.0
## The ravine's floor, where the bungisngis stands.
const FLOOR_Y := 820.0

var failures := 0
var checked := 0
const CHECKS := 25
var level: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(420.0).timeout.connect(func() -> void:
		print("OBRA_L4_SEG3_FAILED=watchdog")
		quit(2))
	var only := " ".join(OS.get_cmdline_user_args())
	for scenario in [_its_cry_shows_where_it_comes_from, _the_path_kept_passes_it, _down_by_the_cry_the_path_is_not_kept,
			_walked_on_to_the_cry_she_falls, _a_light_shows_it_for_what_it_is, _struck_down_it_leaves_nothing,
			_its_body_walls_the_crossing, _something_absurd_sets_it_laughing, _over_its_head_is_the_way_over,
			_beaten_it_is_driven_off, _its_slam_throws_her,
			_salt_on_the_lower_half_ends_her, _a_light_held_on_the_lower_half, _her_lantern_is_not_that_light,
			_driven_off_her_lower_half_stands, _the_upper_half_keeps_to_its_ground,
			_a_fire_lights_round_it, _a_sun_lights_far,
			_a_blade_swung_first_the_path_still_passes_it, _a_blade_swung_first_salt_still_ends_her,
			_what_a_drawing_cannot_do_here_is_said_in_english, _a_tool_with_no_verb_is_offered_once]:
		if not only.is_empty() and not String((scenario as Callable).get_method()).contains(only):
			continue
		level = await _open_level()
		await scenario.call()
		level.queue_free()
		await _frames(3)
	if only.is_empty() and checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_L4_SEG3_OK")
		quit(0)
	else:
		print("OBRA_L4_SEG3_FAILED=%d" % failures)
		quit(1)


# --- The tiyanak ---------------------------------------------------------------------------

func _tiyanak() -> Tiyanak2D:
	return level.get("_tiyanak") as Tiyanak2D


## Both the strength of a cry seen near and one seen far, a cry each.
func _its_cry_shows_where_it_comes_from() -> void:
	await _put(16700.0, GROUND_Y, &"move_right")
	var near := await _next_cry_strength(5.0)
	await _put(15900.0, GROUND_Y, &"move_right")
	var far := await _next_cry_strength(5.0)
	_check(near > 0.0 and far > 0.0 and near > far, "its cry shows as an amber ripple, stronger the nearer she is",
		"near %.2f, far %.2f" % [near, far])


func _the_path_kept_passes_it() -> void:
	# On the path's high log, over the drop, walking on to the far side.
	await _put(17150.0, 465.0, &"move_right")
	await _hold(&"move_right", 3.0)
	var director = level.get("director")
	_check(director.call("committed_route", "L4_TIYANAK") == "pragmatist" and director.call("is_solved", "L4_TIYANAK")
			and not bool(level.get("_went_to_the_cry")),
		"kept to the path over the drop, she is past it: the pragmatist's way",
		"route '%s', x %.0f" % [director.call("committed_route", "L4_TIYANAK"), _her_x()])


func _down_by_the_cry_the_path_is_not_kept() -> void:
	await _put(17000.0, GROUND_Y, &"move_right")
	await _frames(30)
	await _put(17760.0, GROUND_Y, &"move_right")
	await _frames(30)
	var director = level.get("director")
	_check(not director.call("is_solved", "L4_TIYANAK") and bool(level.get("_went_to_the_cry")),
		"gone down to the cry first, the far side is not the path kept", "solved %s" % director.call("is_solved", "L4_TIYANAK"))


## The danger is the terrain it leads to: the bushes run on over nothing.
func _walked_on_to_the_cry_she_falls() -> void:
	await _put(17200.0, GROUND_Y, &"move_right")
	Input.action_press(&"move_right")
	var deepest := 0.0
	var back := false
	for _frame in range(5 * 60):
		await _frames(1)
		deepest = maxf(deepest, (level.get("player") as Node2D).global_position.y)
		if deepest > GROUND_Y + 300.0 and _her_x() < 16000.0:
			back = true
			break
	Input.action_release(&"move_right")
	_check(back, "walked on toward the cry, she falls through the bushes and the woods take her back",
		"deepest %.0f, now at x %.0f" % [deepest, _her_x()])


func _a_light_shows_it_for_what_it_is() -> void:
	await _put(16800.0, GROUND_Y, &"move_right")
	await _become("flashlight")
	level.call("_use_equipped_utility")
	await _frames(90)
	var director = level.get("director")
	_check(director.call("committed_route", "L4_TIYANAK") == "artist" and director.call("is_solved", "L4_TIYANAK")
			and _tiyanak().is_revealed() and _tiyanak().is_gone(),
		"a light she drew shows it for what it is, and it flees",
		"route '%s', revealed %s, gone %s" % [director.call("committed_route", "L4_TIYANAK"), _tiyanak().is_revealed(), _tiyanak().is_gone()])


func _struck_down_it_leaves_nothing() -> void:
	# Every kind sure to drop, if anything were rolled for it.
	var satchel := level.get("satchel") as Satchel
	for id in satchel.ids():
		satchel.row(id)["drop_chance"] = 1.0
	await _put(17060.0, GROUND_Y, &"move_right")
	await _become("sword")
	level.call("_use_equipped_utility")
	await _frames(10)
	var director = level.get("director")
	var drawn_in := String(director.call("committed_route", "L4_TIYANAK"))
	var by_the_swing := bool(director.call("is_solved", "L4_TIYANAK"))
	var before := _pickups()
	var apo := level.get("player") as Node2D
	for _blow in range(10):
		if _tiyanak().is_dead():
			break
		_tiyanak().apply_tool_hit("sword", 0.0, apo)
		await _frames(2)
	await _frames(20)
	_check(drawn_in == "protector" and not by_the_swing and director.call("is_solved", "L4_TIYANAK"),
		"struck down after a weapon drawn, the fight is answered -- not by the swing that chose it",
		"committed '%s', by the swing %s, then %s" % [drawn_in, by_the_swing, director.call("is_solved", "L4_TIYANAK")])
	_check(_pickups() == before, "and it leaves nothing where it fell", "%d things lying there, %d before" % [_pickups(), before])


# --- The bungisngis -------------------------------------------------------------------------

func _bungisngis() -> Bungisngis2D:
	return level.get("_bungisngis") as Bungisngis2D


func _its_body_walls_the_crossing() -> void:
	await _put(19160.0, FLOOR_Y, &"move_right")
	await _hold(&"move_right", 1.5)
	_check(_her_x() < 19215.0, "on the ravine's floor, its body walls the crossing", "she got to x %.0f" % _her_x())


func _something_absurd_sets_it_laughing() -> void:
	await _put(19050.0, GROUND_Y, &"move_right")
	await _become("fish")
	await _frames(int(0.2 * 60.0))
	var director = level.get("director")
	var early := bool(director.call("is_solved", "L4_BUNGISNGIS"))
	await _frames(int(0.8 * 60.0))
	await _frames(2)
	_check(not early and director.call("committed_route", "L4_BUNGISNGIS") == "artist"
			and director.call("is_solved", "L4_BUNGISNGIS") and _bungisngis().is_laughing()
			and _bungisngis().wall.collision_layer == 0,
		"something absurd brought to it a moment, it laughs itself helpless and the crossing is open",
		"early %s, route '%s', laughing %s, wall %d" % [early, director.call("committed_route", "L4_BUNGISNGIS"),
			_bungisngis().is_laughing(), _bungisngis().wall.collision_layer])


func _over_its_head_is_the_way_over() -> void:
	await _put(19100.0, GROUND_Y, &"move_right")
	level.call("_judge_submission", "ladder")
	await _frames(20)
	var director = level.get("director")
	var drawn_in := String(director.call("committed_route", "L4_BUNGISNGIS"))
	var on_the_near_side := bool(director.call("is_solved", "L4_BUNGISNGIS"))
	_check(drawn_in == "pragmatist" and not on_the_near_side,
		"a way over drawn, the near bank is not yet over", "committed '%s', solved %s" % [drawn_in, on_the_near_side])
	# Up on the high path, over its head and the ravine, and on to the far bank.
	await _put(19300.0, 400.0, &"move_right")
	await _hold(&"move_right", 1.5)
	_check(director.call("is_solved", "L4_BUNGISNGIS") and _bungisngis().is_in_the_way(),
		"along the high path to the far bank, over it while it still stands: the pragmatist's way",
		"solved %s, x %.0f" % [director.call("is_solved", "L4_BUNGISNGIS"), _her_x()])


func _beaten_it_is_driven_off() -> void:
	await _put(19160.0, FLOOR_Y, &"move_right")
	await _become("sword")
	level.call("_use_equipped_utility")
	await _frames(10)
	var director = level.get("director")
	var drawn_in := String(director.call("committed_route", "L4_BUNGISNGIS"))
	var apo := level.get("player") as Node2D
	for _blow in range(40):
		if _bungisngis().is_dead():
			break
		_bungisngis().apply_tool_hit("sword", 0.0, apo)
		await _frames(2)
	await _frames(10)
	_check(drawn_in == "protector" and director.call("is_solved", "L4_BUNGISNGIS") and _bungisngis().is_dead()
			and _bungisngis().wall.collision_layer == 0,
		"beaten, it is driven off and the crossing is open", "committed '%s', solved %s, wall %d"
			% [drawn_in, director.call("is_solved", "L4_BUNGISNGIS"), _bungisngis().wall.collision_layer])


## No grace this time: its slam is meant to land. Up and away from it -- the ravine's wall is close
## behind her on its floor, so the throw is measured whichever way it takes her.
func _its_slam_throws_her() -> void:
	await _put(19165.0, FLOOR_Y, &"move_right", false)
	var health := level.get("player_health") as PlayerHealth
	var from_stage := health.stage
	var from := (level.get("player") as Node2D).global_position
	var furthest := 0.0
	for _frame in range(4 * 60):
		await _frames(1)
		furthest = maxf(furthest, from.distance_to((level.get("player") as Node2D).global_position))
		if health.stage < from_stage and furthest > 25.0:
			break
	_check(health.stage < from_stage and furthest > 25.0, "its slam lands on her and throws her",
		"stage %d to %d, thrown %.0f px" % [from_stage, health.stage, furthest])


# --- The manananggal ------------------------------------------------------------------------

func _upper() -> ManananggalUpper2D:
	return level.get("_upper") as ManananggalUpper2D


func _lower() -> ManananggalLower2D:
	return level.get("_lower") as ManananggalLower2D


func _salt_on_the_lower_half_ends_her() -> void:
	await _put(20640.0, GROUND_Y, &"move_right")
	(level.get("satchel") as Satchel).add("asin", 2)
	level.call("_use_from_satchel", "asin")
	await _frames(60)
	var director = level.get("director")
	_check(director.call("committed_route", "L4_MANANANGGAL") == "pragmatist" and director.call("is_solved", "L4_MANANANGGAL")
			and _lower().is_salted() and _upper().is_gone(),
		"salt thrown on her lower half ends her: the pragmatist's way",
		"route '%s', salted %s, upper gone %s" % [director.call("committed_route", "L4_MANANANGGAL"), _lower().is_salted(), _upper().is_gone()])


func _a_light_held_on_the_lower_half() -> void:
	await _put(20700.0, GROUND_Y, &"move_right")
	await _become("flashlight")
	level.call("_use_equipped_utility")
	await _frames(60)
	var director = level.get("director")
	var at_a_second := bool(director.call("is_solved", "L4_MANANANGGAL"))
	await _frames(int(1.6 * 60.0))
	_check(not at_a_second and director.call("committed_route", "L4_MANANANGGAL") == "artist"
			and director.call("is_solved", "L4_MANANANGGAL") and _upper().is_gone(),
		"a light she drew held on the lower half two seconds: she cannot rejoin, and is gone",
		"at a second %s, route '%s', upper gone %s" % [at_a_second, director.call("committed_route", "L4_MANANANGGAL"), _upper().is_gone()])


func _her_lantern_is_not_that_light() -> void:
	var director = level.get("director")
	director.call("commit_route", "L4_MANANANGGAL", "artist")
	await _put(20800.0, GROUND_Y, &"move_right")
	await _frames(3 * 60)
	_check(not director.call("is_solved", "L4_MANANANGGAL"),
		"her own lantern beside the lower half does not count as the light", "solved %s" % director.call("is_solved", "L4_MANANANGGAL"))


func _driven_off_her_lower_half_stands() -> void:
	await _put(20700.0, GROUND_Y, &"move_right")
	await _become("sword")
	level.call("_use_equipped_utility")
	await _frames(10)
	var director = level.get("director")
	var drawn_in := String(director.call("committed_route", "L4_MANANANGGAL"))
	var apo := level.get("player") as Node2D
	for _blow in range(30):
		if _upper().is_gone():
			break
		_upper().apply_tool_hit("sword", 0.0, apo)
		await _frames(2)
	await _frames(10)
	_check(drawn_in == "protector" and director.call("is_solved", "L4_MANANANGGAL") and _upper().is_gone()
			and not _lower().is_dead() and not _lower().is_salted(),
		"her upper half driven off answers the fight, and her lower half still stands",
		"committed '%s', solved %s, lower dead %s" % [drawn_in, director.call("is_solved", "L4_MANANANGGAL"), _lower().is_dead()])


## Once it has her -- hunting her over its ground -- and then she goes on past it.
func _the_upper_half_keeps_to_its_ground() -> void:
	var home := _upper().global_position
	await _put(20700.0, GROUND_Y, &"move_right")
	await _frames(int(1.5 * 60.0))
	var hunting := _upper().state_name() != "IDLE"
	await _put(21900.0, GROUND_Y, &"move_right")
	await _frames(4 * 60)
	if not hunting:
		print("  (it never started hunting her)")
	# Back over where it rose, and holding there -- not drifting on after her.
	_check(hunting and absf(_upper().global_position.x - home.x) <= 200.0,
		"her upper half does not follow her off its ground, but goes back over it", "it is at x %.0f, she at %.0f" % [_upper().global_position.x, _her_x()])


## A blade swung first is not the choice made for good: whatever she ends up doing answers it.
func _a_blade_swung_first_the_path_still_passes_it() -> void:
	await _put(16900.0, GROUND_Y, &"move_right")
	await _become("sword")
	level.call("_use_equipped_utility")
	await _frames(20)
	var director = level.get("director")
	var first := String(director.call("committed_route", "L4_TIYANAK"))
	await _put(17150.0, 465.0, &"move_right")
	await _hold(&"move_right", 3.0)
	_check(first == "protector" and director.call("committed_route", "L4_TIYANAK") == "pragmatist"
			and director.call("is_solved", "L4_TIYANAK"),
		"a blade swung first, the path kept after it still passes the tiyanak",
		"first '%s', then '%s'" % [first, director.call("committed_route", "L4_TIYANAK")])


func _a_blade_swung_first_salt_still_ends_her() -> void:
	await _put(20640.0, GROUND_Y, &"move_right")
	await _become("sword")
	level.call("_use_equipped_utility")
	await _frames(20)
	var director = level.get("director")
	var first := String(director.call("committed_route", "L4_MANANANGGAL"))
	(level.get("satchel") as Satchel).add("asin", 2)
	level.call("_use_from_satchel", "asin")
	await _frames(60)
	_check(first == "protector" and director.call("committed_route", "L4_MANANANGGAL") == "pragmatist"
			and director.call("is_solved", "L4_MANANANGGAL") and _upper().is_gone(),
		"a blade swung first, salt after it still ends the manananggal",
		"first '%s', then '%s', solved %s" % [first, director.call("committed_route", "L4_MANANANGGAL"),
			director.call("is_solved", "L4_MANANANGGAL")])


## What she is told when a drawing is not what a place needs, and what F will do with a tool in
## hand, both as sentences: Dilim's tags are not verbs ("can ABSURD", "a elephant can BEAST"), and a
## tool with no verb of its own was offered as "use here here".
func _what_a_drawing_cannot_do_here_is_said_in_english() -> void:
	await _put(19050.0, GROUND_Y, &"move_right")
	var bar := level.get("hint_bar") as HintBar
	await _become("elephant")
	var said := bar.current_text()
	_check(said.begins_with("An elephant can ") and said.contains("be a BEAST") and said.contains("be ABSURD")
			and not said.contains("can ABSURD") and not said.contains("can BEAST"),
		"a drawing that is not what is needed is told so in a sentence", "\"%s\"" % said)


func _a_tool_with_no_verb_is_offered_once() -> void:
	await _put(19050.0, GROUND_Y, &"move_right")
	var bar := level.get("hint_bar") as HintBar
	await _become("wheel")
	var offered := bar.current_text()
	_check(offered.ends_with("to use here") and not offered.contains("here here"),
		"and a tool in hand with no verb of its own is offered once, not as \"use here here\"", "\"%s\"" % offered)


# --- The lights -----------------------------------------------------------------------------

func _set_down(entity_id: String, at: Vector2) -> UtilityObject:
	var thing := (level.get("registry") as EntityRegistry).instantiate_entity(entity_id) as UtilityObject
	level.get_node(^"EnvironmentBaseplate/GameplayPlane").add_child(thing)
	thing.global_position = at
	thing.freeze = true
	await _frames(4)
	return thing


func _a_fire_lights_round_it() -> void:
	var fire := await _set_down("campfire", Vector2(17000.0, 560.0))
	var lit_near := LightField.light_at(self, fire.global_position + Vector2(120.0, 0.0))
	var lit_far := LightField.light_at(self, fire.global_position + Vector2(900.0, 0.0))
	_check(lit_near >= 0.9 and lit_far < 0.05 and not fire.light_hole().has("direction"),
		"a campfire set down lights the dark all round it", "%.2f beside it, %.2f far off" % [lit_near, lit_far])
	fire.set_preview(true)
	_check(fire.light_hole().is_empty(), "and one still being placed lights nothing", "%s" % fire.light_hole())


func _a_sun_lights_far() -> void:
	var sun := await _set_down("sun", Vector2(17000.0, 400.0))
	var lit := LightField.light_at(self, sun.global_position + Vector2(0.0, 300.0))
	_check(lit >= 0.9, "a drawn sun lights the dark a long way round it", "%.2f, 300 px off" % lit)


# --- Helpers --------------------------------------------------------------------------------

func _her_x() -> float:
	return (level.get("player") as Node2D).global_position.x


## Her feet on `ground_y` at `x`, facing `toward` -- in a long grace unless she is to be hit.
func _put(x: float, ground_y: float, toward: StringName, graced: bool = true) -> void:
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": Vector2(x, ground_y - 4.0), "linear_velocity": Vector2.ZERO})
	if graced:
		(level.get("player_health") as PlayerHealth).call("_start_grace", 600.0)
	await _frames(6)
	Input.action_press(toward)
	await _frames(2)
	Input.action_release(toward)
	await _frames(6)


func _hold(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	await _frames(int(seconds * 60.0))
	Input.action_release(action)
	await _frames(4)


func _become(entity_id: String) -> void:
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	level.call("_on_drawing_ready", entity_id, entity_id.capitalize(), sheet, {"confidence": 0.9},
		[{"points": PackedVector2Array([Vector2(0, 0), Vector2(40, 0)]), "width": 6.0, "color": Color.BLACK}], 1.0)
	await _frames(10)


## The strength of the next tiyanak ripple put up within `seconds`, or 0.
func _next_cry_strength(seconds: float) -> float:
	var ripple := level.get("edge_ripple") as EdgeRipple
	for _frame in range(int(seconds * 60.0)):
		await _frames(1)
		var ripples: Array = ripple.get("_ripples")
		for entry: Dictionary in ripples:
			if String(entry.get("kind", "")) == "tiyanak" and float(entry.get("age", 1.0)) < 0.05:
				return float(entry.get("strength", 0.0))
	return 0.0


func _pickups() -> int:
	var count := 0
	for node in level.find_children("*", "Area2D", true, false):
		if node is SatchelPickup2D and not (node as Node).is_queued_for_deletion():
			count += 1
	return count


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
