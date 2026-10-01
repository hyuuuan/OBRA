extends SceneTree
## Level 2's own systems, driven headlessly:
##   godot --headless --path game --script res://tests/run_level2_systems_probe.gd
##
## These carry the promises the level config only declares. The audit can check that
## `restrictions` names real classes; only this can check that the ceiling actually bites,
## that a banned class is refused rather than punished, that every way a bird comes down puts
## its piece on the floor, and that a throw goes where its arc said it would.

const RestrictionsClass = preload("res://scripts/level_restrictions.gd")
const LedgerClass = preload("res://scripts/scrap_ledger.gd")
const DanceClass = preload("res://scripts/dance_minigame.gd")
const BirdClass = preload("res://scripts/scrap_bird_2d.gd")
const LineClass = preload("res://scripts/bandarita_line_2d.gd")
const ThrowClass = preload("res://scripts/stone_throw_2d.gd")
const AssemblyClass = preload("res://scripts/scrap_assembly.gd")

const LEVEL_PATH := "res://config/level_02.json"
const ENTITIES_PATH := "res://config/entities.json"

var results: Array[String] = []
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	results.append("  %s  %-38s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _load(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _roster_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for entity_value: Variant in _load(ENTITIES_PATH).get("entities", []):
		out.append(String((entity_value as Dictionary).get("id", "")))
	return out


func _run() -> void:
	print("\n===== LEVEL 2 SYSTEMS =====")
	_probe_restrictions()
	_probe_ceiling()
	_probe_ledger()
	_probe_dance()
	await _probe_birds()
	await _probe_every_way_down()
	await _probe_the_throw()
	_probe_assembly()
	for line in results:
		print(line)
	# `quit()` schedules the exit; it does not return, so without the else this printed
	# both the OK marker and FAILED=0 on a clean run. A grep for either then answers yes.
	if failures == 0:
		print("OBRA_LEVEL2_SYSTEMS_OK")
		quit(0)
	else:
		print("OBRA_LEVEL2_SYSTEMS_FAILED=%d" % failures)
		quit(1)


## The one route in this project answered by something other than a drawing. What has to be
## true of it is not that it is fun -- it is that it CANNOT DEAD-END THE RUN.
func _probe_dance() -> void:
	var beats := PackedFloat32Array([1.0, 2.0, 3.0, 4.0, 5.0])

	# Cleared first go.
	var d = DanceClass.new(); root.add_child(d)
	d.set_track(beats); d.begin_attempt()
	for i in range(5):
		d.judge(i, beats[i] + 0.05)
	_check(d.perfect_count() == 5, "a stroke on the beat is perfect", "5 of 5")
	_check(d.end_attempt(), "clearing it ends the run", "one attempt")
	_check(d.cleared() and d.flower_earned() and d.kandila_earned(),
		"cleared in one gives both", "kandila and flower")
	d.queue_free()

	# Early and late still count -- the bar names them so the player learns which way.
	d = DanceClass.new(); root.add_child(d)
	d.set_track(beats); d.begin_attempt()
	_check(d.judge(0, beats[0] - 0.25) == "early", "a stroke before the beat reads early", "-0.25s")
	_check(d.judge(1, beats[1] + 0.25) == "late", "and after it reads late", "+0.25s")
	_check(d.judge(2, beats[2] + 1.20) == "miss", "far enough out is a miss", "+1.20s")
	_check(d.landed() == 2, "early and late still land", "2 landed, 1 missed")
	d.queue_free()

	# Failed twice: the flower is withheld and NOTHING ELSE IS.
	d = DanceClass.new(); root.add_child(d)
	d.set_track(beats)
	d.begin_attempt()
	for i in range(5):
		d.judge(i, beats[i] + 4.0)
	_check(not d.end_attempt(), "failing the first go does not end it", "one left")
	_check(d.attempts_left() == 1, "and says so", "%d left" % d.attempts_left())
	d.begin_attempt()
	for i in range(5):
		d.judge(i, beats[i] + 4.0)
	_check(d.end_attempt(), "failing the second ends it", "both used")
	_check(not d.flower_earned(), "the flower is withheld", "three routes lose it, all silently")
	_check(d.kandila_earned(),
		"BUT THE KANDILA IS NOT", "the level cannot dead-end -- only the flower is at stake")
	d.queue_free()

	# A third go is not on offer.
	d = DanceClass.new(); root.add_child(d)
	d.set_track(beats)
	d.begin_attempt(); d.end_attempt(); d.begin_attempt(); d.end_attempt()
	var before: int = d.attempts_used()
	d.begin_attempt()
	_check(d.attempts_used() == before and d.is_finished(),
		"a third attempt is refused", "%d used, finished" % d.attempts_used())
	d.queue_free()


## An alley in miniature: a floor at y = 0 in `holder`, a line strung 320 above it, and a flock
## nesting in it -- the same shapes the level builds, without the level.
func _flock(holder: Node2D, count: int = 5) -> Array:
	var line = LineClass.new()
	line.span = 780.0
	line.nest_count = count
	line.position = Vector2(0.0, -320.0)
	holder.add_child(line)
	var birds: Array = []
	for i in range(count):
		var bird = BirdClass.new()
		bird.scrap_id = "alley1_%d" % i
		bird.airspace = Rect2(-380.0, -270.0, 760.0, 150.0)
		bird.nest = line.nest_point.bind(i)
		bird.position = Vector2(-300.0 + i * 150.0, -200.0)
		holder.add_child(bird)
		birds.append(bird)
	return birds


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


## THREE WAYS DOWN, ONE PIECE EACH, AND IT ENDS ON THE FLOOR. Each way is driven to the end on
## real physics frames: the piece is let go exactly once, on the floor, and the bird that let
## go of it answers nothing else.
func _probe_birds() -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var birds := _flock(holder)
	_check(birds.size() == 5, "five birds, five pieces", "one scrap each")
	var dropped: Dictionary = {}
	for bird in birds:
		bird.scrap_dropped.connect(func(id: String, at: Vector2) -> void:
			dropped[id] = (dropped.get(id, []) as Array) + [at])
	_check(birds[3].hit_test(birds[3].global_position, 7.0), "a bird in the air can be hit",
		"a stone at its middle")

	# Fed: down to the offering, and the piece set down beside it.
	_check(birds[0].calm(Vector2(120.0, 0.0)), "a fed bird comes down", "to what was put out")
	_check(birds[0].state() == BirdClass.State.DESCENDING and birds[0].is_holding(),
		"flying down with its piece still in its beak", "not dropped from the air")
	# Struck: it tumbles, lets go on landing, and later shakes it off.
	_check(birds[1].strike_down(), "a struck bird falls", "alley1_1")
	# Scattered: gone at once, and the piece flutters down by itself.
	_check(birds[2].startle(), "a scattered bird bolts", "alley1_2")
	_check(not birds[2].is_holding(), "and lets go of its piece as it goes",
		"nothing is carried off")
	# One answer per bird: otherwise a piece is dropped twice.
	_check(not birds[0].strike_down() and not birds[0].startle() and not birds[0].calm(),
		"an answered bird cannot be answered again", "no piece can be taken twice")
	_check(not birds[1].hit_test(birds[1].global_position, 7.0),
		"and a falling one cannot be hit again", "one stone, one bird")

	await _frames(240)
	_check(birds[0].state() == BirdClass.State.CALMED, "the fed one lands and eats", "calmed")
	var once := true
	var on_floor := true
	for id: String in ["alley1_0", "alley1_1", "alley1_2"]:
		var drops: Array = dropped.get(id, [])
		if drops.size() != 1:
			once = false
		for at: Vector2 in drops:
			if absf(at.y - holder.global_position.y) > 0.5:
				on_floor = false
	_check(once, "every piece let go of exactly once", str(dropped.keys()))
	_check(on_floor, "and every one of them on the floor", "at the floor's own height")
	var fed_at: Array = dropped.get("alley1_0", [])
	_check(not fed_at.is_empty() and absf((fed_at[0] as Vector2).x - 120.0) <= BirdClass.BESIDE + 1.0,
		"the fed one leaves it beside the offering", "%s" % str(fed_at))
	_check(birds[1].state() == BirdClass.State.GONE and birds[2].state() == BirdClass.State.GONE,
		"a struck bird shakes it off and goes; a scattered one is long gone",
		"struck %d, scattered %d" % [birds[1].state(), birds[2].state()])
	_check(not dropped.has("alley1_3") and not dropped.has("alley1_4") and birds[3].is_holding(),
		"and the ones left alone still have theirs", "nothing dropped by itself")

	# A restore: up again with the piece, or long gone without it -- never half of each.
	birds[1].restore_to(false)
	_check(birds[1].is_airborne() and birds[1].is_holding(), "a restore can put a bird back up",
		"with its piece")
	birds[4].restore_to(true)
	_check(birds[4].state() == BirdClass.State.GONE and not birds[4].is_holding(),
		"or leave it gone, with its piece handed over", "done")
	holder.queue_free()


func _probe_assembly() -> void:
	var asm = AssemblyClass.new()
	root.add_child(asm)
	var slots: Dictionary = {}
	for i in range(7):
		slots["scrap_%d" % i] = Vector2(i * 200.0, 0.0)
	asm.set_slots(slots)
	_check(asm.slot_count() == 7 and asm.placed() == 0, "seven slots, none filled", "0 of 7")
	_check(not asm.drop("scrap_0", Vector2(400.0, 0.0)),
		"a piece dropped far from its slot does not snap", "400px away")
	_check(asm.drop("scrap_0", Vector2(40.0, 20.0)), "dropped near it, it does", "within the snap")
	_check(not asm.drop("scrap_0", Vector2(0.0, 0.0)),
		"and a piece cannot be placed twice", "a double release is not two of seven")
	_check(not asm.drop("not_a_piece", Vector2(0.0, 0.0)),
		"something that is not one of the seven never snaps", "unknown id")

	var done: Array = []
	asm.assembled.connect(func(creased: bool) -> void: done.append(creased))
	asm.set_creased(true)
	_check(asm.place_all() == 6, "the rest go home", "6 remaining placed")
	_check(asm.is_complete() and done.size() == 1, "and that finishes it", "7 of 7, announced once")
	_check(bool(done[0]), "the fold shows if Level 1 cut the canvas",
		"visual only -- it changes nothing else")
	asm.queue_free()


## THE PROMISE, "none can be permanently lost", at the size of one alley and for every way
## through it. Whichever way the flock is answered -- fed, cut down, knocked down one at a time
## -- every piece ends on the floor between the walls, where a player can walk over it.
func _probe_every_way_down() -> void:
	var lost: Array[String] = []
	for way in ["fed", "cut down", "knocked down"]:
		var holder := Node2D.new()
		root.add_child(holder)
		var birds := _flock(holder)
		var dropped: Dictionary = {}
		for bird in birds:
			bird.scrap_dropped.connect(func(id: String, at: Vector2) -> void: dropped[id] = at)
		for i in range(birds.size()):
			match way:
				"fed": birds[i].calm(Vector2(-60.0 + i * 30.0, 0.0))
				"cut down": birds[i].startle()
				"knocked down": birds[i].strike_down()
		await _frames(300)
		if dropped.size() != birds.size():
			lost.append("%s: %d of %d on the floor" % [way, dropped.size(), birds.size()])
		for id: String in dropped.keys():
			var at: Vector2 = dropped[id]
			if absf(at.x) > 390.0:
				lost.append("%s: %s outside the walls at %.0f" % [way, id, at.x])
		var ledger = LedgerClass.new()
		holder.add_child(ledger)
		if not ledger.all_still_reachable(dropped.size() + 2):
			lost.append("%s: the ledger says a piece is unreachable" % way)
		holder.queue_free()
	_check(lost.is_empty(), "every way down puts every piece on the floor",
		"fed, cut down, knocked down: 5 of 5 each" if lost.is_empty() else "; ".join(lost))


## THE THROW, on its own. What it shows is what happens: a throw lands where the arc ends, a
## bird on the arc is hit, one bird to a throw, a boomerang comes back, a cannon keeps its shot,
## and a stone is where it landed until the hand walks over it.
func _probe_the_throw() -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var hand_at := [Vector2(0.0, -48.0)]
	var thrower = ThrowClass.new()
	holder.add_child(thrower)
	thrower.floor_y = 0.0
	thrower.walls = Vector2(-450.0, 450.0)
	thrower.follow_mouse = false
	thrower.hand = func() -> Vector2: return hand_at[0]
	var targets: Array = []
	thrower.targets = func() -> Array: return targets

	thrower.hold(ThrowClass.Kind.STONE)
	_check(thrower.kind == ThrowClass.Kind.NONE and not thrower.ready_to_throw(),
		"no stone drawn, nothing to throw", "a stone is only held once drawn")
	thrower.give_stone()
	thrower.hold(ThrowClass.Kind.STONE)
	_check(thrower.ready_to_throw() and thrower.stone_in_hand(), "a drawn stone is in the hand",
		"ready")
	# Short of the far wall, so what is measured is the landing and not the wall.
	thrower.aim_at(Vector2(140.0, -120.0))
	var arc: PackedVector2Array = thrower.trajectory(thrower.current_velocity(), 4.0)
	_check(thrower.throw(), "and thrown along the aim", "let go")
	_check(not thrower.ready_to_throw(), "one stone is one throw", "not in the hand now")
	await _frames(240)
	_check(thrower.stone_on_the_floor()
		and thrower.resting_stone().distance_to(Vector2(arc[arc.size() - 1].x, -ThrowClass.STONE_RADIUS)) <= 1.0,
		"it lands where the arc ends", "%s against %s" % [thrower.resting_stone(), arc[arc.size() - 1]])
	hand_at[0] = Vector2(thrower.resting_stone().x - 10.0, -48.0)
	await _frames(2)
	_check(thrower.stone_in_hand(), "and walking over it picks it up", "in hand again")

	# A bird on the arc is hit, and only the first of two.
	hand_at[0] = Vector2(0.0, -48.0)
	await _frames(2)
	thrower.aim_at(Vector2(150.0, -260.0))
	var path: PackedVector2Array = thrower.trajectory(thrower.current_velocity(), 4.0)
	var first = BirdClass.new()
	var second = BirdClass.new()
	for bird in [first, second]:
		bird.scrap_id = "target"
		bird.airspace = Rect2(-440.0, -400.0, 880.0, 390.0)
		holder.add_child(bird)
		bird.set_physics_process(false)
		targets.append(bird)
	first.global_position = path[int(path.size() * 0.35)]
	second.global_position = path[int(path.size() * 0.6)]
	var hits: Array = []
	thrower.hit.connect(func(bird: Node2D) -> void: hits.append(bird))
	thrower.throw()
	await _frames(120)
	_check(hits.size() == 1 and hits[0] == first and first.state() == BirdClass.State.FALLING,
		"a bird on the arc is hit", "struck, and falling")
	_check(second.state() == BirdClass.State.FLYING, "one bird to a throw",
		"the one behind it is still up")
	for bird in [first, second]:
		targets.erase(bird)
		bird.queue_free()

	# Into the wall: straight down, and inside it.
	await _fetch(thrower, hand_at)
	thrower.aim_at(Vector2(-300.0, -300.0))
	thrower.throw()
	await _frames(240)
	_check(thrower.stone_on_the_floor() and thrower.resting_stone().x > -450.0,
		"a stone off a wall drops inside it", "at %.0f" % thrower.resting_stone().x)

	# The boomerang and the cannon: thrown from the hand, and never lost.
	hand_at[0] = Vector2(0.0, -48.0)
	thrower.hold(ThrowClass.Kind.BOOMERANG)
	thrower.aim_at(Vector2(220.0, -120.0))
	_check(thrower.throw() and not thrower.ready_to_throw(), "a boomerang throws once at a time",
		"in the air")
	await _frames(360)
	_check(not thrower.in_flight(), "and comes back to the hand", "ready again")
	thrower.hold(ThrowClass.Kind.CANNON)
	_check(thrower.throw(), "a cannon fires", "one shot")
	await _frames(300)
	_check(not thrower.in_flight() and thrower.ready_to_throw(), "and keeps its shot",
		"ready to fire again")
	thrower.clear()
	_check(thrower.kind == ThrowClass.Kind.NONE and not thrower.has_stone()
		and not thrower.stone_on_the_floor(), "and put away, it holds nothing", "cleared")
	_check(ThrowClass.reach() >= 330.0, "the hardest throw clears the strings",
		"%.0fpx up from the floor" % ThrowClass.reach())
	holder.queue_free()


func _fetch(thrower, hand_at: Array) -> void:
	if thrower.stone_on_the_floor():
		hand_at[0] = Vector2(thrower.resting_stone().x, -48.0)
		await _frames(2)
	hand_at[0] = Vector2(0.0, -48.0)
	thrower.hold(ThrowClass.Kind.STONE)
	await _frames(1)


func _fresh() -> Node:
	var rules = RestrictionsClass.new()
	root.add_child(rules)
	var problems: Array = rules.load_from(_load(LEVEL_PATH), _roster_ids())
	_check(problems.is_empty(), "the level's rules load clean",
		"%d banned, %d capped" % [rules.banned_classes().size(), rules.capped_classes().size()]
		if problems.is_empty() else "; ".join(problems))
	return rules


func _probe_restrictions() -> void:
	var rules := _fresh()
	_check(rules.is_armed(), "restrictions are armed", "the level takes something away")
	_check(rules.is_banned("spider") and rules.is_banned("ant"),
		"the small ones are banned", "spider, ant")
	_check(not rules.is_banned("monkey") and not rules.is_banned("frog"),
		"the scare classes are not", "monkey and frog stay legal -- a stated path needs them")
	_check(not rules.is_banned("crab"),
		"crab is deliberately legal", "borderline on size; nothing needs it banned")

	# The refusal channel: it must ANSWER, not punish, and it must say why.
	var heard: Array = []
	rules.submission_refused.connect(func(id: String, note: String) -> void: heard.append([id, note]))
	var refused: bool = rules.refuses("butterfly")
	_check(refused and heard.size() == 1, "a banned class is refused at submission",
		"one refusal, no checkpoint touched")
	_check(not String(heard[0][1]).is_empty() and String(heard[0][1]).contains("trampled"),
		"and the refusal says why", String(heard[0][1]))
	_check(not rules.refuses("monkey"), "a legal class is not refused", "monkey passed")

	# A rule naming a class the roster does not have bans nothing -- it must be loud.
	var broken = RestrictionsClass.new()
	root.add_child(broken)
	var problems: Array = broken.load_from(
		{"restrictions": {"banned_playable_classes": {"classes": ["griffin"]}}},
		_roster_ids())
	# TWO problems, not one, and the second is the one that matters: dropping the ghost
	# class left the rule banning nothing at all, and a restriction that silently bans
	# nothing is the exact failure the design says must be loud at startup.
	var joined := "; ".join(problems)
	_check(joined.contains("griffin") and joined.contains("no classes at all"),
		"a rule naming a ghost class fails loudly",
		"%d problem(s): %s" % [problems.size(), joined] if not problems.is_empty()
		else "IT WAS SILENT")
	broken.queue_free()
	rules.queue_free()


func _probe_ceiling() -> void:
	var rules := _fresh()
	# The bandarita line, at y = -400. Above it is a SMALLER y, which is the comparison
	# this is most likely to get backwards.
	rules.set_ceiling(-400.0)
	_check(rules.crossed("bird", -520.0), "flying over the line is a crossing",
		"bird at -520 against a line at -400")
	_check(not rules.crossed("bird", -300.0), "flying under it is not",
		"bird at -300 is below the line")
	_check(is_equal_approx(rules.height_over("bird", -520.0), 120.0),
		"and it knows by how much", "120px over")
	_check(not rules.crossed("monkey", -900.0), "an uncapped class may go as high as it likes",
		"monkey at -900 is nobody's business")

	var crossings: Array = []
	rules.ceiling_crossed.connect(func(id: String, over: float) -> void: crossings.append([id, over]))
	_check(rules.check_height("bat", -900.0) and crossings.size() == 1,
		"a crossing is reported once", "bat, 500px over")

	# THE TRADE, PER SCENE. The cap is read off the line in the scene the player is in, and a
	# line that is cut is not a ceiling any more -- so cutting an alley's strings opens that
	# alley's sky, and a scene whose line is still up keeps its cap.
	var line = LineClass.new()
	root.add_child(line)
	_check(line.still_a_ceiling(), "a line strung up is a ceiling", "under the strings")
	_check(line.cut_it_down() and not line.still_a_ceiling(), "and cut down it is not",
		"the level reads that and stands the cap down")
	_check(not line.cut_it_down(), "and it cannot be cut twice", "one cut")
	line.put_back_up()
	_check(line.still_a_ceiling(), "and a restore strings it again", "as it was")
	line.queue_free()

	# A scene with no line strung across it does not invent one.
	var elsewhere := _fresh()
	elsewhere.set_ceiling(-INF)
	_check(not elsewhere.crossed("bird", -99999.0), "a scene with no line has no ceiling",
		"the rule stands down where the art does not")
	elsewhere.queue_free()
	rules.queue_free()


func _probe_ledger() -> void:
	var ledger = LedgerClass.new()
	root.add_child(ledger)
	ledger.reset()
	_check(ledger.total() == 7 and ledger.held() == 0, "seven pieces, none held", "0 of 7")
	_check(ledger.recover("scrap_1"), "a scrap is recovered", "1 of 7")
	_check(not ledger.recover("scrap_1"), "and cannot be recovered twice",
		"a swept trigger must not print eight of seven")
	_check(ledger.held() == 1, "the count is honest", "%d of 7" % ledger.held())
	_check(ledger.all_still_reachable(6) and not ledger.all_still_reachable(5),
		"the rest are reachable only if they are somewhere", "held + in a beak or on a floor")

	var state: Dictionary = ledger.serialize()
	ledger.reset()
	_check(ledger.held() == 0, "a reset clears it", "0 of 7")
	ledger.restore(state)
	_check(ledger.held() == 1 and ledger.has("scrap_1"), "and a checkpoint brings it back",
		"1 held")
	# A checkpoint from before this change carried a count of deferred escapees. Nothing is
	# deferred any more, and an old key must not trip a restore.
	ledger.restore({"held": ["scrap_1", "scrap_2"], "deferred": 3})
	_check(ledger.held() == 2, "an old snapshot with a deferred count still restores",
		"the count is ignored")
	ledger.queue_free()
