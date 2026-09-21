extends SceneTree
## Level 3 data audit: the load_time_assertions from level_03.json, run as a suite.
##   godot --headless --path game --script res://tests/run_level3_audit.gd
##
## DATA ONLY, like Level 2's was before its geometry existed. Dagat has no scene yet, and the
## assertions that matter most are true or false before one does: a route that resolves to one
## class, a tag taught after the choice that needs it, a line naming a class.
##
## FIVE CHECKS HERE ARE NEW, and each exists because Dagat does something no level has:
##
##   * every class in the aquatic rule must ACTUALLY SWIM -- a swimmer list is a promise, and
##     four of Dagat's seven carry land rigs and reach the water only through can_swim. A
##     class listed here that cannot swim is a player reverted for drawing the right answer;
##   * the aquatic rule must name at least one swimmer, because a rule that resolves to
##     nothing does not fail open here the way a ban list does -- it drowns everything;
##   * every tag a route requires must unlock at or before level 3, which is the mistake
##     `light` was one commit away from being: declared in the level that uses it and
##     unlocked in the one after;
##   * the Swim gate must have an answer above BR-7's 0.70 recall floor. `frog` is in the tag
##     at 0.576, the worst class in the roster, and is safe ONLY as one of seven;
##   * objectives are held to the no-class rule as well as dialogue. level_02.json's own
##     comment claims that and nothing checked it; in a level set in the sea it is not a
##     formality.

const AbilityTagsScript = preload("res://scripts/ability_tags.gd")
const DialogueScriptClass = preload("res://scripts/dialogue_script.gd")
const LevelRestrictionsClass = preload("res://scripts/level_restrictions.gd")

const TAGS_PATH := "res://config/tags.json"
const LEVEL_PATH := "res://config/level_03.json"
const DIALOGUE_PATH := "res://config/dialogue_l3.json"
const ENTITIES_PATH := "res://config/entities.json"
const RIGS_DIR := "res://config/rigs/"
const LABELS_PATH := "res://../model/labels.json"
const LEVELS_PATH := "res://config/levels.json"
const METRICS_PATH := "res://../model/metrics.json"
const ENVIRONMENT_PATH := "res://levels/level_3/level_3_environment.tscn"
const LEVEL_SCRIPT_PATH := "res://scripts/level_3.gd"

## BR-7. No critical-path obstacle may depend on a class whose held-out recall is under this.
const RECALL_FLOOR := 0.70
const THIS_LEVEL := 3

var results: Array[String] = []
var failures := 0
var tags: Node


func _initialize() -> void:
	call_deferred("_run")


func _pass(what: String, detail: String) -> void:
	results.append("  OK    %-34s %s" % [what, detail])


func _fail(what: String, detail: String) -> void:
	results.append("  FAIL  %-34s %s" % [what, detail])
	failures += 1


func _check(ok: bool, what: String, detail: String) -> void:
	if ok: _pass(what, detail)
	else: _fail(what, detail)


func _run() -> void:
	tags = root.get_node_or_null("AbilityTags")
	if tags == null:
		tags = AbilityTagsScript.new()
		tags.name = "AbilityTags"
		root.add_child(tags)
		tags.call("load_tags")

	var level := _load(LEVEL_PATH)
	var dialogue := _load(DIALOGUE_PATH)

	print("\n===== LEVEL 3 (DAGAT) DATA AUDIT =====")
	_audit_identity(level)
	_audit_every_route_resolves(level)
	_audit_aquatic_rule(level)
	_audit_swimmers_can_swim(level)
	_audit_answers_are_recognisable(level)
	_audit_swim_gate_clears_the_floor(level)
	_audit_tags_taught_before_use(level)
	_audit_tags_unlock_by_this_level(level)
	_audit_checkpoints_precede_morphs(level)
	_audit_no_line_names_a_class(dialogue)
	_audit_no_objective_names_a_class(level)
	_audit_dialogue_hooks_exist(level, dialogue)
	_audit_no_line_is_unreachable(level, dialogue)
	_audit_every_route_has_a_button(level, dialogue)
	_audit_conditions_match_effects(level, dialogue)
	_audit_shipping_state()
	_audit_one_seabed(level)

	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_LEVEL3_AUDIT_OK")
		quit(0)
	else:
		print("OBRA_LEVEL3_AUDIT_FAILED=%d" % failures)
		quit(1)


func _load(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _routes_of(level: Dictionary) -> Array:
	var out: Array = []
	for obstacle_value: Variant in level.get("obstacles", []):
		var obstacle: Dictionary = obstacle_value
		for name_value: Variant in (obstacle.get("routes", {}) as Dictionary).keys():
			out.append([String(obstacle.get("id", "?")), String(name_value),
				(obstacle["routes"] as Dictionary)[name_value] as Dictionary])
	return out


func _solutions(route: Dictionary) -> PackedStringArray:
	var report := tags.call("resolve_report",
		route.get("required_tags", []),
		String(route.get("match", AbilityTagsScript.MATCH_ALL)),
		route.get("exclude", [])) as Dictionary
	return report["solutions"]


func _class_terms() -> Array[String]:
	var terms: Array[String] = []
	for entity_value: Variant in _load(ENTITIES_PATH).get("entities", []):
		var entity: Dictionary = entity_value
		terms.append(String(entity.get("id", "")).replace("_", " "))
		terms.append(String(entity.get("display_name", "")))
	return terms


func _names_a_class(body: String, terms: Array[String]) -> String:
	for term in terms:
		if term.is_empty():
			continue
		var pattern := RegEx.new()
		pattern.compile("(?i)\\b%s\\b" % term.replace(" ", "\\s+"))
		if pattern.search(body) != null:
			return term
	return ""


func _audit_identity(level: Dictionary) -> void:
	# The runtime id is what PlayerProfile keys routes, completions and unlocks on.
	_check(String(level.get("level_id", "")) == "level_3", "runtime id is level_3",
		String(level.get("level_id", "")))
	_check(int(level.get("order", 0)) == THIS_LEVEL, "order is 3",
		str(int(level.get("order", 0))))


func _audit_every_route_resolves(level: Dictionary) -> void:
	var floor_hits: Array[String] = []
	for entry in _routes_of(level):
		var label := "%s.%s" % [entry[0], entry[1]]
		var route: Dictionary = entry[2]
		if route.has("answered_by"):
			_pass(label, "answered by %s -- not a drawing" % route["answered_by"])
			continue
		var solved := _solutions(route)
		if solved.size() < AbilityTagsScript.MIN_SOLUTIONS:
			_fail(label, "resolves %d class(es) %s -- an obstacle with one answer"
				% [solved.size(), solved])
			continue
		if solved.size() == AbilityTagsScript.MIN_SOLUTIONS:
			floor_hits.append(label)
		_pass(label, "%d: %s" % [solved.size(), ", ".join(solved)])
	if not floor_hits.is_empty():
		_pass("routes at the 2-class floor",
			"%s -- any recall drop here leaves one solution" % ", ".join(floor_hits))


## ⚠ A SWIMMER LIST THAT RESOLVES TO NOTHING DROWNS EVERYTHING. The ban list fails safe --
## banning nothing is a level with no rule. This one fails the other way, because it says
## which classes are allowed, so an empty list reverts every creature the player draws.
## LevelRestrictions reports it; this is where it is caught before a scene exists.
func _audit_aquatic_rule(level: Dictionary) -> void:
	var restrictions := LevelRestrictionsClass.new()
	var roster := PackedStringArray()
	for entity_value: Variant in _load(ENTITIES_PATH).get("entities", []):
		roster.append(String((entity_value as Dictionary).get("id", "")))
	var problems: Array = restrictions.load_from(level, roster)
	_check(problems.is_empty(), "the aquatic rule loads",
		"%d swimmer(s): %s" % [restrictions.swimmer_classes().size(),
			", ".join(restrictions.swimmer_classes())]
		if problems.is_empty() else "; ".join(PackedStringArray(problems)))
	_check(restrictions.aquatic_rule_armed() and not restrictions.swimmer_classes().is_empty(),
		"and it names somebody who can breathe",
		"armed with %d" % restrictions.swimmer_classes().size())

	# Every named class must exist in the MODEL, not only in the manifest: a rule naming a
	# class the recogniser cannot produce is a rule about nothing.
	var labels: Array = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LABELS_PATH))
	if parsed is Array:
		labels = parsed
	elif parsed is Dictionary:
		labels = (parsed as Dictionary).get("labels", [])
	if labels.is_empty():
		_pass("swimmers exist in the model", "no labels.json -- the model has not been exported")
		return
	var known: Dictionary = {}
	for label_value: Variant in labels:
		known[String(label_value).replace(" ", "_")] = true
	var strangers: Array[String] = []
	for entity_id in restrictions.swimmer_classes():
		if not known.has(entity_id):
			strangers.append(entity_id)
	_check(strangers.is_empty(), "swimmers exist in the model",
		"%d checked against labels.json" % restrictions.swimmer_classes().size()
		if strangers.is_empty() else "not in the model: %s" % ", ".join(strangers))
	restrictions.free()


## THE ONE THAT WOULD HAVE BITTEN. Four of the seven are not swimmer rigs -- crab and sea
## turtle walk, penguin is a biped, frog is a hopper -- and they reach the fish drive only
## through rig_profile.can_swim. A class listed as a swimmer without it is a player reverted
## for drawing exactly what the level asked for.
func _audit_swimmers_can_swim(level: Dictionary) -> void:
	var sea: Dictionary = (level.get("restrictions", {}) as Dictionary).get("aquatic_only", {})
	var landlubbers: Array[String] = []
	var amphibious: Array[String] = []
	for value: Variant in sea.get("swimmers", []):
		var entity_id := String(value)
		var profile: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("%s%s.json" % [RIGS_DIR, entity_id]))
		var rig: Dictionary = profile as Dictionary if profile is Dictionary else {}
		var rig_type := String(rig.get("rig_type", ""))
		if rig_type == "swimmer":
			continue
		if bool(rig.get("can_swim", false)):
			amphibious.append(entity_id)
			continue
		landlubbers.append("%s (%s, no can_swim)" % [entity_id, rig_type if not rig_type.is_empty() else "no profile"])
	_check(landlubbers.is_empty(), "every swimmer can actually swim",
		"%d amphibious via can_swim: %s" % [amphibious.size(), ", ".join(amphibious)]
		if landlubbers.is_empty() else "cannot: %s" % ", ".join(landlubbers))


func _audit_answers_are_recognisable(level: Dictionary) -> void:
	var report := _report()
	if report.is_empty():
		_pass("every answer is recognisable", "no metrics.json -- the model has not been evaluated")
		return
	var unusable: Array[String] = []
	var weakest: Array[String] = []
	for entry in _routes_of(level):
		var route: Dictionary = entry[2]
		if route.has("answered_by"):
			continue
		var lowest := 1.0
		var lowest_id := ""
		for candidate in _solutions(route):
			var recall := float((report.get(candidate, {}) as Dictionary).get("recall", 1.0))
			if recall < lowest:
				lowest = recall
				lowest_id = candidate
		if lowest < 0.5:
			unusable.append("%s.%s leans on '%s' at %.0f%% recall"
				% [entry[0], entry[1], lowest_id, lowest * 100.0])
		weakest.append("%s.%s %s %.0f%%" % [entry[0], entry[1], lowest_id, lowest * 100.0])
	_check(unusable.is_empty(), "every answer is recognisable",
		"weakest per route -- %s" % "; ".join(weakest) if unusable.is_empty()
		else "; ".join(unusable))


## BR-7, stated the way the roster forces it to be stated. The floor is not "every answer
## clears 0.70" -- `frog` is in Swim at 0.576 and the design put it there knowingly. It is
## "the gate is never ONLY answerable by something under the floor", so a player whose frog
## is misread has six other bodies and the level is still finishable.
func _audit_swim_gate_clears_the_floor(level: Dictionary) -> void:
	var report := _report()
	if report.is_empty():
		_pass("no gate rests on a weak class alone", "no metrics.json")
		return
	var thin: Array[String] = []
	var carried: Array[String] = []
	for entry in _routes_of(level):
		var route: Dictionary = entry[2]
		if route.has("answered_by"):
			continue
		var strong: Array[String] = []
		var weak: Array[String] = []
		for candidate in _solutions(route):
			var recall := float((report.get(candidate, {}) as Dictionary).get("recall", 0.0))
			if recall >= RECALL_FLOOR:
				strong.append(candidate)
			else:
				weak.append("%s %.0f%%" % [candidate, recall * 100.0])
		if strong.is_empty():
			thin.append("%s.%s has no answer at or above %.0f%%"
				% [entry[0], entry[1], RECALL_FLOOR * 100.0])
		elif not weak.is_empty():
			carried.append("%s.%s carries %s on %d strong answer(s)"
				% [entry[0], entry[1], ", ".join(weak), strong.size()])
	_check(thin.is_empty(), "no gate rests on a weak class alone",
		("; ".join(carried) if not carried.is_empty() else "every answer clears the floor")
		if thin.is_empty() else "; ".join(thin))


func _report() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(METRICS_PATH))
	return (parsed as Dictionary).get("classification_report", {}) if parsed is Dictionary else {}


func _audit_tags_taught_before_use(level: Dictionary) -> void:
	var problems: Array[String] = []
	for obstacle_value: Variant in level.get("obstacles", []):
		var obstacle: Dictionary = obstacle_value
		var taught: Array = obstacle.get("teaches_before_choice", [])
		for name_value: Variant in (obstacle.get("routes", {}) as Dictionary).keys():
			var route: Dictionary = (obstacle["routes"] as Dictionary)[name_value]
			for tag_value: Variant in route.get("required_tags", []):
				if not taught.has(String(tag_value)):
					problems.append("%s.%s needs '%s', which the beat does not teach"
						% [obstacle.get("id", "?"), name_value, tag_value])
	_check(problems.is_empty(), "tags taught before use",
		"every required tag is unlocked before its choice" if problems.is_empty()
		else "; ".join(problems))


## ⚠ THE MISTAKE `light` WAS ONE COMMIT AWAY FROM BEING. A tag cannot be required by a level
## and unlocked in a later one: the Ability Book would show it locked at the exact obstacle
## asking for it, and tags_for_class_by_level would keep it out of the hints as well.
func _audit_tags_unlock_by_this_level(level: Dictionary) -> void:
	var late: Array[String] = []
	var used: Dictionary = {}
	for entry in _routes_of(level):
		for tag_value: Variant in (entry[2] as Dictionary).get("required_tags", []):
			used[String(tag_value)] = true
	for obstacle_value: Variant in level.get("obstacles", []):
		for beat_value: Variant in (obstacle_value as Dictionary).get("sub_beats", []):
			for tag_value: Variant in (beat_value as Dictionary).get("required_tags", []):
				used[String(tag_value)] = true
	for tag_value: Variant in used.keys():
		var tag := String(tag_value)
		var unlock := int(tags.call("unlock_level", tag))
		if unlock > THIS_LEVEL:
			late.append("%s unlocks in level %d" % [tag, unlock])
	_check(late.is_empty(), "every tag used here is unlocked by 3",
		"%d tag(s): %s" % [used.size(), ", ".join(PackedStringArray(used.keys()))]
		if late.is_empty() else "; ".join(late))


## FR-8: a creature morph is refused off a checkpoint, so a beat that needs one and has no
## checkpoint before it is a beat that cannot be answered.
func _audit_checkpoints_precede_morphs(level: Dictionary) -> void:
	var declared: Dictionary = {}
	for checkpoint_value: Variant in level.get("checkpoints", []):
		declared[String((checkpoint_value as Dictionary).get("id", ""))] = true
	var problems: Array[String] = []
	var seen_any := false
	for obstacle_value: Variant in level.get("obstacles", []):
		var obstacle: Dictionary = obstacle_value
		var id := String(obstacle.get("id", "?"))
		var commit := String(obstacle.get("checkpoint_on_commit", ""))
		if (obstacle.get("routes", {}) as Dictionary).is_empty():
			# A tutorial beat is answered at the level's opening checkpoint.
			seen_any = seen_any or not declared.is_empty()
			continue
		if commit.is_empty():
			problems.append("%s commits no checkpoint" % id)
		elif not declared.has(commit):
			problems.append("%s names checkpoint '%s', which is not declared" % [id, commit])
	_check(problems.is_empty() and seen_any, "checkpoint per route commit",
		"%d checkpoints declared" % declared.size() if problems.is_empty() and seen_any
		else ("; ".join(problems) if not problems.is_empty()
			else "no checkpoint precedes the tutorial beat"))


func _audit_no_line_names_a_class(dialogue: Dictionary) -> void:
	var terms := _class_terms()
	var offenders: Array[String] = []
	for line_value: Variant in dialogue.get("lines", []):
		var line: Dictionary = line_value
		# The button too, not only the line: they are the same sentence.
		var named := _names_a_class("%s %s" % [line.get("text", ""), line.get("choice_label", "")], terms)
		if not named.is_empty():
			offenders.append("%s names '%s'" % [line.get("id", "?"), named])
	_check(offenders.is_empty(), "no line names a class",
		"%d lines clean" % (dialogue.get("lines", []) as Array).size()
		if offenders.is_empty() else "; ".join(offenders))


## level_02.json's objectives block claims its audit holds these to the same rule. It did
## not. In a level set in the sea, where seventeen of the fifty are things you would reach
## for, it is not a formality.
func _audit_no_objective_names_a_class(level: Dictionary) -> void:
	var terms := _class_terms()
	var offenders: Array[String] = []
	var counted := 0
	for key_value: Variant in (level.get("objectives", {}) as Dictionary).keys():
		var key := String(key_value)
		if key.begins_with("$"):
			continue
		counted += 1
		var named := _names_a_class(String((level["objectives"] as Dictionary)[key]), terms)
		if not named.is_empty():
			offenders.append("objective '%s' names '%s'" % [key, named])
	_check(offenders.is_empty(), "no objective names a class",
		"%d objective lines clean" % counted if offenders.is_empty()
		else "; ".join(offenders))


func _audit_dialogue_hooks_exist(level: Dictionary, dialogue: Dictionary) -> void:
	var hooks: Dictionary = {}
	for line_value: Variant in dialogue.get("lines", []):
		hooks[String((line_value as Dictionary).get("at", ""))] = true
	var missing: Array[String] = []
	for obstacle_value: Variant in level.get("obstacles", []):
		var obstacle: Dictionary = obstacle_value
		var id := String(obstacle.get("id", "?"))
		if (obstacle.get("routes", {}) as Dictionary).is_empty():
			# A tutorial beat asks for itself through its sub-beats instead.
			for beat_value: Variant in obstacle.get("sub_beats", []):
				var beat_id := "%s.%s" % [id, (beat_value as Dictionary).get("id", "?")]
				if not hooks.has(beat_id):
					missing.append(beat_id)
			continue
		for expected in ["%s.enter" % id, "%s.teach" % id, "%s.choice" % id]:
			if not hooks.has(expected):
				missing.append(expected)
		for name_value: Variant in (obstacle.get("routes", {}) as Dictionary).keys():
			if not hooks.has("%s.%s.commit" % [id, name_value]):
				missing.append("%s.%s.commit" % [id, name_value])
	_check(missing.is_empty(), "dialogue hooks present",
		"%d distinct hooks" % hooks.size() if missing.is_empty()
		else "no line for: %s" % ", ".join(missing))


func _audit_every_route_has_a_button(level: Dictionary, dialogue: Dictionary) -> void:
	var script := DialogueScriptClass.new()
	_check(script.load_from(DIALOGUE_PATH), "dialogue loads", DIALOGUE_PATH)
	var problems: Array[String] = []
	for obstacle_value: Variant in level.get("obstacles", []):
		var obstacle: Dictionary = obstacle_value
		var id := String(obstacle.get("id", "?"))
		if (obstacle.get("routes", {}) as Dictionary).is_empty():
			continue
		var choices: Dictionary = script.choices_for(id)
		for name_value: Variant in (obstacle.get("routes", {}) as Dictionary).keys():
			if not choices.has(String(name_value)):
				problems.append("%s.%s has no button" % [id, name_value])
	for line_value: Variant in dialogue.get("lines", []):
		var line: Dictionary = line_value
		if not line.has("choice_label"):
			continue
		if String(line.get("speaker", "")) != "apo":
			problems.append("%s is a button the apo does not say" % line.get("id", "?"))
		if not String(line.get("text", "")).begins_with(String(line["choice_label"])):
			problems.append("%s: button and line have drifted" % line.get("id", "?"))
	_check(problems.is_empty(), "every route has a button",
		"read off the commit lines, spoken by the apo" if problems.is_empty()
		else "; ".join(problems))


func _audit_conditions_match_effects(level: Dictionary, dialogue: Dictionary) -> void:
	var settable: Dictionary = {}
	for entry in _routes_of(level):
		var route: Dictionary = entry[2]
		for key in ["persistent_effect", "sets_flag", "cross_level_effect"]:
			if route.has(key):
				settable[String(route[key])] = true
	for name_value: Variant in (level.get("inherited_effects", {}) as Dictionary).keys():
		settable[String(name_value)] = true
	var orphans: Array[String] = []
	for line_value: Variant in dialogue.get("lines", []):
		var line: Dictionary = line_value
		var condition := String(line.get("condition", ""))
		if not condition.is_empty() and not settable.has(condition):
			orphans.append("%s waits on '%s', which nothing sets" % [line.get("id", "?"), condition])
	_check(orphans.is_empty(), "conditions match effects",
		"%d flags declared" % settable.size() if orphans.is_empty() else "; ".join(orphans))


const HOST_SOURCES := ["res://scripts/level_3.gd", "res://scripts/level_base.gd"]


## The other direction: every line somebody WROTE has to be said. Five of Piyesta's were not,
## and a line nobody fires is indistinguishable from a line nobody has reached yet.
func _audit_no_line_is_unreachable(level: Dictionary, dialogue: Dictionary) -> void:
	var reachable: Dictionary = {"on_first_decline": true, "after_first_decline_solved": true}
	for obstacle_value: Variant in level.get("obstacles", []):
		var obstacle: Dictionary = obstacle_value
		var id := String(obstacle.get("id", "?"))
		for suffix in ["enter", "teach", "choice", "solved", "warn"]:
			reachable["%s.%s" % [id, suffix]] = true
		# ⚠ SUB-BEATS, which Piyesta had none of. The base fires "<id>.<stage_id>" on entering
		# a stage and "<id>.<stage_id>.solved" when it lands; a reachable set built only from
		# routes reports Dagat's whole shore tutorial as dead.
		for beat_value: Variant in obstacle.get("sub_beats", []):
			var beat := String((beat_value as Dictionary).get("id", "?"))
			reachable["%s.%s" % [id, beat]] = true
			reachable["%s.%s.solved" % [id, beat]] = true
		for route_value: Variant in (obstacle.get("routes", {}) as Dictionary).keys():
			for suffix in ["commit", "solved", "warn", "failed", "retry"]:
				reachable["%s.%s.%s" % [id, route_value, suffix]] = true
	var literal := RegEx.create_from_string("\"([A-Za-z0-9_%]+(?:\\.[A-Za-z0-9_%]+)*)\"")
	for path in HOST_SOURCES:
		if not FileAccess.file_exists(path):
			continue
		var source := FileAccess.get_file_as_string(path)
		for found in literal.search_all(source):
			reachable[found.get_string(1)] = true

	var prefixes: Array[String] = []
	for key: Variant in reachable.keys():
		var text := String(key)
		var cut := text.find("%")
		if cut > 0:
			prefixes.append(text.substr(0, cut))

	var dead: Array[String] = []
	for line_value: Variant in dialogue.get("lines", []):
		var hook := String((line_value as Dictionary).get("at", ""))
		if hook.is_empty() or reachable.has(hook):
			continue
		var built := false
		for prefix in prefixes:
			if hook.begins_with(prefix):
				built = true
				break
		if not built:
			dead.append("%s (%s)" % [hook, (line_value as Dictionary).get("id", "?")])
	_check(dead.is_empty(), "every authored line has a caller",
		"nothing in dialogue_l3.json is written and never said" if dead.is_empty()
		else "never fired: %s" % ", ".join(dead))


## ⚠ SCENE_PATH AND ENDS_RUN HAVE TO AGREE, and this check is written to be meaningful in
## BOTH states rather than to be a stub until the level ships.
##
## Not shipped: level_3 has no scene_path, does not end the run, and level_2 does.
## Shipped:     level_3 has a scene_path that loads, ends the run, and level_2 no longer does.
##
## Anything else is a half-shipped level -- a hub card with nothing behind it, or a player
## who finishes Piyesta and is sent to the ending screen with Dagat unplayed. The check turns
## over on its own when levels.json changes, so nobody has to remember to come back for it.
func _audit_shipping_state() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEVELS_PATH))
	var scene_path := ""
	var ends_run := false
	var piyesta_ends_run := false
	for entry_value: Variant in (parsed as Array):
		var entry: Dictionary = entry_value
		match String(entry.get("id", "")):
			"level_3":
				scene_path = String(entry.get("scene_path", ""))
				ends_run = bool(entry.get("ends_run", false))
			"level_2":
				piyesta_ends_run = bool(entry.get("ends_run", false))
	var shipped := not scene_path.is_empty()
	if shipped:
		_check(ResourceLoader.exists(scene_path) and ends_run and not piyesta_ends_run,
			"shipped, and it ends the run",
			"scene_path '%s', dagat ends_run=%s, piyesta ends_run=%s"
				% [scene_path, ends_run, piyesta_ends_run])
	else:
		_check(not ends_run and piyesta_ends_run,
			"not shipped yet, and consistently so",
			"no scene_path; piyesta still ends the run")


## ⚠ ONE SEABED, AGREED ON BY EVERYTHING THAT STANDS ON IT. The floor is typed in three places
## -- the painted terraces (DeepBand's plate_top + floor_drop + the plate's floor row), the
## Seabed collision, and level_3.gd's BED_Y that the coral and bubbles are placed on -- and it
## moved twice while the level was being painted. Each time something was left behind: coral
## inside the rock, a treasure point under the floor, refills floating a hundred pixels up.
##
## And the space around it has to be sealed: the sea has to reach the bed (or there is a layer
## of air at the bottom of the ocean), and the land at both ends has to go down to it (or there
## is an air pocket under the beach a diver can fall into and not get out of -- which there was).
func _audit_one_seabed(level: Dictionary) -> void:
	const FLOOR_ROW := 789.0
	var scene := (load(ENVIRONMENT_PATH) as PackedScene).instantiate()
	var bed_node := scene.get_node("GameplayPlane/Terrain/Seabed") as Node2D
	var bed_shape := (bed_node.get_node("Shape") as CollisionShape2D).shape as RectangleShape2D
	var collision_top := bed_node.position.y - bed_shape.size.y * 0.5
	var deep := scene.get_node("DeepBand")
	var painted := float(deep.get("plate_top")) + float(deep.get("floor_drop")) + FLOOR_ROW
	var typed := float((load(LEVEL_SCRIPT_PATH) as GDScript).get_script_constant_map()["BED_Y"])
	_check(absf(collision_top - painted) < 1.0 and absf(typed - painted) < 1.0,
		"one seabed", "painted %.0f, collision %.0f, BED_Y %.0f" % [painted, collision_top, typed])

	var stray: Array[String] = []
	for pair: Variant in (level.get("ink_economy", {}) as Dictionary).get("refill_spots", []):
		var spot := Vector2(float((pair as Array)[0]), float((pair as Array)[1]))
		if spot.y > painted + 1.0 or spot.y < painted - 12.0:
			stray.append("(%d, %d)" % [spot.x, spot.y])
	var creature := scene.get_node("GameplayPlane/Bakunawa") as Node2D
	var treasure: Vector2 = creature.position + (creature.get("treasure_offset") as Vector2)
	if treasure.y > painted:
		stray.append("treasure (%d, %d)" % [treasure.x, treasure.y])
	_check(stray.is_empty(), "refills and the treasure are on the bed, not in it",
		"all within 12 px above %.0f" % painted if stray.is_empty()
		else "off the bed: %s" % ", ".join(stray))

	var sea := scene.get_node("GameplayPlane/Sea") as Node2D
	var sea_size: Vector2 = sea.get("surface_size")
	var sea_bottom := sea.position.y + sea_size.y * 0.5
	var sealed: Array[String] = []
	if sea_bottom < painted:
		sealed.append("the sea stops at %.0f" % sea_bottom)
	for land_name in ["Shore", "Island"]:
		var land := scene.get_node("GameplayPlane/Terrain/%s" % land_name) as Node2D
		var shape := (land.get_node("Shape") as CollisionShape2D).shape as RectangleShape2D
		var land_bottom := land.position.y + shape.size.y * 0.5
		if land_bottom < painted:
			sealed.append("%s stops at %.0f" % [land_name, land_bottom])
	_check(sealed.is_empty(), "no air under the land or the sea",
		"sea and both shores reach the bed at %.0f" % painted if sealed.is_empty()
		else ", ".join(sealed))
	scene.free()
