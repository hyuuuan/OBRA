extends SceneTree
## PIYESTA'S ALLEYS, PLAYED: the flock, the choice, and the three ways to get the pieces back.
##   godot --headless --path game --script res://tests/run_level2_alley_probe.gd
##
## Kent, on the alleys: the birds "are just perched to the banderitas instead of flying around",
## and there should be three choices -- "throw a rock (this includes a projectile trajectory in
## the game), to feed bread so that the birds will go down, and then to cut the banderitas using
## a ladder and a scissor" -- in "the two areas where the player needs to collect the parts of
## the painting". Every one of those is something a player sees or does, so this does them:
##
##   the flock FLIES -- it wanders the alley and goes home to the strings between flights
##   the choice is asked at the way in, all three ways on it, after Lolo has seen the flock
##   feeding brings every bird down to what was set out, and each leaves its piece beside it
##   cutting takes a climb and an edge: from the floor the strings are out of reach; from the
##     top of the ladder they come down, the nests with them, and every piece flutters down
##   throwing goes where the dotted arc said, a hit brings a bird down, a miss costs a walk
##   nothing is counted until it is walked over, and the way on opens only then
##   and a restore to the choice puts the alley back the way it was
##
## Drawings are handed over through the drawing panel's own door, set down through the
## placement controller, and used with the level's own F. The climb is the wanderer's, held up.

var failures := 0
var level: Node
var director
var player: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-58s %s" % ["OK  " if ok else "FAIL", what, detail])


func _run() -> void:
	print("\n===== LEVEL 2 ALLEYS =====")
	await _audit_the_flock_flies()
	await _audit_the_choice_is_asked_at_the_way_in()
	await _audit_feeding("1")
	await _audit_feeding("2")
	await _audit_cutting("1")
	await _audit_cutting("2")
	await _audit_throwing_stones()
	await _audit_throwing_a_boomerang()
	await _audit_nothing_comes_to_rest_in_a_doorway()
	await _audit_a_restore_puts_the_alley_back()
	print("OBRA_LEVEL2_ALLEY_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)


# --- The flock ---------------------------------------------------------------------------

## ⚠ "PERCHED TO THE BANDERITAS INSTEAD OF FLYING AROUND." Measured over eighteen seconds of the
## alley running: every bird covers real distance, every one goes home to its own nest in the
## strings at least once and sits ON it, none of them spends most of its time sitting, and none
## leaves the alley's air.
func _audit_the_flock_flies() -> void:
	var alley = await _open_at("1", "protector")
	var birds: Array = alley.get("birds")
	var line: BandaritaLine2D = alley.get("line")
	var room := alley.get("room") as PiyestaRoom2D
	var travelled: Dictionary = {}
	var perched_frames: Dictionary = {}
	var off_nest: Array[String] = []
	var out_of_air: Array[String] = []
	var last: Dictionary = {}
	for bird: ScrapBird2D in birds:
		travelled[bird.scrap_id] = 0.0
		perched_frames[bird.scrap_id] = 0
		last[bird.scrap_id] = bird.global_position
	var frames := 18 * 60
	for _frame in range(frames):
		await physics_frame
		for index in range(birds.size()):
			var bird: ScrapBird2D = birds[index]
			travelled[bird.scrap_id] = float(travelled[bird.scrap_id]) \
				+ bird.global_position.distance_to(last[bird.scrap_id])
			last[bird.scrap_id] = bird.global_position
			if bird.is_perched():
				perched_frames[bird.scrap_id] = int(perched_frames[bird.scrap_id]) + 1
				if bird.global_position.distance_to(line.nest_point(index)) > 12.0 \
						and not off_nest.has(bird.scrap_id):
					off_nest.append(bird.scrap_id)
			var up := room.global_position.y - bird.global_position.y
			var across := absf(bird.global_position.x - room.global_position.x)
			if (up < _level_const("FLOCK_LOW") - 2.0 or up > _level_const("ALLEY_LINE") + 20.0
					or across > room.room_length * 0.5) and not out_of_air.has(bird.scrap_id):
				out_of_air.append(bird.scrap_id)
	var still: Array[String] = []
	var never_home: Array[String] = []
	var sitters: Array[String] = []
	for bird: ScrapBird2D in birds:
		if float(travelled[bird.scrap_id]) < 400.0:
			still.append("%s %.0fpx" % [bird.scrap_id, travelled[bird.scrap_id]])
		if int(perched_frames[bird.scrap_id]) == 0:
			never_home.append(bird.scrap_id)
		if int(perched_frames[bird.scrap_id]) > frames / 2:
			sitters.append(bird.scrap_id)
	_check(still.is_empty(), "the flock flies the alley, all five of them",
		"every one covered 400px or more in 18s" if still.is_empty() else ", ".join(still))
	_check(never_home.is_empty(), "and every one goes home to the strings between flights",
		"all perched at least once" if never_home.is_empty() else "never: %s" % ", ".join(never_home))
	_check(off_nest.is_empty(), "sitting ON its own nest, riding the line",
		"within 12px of it" if off_nest.is_empty() else ", ".join(off_nest))
	_check(sitters.is_empty(), "and none of them is perched most of the time",
		"perched frames: %s" % str(perched_frames))
	_check(out_of_air.is_empty(), "and none leaves the alley's air",
		"above the apo, under the strings, between the walls" if out_of_air.is_empty()
		else ", ".join(out_of_air))
	var holding := 0
	for bird: ScrapBird2D in birds:
		if bird.is_holding():
			holding += 1
	_check(holding == birds.size(), "each with its piece of the painting in its beak",
		"%d of %d" % [holding, birds.size()])
	await _close()


# --- The choice ------------------------------------------------------------------------------

## The three ways are offered at the way in -- after Lolo has seen the flock, with the verbs they
## need already taught -- and nothing is judged before one of them is chosen.
func _audit_the_choice_is_asked_at_the_way_in() -> void:
	for which in ["1", "2"]:
		level = await _open()
		director = level.get("director")
		await _walk_into_alley(which)
		var ob := _obstacle_of(which)
		var choice := level.get_node_or_null(^"DialogueChoiceOverlay")
		var asked := await _wait_for_choice()
		_check(asked, "Alley %s: walking in asks how" % which,
			"the choice is up" if asked else "NOTHING ASKED -- the alley has no way in")
		_check(String(level.call("_dialogue_node_obstacle_id")) == ob,
			"Alley %s: and it is asking for %s" % [which, ob],
			String(level.call("_dialogue_node_obstacle_id")))
		var choices: Dictionary = (level.get("script_lines") as Object).call("choices_for", ob)
		_check(choices.size() == 3, "Alley %s: with all three ways on it" % which,
			", ".join(PackedStringArray(choices.values())))
		_check(bool((level.get("script_lines") as Object).call("has_heard", "%s.enter" % ob)),
			"Alley %s: after Lolo has seen the flock" % which, "%s.enter was said first" % ob)
		var untaught: Array[String] = []
		var tags := root.get_node("AbilityTags")
		for tag in ["feed", "climb", "cut", "strike"]:
			if not bool(tags.call("is_unlocked", tag)):
				untaught.append(tag)
		_check(untaught.is_empty(), "Alley %s: every verb on it already taught" % which,
			"feed, climb, cut, strike" if untaught.is_empty() else "untaught: %s" % untaught)
		# Nothing drawn counts before the choice. The director judges an uncommitted beat by every
		# route's tags at once, exclusions ignored, which is how a beat gets solved by no route.
		if choice != null and bool(choice.call("is_open")):
			choice.call("close")
			UIRouter.refresh_pause(self)
			paused = false
		level.call("_judge_submission", "bread")
		await _frames(4)
		_check(not director.is_solved(ob) and String(director.committed_route(ob)).is_empty(),
			"Alley %s: and nothing drawn counts before the choice" % which,
			"refused, and asked again" if not director.is_solved(ob) else "SOLVED BY NO ROUTE")
		await _close()


# --- Feeding -------------------------------------------------------------------------------

func _audit_feeding(which: String) -> void:
	var alley = await _open_at(which, "artist")
	var ob := _obstacle_of(which)
	var birds: Array = alley.get("birds")
	var held_before: int = level.get("ledger").call("held")
	_draw("bread")
	await _frames(4)
	# Well clear of the apo, so no piece lands where they are standing and is picked up at once.
	var apo_x := player.global_position.x
	var set_at := player.global_position + Vector2(280.0, -30.0)
	await _place("bread", set_at)
	var bread := _placed("bread")
	_check(director.is_solved(ob), "Alley %s: something to eat set down answers it" % which,
		"feed" if director.is_solved(ob) else "NOT ANSWERED")
	var coming := 0
	for bird: ScrapBird2D in birds:
		if bird.state() == ScrapBird2D.State.DESCENDING:
			coming += 1
	_check(coming == birds.size(), "Alley %s: and every bird comes down to it" % which,
		"%d of %d on the way down" % [coming, birds.size()])
	await _until(func() -> bool: return (alley.get("dropped") as Dictionary).size() >= birds.size(), 900)
	var eating := 0
	var facing_it := 0
	var far: Array[String] = []
	var under: Array[String] = []
	var past: Array[String] = []
	var food := bread.world_extent() if bread != null else Rect2()
	for bird: ScrapBird2D in birds:
		if bird.state() == ScrapBird2D.State.CALMED:
			eating += 1
		if _faces(bird, food.get_center().x):
			facing_it += 1
	for piece: Node2D in (alley.get("pieces") as Dictionary).values():
		var x := piece.global_position.x
		if absf(x - food.get_center().x) > 420.0:
			far.append("%.0f" % x)
		# ⚠ NOT UNDER IT, AND NOT PAST IT. What was set down is solid -- a piece beneath it can
		# only be reached by climbing onto it, and one beyond it only by getting over it. Both
		# found by the play bot.
		if x >= food.position.x - 10.0 and x <= food.end.x + 10.0:
			under.append("%.0f" % x)
		elif signf(x - food.get_center().x) != signf(apo_x - food.get_center().x):
			past.append("%.0f" % x)
	_check(eating == birds.size(), "Alley %s: they land and eat" % which,
		"%d eating" % eating)
	_check(facing_it == birds.size(), "Alley %s: every one of them facing it" % which,
		"%d of %d" % [facing_it, birds.size()])
	var lying := (alley.get("pieces") as Dictionary).size()
	var picked := int(level.get("ledger").call("held")) - held_before
	_check(lying + picked == birds.size() and far.is_empty(),
		"Alley %s: and every piece is left on the floor by it" % which,
		"%d lying there, %d already walked over, all near it" % [lying, picked]
		if far.is_empty() else "far off: %s" % ", ".join(far))
	_check(under.is_empty(), "Alley %s: and none of them under it" % which,
		"clear of %.0f..%.0f" % [food.position.x, food.end.x] if under.is_empty()
		else "under it at %s" % ", ".join(under))
	_check(past.is_empty(), "Alley %s: or past it from the apo" % which,
		"all on the apo's side" if past.is_empty() else "beyond it at %s" % ", ".join(past))
	await _collect_and_leave(alley, which, held_before)
	await _close()


# --- Cutting ---------------------------------------------------------------------------------

func _audit_cutting(which: String) -> void:
	var alley = await _open_at(which, "pragmatist")
	var ob := _obstacle_of(which)
	var birds: Array = alley.get("birds")
	var line: BandaritaLine2D = alley.get("line")
	var held_before: int = level.get("ledger").call("held")
	var script_lines = level.get("script_lines")
	# Half one: something to climb, set under the strings.
	_draw("ladder")
	await _frames(4)
	await _place("ladder", Vector2(line.middle().x, player.global_position.y - 60.0))
	_check(director.stage(ob) == 1 and not director.is_solved(ob),
		"Alley %s: the climb is the first half, not the whole" % which,
		"stage %d" % director.stage(ob))
	var climbed_hook := "%s.pragmatist.climbed" % ob
	_check(bool(script_lines.call("has_heard", climbed_hook)),
		"Alley %s: and Lolo says what the second half is" % which, climbed_hook)
	# Half two: something to cut with. Drawn now, it goes straight into the hand.
	_draw("scissors")
	await _frames(10)
	var held := level.get("_equipped_utility") as UtilityObject
	_check(held != null and held.item_data.entity_id == "scissors",
		"Alley %s: the edge goes straight into the hand" % which,
		held.item_data.entity_id if held != null else "NOTHING IN HAND")
	# From the floor the strings are out of reach -- the whole reason for the climb.
	level.call("_use_equipped_utility")
	await _frames(4)
	var said := String((level.get("hint_bar") as HintBar).current_text())
	_check(not director.is_solved(ob) and not line.is_cut(),
		"Alley %s: from the floor the strings are out of reach" % which,
		"refused: \"%s\"" % said if not director.is_solved(ob) else "CUT FROM THE FLOOR")
	_check(said.contains("reach"), "Alley %s: and it says so" % which, "\"%s\"" % said)
	# Up the ladder, the way a player climbs: stand on it and hold up.
	var ladder := _placed("ladder")
	player.global_position = Vector2(ladder.global_position.x, player.global_position.y)
	await _frames(20)
	Input.action_press(&"move_up")
	await _frames(240)
	held = level.get("_equipped_utility") as UtilityObject
	var reach := line.reach_distance(held.global_position) if held != null else INF
	_check(reach <= _level_const("CUT_REACH"), "Alley %s: from the top of the ladder it can reach" % which,
		"%.0fpx from the strings" % reach)
	level.call("_use_equipped_utility")
	Input.action_release(&"move_up")
	await _frames(4)
	_check(director.is_solved(ob) and line.is_cut(), "Alley %s: and the strings come down" % which,
		"cut" if line.is_cut() else "STILL UP")
	var bolting := 0
	for bird: ScrapBird2D in birds:
		if bird.state() == ScrapBird2D.State.FLEEING and not bird.is_holding():
			bolting += 1
	_check(bolting == birds.size(), "Alley %s: every bird bolts and lets go" % which,
		"%d of %d" % [bolting, birds.size()])
	_check(not _still_holds("scissors"), "Alley %s: the edge is used up" % which, "one use")
	await _frames(2)
	var restrictions = level.get("restrictions")
	_check(float(restrictions.call("ceiling")) == -INF,
		"Alley %s: and the alley's sky is open" % which,
		"no cap under strings that are not there")
	await _until(func() -> bool: return (alley.get("dropped") as Dictionary).size() >= birds.size(), 600)
	_check((alley.get("pieces") as Dictionary).size() == birds.size(),
		"Alley %s: every piece flutters down to the floor" % which,
		"%d of %d lying there" % [(alley.get("pieces") as Dictionary).size(), birds.size()])
	# ⚠ AND NOT UNDER THE LADDER. It is solid until it is climbed: a piece that came down at its
	# foot lay out of reach of anywhere the apo could stand. Found by the play bot.
	var foot := ladder.world_extent()
	var out_from_under := float(level.call("_clear_of_drawings", alley, foot.get_center().x))
	_check(out_from_under < foot.position.x - 15.0 or out_from_under > foot.end.x + 15.0,
		"Alley %s: one that comes down under the ladder slides out from under it" % which,
		"to %.0f, the ladder stands %.0f..%.0f" % [out_from_under, foot.position.x, foot.end.x])
	player.call("end_ladder")
	await _frames(90)
	await _collect_and_leave(alley, which, held_before)
	# ⚠ THE LADDER IS STILL STANDING IN THE MIDDLE OF THE ALLEY, solid, with the way on past it.
	# Found by the play bot, stopped at its foot. Walked up to on the way out, it says what to do.
	var room := alley.get("room") as PiyestaRoom2D
	var stood := ladder.world_extent()
	player.global_position = Vector2(stood.position.x - 24.0, room.global_position.y)
	await _frames(6)
	var told := String((level.get("hint_bar") as HintBar).current_text())
	_check(told.contains("in the way") and told.contains("climb over it"),
		"Alley %s: the ladder in the way on says how past it" % which, "\"%s\"" % told)
	level.call("press_interact")
	await _frames(6)
	_check(_slot_of("ladder") >= 0, "Alley %s: and E takes it back" % which, "in the bag")
	await _close()


# --- Throwing --------------------------------------------------------------------------------

## A drawn round shape is a stone in the hand; the arc it shows is the flight it takes; a miss
## lies where it landed and is walked back to; every hit brings a bird down.
func _audit_throwing_stones() -> void:
	var alley = await _open_at("1", "protector")
	var ob := "L2_N2"
	var birds: Array = alley.get("birds")
	var thrower: StoneThrow2D = alley.get("thrower")
	thrower.follow_mouse = false
	var ink = level.get("ink_manager")
	var ink_before: float = ink.call("remaining")
	_draw("circle")
	await _frames(4)
	_check(thrower.stone_in_hand() and _slot_of("circle") < 0,
		"a round shape drawn here is a stone in the hand", "not the bag")
	_check(is_equal_approx(float(ink.call("remaining")), ink_before - 1.0),
		"and it costs what setting a shape down costs", "one unit")
	_check(director.stage(ob) == 1, "and drawing it is the first half of the route",
		"stage %d" % director.stage(ob))
	_check(String(level.call("_current_objective").get("key", "")) == "flock_aim",
		"the objective says how to throw", String(level.call("objective_text",
			level.call("_current_objective"))))
	# The arc is where the throw goes: lobbed low along the floor, under the flock, it lands
	# where the dots end.
	var room := alley.get("room") as PiyestaRoom2D
	var hand: Vector2 = level.call("_throwing_hand")
	thrower.aim_at(hand + Vector2(140.0, -40.0))
	await _frames(1)
	var arc := thrower.trajectory(thrower.current_velocity(), 4.0)
	_check(arc.size() > 2 and arc[0].distance_to(level.call("_throwing_hand")) < 1.0,
		"the dotted arc starts in the hand", "%d dots" % arc.size())
	level.call("_use_equipped_utility")
	await _until(func() -> bool: return not thrower.in_flight(), 240)
	var landed := thrower.resting_stone()
	_check(thrower.stone_on_the_floor() and absf(landed.x - arc[arc.size() - 1].x) <= 2.0,
		"and a miss lands where the arc said", "%.0f against %.0f" % [landed.x, arc[arc.size() - 1].x]
		if thrower.stone_on_the_floor() else "NOT ON THE FLOOR")
	_check(String(level.call("_current_objective").get("key", "")) == "flock_fetch",
		"and the objective points at it", String(level.call("objective_text",
			level.call("_current_objective"))))
	var ink_mid: float = ink.call("remaining")
	_draw("circle")
	await _frames(4)
	_check(is_equal_approx(float(ink.call("remaining")), ink_mid) and thrower.stone_on_the_floor(),
		"a second stone is not sold while the first is lying there", "free, and refused")
	player.global_position = Vector2(landed.x, player.global_position.y)
	await _frames(6)
	_check(thrower.stone_in_hand(), "walking over it picks it back up", "in hand again")
	# Now every bird, each at rest on its nest. A throw that brings nothing down is a miss -- a
	# bird can leave its nest while the stone is in the air -- and it costs a walk, not a bird.
	var throws := 0
	var hits := 0
	var doubles := 0
	for _round in range(120):
		if director.is_solved(ob):
			break
		var target := _perched(birds)
		if target == null:
			await _frames(8)
			continue
		player.global_position = Vector2(clampf(target.global_position.x - 90.0,
			room.global_position.x - 400.0, room.global_position.x + 400.0), player.global_position.y)
		await _frames(4)
		if not target.is_perched():
			continue
		if not thrower.stone_in_hand():
			await _fetch(thrower)
			continue
		var aim := _aim_for(thrower, target.global_position)
		if not aim.is_finite():
			await _frames(20)
			continue
		thrower.aim_at(aim)
		var down_before := _down(birds)
		level.call("_use_equipped_utility")
		throws += 1
		await _until(func() -> bool: return not thrower.in_flight(), 240)
		var downed := _down(birds) - down_before
		if downed > 0:
			hits += 1
		if downed > 1:
			doubles += 1
		await _fetch(thrower)
	_check(director.is_solved(ob), "every bird knocked down answers it",
		"%d throws, %d hits" % [throws, hits] if director.is_solved(ob)
		else "STILL UP after %d throws" % throws)
	_check(hits == birds.size() and doubles == 0,
		"one bird to a throw, and every bird took one", "%d hits" % hits)
	_check(throws <= birds.size() * 3, "and a throw along the arc at a bird at rest hits it",
		"%d throws for %d birds" % [throws, birds.size()])
	_check(thrower.kind == StoneThrow2D.Kind.NONE and not thrower.has_stone(),
		"and the stone is put away", "nothing left to throw")
	var dazed_then_gone := true
	await _frames(240)
	for bird: ScrapBird2D in birds:
		if bird.state() != ScrapBird2D.State.GONE:
			dazed_then_gone = false
	_check(dazed_then_gone, "a struck bird shakes it off and goes, it is not killed",
		"every one flew off")
	await _collect_and_leave(alley, "1", 0)
	await _close()


## The boomerang, thrown the same way from the hand: its first throw is the answer, it comes back
## every time, and it is spent once the flock is down.
func _audit_throwing_a_boomerang() -> void:
	var alley = await _open_at("2", "protector")
	var ob := "L2_N3"
	var birds: Array = alley.get("birds")
	var thrower: StoneThrow2D = alley.get("thrower")
	thrower.follow_mouse = false
	var room := alley.get("room") as PiyestaRoom2D
	var held_before: int = level.get("ledger").call("held")
	_draw("boomerang")
	await _frames(10)
	var held := level.get("_equipped_utility") as UtilityObject
	_check(held != null and held.item_data.entity_id == "boomerang",
		"Alley 2: a boomerang drawn here goes into the hand", "ready to throw")
	_check(thrower.kind == StoneThrow2D.Kind.BOOMERANG and thrower.ready_to_throw(),
		"Alley 2: and the arc is up", "thrown from the hand")
	var came_back := true
	var throws := 0
	for _round in range(120):
		if director.is_solved(ob):
			break
		var target := _perched(birds)
		if target == null:
			await _frames(8)
			continue
		player.global_position = Vector2(clampf(target.global_position.x - 90.0,
			room.global_position.x - 400.0, room.global_position.x + 400.0), player.global_position.y)
		await _frames(4)
		if not target.is_perched() or not thrower.ready_to_throw():
			await _frames(6)
			continue
		var aim := _aim_for(thrower, target.global_position)
		if not aim.is_finite():
			await _frames(20)
			continue
		thrower.aim_at(aim)
		level.call("_use_equipped_utility")
		throws += 1
		if throws == 1:
			_check(director.stage(ob) == 1, "Alley 2: its first throw is the first half",
				"stage %d" % director.stage(ob))
		await _until(func() -> bool: return not thrower.in_flight(), 360)
		if thrower.in_flight():
			came_back = false
	_check(director.is_solved(ob), "Alley 2: both knocked down answers it", "%d throws" % throws)
	_check(came_back, "Alley 2: and it came back to the hand every time", "never lost")
	_check(not _still_holds("boomerang"), "Alley 2: and once the flock is down it is spent",
		"one use, and the use was the flock")
	await _collect_and_leave(alley, "2", held_before)
	await _close()


# --- The doorways ----------------------------------------------------------------------------

## ⚠ FOUND BY THE PLAY BOT. Something to eat set down by the way in brought the flock down by
## the wall, and two pieces landed in the doorway: walking in to pick them up walked the apo out
## into the church, and they were still lying there when the apo came back. Every piece, and
## the stone, comes to rest on the floor between the two doorways -- and is picked up there
## without leaving the alley.
func _audit_nothing_comes_to_rest_in_a_doorway() -> void:
	var alley = await _open_at("1", "artist")
	var room := alley.get("room") as PiyestaRoom2D
	var birds: Array = alley.get("birds")
	var left := room.global_position.x + room.exit_rect().end.x
	var right := room.global_position.x + room.onward_rect().position.x
	_draw("bread")
	await _frames(4)
	# As far back toward the way in as the room lets it go.
	await _place("bread", Vector2(room.global_position.x - room.room_length * 0.5,
		player.global_position.y - 30.0))
	await _until(func() -> bool: return (alley.get("dropped") as Dictionary).size() >= birds.size(), 900)
	var in_a_doorway: Array[String] = []
	for piece: Node2D in (alley.get("pieces") as Dictionary).values():
		if piece.global_position.x - 15.0 <= left or piece.global_position.x + 15.0 >= right:
			in_a_doorway.append("%.0f" % piece.global_position.x)
	_check(in_a_doorway.is_empty(), "fed by the way in, no piece lands in the doorway",
		"between %.0f and %.0f" % [left, right] if in_a_doorway.is_empty()
		else "in a doorway at %s" % ", ".join(in_a_doorway))
	var left_the_alley := false
	for _i in range(20):
		var pieces: Dictionary = alley.get("pieces")
		if pieces.is_empty():
			break
		var piece: Node2D = pieces.values()[0]
		player.global_position = Vector2(piece.global_position.x, player.global_position.y)
		await _frames(8)
		if level.call("_room_holding_player") != room:
			left_the_alley = true
			break
	_check(not left_the_alley and (alley.get("pieces") as Dictionary).is_empty(),
		"and every one is picked up without leaving the alley",
		"all of them, still in the alley" if not left_the_alley else "WALKED OUT INTO THE CHURCH")
	await _close()

	# A bird knocked down at either end of the alley: its piece comes down out of the doorway.
	alley = await _open_at("1", "protector")
	room = alley.get("room") as PiyestaRoom2D
	birds = alley.get("birds")
	right = room.global_position.x + room.onward_rect().position.x
	for index in [0, 1]:
		var bird: ScrapBird2D = birds[index]
		bird.set_physics_process(false)
		bird.position = Vector2(bird.airspace.position.x if index == 0 else bird.airspace.end.x,
			-150.0)
		bird.set("_facing", -1.0 if index == 0 else 1.0)
		bird.set_physics_process(true)
		bird.strike_down()
	await _until(func() -> bool: return (alley.get("dropped") as Dictionary).size() >= 2, 300)
	var at_the_ends: Array[String] = []
	for piece: Node2D in (alley.get("pieces") as Dictionary).values():
		if piece.global_position.x - 15.0 <= left or piece.global_position.x + 15.0 >= right:
			at_the_ends.append("%.0f" % piece.global_position.x)
	_check((alley.get("pieces") as Dictionary).size() == 2 and at_the_ends.is_empty(),
		"knocked down at either end, no piece lands in the doorway",
		"both between %.0f and %.0f" % [left, right] if at_the_ends.is_empty()
		else "in a doorway at %s" % ", ".join(at_the_ends))
	await _close()

	# A stone thrown into the far doorway rolls back out of it.
	alley = await _open_at("1", "protector")
	room = alley.get("room") as PiyestaRoom2D
	right = room.global_position.x + room.onward_rect().position.x
	var thrower: StoneThrow2D = alley.get("thrower")
	thrower.follow_mouse = false
	_draw("circle")
	await _frames(4)
	# From the far end of the floor, hard at the far wall: it comes down in the doorway.
	player.global_position = Vector2(room.global_position.x + 250.0, player.global_position.y)
	await _frames(6)
	thrower.aim_at(level.call("_throwing_hand") + Vector2(400.0, -80.0))
	level.call("_use_equipped_utility")
	await _until(func() -> bool: return not thrower.in_flight(), 300)
	var landed := thrower.resting_stone()
	await _frames(60)
	var rest := thrower.resting_stone()
	_check(landed.x + 15.0 >= right and thrower.stone_on_the_floor() and rest.x + 15.0 < right,
		"a stone thrown into a doorway rolls back out of it",
		"came down at %.0f, at rest at %.0f; the doorway starts at %.0f" % [
			landed.x, rest.x, right])
	player.global_position = Vector2(rest.x, player.global_position.y)
	await _frames(8)
	_check(thrower.stone_in_hand() and level.call("_room_holding_player") == room,
		"and is picked up without leaving the alley", "in hand, in the alley")
	await _close()


# --- A restore -------------------------------------------------------------------------------

## The checkpoint is written at the choice and again once every piece is in hand. A restore to the
## first puts the alley back as it was then: every piece back in a beak, nothing on the floor, no
## stone -- and the ink the stone cost given back with the rest.
func _audit_a_restore_puts_the_alley_back() -> void:
	var alley = await _open_at("1", "protector")
	var ob := "L2_N2"
	var birds: Array = alley.get("birds")
	var ledger = level.get("ledger")
	var ink = level.get("ink_manager")
	var ink_at_choice: float = ink.call("remaining")
	_draw("circle")
	await _frames(4)
	(birds[0] as ScrapBird2D).strike_down()
	(birds[1] as ScrapBird2D).strike_down()
	await _until(func() -> bool: return (alley.get("dropped") as Dictionary).size() >= 2, 300)
	var piece: Node2D = (alley.get("pieces") as Dictionary).values()[0]
	player.global_position = Vector2(piece.global_position.x, player.global_position.y)
	await _frames(6)
	_check(int(ledger.call("held")) == 1, "a restore: one piece picked up, one lying there",
		"%d held, %d on the floor" % [int(ledger.call("held")),
			(alley.get("pieces") as Dictionary).size()])
	level.call("_restore_checkpoint")
	await _frames(4)
	var holding := 0
	for bird: ScrapBird2D in birds:
		if bird.is_holding() and bird.is_airborne():
			holding += 1
	_check(int(ledger.call("held")) == 0 and holding == birds.size(),
		"a restore to the choice puts every piece back in a beak",
		"%d held, %d birds up with theirs" % [int(ledger.call("held")), holding])
	_check((alley.get("pieces") as Dictionary).is_empty() and not (alley.get("thrower") as StoneThrow2D).has_stone(),
		"and nothing is left lying there, stone included", "the alley as it was at the choice")
	_check(director.stage(ob) == 0 and is_equal_approx(float(ink.call("remaining")), ink_at_choice),
		"and the stone's ink comes back with the stage", "stage %d, %.0f ink" % [director.stage(ob),
			float(ink.call("remaining"))])
	await _close()


# --- Harness -----------------------------------------------------------------------------

## A fresh Piyesta with the church done: the candle on the rack and the far door open.
func _open() -> Node:
	var fresh := (load("res://level_2.tscn") as PackedScene).instantiate()
	(fresh.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(fresh)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(30)
	fresh.set("_has_kandila", true)
	(fresh.get("chancel") as ChurchInterior2D).kandila_on_rack = true
	(fresh.get("church") as PiyestaRoom2D).open_onward()
	return fresh


## Into an alley through its doorway, the way a player arrives. Alley 2 is reached through Alley
## 1, which is finished by feeding it -- its own audit is above.
func _walk_into_alley(which: String) -> void:
	player = level.get("player") as Node2D
	level.call("_go_onward", level.get("church"))
	await _frames(20)
	if which == "1":
		return
	await _choose("artist")
	_draw("bread")
	await _frames(4)
	await _place("bread", player.global_position + Vector2(170.0, -30.0))
	var first = level.get("_alleys")["L2_N2"]
	await _until(func() -> bool: return (first.get("dropped") as Dictionary).size() >= 5, 900)
	await _pick_up_everything(first)
	level.call("_go_onward", level.get("alley_1"))
	await _frames(20)


func _open_at(which: String, route: String):
	level = await _open()
	director = level.get("director")
	await _walk_into_alley(which)
	await _choose(route)
	player = level.get("player") as Node2D
	return level.get("_alleys")[_obstacle_of(which)]


func _close() -> void:
	Input.action_release(&"move_up")
	if level != null and is_instance_valid(level):
		level.queue_free()
	await process_frame
	await process_frame
	paused = false


## The level's own numbers -- the flock's air, the strings, how close an edge has to be -- read
## off the running level's script rather than copied, so a retune cannot leave this checking the
## old ones. (Not preloaded: level_2.gd names the autoloads, which a `--script` run has not
## registered when it compiles its own dependencies.)
func _level_const(name: String) -> float:
	return float((level.get_script() as Script).get_script_constant_map().get(name, NAN))


func _obstacle_of(which: String) -> String:
	return "L2_N2" if which == "1" else "L2_N3"


func _wait_for_choice() -> bool:
	var choice := level.get_node_or_null(^"DialogueChoiceOverlay")
	for _i in range(600):
		if choice != null and bool(choice.call("is_open")):
			return true
		await physics_frame
	return false


func _choose(route: String) -> void:
	if not await _wait_for_choice():
		return
	var choice := level.get_node_or_null(^"DialogueChoiceOverlay")
	choice.call("_on_route_pressed", route)
	await _frames(10)


func _draw(entity_id: String) -> void:
	level.call("_on_drawing_ready", entity_id, entity_id.capitalize(),
		Image.create(28, 28, false, Image.FORMAT_RGBA8), {"confidence": 0.9}, [], 1.0)


func _slot_of(entity_id: String) -> int:
	return int(level.call("_slot_holding", entity_id))


func _still_holds(entity_id: String) -> bool:
	var held := level.get("_equipped_utility") as UtilityObject
	var in_hand := held != null and is_instance_valid(held) and held.item_data != null \
		and held.item_data.entity_id == entity_id
	return in_hand or _slot_of(entity_id) >= 0


func _place(entity_id: String, at: Vector2) -> void:
	var slot := _slot_of(entity_id)
	if slot < 0:
		return
	level.call("_on_inventory_slot_pressed", slot)
	await _frames(2)
	var placement := level.get("placement_controller") as Node2D
	placement.set_process(false)
	placement.call("update_target", at)
	await _frames(4)
	placement.call("confirm_placement")
	placement.set_process(true)
	await _frames(10)


## The newest drawing of `entity_id` set down. The newest, because both alleys are at the same x
## and the way into Alley 2 feeds Alley 1 -- the first bread found was the other alley's.
func _placed(entity_id: String) -> PhysicsShapeObject:
	var newest: PhysicsShapeObject = null
	for item in (level.get("world_item_root") as Node).get_children():
		var drawn := item as PhysicsShapeObject
		if drawn != null and drawn.item_data != null and drawn.item_data.entity_id == entity_id:
			newest = drawn
	return newest


## Walk over every piece lying on the floor, the nearest first.
func _pick_up_everything(alley) -> void:
	for _i in range(20):
		var pieces: Dictionary = alley.get("pieces")
		if pieces.is_empty():
			return
		var piece: Node2D = pieces.values()[0]
		player.global_position = Vector2(piece.global_position.x, player.global_position.y)
		await _frames(6)


## NOTHING COUNTS UNTIL IT IS WALKED OVER, and the way on opens only once all of it is in hand.
func _collect_and_leave(alley, which: String, held_before: int) -> void:
	var ledger = level.get("ledger")
	var room := alley.get("room") as PiyestaRoom2D
	var count: int = (alley.get("scraps") as PackedStringArray).size()
	var before: int = ledger.call("held")
	_check(not room.onward_open, "Alley %s: the way on stays shut until they are picked up" % which,
		"%d of %d in hand" % [before - held_before, count])
	await _pick_up_everything(alley)
	await _frames(4)
	_check(int(ledger.call("held")) == held_before + count,
		"Alley %s: walking over the pieces picks every one up" % which,
		"%d of %d" % [int(ledger.call("held")) - held_before, count])
	_check(room.onward_open, "Alley %s: and then the way on opens" % which,
		"open" if room.onward_open else "STILL SHUT")
	var checkpoints = level.get("checkpoints")
	var saved: Dictionary = checkpoints.call("peek")
	var kept: Array = ((saved.get("level", {}) as Dictionary).get("scraps", {}) as Dictionary).get("held", [])
	_check(kept.size() == held_before + count,
		"Alley %s: and the checkpoint is written again with them in hand" % which,
		"%d in the snapshot" % kept.size())


## Whether a bird on the floor is turned toward `x`. Read off the bird's own facing, which is
## what its drawing is flipped by.
func _faces(bird: ScrapBird2D, x: float) -> bool:
	var facing := float(bird.get("_facing"))
	return facing == (1.0 if x >= bird.global_position.x else -1.0)


func _down(birds: Array) -> int:
	var count := 0
	for bird: ScrapBird2D in birds:
		if bird.is_answered():
			count += 1
	return count


func _perched(birds: Array) -> ScrapBird2D:
	for bird: ScrapBird2D in birds:
		if bird.is_perched():
			return bird
	return null


func _fetch(thrower: StoneThrow2D) -> void:
	if not thrower.stone_on_the_floor():
		return
	player.global_position = Vector2(thrower.resting_stone().x, player.global_position.y)
	await _frames(6)


## An aim point whose arc passes through `target`, searched the way a player searches: along
## the directions and strengths the pointer can give.
func _aim_for(thrower: StoneThrow2D, target: Vector2) -> Vector2:
	var hand: Vector2 = level.call("_throwing_hand")
	var best := Vector2.INF
	var best_miss := INF
	for step in range(0, 120):
		var angle := deg_to_rad(-178.0 + step * (176.0 / 120.0))
		for pull in range(4, 40):
			var point := hand + Vector2.from_angle(angle) * (pull * 10.0)
			var miss := INF
			for at in thrower.trajectory(thrower.velocity_for(point), 2.0):
				miss = minf(miss, at.distance_to(target))
			if miss < best_miss:
				best_miss = miss
				best = point
	return best if best_miss < 12.0 else Vector2.INF


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func _until(done: Callable, limit: int) -> void:
	for _frame in range(limit):
		if bool(done.call()):
			return
		await physics_frame
