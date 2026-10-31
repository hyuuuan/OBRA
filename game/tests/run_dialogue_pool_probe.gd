extends SceneTree
## Lolo's comments on the player's drawings come from pools, picked by the manuscript's shuffle
## bag (thesis §4.5.4.4): an unheard line first, a heard one dropping out and coming back as
## the pool moves on -- so a player who misses five times hears five different things, and the
## first of them is the one that teaches what the drawing can do here.
##
##   godot --headless --path game --script res://tests/run_dialogue_pool_probe.gd

## Every check this probe makes. A script error that skips them must not pass as quiet.
const CHECKS := 6

var failures := 0
var checked := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_the_bag_weighs_lines_as_the_manuscript_says()

	var level := (load("res://game_level.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(40):
		await physics_frame
	var profile := root.get_node("PlayerProfile")
	var director := level.get("director") as LevelDirector
	var hint := level.get("hint_bar") as Node
	var obstacle := String(director.obstacle_ids()[0])
	director.enter_obstacle(obstacle)
	var verdict := {"required_tags": director.required_tags(obstacle)}

	var misses: Array[String] = []
	for _miss in range(5):
		level.call("_say_it_did_not_fit", "frog", verdict)
		misses.append(String(hint.call("current_text")))
	var distinct := {}
	for said in misses:
		distinct[said] = true
	_check(misses[0].begins_with("A frog can ") and misses[0].contains("This needs something that can"),
		"the first miss teaches what the drawing can do here", misses[0])
	_check(distinct.size() == 5 and not "".join(misses).contains("{"),
		"five misses, five different things, every blank filled", " | ".join(misses))

	var registry := level.get("registry") as EntityRegistry
	var fact := String(level.call("_safe_fact", "frog"))
	var frog: Dictionary = registry.call("get_entity", "frog")
	var true_fact := String(frog.get("ability_assertion", ""))
	frog["ability_assertion"] = "A frog can climb a ladder."
	var leaking := String(level.call("_safe_fact", "frog"))
	frog["ability_assertion"] = true_fact
	_check(not fact.is_empty() and "".join(misses).contains(fact) and leaking.is_empty(),
		"a miss can cite the drawing's own ConceptNet fact, never one naming another class",
		"'%s'; a fact naming a ladder: '%s'" % [fact, leaking])

	level.set("_refusal_spoken", true)
	var advice: Array[String] = []
	for _decline in range(5):
		level.call("_on_recognition_declined", "frog", 0.4, 0.5, "confidence")
		advice.append(String(hint.call("current_text")))
	level.call("_on_recognition_declined", "frog", 0.7, 0.05, "margin")
	var margin := String(hint.call("current_text"))
	var advised := {}
	for said in advice:
		advised[said] = true
	_check(advised.size() == 5 and not advised.has(margin) and not margin.is_empty(),
		"each later decline advises something new, by the half of the gate that refused",
		"%d different; margin: %s" % [advised.size(), margin])

	var bag := "%s:comment.not_fit" % String(LevelManager_id())
	_check(int(profile.call("dialogue_heard_count", "L1_POOL_NF_2")) >= 1
		and int(profile.call("picks_since", bag, "L1_POOL_NF_2")) >= 1,
		"the save remembers what was said and how long ago",
		"heard %d, %d picks since" % [int(profile.call("dialogue_heard_count", "L1_POOL_NF_2")),
			int(profile.call("picks_since", bag, "L1_POOL_NF_2"))])

	if checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_DIALOGUE_POOL_OK")
		quit(0)
	else:
		print("OBRA_DIALOGUE_POOL_FAILED=%d" % failures)
		quit(1)


func LevelManager_id() -> String:
	return String(root.get_node("LevelManager").get("current_level_id"))


func _the_bag_weighs_lines_as_the_manuscript_says() -> void:
	var unseen := ShuffleBag.weight(0, 0, 0, 5)
	var just_heard := ShuffleBag.weight(0, 1, 0, 5)
	var halfway := ShuffleBag.weight(0, 1, 2, 4)
	var recovered := ShuffleBag.weight(0, 1, 9, 4)
	var favoured := ShuffleBag.weight(2, 1, 9, 4)
	_check(is_equal_approx(unseen, 101.0) and is_equal_approx(just_heard, 0.0)
		and is_equal_approx(halfway, 0.5) and is_equal_approx(recovered, 1.0)
		and is_equal_approx(favoured, 3.0),
		"unseen +100; a heard line drops to 0 and recovers to its priority over the pool's picks",
		"%.1f, %.1f, %.1f, %.1f, priority 2: %.1f" % [unseen, just_heard, halfway, recovered, favoured])


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
