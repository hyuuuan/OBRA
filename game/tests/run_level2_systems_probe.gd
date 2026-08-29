extends SceneTree
## Level 2's own systems, driven headlessly:
##   godot --headless --path game --script res://tests/run_level2_systems_probe.gd
##
## These two carry the promises the level config only declares. The audit can check that
## `restrictions` names real classes; only this can check that the ceiling actually bites,
## that a banned class is refused rather than punished, and that no route through Alley 1
## can lose a scrap.

const RestrictionsClass = preload("res://scripts/level_restrictions.gd")
const LedgerClass = preload("res://scripts/scrap_ledger.gd")
const DanceClass = preload("res://scripts/dance_minigame.gd")
const BirdClass = preload("res://scripts/scrap_bird_2d.gd")
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
	_probe_scrap_conservation()
	_probe_dance()
	_probe_birds()
	_probe_assembly()
	_probe_alley_end_to_end()
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


func _flock(parent: Node) -> Array:
	var birds: Array = []
	for i in range(5):
		var bird = BirdClass.new()
		bird.scrap_id = "alley1_%d" % i
		parent.add_child(bird)
		birds.append(bird)
	return birds


func _probe_birds() -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var birds := _flock(holder)
	_check(birds.size() == 5, "five birds, five pieces", "one scrap each")

	var dropped: Array = []
	var flown: Array = []
	for bird in birds:
		bird.scrap_dropped.connect(func(id: String, _at: Vector2) -> void: dropped.append(id))
		bird.flew_off.connect(func(id: String) -> void: flown.append(id))

	_check(birds[0].calm(), "a calmed bird gives up its piece", "alley1_0 dropped")
	_check(birds[1].strike_down(), "a downed bird drops it where it fell", "alley1_1 dropped")
	_check(birds[2].startle(), "a startled bird carries it onward", "alley1_2 deferred")
	_check(dropped.size() == 2 and flown.size() == 1, "three verbs, three outcomes",
		"%d dropped, %d flown" % [dropped.size(), flown.size()])

	# A bird already answered answers nothing else -- otherwise one scrap counts twice.
	_check(not birds[0].strike_down() and not birds[0].startle() and not birds[0].calm(),
		"an answered bird cannot be answered again", "no scrap can be taken twice")
	_check(dropped.size() == 2, "and nothing more is dropped", "still 2")

	# The hit protocol the boomerang and the cannon already speak.
	_check(birds[3].apply_tool_hit("boomerang", 180.0, null),
		"apply_tool_hit downs one", "the existing tool protocol reaches a bird")
	_check(not birds[3].apply_tool_hit("boomerang", 180.0, null),
		"and a second hit does nothing", "already down")

	# The timer takes only what is still up there.
	_check(birds[4].timer_expired(), "the timer sends the stragglers on", "alley1_4 deferred")
	_check(not birds[0].timer_expired(), "and leaves the answered alone", "alley1_0 stays put")
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


## The whole of Problem 2 and Problem 3, walked for every Alley 1 outcome with REAL birds
## rather than arithmetic. This is the check that would catch a bird that quietly answers
## twice, or an alley that spawns the wrong number of tangled ones.
func _probe_alley_end_to_end() -> void:
	var outcomes := {"calm all five": "calm", "startle all five": "startle",
		"down two, timer takes three": "partial"}
	var broken: Array[String] = []
	for label: String in outcomes:
		var how: String = outcomes[label]
		var holder := Node2D.new()
		root.add_child(holder)
		var ledger = LedgerClass.new()
		holder.add_child(ledger)
		ledger.reset()
		var birds := _flock(holder)
		var deferred := 0
		for bird in birds:
			bird.scrap_dropped.connect(func(id: String, _at: Vector2) -> void: ledger.recover(id))
		for i in range(birds.size()):
			match how:
				"calm": birds[i].calm()
				"startle": birds[i].startle()
				"partial":
					if i < 2: birds[i].strike_down()
					else: birds[i].timer_expired()
		for bird in birds:
			if bird.state() == BirdClass.State.GONE:
				deferred += 1
		ledger.defer(deferred)
		# Alley 2: its own two, plus every one that flew on.
		if not ledger.all_still_reachable(LedgerClass.IN_ALLEY_2):
			broken.append("%s: a scrap is unreachable" % label)
		for i in range(ledger.claim_deferred()):
			ledger.recover("alley1_carried_%d" % i)
		ledger.recover("alley2_a")
		ledger.recover("alley2_b")
		if not ledger.is_complete():
			broken.append("%s ends at %d of 7" % [label, ledger.held()])
		holder.queue_free()
	_check(broken.is_empty(), "real birds, every route, seven pieces",
		"all %d outcomes reach 7 of 7" % outcomes.size() if broken.is_empty()
		else "; ".join(broken))


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

	# THE TRADE. Cutting the line is what buys the sky, and it must hold for the rest of
	# the level rather than for the scene the cut happened in.
	rules.lift()
	_check(rules.is_lifted(), "cutting lifts the ceiling", "flag: %s" % rules.lift_flag())
	_check(not rules.crossed("bird", -5000.0),
		"and nothing is a crossing afterwards", "bird at -5000 is legal now")

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

	ledger.defer(3)
	_check(ledger.deferred() == 3, "the flock's escapees are carried, not lost", "3 deferred")
	ledger.defer(99)
	_check(ledger.deferred() == 5, "and never more than there were", "clamped to 5")
	ledger.defer(-4)
	_check(ledger.deferred() == 0, "nor fewer than none", "clamped to 0")

	ledger.defer(2)
	var state: Dictionary = ledger.serialize()
	ledger.reset()
	_check(ledger.held() == 0 and ledger.deferred() == 0, "a reset clears it", "0 of 7")
	ledger.restore(state)
	_check(ledger.held() == 1 and ledger.deferred() == 2,
		"and a checkpoint brings both back", "1 held, 2 deferred")
	_check(ledger.claim_deferred() == 2 and ledger.deferred() == 0,
		"claiming the deferred clears the debt", "so a restore cannot spawn them twice")
	ledger.queue_free()


## THE PROMISE: "None can be permanently lost. A missed bird only defers its scrap to the
## next screen." Walked for every Alley 1 outcome, including the partial ones the timer
## produces, which are the only ones where the arithmetic is not obvious.
func _probe_scrap_conservation() -> void:
	var routes := {
		"artist  (feed all five)": 5,
		"pragmatist (all five scatter)": 0,
		"protector, 5 of 5 downed": 5,
		"protector, 3 of 5 downed": 3,
		"protector, 1 of 5 downed": 1,
		"protector, 0 of 5 downed": 0,
	}
	var lost: Array[String] = []
	for label: String in routes:
		var downed: int = routes[label]
		var ledger = LedgerClass.new()
		root.add_child(ledger)
		ledger.reset()
		for i in range(downed):
			ledger.recover("alley1_%d" % i)
		ledger.defer(LedgerClass.IN_ALLEY_1 - downed)
		# Alley 2 always holds its own two, plus whatever the flock carried in.
		var reachable_in_alley_2: int = LedgerClass.IN_ALLEY_2
		if not ledger.all_still_reachable(reachable_in_alley_2):
			lost.append(label)
		# Now actually take them all, the way Alley 2 does.
		for i in range(ledger.claim_deferred()):
			ledger.recover("alley1_carried_%d" % i)
		ledger.recover("alley2_a")
		ledger.recover("alley2_b")
		if not ledger.is_complete():
			lost.append("%s ends at %d of 7" % [label, ledger.held()])
		ledger.queue_free()
	_check(lost.is_empty(), "no route through Alley 1 loses a scrap",
		"all %d outcomes reach 7 of 7" % routes.size() if lost.is_empty()
		else "; ".join(lost))
