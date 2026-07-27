extends SceneTree
## Every entity in the manifest, built and driven, reported as one table:
##   godot --headless --path game --script res://tests/run_roster_sweep.gd
##
## The regression suite asserts these properties on the 20 animated classes. This
## sweeps all 50, including the utilities and physics morphs, and prints the numbers
## rather than only a pass/fail -- so a class that is merely CLOSE to a bound is
## visible before it crosses one.

const RosterFixtures = preload("res://tests/roster_fixtures.gd")

const REST_TOLERANCE := 0.01
const STRETCH_BOUND := 1.40
const MIN_TRAVEL := 2.0

var world: Node2D
var registry: EntityRegistry
var problems: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	world = Node2D.new()
	root.add_child(world)
	_add_floor()
	registry = EntityRegistry.new()
	world.add_child(registry)
	registry.load_manifest()

	print("%-14s %-8s %-6s %8s %8s %8s %6s" % [
		"entity", "rig", "role", "rest_px", "travel", "stretch", "lines"
	])
	print("-".repeat(70))
	for entity_id in registry.get_entity_ids():
		await _sweep(entity_id)

	# Drawings that do not match their skeleton's limb count. A class-driven skeleton
	# always has every bone its archetype defines, whether or not the player drew that
	# part, so these are the cases where bones compete for ink that was never theirs.
	print("-".repeat(70))
	await _sweep("monkey", RosterFixtures.biped_legs_only(), "monkey/no-arms")
	await _sweep("penguin", RosterFixtures.biped_legs_only(), "penguin/no-arms")
	await _sweep("horse", RosterFixtures.legged(2, 240.0), "horse/2-legs")

	print("-".repeat(70))
	if problems.is_empty():
		print("OBRA_ROSTER_SWEEP_OK (%d entities)" % registry.get_entity_ids().size())
		quit(0)
	else:
		for problem in problems:
			print("PROBLEM: %s" % problem)
		print("OBRA_ROSTER_SWEEP_FAILED=%d" % problems.size())
		quit(1)


func _sweep(entity_id: String, fixture: Array = [], label: String = "") -> void:
	var shown_as := label if not label.is_empty() else entity_id
	var entry := registry.get_entity(entity_id)
	var rig_type := String(entry.get("rig_type", "none"))
	var role := String(entry.get("runtime_role", ""))
	var instance := registry.instantiate_entity(entity_id) as Node2D
	if instance == null:
		problems.append("%s could not be instantiated" % shown_as)
		return
	world.add_child(instance)
	instance.global_position = Vector2(420.0, 240.0)
	if instance.has_method("set_world_bounds"):
		instance.call("set_world_bounds", Rect2(0.0, -520.0, 3760.0, 1200.0))
	if not instance.has_method("apply_drawing"):
		print("%-14s %-8s %-6s %8s %8s %8s %6s" % [shown_as, rig_type, _short(role), "-", "-", "-", "-"])
		instance.queue_free()
		await process_frame
		return

	var strokes: Array = fixture if not fixture.is_empty() else RosterFixtures.for_rig(rig_type, entity_id)
	instance.call("apply_drawing", _blank_image(), strokes)
	var skin := instance.get_node_or_null("DrawingSkin") as RuntimeRig2D
	if skin == null or not skin.debug_skin_active():
		# Not a failure by itself: a bitmap fallback has no strokes to skin. It IS a
		# failure for anything the game animates.
		if role == "active_ragdoll_morph":
			problems.append("%s (%s) is not skinned to its class skeleton" % [shown_as, rig_type])
		print("%-14s %-8s %-6s %8s %8s %8s %6s" % [shown_as, rig_type, _short(role), "-", "-", "-", "-"])
		instance.queue_free()
		await process_frame
		return

	# Frame zero must be the drawing, in world space.
	var drawn := skin.get_vector_strokes()
	var to_world := skin.debug_skin_transform()
	var drawn_to_world := instance.global_transform
	var rest_error := 0.0
	var rendered := skin.debug_skin_points()
	for index in range(mini(rendered.size(), drawn.size())):
		var source: PackedVector2Array = (drawn[index] as Dictionary)["points"]
		var shown: PackedVector2Array = rendered[index]
		for p in range(mini(source.size(), shown.size())):
			rest_error = maxf(rest_error, (to_world * shown[p]).distance_to(drawn_to_world * source[p]))

	var lines := _count_lines(instance)
	var expected_lines := rendered.size() * 2

	# Then drive it and watch the ink.
	instance.set_physics_process(false)
	var state := RosterFixtures.gait_for(rig_type)
	var motion := {"moving": true, "speed_ratio": 1.0, "direction": 1.0, "charge_ratio": 1.0}
	var rest_lengths: Array[float] = []
	for stroke_value in drawn:
		rest_lengths.append(_length((stroke_value as Dictionary)["points"]))
	var first := skin.debug_skin_points()
	var travel := 0.0
	var stretch := 1.0
	for _frame in range(150):
		skin.set_motion_state(state, motion)
		await physics_frame
		var now := skin.debug_skin_points()
		for s in range(mini(first.size(), now.size())):
			var before: PackedVector2Array = first[s]
			var after: PackedVector2Array = now[s]
			for p in range(mini(before.size(), after.size())):
				travel = maxf(travel, before[p].distance_to(after[p]))
			if s < rest_lengths.size() and rest_lengths[s] > 0.001:
				stretch = maxf(stretch, _length(after) / rest_lengths[s])

	print("%-14s %-8s %-6s %8.4f %8.1f %7.0f%% %6d" % [
		shown_as, rig_type, _short(role), rest_error, travel, stretch * 100.0, lines
	])
	if rest_error > REST_TOLERANCE:
		problems.append("%s renders %.4f px off its drawing at rest" % [shown_as, rest_error])
	if lines != expected_lines:
		problems.append("%s renders %d ink lines, expected %d" % [shown_as, lines, expected_lines])
	if stretch > STRETCH_BOUND:
		problems.append("%s ink stretched to %.0f%%" % [shown_as, stretch * 100.0])
	if role == "active_ragdoll_morph" and travel < MIN_TRAVEL:
		problems.append("%s renders frozen (%.2f px of ink travel)" % [shown_as, travel])
	instance.queue_free()
	await process_frame


func _short(role: String) -> String:
	match role:
		"active_ragdoll_morph":
			return "live"
		"physics_morph":
			return "phys"
		"utility":
			return "util"
	return role


func _count_lines(node: Node) -> int:
	var total := 0
	for child in node.get_children():
		if child is Line2D:
			total += 1
		total += _count_lines(child)
	return total


func _length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total


func _blank_image() -> Image:
	return Image.create(8, 8, false, Image.FORMAT_RGBA8)


func _add_floor() -> void:
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(4000.0, 80.0)
	shape.shape = rectangle
	floor_body.add_child(shape)
	floor_body.position = Vector2(1000.0, 700.0)
	world.add_child(floor_body)
