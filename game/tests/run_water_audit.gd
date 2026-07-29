extends SceneTree
## Does water behave like water? Buoyancy, wading, and whether a fish sinks.
##   godot --headless --path game --script res://tests/run_water_audit.gd
##
## THE HARNESS CHECKS ITSELF FIRST. An earlier version of this reported three identical
## readings across three different code states -- which is not a result, it is a harness
## that is not measuring anything. Two things had gone wrong, and both are easy to
## repeat, so each now has an explicit precondition that fails loudly:
##
##   1. The test geometry sat below the wanderer's default world_bounds (y > 680), and
##      the wanderer teleports back to the top of the world when it falls past them. It
##      was not sinking, it was looping. Everything here lives inside the bounds.
##   2. A drawn creature's rig bodies are top_level, so setting the morph node's
##      global_position moves the node and leaves the physics behind at the origin. The
##      fish was never in the pool at all, which is why changing its buoyancy changed
##      nothing. Morphs are positioned through apply_morph_state, which moves every body.

var world: Node2D
var registry: EntityRegistry
var results: Array[String] = []

## Everything is laid out inside Rect2(0, -520, 3760, 1200): water at y 150..450,
## riverbed at 460.
const SURFACE_Y := 150.0
const POOL_HEIGHT := 300.0
const BED_TOP := 460.0


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

	await _check_a_cork_floats()
	await _check_wading()
	await _check_fish_sinks_and_swims()

	print("\n===== WATER AUDIT =====")
	for line in results:
		print(line)
	quit(0)


func _pass(what: String, detail: String) -> void:
	results.append("  OK    %-18s %s" % [what, detail])


func _fail(what: String, detail: String) -> void:
	results.append("  FAIL  %-18s %s" % [what, detail])


func _bed() -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(1200.0, BED_TOP + 60.0)
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(3000.0, 120.0)
	collision.shape = box
	body.add_child(collision)
	world.add_child(body)


func _pool() -> void:
	var pool := WaterArea2D.new()
	# Before add_child: _ready sizes the collision from surface_size, so setting it
	# afterwards leaves a correctly drawn pool with the wrong shape in it.
	pool.surface_size = Vector2(1400.0, POOL_HEIGHT)
	pool.position = Vector2(1200.0, SURFACE_Y + POOL_HEIGHT * 0.5)
	world.add_child(pool)


func _settle(frames: int) -> void:
	for i in range(frames):
		await physics_frame


## A light rigid body dropped in must come back up. Nothing else here means anything
## if the lift is not being applied at all.
func _check_a_cork_floats() -> void:
	var cork := RigidBody2D.new()
	cork.mass = 0.4
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	collision.shape = circle
	cork.add_child(collision)
	world.add_child(cork)
	cork.global_position = Vector2(700.0, SURFACE_Y - 60.0)
	await _settle(20)
	if int(cork.get_meta("water_overlap_count", 0)) <= 0 and cork.global_position.y > SURFACE_Y:
		_fail("water registers", "the pool never tagged a body inside it")
		cork.queue_free()
		await process_frame
		return
	var deepest := cork.global_position.y
	for i in range(180):
		await physics_frame
		deepest = maxf(deepest, cork.global_position.y)
	var resurfaced := deepest - cork.global_position.y
	var resting := cork.global_position.y
	if resurfaced > 10.0 and resting < BED_TOP - 20.0:
		_pass("buoyancy", "cork sank to %.0f, rose %.0f, floats above the bed" % [deepest, resurfaced])
	elif resting >= BED_TOP - 20.0:
		_fail("buoyancy", "cork sank to the riverbed at y=%.0f -- no lift" % resting)
	else:
		_fail("buoyancy", "cork settled at y=%.0f without rising" % resting)
	cork.queue_free()
	await process_frame


## Deep water has to stop a walker, or a drawn boat is pointless.
func _check_wading() -> void:
	var hero := (load("res://creatures/wanderer.tscn") as PackedScene).instantiate() as Node2D
	world.add_child(hero)
	hero.call("set_world_bounds", Rect2(0.0, -520.0, 3760.0, 1200.0))
	hero.global_position = Vector2(700.0, SURFACE_Y - 80.0)
	await _settle(30)
	if not bool(hero.call("is_in_water")):
		_fail("wading", "the wanderer never registered as being in the water")
		hero.queue_free()
		await process_frame
		return
	var dry := (load("res://creatures/wanderer.tscn") as PackedScene).instantiate() as Node2D
	world.add_child(dry)
	dry.call("set_world_bounds", Rect2(0.0, -520.0, 3760.0, 1200.0))
	dry.global_position = Vector2(2400.0, BED_TOP - 40.0)
	await _settle(20)
	var wet_start := hero.global_position.x
	var dry_start := dry.global_position.x
	Input.action_press("move_right")
	await _settle(120)
	Input.action_release("move_right")
	var wet := hero.global_position.x - wet_start
	var walked := dry.global_position.x - dry_start
	if walked > 100.0 and wet < walked * 0.75:
		_pass("wading", "%.0fpx through water vs %.0fpx on land" % [wet, walked])
	elif walked <= 100.0:
		_fail("wading", "the dry control did not walk (%.0fpx) -- harness fault" % walked)
	else:
		_fail("wading", "water cost nothing: %.0fpx wet vs %.0fpx dry" % [wet, walked])
	hero.queue_free()
	dry.queue_free()
	await process_frame


## Left alone a fish should drift down; told to swim it should beat that easily and
## hold a depth well clear of both the surface and the bed.
func _check_fish_sinks_and_swims() -> void:
	var fish := registry.instantiate_entity("fish") as Node2D
	world.add_child(fish)
	fish.call("apply_drawing", _blank(), [{
		"points": PackedVector2Array([
			Vector2(0, 0), Vector2(60, 12), Vector2(96, 0), Vector2(60, -12), Vector2(0, 0)]),
		"width": 6.0, "color": Color.BLACK,
	}])
	# Through apply_morph_state, NOT global_position: the rig bodies are top_level and
	# would otherwise stay at the origin while the node alone moved.
	fish.call("apply_morph_state", {"position": Vector2(1000.0, SURFACE_Y + 90.0)})
	await _settle(20)
	var anchor := fish.call("get_physics_anchor") as Node2D
	if anchor == null or not bool(fish.call("is_in_water")):
		_fail("fish in water", "the fish never registered as being in the pool")
		fish.queue_free()
		await process_frame
		return
	var idle_start := anchor.global_position.y
	await _settle(120)
	var sank := anchor.global_position.y - idle_start
	if sank > 12.0:
		_pass("fish sinks", "drifted %.0fpx down when left alone" % sank)
	else:
		_fail("fish sinks", "held its depth (%.0fpx) with no input" % sank)

	var swim_start := anchor.global_position.y
	Input.action_press("move_up")
	await _settle(120)
	Input.action_release("move_up")
	var risen := swim_start - anchor.global_position.y
	if risen > 40.0:
		_pass("fish swims up", "climbed %.0fpx against its own weight" % risen)
	else:
		_fail("fish swims up", "only climbed %.0fpx -- too heavy to swim" % risen)
	if anchor.global_position.y < BED_TOP - 10.0:
		_pass("fish stays wet", "at y=%.0f, clear of the bed" % anchor.global_position.y)
	else:
		_fail("fish stays wet", "sank out of the pool to y=%.0f" % anchor.global_position.y)
	fish.queue_free()
	await process_frame


func _blank() -> Image:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return image
