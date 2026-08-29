extends SceneTree
## Level 2 data audit: the load_time_assertions from level_02.json, run as a suite.
##   godot --headless --path game --script res://tests/run_level2_audit.gd
##
## DATA ONLY, on purpose. Level 2 has no scene yet, and the assertions that matter most are
## the ones that are true or false before a scene exists: an obstacle that resolves to one
## class, a tag taught after the choice that needs it, a dialogue line naming a class. The
## scene checks (R1-R10 measured off real nodes, the nodraw bot) come with the geometry.
##
## THREE OF THESE CHECKS ARE NEW and exist because Level 2 restricts what may be drawn --
## something no level has done before:
##   * the two-answer floor is measured AFTER the banned-class list is subtracted, not just
##     after the route's own exclusions;
##   * every class named in a restriction must exist in labels.json, or the rule silently
##     bans nothing;
##   * no route may require a class the flight ceiling punishes -- the tag layer offering an
##     answer the restriction handler then takes back is the worst failure this game has.

const AbilityTagsScript = preload("res://scripts/ability_tags.gd")
const DialogueScriptClass = preload("res://scripts/dialogue_script.gd")
const UtilityObjectClass = preload("res://scripts/utility_object.gd")

const TAGS_PATH := "res://config/tags.json"
const LEVEL_PATH := "res://config/level_02.json"
const DIALOGUE_PATH := "res://config/dialogue_l2.json"
const ENTITIES_PATH := "res://config/entities.json"
const LABELS_PATH := "res://../model/labels.json"
const LEVELS_PATH := "res://config/levels.json"

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

	print("\n===== LEVEL 2 (PISTA) DATA AUDIT =====")
	_audit_identity(level)
	_audit_every_route_resolves(level)
	_audit_ban_list_subtracted(level)
	_audit_restriction_classes_exist(level)
	_audit_no_route_fights_the_ceiling(level)
	_audit_ranged_routes_can_reach(level)
	_audit_tags_taught_before_use(level)
	_audit_checkpoints_precede_morphs(level)
	_audit_no_line_names_a_class(dialogue)
	_audit_dialogue_hooks_exist(level, dialogue)
	_audit_every_route_has_a_button(level, dialogue)
	_audit_conditions_match_effects(level, dialogue)
	_audit_not_yet_playable()

	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_LEVEL2_AUDIT_OK")
		quit(0)
	else:
		print("OBRA_LEVEL2_AUDIT_FAILED=%d" % failures)
		quit(1)


func _load(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	return parsed as Dictionary if parsed is Dictionary else {}


func _audit_identity(level: Dictionary) -> void:
	# The runtime id is what PlayerProfile keys on; renaming it orphans every profile.
	_check(String(level.get("level_id", "")) == "level_2", "runtime id is level_2",
		String(level.get("level_id", "")))
	_check(String(level.get("design_level_id", "")) == "L2_PISTA", "design id is L2_PISTA",
		String(level.get("design_level_id", "")))
	_check(String(level.get("unlocks_on_complete", "")) == "L3_DAGAT", "unlocks Dagat",
		String(level.get("unlocks_on_complete", "")))


## Routes not answered by drawing declare it, and are exempt from the floor rather than
## silently failing a check that was never about them.
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


## THE NEW ONE. A banned class still carries its tag, so AbilityTags happily counts it as
## a solution to a route in a level where it can never be drawn. Level 1 never needed this
## because Level 1 bans nothing.
func _audit_ban_list_subtracted(level: Dictionary) -> void:
	var banned: Array = ((level.get("restrictions", {}) as Dictionary)
		.get("banned_playable_classes", {}) as Dictionary).get("classes", [])
	var problems: Array[String] = []
	var bitten: Array[String] = []
	for entry in _routes_of(level):
		var route: Dictionary = entry[2]
		if route.has("answered_by"):
			continue
		var solved := _solutions(route)
		var left: Array[String] = []
		var lost: Array[String] = []
		for candidate in solved:
			if banned.has(candidate): lost.append(candidate)
			else: left.append(candidate)
		if not lost.is_empty():
			bitten.append("%s.%s loses %s" % [entry[0], entry[1], ", ".join(lost)])
		if left.size() < AbilityTagsScript.MIN_SOLUTIONS:
			problems.append("%s.%s resolves %d after the ban list %s"
				% [entry[0], entry[1], left.size(), left])
	_check(problems.is_empty(), "two answers AFTER the ban list",
		("%d banned class(es); %s" % [banned.size(),
			"; ".join(bitten) if not bitten.is_empty() else "no route loses an answer"])
		if problems.is_empty() else "; ".join(problems))


## A restriction naming a class that is not in labels.json bans nothing and fails silently
## at runtime, which is the one outcome the design says must not happen.
func _audit_restriction_classes_exist(level: Dictionary) -> void:
	var text := FileAccess.get_file_as_string(LABELS_PATH)
	var parsed: Variant = JSON.parse_string(text)
	var labels: Array = parsed as Array if parsed is Array else []
	# labels.json holds Quick Draw SOURCE labels ("sea turtle"); restrictions name entity
	# ids. Map through the manifest so the comparison is like-for-like.
	var by_id: Dictionary = {}
	for entity_value: Variant in _load(ENTITIES_PATH).get("entities", []):
		var entity: Dictionary = entity_value
		by_id[String(entity.get("id", ""))] = String(entity.get("quickdraw_label", ""))
	var missing: Array[String] = []
	var checked := 0
	var restrictions: Dictionary = level.get("restrictions", {})
	for rule_value: Variant in restrictions.keys():
		var rule: Variant = restrictions[rule_value]
		if not (rule is Dictionary):
			continue
		for class_value: Variant in (rule as Dictionary).get("classes", []):
			var class_id := String(class_value)
			checked += 1
			if not by_id.has(class_id):
				missing.append("%s (%s) is not in entities.json" % [class_id, rule_value])
			elif not labels.has(by_id[class_id]):
				missing.append("%s (%s) is not in labels.json" % [class_id, rule_value])
	_check(missing.is_empty(), "restriction classes exist",
		"%d class(es) across %d rule(s), all in the manifest and the model"
		% [checked, restrictions.size() - 1] if missing.is_empty() else "; ".join(missing))


## THE TRAP THIS LEVEL INVENTS. A route may not be answerable by a class the flight ceiling
## sends back to a checkpoint: the tag layer would offer it, the level would accept it as an
## answer, and the restriction handler would take it away. `bat` carries `climb`, and Node 3
## asks the player to climb TO the bandaritas -- which ARE the ceiling.
func _audit_no_route_fights_the_ceiling(level: Dictionary) -> void:
	var ceiling: Array = ((level.get("restrictions", {}) as Dictionary)
		.get("flight_ceiling", {}) as Dictionary).get("classes", [])
	var problems: Array[String] = []
	for entry in _routes_of(level):
		var route: Dictionary = entry[2]
		if route.has("answered_by"):
			continue
		for candidate in _solutions(route):
			if ceiling.has(candidate):
				problems.append("%s.%s accepts '%s', which the ceiling punishes"
					% [entry[0], entry[1], candidate])
	_check(problems.is_empty(), "no route fights the ceiling",
		"%d capped class(es), none reachable as an answer" % ceiling.size()
		if problems.is_empty() else "; ".join(problems))


## AN ANSWER THAT CANNOT REACH IS NOT AN ANSWER, and the tag layer cannot see it.
##
## `strike` means "able to hit hard in one place", which is true of a boomerang, an axe and
## a sword. Level 2 asks it to knock a bird out of the air, and only one of those three
## leaves the hand -- a blade swings inside TOOL_REACH. So the route resolved to three
## classes, the player drew any of them, the game accepted the drawing, and two of the
## three then did nothing at all. That is the same defect as a route accepting a class the
## ceiling punishes, one layer down, and it is invisible to every check that reads data.
##
## A route that needs distance declares `requires_reach_px`; every class it accepts must
## have a behaviour that reaches at least that far. The reaches are READ OFF the constants
## in utility_object.gd rather than copied here, so tuning a throw cannot silently
## invalidate a level.
func _audit_ranged_routes_can_reach(level: Dictionary) -> void:
	var roster: Dictionary = {}
	for entity_value: Variant in _load(ENTITIES_PATH).get("entities", []):
		var entity: Dictionary = entity_value
		roster[String(entity.get("id", ""))] = entity
	var problems: Array[String] = []
	var checked := 0
	for entry in _routes_of(level):
		var route: Dictionary = entry[2]
		if not route.has("requires_reach_px"):
			continue
		var needed := float(route["requires_reach_px"])
		for candidate in _solutions(route):
			var entity: Dictionary = roster.get(candidate, {})
			# A creature has no utility_behavior; it reaches by BEING somewhere, and a
			# route that needs a thrown answer should not have resolved to one.
			var behaviour := String(entity.get("utility_behavior", ""))
			if behaviour.is_empty():
				problems.append("%s.%s accepts '%s', which is not a thing you throw"
					% [entry[0], entry[1], candidate])
				continue
			var reach: float = UtilityObjectClass.reach_of(behaviour)
			checked += 1
			if reach < needed:
				problems.append("%s.%s accepts '%s', which reaches %.0fpx of the %.0fpx it needs"
					% [entry[0], entry[1], candidate, reach, needed])
	_check(problems.is_empty(), "a ranged route's answers can reach",
		"%d answer(s) checked against their real reach" % checked
		if problems.is_empty() else "; ".join(problems))


func _audit_tags_taught_before_use(level: Dictionary) -> void:
	var known: Dictionary = {}
	var unlock_at: Dictionary = {}
	for entry_value: Variant in level.get("tags_unlocked", []):
		var entry: Dictionary = entry_value
		unlock_at[String(entry.get("tag", ""))] = String(entry.get("at", ""))
	var problems: Array[String] = []
	for obstacle_value: Variant in level.get("obstacles", []):
		var obstacle: Dictionary = obstacle_value
		var id := String(obstacle.get("id", "?"))
		for tag_value: Variant in unlock_at.keys():
			if String(unlock_at[tag_value]).begins_with(id):
				known[String(tag_value)] = true
		for tag_value: Variant in obstacle.get("teaches_before_choice", []):
			known[String(tag_value)] = true
		for name_value: Variant in (obstacle.get("routes", {}) as Dictionary).keys():
			var route: Dictionary = (obstacle["routes"] as Dictionary)[name_value]
			for tag_value: Variant in route.get("required_tags", []):
				if not known.has(String(tag_value)):
					problems.append("%s.%s needs '%s'" % [id, name_value, tag_value])
	_check(problems.is_empty(), "tags taught before use",
		"%d tags, all unlocked before the choice needing them" % known.size()
		if problems.is_empty() else "; ".join(problems))


func _audit_checkpoints_precede_morphs(level: Dictionary) -> void:
	var declared: Dictionary = {}
	for cp_value: Variant in level.get("checkpoints", []):
		declared[String((cp_value as Dictionary).get("id", ""))] = true
	var problems: Array[String] = []
	for obstacle_value: Variant in level.get("obstacles", []):
		var obstacle: Dictionary = obstacle_value
		if (obstacle.get("routes", {}) as Dictionary).is_empty():
			continue
		var cp := String(obstacle.get("checkpoint_on_commit", ""))
		if cp.is_empty():
			problems.append("%s commits a route with no checkpoint" % obstacle.get("id", "?"))
		elif not declared.has(cp):
			problems.append("%s names undeclared %s" % [obstacle.get("id", "?"), cp])
	_check(problems.is_empty(), "checkpoint per route commit",
		"%d checkpoints declared" % declared.size() if problems.is_empty()
		else "; ".join(problems))


func _audit_no_line_names_a_class(dialogue: Dictionary) -> void:
	var terms: Array[String] = []
	for entity_value: Variant in _load(ENTITIES_PATH).get("entities", []):
		var entity: Dictionary = entity_value
		terms.append(String(entity.get("id", "")).replace("_", " "))
		terms.append(String(entity.get("display_name", "")))
	var offenders: Array[String] = []
	for line_value: Variant in dialogue.get("lines", []):
		var line: Dictionary = line_value
		# The button too, not only the line: they are the same sentence and the strip is
		# read by the same player.
		var body := "%s %s" % [line.get("text", ""), line.get("choice_label", "")]
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
		for name_value: Variant in (obstacle.get("routes", {}) as Dictionary).keys():
			if not hooks.has("%s.%s.commit" % [id, name_value]):
				missing.append("%s.%s.commit" % [id, name_value])
	_check(missing.is_empty(), "dialogue hooks present",
		"%d distinct hooks" % hooks.size() if missing.is_empty()
		else "no line for: %s" % ", ".join(missing))


## The button and the line are literally the same string, and the apo is the one who says
## it. A paraphrase between the two is the player reading one sentence and hearing another.
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


## scene_path LAST. Three tests assert Level 2 is not playable while it is empty, and they
## are right to: a path to a scene that half-exists is a card the hub will happily offer.
func _audit_not_yet_playable() -> void:
	var text := FileAccess.get_file_as_string(LEVELS_PATH)
	var parsed: Variant = JSON.parse_string(text)
	var listed := ""
	for entry_value: Variant in (parsed as Array):
		var entry: Dictionary = entry_value
		if String(entry.get("id", "")) == "level_2":
			listed = String(entry.get("scene_path", ""))
	_check(listed.is_empty(), "level 2 is not yet playable",
		"levels.json scene_path is still empty, which is correct until a scene exists"
		if listed.is_empty() else "scene_path is '%s' -- filled in too early" % listed)
