extends SceneTree
## Level 4 audit: Dilim's load_time_assertions, its lines, its ground, and the hooks it turns on.
##   godot --headless --path game --script res://tests/run_level4_audit.gd
##
## Three parts. THE DATA (level_04.json, dialogue_l4.json) is true or false before anything runs.
## THE GROUND is read off the environment scene: every beat has a volume and a mark, in order,
## and the canopy is a ceiling over every one of them. THE LEVEL is level_4.tscn opened headless:
## no Lolo, her opening in her voice, the fighting hooks on, the dark by zone, the knockout in
## Lola's words, and the banner by where she is.
##
## WHAT IS NEW AGAINST THE LEVELS BEFORE IT, and why each check exists:
##
##   * EVERY ENCOUNTER HAS A WAY PAST THAT IS NOT A FIGHT (Kent's design: "combat be survivable
##     without combat skill"). A route asking for `strike` is the fight; one more is required.
##   * NOTHING STORY-SHAPED MID-ENCOUNTER. A lore line pauses the whole tree. Once something is
##     hunting her, only `hint` lines -- the hint bar, which never stops play -- may be said.
##   * THE CANOPY IS A CEILING, measured with a ray: over every beat, higher than the tallest
##     thing she can place and jump off (LEVEL_2.md R9), so it blocks flight and nothing else.
##   * EVERY LINE IS HERS. Lolo stopped at the water; a line in his voice here is a ghost.

const AbilityTagsScript = preload("res://scripts/ability_tags.gd")
const DialogueScriptClass = preload("res://scripts/dialogue_script.gd")

const LEVEL_PATH := "res://config/level_04.json"
const DIALOGUE_PATH := "res://config/dialogue_l4.json"
const ENTITIES_PATH := "res://config/entities.json"
const TAGS_PATH := "res://config/tags.json"
const LEVELS_PATH := "res://config/levels.json"
const METRICS_PATH := "res://../model/metrics.json"
const SCENE_PATH := "res://level_4.tscn"
const HOST_SOURCES := ["res://scripts/level_4.gd", "res://scripts/level_base.gd"]

## BR-7. No critical-path obstacle may depend on a class whose held-out recall is under this.
const RECALL_FLOOR := 0.70
const THIS_LEVEL := 4
## Where she stands, and the tallest thing she can place and then jump off: a tree, 268, and her
## jump, 94 (LEVEL_2.md R9). The canopy has to be higher than that.
const GROUND_Y := 600.0
const PLACED_REACH := 362.0
## The route that is a fight.
const FIGHT_TAG := "strike"

var results: Array[String] = []
var failures := 0
var tags: Node


func _initialize() -> void:
	call_deferred("_run")


func _pass(what: String, detail: String) -> void:
	results.append("  OK    %-40s %s" % [what, detail])


func _fail(what: String, detail: String) -> void:
	results.append("  FAIL  %-40s %s" % [what, detail])
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

	print("\n===== LEVEL 4 (DILIM) AUDIT =====")
	# The data.
	_audit_identity(level)
	_audit_every_route_resolves(level)
	_audit_no_gate_rests_on_a_weak_class(level)
	_audit_tags_unlock_by_this_level(level)
	_audit_every_encounter_has_a_way_round(level)
	_audit_the_mound_is_not_a_fight(level)
	_audit_ink_before_every_drawn_encounter(level)
	_audit_lighting_states(level)
	_audit_every_line_is_hers(dialogue)
	_audit_no_line_names_a_class(dialogue)
	_audit_no_objective_names_a_class(level)
	_audit_nothing_story_shaped_mid_encounter(level)
	_audit_no_line_is_unreachable(level, dialogue)
	_audit_shipping_state()
	# The ground and the level.
	var scene := await _open_level()
	_audit_beats_in_order(level, scene)
	_audit_checkpoints_in_their_clearings(level, scene)
	_audit_canopy_over_every_beat(level, scene)
	_audit_santelmo_before_the_mound(scene)
	_audit_the_night_is_in_the_last_clearing(scene)
	_audit_nothing_stands_on_the_crown(scene)
	_audit_jars_where_the_file_says(level, scene)
	_audit_the_tiyanak_earns_nothing(scene)
	_audit_the_far_sides_gaps(scene)
	_audit_the_high_path(scene)
	_audit_the_giant_stands_in_the_crossing(scene)
	_audit_level_goes_alone(scene)
	_audit_fighting_hooks_on(scene)
	_audit_dark_by_zone(level, scene)
	_audit_knockout_in_lolas_words(scene, dialogue)
	await _audit_banner_by_place(scene)
	_audit_objectives_fit(level, scene)
	scene.queue_free()
	await process_frame

	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_LEVEL4_AUDIT_OK")
		quit(0)
	else:
		print("OBRA_LEVEL4_AUDIT_FAILED=%d" % failures)
		quit(1)


# --- The data ------------------------------------------------------------------------

func _audit_identity(level: Dictionary) -> void:
	_check(String(level.get("level_id", "")) == "level_4" and int(level.get("order", 0)) == THIS_LEVEL
			and String(level.get("tally", "")) == "majority",
		"level_4, order 4, tallied by majority",
		"%s / %d / %s" % [level.get("level_id", "?"), int(level.get("order", 0)), level.get("tally", "-")])


func _audit_every_route_resolves(level: Dictionary) -> void:
	var short: Array[String] = []
	var floor_hits: Array[String] = []
	var drawn := 0
	for entry in _routes_of(level):
		var route: Dictionary = entry[2]
		if route.has("answered_by"):
			continue
		drawn += 1
		var solved := _solutions(route)
		if solved.size() < AbilityTagsScript.MIN_SOLUTIONS:
			short.append("%s.%s resolves %s" % [entry[0], entry[1], solved])
		elif solved.size() == AbilityTagsScript.MIN_SOLUTIONS:
			floor_hits.append("%s.%s" % [entry[0], entry[1]])
	_check(drawn > 0 and short.is_empty(), "every drawn route has two answers",
		"%d drawn routes; at the floor: %s" % [drawn, ", ".join(floor_hits) if not floor_hits.is_empty() else "none"]
		if short.is_empty() else "; ".join(short))


## BR-7 as the roster forces it: the gate is never ONLY answerable by something under the floor.
func _audit_no_gate_rests_on_a_weak_class(level: Dictionary) -> void:
	var report := _report()
	if report.is_empty():
		_pass("no gate rests on a weak class alone", "no metrics.json -- the model has not been evaluated")
		return
	var thin: Array[String] = []
	for entry in _routes_of(level):
		var route: Dictionary = entry[2]
		if route.has("answered_by"):
			continue
		var strong := 0
		for candidate in _solutions(route):
			if float((report.get(candidate, {}) as Dictionary).get("recall", 0.0)) >= RECALL_FLOOR:
				strong += 1
		if strong == 0:
			thin.append("%s.%s" % [entry[0], entry[1]])
	_check(thin.is_empty(), "no gate rests on a weak class alone",
		"every drawn route has an answer at or above %.0f%% recall" % (RECALL_FLOOR * 100.0)
		if thin.is_empty() else "nothing at the floor: " + ", ".join(thin))


func _audit_tags_unlock_by_this_level(level: Dictionary) -> void:
	var table: Dictionary = _load(TAGS_PATH).get("tags", {})
	var late: Array[String] = []
	for entry in _routes_of(level):
		for tag_value: Variant in (entry[2] as Dictionary).get("required_tags", []):
			var tag := String(tag_value)
			var at := int((table.get(tag, {}) as Dictionary).get("unlocked_in_level", 99))
			if at > THIS_LEVEL:
				late.append("%s.%s needs '%s' (level %d)" % [entry[0], entry[1], tag, at])
	_check(late.is_empty(), "every tag it asks for is open by level 4",
		"light, strike, hoof, beast, absurd, weather, cut, span, climb" if late.is_empty()
		else "; ".join(late))


## Kent's design: "Every creature below has at least one non-combat resolution".
func _audit_every_encounter_has_a_way_round(level: Dictionary) -> void:
	var fights_only: Array[String] = []
	var counted := 0
	for obstacle in _encounters(level):
		counted += 1
		var another := false
		for route_value: Variant in (obstacle.get("routes", {}) as Dictionary).values():
			if not ((route_value as Dictionary).get("required_tags", []) as Array).has(FIGHT_TAG):
				another = true
		if not another:
			fights_only.append(String(obstacle.get("id", "?")))
	_check(counted >= 7 and fights_only.is_empty(), "every encounter has a way that is not a fight",
		"%d encounters" % counted if fights_only.is_empty() else "only a fight: " + ", ".join(fights_only))


## "Protector: none, deliberately. You cannot fight a mound."
func _audit_the_mound_is_not_a_fight(level: Dictionary) -> void:
	var nuno := _obstacle(level, "L4_NUNO")
	var routes: Dictionary = nuno.get("routes", {})
	var fights := false
	for route_value: Variant in routes.values():
		fights = fights or ((route_value as Dictionary).get("required_tags", []) as Array).has(FIGHT_TAG)
	_check(not nuno.is_empty() and not routes.has("protector") and not fights,
		"the mound has no fight", "routes: %s" % ", ".join(routes.keys()))


## Ink is the level's difficulty curve (Kent's design), so an encounter that can only be answered
## by drawing needs ink within reach: a jar before it.
func _audit_ink_before_every_drawn_encounter(level: Dictionary) -> void:
	var jars: Array = (level.get("ink_economy", {}) as Dictionary).get("jars_before", [])
	var dry: Array[String] = []
	var needs := 0
	for obstacle in _encounters(level):
		var free := false
		for route_value: Variant in (obstacle.get("routes", {}) as Dictionary).values():
			free = free or (route_value as Dictionary).has("answered_by")
		if free:
			continue
		needs += 1
		if not jars.has(String(obstacle.get("id", ""))):
			dry.append(String(obstacle.get("id", "?")))
	_check(dry.is_empty(), "ink before every encounter that needs a drawing",
		"%d need one, each with a jar before it" % needs if dry.is_empty()
		else "no ink-free way and no jar: " + ", ".join(dry))


const TRULY_DARK := 0.95


func _audit_lighting_states(level: Dictionary) -> void:
	var ids: Array[String] = []
	for obstacle_value: Variant in level.get("obstacles", []):
		ids.append(String((obstacle_value as Dictionary).get("id", "")))
	var wrong: Array[String] = []
	var states: Array = level.get("lighting_states", [])
	for state_value: Variant in states:
		var state: Dictionary = state_value
		var dark := float(state.get("darkness", -1.0))
		if not ids.has(String(state.get("from", ""))) or not ids.has(String(state.get("to", ""))) \
				or dark <= 0.0 or dark > 1.0:
			wrong.append(String(state.get("id", "?")))
	_check(not states.is_empty() and wrong.is_empty(), "every dark zone names its beats",
		"%d zones" % states.size() if wrong.is_empty() else "wrong: " + ", ".join(wrong))
	# TRULY DARK (Kent): outside a light the woods are all but black, so the light she has is a small
	# circle and one she makes is plainly more. At 0.8 the edge of the woods read as dusk.
	var light_ones: Array[String] = []
	for state_value: Variant in states:
		var state: Dictionary = state_value
		if float(state.get("darkness", 0.0)) < TRULY_DARK:
			light_ones.append("%s %.2f" % [state.get("id", "?"), float(state.get("darkness", 0.0))])
	_check(light_ones.is_empty(), "the woods are truly dark, every zone of them",
		"all at %.2f or darker" % TRULY_DARK if light_ones.is_empty() else "too light: " + ", ".join(light_ones))


func _audit_every_line_is_hers(dialogue: Dictionary) -> void:
	var script := DialogueScriptClass.new()
	script.load_from(DIALOGUE_PATH)
	var others: Array[String] = []
	var lines: Array = dialogue.get("lines", [])
	for line_value: Variant in lines:
		var line: Dictionary = line_value
		if script.speaker_of(line) != "apo" or String(line.get("speaker", "")) != "apo":
			others.append(String(line.get("id", "?")))
	_check(not lines.is_empty() and String(dialogue.get("speaker_default", "")) == "apo"
			and others.is_empty(),
		"every line is hers", "%d lines, speaker_default apo" % lines.size() if others.is_empty()
		else "not hers: " + ", ".join(others))


func _audit_no_line_names_a_class(dialogue: Dictionary) -> void:
	var terms := _class_terms()
	var offenders: Array[String] = []
	for line_value: Variant in dialogue.get("lines", []):
		var line: Dictionary = line_value
		var named := _names_a_class("%s %s" % [line.get("text", ""), line.get("choice_label", "")], terms)
		if not named.is_empty():
			offenders.append("%s names '%s'" % [line.get("id", "?"), named])
	_check(offenders.is_empty(), "no line names a class",
		"%d lines clean" % (dialogue.get("lines", []) as Array).size()
		if offenders.is_empty() else "; ".join(offenders))


func _audit_no_objective_names_a_class(level: Dictionary) -> void:
	var terms := _class_terms()
	var base = load("res://scripts/level_base.gd")
	var offenders: Array[String] = []
	var counted := 0
	for key_value: Variant in (level.get("objectives", {}) as Dictionary).keys():
		var key := String(key_value)
		if key.begins_with("$"):
			continue
		counted += 1
		var named := _names_a_class(String(base.with_keys(String(level["objectives"][key]))), terms)
		if not named.is_empty():
			offenders.append("'%s' names '%s'" % [key, named])
	_check(counted > 0 and offenders.is_empty(), "no objective names a class",
		"%d objectives clean" % counted if offenders.is_empty() else "; ".join(offenders))


## A lore line pauses the tree. Arriving, and the answer landing, are the only places a story
## line may be said at an encounter; anything else there has to be a hint. The finale is held to
## it too though it has no routes -- its night is the longest fight in the level -- with arriving
## and the morning as its two calm places.
func _audit_nothing_story_shaped_mid_encounter(level: Dictionary) -> void:
	var script := DialogueScriptClass.new()
	script.load_from(DIALOGUE_PATH)
	var calm: Dictionary = {}
	var encounter_ids: Array[String] = []
	for obstacle in _encounters(level):
		var id := String(obstacle.get("id", ""))
		encounter_ids.append(id)
		calm["%s.enter" % id] = true
		calm["%s.solved" % id] = true
		for route_value: Variant in (obstacle.get("routes", {}) as Dictionary).keys():
			calm["%s.%s.solved" % [id, route_value]] = true
	encounter_ids.append("L4_FINALE")
	calm["L4_FINALE.enter"] = true
	calm["L4_FINALE.solved"] = true
	var loud: Array[String] = []
	var checked := 0
	for line_value: Variant in script.hooks():
		var hook := String(line_value)
		if not encounter_ids.has(hook.get_slice(".", 0)):
			continue
		for line_entry: Variant in script.peek(hook):
			checked += 1
			var line: Dictionary = line_entry
			if not calm.has(hook) and script.kind_of(line) != "hint":
				loud.append("%s (%s)" % [line.get("id", "?"), hook])
	_check(loud.is_empty(), "nothing story-shaped mid-encounter",
		"%d encounter lines, each on arriving, answered, or a hint" % checked if loud.is_empty()
		else "stops the fight: " + ", ".join(loud))


## Every line somebody wrote has to be said. A line nobody fires looks exactly like a line nobody
## has reached yet. The same reading as Dagat's audit: the hooks the base fires per beat and per
## route, every hook literal in the level's sources, and every conversation step.
func _audit_no_line_is_unreachable(level: Dictionary, dialogue: Dictionary) -> void:
	var reachable: Dictionary = {"on_first_decline": true, "after_first_decline_solved": true}
	for obstacle_value: Variant in level.get("obstacles", []):
		var obstacle: Dictionary = obstacle_value
		var id := String(obstacle.get("id", "?"))
		for suffix in ["enter", "teach", "choice", "solved", "warn"]:
			reachable["%s.%s" % [id, suffix]] = true
		# A clearing's sub-beat: "<id>.<stage>" on entering it, "<id>.<stage>.solved" when it lands.
		for beat_value: Variant in obstacle.get("sub_beats", []):
			var beat := String((beat_value as Dictionary).get("id", "?"))
			reachable["%s.%s" % [id, beat]] = true
			reachable["%s.%s.solved" % [id, beat]] = true
		for route_value: Variant in (obstacle.get("routes", {}) as Dictionary).keys():
			for suffix in ["commit", "solved", "warn", "failed", "retry"]:
				reachable["%s.%s.%s" % [id, route_value, suffix]] = true
	var literal := RegEx.create_from_string("\"([A-Za-z0-9_%]+(?:\\.[A-Za-z0-9_%]+)*)\"")
	for path in HOST_SOURCES:
		for found in literal.search_all(FileAccess.get_file_as_string(path)):
			reachable[found.get_string(1)] = true
	var steps: Array = []
	for conversation_value: Variant in (dialogue.get("conversations", {}) as Dictionary).values():
		if conversation_value is Array:
			steps.append_array(conversation_value)
	for entry_value: Variant in dialogue.get("returns", []):
		steps.append_array((entry_value as Dictionary).get("steps", []))
	var authored: Dictionary = {}
	for line_value: Variant in dialogue.get("lines", []):
		authored[String((line_value as Dictionary).get("at", ""))] = true
	var empty_steps: Array[String] = []
	for step_value: Variant in steps:
		var say := String((step_value as Dictionary).get("say", ""))
		if say.is_empty():
			continue
		reachable[say] = true
		if not authored.has(say):
			empty_steps.append(say)
	var dead: Array[String] = []
	for line_value: Variant in dialogue.get("lines", []):
		var hook := String((line_value as Dictionary).get("at", ""))
		if not reachable.has(hook):
			dead.append("%s (%s)" % [hook, (line_value as Dictionary).get("id", "?")])
	_check(dead.is_empty() and empty_steps.is_empty(), "every line is said, every step has words",
		"%d lines, %d steps" % [(dialogue.get("lines", []) as Array).size(), steps.size()]
		if dead.is_empty() and empty_steps.is_empty()
		else "never said: %s; says nothing: %s" % [", ".join(dead), ", ".join(empty_steps)])


## Not on the hub until it is finished: levels.json names no scene for it, and Dagat still ends
## the run. Turns over by itself when levels.json changes.
func _audit_shipping_state() -> void:
	var scene_path := ""
	var ends_run := false
	var dagat_ends_run := false
	for entry_value: Variant in (JSON.parse_string(FileAccess.get_file_as_string(LEVELS_PATH)) as Array):
		var entry: Dictionary = entry_value
		match String(entry.get("id", "")):
			"level_4":
				scene_path = String(entry.get("scene_path", ""))
				ends_run = bool(entry.get("ends_run", false))
			"level_3":
				dagat_ends_run = bool(entry.get("ends_run", false))
	if scene_path.is_empty():
		_check(not ends_run and dagat_ends_run, "not shipped yet, and consistently so",
			"no scene_path; Dagat still ends the run")
	else:
		_check(ResourceLoader.exists(scene_path) and ends_run and not dagat_ends_run,
			"shipped, and it ends the run", "scene_path '%s'" % scene_path)


# --- The ground and the level --------------------------------------------------------

func _open_level() -> Node:
	var scene := (load(SCENE_PATH) as PackedScene).instantiate()
	# The opening is off in test runs unless asked for; whose voice it is in is checked here.
	scene.set(&"intro_enabled", true)
	(scene.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(scene)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(180)
	return scene


## Frames with every line put away as it comes, so the level never sits paused on one.
func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		if paused:
			call_group(DialogueBox.GROUP, &"hide_line")
			paused = false


func _audit_beats_in_order(level: Dictionary, scene: Node) -> void:
	var spans: Dictionary = scene.call("_beat_spans")
	var marks: Dictionary = scene.get_script().get_script_constant_map().get("BEAT_MARKS", {})
	var problems: Array[String] = []
	var west := -INF
	var count := 0
	for obstacle_value: Variant in level.get("obstacles", []):
		var id := String((obstacle_value as Dictionary).get("id", ""))
		count += 1
		if not spans.has(id):
			problems.append("%s has no ground" % id)
			continue
		var span: Vector2 = spans[id]
		if span.x < west:
			problems.append("%s starts before the beat ahead of it ends" % id)
		west = span.y
		var mark: Variant = scene.call("_mark_at", id)
		if not marks.has(id) or not (mark is Vector2) \
				or (mark as Vector2).x < span.x or (mark as Vector2).x > span.y:
			problems.append("%s has no mark on its own ground" % id)
	_check(count >= 10 and problems.is_empty(), "every beat has its ground and mark, in order",
		"%d beats, west to east as the level file lists them" % count if problems.is_empty()
		else "; ".join(problems))


func _audit_checkpoints_in_their_clearings(level: Dictionary, scene: Node) -> void:
	var spans: Dictionary = scene.call("_beat_spans")
	var areas: Dictionary = {}
	for node in scene.get_tree().get_nodes_in_group(&"checkpoint_areas"):
		var area := node as CheckpointArea2D
		if area != null:
			areas[area.checkpoint_id] = area.global_position.x
	var problems: Array[String] = []
	for checkpoint_value: Variant in level.get("checkpoints", []):
		var checkpoint: Dictionary = checkpoint_value
		var id := String(checkpoint.get("id", ""))
		var at := String(checkpoint.get("at", ""))
		var span: Vector2 = spans.get(at, Vector2(INF, -INF))
		if not areas.has(id):
			problems.append("%s has no area" % id)
		elif float(areas[id]) < span.x or float(areas[id]) > span.y:
			problems.append("%s stands outside %s" % [id, at])
	_check(not areas.is_empty() and problems.is_empty(), "every checkpoint stands in its clearing",
		"%s" % ", ".join(areas.keys()) if problems.is_empty() else "; ".join(problems))


## Measured, not read off the scene: a ray straight up from the ground in the middle of every beat
## has to meet the canopy, and meet it higher than anything she can build and jump off.
func _audit_canopy_over_every_beat(level: Dictionary, scene: Node) -> void:
	var spans: Dictionary = scene.call("_beat_spans")
	var space := (scene as Node2D).get_world_2d().direct_space_state
	# The canopy, not what stands under it: a branch or a rock is ground to stand on, and the
	# ray looks past every piece of the terrain that is not the ceiling.
	var past: Array[RID] = []
	var terrain := scene.get_node_or_null(^"EnvironmentBaseplate/GameplayPlane/Terrain")
	if terrain != null:
		for piece in terrain.get_children():
			if piece is CollisionObject2D and piece.name != "Canopy":
				past.append((piece as CollisionObject2D).get_rid())
	var problems: Array[String] = []
	var lowest := INF
	for obstacle_value: Variant in level.get("obstacles", []):
		var id := String((obstacle_value as Dictionary).get("id", ""))
		var span: Vector2 = spans.get(id, Vector2.ZERO)
		for x in [span.x + 20.0, (span.x + span.y) * 0.5, span.y - 20.0]:
			var query := PhysicsRayQueryParameters2D.create(Vector2(x, GROUND_Y - 4.0),
				Vector2(x, GROUND_Y - 3000.0), 1, past)
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				problems.append("open sky over %s at %.0f" % [id, x])
				continue
			var height := GROUND_Y - (hit["position"] as Vector2).y
			lowest = minf(lowest, height)
			if height <= PLACED_REACH:
				problems.append("%s's canopy at %.0f px, within reach" % [id, height])
	_check(problems.is_empty() and lowest < INF, "the canopy is a ceiling over every beat",
		"lowest %.0f px over the ground, above the %.0f px reach" % [lowest, PLACED_REACH]
		if problems.is_empty() else "; ".join(problems))


## Segment 1 is "santelmo and the nuno" (Kent's design): a flame between where she starts and the
## mound, floating where it can reach her -- at her middle, not over her head.
func _audit_santelmo_before_the_mound(scene: Node) -> void:
	var spans: Dictionary = scene.call("_beat_spans")
	var mound_west := (spans.get("L4_NUNO", Vector2.ZERO) as Vector2).x
	var start := (scene.get("spawn_point") as Node2D).global_position.x
	var placed: Array[String] = []
	var ahead := false
	for node in scene.find_children("*", "Node2D", true, false):
		var flame := node as Santelmo2D
		if flame == null:
			continue
		var at := flame.home()
		placed.append("%.0f,%.0f" % [at.x, at.y])
		var reaches := at.y > GROUND_Y - 100.0 and at.y < GROUND_Y - 30.0
		ahead = ahead or (at.x > start and at.x < mound_west and reaches)
	_check(ahead, "a santelmo waits before the mound, within her reach",
		"at %s; the mound from %.0f" % [", ".join(placed), mound_west])


## One night, standing in the finale's beat and beginning exactly at its west edge -- where CP3
## puts her back -- so a knockout there starts it over and nothing short of it does.
func _audit_the_night_is_in_the_last_clearing(scene: Node) -> void:
	var span: Vector2 = (scene.call("_beat_spans") as Dictionary).get("L4_FINALE", Vector2.ZERO)
	var nights: Array[String] = []
	var right := false
	for node in scene.find_children("*", "Node2D", true, false):
		var night := node as DilimFinale2D
		if night == null:
			continue
		var x := night.global_position.x
		nights.append("%.0f from %.0f" % [x, night.arena_west])
		right = x > span.x and x < span.y and is_equal_approx(night.arena_west, span.x)
	_check(nights.size() == 1 and right, "the night stands in the last clearing, from its edge",
		"%s; the clearing %.0f..%.0f" % [", ".join(nights), span.x, span.y])


## A board planted on the nuno's mound puts the one thing she must not stand on under the thing
## she reads -- seen in a window, the "?" board stood on the crown. Every board stays off it.
func _audit_nothing_stands_on_the_crown(scene: Node) -> void:
	var mound := scene.get("_mound") as NunoMound2D
	var on_it: Array[String] = []
	var boards := 0
	for node in scene.get_tree().get_nodes_in_group(&"signposts"):
		var board := node as Node2D
		if board == null or mound == null:
			continue
		boards += 1
		if absf(board.global_position.x - mound.global_position.x) <= NunoMound2D.WIDTH * 0.5 + 20.0:
			on_it.append("%s at %.0f" % [board.name, board.global_position.x])
	_check(mound != null and boards > 0 and on_it.is_empty(), "no board stands on the nuno's mound",
		"%d boards clear of it" % boards if on_it.is_empty() else "on it: " + ", ".join(on_it))


## Every encounter level_04.json says has a jar before it has one: in the stretch between the beat
## before it and its own ground.
func _audit_jars_where_the_file_says(level: Dictionary, scene: Node) -> void:
	var spans: Dictionary = scene.call("_beat_spans")
	var order: Array[String] = []
	for obstacle_value: Variant in level.get("obstacles", []):
		order.append(String((obstacle_value as Dictionary).get("id", "")))
	var jars: Array[float] = []
	for node in scene.find_children("*", "Area2D", true, false):
		if node is InkJar2D:
			jars.append((node as Node2D).global_position.x)
	var missing: Array[String] = []
	var wanted: Array = (level.get("ink_economy", {}) as Dictionary).get("jars_before", [])
	for id_value: Variant in wanted:
		var id := String(id_value)
		var at := order.find(id)
		var from := (spans.get(order[at - 1], Vector2.ZERO) as Vector2).y if at > 0 else -INF
		var to := (spans.get(id, Vector2.ZERO) as Vector2).x
		if not jars.any(func(x: float) -> bool: return x > from and x < to):
			missing.append(id)
	_check(not wanted.is_empty() and missing.is_empty(), "a jar of ink before each encounter the file names",
		"%d jars, before %s" % [jars.size(), ", ".join(wanted)] if missing.is_empty() else "none before: " + ", ".join(missing))


## Kent's design: "The tiyanak fight earns nothing -- no drops."
func _audit_the_tiyanak_earns_nothing(scene: Node) -> void:
	var tiyanak := scene.get("_tiyanak") as Tiyanak2D
	_check(tiyanak != null and not tiyanak.drops, "the tiyanak drops nothing when it falls",
		"drops %s" % (tiyanak.drops if tiyanak != null else "no tiyanak"))


## The two gaps on the far side -- the drop by the cry, the ravine -- measured off the ground itself:
## each past a running jump (228) and under a drawn bridge (340), the design's numbers.
const RUNNING_JUMP := 228.0
const BRIDGE := 340.0
const JUMP := 94.3


func _audit_the_far_sides_gaps(scene: Node) -> void:
	var widths: Array[String] = []
	var fine := true
	for mark in ["TiyanakMark", "BungisngisMark"]:
		var at := (scene.find_child(mark, true, false) as Node2D).global_position
		var gap := _gap_in_the_floor(scene, at.x - 300.0, at.x + 800.0, at.y)
		widths.append("%s %.0f" % [mark.trim_suffix("Mark"), gap])
		fine = fine and gap > RUNNING_JUMP and gap < BRIDGE
	_check(fine, "each gap on the far side is past a running jump and under a bridge",
		", ".join(widths) + " px (%.0f < gap < %.0f)" % [RUNNING_JUMP, BRIDGE])


## The widest stretch with no floor under it, scanning `from` to `to` along the ground at `ground_y`.
func _gap_in_the_floor(scene: Node, from: float, to: float, ground_y: float) -> float:
	var space := (scene as Node2D).get_world_2d().direct_space_state
	var widest := 0.0
	var run := 0.0
	var x := from
	while x <= to:
		var ray := PhysicsRayQueryParameters2D.create(Vector2(x, ground_y - 6.0), Vector2(x, ground_y + 6.0),
			PhysicsLayers.WORLD)
		if space.intersect_ray(ray).is_empty():
			run += 5.0
			widest = maxf(widest, run)
		else:
			run = 0.0
		x += 5.0
	return widest


## The high path over the ravine: higher than a jump, so only something drawn to climb gets her up,
## and long enough to carry her over the ravine.
func _audit_the_high_path(scene: Node) -> void:
	var space := (scene as Node2D).get_world_2d().direct_space_state
	var ground := (scene.find_child("BungisngisMark", true, false) as Node2D).global_position.y
	var heights: Array[float] = []
	for x in [19160.0, 19300.0, 19440.0]:
		var ray := PhysicsRayQueryParameters2D.create(Vector2(x, ground - 300.0), Vector2(x, ground - 10.0),
			PhysicsLayers.WORLD)
		var hit := space.intersect_ray(ray)
		heights.append(ground - float(hit["position"].y) if not hit.is_empty() else 0.0)
	var over := heights.all(func(h: float) -> bool: return h > JUMP)
	_check(over, "the high path runs over the ravine, out of a jump's reach",
		"%s px up (a jump is %.0f)" % [heights, JUMP])


## Kent's design: "Blocks a crossing." It stands on the ravine's floor, its wall up.
func _audit_the_giant_stands_in_the_crossing(scene: Node) -> void:
	var giant := scene.get("_bungisngis") as Bungisngis2D
	var space := (scene as Node2D).get_world_2d().direct_space_state
	var ok := false
	var detail := "no bungisngis"
	if giant != null:
		var feet := giant.global_position + Vector2(0.0, giant.body_size.y * 0.5)
		var ray := PhysicsRayQueryParameters2D.create(feet - Vector2(30.0, 4.0), feet + Vector2(-30.0, 8.0),
			PhysicsLayers.WORLD)
		var floor_hit := space.intersect_ray(ray)
		var ground := (scene.find_child("BungisngisMark", true, false) as Node2D).global_position.y
		ok = not floor_hit.is_empty() and feet.y > ground + JUMP and giant.wall.collision_layer != 0
		detail = "feet at %.0f, %.0f under the bank; wall %s" % [feet.y, feet.y - ground, giant.wall.collision_layer != 0]
	_check(ok, "the bungisngis stands in the ravine's crossing, a wall", detail)


func _audit_level_goes_alone(scene: Node) -> void:
	var spoken := int(scene.get("script_lines").call("lines_spoken"))
	_check(String(root.get_node(^"LevelManager").get(&"current_level_id")) == "level_4"
			and scene.get("lolo") == null and spoken > 0,
		"it opens as level_4, alone, and says so", "no Lolo; %d opening line(s) said" % spoken)
	scene.call("_say_why", "Back to the path.")
	var hint := scene.get("hint_bar") as HintBar
	var expected := "%s:" % String(scene.get("APO_SPEAKER")).to_upper()
	_check(hint != null and hint.current_speaker() == expected, "its notes are in her own voice",
		hint.current_speaker() if hint != null else "-")


func _audit_fighting_hooks_on(scene: Node) -> void:
	var off: Array[String] = []
	for hook in ["_has_player_health", "_every_drawing_costs_ink", "_tool_wear_enabled",
			"_click_attacks", "_camera_follows_physics"]:
		if not bool(scene.call(hook)):
			off.append(hook)
	if not bool(scene.call("_draws_into_the_hand", "sword")):
		off.append("_draws_into_the_hand")
	if not bool((scene.get("player") as Node).get(&"can_walk")):
		off.append("can_walk")
	var built := scene.get("player_health") != null and scene.get("darkness_layer") != null \
		and scene.get("held_lantern") != null
	_check(off.is_empty() and built, "a level that fights: every hook on",
		"health, lantern, dark, wear, ink per drawing, into the hand, click, camera, walk"
		if off.is_empty() and built else "off: %s; built: %s" % [", ".join(off), built])


func _audit_dark_by_zone(level: Dictionary, scene: Node) -> void:
	var spans: Dictionary = scene.call("_beat_spans")
	var wrong: Array[String] = []
	for state_value: Variant in level.get("lighting_states", []):
		var state: Dictionary = state_value
		var span: Vector2 = spans.get(String(state.get("from", "")), Vector2.ZERO)
		var at := float(scene.call("_darkness_at", (span.x + span.y) * 0.5))
		if not is_equal_approx(at, float(state.get("darkness", -1.0))):
			wrong.append("%s reads %.2f" % [state.get("id", "?"), at])
	var opening := float((scene.get("darkness_layer") as Node).get(&"darkness"))
	_check(wrong.is_empty() and is_equal_approx(opening, float(
			(level["lighting_states"][0] as Dictionary).get("darkness", -1.0))),
		"the dark deepens by zone", "opens at %.2f; each zone its own" % opening
		if wrong.is_empty() else "; ".join(wrong))


func _audit_knockout_in_lolas_words(scene: Node, dialogue: Dictionary) -> void:
	var pool: Array[String] = []
	for line_value: Variant in dialogue.get("lines", []):
		if String((line_value as Dictionary).get("at", "")) == "RESPAWN":
			pool.append(String((line_value as Dictionary).get("text", "")))
	var said: Array[String] = []
	for _knockout in range(pool.size() + 1):
		said.append(String(scene.call("_knockout_words")))
	var in_turn := pool.size() >= 2 and said.slice(0, pool.size()) == pool and said[-1] == pool[0]
	_check(in_turn and pool[0].begins_with("Lola said the woods take people"),
		"a knockout is said in Lola's words, in turn", "%d lines, then round again" % pool.size()
		if in_turn else "said %s" % [said])


func _audit_banner_by_place(scene: Node) -> void:
	var player := scene.get("player") as Node2D
	var expected := {260.0: "edge", 4100.0: "woods", 5000.0: "rest", 15400.0: "rest",
		21000.0: "woods", 22000.0: "dawn"}
	var wrong: Array[String] = []
	for x: float in expected:
		player.call("apply_morph_state", {"position": Vector2(x, GROUND_Y - 10.0), "linear_velocity": Vector2.ZERO})
		await _frames(3)
		var goal: Dictionary = scene.call("_current_objective")
		var key := String(goal.get("key", ""))
		var target: Variant = goal.get("target", null)
		var points_on := key == "dawn" or (target is Vector2 and (target as Vector2).x >= x - 1.0)
		if key != String(expected[x]) or not points_on:
			wrong.append("at %.0f '%s' -> %s" % [x, key, target])
	_check(wrong.is_empty(), "the banner says what is next by where she is",
		"edge, woods, rest, dawn -- each pointing ahead of her" if wrong.is_empty()
		else "; ".join(wrong))


## Every objective is one line in the banner, at the smallest size the quest card sets a task.
func _audit_objectives_fit(level: Dictionary, scene: Node) -> void:
	var label := (scene.get("objective_banner") as Control).get("_label") as Label
	var font := label.get_theme_font(&"font")
	var cut: Array[String] = []
	var counted := 0
	for key_value: Variant in (level.get("objectives", {}) as Dictionary).keys():
		var key := String(key_value)
		if key.begins_with("$"):
			continue
		counted += 1
		var line := String(scene.call("with_keys", String(level["objectives"][key])))
		var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			ObjectiveBanner.SMALL).x
		if width > ObjectiveBanner.MAX_WIDTH:
			cut.append("\"%s\" (%.0f px)" % [line, width])
	_check(font != null and counted > 0 and cut.is_empty(), "every objective fits its banner",
		"%d lines, none wider than %.0f px" % [counted, ObjectiveBanner.MAX_WIDTH]
		if cut.is_empty() else "trimmed: " + ", ".join(cut))


# --- Helpers ----------------------------------------------------------------------------

func _load(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _report() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(METRICS_PATH))
	return (parsed as Dictionary).get("classification_report", {}) if parsed is Dictionary else {}


func _obstacle(level: Dictionary, id: String) -> Dictionary:
	for obstacle_value: Variant in level.get("obstacles", []):
		if String((obstacle_value as Dictionary).get("id", "")) == id:
			return obstacle_value
	return {}


## The beats something is met at: every obstacle with routes.
func _encounters(level: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for obstacle_value: Variant in level.get("obstacles", []):
		if not ((obstacle_value as Dictionary).get("routes", {}) as Dictionary).is_empty():
			out.append(obstacle_value)
	return out


func _routes_of(level: Dictionary) -> Array:
	var out: Array = []
	for obstacle in _encounters(level):
		for name_value: Variant in (obstacle["routes"] as Dictionary).keys():
			out.append([String(obstacle.get("id", "?")), String(name_value),
				(obstacle["routes"] as Dictionary)[name_value] as Dictionary])
	return out


func _solutions(route: Dictionary) -> PackedStringArray:
	var report := tags.call("resolve_report", route.get("required_tags", []),
		String(route.get("match", AbilityTagsScript.MATCH_ALL)), route.get("exclude", [])) as Dictionary
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
