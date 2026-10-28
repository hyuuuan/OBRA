extends SceneTree
## Mayon, checked against its own rules: the data, the ground and the level.
##
##   godot --headless --path game --script res://tests/run_level5_audit.gd

const AbilityTagsScript = preload("res://scripts/ability_tags.gd")
const LEVEL_PATH := "res://config/level_05.json"
const DIALOGUE_PATH := "res://config/dialogue_l5.json"
const SCRIPT_PATH := "res://scripts/level_5.gd"
const LEVELS_PATH := "res://config/levels.json"
const ENTITIES_PATH := "res://config/entities.json"
const METRICS_PATH := "res://../model/metrics.json"
const RECALL_FLOOR := 0.70
const GATES := ["L5_SPAN", "L5_CLIMB"]
## R1/R2/R4 and the tallest answers (LEVEL_TEMPLATE.md).
const RUNNING_JUMP := 228.0
const BRIDGE := 340.0
const PRIMITIVE_REACH := 174.0
const STAIRS_REACH := 270.0
const JUMP := 94.3
const FLOOR_BEFORE := 180.0

## Every check this audit makes. A script error that skips them must not pass as quiet.
const CHECKS := 12

var failures := 0
var checked := 0
var tags: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	tags = root.get_node_or_null("AbilityTags")
	if tags == null:
		tags = AbilityTagsScript.new()
		tags.name = "AbilityTags"
		root.add_child(tags)
	var level := _load(LEVEL_PATH)
	_audit_gates_have_two_strong_answers(level)
	_audit_no_line_names_a_class()
	_audit_nothing_refills(level)
	_audit_shipping_state()
	var scene := await _open_level()
	_audit_hooks(scene)
	_audit_the_reserve_is_the_gates(scene)
	_audit_gate_ground(scene)
	_audit_silent_checkpoints(scene, level)
	_audit_nothing_fights(scene)
	_audit_every_obstacle_has_a_volume(scene, level)
	_audit_the_fragments(scene)
	_audit_the_flower_is_off_the_path(scene)
	if checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_LEVEL5_AUDIT_OK")
		quit(0)
	else:
		print("OBRA_LEVEL5_AUDIT_FAILED=%d" % failures)
		quit(1)


## The doc's recall discipline: a misread gate in the climax is the worst place for it, so each
## gate has at least two answers at or above the floor, after its own exclusions.
func _audit_gates_have_two_strong_answers(level: Dictionary) -> void:
	var report := _report()
	var thin: Array[String] = []
	var seen: Array[String] = []
	for id: String in GATES:
		for beat_value: Variant in _obstacle(level, id).get("sub_beats", []):
			var beat: Dictionary = beat_value
			var answers := tags.call("resolve_report", beat.get("required_tags", []),
				String(beat.get("match", AbilityTagsScript.MATCH_ALL)), beat.get("exclude", [])) as Dictionary
			var strong: Array[String] = []
			for candidate: String in answers["solutions"]:
				if float((report.get(candidate, {}) as Dictionary).get("recall", 0.0)) >= RECALL_FLOOR:
					strong.append(candidate)
			seen.append("%s: %s" % [id, ", ".join(strong)])
			if strong.size() < 2:
				thin.append("%s.%s has %d" % [id, beat.get("id", "?"), strong.size()])
	_check(thin.is_empty() and seen.size() == GATES.size(),
		"each gate has two or more answers at or above %.0f%% recall" % (RECALL_FLOOR * 100.0),
		"; ".join(seen) if thin.is_empty() else "; ".join(thin))


func _audit_no_line_names_a_class() -> void:
	var terms := _class_terms()
	var hits: Array[String] = []
	for line_value: Variant in _load(DIALOGUE_PATH).get("lines", []):
		var text := String((line_value as Dictionary).get("text", "")).to_lower()
		for term in terms:
			var pattern := RegEx.create_from_string("\\b%s\\b" % term.to_lower())
			if pattern.search(text) != null:
				hits.append("%s names '%s'" % [(line_value as Dictionary).get("id", "?"), term])
	var objectives: Dictionary = _load(LEVEL_PATH).get("objectives", {})
	for key: String in objectives:
		if key.begins_with("$"):
			continue
		for term in terms:
			if RegEx.create_from_string("\\b%s\\b" % term.to_lower()).search(String(objectives[key]).to_lower()) != null:
				hits.append("objective %s names '%s'" % [key, term])
	_check(hits.is_empty(), "no line or objective names a drawable class",
		"none" if hits.is_empty() else "; ".join(hits.slice(0, 4)))


## No refill anywhere (the doc: "not one").
func _audit_nothing_refills(level: Dictionary) -> void:
	var economy: Dictionary = level.get("ink_economy", {})
	var source := FileAccess.get_file_as_string(SCRIPT_PATH)
	var refills: Array[String] = []
	for key in ["refilled_at", "jars_before"]:
		if economy.has(key):
			refills.append("ink_economy." + key)
	if source.contains("add_ink("):
		refills.append("level_5.gd calls add_ink")
	_check(refills.is_empty() and int(economy.get("capacity", 0)) == 6,
		"nothing on the mountain gives ink back, and the brush holds six",
		"no refill" if refills.is_empty() else ", ".join(refills))


## Mayon is not on the hub until it is built (PR 10 ships it).
func _audit_shipping_state() -> void:
	var path := ""
	for entry_value: Variant in JSON.parse_string(FileAccess.get_file_as_string(LEVELS_PATH)):
		var entry: Dictionary = entry_value
		if entry.get("id", "") == "level_5":
			path = String(entry.get("scene_path", ""))
	_check(path.is_empty(), "Mayon is not on the hub yet", "scene_path '%s'" % path)


func _audit_hooks(scene: Node) -> void:
	var on := ["_every_drawing_costs_ink", "_saves_silently", "_ink_always_visible",
		"_camera_follows_height", "_ends_with_its_own_scene"]
	var off := ["_has_player_health", "_morph_has_a_life", "_click_attacks", "_tool_wear_enabled"]
	var wrong: Array[String] = []
	for hook in on:
		if not bool(scene.call(hook)):
			wrong.append(hook + " is off")
	for hook in off:
		if bool(scene.call(hook)):
			wrong.append(hook + " is on")
	var camera := scene.call("_world_camera") as Camera2D
	if camera == null or not bool(camera.get("vertical_free")):
		wrong.append("the camera is pinned, not following her height")
	var reserve := (scene.get("ink_manager") as InkManager).hidden_reserve
	if not is_equal_approx(reserve, 2.0):
		wrong.append("hidden reserve %.1f, not 2" % reserve)
	_check(wrong.is_empty() and bool(scene.call("_has_companion")),
		"the level's hooks: ink is the story, saves are silent, no health, lolo with her",
		"as designed" if wrong.is_empty() else ", ".join(wrong))


func _audit_the_reserve_is_the_gates(scene: Node) -> void:
	var director := scene.get("director") as LevelDirector
	var at_the_foot := bool(scene.call("_may_use_hidden_ink", "bridge"))
	var at_gates: Array[bool] = []
	for id: String in GATES:
		director.enter_obstacle(id)
		at_gates.append(bool(scene.call("_may_use_hidden_ink", "bridge")))
		director.exit_obstacle(id)
	_check(not at_the_foot and at_gates == [true, true],
		"only the climb's gates may draw on the hidden reserve",
		"at the foot %s, at the gates %s" % [at_the_foot, at_gates])


## The span and the wall, read off the ground itself.
func _audit_gate_ground(scene: Node) -> void:
	var rects: Array[Rect2] = []
	for name in ["Slopes", "Cone"]:
		var body := scene.get_node("EnvironmentBaseplate/GameplayPlane/Terrain/" + name)
		for rect: Rect2 in body.get("platforms"):
			rects.append(rect)
	rects.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	var gaps: Array[String] = []
	var walls: Array[String] = []
	var wrong: Array[String] = []
	for index in range(1, rects.size()):
		var before := rects[index - 1]
		var after := rects[index]
		var gap := after.position.x - before.end.x
		var rise := before.position.y - after.position.y
		if gap > 1.0:
			gaps.append("%.0f wide after %.0f of floor" % [gap, before.size.x])
			if gap <= RUNNING_JUMP or gap >= BRIDGE or before.size.x < FLOOR_BEFORE:
				wrong.append("the gap at %.0f is %.0f across after %.0f of floor" % [before.end.x, gap, before.size.x])
		elif rise > JUMP:
			walls.append("%.0f up after %.0f of floor" % [rise, before.size.x])
			if rise <= PRIMITIVE_REACH or rise >= STAIRS_REACH or before.size.x < FLOOR_BEFORE:
				wrong.append("the wall at %.0f is %.0f up after %.0f of floor" % [after.position.x, rise, before.size.x])
	_check(wrong.is_empty() and gaps.size() == 1 and walls.size() == 1,
		"one span past a running jump and under a bridge, one wall past a primitive and under stairs, and every other step jumpable",
		"span %s; wall %s" % [", ".join(gaps), ", ".join(walls)] if wrong.is_empty() else "; ".join(wrong))


func _audit_silent_checkpoints(scene: Node, level: Dictionary) -> void:
	var declared: Array[String] = []
	for entry_value: Variant in level.get("checkpoints", []):
		declared.append(String((entry_value as Dictionary).get("id", "")))
	var found: Array[String] = []
	var loud: Array[String] = []
	for area in scene.find_children("*", "Area2D", true, false):
		if area.get("checkpoint_id") == null:
			continue
		found.append(String(area.get("checkpoint_id")))
		if bool(area.get("shows_mark")) or bool(area.get("lights_on_entry")):
			loud.append(String(area.get("checkpoint_id")))
	found.sort()
	declared.sort()
	_check(loud.is_empty() and found == declared and bool(scene.call("_saves_silently")),
		"every checkpoint is silent: no lantern, no letterbox, no word",
		"%s, all quiet" % ", ".join(found) if loud.is_empty() else "loud: " + ", ".join(loud))


func _audit_nothing_fights(scene: Node) -> void:
	var fighters: Array[String] = []
	for node in scene.find_children("*", "", true, false):
		if node is Enemy2D:
			fighters.append(String(node.name))
	_check(fighters.is_empty(), "nothing on the mountain fights",
		"no enemy" if fighters.is_empty() else ", ".join(fighters))


func _audit_every_obstacle_has_a_volume(scene: Node, level: Dictionary) -> void:
	var data: Array[String] = []
	for obstacle_value: Variant in level.get("obstacles", []):
		data.append(String((obstacle_value as Dictionary).get("id", "")))
	var volumes: Array[String] = []
	for area in scene.find_children("*", "Area2D", true, false):
		if area.get("obstacle_id") != null:
			volumes.append(String(area.get("obstacle_id")))
	data.sort()
	volumes.sort()
	_check(data == volumes, "every beat in the data has its volume in the ground, and no other",
		", ".join(volumes) if data == volumes else "data %s, ground %s" % [data, volumes])


## Act Two: twelve fragments, three with lolo in them, and every class that saves one reads at
## or above the floor -- a misread fragment costs nothing but is a choice taken away.
func _audit_the_fragments(scene: Node) -> void:
	var report := _report()
	var fragments := scene.find_children("*", "MemoryFragment2D", true, false)
	var lolo := 0
	var thin: Array[String] = []
	for node in fragments:
		var fragment := node as MemoryFragment2D
		if fragment.holds_lolo:
			lolo += 1
		var strong := 0
		for entity: String in fragment.accepts:
			if float((report.get(entity, {}) as Dictionary).get("recall", 0.0)) >= RECALL_FLOOR:
				strong += 1
			else:
				thin.append("%s: %s" % [fragment.fragment_id, entity])
		if strong < 2:
			thin.append("%s has %d" % [fragment.fragment_id, strong])
	_check(fragments.size() == 12 and lolo == 3 and thin.is_empty(),
		"twelve fragments, three with lolo in them, each saved by two or more strong classes",
		"%d fragments, %d with lolo" % [fragments.size(), lolo] if thin.is_empty() else "; ".join(thin))


## The flower's fragment is down a path nobody needed to walk: out of reach of the corridor.
func _audit_the_flower_is_off_the_path(scene: Node) -> void:
	var flower: MemoryFragment2D = null
	for node in scene.find_children("*", "MemoryFragment2D", true, false):
		if (node as MemoryFragment2D).fragment_id == "flower":
			flower = node
	var below := 0.0
	if flower != null:
		var ground_y := 60.0 if flower.global_position.x < 9200.0 else -20.0
		below = ground_y - flower.global_position.y
	_check(flower != null and below > flower.reach + 60.0,
		"the flower is off the path: out of reach from the corridor beneath it",
		"%.0f px above the path, reach %.0f" % [below, flower.reach if flower != null else 0.0])


# --- Helpers ----------------------------------------------------------------------------

func _open_level() -> Node:
	var scene := (load("res://level_5.tscn") as PackedScene).instantiate()
	(scene.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(scene)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(40):
		await physics_frame
	call_group(DialogueBox.GROUP, &"hide_line")
	paused = false
	for _frame in range(4):
		await physics_frame
	return scene


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


func _class_terms() -> Array[String]:
	var terms: Array[String] = []
	for entity_value: Variant in _load(ENTITIES_PATH).get("entities", []):
		var entity: Dictionary = entity_value
		terms.append(String(entity.get("id", "")).replace("_", " "))
		terms.append(String(entity.get("display_name", "")))
	return terms


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
