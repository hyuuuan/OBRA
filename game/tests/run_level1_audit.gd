extends SceneTree
## Level 1 data audit: the load-time assertions from level_01.json, run as a suite.
##   godot --headless --path game --script res://tests/run_level1_audit.gd
##
## These are DATA defects, not code defects, and every one of them is invisible until a
## player walks into the obstacle it breaks. An obstacle that resolves to one class is a
## dead end for whoever cannot draw that one thing; a tag taught after the choice that
## needs it is a choice made blind; a dialogue line naming a class turns "draw anything
## that spans" into a spelling test. None of that shows up in a compile.

## The autoload is fetched from the tree rather than named directly: a --script run
## compiles this file BEFORE autoloads are registered, so `AbilityTags.foo()` is a compile
## error here even though it is valid everywhere else. The preload is only for constants,
## which resolve off the script resource and do not need the instance.
const AbilityTagsScript = preload("res://scripts/ability_tags.gd")
## Preloaded rather than named: a class_name is not registered yet in a --script run.
const DialogueScriptClass = preload("res://scripts/dialogue_script.gd")
const CheckpointManagerClass = preload("res://scripts/checkpoint_manager.gd")
## Preloaded, not named: class_name is not registered yet in a --script run.
const StairTreadClass = preload("res://scripts/stair_tread_2d.gd")
const FloatingTreadClass = preload("res://scripts/floating_tread_2d.gd")
const StrawPileClass = preload("res://scripts/straw_pile_2d.gd")
const WardLockClass = preload("res://scripts/ward_lock_2d.gd")
const BululClass = preload("res://scripts/bulul_2d.gd")
const BaleClass = preload("res://scripts/bale_2d.gd")
const LevelDirectorClass = preload("res://scripts/level_director.gd")

const TAGS_PATH := "res://config/tags.json"
const LEVEL_PATH := "res://config/level_01.json"
const DIALOGUE_PATH := "res://config/dialogue_l1.json"
const ENTITIES_PATH := "res://config/entities.json"

var results: Array[String] = []
var failures := 0
var tags: Node


func _initialize() -> void:
	call_deferred("_run")


func _pass(what: String, detail: String) -> void:
	results.append("  OK    %-28s %s" % [what, detail])


func _fail(what: String, detail: String) -> void:
	results.append("  FAIL  %-28s %s" % [what, detail])
	failures += 1


func _check(ok: bool, what: String, detail: String) -> void:
	if ok:
		_pass(what, detail)
	else:
		_fail(what, detail)


func _run() -> void:
	tags = root.get_node_or_null("AbilityTags")
	if tags == null:
		print("OBRA_LEVEL1_AUDIT_FAILED=1  (AbilityTags autoload is not registered)")
		quit(1)
		return
	var level := _load(LEVEL_PATH)
	var dialogue := _load(DIALOGUE_PATH)

	_audit_tag_roster()
	_audit_every_route_resolves(level)
	_audit_tags_taught_before_use(level)
	_audit_checkpoints_precede_morphs(level)
	_audit_no_line_names_a_class(dialogue)
	_audit_dialogue_hooks_exist(level, dialogue)
	_audit_dialogue_loader(level)
	_audit_checkpoint_manager()
	_audit_level_director()
	await _audit_live_level()
	await _audit_node_two()
	_audit_ward_lock()
	await _audit_node_three()
	# LAST. It opens the completion overlay, which pauses the tree, and a paused tree
	# makes every physics check after it read zero.
	await _audit_completion_gate()

	print("\n===== LEVEL 1 DATA AUDIT =====")
	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_LEVEL1_AUDIT_OK")
		quit(0)
	else:
		print("OBRA_LEVEL1_AUDIT_FAILED=%d" % failures)
		quit(1)


func _load(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		_fail("load", "%s is missing or empty" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		_fail("load", "%s is not a JSON object" % path)
		return {}
	return parsed as Dictionary


# --- 1. Every tag member is a class the recogniser can actually produce -------

func _audit_tag_roster() -> void:
	# READ tags.json FROM DISK, not through AbilityTags. The loader already drops members
	# that are not in the roster, so asking it for its own class lists can only ever
	# return classes that passed -- the check would be testing the filter rather than the
	# data, and would pass against a tags.json naming a class that does not exist.
	# Mutation-tested: adding a bogus class went undetected until this read raw.
	var roster := _roster_ids()
	var raw := _load(TAGS_PATH)
	var missing: Array[String] = []
	var thin: Array[String] = []
	var raw_tags: Dictionary = raw.get("tags", {})
	for tag_value: Variant in raw_tags.keys():
		var tag := String(tag_value)
		var declared: Dictionary = (raw_tags[tag_value] as Dictionary).get("classes", {})
		for class_value: Variant in declared.keys():
			if not roster.has(String(class_value)):
				missing.append("%s->%s" % [tag, class_value])
		var members := tags.call("classes_for_tag", tag) as PackedStringArray
		# A declared-but-empty tag is deliberate (held for a later level); a tag with
		# exactly one member is not, because any obstacle using it has one answer.
		if members.size() == 1:
			thin.append("%s(%d)" % [tag, members.size()])
	_check(missing.is_empty(), "tag members in roster",
		"all %d memberships resolve" % _membership_count() if missing.is_empty()
		else "not in roster: %s" % ", ".join(missing))
	_check(thin.is_empty(), "no single-member tag",
		"every populated tag has >= 2" if thin.is_empty() else ", ".join(thin))


func _audit_every_route_resolves(level: Dictionary) -> void:
	var floor_hits: Array[String] = []
	for obstacle_value: Variant in level.get("obstacles", []):
		var obstacle: Dictionary = obstacle_value
		var id := String(obstacle.get("id", "?"))
		for sub_value: Variant in obstacle.get("sub_beats", []):
			var sub: Dictionary = sub_value
			_resolve_case("%s.%s" % [id, sub.get("id", "?")], sub, floor_hits)
		for route_value: Variant in (obstacle.get("routes", {}) as Dictionary).keys():
			var route: Dictionary = (obstacle["routes"] as Dictionary)[route_value]
			_resolve_case("%s.%s" % [id, route_value], route, floor_hits)
			if route.has("then"):
				_resolve_case("%s.%s.then" % [id, route_value], route["then"], floor_hits)
	if not floor_hits.is_empty():
		# Not a failure -- the design knows about these and marks them. Reported so the
		# BR-7 recall audit knows exactly which rows it is allowed to move.
		_pass("routes at the 2-class floor",
			"%s -- any recall drop here leaves one solution" % ", ".join(floor_hits))


func _resolve_case(label: String, spec: Dictionary, floor_hits: Array[String]) -> void:
	var required: Array = spec.get("required_tags", [])
	var match_mode := String(spec.get("match", AbilityTagsScript.MATCH_ALL))
	var exclude: Array = spec.get("exclude", [])
	var report := tags.call("resolve_report", required, match_mode, exclude) as Dictionary
	var solutions: PackedStringArray = report["solutions"]

	if not (report["unknown_tags"] as Array).is_empty():
		_fail(label, "unknown tag(s): %s" % ", ".join(report["unknown_tags"]))
		return
	if solutions.size() < AbilityTagsScript.MIN_SOLUTIONS:
		var removed: PackedStringArray = report["excluded"]
		_fail(label, "resolves %d class(es) %s after excluding [%s] -- an obstacle with one answer" % [
			solutions.size(), solutions, ", ".join(removed)])
		return
	if solutions.size() == AbilityTagsScript.MIN_SOLUTIONS:
		floor_hits.append(label)
	_pass(label, "%d: %s" % [solutions.size(), ", ".join(solutions)])


# --- 2. You cannot choose a route whose verb you were never taught -----------

func _audit_tags_taught_before_use(level: Dictionary) -> void:
	# Walk the level in order, accumulating what the player knows by the time each
	# obstacle presents its choice. Ordering is the whole point: a tag taught at Node 2
	# is useless to a choice made at Node 1.
	var known: Dictionary = {}
	var unlock_at: Dictionary = {}   # tag -> the obstacle id that teaches it
	for entry_value: Variant in level.get("tags_unlocked", []):
		var entry: Dictionary = entry_value
		unlock_at[String(entry.get("tag", ""))] = String(entry.get("at", ""))

	var problems: Array[String] = []
	for obstacle_value: Variant in level.get("obstacles", []):
		var obstacle: Dictionary = obstacle_value
		var id := String(obstacle.get("id", "?"))
		# Tags this obstacle teaches become known as it is entered.
		for tag_value: Variant in unlock_at.keys():
			if String(unlock_at[tag_value]).begins_with(id):
				known[String(tag_value)] = true
		for tag_value: Variant in obstacle.get("teaches_before_choice", []):
			known[String(tag_value)] = true
		# Every tag any of its routes needs must be known by now.
		for route_value: Variant in (obstacle.get("routes", {}) as Dictionary).keys():
			var route: Dictionary = (obstacle["routes"] as Dictionary)[route_value]
			var needed: Array = (route.get("required_tags", []) as Array).duplicate()
			if route.has("then"):
				needed.append_array((route["then"] as Dictionary).get("required_tags", []))
			for tag_value: Variant in needed:
				var tag := String(tag_value)
				if not known.has(tag):
					problems.append("%s.%s needs '%s'" % [id, route_value, tag])
		for sub_value: Variant in obstacle.get("sub_beats", []):
			var sub: Dictionary = sub_value
			for tag_value: Variant in sub.get("required_tags", []):
				if not known.has(String(tag_value)):
					problems.append("%s.%s needs '%s'" % [id, sub.get("id", "?"), tag_value])

	_check(problems.is_empty(), "tags taught before use",
		"%d tags, all unlocked before the choice needing them" % known.size()
		if problems.is_empty() else "; ".join(problems))


# --- 3. A morph must never be the thing that loses your progress -------------

func _audit_checkpoints_precede_morphs(level: Dictionary) -> void:
	var declared: Dictionary = {}
	for cp_value: Variant in level.get("checkpoints", []):
		declared[String((cp_value as Dictionary).get("id", ""))] = true
	var problems: Array[String] = []
	for obstacle_value: Variant in level.get("obstacles", []):
		var obstacle: Dictionary = obstacle_value
		if not (obstacle.get("routes", {}) as Dictionary).is_empty():
			var cp := String(obstacle.get("checkpoint_on_commit", ""))
			if cp.is_empty():
				problems.append("%s commits a route with no checkpoint" % obstacle.get("id", "?"))
			elif not declared.has(cp):
				problems.append("%s names undeclared checkpoint %s" % [obstacle.get("id", "?"), cp])
	_check(problems.is_empty(), "checkpoint per route commit",
		"%d checkpoints declared" % declared.size() if problems.is_empty()
		else "; ".join(problems))


# --- 4. THE CARDINAL RULE: no line may name a drawable class -----------------

func _audit_no_line_names_a_class(dialogue: Dictionary) -> void:
	# Word-boundary matching, and it matters: this dialogue is Taglish, and "Ang Batong
	# Palatandaan" contains the letters of `bat` while naming no class at all. A
	# substring search would fail the level's own exit marker.
	var terms: Array[String] = []
	var text := FileAccess.get_file_as_string(ENTITIES_PATH)
	var parsed: Variant = JSON.parse_string(text)
	for entity_value: Variant in (parsed as Dictionary).get("entities", []):
		var entity: Dictionary = entity_value
		terms.append(String(entity.get("id", "")).replace("_", " "))
		terms.append(String(entity.get("display_name", "")))

	var offenders: Array[String] = []
	for line_value: Variant in dialogue.get("lines", []):
		var line: Dictionary = line_value
		var body := String(line.get("text", ""))
		for term in terms:
			if term.is_empty():
				continue
			var pattern := RegEx.new()
			pattern.compile("(?i)\\b%s\\b" % term.replace(" ", "\\s+"))
			if pattern.search(body) != null:
				offenders.append("%s names '%s'" % [line.get("id", "?"), term])
				break
	_check(offenders.is_empty(), "no line names a class",
		"%d lines clean" % (dialogue.get("lines", []) as Array).size()
		if offenders.is_empty() else "; ".join(offenders))


# --- 5. Every hook the level fires has a line, and vice versa ----------------

func _audit_dialogue_hooks_exist(level: Dictionary, dialogue: Dictionary) -> void:
	var hooks: Dictionary = {}
	for line_value: Variant in dialogue.get("lines", []):
		hooks[String((line_value as Dictionary).get("at", ""))] = true
	var missing: Array[String] = []
	for obstacle_value: Variant in level.get("obstacles", []):
		var obstacle: Dictionary = obstacle_value
		var id := String(obstacle.get("id", "?"))
		if (obstacle.get("routes", {}) as Dictionary).is_empty():
			continue
		for expected in ["%s.enter" % id, "%s.teach" % id, "%s.choice" % id]:
			if not hooks.has(expected):
				missing.append(expected)
		for route_value: Variant in (obstacle.get("routes", {}) as Dictionary).keys():
			var commit := "%s.%s.commit" % [id, route_value]
			if not hooks.has(commit):
				missing.append(commit)
	_check(missing.is_empty(), "dialogue hooks present",
		"%d distinct hooks" % hooks.size() if missing.is_empty()
		else "no line for: %s" % ", ".join(missing))


# --- 6. The loader, not just the data ----------------------------------------

func _audit_dialogue_loader(level: Dictionary) -> void:
	var script = DialogueScriptClass.new()
	_check(script.load_from(DIALOGUE_PATH), "dialogue loads", "%s" % DIALOGUE_PATH)

	# The three route buttons are read off the commit lines, so a node missing one would
	# present a choice the player cannot make.
	var problems: Array[String] = []
	for obstacle_value: Variant in level.get("obstacles", []):
		var obstacle: Dictionary = obstacle_value
		var routes: Dictionary = obstacle.get("routes", {})
		if routes.is_empty():
			continue
		var id := String(obstacle.get("id", "?"))
		var labels: Dictionary = script.choices_for(id)
		for route_value: Variant in routes.keys():
			if not labels.has(String(route_value)):
				problems.append("%s.%s has no choice_label" % [id, route_value])
	_check(problems.is_empty(), "every route has a button",
		"3 labels at each node" if problems.is_empty() else "; ".join(problems))

	# `once` is what stops the refusal beat scolding the player on every decline. If it
	# leaked, the kindest line in the level becomes the most irritating one.
	var first: Array = script.fire("on_first_decline")
	var second: Array = script.fire("on_first_decline")
	_check(first.size() == 1 and second.is_empty(), "once-lines fire once",
		"refusal beat fired %d then %d" % [first.size(), second.size()])

	# A conditional line must stay silent until its flag is set, and must then appear.
	# Counted from the RAW file, not through peek(): peek's whole job is to hide unmet
	# conditions, so counting them through it reports zero however many there are. Same
	# trap as the tag-roster check above -- do not ask a filter what it filtered out.
	var raw := _load(DIALOGUE_PATH)
	var conditional: Array[Dictionary] = []
	for line_value: Variant in raw.get("lines", []):
		if (line_value as Dictionary).has("condition"):
			conditional.append(line_value as Dictionary)
	_check(not conditional.is_empty(), "conditional lines exist",
		"%d gated on a flag" % conditional.size())

	var leaked: Array[String] = []
	var stuck: Array[String] = []
	for line in conditional:
		var hook := String(line["at"])
		var id := String(line["id"])
		var flag := String(line["condition"])
		if _hook_yields(script, hook, id):
			leaked.append("%s before '%s'" % [id, flag])
		script.set_flag(flag)
		if not _hook_yields(script, hook, id):
			stuck.append("%s after '%s'" % [id, flag])
	_check(leaked.is_empty(), "unmet conditions stay silent",
		"%d lines held back" % conditional.size() if leaked.is_empty() else "; ".join(leaked))
	_check(stuck.is_empty(), "met conditions do fire",
		"all %d fire once flagged" % conditional.size() if stuck.is_empty() else "; ".join(stuck))

	# Every condition must name a flag the level actually sets. A typo here is silent:
	# Lolo simply never mentions the cost, and the Protector route loses the one line
	# that makes felling the muyong land as something that happened.
	var settable: Dictionary = {}
	for obstacle_value: Variant in level.get("obstacles", []):
		for route_value: Variant in ((obstacle_value as Dictionary).get("routes", {}) as Dictionary).values():
			var route: Dictionary = route_value
			for key in ["persistent_effect", "sets_flag", "cross_level_effect"]:
				if route.has(key):
					settable[String(route[key])] = true
	var orphans: Array[String] = []
	for line in conditional:
		if not settable.has(String(line["condition"])):
			orphans.append("%s waits on '%s', which nothing sets" % [line["id"], line["condition"]])
	_check(orphans.is_empty(), "conditions match effects",
		"%d flags declared by routes" % settable.size() if orphans.is_empty()
		else "; ".join(orphans))


## Does this hook currently yield the given line? peek() rather than fire() so the check
## does not consume once-lines as a side effect of looking.
func _hook_yields(script, hook: String, line_id: String) -> bool:
	for line_value: Variant in script.peek(hook):
		if String((line_value as Dictionary).get("id", "")) == line_id:
			return true
	return false


# --- 7. Checkpoints ----------------------------------------------------------

func _audit_checkpoint_manager() -> void:
	var cp = CheckpointManagerClass.new()

	# Nothing written yet is not an error -- it is "restart the level", and the caller
	# has to be able to tell the difference.
	_check(not cp.has_checkpoint() and cp.restore().is_empty(),
		"empty until written", "no checkpoint reads as empty, not as a bad one")

	var ink := 7.5
	cp.write("CP0", {"ink": ink, "toolbelt": ["axe"], "position": Vector2(120.0, 40.0),
		"placed": [{"entity_id": "ladder"}], "obstacles": {"B0_HAGDAN": "solved"}})
	_check(cp.has_checkpoint() and cp.latest_id() == "CP0", "write", "CP0 written")

	# THE SNAPSHOT MUST NOT TRACK THE LIVE WORLD. Mutating what was passed in, or what
	# comes back out, must not reach the stored copy -- a checkpoint that quietly becomes
	# a copy of the present restores the death that caused it.
	var restored: Dictionary = cp.restore()
	(restored["toolbelt"] as Array).append("sword")
	(restored["obstacles"] as Dictionary)["B0_HAGDAN"] = "broken"
	var again: Dictionary = cp.restore()
	_check((again["toolbelt"] as Array).size() == 1
		and String((again["obstacles"] as Dictionary)["B0_HAGDAN"]) == "solved",
		"snapshot is deep-copied", "editing a restored copy did not reach the checkpoint")

	# Everything the spec says a restore must return.
	_check(is_equal_approx(float(again["ink"]), ink)
		and (again["toolbelt"] as Array).has("axe")
		and (again["placed"] as Array).size() == 1
		and not (again["obstacles"] as Dictionary).is_empty(),
		"restore returns the four", "ink, toolbelt, placed entities, obstacle state")

	# Re-entering a trigger is not progress. Two writes of the same id must leave one.
	cp.write("CP0", {"ink": 1.0})
	_check(cp.count() == 1 and cp.ids().size() == 1,
		"re-write replaces", "CP0 written twice -> %d snapshot(s)" % cp.count())

	cp.write("CP1", {"ink": 9.0})
	_check(cp.latest_id() == "CP1" and cp.count() == 2,
		"latest wins", "CP1 is now the restore point")
	_check(cp.restore_count("CP0") == 2 and cp.total_restores() >= 2,
		"restores are counted", "CP0 restored %d times" % cp.restore_count("CP0"))

	# peek must not count as a restore, or the telemetry line reports the HUD looking at
	# the indicator as the player having died.
	var before := cp.total_restores()
	cp.peek()
	cp.peek("CP0")
	_check(cp.total_restores() == before, "peek does not count",
		"looked twice, still %d restores" % cp.total_restores())

	# It is a Node and was never added to the tree, so nothing else will free it. Left
	# alone it reports as a leak at exit, which is exactly the noise that hides a real one.
	cp.free()


# --- 8. The director ---------------------------------------------------------

func _audit_level_director() -> void:
	var d = LevelDirectorClass.new()
	root.add_child(d)          # _ready resolves the autoloads it talks to
	_check(d.load_level(LEVEL_PATH), "director loads", "%s" % LEVEL_PATH)

	# --- Beat 0: sub-beats run in order, and each is its own requirement -------
	d.enter_obstacle("B0_HAGDAN")
	_check(d.current_obstacle() == "B0_HAGDAN", "enter", "at B0_HAGDAN")
	_check((d.required_tags() as Array) == ["span"], "sub-beat 1 asks for span",
		"%s" % [d.required_tags()])

	# A wrong-tag drawing must not solve it, and must cost an attempt.
	var wrong: Dictionary = d.note_submission("frog")
	_check(not wrong["solves"] and not wrong["tag_match"] and int(wrong["attempts"]) == 1,
		"wrong tag is refused", "frog vs span -> attempts %d" % wrong["attempts"])

	var right: Dictionary = d.note_submission("square")
	_check(right["solves"] and right["tag_match"], "right tag solves", "square carries span")
	# Two sub-beats, so the first solve ADVANCES rather than completing the beat.
	_check(bool(right["stage_advanced"]) and not bool(right["obstacle_complete"]),
		"sub-beat advances", "stage moved to sub2 instead of finishing the beat")
	_check((d.required_tags() as Array) == ["roll"], "sub-beat 2 asks for roll",
		"%s" % [d.required_tags()])
	var done: Dictionary = d.note_submission("circle")
	_check(bool(done["obstacle_complete"]) and d.is_solved("B0_HAGDAN"),
		"beat completes", "circle closed B0_HAGDAN")

	# --- Node 1: the choice gates the requirement -----------------------------
	d.exit_obstacle("B0_HAGDAN")
	d.enter_obstacle("L1_N1")
	# Before committing, the strip shows every route's tag -- it must not pre-empt the
	# choice by showing only one.
	var before: Array = d.required_tags()
	_check(before.has("span") and before.has("cut") and before.size() >= 3,
		"pre-choice shows all routes", "%s" % [before])

	d.commit_route("L1_N1", "artist")
	_check(d.committed_route("L1_N1") == "artist", "commit", "artist committed")
	_check((d.required_tags() as Array) == ["span"], "post-choice narrows",
		"artist wants span, not the union")

	# Artist is the two-stage route: span the gorge, THEN climb the far abutment.
	var span: Dictionary = d.note_submission("bridge")
	_check(bool(span["stage_advanced"]) and not bool(span["obstacle_complete"]),
		"artist stage 1", "bridge spanned; the climb is still to come")
	_check((d.required_tags() as Array) == ["climb"], "artist stage 2 asks for climb",
		"%s" % [d.required_tags()])
	# crab and snake carry climb but are excluded here; the exclusion must bite.
	var excluded: Dictionary = d.note_submission("crab")
	_check(not excluded["solves"], "exclusions bite", "crab carries climb but is excluded")
	var climbed: Dictionary = d.note_submission("spider")
	_check(bool(climbed["obstacle_complete"]), "artist completes", "spider finished the node")

	d.free()
	_audit_hint_ladder()


## T3 is the only tier that changes what the game ACCEPTS rather than what it says, so it
## gets its own walk: a stuck Protector must be able to finish with an Artist solution,
## the attempt must be flagged assisted, and the route tally must NOT move.
func _audit_hint_ladder() -> void:
	var d = LevelDirectorClass.new()
	root.add_child(d)
	d.load_level(LEVEL_PATH)
	d.enter_obstacle("L1_N2")
	d.commit_route("L1_N2", "protector")          # Weather -> {butterfly, fan}
	_check(d.hint_tier() == 0, "starts at T0", "no help yet")

	# A rake is Forage: an Artist answer, wrong for this route at full strictness.
	var early: Dictionary = d.note_submission("rake")
	_check(not early["solves"], "T0 refuses another route's answer", "rake vs weather")

	# Four failures opens T3.
	for attempt in ["rake", "rake", "rake"]:
		d.note_submission(attempt)
	_check(d.hint_tier() == LevelDirectorClass.MAX_TIER, "four failures reach T3",
		"tier %d after %d attempts" % [d.hint_tier(), d.attempts("L1_N2")])

	var helped: Dictionary = d.note_submission("rake")
	_check(bool(helped["solves"]), "T3 widens the accept-set", "rake now solves L1_N2")
	# The two must not collapse into each other: it solved, but it was not what the
	# route asked for, and the statistics have to be able to tell those apart.
	_check(not bool(helped["tag_match"]), "assistance is not a tag match",
		"solved without carrying the required tag")
	_check(bool(helped["assisted"]) and d.was_assisted("L1_N2"), "solve is flagged assisted",
		"excluded from unassisted statistics")
	_check(d.committed_route("L1_N2") == "protector", "tally keeps the CHOICE",
		"still protector, though an artist answer solved it")
	d.free()


# --- 9. The real level ---------------------------------------------------------

## Everything above is data and units. This drives the actual scene, because the wiring
## between them is where the silent failures live: an obstacle volume whose id does not
## match the data is a trigger the player walks straight through, and it looks exactly
## like an obstacle that is working until someone tries to solve it.
func _audit_live_level() -> void:
	var packed := load("res://game_level.tscn") as PackedScene
	if packed == null:
		_fail("live level", "game_level.tscn did not load")
		return
	var level := packed.instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	await process_frame
	await process_frame

	var d = level.get("director")
	var strip = level.get("requirement_strip")
	_check(d != null and strip != null, "obstacle layer built",
		"director and strip exist on the level")

	_audit_polygon_fills(level)
	if d == null:
		level.queue_free()
		await process_frame
		return

	# Every volume in the scene must resolve to an entry in the data. A mismatch is a
	# dead obstacle, so it is an error at build time rather than a mystery at play time.
	var volumes := level.get_tree().get_nodes_in_group(&"level_obstacles")
	var dead: Array[String] = []
	for node in volumes:
		var id: String = node.get("obstacle_id")
		if (d.obstacle(id) as Dictionary).is_empty():
			dead.append(id)
	_check(not volumes.is_empty() and dead.is_empty(), "obstacle volumes resolve",
		"%d volume(s), all in level_01.json" % volumes.size() if dead.is_empty()
		else "no data for: %s" % ", ".join(dead))

	# Walk into Beat 0. The volume detects the player group, so this works whether they
	# are the wanderer or a drawn creature.
	var player := level.get("player") as Node2D
	_check(player != null, "player exists", "spawned")
	if player == null:
		level.queue_free()
		await process_frame
		return
	player.global_position = Vector2(700.0, 440.0)
	for _frame in range(12):
		await physics_frame
	_check(d.current_obstacle() == "B0_HAGDAN", "walking in registers",
		"director is at '%s'" % d.current_obstacle())

	# T0 says nothing. The strip must stay hidden until the player has asked or struggled.
	_check(not strip.visible, "T0 shows no strip", "flavour only, no tag named")

	# ...but Lolo does. The sub-beat lines are him asking for the thing the beat needs,
	# and they sat in the script UNFIRED: Beat 0 asked for nothing out loud, and the only
	# thing naming the requirement was a strip that does not appear until T1. A player who
	# walked in and waited heard nothing for thirty seconds. Read off the live bubble,
	# because "the hook exists in the file" was true the whole time it was broken.
	var asked := _lolo_bubble(level)
	_check(asked.to_lower().contains("span"), "beat 0 asks out loud at T0",
		"Lolo: %s" % asked.substr(0, 64))
	# The script marks tags with **asterisks**; Lolo's bubble is a plain Label with no
	# markup and printed them literally, which reads as a typo in the one line the
	# tutorial most needs the player to trust.
	_check(not asked.contains("**"), "no raw markup reaches the bubble",
		"clean" if not asked.contains("**") else "Lolo: %s" % asked.substr(0, 64))

	# Opening the canvas IS asking. T1 names the tag and nothing else.
	d.note_canvas_opened()
	await process_frame
	_check(d.hint_tier() >= 1 and strip.visible, "canvas open raises to T1",
		"tier %d, strip visible" % d.hint_tier())
	var shown := _strip_text(strip)
	_check(shown.to_lower().contains("span"), "T1 names the tag", shown)
	# The cardinal rule, enforced on the live HUD and not just on the dialogue file.
	var named := _class_named_in(shown)
	_check(named.is_empty(), "the strip names no class",
		shown if named.is_empty() else "strip said '%s'" % named)

	# Solving it through the real level entry point, not the director directly.
	level.call("_judge_submission", "square")
	await process_frame
	_check(d.stage_id("B0_HAGDAN") == "sub2", "solving advances the beat",
		"now at sub-beat '%s'" % d.stage_id("B0_HAGDAN"))
	var asked2 := _lolo_bubble(level)
	_check(asked2.to_lower().contains("roll"), "the second sub-beat asks for itself",
		"Lolo: %s" % asked2.substr(0, 64))

	level.call("_judge_submission", "circle")
	await process_frame
	_check(d.is_solved("B0_HAGDAN"), "beat completes in the live level", "B0_HAGDAN solved")
	_check(not strip.visible, "solved obstacle clears the strip", "nothing left to ask for")

	# --- the stair must still be a stair the player cannot just walk up ------
	# THE TREADS DEFEATED THE BEAT ONCE ALREADY. Added centre-anchored while the terrain is
	# top-left anchored, every riser came out half a tread short: 24, 36 and 80px against a
	# 94.3px jump, so the player could walk straight up and Beat 0 asked them for nothing.
	# Art that illustrates a gap must not fill it.
	var hagdan := level.get_node_or_null("EnvironmentBaseplate/GameplayPlane/Hagdan")
	_check(hagdan != null, "Ang Hagdan exists", "the stair is in the level")
	if hagdan != null:
		var jump: float = pow(430.0, 2.0) / (2.0 * 980.0)   # from wanderer.gd
		var lower := level.get_node_or_null(
			"EnvironmentBaseplate/GameplayPlane/Terrain/LowerRight") as Node2D
		# ONLY the stones you can stand on. The broken stubs share the script -- they are
		# what the missing treads left behind -- but they carry no collision, so counting
		# them would measure the gap from a thing that cannot hold the player.
		var treads: Array[Node2D] = []
		for child in hagdan.get_children():
			if child.get_script() == StairTreadClass and not bool(child.get("is_broken")):
				treads.append(child as Node2D)
		var stubs := 0
		for child in hagdan.get_children():
			if child.get_script() == StairTreadClass and bool(child.get("is_broken")):
				stubs += 1
		# The absence has to be drawn or two stones read as two rocks rather than as a
		# stair someone has to repair.
		_check(stubs == 3, "the three missing treads are drawn",
			"%d broken stub(s) where the gone ones were" % stubs)
		# And a stub must never be standable, or the gap quietly fills itself.
		var solid_stubs: Array[String] = []
		for child in hagdan.get_children():
			if child.get_script() == StairTreadClass and bool(child.get("is_broken")):
				for grandchild in child.get_children():
					if grandchild is CollisionShape2D or grandchild is CollisionPolygon2D:
						solid_stubs.append(String(child.name))
		_check(solid_stubs.is_empty(), "broken stubs are not standable",
			"none carry collision" if solid_stubs.is_empty() else ", ".join(solid_stubs))
		# Highest surface_y is the lowest stone on screen: y grows downward.
		treads.sort_custom(func(a, b): return float(a.call("surface_y")) > float(b.call("surface_y")))
		_check(not treads.is_empty(), "the stair has treads", "%d stone(s) survive" % treads.size())

		if not treads.is_empty() and lower != null:
			var rise: float = lower.global_position.y - float(treads[0].call("surface_y"))
			_check(rise > jump + 8.0, "the gap is still ungated",
				"%.0fpx from the bank to the lowest stone, against a %.0fpx jump" % [rise, jump])

		# And once the gap IS bridged the treads have to connect, or the player pays for a
		# step and is stranded one stone higher.
		var unreachable: Array[String] = []
		for index in range(treads.size() - 1):
			var step: float = float(treads[index].call("surface_y")) - float(treads[index + 1].call("surface_y"))
			if step > jump:
				unreachable.append("%s -> %s is %.0fpx" % [
					treads[index].name, treads[index + 1].name, step])
		_check(unreachable.is_empty(), "the surviving treads connect",
			"%d step(s), all climbable" % maxi(0, treads.size() - 1) if unreachable.is_empty()
			else "; ".join(unreachable))

	# --- the tread that floated off, and what Roll does to it ----------------
	# Sub-beat 0.2's whole lesson. It was drawn and it floated, but nothing made weighing it
	# down mean anything, so the mechanic was fiction: the strip asked for ROLL and any
	# rolling thing placed anywhere satisfied it.
	var floater := level.get_node_or_null(
		"EnvironmentBaseplate/GameplayPlane/Hagdan/FloatingTread")
	_check(floater != null and floater.get_script() == FloatingTreadClass,
		"the floating tread is live", "carries FloatingTread2D")
	if floater != null and floater.get_script() == FloatingTreadClass:
		_check(not bool(floater.call("is_settled")), "loose to begin with",
			"nothing is holding it down yet")

		# Something that does NOT roll must not settle it, or the tag is decorative.
		var wrong := _drop_on(level, floater, "square")
		for _frame in range(40):
			await physics_frame
		_check(not bool(floater.call("is_settled")), "a non-rolling weight does not settle it",
			"a square on it is still just a square on it")
		if wrong != null and is_instance_valid(wrong):
			wrong.queue_free()
		await process_frame

		# Something that does.
		var roller := _drop_on(level, floater, "circle")
		_check(roller != null, "a rolling weight exists to drop", "circle placed above it")
		for _frame in range(140):
			await physics_frame
		var touching := PackedStringArray()
		for b in (floater as RigidBody2D).get_colliding_bodies():
			touching.append("%s@%s" % [b.name, (b as Node2D).global_position.round()])
		_check(bool(floater.call("is_settled")), "a rolling weight settles it",
			"settled by '%s'" % floater.call("settling_class") if bool(floater.call("is_settled"))
			else "tread@%s vy=%.1f rot=%.2f touching=[%s] roller@%s" % [
				(floater as Node2D).global_position.round(),
				(floater as RigidBody2D).linear_velocity.y,
				float(floater.get("rotation")), ", ".join(touching),
				roller.global_position.round() if roller != null and is_instance_valid(roller) else "gone"])
		if bool(floater.call("is_settled")):
			_check(bool(floater.get("freeze")), "settled means solid",
				"frozen, so the water cannot lift it back up")
			_check(absf(float(floater.get("rotation"))) < 0.05, "it settles level",
				"%.3f rad -- a crooked tread is a ramp nobody asked for" % floater.get("rotation"))

	# --- CP0: a checkpoint you reach by walking ------------------------------
	# Beat 0 has no dialogue node, so before this it had no checkpoint at all and a slip on
	# the terrace above sent the player back to the level's start with both sub-beats
	# already solved.
	var cp_area := level.get_node_or_null(
		"EnvironmentBaseplate/GameplayPlane/Hagdan/CP0") as CheckpointArea2D
	_check(cp_area != null, "CP0 exists", "at the top of the flight")
	if cp_area != null:
		(level.get("player") as Node2D).global_position = cp_area.global_position
		for _frame in range(10):
			await physics_frame
		_check(cp_area.is_written(), "walking into CP0 writes it", "reached")
		_check((level.get("checkpoints")).latest_id() == "CP0",
			"CP0 is the restore point", "latest is '%s'" % (level.get("checkpoints")).latest_id())
		# Re-entering is not progress; it must not re-write.
		cp_area.emit_signal("reached", "CP0")
		await process_frame
		_check((level.get("checkpoints")).count() >= 1, "re-entry does not stack",
			"%d snapshot(s)" % (level.get("checkpoints")).count())

	# --- falling puts you back, and brings your things with you --------------
	# Writing a checkpoint was already covered; nothing called restore(), so the one
	# situation it exists for was untested. Driven by an actual fall rather than by
	# calling the restore directly, because the trigger is half of the feature.
	var cp_before = level.get("checkpoints")
	level.call("_write_checkpoint", "CP_TEST")
	var ink_at_checkpoint: float = (level.get_node("InkManager") as InkManager).committed
	var home: Vector2 = (level.get("player") as Node2D).global_position

	# Spend ink and drop a prop AFTER the checkpoint. Both must be undone.
	var ink := level.get_node("InkManager") as InkManager
	ink.reserve_attempt(3.0)
	ink.commit_attempt()
	var stray := _fake_prop(level)
	await process_frame
	_check(stray != null and is_instance_valid(stray), "prop placed after the checkpoint",
		"a stray prop exists to be cleaned up")

	# Off the bottom of the world.
	var bounds := Rect2(level.get_node("EnvironmentBaseplate").get("world_bounds"))
	(level.get("player") as Node2D).global_position = Vector2(home.x, bounds.end.y + 600.0)
	for _frame in range(8):
		await physics_frame

	var landed: Vector2 = (level.get("player") as Node2D).global_position
	_check(landed.distance_to(home) < 200.0, "a fall returns you to the checkpoint",
		"landed %.0fpx from where the checkpoint was written" % landed.distance_to(home))
	_check(is_equal_approx((level.get_node("InkManager") as InkManager).committed, ink_at_checkpoint),
		"restore gives the ink back", "committed is back to %.1f" % ink_at_checkpoint)
	_check(stray == null or not is_instance_valid(stray) or stray.is_queued_for_deletion(),
		"props placed since are removed", "the stray prop is gone")
	_check(cp_before.restore_count("CP_TEST") == 1, "the restore is counted",
		"CP_TEST restored once")

	# --- the choice must count ONCE ------------------------------------------
	# DialogueNode2D used to write the tally itself and so did the director, so a single
	# answer counted twice towards an ending that needs 7 of 12. One writer now, and this
	# is what holds it: drive the REAL node the way a player does and count the delta.
	var profile := root.get_node_or_null("PlayerProfile")
	var node := level.get("dialogue_node") as DialogueNode2D
	if profile != null and node != null:
		var before := int(profile.call("route_count", "artist"))
		node.choose("artist")
		await process_frame
		var after := int(profile.call("route_count", "artist"))
		_check(after == before + 1, "one choice counts once",
			"artist tally %d -> %d" % [before, after])
		_check(d.committed_route("L1_N1") == "artist", "choice reaches the director",
			"L1_N1 committed to artist")
		# Committing writes the checkpoint, which is what puts one in front of every
		# morph on the route.
		var cp = level.get("checkpoints")
		_check(cp != null and cp.has_checkpoint() and cp.latest_id() == "CP1",
			"commit writes its checkpoint", "latest is '%s'" % (cp.latest_id() if cp != null else "-"))
	else:
		_fail("one choice counts once", "no profile or dialogue node to drive")

	level.queue_free()
	await process_frame


## What is in Lolo's speech bubble right now. His voice, as the player sees it -- not the
## status label, which carries the apo's own lines.
func _lolo_bubble(level: Node) -> String:
	var lolo = level.get("lolo")
	if lolo == null or not is_instance_valid(lolo):
		return ""
	return _collect_labels(lolo)


## Drop a placed prop of `class_id` just above `target`, the way a player placing one
## there would. Returns it so the caller can clear it away again.
func _drop_on(level: Node, target: Node2D, class_id: String) -> PhysicsShapeObject:
	var registry := level.get_node("EntityRegistry") as EntityRegistry
	var prop := registry.instantiate_entity(class_id) as PhysicsShapeObject
	if prop == null:
		return null
	level.get_node("EnvironmentBaseplate/GameplayPlane/WorldItemRoot").add_child(prop)
	prop.apply_item_data(DrawnItemData.from_prediction(
		class_id, class_id.capitalize(), _blank_image(), [], 0.4, registry.get_entity(class_id)))
	prop.global_position = target.global_position - Vector2(0.0, 46.0)
	prop.confirm_placement()
	return prop


## A minimal placed prop, so the restore has something to clean up. Not a real drawing --
## the restore only ever looks at instance ids and transforms.
func _fake_prop(level: Node) -> PhysicsShapeObject:
	var registry := level.get_node("EntityRegistry") as EntityRegistry
	var prop := registry.instantiate_entity("square") as PhysicsShapeObject
	if prop == null:
		return null
	level.get_node("EnvironmentBaseplate/GameplayPlane/WorldItemRoot").add_child(prop)
	prop.apply_item_data(DrawnItemData.from_prediction(
		"square", "Square", _blank_image(), [], 0.4, registry.get_entity("square")))
	prop.global_position = Vector2(900.0, 300.0)
	return prop


func _blank_image() -> Image:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return image


## Ang Dayami. Three routes to the same chest that must NOT be the same thing.
##
## Run three times over, one route each, in a fresh level -- a route is a commitment and
## cannot be taken back, so they cannot share a world.
func _audit_node_two() -> void:
	for route in ["artist", "pragmatist", "protector"]:
		await _walk_node_two(route)


func _walk_node_two(route: String) -> void:
	var packed := load("res://game_level.tscn") as PackedScene
	var level := packed.instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	await process_frame
	await process_frame

	var d = level.get("director")
	var script_lines = level.get("script_lines_l1")
	var dayami := level.get_node_or_null("EnvironmentBaseplate/GameplayPlane/Dayami")
	if d == null or dayami == null:
		_fail("node 2 (%s)" % route, "the level has no Dayami or no director")
		level.queue_free()
		await process_frame
		return

	if route == "artist":
		# Only checked once: the volume and its wiring are the same for all three.
		_check(not (d.obstacle("L1_N2") as Dictionary).is_empty(),
			"L1_N2 is in the level data", "the obstacle exists")
		var piles := 0
		for child in dayami.get_children():
			if child.get_script() == StrawPileClass:
				piles += 1
		_check(piles == 3, "three heaps of straw", "%d pile(s)" % piles)
		var chest := dayami.get_node_or_null("Baul") as Baul2D
		_check(chest != null and not chest.visible,
			"the baul starts hidden", "it is in the straw, not on the terrace")

	# Walk in. Entering must teach all three verbs BEFORE the choice, or the player is
	# choosing between words they have never been told.
	var player := level.get("player") as Node2D
	var volume := level.get_node("EnvironmentBaseplate/GameplayPlane/Obstacles/L1_N2") as Node2D
	player.global_position = volume.global_position
	for _frame in range(12):
		await physics_frame
	if route == "artist":
		_check(d.current_obstacle() == "L1_N2", "walking onto the terrace registers",
			"director is at '%s'" % d.current_obstacle())
		var taught: Array[String] = []
		for tag in ["forage", "carry", "weather"]:
			if bool(tags.call("is_unlocked", tag)):
				taught.append(tag)
		_check(taught.size() == 3, "all three verbs taught on arrival",
			"%s" % [taught])

	d.commit_route("L1_N2", route)
	await process_frame

	# Solve it the way that route asks for.
	var solver: String = {"artist": "rake", "pragmatist": "ant", "protector": "fan"}[route]
	level.call("_judge_submission", solver)
	# The artist route plays out over a couple of seconds; the others are immediate.
	for _frame in range(150):
		await physics_frame

	_check(d.is_solved("L1_N2"), "%s solves it" % route, "with '%s'" % solver)

	# THE STRAW REMEMBERS WHICH ROUTE. This is the whole difference between them.
	var states: Array[int] = []
	for child in dayami.get_children():
		if child.get_script() == StrawPileClass:
			states.append(int(child.call("state")))
	var expected: int = {"artist": StrawPileClass.State.COMBED,
		"pragmatist": StrawPileClass.State.TUNNELLED,
		"protector": StrawPileClass.State.SCATTERED}[route]
	var all_match := not states.is_empty()
	for value in states:
		if value != expected:
			all_match = false
	_check(all_match, "%s leaves its own mark on the straw" % route,
		"every heap is %s" % ["intact", "combed", "tunnelled", "scattered"][expected])

	var chest2 := dayami.get_node_or_null("Baul") as Baul2D
	_check(chest2 != null and chest2.is_found(), "the chest turns up either way",
		"found on the %s route" % route)

	# The rewards, which are the reason the routes are not interchangeable.
	var knows := bool(script_lines.call("is_flag_set", "knows_about_key"))
	var scattered := bool(script_lines.call("is_flag_set", "straw_scattered"))
	if route == "artist":
		_check(knows, "combing pays out at NODE 3",
			"knows_about_key is set -- the page is the only place a nail is mentioned")
		_check(not scattered, "the patient route costs nothing", "the straw is left standing")
	else:
		_check(not knows, "the fast routes miss the page",
			"knows_about_key unset, so Node 3 is searched blind")
	if route == "protector":
		_check(scattered, "scattering is recorded",
			"straw_scattered is set, and the exit line is gated on it")

	level.queue_free()
	await process_frame


## The ward sequence: does a drawn key's SHAPE decide anything?
##
## The recogniser only gets the player through the door -- it says "that is a key" and has
## no opinion about whether it is THIS key. Everything below is geometry on the player's own
## strokes, which is the point: the drawing is not a token standing in for a key, it is the
## key, and its shape is load-bearing.
func _audit_ward_lock() -> void:
	# Three teeth, standing well off a long thin blade: what the slot wants.
	var right := _key_strokes(3, 26.0, 200.0)
	var measured: Dictionary = WardLockClass.measure(right)
	_check(int(measured["bits"]) == 3, "it counts the teeth",
		"read %d bit(s) off a three-toothed key" % measured["bits"])
	_check(float(measured["aspect"]) > 2.0, "it measures the blade",
		"aspect %.1f -- long and thin, not a comb" % measured["aspect"])

	# A key of the same shape drawn twice the size must measure the same. The player draws
	# at whatever scale they like and the lock cannot care.
	var big: Dictionary = WardLockClass.measure(_key_strokes(3, 52.0, 400.0))
	_check(int(big["bits"]) == int(measured["bits"])
		and absf(float(big["aspect"]) - float(measured["aspect"])) < 0.6,
		"scale does not change the answer",
		"same key at 2x reads %d bits, aspect %.1f" % [big["bits"], big["aspect"]])

	# Wrong tooth count is refused, and the refusal names what is wrong.
	var lock = WardLockClass.new()
	var wrong: Dictionary = lock.try_key(_key_strokes(6, 26.0, 200.0))
	_check(not bool(wrong["opens"]) and String(wrong["reason"]) == "bits",
		"the wrong key turns and stops", "refused on '%s'" % wrong["reason"])
	_check(float(wrong["revealed"]) > 0.0, "a failed turn shows more of the ward",
		"%.0f%% of the shape is now drawn on the canvas" % (float(wrong["revealed"]) * 100.0))
	lock.free()

	# The right key opens it first time.
	var fresh = WardLockClass.new()
	var good: Dictionary = fresh.try_key(right)
	_check(bool(good["opens"]) and not bool(good["forced"]),
		"the right key opens it", "on attempt %d, unforced" % good["attempt"])
	fresh.free()

	# NOBODY FAILS PERMANENTLY. Three wrong keys and it opens anyway -- being locked out of
	# the level by a shape nobody described is not a lesson.
	var stubborn = WardLockClass.new()
	var last: Dictionary = {}
	for attempt in range(3):
		last = stubborn.try_key(_key_strokes(7, 4.0, 60.0))
	_check(bool(last["opens"]) and bool(last["forced"]),
		"the third turn opens it regardless",
		"forced on attempt %d, so there is no dead end" % last["attempt"])
	stubborn.free()


## A key drawn as a person draws one: a long blade with teeth standing off one edge.
func _key_strokes(teeth: int, tooth_depth: float, blade_length: float) -> Array:
	var spine: Array[Vector2] = []
	for step in range(24):
		spine.append(Vector2(blade_length * float(step) / 23.0, 0.0))
	var points := PackedVector2Array(spine)
	var strokes: Array = [{"points": points, "width": 6.0, "color": Color.BLACK}]
	for index in range(teeth):
		var x: float = blade_length * (0.55 + 0.4 * float(index) / maxf(1.0, float(teeth)))
		strokes.append({
			"points": PackedVector2Array([Vector2(x, 0.0), Vector2(x, tooth_depth)]),
			"width": 6.0, "color": Color.BLACK,
		})
	return strokes


## Ang Bale. Three ways into the same chest, one of which costs something in Pista.
func _audit_node_three() -> void:
	# START FROM A CLEAN PROFILE. Canvas damage is deliberately permanent -- it has to
	# outlive the session for Pista to know about it -- so a profile left over from the
	# last run already has the crease recorded, and "the protector route creases it" passes
	# without the route doing anything. Mutation-testing caught exactly that: removing the
	# write left the check green.
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://profile.json"))
	var profile := root.get_node_or_null("PlayerProfile")
	if profile != null:
		profile.call("load_profile")
	for route in ["artist", "pragmatist", "protector"]:
		await _walk_node_three(route)


func _walk_node_three(route: String) -> void:
	var packed := load("res://game_level.tscn") as PackedScene
	var level := packed.instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	await process_frame
	await process_frame

	var d = level.get("director")
	var script_lines = level.get("script_lines_l1")
	var bale_root := level.get_node_or_null("EnvironmentBaseplate/GameplayPlane/Bale")
	if d == null or bale_root == null:
		_fail("node 3 (%s)" % route, "the level has no Bale or no director")
		level.queue_free()
		await process_frame
		return

	if route == "artist":
		var house := bale_root.get_node_or_null("House")
		_check(house != null and house.get_script() == BaleClass,
			"the bale is standing", "four posts and a roof")
		# THE HALIPAN ARE SOLID. They are why "climb the post" is not an answer, so if they
		# stop being collidable the Artist route stops having a reason to exist.
		var guards := 0
		var posts := 0
		if house != null:
			for child in house.get_children():
				if String(child.name).begins_with("Halipan"):
					for grandchild in child.get_children():
						if grandchild is CollisionShape2D:
							guards += 1
				elif String(child.name).begins_with("Post"):
					posts += 1
		_check(posts == 4, "four posts", "%d" % posts)
		_check(guards == 4, "every post carries a solid halipan",
			"%d rat guard(s) with collision -- this is why the posts cannot be climbed" % guards)

		# THE CULTURAL GUARDRAIL, as an assertion rather than a comment.
		var figures: Array[Node] = []
		for child in bale_root.get_children():
			if child.get_script() == BululClass:
				figures.append(child)
		_check(figures.size() == 2, "two bulul", "%d" % figures.size())
		var solid: Array[String] = []
		for figure in figures:
			if bool(figure.call("has_collision")):
				solid.append(String(figure.name))
		_check(solid.is_empty(), "no bulul has collision",
			"none can be stood on, pushed or chopped" if solid.is_empty()
			else "SOLID: %s" % ", ".join(solid))
		var in_data := false
		for obstacle_value: Variant in (d.level_data().get("obstacles", []) as Array):
			for route_value: Variant in ((obstacle_value as Dictionary).get("routes", {}) as Dictionary).values():
				if String(JSON.stringify(route_value)).to_lower().contains("bulul"):
					in_data = true
		_check(not in_data, "no route requires a bulul",
			"they carry no puzzle function anywhere in the level data")

	var player := level.get("player") as Node2D
	# On the terrace BESIDE the house, not on top of it: the posts, deck and thatch are
	# solid, and dropping the player into the middle of them wedges them in the geometry
	# instead of walking them up to it.
	player.global_position = Vector2(3360.0, 170.0)
	for _frame in range(20):
		await physics_frame
	if route == "artist":
		_check(d.current_obstacle() == "L1_N3", "arriving at the bale registers",
			"director is at '%s' (player at %s)" % [d.current_obstacle(), player.global_position.round()])
		_check(bool(tags.call("is_unlocked", "unlock")), "Unlock is taught on arrival",
			"the verb exists before the choice that needs it")

	var profile_pre := root.get_node_or_null("PlayerProfile")
	var creased_before := profile_pre != null \
		and bool(profile_pre.call("is_canvas_damaged", "canvas_2_pista"))

	d.commit_route("L1_N3", route)
	await process_frame
	var solver: String = {"artist": "spider", "pragmatist": "key", "protector": "axe"}[route]
	level.call("_judge_submission", solver)
	for _frame in range(260):
		await physics_frame

	_check(d.is_solved("L1_N3"), "%s solves it" % route, "with '%s'" % solver)
	var profile3 := root.get_node_or_null("PlayerProfile")
	_check(profile3 != null and bool(profile3.call("has_object", "canvas_2_pista")),
		"the chest yields the second canvas", "granted on the %s route" % route)

	# The cost that leaves the level, checked as a TRANSITION rather than a state.
	var creased := profile3 != null and bool(profile3.call("is_canvas_damaged", "canvas_2_pista"))
	if route == "protector":
		_check(not creased_before, "the crease is not there before the hasp is cut",
			"clean going in, so the check below means something")
		_check(creased, "cutting the hasp creases the canvas",
			"recorded on the profile, so Pista still knows two levels later")
	else:
		_check(not creased, "the %s route leaves the canvas whole" % route,
			"nothing damaged -- only cutting costs Pista a hidden flower")
	level.queue_free()
	await process_frame


## Nothing in the level may be filled from an AtlasTexture through a Polygon2D.
##
## It does not draw the region. It samples the whole atlas page using the polygon's own
## vertex coordinates as UVs, so the prop comes out as whatever art lies near the region --
## for this atlas mostly dark, which against the terraces is indistinguishable from not
## being there. Every prop built for Nodes 2 and 3 shipped that way and none of them was
## on screen: three straw piles, the baul's body, and the bale's posts, deck and thatch.
## It cost a screenshotting session to find, because each one reported present, positioned
## and visible the whole time.
##
## The UV is checked too. Left empty it defaults to the vertex coordinates, which move
## when the shape does -- a settling straw pile slid its own texture off itself.
## atlas_tile.gd does both correctly; this is here so the next prop cannot quietly not.
func _audit_polygon_fills(level: Node) -> void:
	var atlas_filled: Array[String] = []
	var unanchored: Array[String] = []
	for node in _all_nodes(level):
		var poly := node as Polygon2D
		if poly == null or poly.texture == null:
			continue
		if poly.texture is AtlasTexture:
			atlas_filled.append(String(poly.get_path()))
		elif poly.uv.is_empty():
			unanchored.append(String(poly.get_path()))
	_check(atlas_filled.is_empty(), "no polygon is filled from an atlas region",
		"every textured polygon has a cut-out texture" if atlas_filled.is_empty()
		else "invisible in play: %s" % ", ".join(atlas_filled))
	_check(unanchored.is_empty(), "every textured polygon anchors its own UV",
		"none inherits its vertices as UVs" if unanchored.is_empty()
		else "fill will drift when reshaped: %s" % ", ".join(unanchored))


func _all_nodes(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child in node.get_children():
		out.append_array(_all_nodes(child))
	return out


## Walking up to the house is not the same as finishing the level.
##
## The GoalMarker sits inside Ang Bale and completion used to be a distance check and
## nothing else, so arriving at Node 3 ended Level 1 before Lolo had offered a way in and
## before the chest was opened. This asserts both halves: arriving does not finish it, and
## answering the bale does.
func _audit_completion_gate() -> void:
	# The overlay is the visible effect. Asserting the private flag behind it would pass
	# against a level that completed silently and showed the player nothing.
	var packed := load("res://game_level.tscn") as PackedScene
	var level := packed.instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	await process_frame
	await process_frame

	var d = level.get("director")
	var player := level.get("player") as Node2D
	var overlay := level.get_node_or_null("LevelCompleteOverlay")
	var marker := level.get_node_or_null(
		"EnvironmentBaseplate/GameplayPlane/GoalMarker") as Node2D
	if d == null or player == null or overlay == null or marker == null:
		_fail("completion gate", "the level has no goal marker, player, director or overlay")
		level.queue_free()
		await process_frame
		return

	# Standing ON the marker, which is as arrived as it is possible to be.
	player.global_position = marker.global_position
	for _frame in range(30):
		await physics_frame
	_check(not bool(overlay.call("is_open")), "arriving at the bale does not end the level",
		"the player is standing on the goal marker and Ang Bale is unanswered")

	# Choosing a way in is not the same as getting in. CP3 is written on the commit, so a
	# gate that only asked whether the checkpoint existed would let the player finish by
	# pressing a dialogue button and walking four metres without drawing anything.
	d.enter_obstacle("L1_N3")
	d.commit_route("L1_N3", "pragmatist")
	await process_frame
	player.global_position = marker.global_position
	for _frame in range(30):
		await physics_frame
	_check(not bool(overlay.call("is_open")), "committing to a route does not end it either",
		"CP3 is written, the bale is still shut")

	# Now answer it.
	level.call("_judge_submission", "key")
	for _frame in range(60):
		await physics_frame
	player.global_position = marker.global_position
	for _frame in range(30):
		await physics_frame
	_check(bool(overlay.call("is_open")), "answering the bale does end it",
		"L1_N3 solved, so the goal marker completes the level")

	level.queue_free()
	await process_frame
	# The overlay paused the tree on its way up, and it is not this run's job to leave it
	# that way -- a paused tree is how one failing test once looked like twenty.
	paused = false


func _strip_text(strip) -> String:
	# Recursive: the strip is Control > PanelContainer > VBoxContainer > Label, and a
	# two-level walk silently returned "" the moment the panel was added -- which reads
	# in a test as "the strip says nothing" rather than as "this helper is wrong".
	return _collect_labels(strip).strip_edges()


func _collect_labels(node: Node) -> String:
	var out := ""
	for child in node.get_children():
		if child is Label and (child as Label).visible:
			out += String((child as Label).text) + "  "
		out += _collect_labels(child)
	return out


## Any of the 50 class names appearing in HUD text, by word boundary. Same rule as the
## dialogue check and for the same reason -- naming a class turns the puzzle into a
## spelling test, and the strip is the surface most likely to leak one by accident.
func _class_named_in(text: String) -> String:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ENTITIES_PATH))
	for entity_value: Variant in (parsed as Dictionary).get("entities", []):
		var entity: Dictionary = entity_value
		for term in [String(entity.get("id", "")).replace("_", " "),
				String(entity.get("display_name", ""))]:
			if term.is_empty():
				continue
			var pattern := RegEx.new()
			pattern.compile("(?i)\\b%s\\b" % term.replace(" ", "\\s+"))
			if pattern.search(text) != null:
				return term
	return ""


# --- helpers -----------------------------------------------------------------

func _roster_ids() -> Dictionary:
	var ids: Dictionary = {}
	var text := FileAccess.get_file_as_string(ENTITIES_PATH)
	var parsed: Variant = JSON.parse_string(text)
	for entity_value: Variant in (parsed as Dictionary).get("entities", []):
		ids[String((entity_value as Dictionary).get("id", ""))] = true
	return ids


func _membership_count() -> int:
	var total := 0
	for tag in tags.call("all_tags"):
		total += (tags.call("classes_for_tag", tag) as PackedStringArray).size()
	return total
