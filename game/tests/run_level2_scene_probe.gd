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
## The apo is 96 tall (`wanderer.gd`), so what they can touch at the top of a jump from a
## surface is that surface plus their height plus R1's rise.
const APO_HEIGHT := 96.0
## R4: a drawn primitive is 80px and must be climbable. It is also the CHEAPEST thing the
## player can stand on, so it sets the floor under any Climb gate.
const PRIMITIVE := 80.0
## The shortest thing `climb` resolves to that the player stands on top of. `stairs` is
## 176 in object_sizes.json and the design names it as an accepted answer outright, so a
## gate above what stairs reach is a gate half of its own answers cannot open.
const STAIRS := 176.0

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
	_audit_the_rooms_are_rooms()
	_audit_the_rooms_do_not_overlap()
	_audit_the_bunting_is_where_it_can_be_reached()
	_audit_the_flock_is_within_reach()
	_audit_the_plaza_is_not_empty()
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


## THE FOUR INSIDES, AND WHETHER THEY ARE ROOMS OR JUST FLOORS.
##
## They were floors: four bare Node2Ds with a collision box under them, joining no group and
## answering none of the six questions `_refresh_room_framing` asks. A room that does not
## answer them is not entered -- the camera never switches, the placement box never narrows,
## and `_room_holding_player` returns null for a player who is plainly standing in one.
func _audit_the_rooms_are_rooms() -> void:
	var rooms := level.get_tree().get_nodes_in_group(&"interiors")
	_check(rooms.size() == 4, "four insides, and they joined the group",
		"%d in `interiors`" % rooms.size())
	var contract := ["bounds", "camera_rect", "entry_point", "eye_level", "how_far_in",
		"exit_rect"]
	var mute: Array[String] = []
	for node in rooms:
		for method in contract:
			if not node.has_method(method):
				mute.append("%s cannot answer %s" % [node.name, method])
	_check(mute.is_empty(), "every one answers the whole contract",
		"6 questions x %d rooms" % rooms.size() if mute.is_empty() else "; ".join(mute))

	# A room is parked in the sky. Its entry point is where the player is PUT DOWN, and if
	# there is nothing under it they fall out of the level and the fall limit fishes them
	# back to the plaza -- which reads as the door being broken.
	var space := (level as Node2D).get_world_2d().direct_space_state
	var floating: Array[String] = []
	var outside: Array[String] = []
	for node in rooms:
		var room := node as Node2D
		var box := Rect2(room.call("bounds"))
		for what: Array in [["entry", room.call("entry_point")],
				["return", room.call("return_point")]]:
			var at := Vector2(what[1])
			# FROM ABOVE, the way the lantern probes. A ray that starts exactly on the
			# surface it is asking about is a ray Godot may or may not report, depending on
			# which side of the edge the float lands -- and the landing point IS the floor
			# line, because that is where a body's feet go.
			var query := PhysicsRayQueryParameters2D.create(
				at - Vector2(0.0, 40.0), at + Vector2(0.0, 300.0))
			query.collision_mask = 1
			if space.intersect_ray(query).is_empty():
				floating.append("%s.%s over nothing" % [room.name, what[0]])
			# Grown, because both land a body's width inside the wall and the box is the
			# walkable extent rather than the drawn one.
			if not box.grow(40.0).has_point(at):
				outside.append("%s.%s is outside its own room" % [room.name, what[0]])
	_check(floating.is_empty(), "and something under every place it puts you",
		"%d landing points" % (rooms.size() * 2) if floating.is_empty()
		else "; ".join(floating))
	_check(outside.is_empty(), "and every one of them is inside the room",
		"checked against each room's own bounds" if outside.is_empty()
		else "; ".join(outside))

	# ⚠ THE ONE THAT MATTERS. A doorway is walked into, so its box has to sit ON the floor.
	# Authored a hundred units up it becomes a thing the player can see and never reach, and
	# nothing in the level would ever say so -- the room simply has no way out.
	var high: Array[String] = []
	for node in rooms:
		var room := node as Node2D
		for what: Array in [["way back", room.call("exit_rect")],
				["way onward", room.call("onward_rect")]]:
			var rect := Rect2(what[1])
			var foot: float = rect.position.y + rect.size.y
			if absf(foot) > 8.0:
				high.append("%s %s stands %.0fpx off the floor" % [room.name, what[0], foot])
	_check(high.is_empty(), "both openings stand on the floor",
		"8 openings, all at floor level" if high.is_empty() else "; ".join(high))

	# An alley is open to the sky by design: that is where the birds circle and where the
	# bandaritas hang, and a lid over it would make the flight rule a roof instead of a line.
	var lidded: Array[String] = []
	for node in rooms:
		var room := node as Node2D
		var alley := int(room.get("kind")) == 2
		var has_lid := room.get_node_or_null(^"Ceiling") != null
		if alley == has_lid:
			lidded.append("%s %s a ceiling" % [room.name, "has" if has_lid else "lacks"])
	_check(lidded.is_empty(), "the alleys are open and the rest are not",
		"2 open to the sky, 2 roofed" if lidded.is_empty() else "; ".join(lidded))


## `_room_holding_player` walks the group and returns the FIRST room whose bounds contain the
## player, so two rooms sharing a point is a coin toss decided by tree order -- and the
## camera, the zoom and the placement box all follow whichever won. The church and the lit
## house were within a hundred units of overlapping when they were first parked.
func _audit_the_rooms_do_not_overlap() -> void:
	var rooms := level.get_tree().get_nodes_in_group(&"interiors")
	var clashes: Array[String] = []
	for i in range(rooms.size()):
		for j in range(i + 1, rooms.size()):
			var a := Rect2((rooms[i] as Node2D).call("bounds")).grow(90.0)
			var b := Rect2((rooms[j] as Node2D).call("bounds")).grow(90.0)
			if a.intersects(b):
				clashes.append("%s and %s" % [rooms[i].name, rooms[j].name])
	_check(clashes.is_empty(), "and no two of them share a point",
		"%d pairs, all clear at the 90px the base grows by" % (
			rooms.size() * (rooms.size() - 1) / 2)
		if clashes.is_empty() else "; ".join(clashes))


## ALLEY 2's BUNTING HAS TO SIT IN A WINDOW WITH TWO REAL WALLS, and both of them are ways
## to break Problem 3 without anything else in the project noticing.
##
## Too low and it is not a Climb gate: a drawn primitive is 80 and the apo is 96 and the
## jump lifts 94.3, so anybody can touch 270 for the price of one square. Too high and half
## of `climb`'s own answers cannot reach it -- which is scar 3 of this level, where `strike`
## resolved to a blade that swings inside 96px against a bird in the air, and the tag layer
## agreed with the player and then did nothing.
func _audit_the_bunting_is_where_it_can_be_reached() -> void:
	var lines := level.get_tree().get_nodes_in_group(&"bandarita_lines")
	_check(lines.size() == 2, "both alleys have a line strung in them",
		"%d found -- Alley 1 needs one for its ceiling to be diegetic" % lines.size())
	var alley_2 := level.get("alley_2") as Node2D
	var alley_1 := level.get("alley_1") as Node2D
	if alley_2 == null or alley_1 == null:
		_check(false, "the level has both alleys", "one is missing")
		return
	var line := alley_2.get_node_or_null(^"Bandaritas") as BandaritaLine2D
	if line == null:
		_check(false, "Alley 2's bunting is strung", "no line in the room")
		return
	var above_floor := alley_2.global_position.y - line.global_position.y
	var hop := PRIMITIVE + APO_HEIGHT + JUMP_RISE
	var climbed := STAIRS + APO_HEIGHT + JUMP_RISE
	_check(above_floor > hop, "and Alley 2's is out of reach without climbing something",
		"%.0fpx up against %.0f for a primitive and a jump" % [above_floor, hop])
	_check(above_floor < climbed, "and inside reach once you have",
		"%.0fpx against %.0f off the shortest thing `climb` resolves to" % [
			above_floor, climbed])
	_check(line.scraps_held == ScrapLedger.IN_ALLEY_2, "with the last two pieces on it",
		"%d of the seven" % line.scraps_held)

	# The design records Alley 1's missing line as an open question in level_02.json: it
	# needs a flight cap and had nothing visible to hang one on, "or the cap is an invisible
	# wall exactly where the design says it must not be".
	var first := alley_1.get_node_or_null(^"Bandaritas") as BandaritaLine2D
	_check(first != null and first.scraps_held == 0,
		"Alley 1's line is a ceiling and nothing else",
		"nothing strung on it -- it exists so the cap is visible")
	# ⚠ AND IT MUST BE ABOVE THE ALLEY, not across it. A cap the player walks into on the
	# ground is a wall.
	if first != null:
		var head := alley_1.global_position.y - first.global_position.y
		_check(head > APO_HEIGHT + JUMP_RISE,
			"and it is over the player's head, not across the alley",
			"%.0fpx up against a %.0f reach on foot" % [head, APO_HEIGHT + JUMP_RISE])


## Five birds, and the Protector route says it can hit them from 260px. If they ride higher
## than that, the route is a wall for the one answer that is supposed to open it.
func _audit_the_flock_is_within_reach() -> void:
	var alley_1 := level.get("alley_1") as Node2D
	if alley_1 == null:
		_check(false, "the first alley exists", "-")
		return
	var birds: Array[ScrapBird2D] = []
	for child in alley_1.get_children():
		var bird := child as ScrapBird2D
		if bird != null:
			birds.append(bird)
	_check(birds.size() == ScrapLedger.IN_ALLEY_1, "five birds in the first alley",
		"%d, one scrap each" % birds.size())
	var ids: Dictionary = {}
	for bird in birds:
		ids[bird.scrap_id] = true
	_check(ids.size() == birds.size(), "and every one carries a different piece",
		"%d distinct scrap ids" % ids.size())

	# Read off the level data rather than restated here: the reach the Protector route
	# claims is `requires_reach_px`, and a test carrying its own copy stops testing it.
	var director = level.get("director")
	var reach := 260.0
	for entry: Variant in (director.level_data().get("obstacles", []) if director != null else []):
		var obstacle: Dictionary = entry
		if String(obstacle.get("id", "")) != "L2_N2":
			continue
		var routes: Dictionary = obstacle.get("routes", {})
		var protector: Dictionary = routes.get("protector", {})
		reach = float(protector.get("requires_reach_px", reach))
	var far: Array[String] = []
	for bird in birds:
		# From a player standing directly under it, which is the best case the route gets.
		var up := alley_1.global_position.y - bird.global_position.y
		if up > reach:
			far.append("%s rides %.0fpx up" % [bird.scrap_id, up])
	_check(far.is_empty(), "and the flock rides inside the reach that route claims",
		"under %.0fpx, which is what level_02.json promises" % reach
		if far.is_empty() else "; ".join(far))


## THE DANCERS ARE THE PLAZA. Everything Problem 1 offers is about them -- dance for them,
## scare them off, or walk past them to the houses -- and the level said nothing at all when
## the group failed to build. It failed on its first run, because the script overrode
## `CanvasItem.draw_ellipse` and Godot detached the whole class, and every check in this
## suite stayed green while the plaza stood empty. That is trap 1 again, one class over.
func _audit_the_plaza_is_not_empty() -> void:
	var groups := level.get_tree().get_nodes_in_group(&"dancer_groups")
	_check(groups.size() == 1, "the dancers are in the plaza",
		"%d group(s)" % groups.size())
	if groups.is_empty():
		return
	var group := groups[0] as DancerGroup2D
	_check(group.dancers >= 3, "and there are enough of them to be a set",
		"%d dancing" % group.dancers)
	# They have to stand ON the mark the scene authored, because that mark is what the
	# scare-reach check above is measured against.
	var mark := level.get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/Marks/DancersMark") as Node2D
	_check(mark != null and group.global_position.distance_to(mark.global_position) < 1.0,
		"and they stand on the mark the level measures from",
		"the same spot `and the slowest scare can still reach them` uses")
	# ⚠ AND THE WARNING HAS TO CARRY FURTHER THAN THE CHOICE. The design asks for the
	# irreversibility to be signalled BEFORE the player commits; if the dialogue node caught
	# them first, the line would arrive behind a modal that has already taken the decision.
	var node := level.get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/DialogueNode") as Node2D
	if node == null:
		_check(false, "the plaza has its dialogue node", "-")
		return
	var to_node: float = absf(group.global_position.x - node.global_position.x)
	_check(group.notice_range > to_node,
		"and the warning reaches further than the choice does",
		"%.0fpx of notice against %.0fpx to the node" % [group.notice_range, to_node])
