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


## ⚠ EVERY OBJECTIVE FITS ITS BANNER. The banner is one line, at most ObjectiveBanner.MAX_WIDTH
## wide, and it trims anything longer to an ellipsis. Played through, the line at the creature's
## fork was the one trimmed -- "Something that can LIGHT or STRIKE -- or slip by while it is
## loo..." -- so the only words on screen saying there was a third way past cut off in the middle
## of saying it. So was the first line of the level. Measured with the banner's own font at its
## own size: every line, and every `.tags` line with its own obstacle's tags put into it, each
## with its `{key:...}` written out as the key it names.
##
## ⚠ WHICH OBSTACLE A `.tags` LINE SPEAKS FOR is level_3.gd's _current_objective's to decide, and
## it is written down here for the same reason: a `.tags` line with no entry here fails rather
## than being skipped, so a new one cannot arrive unmeasured.
##
## `dive_draw` is shown once the dive is chosen, when its tags are the dive's own; measured here
## against the crossing before the choice, which puts in both ways' tags -- the longer reading,
## so a line that fits it fits the one the player sees.
const OBJECTIVE_OBSTACLE := {"dive_draw": "L3_N1", "bakunawa": "L3_N2"}


func _audit_objectives_fit(level: Dictionary) -> void:
	var level_scene := (load("res://level_3.tscn") as PackedScene).instantiate() as Node2D
	(level_scene.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level_scene)
	for _frame in range(4):
		await process_frame
	var label := (level_scene.get("objective_banner") as Control).get("_label") as Label
	var font := label.get_theme_font(&"font")
	var font_size := label.get_theme_font_size(&"font_size")
	var director = level_scene.get("director")
	var readings: Array[String] = []
	var table: Dictionary = level.get("objectives", {})
	for key: String in table.keys():
		if key.begins_with("$"):
			continue
		if not key.ends_with(".tags"):
			readings.append(String(table[key]))
			continue
		var owner := String(OBJECTIVE_OBSTACLE.get(key.trim_suffix(".tags"), ""))
		var spec: Dictionary = director.call("requirement_spec", owner) if not owner.is_empty() \
			else {}
		var needed: Array = spec.get("required_tags", [])
		if needed.is_empty():
			readings.append("%s: no obstacle to take its tags from" % key)
			continue
		readings.append(String(table[key]).replace("{tags}", String(level_scene.call(
			"_objective_tags", needed, String(spec.get("match", "all"))))))
	var cut: Array[String] = []
	for index in range(readings.size()):
		# With its keys in, the way the banner writes it.
		readings[index] = String(level_scene.call("with_keys", readings[index]))
	for line in readings:
		var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		if width > ObjectiveBanner.MAX_WIDTH or line.contains("no obstacle to take"):
			cut.append("\"%s\" (%.0f px)" % [line, width])
	_check(font != null and not readings.is_empty() and cut.is_empty(),
		"every objective fits its banner",
		"%d readings, none wider than %.0f px" % [readings.size(), ObjectiveBanner.MAX_WIDTH]
		if cut.is_empty() else "trimmed: " + ", ".join(cut))
	level_scene.queue_free()
	await process_frame


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
	_audit_land_is_the_ground()
	_audit_checkpoints_are_spread_out(level)
	await _audit_sea_marks()
	await _audit_objectives_fit(level)

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
	# ⚠ READ AS SHOWN. A `{key:redraw}` is written out as "R" before anybody sees it -- and
	# `key` is one of the fifty, so read raw every line that names a key named a class.
	var base = load("res://scripts/level_base.gd")
	for key_value: Variant in (level.get("objectives", {}) as Dictionary).keys():
		var key := String(key_value)
		if key.begins_with("$"):
			continue
		counted += 1
		var shown := String(base.with_keys(String((level["objectives"] as Dictionary)[key])))
		var named := _names_a_class(shown, terms)
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

	# ⚠ CONVERSATIONS, THE REPLAY POOL AND THE FORK REMINDERS ARE FIRED FROM DATA. The
	# welcome-back greetings and fun facts are played by LevelBase._run_conversation out of
	# this same file, and a fork answered before opens with `<obstacle>.choice.again.<route>`
	# (LevelBase._remind_of_last_choice). A step naming a hook no line carries says nothing,
	# and is reported rather than counted.
	for obstacle_value: Variant in level.get("obstacles", []):
		var forked: Dictionary = (obstacle_value as Dictionary).get("routes", {})
		var fork_id := String((obstacle_value as Dictionary).get("id", "?"))
		for route_value: Variant in forked.keys():
			reachable["%s.choice.again.%s" % [fork_id, route_value]] = true
		if not forked.is_empty():
			reachable["%s.choice.again.all" % fork_id] = true
	var steps: Array = []
	for conversation_value: Variant in (dialogue.get("conversations", {}) as Dictionary).values():
		if conversation_value is Array:
			steps.append_array(conversation_value)
	for entry_value: Variant in dialogue.get("returns", []):
		steps.append_array((entry_value as Dictionary).get("steps", []))
	var spoken_ids: Dictionary = {}
	var authored_hooks: Dictionary = {}
	for line_value: Variant in dialogue.get("lines", []):
		authored_hooks[String((line_value as Dictionary).get("at", ""))] = true
	var empty_steps: Array[String] = []
	for step_value: Variant in steps:
		var step: Dictionary = step_value
		for key in ["say", "ask", "again"]:
			if step.has(key):
				reachable[String(step[key])] = true
				if not authored_hooks.has(String(step[key])):
					empty_steps.append(String(step[key]))
		for option_value: Variant in step.get("options", []):
			var option: Dictionary = option_value
			spoken_ids[String(option.get("line", ""))] = true
			if option.has("then"):
				reachable[String(option["then"])] = true
	_check(empty_steps.is_empty(), "every conversation step has words",
		"%d steps" % steps.size() if empty_steps.is_empty()
		else "says nothing: %s" % ", ".join(empty_steps))

	var dead: Array[String] = []
	for line_value: Variant in dialogue.get("lines", []):
		var hook := String((line_value as Dictionary).get("at", ""))
		if hook.is_empty() or reachable.has(hook) \
				or spoken_ids.has(String((line_value as Dictionary).get("id", ""))):
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
## -- the painted floor strip (DeepBand's plate_top + floor_drop + the row the strip is pinned
## at + its walking row), the Seabed collision, and level_3.gd's BED_Y that the coral and
## bubbles are placed on -- and it moved twice while the level was being painted. Each time
## something was left behind: coral inside the rock, a treasure point under the floor, refills
## floating a hundred pixels up. The strip is also read at that row, so a redrawn floor whose
## sand starts lower than it says fails here rather than on screen.
##
## And the space around it has to be sealed: the sea has to reach the bed (or there is a layer
## of air at the bottom of the ocean), and the land at both ends has to go down to it (or there
## is an air pocket under the beach a diver can fall into and not get out of -- which there was).
func _audit_one_seabed(level: Dictionary) -> void:
	var scene := (load(ENVIRONMENT_PATH) as PackedScene).instantiate()
	var bed_node := scene.get_node("GameplayPlane/Terrain/Seabed") as Node2D
	var bed_shape := (bed_node.get_node("Shape") as CollisionShape2D).shape as RectangleShape2D
	var collision_top := bed_node.position.y - bed_shape.size.y * 0.5
	var deep := scene.get_node("DeepBand")
	var floor_art := (deep.get_script() as GDScript).get_script_constant_map()
	var walk := float(floor_art["SEABED_WALK"])
	var painted := float(deep.get("plate_top")) + float(deep.get("floor_drop")) \
		+ float(floor_art["SEABED_TOP_ROW"]) + walk
	var typed := float((load(LEVEL_SCRIPT_PATH) as GDScript).get_script_constant_map()["BED_Y"])
	_check(absf(collision_top - painted) < 1.0 and absf(typed - painted) < 1.0,
		"one seabed", "painted %.0f, collision %.0f, BED_Y %.0f" % [painted, collision_top, typed])
	var strip := (load(String(floor_art["SEABED_FLOOR"])) as Texture2D).get_image()
	if strip.is_compressed():
		strip.decompress()
	var bare := 0
	for x in range(strip.get_width()):
		if strip.get_pixel(x, int(walk)).a < 0.99:
			bare += 1
	_check(bare == 0, "and the painted floor is sand at that row, all the way across",
		"%d of %d columns bare at row %d" % [bare, strip.get_width(), int(walk)])

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
	# The channel has to be a wall from above the water to below the bed, at both stagings.
	var seal: Vector2 = creature.get("seal_span")
	if seal == Vector2.ZERO or seal.x > sea.position.y - sea_size.y * 0.5 - 40.0 or seal.y < painted + 20.0:
		sealed.append("the coils seal %s, not the whole column" % seal)
	_check(sealed.is_empty(), "no air under the land or the sea",
		"sea, both shores and the coils all reach the bed at %.0f" % painted if sealed.is_empty()
		else ", ".join(sealed))
	scene.free()



## ⚠ ONE CHECKPOINT TO A STRETCH. CP1 was an area at x 640 on the beach and CP2, written when the
## crossing is chosen, planted its mark at 860: two checkpoints, two notices, a few seconds apart
## on a beach where nothing can be lost (Kent: "why is there two checkpoints in the first part of
## level 3, i think that is unnecessary"). Every mark the level shows -- an area's own, and the
## one a commit plants at its obstacle's far edge -- has to be well clear of every other.
const CHECKPOINT_SPACING := 600.0


func _audit_checkpoints_are_spread_out(level: Dictionary) -> void:
	var scene := (load(ENVIRONMENT_PATH) as PackedScene).instantiate()
	var marks := {}
	var commits := {}
	for entry: Dictionary in (level.get("obstacles", []) as Array):
		var on_commit := String(entry.get("checkpoint_on_commit", ""))
		if not on_commit.is_empty():
			commits[String(entry.get("id", ""))] = on_commit
	for node in scene.find_children("*", "Area2D", true, false):
		if "checkpoint_id" in node and not String(node.get("checkpoint_id")).is_empty():
			marks[String(node.get("checkpoint_id"))] = (node as Node2D).position
		elif "obstacle_id" in node and commits.has(String(node.get("obstacle_id"))) \
				and bool(node.get("plants_commit_mark")):
			var size: Vector2 = node.get("trigger_size")
			marks[commits[String(node.get("obstacle_id"))]] = (node as Node2D).position + Vector2(
				size.x * 0.5 - 40.0 + float(node.get("checkpoint_mark_offset")), 0.0)
	var crowded: Array[String] = []
	var ids := marks.keys()
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var gap := (marks[ids[i]] as Vector2).distance_to(marks[ids[j]] as Vector2)
			if gap < CHECKPOINT_SPACING:
				crowded.append("%s and %s are %.0f px apart" % [ids[i], ids[j], gap])
	_check(crowded.is_empty(), "one checkpoint to a stretch",
		"%d marks, every pair at least %.0f px apart" % [marks.size(), CHECKPOINT_SPACING]
			if crowded.is_empty() else ", ".join(crowded))
	scene.free()


## ⚠ THE LAND YOU SEE IS THE LAND YOU STAND ON. Each beach is a picture (build_dagat_props.py)
## that the shore band sets down over a collision rectangle, and the two are typed in different
## files. The first rebuild drew the home beach's sand ending 53 pixels short of its collision and
## the island's starting 28 pixels inside its own, so the apo walked out over open water at both
## ends -- the exact look being fixed -- and a diver met an invisible wall in the water. So each
## picture is read where the backdrop puts it: the sand's top row is the collision's top, the sand
## ends on the collision's sea edge at that row, and no row of the face stops short of the edge by
## more than 16 pixels. (Not zero: the edge is whole stones forty to seventy pixels wide, and the
## generator chooses which -- see its LANDS.)
func _audit_land_is_the_ground() -> void:
	var scene := (load(ENVIRONMENT_PATH) as PackedScene).instantiate()
	var band := scene.get_node("ShoreBand")
	var constants := (band.get_script() as GDScript).get_script_constant_map()
	var plate_top := float(band.get("plate_top"))
	var shore_rows: Array = (constants["BANDS"] as Dictionary)["shore"]
	var found: Array[String] = []
	var problems: Array[String] = []
	for pair: Array in [[String(constants["LAND_HOME"]), "Shore"], [String(constants["LAND_ISLAND"]), "Island"]]:
		var key := String(pair[0])
		var land := scene.get_node("GameplayPlane/Terrain/%s" % pair[1]) as Node2D
		var size := ((land.get_node("Shape") as CollisionShape2D).shape as RectangleShape2D).size
		var top := land.position.y - size.y * 0.5
		var sea_right := String(pair[1]) == "Shore"
		var edge := land.position.x + size.x * 0.5 if sea_right else land.position.x - size.x * 0.5
		var row: Dictionary = {}
		for candidate: Dictionary in shore_rows:
			if String(candidate["key"]) == key:
				row = candidate
		if row.is_empty():
			problems.append("%s is not in the shore band" % key.get_file())
			continue
		var piece: Dictionary = (row["pieces"] as Array)[0]
		var image := (load(key) as Texture2D).get_image()
		if image.is_compressed():
			image.decompress()
		var at_parts := String(piece["at"]).split(".")
		var ground: Vector2 = band.get(at_parts[0])
		var at := ground.x if at_parts[1] == "x" else ground.y
		at += float(piece.get("nudge", 0.0))
		var left := at if String(piece["align"]) == "left" else at - image.get_width()
		var first := image.get_used_rect().position.y
		var walking := plate_top + float(row["top_row"]) + first
		# How far row `y` reaches out past the edge: + over the sea, - short of it.
		var reach := func(y: int) -> float:
			if sea_right:
				for x in range(image.get_width() - 1, -1, -1):
					if image.get_pixel(x, y).a > 0.0:
						return left + x + 1 - edge
			else:
				for x in range(image.get_width()):
					if image.get_pixel(x, y).a > 0.0:
						return edge - (left + x)
			return -INF
		var at_feet: float = reach.call(first)
		var shortest := INF
		var shortest_at := 0
		for y in range(first + 34, image.get_height()):
			var r: float = reach.call(y)
			if r < shortest:
				shortest = r
				shortest_at = y
		found.append("%s: walks at %.0f on %.0f, sand %+.0f at the edge, face %+.0f at worst" % [
			pair[1], walking, top, at_feet, shortest])
		if absf(walking - top) > 0.5:
			problems.append("%s's sand is at %.0f, its collision at %.0f" % [pair[1], walking, top])
		if absf(at_feet) > 2.0:
			problems.append("%s's sand ends %.0f %s its collision's edge at %.0f" % [
				pair[1], absf(at_feet), "short of" if at_feet < 0.0 else "past", edge])
		if shortest < -16.0:
			problems.append("%s's face stops %.0f short of the edge at world y %.0f" % [
				pair[1], -shortest, plate_top + float(row["top_row"]) + shortest_at])
	_check(problems.is_empty(), "the land drawn is the land stood on",
		"; ".join(found) if problems.is_empty() else ", ".join(problems))
	scene.free()


## ⚠ WHAT STANDS ON THE SEABED IS OF THE SEA. The checkpoint was a stone lantern with a fire in
## it and the boards were wooden signposts: under the water the first was left off altogether
## ("a lit lantern at the bottom of the sea is not a thing") and the second stood there anyway,
## three pale planks on posts at the encounter. Under the sea they are a giant clam and a broken
## pillar from the ruins -- see under_the_sea.gd -- and on the beach exactly what they were.
##
## Read off the real level, planted and settled, because both decide their form from where they
## end up standing: a data check cannot see it.
func _audit_sea_marks() -> void:
	var level_scene := (load("res://level_3.tscn") as PackedScene).instantiate() as Node2D
	(level_scene.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level_scene)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(12):
		await physics_frame
	var bed := float((load(LEVEL_SCRIPT_PATH) as GDScript).get_script_constant_map()["BED_Y"])
	var sea := level_scene.get_node("EnvironmentBaseplate/GameplayPlane/Sea") as Node2D
	var surface := float(sea.call("surface_y"))
	var sea_size: Vector2 = sea.get("surface_size")
	var wrong: Array[String] = []
	var floating: Array[String] = []
	var under := 0
	var over := 0
	for node in level_scene.find_children("*", "", true, false):
		var mark := node as Node2D
		if mark == null:
			continue
		var is_lantern := node is CheckpointLantern2D
		var is_sign := node is Signpost2D
		if not is_lantern and not is_sign:
			continue
		var at := mark.global_position
		var inside := at.y > surface + 8.0 and absf(at.x - sea.global_position.x) <= sea_size.x * 0.5
		var sea_form := int(mark.get("form")) == 1 if is_lantern else bool(mark.get("_sea"))
		if inside:
			under += 1
			if absf(at.y - bed) > 2.0:
				floating.append("%s at y %.0f" % [mark.name, at.y])
		else:
			over += 1
		if sea_form != inside:
			wrong.append("%s at (%.0f, %.0f) is %s" % [mark.name, at.x, at.y,
				"of the sea on dry land" if sea_form else "a land mark under the sea"])
	_check(wrong.is_empty() and under > 0 and over > 0, "marks take the sea's forms under it",
		"%d under the sea, %d on land, every one in its own form" % [under, over]
		if wrong.is_empty() else ", ".join(wrong))
	_check(floating.is_empty(), "and the sea's marks stand on the bed",
		"all at %.0f" % bed if floating.is_empty() else ", ".join(floating))
	var clam := level_scene.get_node_or_null(
		"EnvironmentBaseplate/GameplayPlane/Obstacles/CP3b/Checkpoint") as Node2D
	_check(clam != null and int(clam.get("form")) == 1,
		"the checkpoint mid-encounter is marked",
		"a clam on the bed under CP3b -- it was a line of text and nothing on screen")
	# AND ONLY WHERE A LEVEL ASKS. A mark planted in this same sea by something that is not
	# part of a level that opted in stays what it is: Payyo's paddy is water too.
	var stranger := Node2D.new()
	root.add_child(stranger)
	stranger.global_position = Vector2(3000.0, 1400.0)
	var loose := CheckpointLantern2D.plant(stranger, Vector2.ZERO)
	var loose_sign := Signpost2D.plant(stranger, Signpost2D.Mark.HINT, Vector2.ZERO)
	await physics_frame
	await physics_frame
	_check(loose != null and int(loose.get("form")) == 0 and not bool(loose_sign.get("_sea")),
		"and only in a level that asks for them",
		"the same water, no under_the_sea on the way up: a lantern and a board")
	stranger.queue_free()
	level_scene.queue_free()
	await process_frame

