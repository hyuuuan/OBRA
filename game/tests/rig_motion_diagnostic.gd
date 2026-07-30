extends SceneTree
## Separates the two failure modes the player sees:
##   TRANSIENT — limbs whipping/scattering in the first moments after spawn
##   STEADY    — whether the limb then actually ANIMATES (bounded oscillation of
##               useful amplitude) or just hangs/creeps/spins
## godot --headless --path game --script res://tests/rig_motion_diagnostic.gd

const SpiderReferenceFixtures = preload("res://tests/spider_reference_fixtures.gd")
const SETTLE := 60
const MEASURE := 240

var world: Node2D
var registry: EntityRegistry


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	world = Node2D.new()
	root.add_child(world)
	_add_floor()
	registry = EntityRegistry.new()
	world.add_child(registry)
	registry.load_manifest()

	print("                    |--- transient ---|------------- steady state --------------|")
	print("entity        rig    peakAngVel peakJerr  amplitude  centre  jointErr  COLLAPSE(deg)")
	print("-------------------------------------------------------------------------------")
	for entity_id in ["fish", "shark", "horse", "pig", "bird", "butterfly", "monkey", "frog", "snake", "spider", "crab", "octopus"]:
		if registry.get_entity(entity_id).is_empty():
			continue
		await _probe(entity_id)
	world.queue_free()
	await process_frame
	quit(0)


func _probe(entity_id: String) -> void:
	var entry := registry.get_entity(entity_id)
	var rig_type := String(entry.get("rig_type", "none"))
	var state := _gait_for_rig(rig_type)
	var instance := registry.instantiate_entity(entity_id) as Node2D
	if instance == null:
		return
	world.add_child(instance)
	instance.global_position = Vector2(400.0, 300.0)
	if instance.has_method("set_world_bounds"):
		instance.call("set_world_bounds", Rect2(0.0, -520.0, 3760.0, 1200.0))
	instance.call("apply_drawing", _blank_image(), _fixture_for(entity_id))
	var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
	var primary := skin.get_primary_body()
	instance.set_physics_process(false)
	var params := {"moving": true, "speed_ratio": 1.0, "direction": 1.0, "charge_ratio": 1.0}

	var limb: ActiveRigBody2D = null
	for body in skin.get_rigid_bodies():
		if body != primary:
			limb = body
			break
	if limb == null or primary == null:
		instance.queue_free()
		await process_frame
		return

	# Pose every limb held the instant the rig was built: the drawing itself.
	var rest_angles: Dictionary = {}
	for body in skin.get_rigid_bodies():
		if is_instance_valid(body) and body != primary:
			rest_angles[body.get_instance_id()] = body.rotation - primary.rotation

	# --- transient window ---
	var transient_ang_vel := 0.0
	var transient_joint_error := 0.0
	for _frame in range(SETTLE):
		skin.set_motion_state(state, params)
		await physics_frame
		for body in skin.get_rigid_bodies():
			if is_instance_valid(body) and body != primary:
				transient_ang_vel = maxf(transient_ang_vel, absf(body.angular_velocity))
		transient_joint_error = maxf(transient_joint_error, skin.debug_max_joint_error())

	# --- steady-state window ---
	var tracked := 0.0
	var previous := wrapf(limb.rotation - primary.rotation, -PI, PI)
	var minimum := INF
	var maximum := -INF
	var total := 0.0
	var steady_ang_vel := 0.0
	var steady_joint_error := 0.0
	for _frame in range(MEASURE):
		skin.set_motion_state(state, params)
		await physics_frame
		var measured := wrapf(limb.rotation - primary.rotation, -PI, PI)
		tracked += wrapf(measured - previous, -PI, PI)
		previous = measured
		minimum = minf(minimum, tracked)
		maximum = maxf(maximum, tracked)
		total += tracked
		for body in skin.get_rigid_bodies():
			if is_instance_valid(body) and body != primary:
				steady_ang_vel = maxf(steady_ang_vel, absf(body.angular_velocity))
		steady_joint_error = maxf(steady_joint_error, skin.debug_max_joint_error())

	# How far the limbs ended up from the pose the player drew. This is the number
	# that matters: a large value means the drawing has collapsed into a heap.
	var collapse := 0.0
	for body in skin.get_rigid_bodies():
		if not is_instance_valid(body) or body == primary:
			continue
		if not rest_angles.has(body.get_instance_id()):
			continue
		var rest: float = rest_angles[body.get_instance_id()]
		collapse = maxf(collapse, absf(wrapf(body.rotation - primary.rotation - rest, -PI, PI)))

	print("%-13s %-6s %10.2f %8.2f %10.1f %7.1f %9.2f %10.1f" % [
		entity_id, rig_type,
		transient_ang_vel, transient_joint_error,
		rad_to_deg(maximum - minimum), rad_to_deg(total / float(MEASURE)),
		steady_joint_error, rad_to_deg(collapse)
	])
	instance.queue_free()
	await process_frame


func _add_floor() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0.0, 600.0)
	var collision := CollisionShape2D.new()
	var shape := WorldBoundaryShape2D.new()
	shape.normal = Vector2.UP
	collision.shape = shape
	floor_body.add_child(collision)
	world.add_child(floor_body)


func _gait_for_rig(rig_type: String) -> String:
	match rig_type:
		"flier": return "fly"
		"swimmer": return "swim"
		"hopper": return "jump"
		_: return "walk"


func _blank_image() -> Image:
	var image := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return image


func _stroke(points: PackedVector2Array) -> Dictionary:
	return {"points": points, "width": 8.0, "color": Color.BLACK}


func _closed_body() -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(17):
		var angle := TAU * float(index) / 16.0
		points.append(Vector2(256.0 + cos(angle) * 70.0, 240.0 + sin(angle) * 38.0))
	return points


## Drawings shaped the way a player actually draws these animals. Limbs radiating
## in all four directions (the old fixture) is not what the game receives and hid
## how badly a normal quadruped drawing collapses.
func _fixture_for(entity_id: String) -> Array:
	if entity_id == "snake":
		var wave := PackedVector2Array()
		for index in range(18):
			wave.append(Vector2(90.0 + index * 19.0, 256.0 + sin(float(index) * 0.75) * 28.0))
		return [_stroke(wave)]
	if entity_id == "spider":
		return SpiderReferenceFixtures.separate_legs()
	var strokes: Array = [_stroke(_closed_body())]
	if entity_id in ["fish", "shark", "octopus"]:
		strokes.append(_stroke(PackedVector2Array([
			Vector2(188.0, 240.0), Vector2(150.0, 214.0), Vector2(132.0, 240.0), Vector2(150.0, 266.0)
		])))
		return strokes
	if entity_id in ["bird", "butterfly"]:
		strokes.append(_stroke(PackedVector2Array([
			Vector2(240.0, 212.0), Vector2(206.0, 172.0), Vector2(170.0, 150.0)
		])))
		strokes.append(_stroke(PackedVector2Array([
			Vector2(276.0, 212.0), Vector2(310.0, 172.0), Vector2(346.0, 150.0)
		])))
		return strokes
	for offset in [-46.0, -16.0, 16.0, 46.0]:
		var hip := Vector2(256.0 + offset, 274.0)
		strokes.append(_stroke(PackedVector2Array([
			hip, hip + Vector2(0.0, 34.0), hip + Vector2(0.0, 68.0)
		])))
	return strokes
