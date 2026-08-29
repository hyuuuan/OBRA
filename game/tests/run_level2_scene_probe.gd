extends SceneTree
## Piyesta's geometry, measured off the built scene rather than off the design doc.
##   godot --headless --path game --script res://tests/run_level2_scene_probe.gd
##
## Every number in level_02.json is derived from a constant -- the jump, the tallest thing
## the player can place, how far a morph gets in ten seconds -- and none of that means
## anything until a scene exists to measure. This is where the derivation is checked against
## the thing that was actually built.

const WandererClass = preload("res://scripts/wanderer.gd")
const UtilityObjectClass = preload("res://scripts/utility_object.gd")

## R1: the jump lifts 94.3px (JUMP_VELOCITY -430 against gravity 980). Read here rather
## than copied, so retuning the jump re-measures the level instead of silently invalidating
## it.
const JUMP_RISE := 94.3
## R10, measured by run_morph_reach_probe: the slowest class `startle` resolves to is a
## snake at 428px inside the usable window. A scare gate beyond that is a wall for a
## quarter of its own answers.
const SLOWEST_STARTLE_REACH := 428.0
## R7: a gate must have floor to build on.
const MIN_BUILD_FLOOR := 180.0

var results: Array[String] = []
var failures := 0
var level: Node


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	results.append("  %s  %-36s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _run() -> void:
	var packed := load("res://level_2.tscn") as PackedScene
	if packed == null:
		print("  FAIL  level_2.tscn does not load")
		print("OBRA_LEVEL2_SCENE_FAILED=1")
		quit(1)
		return
	level = packed.instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(30):
		await physics_frame

	print("\n===== LEVEL 2 SCENE =====")
	_audit_it_is_level_2()
	_audit_the_machine_found_its_parts()
	_audit_restrictions_are_live()
	_audit_the_stair_is_walkable()
	_audit_the_plaza_is_buildable()
	_audit_the_ceiling_bites()
	_audit_every_mark_stands_on_ground()
	await _audit_the_apo_stands_on_something()

	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_LEVEL2_SCENE_OK")
		quit(0)
	else:
		print("OBRA_LEVEL2_SCENE_FAILED=%d" % failures)
		quit(1)


func _audit_it_is_level_2() -> void:
	var director = level.get("director")
	_check(director != null and String(director.level_id()) == "level_2",
		"the director loaded level_02.json",
		String(director.level_id()) if director != null else "no director")
	_check(director != null and String(director.display_name()) == "Piyesta",
		"and it is Piyesta", String(director.display_name()) if director != null else "-")
	var script_lines = level.get("script_lines")
	_check(script_lines != null and String(script_lines.level_id()) == "level_2",
		"and dialogue_l2.json with it",
		String(script_lines.level_id()) if script_lines != null else "no dialogue")


## The base resolves these by path. A level whose scene renamed one of them comes up with a
## null it will not notice until the first frame that needs it.
func _audit_the_machine_found_its_parts() -> void:
	var missing: Array[String] = []
	for path in ["EnvironmentBaseplate/GameplayPlane/SpawnPoint",
			"EnvironmentBaseplate/GameplayPlane/EntityRoot",
			"EnvironmentBaseplate/GameplayPlane/WorldItemRoot",
			"EnvironmentBaseplate/GameplayPlane/GoalMarker",
			"CanvasLayer/InventoryHUD", "DrawPanel", "InkManager", "MorphLife",
			"PlacementController", "LevelCompleteOverlay", "DialogueChoiceOverlay"]:
		if level.get_node_or_null(NodePath(path)) == null:
			missing.append(path)
	_check(missing.is_empty(), "every generic node the base expects",
		"11 checked" if missing.is_empty() else "missing: %s" % ", ".join(missing))


func _audit_restrictions_are_live() -> void:
	var rules = level.get("restrictions")
	_check(rules != null and rules.is_armed(), "the restrictions came up armed",
		"%d banned, %d capped" % [rules.banned_classes().size(), rules.capped_classes().size()]
		if rules != null else "no restrictions node")
	var ledger = level.get("ledger")
	_check(ledger != null and ledger.total() == 7, "the ledger is holding seven",
		"%d of %d" % [ledger.held(), ledger.total()] if ledger != null else "no ledger")


## A 240px face with no stair is a Climb gate nobody wrote down. The way down to the plaza
## and back up must cost no ink, so every riser has to be inside the jump.
func _audit_the_stair_is_walkable() -> void:
	var terrain := level.get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/Terrain") as Node2D
	if terrain == null:
		_check(false, "the plaza has terrain", "no Terrain node")
		return
	var tops: Dictionary = {}
	for child in terrain.get_children():
		var body := child as StaticBody2D
		if body == null:
			continue
		var shape := body.get_node_or_null(^"Shape") as CollisionShape2D
		var rect := shape.shape as RectangleShape2D if shape != null else null
		if rect == null:
			continue
		tops[body.name] = body.global_position.y - rect.size.y * 0.5
	var steps := ["LeftTerrace", "StairA", "StairB", "PlazaFloor"]
	var risers: Array[String] = []
	var worst := 0.0
	for index in range(steps.size() - 1):
		if not (tops.has(steps[index]) and tops.has(steps[index + 1])):
			continue
		var rise: float = float(tops[steps[index + 1]]) - float(tops[steps[index]])
		worst = maxf(worst, rise)
		if rise > JUMP_RISE:
			risers.append("%s -> %s is %.0fpx" % [steps[index], steps[index + 1], rise])
	_check(risers.is_empty(), "every riser is inside the jump",
		"worst is %.0fpx against %.1fpx" % [worst, JUMP_RISE]
		if risers.is_empty() else "; ".join(risers))


## R7. The dancers are a scare gate and the player has to be able to stand in front of them
## and draw -- and by R10 they have to be able to REACH them with the slowest thing the tag
## resolves to.
func _audit_the_plaza_is_buildable() -> void:
	var marks := level.get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/Marks") as Node2D
	var start := marks.get_node_or_null(^"StartMark") as Node2D if marks != null else null
	var dancers := marks.get_node_or_null(^"DancersMark") as Node2D if marks != null else null
	if start == null or dancers == null:
		_check(false, "the plaza's beats are marked", "StartMark or DancersMark missing")
		return
	var run := absf(dancers.global_position.x - start.global_position.x)
	_check(run >= MIN_BUILD_FLOOR, "floor to build on before the dancers",
		"%.0fpx of plaza, R7 asks for %.0f" % [run, MIN_BUILD_FLOOR])
	# ⚠ THE ONE THAT MATTERS. A scare gate placed on the frog's budget is a wall for the
	# snake, and the tag layer never tells the player which they drew.
	_check(run <= SLOWEST_STARTLE_REACH,
		"and the slowest scare can still reach them",
		"%.0fpx against a snake's %.0fpx in the usable window" % [run, SLOWEST_STARTLE_REACH])


func _audit_the_ceiling_bites() -> void:
	var rules = level.get("restrictions")
	var marks := level.get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/Marks") as Node2D
	var line := marks.get_node_or_null(^"BuntingLine") as Node2D if marks != null else null
	if rules == null or line == null:
		_check(false, "the plaza has a bandarita line", "no marker or no restrictions")
		return
	var ceiling: float = rules.ceiling()
	_check(ceiling != -INF, "the ceiling was taken from the art",
		"y %.0f, just under the line at y %.0f" % [ceiling, line.global_position.y])
	# The boundary is the strings, so it has to sit at them -- not at a number somebody
	# picked that happens to be nearby.
	_check(absf(ceiling - line.global_position.y) <= 40.0,
		"and it sits AT the line", "%.0fpx apart" % absf(ceiling - line.global_position.y))
	var floor_y := 560.0
	_check(rules.crossed("bird", ceiling - 60.0), "a flier over it is a crossing", "60px over")
	_check(not rules.crossed("bird", floor_y - 40.0), "and one under it is not", "on the plaza")
	# R9: a boundary a placement can already beat is not a flight boundary.
	var reach: float = floor_y - ceiling
	_check(reach > 0.0, "the line is above the plaza", "%.0fpx up" % reach)


## The scene has to hold the player up. A spawn point over nothing is a level that begins
## by falling, and the fall limit is the only thing that would ever say so.
## Every commit mark is planted by a ray cast down onto the first thing it meets. A mark
## floating over nothing warns and then stands where it was authored, which is invisible in
## a green suite -- this probe was green while the scene warned twice.
func _audit_every_mark_stands_on_ground() -> void:
	var space := (level as Node2D).get_world_2d().direct_space_state
	var floating: Array[String] = []
	var marks: Array[Node] = []
	# WALKED, not asked of a group. The lanterns join none -- they are held in the level's
	# own _commit_marks and parented to the volume they belong to -- so a group query
	# returns an empty list and passes, which is what this check did on its first run.
	_collect(level, marks)
	var planted := marks.size()
	for node in marks:
		var mark := node as Node2D
		var from := mark.global_position + Vector2(0.0, -8.0)
		var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 400.0))
		query.collision_mask = 1
		if space.intersect_ray(query).is_empty():
			floating.append("%s at %s" % [mark.name, mark.global_position])
	# A vacuous pass is the failure mode this check is most likely to have, so the count
	# is asserted rather than merely printed.
	_check(planted > 0, "the level plants commit marks at all",
		"%d found by walking the tree" % planted)
	_check(floating.is_empty(), "and every one stands on ground",
		"%d planted" % planted if floating.is_empty() else "; ".join(floating))


func _collect(node: Node, into: Array[Node]) -> void:
	if node is CheckpointLantern2D:
		into.append(node)
	for child in node.get_children():
		_collect(child, into)


func _audit_the_apo_stands_on_something() -> void:
	var spawn := level.get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/SpawnPoint") as Node2D
	var player = level.get("player")
	if spawn == null or player == null:
		_check(false, "the apo spawned", "no spawn point or no player")
		return
	var started := (player as Node2D).global_position
	for _frame in range(90):
		await physics_frame
	var now := (player as Node2D).global_position
	var fell := now.y - started.y
	_check(fell < 300.0, "the apo lands on the terrace rather than falling",
		"settled %.0fpx below the spawn" % fell)
	_check(now.y < 900.0, "and is not under the world", "y %.0f" % now.y)
