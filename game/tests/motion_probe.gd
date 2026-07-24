extends SceneTree
## Measures whether joints actually MOVE in their species gait — per-limb angle
## excursion and the integrated (unwrapped) max joint angle — on realistic
## freehand drawings, not just whether torque is nonzero. This is what exposed
## the limb-windmilling bug the pin-error assertions could not see.
## Run: godot --headless --path game --script res://tests/motion_probe.gd

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

	await _probe("bird freehand", "bird", _bird_freehand(), "fly", {"moving": true, "speed_ratio": 1.0, "direction": 1.0})
	await _probe("bird flap", "bird", _bird_freehand(), "flap", {"moving": true, "speed_ratio": 1.0, "direction": 1.0})
	await _probe("stickman freehand", "monkey", _stickman_freehand(), "walk", {"moving": true, "speed_ratio": 1.0, "direction": 1.0})
	await _probe("spider freehand", "spider", _spider_freehand(), "walk", {"moving": true, "speed_ratio": 1.0, "direction": 1.0})
	var reference_fixtures := load("res://tests/spider_reference_fixtures.gd")
	await _probe("spider clean", "spider", reference_fixtures.separate_legs(), "walk", {"moving": true, "speed_ratio": 1.0, "direction": 1.0})
	await _probe("cat clean reference", "pig", _cat_clean(), "walk", {"moving": true, "speed_ratio": 1.0, "direction": 1.0})
	quit(0)


func _probe(label: String, entity_id: String, strokes: Array, state: String, params: Dictionary) -> void:
	var instance := registry.instantiate_entity(entity_id) as Node2D
	if instance == null:
		print("PROBE %s NO_ENTITY" % label)
		return
	world.add_child(instance)
	instance.global_position = Vector2(300.0, 200.0)
	if instance.has_method("set_world_bounds"):
		instance.call("set_world_bounds", Rect2(0.0, -520.0, 3760.0, 1200.0))
	instance.call("apply_drawing", _blank_image(), strokes)
	var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
	var primary := skin.get_primary_body()
	print("PROBE %s | joints=%d bodies=%d primary=%s roles=%s" % [
		label, skin.get_joint_count(), skin.get_rigid_bodies().size(),
		primary.name if primary != null else "none", str(skin.debug_segment_roles())
	])
	instance.set_physics_process(false)
	# settle
	for _f in range(30):
		skin.set_motion_state("idle", {"moving": false})
		await physics_frame
	var mins: Array[float] = []
	var maxs: Array[float] = []
	for _i in skin._segments:
		mins.append(INF)
		maxs.append(-INF)
	var start_pos := primary.global_position if primary != null else Vector2.ZERO
	var max_error := 0.0
	for _f in range(180):
		skin.set_motion_state(state, params)
		await physics_frame
		max_error = maxf(max_error, skin.debug_max_joint_error())
		for index in range(skin._segments.size()):
			var segment: Dictionary = skin._segments[index]
			var parent := segment["parent"] as ActiveRigBody2D
			var child := segment["body"] as ActiveRigBody2D
			if not is_instance_valid(parent) or not is_instance_valid(child):
				continue
			var angle := wrapf(child.rotation - parent.rotation - float(segment["rest_relative"]), -PI, PI)
			mins[index] = minf(mins[index], angle)
			maxs[index] = maxf(maxs[index], angle)
	var lines: Array[String] = []
	for index in range(skin._segments.size()):
		var segment: Dictionary = skin._segments[index]
		var excursion := rad_to_deg(maxs[index] - mins[index]) if maxs[index] > mins[index] else 0.0
		lines.append("%s L%d.%d %.0fdeg" % [
			String(segment["role"]), int(segment["limb_index"]), int(segment["chain_index"]), excursion
		])
	var displacement := (primary.global_position - start_pos) if primary != null else Vector2.ZERO
	print("  state=%s displacement=%s maxerr=%.1f recov=%d max_tracked=%.0fdeg" % [
		state, str(displacement.round()), max_error, skin.debug_recovery_count(),
		rad_to_deg(skin.debug_max_tracked_angle())
	])
	print("  excursions: %s" % " | ".join(lines))
	var finals: Array[String] = []
	for index in range(skin._segments.size()):
		var segment: Dictionary = skin._segments[index]
		var child := segment["body"] as ActiveRigBody2D
		if not is_instance_valid(child):
			finals.append("%d:invalid" % index)
			continue
		var finite := is_finite(child.rotation) and is_finite(child.global_position.x)
		finals.append("%d:%s m=%.2f trk=%.0f" % [
			index, "ok" if finite else "NONFINITE", child.mass,
			rad_to_deg(float(segment.get("tracked_angle", 0.0)))
		])
	print("  segs: %s" % " | ".join(finals))
	instance.queue_free()
	await process_frame


func _jitter_line(from: Vector2, to: Vector2, step: float = 3.0, amp: float = 1.8, phase: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	var length := from.distance_to(to)
	var count := maxi(2, int(length / step))
	var direction := (to - from) / float(count)
	var normal := Vector2(-direction.y, direction.x).normalized()
	for index in range(count + 1):
		var point := from + direction * float(index)
		point += normal * amp * sin(7.1 * float(index) + phase)
		points.append(point)
	return points


func _jitter_path(waypoints: Array, step: float = 3.0, amp: float = 1.8, phase: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(waypoints.size() - 1):
		var segment := _jitter_line(waypoints[index], waypoints[index + 1], step, amp, phase + float(index))
		if index > 0:
			segment = segment.slice(1)
		points.append_array(segment)
	return points


func _ellipse(center: Vector2, rx: float, ry: float, step_deg: float = 4.0, amp: float = 1.5) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := int(360.0 / step_deg)
	for index in range(count + 1):
		var theta := TAU * float(index) / float(count)
		var wobble := amp * sin(5.0 * theta)
		points.append(center + Vector2(cos(theta) * (rx + wobble), sin(theta) * (ry + wobble)))
	return points


func _stroke(points: PackedVector2Array) -> Dictionary:
	return {"points": points, "width": 8.0, "color": Color.BLACK}


## Bird the way players draw one: oval body, open V wings drawn from the back
## crossing over the body outline, tail feathers, round head with beak.
func _bird_freehand() -> Array:
	var strokes: Array = []
	strokes.append(_stroke(_ellipse(Vector2(256.0, 260.0), 64.0, 40.0)))
	# Left wing: starts above-left of the body, dips INTO the body outline, back up.
	strokes.append(_stroke(_jitter_path([
		Vector2(170.0, 190.0), Vector2(225.0, 240.0), Vector2(283.0, 238.0), Vector2(342.0, 186.0)
	], 3.0, 2.0, 0.4)))
	# Tail: two strokes leaving the body's left edge.
	strokes.append(_stroke(_jitter_line(Vector2(196.0, 252.0), Vector2(128.0, 232.0), 3.0, 1.6, 1.0)))
	strokes.append(_stroke(_jitter_line(Vector2(197.0, 266.0), Vector2(130.0, 268.0), 3.0, 1.6, 2.0)))
	# Head: small circle overlapping the body's right side, plus beak.
	strokes.append(_stroke(_ellipse(Vector2(330.0, 232.0), 24.0, 22.0, 6.0, 1.0)))
	strokes.append(_stroke(_jitter_path([Vector2(352.0, 228.0), Vector2(376.0, 236.0), Vector2(353.0, 242.0)], 3.0, 0.8, 0.0)))
	return strokes


## Classic stick figure: head circle, spine, arms as ONE stroke crossing the
## spine, two separate legs from the spine's base.
func _stickman_freehand() -> Array:
	var strokes: Array = []
	strokes.append(_stroke(_ellipse(Vector2(256.0, 150.0), 30.0, 30.0, 6.0, 1.0)))
	strokes.append(_stroke(_jitter_line(Vector2(256.0, 180.0), Vector2(256.0, 300.0), 3.0, 1.5, 0.0)))
	strokes.append(_stroke(_jitter_line(Vector2(180.0, 230.0), Vector2(332.0, 230.0), 3.0, 1.5, 1.2)))
	strokes.append(_stroke(_jitter_path([Vector2(256.0, 300.0), Vector2(216.0, 360.0), Vector2(206.0, 404.0)], 3.0, 1.5, 2.2)))
	strokes.append(_stroke(_jitter_path([Vector2(256.0, 300.0), Vector2(296.0, 360.0), Vector2(306.0, 404.0)], 3.0, 1.5, 3.1)))
	return strokes


## Freehand spider: wobbly oval + 8 bent legs drawn as separate strokes.
func _spider_freehand() -> Array:
	var strokes: Array = []
	strokes.append(_stroke(_ellipse(Vector2(256.0, 250.0), 55.0, 38.0)))
	var roots := [
		Vector2(212.0, 232.0), Vector2(204.0, 250.0), Vector2(206.0, 268.0), Vector2(218.0, 282.0),
		Vector2(300.0, 232.0), Vector2(308.0, 250.0), Vector2(306.0, 268.0), Vector2(294.0, 282.0)
	]
	for index in range(8):
		var root: Vector2 = roots[index]
		var side := -1.0 if index < 4 else 1.0
		var knee := root + Vector2(side * 52.0, -26.0 + float(index % 4) * 16.0)
		var foot := knee + Vector2(side * 30.0, 58.0)
		strokes.append(_stroke(_jitter_path([root, knee, foot], 3.0, 1.6, float(index) * 0.9)))
	return strokes


func _cat_clean() -> Array:
	var strokes: Array = [_stroke(_ellipse(Vector2(256.0, 250.0), 62.0, 42.0, 6.0, 0.0))]
	for index in range(4):
		var angle := TAU * float(index) / 4.0
		var start := Vector2(256.0, 250.0) + Vector2(cos(angle) * 58.0, sin(angle) * 38.0)
		var tip := start + Vector2(cos(angle) * 76.0, sin(angle) * 76.0)
		strokes.append(_stroke(_jitter_line(start, tip, 4.0, 0.0)))
	return strokes


func _blank_image() -> Image:
	var image := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return image


func _add_floor() -> void:
	var floor_body := StaticBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(4000.0, 60.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	floor_body.add_child(collision)
	floor_body.position = Vector2(1800.0, 430.0)
	world.add_child(floor_body)
