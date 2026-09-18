extends SceneTree
## HOW FAR DOES A MORPH GET ON ONE UNIT OF INK, UNDERWATER?
##
## The sibling of run_morph_reach_probe.gd, and LEVEL_TEMPLATE.md's build order step 2 for
## Dagat: "measure the new mechanic before costing anything out". Dagat introduces two at once
## -- swimming as a movement mode, and ink that drains by the second instead of a clock that
## expires -- so every crossing distance, drain rate and refill count in level_03.json is
## measured against what this prints rather than chosen.
##
## ⚠ R10 DOES NOT SURVIVE THIS LEVEL UNCHANGED. The template's rule is "a gate that must be
## REACHED is measured against its slowest answer", and its numbers are px per MorphLife
## SECOND. Dagat has no MorphLife, so reach here is px per unit of INK. The two are only the
## same number if the drain rate happens to be one unit per ten seconds, and it is not: the
## whole point of a per-class rate is that a shark costs more to hold than a fish, so the
## slowest answer and the most expensive answer are no longer the same class. The last column
## is the one a gate is placed against.
##
## Both of the harness traps documented in run_water_audit.gd apply and are repeated here,
## because getting either wrong produces confident numbers that mean nothing:
##
##   1. Everything lives inside the world bounds. A body that falls past them is teleported
##      back to the top of the world, which reads as travel.
##   2. A rig's bodies are top_level, so writing the morph node's global_position moves the
##      node and leaves the physics at the origin. Morphs are placed through apply_morph_state.
##
##   godot --headless --path game --script res://tests/run_swim_reach_probe.gd

const RosterFixtures = preload("res://tests/roster_fixtures.gd")
const InkManagerClass = preload("res://scripts/ink_manager.gd")
const InkDrainClass = preload("res://scripts/ink_drain.gd")

## The seven the design names for the dive, in the order it names them. All seven are in the
## roster and none needs retraining.
const SWIMMERS := ["fish", "octopus", "shark", "sea_turtle", "crab", "penguin", "frog"]

## A big pool, because the thing being measured is how far something gets across open water.
## Surface at 150, bed at 1160: a thousand pixels of column, wider than any crossing Dagat
## will ask for, so nothing here is measuring a wall.
const SURFACE_Y := 150.0
const POOL_WIDTH := 6000.0
const POOL_HEIGHT := 1000.0
const BED_TOP := 1180.0
const BOUNDS := Rect2(-200.0, -520.0, 7000.0, 2200.0)

## Seconds of held input per reading. Long enough that the acceleration ramp is a small part
## of the distance, short enough that the run finishes.
const RUN_SECONDS := 6.0
const SETTLE_FRAMES := 40

var world: Node2D
var registry: EntityRegistry
var rows: Array = []
var notes: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	world = Node2D.new()
	root.add_child(world)
	registry = EntityRegistry.new()
	world.add_child(registry)
	registry.load_manifest()
	_bed()
	_pool()

	# Read the rate off a fresh InkDrain rather than hardcoding it, the same reason the morph
	# reach probe reads MorphLife.seconds: it is balance, and a probe that copies it stops
	# being true the moment somebody tunes it.
	var drain := InkDrainClass.new()
	var rate: float = drain.default_rate
	var warn: float = drain.warning_ratio
	drain.free()
	var budget: float = InkManagerClass.BUDGET
	# What is left once the player has to still be somewhere survivable, which is the same
	# reading the morph probe's "usable" column takes.
	var usable := budget * (1.0 - warn)

	print("\n===== SWIM REACH =====")
	print("ink budget %.0f units, default drain %.2f units/s, warning at %.0f%% (%.1f usable units)"
		% [budget, rate, warn * 100.0, usable])
	print("a held direction for %.0fs, in open water %.0fpx deep\n" % [RUN_SECONDS, POOL_HEIGHT])
	print("%-11s %-8s %8s %8s %8s %8s %10s  %s" % [
		"class", "rig", "px/s", "x@run", "rise", "dive", "px/ink", "verdict"])
	print("-".repeat(88))
	for entity_id in SWIMMERS:
		await _measure(entity_id, rate, usable)
	for row in rows:
		print(row)
	print("")
	print("* the pool ended the reading, not the creature: it reached the surface or the bed")
	print("")
	for note in notes:
		print("NOTE: %s" % note)
	print("\nOBRA_SWIM_REACH_OK")
	quit(0)


func _measure(entity_id: String, rate: float, usable_units: float) -> void:
	var entry := registry.get_entity(entity_id)
	var rig_type := String(entry.get("rig_type", "none"))
	var instance := registry.instantiate_entity(entity_id) as Node2D
	if instance == null:
		rows.append("%-11s %-8s  could not be instantiated" % [entity_id, rig_type])
		return
	world.add_child(instance)
	if instance.has_method("set_world_bounds"):
		instance.call("set_world_bounds", BOUNDS)
	instance.call("apply_drawing", _blank(), RosterFixtures.for_rig(rig_type, entity_id))
	# Mid-column, so neither the surface nor the bed is in the way of the first reading.
	instance.call("apply_morph_state", {"position": Vector2(600.0, SURFACE_Y + POOL_HEIGHT * 0.5)})
	await _settle(SETTLE_FRAMES)

	var anchor := instance.call("get_physics_anchor") as Node2D
	if anchor == null:
		rows.append("%-11s %-8s  rig built without an anchor" % [entity_id, rig_type])
		instance.queue_free()
		await process_frame
		return
	if not bool(instance.call("is_in_water")):
		# The one failure that invalidates every number below it, so it is reported as a
		# failure rather than as a small distance.
		rows.append("%-11s %-8s  NEVER REGISTERED AS BEING IN THE WATER" % [entity_id, rig_type])
		notes.append("%s never entered the pool -- its reading would be a land reading" % entity_id)
		instance.queue_free()
		await process_frame
		return

	var frames := int(RUN_SECONDS * 60.0)
	var across := await _hold(instance, anchor, &"move_right", frames)
	instance.call("apply_morph_state", {"position": Vector2(600.0, SURFACE_Y + POOL_HEIGHT * 0.5)})
	await _settle(SETTLE_FRAMES)
	var rise := -(await _hold(instance, anchor, &"move_up", frames, true))
	var rise_mark := "*" if _clamped else " "
	instance.call("apply_morph_state", {"position": Vector2(600.0, SURFACE_Y + POOL_HEIGHT * 0.4)})
	await _settle(SETTLE_FRAMES)
	var dive := await _hold(instance, anchor, &"move_down", frames, true)
	var dive_mark := "*" if _clamped else " "

	var speed := across / RUN_SECONDS
	# THE COLUMN A GATE IS PLACED AGAINST. Distance per unit of ink, not per second: a class
	# that swims fast and drains fast is not a long crossing.
	var per_ink := speed / maxf(0.0001, rate)
	var verdict := "ok"
	if absf(across) < 60.0:
		verdict = "DOES NOT TRAVEL"
		notes.append("%s covers %.0fpx in %.0fs of held input -- it cannot answer a crossing"
			% [entity_id, across, RUN_SECONDS])
	elif rise < 40.0:
		verdict = "cannot rise"
		notes.append("%s only climbs %.0fpx -- it cannot get back to the surface, and the "
			% [entity_id, rise] + "ink-zero case says the apo is carried up")
	rows.append("%-11s %-8s %8.0f %8.0f %7.0f%s %7.0f%s %10.0f  %s" % [
		entity_id, rig_type, speed, across, rise, rise_mark, dive, dive_mark, per_ink, verdict])
	notes.append("%s at the usable budget: about %.0fpx of crossing (%.1f units x %.0f px/ink)"
		% [entity_id, per_ink * usable_units, usable_units, per_ink])
	instance.queue_free()
	await process_frame


## Hold one direction and report the displacement along the axis it drives.
##
## ⚠ SETS _clamped WHEN THE POOL ENDED THE READING RATHER THAN THE CREATURE. A vertical run
## from mid-column reaches the surface well inside six seconds for every one of the seven, so
## the rise figure is "as far as there was water", not "as far as it could climb". Printed
## with a * so nobody reads it as an ability. The useful fact it does carry is boolean: every
## class can get back up, which is what the ink-zero case depends on.
var _clamped := false

func _hold(instance: Node2D, anchor: Node2D, action: StringName, frames: int,
		vertical := false) -> float:
	var start := anchor.global_position
	_clamped = false
	Input.action_press(action)
	for _frame in range(frames):
		await physics_frame
		var here := anchor.global_position
		if here.y > BED_TOP - 40.0 or here.y < SURFACE_Y + 20.0:
			_clamped = true
			break
	Input.action_release(action)
	var moved := anchor.global_position - start
	return moved.y if vertical else moved.x


func _settle(frames: int) -> void:
	for _frame in range(frames):
		await physics_frame


func _blank() -> Image:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return image


func _bed() -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(POOL_WIDTH + 800.0, 120.0)
	shape.shape = rectangle
	body.add_child(shape)
	body.position = Vector2(POOL_WIDTH * 0.5, BED_TOP + 60.0)
	world.add_child(body)


func _pool() -> void:
	var water := WaterArea2D.new()
	# ⚠ BEFORE add_child. WaterArea2D sizes its collision shape in _ready, so a surface_size
	# written afterwards leaves a pool the size of the default and a probe measuring a body
	# that is mostly outside it. run_water_audit.gd documents the same trap.
	water.surface_size = Vector2(POOL_WIDTH, POOL_HEIGHT)
	water.position = Vector2(POOL_WIDTH * 0.5, SURFACE_Y + POOL_HEIGHT * 0.5)
	world.add_child(water)
