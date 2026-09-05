extends SceneTree
## HOW FAR DOES A MORPH ACTUALLY GET BEFORE ITS TEN SECONDS RUN OUT?
##
## LEVEL_TEMPLATE.md's build order puts this second, ahead of every number in a level
## design: "measure the new mechanic before costing anything out". Level 2 introduces no new
## tag movement -- it introduces new REQUIREMENTS on movement the engine already has, and
## `startle` is the one that has to cross ground to work. A scare gate the player cannot
## reach inside MorphLife's budget is a wall, and it looks exactly like a puzzle in a green
## report.
##
## What this prints is the reach budget for the plaza: how far east a morph gets, how high it
## can climb, and whether it moves at all. Every distance in level_02.json is measured against
## these numbers rather than chosen.
##
##   godot --headless --path game --script res://tests/run_morph_reach_probe.gd

const RosterFixtures = preload("res://tests/roster_fixtures.gd")
const MorphLifeClass = preload("res://scripts/morph_life.gd")

## The classes Level 2 asks to cross ground: `startle` answers both the plaza scare
## (Problem 1 Protector) and the alley chase (Problem 2 Pragmatist). `climb` is what
## Problem 3's Artist route asks for, so its creature members are measured too.
const STARTLE := ["snake", "monkey", "shark", "frog"]
const CLIMBERS := ["bat", "monkey", "crab"]

var world: Node2D
var registry: EntityRegistry
var rows: Array = []
var notes: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	world = Node2D.new()
	root.add_child(world)
	_add_floor()
	registry = EntityRegistry.new()
	world.add_child(registry)
	registry.load_manifest()

	# Read the budget rather than assuming ten: it is exported on the node because it is
	# balance, and a probe that hardcodes it stops being true the moment somebody tunes it.
	var life := MorphLifeClass.new()
	var budget: float = life.seconds
	var warn: float = life.warning_ratio
	life.free()
	# The usable window is what is left once the player has to be somewhere survivable.
	var usable := budget * (1.0 - warn)

	print("\n===== MORPH REACH (MorphLife = %.1fs, usable %.1fs before the warning) =====" % [budget, usable])
	print("%-10s %-8s %9s %9s %9s %9s  %s" % [
		"class", "rig", "x@usable", "x@full", "climb", "peak_v", "verdict"])
	print("-".repeat(78))
	for entity_id in STARTLE:
		await _measure(entity_id, budget, usable, "startle")
	print("-".repeat(78))
	for entity_id in CLIMBERS:
		await _measure(entity_id, budget, usable, "climb")
	print("-".repeat(78))
	for row in rows:
		print(row)
	print("")
	for note in notes:
		print("NOTE: %s" % note)
	print("\nOBRA_MORPH_REACH_OK")
	quit(0)


func _measure(entity_id: String, budget: float, usable: float, _tag: String) -> void:
	var entry := registry.get_entity(entity_id)
	var rig_type := String(entry.get("rig_type", "none"))
	var instance := registry.instantiate_entity(entity_id) as Node2D
	if instance == null:
		print("%-10s %-8s  could not be instantiated" % [entity_id, rig_type])
		return
	world.add_child(instance)
	instance.global_position = Vector2(420.0, 560.0)
	if instance.has_method("set_world_bounds"):
		instance.call("set_world_bounds", Rect2(0.0, -520.0, 3760.0, 1600.0))
	if instance.has_method("apply_drawing"):
		instance.call("apply_drawing", _blank_image(),
			RosterFixtures.for_rig(rig_type, entity_id))

	# Let it settle onto the floor before the clock starts, or the drop counts as travel.
	for _settle in range(30):
		await physics_frame
	var start := _anchor_of(instance)

	var frames_usable := int(usable * 60.0)
	var frames_full := int(budget * 60.0)
	var x_at_usable := 0.0
	var climb := 0.0
	var peak_speed := 0.0
	Input.action_press(&"move_right")
	for frame in range(frames_full):
		# Held, not tapped: hoppers and fliers both read `jump` as "keep going up", and a
		# probe that never presses it measures a creature refusing to use half of itself.
		if frame % 20 == 0:
			Input.action_press(&"jump")
		elif frame % 20 == 4:
			Input.action_release(&"jump")
		await physics_frame
		var here := _anchor_of(instance)
		climb = maxf(climb, start.y - here.y)
		if instance.has_method("get_physics_anchor"):
			var body := instance.call("get_physics_anchor") as RigidBody2D
			if body != null:
				peak_speed = maxf(peak_speed, body.linear_velocity.length())
		if frame == frames_usable:
			x_at_usable = here.x - start.x
	Input.action_release(&"move_right")
	Input.action_release(&"jump")

	var x_full := _anchor_of(instance).x - start.x
	var verdict := "ok"
	if absf(x_full) < 40.0:
		verdict = "DOES NOT TRAVEL"
		notes.append("%s covers %.0fpx in %.0fs -- it cannot answer a gate it must reach"
			% [entity_id, x_full, budget])
	elif x_at_usable < 200.0:
		verdict = "short"
		notes.append("%s reaches only %.0fpx before the low-life warning" % [entity_id, x_at_usable])
	rows.append("%-10s %-8s %9.0f %9.0f %9.0f %9.0f  %s" % [
		entity_id, rig_type, x_at_usable, x_full, climb, peak_speed, verdict])
	instance.queue_free()
	await process_frame


func _anchor_of(instance: Node2D) -> Vector2:
	if instance.has_method("get_physics_anchor"):
		var anchor := instance.call("get_physics_anchor") as Node2D
		if anchor != null:
			return anchor.global_position
	return instance.global_position


func _blank_image() -> Image:
	return Image.create(8, 8, false, Image.FORMAT_RGBA8)


func _add_floor() -> void:
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8000.0, 80.0)
	shape.shape = rectangle
	floor_body.add_child(shape)
	floor_body.position = Vector2(2000.0, 700.0)
	world.add_child(floor_body)
