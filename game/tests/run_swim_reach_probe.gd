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
const LEVEL_PATH := "res://config/level_03.json"

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
var failures := 0
var _economy: Dictionary = {}


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

	# ⚠ THE LEVEL'S OWN NUMBERS, NOT InkDrain's DEFAULTS. Once the rates are per class, a
	# probe reading the default measures a level nobody plays -- and the whole point of the
	# tuning pass is that the seven no longer share a rate.
	_economy = _load(LEVEL_PATH).get("ink_economy", {})
	var drain := InkDrainClass.new()
	var default_rate := float(_economy.get("default_rate_per_second", drain.default_rate))
	var warn := float(_economy.get("warning_ratio", drain.warning_ratio))
	drain.free()
	var budget: float = InkManagerClass.BUDGET
	# What is left once the player has to still be somewhere survivable, which is the same
	# reading the morph probe's "usable" column takes.
	var usable := budget * (1.0 - warn)
	var longest := _longest_unrefilled()
	var refill := float(_economy.get("refill_units", 1.5))

	print("\n===== SWIM REACH =====")
	print("ink budget %.0f units, warning at %.0f%% (%.1f usable), default rate %.2f/s"
		% [budget, warn * 100.0, usable, default_rate])
	print("crossing %.0f..%.0fpx with %d refill(s) of %.1f -- longest unrefilled stretch %.0fpx"
		% [float(_economy.get("crossing_from_px", 0)), float(_economy.get("crossing_to_px", 0)),
			(_economy.get("refill_spots", []) as Array).size(), refill, longest])
	print("a held direction for %.0fs, in open water %.0fpx deep\n" % [RUN_SECONDS, POOL_HEIGHT])
	print("%-11s %7s %6s %7s %8s %8s %7s  %s" % [
		"class", "px/s", "rate", "px/ink", "reach", "stretch", "hold", "verdict"])
	print("-".repeat(82))
	for entity_id in SWIMMERS:
		await _measure(entity_id, default_rate, usable, longest)
	for row in rows:
		print(row)
	print("")
	print("reach   = px on the usable budget      stretch = units to cross the longest %.0fpx"
		% longest)
	print("hold    = seconds a form lasts on the usable budget plus the %.1f units in the arena"
		% _arena_refill_units())
	print("          the encounter's budget is %ds -- a full sweep is %.1fs and has to be waited out"
		% [int(_economy.get("encounter_seconds", 0)), 4.0 * 1.05 / 0.55])
	print("")
	for note in notes:
		print("NOTE: %s" % note)
	if failures > 0:
		print("\nOBRA_SWIM_REACH_FAILED=%d" % failures)
		quit(1)
		return
	print("\nOBRA_SWIM_REACH_OK")
	quit(0)


func _load(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


## What is available to spend INSIDE the encounter, which is the part charged by the second.
func _arena_refill_units() -> float:
	var from_x := float(_economy.get("arena_from_px", INF))
	var each := float(_economy.get("refill_units", 1.5))
	var total := 0.0
	for pair: Variant in _economy.get("refill_spots", []):
		if float((pair as Array)[0]) >= from_x:
			total += each
	return total


## The widest gap a player can be asked to cover on one tank: entry to the first refill, each
## refill to the next, and the last refill to the far side.
func _longest_unrefilled() -> float:
	var marks: Array[float] = [float(_economy.get("crossing_from_px", 0.0))]
	for pair: Variant in _economy.get("refill_spots", []):
		marks.append(float((pair as Array)[0]))
	marks.append(float(_economy.get("crossing_to_px", 0.0)))
	var widest := 0.0
	for index in range(marks.size() - 1):
		widest = maxf(widest, marks[index + 1] - marks[index])
	return widest


func _measure(entity_id: String, default_rate: float, usable_units: float,
		longest: float) -> void:
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
	var rates: Dictionary = _economy.get("rates", {})
	var rate := float(rates.get(entity_id, default_rate))
	# THE COLUMN A GATE IS PLACED AGAINST. Distance per unit of ink, not per second: a class
	# that swims fast and drains fast is not a long crossing. R10a.
	var per_ink := speed / maxf(0.0001, rate)
	var reach := per_ink * usable_units
	var stretch_cost := longest / maxf(1.0, per_ink)

	var verdict := "ok"
	if absf(across) < 60.0:
		verdict = "DOES NOT TRAVEL"
		failures += 1
		notes.append("%s covers %.0fpx in %.0fs of held input -- it cannot answer a crossing"
			% [entity_id, across, RUN_SECONDS])
	elif rise < 40.0:
		verdict = "cannot rise"
		failures += 1
		notes.append("%s only climbs %.0fpx -- it cannot get back to the surface, and the "
			% [entity_id, rise] + "ink-zero case says the apo is carried up")
	elif stretch_cost > usable_units:
		# ⚠ THE ONE THAT MATTERS AFTER TUNING. A body the level offers and the player cannot
		# pay for is a dead end dressed as a choice: they draw it, swim, run dry mid-crossing
		# and are carried back, every time, with nothing telling them the body was the problem.
		verdict = "CANNOT PAY ITS WAY"
		failures += 1
		notes.append("%s needs %.2f units for the longest unrefilled stretch and has %.1f"
			% [entity_id, stretch_cost, usable_units])
	# THE SECOND AXIS. The encounter is the only stretch of this level priced in time, and it
	# is the one a fast expensive class cannot brute-force: a shark holds a form for fifteen
	# seconds on a full tank and a single sweep of the creature's own cone takes almost eight.
	var hold := (usable_units + _arena_refill_units()) / maxf(0.0001, rate)
	var wanted := float(_economy.get("encounter_seconds", 0.0))
	if verdict == "ok" and wanted > 0.0 and hold < wanted:
		verdict = "CANNOT AFFORD THE ENCOUNTER"
		failures += 1
		notes.append("%s holds for %.0fs with every arena refill taken, and the encounter "
			% [entity_id, hold] + "is budgeted at %.0fs" % wanted)
	elif verdict == "ok" and stretch_cost > usable_units * 0.75:
		verdict = "tight"
		notes.append("%s spends %.0f%% of a full tank on the longest stretch"
			% [entity_id, stretch_cost / usable_units * 100.0])
	rows.append("%-11s %7.0f %6.2f %7.0f %8.0f %8.2f %7.0f  %s" % [
		entity_id, speed, rate, per_ink, reach, stretch_cost, hold, verdict])
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
