extends SceneTree
## Dilim's middle stretch, headless: a drawn body's ink, the sigbin, the tikbalang and the kapre.
##
##   godot --headless --path game --script res://tests/run_level4_seg2_probe.gd
##
## Driven the way a player drives it -- drawings handed in as the recogniser would, keys held --
## and read back off what the level and the things in it say happened.

const GROUND_Y := 600.0

var failures := 0
var checked := 0
const CHECKS := 14
var level: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(240.0).timeout.connect(func() -> void:
		print("OBRA_L4_SEG2_FAILED=watchdog")
		quit(2))
	level = await _open_level()
	await _a_drawn_body_costs_ink_and_has_no_clock()
	await _at_no_ink_she_is_herself()
	level.queue_free()
	await _frames(3)
	for sigbin_check in [_a_light_sends_the_sigbin_off, _her_back_to_the_rock_and_it_gives_up, _facing_the_rock_is_not_her_back_to_it, _well_off_the_rock_is_not_against_it, _struck_down_it_is_driven_off]:
		level = await _open_level()
		await sigbin_check.call()
		level.queue_free()
		await _frames(3)
	for tikbalang_check in [_walking_on_she_comes_back_to_the_rock, _a_body_with_hooves_is_let_by, _another_animals_body_is_let_by, _a_race_run_flat_out_is_won, _a_race_walked_is_lost]:
		level = await _open_level()
		await tikbalang_check.call()
		level.queue_free()
		await _frames(3)
	if checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_L4_SEG2_OK")
		quit(0)
	else:
		print("OBRA_L4_SEG2_FAILED=%d" % failures)
		quit(1)


# --- A drawn body ------------------------------------------------------------------------

func _become(entity_id: String) -> void:
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	level.call("_on_drawing_ready", entity_id, entity_id.capitalize(), sheet, {"confidence": 0.9},
		[{"points": PackedVector2Array([Vector2(0, 0), Vector2(40, 0)]), "width": 6.0, "color": Color.BLACK}], 1.0)
	await _frames(10)


## A horse held for twelve seconds: past the ten a body lasts anywhere else, and a quarter of a
## unit gone each second.
func _a_drawn_body_costs_ink_and_has_no_clock() -> void:
	var ink := level.get("ink_manager") as InkManager
	await _become("horse")
	var from := ink.remaining()
	await _frames(2 * 60)
	var after_two := from - ink.remaining()
	await _frames(10 * 60)
	var still := String(level.get("_current_form_id")) == "horse"
	_check(absf(after_two - 0.5) < 0.05, "a drawn body costs a quarter of a unit a second",
		"%.2f in two seconds" % after_two)
	_check(still, "and it has no ten-second clock", "still a horse at twelve seconds: %s" % still)


func _at_no_ink_she_is_herself() -> void:
	var ink := level.get("ink_manager") as InkManager
	ink.drain(ink.remaining() - 0.05)
	await _frames(60)
	_check(String(level.get("_current_form_id")).is_empty() and level.get("player") is Wanderer,
		"at no ink she is herself again", "form '%s'" % level.get("_current_form_id"))


# --- The sigbin --------------------------------------------------------------------------

## Her in the sigbin's ground in a long grace (its blows land nothing), facing `toward`.
func _stand_at(x: float, toward: StringName) -> void:
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": Vector2(x, GROUND_Y - 4.0), "linear_velocity": Vector2.ZERO})
	(level.get("player_health") as PlayerHealth).call("_start_grace", 600.0)
	await _frames(6)
	Input.action_press(toward)
	await _frames(2)
	Input.action_release(toward)
	await _frames(6)


func _sigbin() -> Sigbin2D:
	return level.get("_sigbin") as Sigbin2D


func _a_light_sends_the_sigbin_off() -> void:
	await _stand_at(6950.0, &"move_right")
	await _become("flashlight")
	# Lines left up for this one read: the probe otherwise dismisses each as it comes.
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", false)
	level.call("_use_equipped_utility")
	await physics_frame
	var said := String((level.get("dialogue_box") as Node).call("current_line"))
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(90)
	_check(said.begins_with("It cannot bear being seen"), "and she says what Lola knew of it", "\"%s\"" % said)
	var director = level.get("director")
	_check(director.call("committed_route", "L4_SIGBIN") == "artist" and director.call("is_solved", "L4_SIGBIN")
			and _sigbin().is_gone(),
		"shown a light, the sigbin flees", "route '%s', gone %s" % [director.call("committed_route", "L4_SIGBIN"), _sigbin().is_gone()])


func _her_back_to_the_rock_and_it_gives_up() -> void:
	await _stand_at(6812.0, &"move_right")
	await _frames(4 * 60)
	var director = level.get("director")
	var early := bool(director.call("is_solved", "L4_SIGBIN"))
	await _frames(int(1.6 * 60.0))
	_check(not early and director.call("committed_route", "L4_SIGBIN") == "pragmatist"
			and director.call("is_solved", "L4_SIGBIN") and _sigbin().is_gone(),
		"with her back to the rock five seconds, it cannot get behind her and gives up",
		"at four seconds %s; then route '%s', gone %s" % [early, director.call("committed_route", "L4_SIGBIN"), _sigbin().is_gone()])


func _facing_the_rock_is_not_her_back_to_it() -> void:
	await _stand_at(6812.0, &"move_left")
	await _frames(6 * 60)
	var director = level.get("director")
	_check(not director.call("is_solved", "L4_SIGBIN") and not _sigbin().is_gone(),
		"facing the rock is not her back to it", "solved %s after six seconds" % director.call("is_solved", "L4_SIGBIN"))


## Her back to the rock but 200 px off it: open ground behind her, and it can get round.
func _well_off_the_rock_is_not_against_it() -> void:
	await _stand_at(7010.0, &"move_right")
	await _frames(6 * 60)
	var director = level.get("director")
	_check(not director.call("is_solved", "L4_SIGBIN"), "and nor is standing well off it",
		"solved %s after six seconds, 200 px off the rock" % director.call("is_solved", "L4_SIGBIN"))


func _struck_down_it_is_driven_off() -> void:
	await _stand_at(6950.0, &"move_right")
	await _become("sword")
	level.call("_use_equipped_utility")
	await _frames(10)
	var director = level.get("director")
	var drawn_in := String(director.call("committed_route", "L4_SIGBIN"))
	var solved_by_the_swing := bool(director.call("is_solved", "L4_SIGBIN"))
	var apo := level.get("player") as Node2D
	for _blow in range(_sigbin().max_hp):
		_sigbin().apply_tool_hit("sword", 0.0, apo)
	await _frames(10)
	_check(drawn_in == "protector" and not solved_by_the_swing and director.call("is_solved", "L4_SIGBIN"),
		"struck down, it is driven off -- and the swing that drew the fight in did not end it",
		"committed '%s', solved by the swing %s, then %s" % [drawn_in, solved_by_the_swing, director.call("is_solved", "L4_SIGBIN")])


# --- The tikbalang ---------------------------------------------------------------------------

func _her_x() -> float:
	return (level.get("player") as Node2D).global_position.x


## Holds the keys until she has gone past `past` and come back short of `back`, or `seconds` pass.
## Returns whether she was led back.
func _walk_on(seconds: float, walking: bool, past: float = 9650.0, back: float = 9000.0) -> bool:
	if walking:
		Input.action_press(&"walk")
	Input.action_press(&"move_right")
	var beyond := false
	var returned := false
	for _frame in range(int(seconds * 60.0)):
		await _frames(1)
		beyond = beyond or _her_x() >= past
		if beyond and _her_x() < back:
			returned = true
			break
	Input.action_release(&"move_right")
	Input.action_release(&"walk")
	await _frames(4)
	return returned


func _walking_on_she_comes_back_to_the_rock() -> void:
	await _stand_at(9550.0, &"move_right")
	var led_back := await _walk_on(3.0, false)
	_check(led_back and absf(_her_x() - 8350.0) < 40.0, "walking on past the tikbalang, she comes back to the same rock",
		"led back %s, at %.0f" % [led_back, _her_x()])


func _a_body_with_hooves_is_let_by() -> void:
	await _stand_at(9000.0, &"move_right")
	await _become("horse")
	var director = level.get("director")
	var route := String(director.call("committed_route", "L4_TIKBALANG"))
	var tikbalang := level.get("_tikbalang") as Tikbalang2D
	await _frames(60)
	level.call("_revert_to_base_form")
	await _frames(10)
	await _stand_at(9550.0, &"move_right")
	var led_back := await _walk_on(2.0, false)
	_check(route == "artist" and director.call("is_solved", "L4_TIKBALANG") and tikbalang.is_aside()
			and not led_back and _her_x() > 9750.0,
		"a body with hooves it takes for its own, and the way on is open",
		"route '%s', aside %s, led back %s, at %.0f" % [route, tikbalang.is_aside(), led_back, _her_x()])


func _another_animals_body_is_let_by() -> void:
	await _stand_at(9000.0, &"move_right")
	await _become("monkey")
	var director = level.get("director")
	_check(director.call("committed_route", "L4_TIKBALANG") == "pragmatist" and director.call("is_solved", "L4_TIKBALANG"),
		"any other animal's body it does not chase", "route '%s'" % director.call("committed_route", "L4_TIKBALANG"))


func _a_race_run_flat_out_is_won() -> void:
	await _stand_at(8480.0, &"move_right")
	var offer: Dictionary = level.call("_level_interact_offer")
	level.call("press_interact")
	await _frames(int(1.05 * 60.0))
	await _walk_on(5.5, false)
	var director = level.get("director")
	_check(String(offer.get("verb", "")) == "RACE" and director.call("committed_route", "L4_TIKBALANG") == "protector"
			and director.call("is_solved", "L4_TIKBALANG"),
		"a race to its finish, run the whole way, she wins", "offer %s, route '%s'"
			% [offer, director.call("committed_route", "L4_TIKBALANG")])


func _a_race_walked_is_lost() -> void:
	await _stand_at(8480.0, &"move_right")
	level.call("press_interact")
	await _frames(int(1.05 * 60.0))
	await _walk_on(6.0, true, 9200.0, 8700.0)
	var director = level.get("director")
	var tikbalang := level.get("_tikbalang") as Tikbalang2D
	_check(not director.call("is_solved", "L4_TIKBALANG") and not tikbalang.is_racing() and _her_x() < 8700.0,
		"walked, the race is lost, and she is led back", "solved %s, at %.0f"
			% [director.call("is_solved", "L4_TIKBALANG"), _her_x()])


# --- Helpers -----------------------------------------------------------------------------

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
