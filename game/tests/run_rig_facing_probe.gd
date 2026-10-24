extends SceneTree
## Does a drawn creature turn to face the way it moves?
##
## Kent, 2026-10-25: "make the drawings flip to face the way they move." A drawing looks the way
## it was drawn (SkeletonFit reads it: a horse drawn facing left is a left-facing horse); driven
## the other way it turns round, a squash through the middle in held frames, and keeps facing
## that way when it stops. One that looks no way -- a butterfly, a face -- never turns. Built
## the way the game builds them (EntityRegistry -> apply_drawing), its ink read back as drawn.
##
## Run: godot --headless --path game --script res://tests/run_rig_facing_probe.gd

const Fixtures := preload("res://tests/drawn_like_people_fixtures.gd")
const CHECKS := 22
const STEP := 1.0 / 60.0

var registry: EntityRegistry
var world: Node2D
var checked := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	world = Node2D.new()
	root.add_child(world)
	registry = EntityRegistry.new()
	world.add_child(registry)
	registry.load_manifest()
	_reduce(false)
	_a_left_facing_horse_turns_to_go_right()
	_a_right_facing_horse_going_right_does_not_turn()
	_a_butterfly_never_turns()
	_turned_round_it_leans_the_way_it_goes()
	_with_motion_reduced_it_turns_at_once()
	await _its_bodies_turn_round_with_it()
	await _turned_round_it_holds_poses_the_mirror_way()
	if checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	print("OBRA_RIG_FACING_OK" if failures == 0 else "OBRA_RIG_FACING_FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)


func _a_left_facing_horse_turns_to_go_right() -> void:
	var skin := _build("horse", Fixtures.mirrored(_fixture("horse facing right")))
	var drawn := _span(skin)
	_check(float(skin.debug_facing()["drawn"]) == -1.0, "a horse drawn facing left is read as looking left",
		"drawn %s" % skin.debug_facing()["drawn"])
	_check(_head_side(skin) < 0.0, "and its head starts on the left", "head %.1f from its body" % _head_side(skin))
	var flips: Array[float] = []
	for frame in range(30):
		_drive(skin, 1.0)
		flips.append(float(skin.debug_facing()["flip"]))
	var held := {}
	for value in flips:
		held[snappedf(value, 0.001)] = true
	_check(_head_side(skin) > 0.0, "driven right, it turns round: its head ends on the right",
		"head %.1f from its body" % _head_side(skin))
	var squashed := 0
	for value in flips:
		if absf(value) < 0.99:
			squashed += 1
	# Squashed through the middle and out again: 1 -> 1/3 -> (bodies turn) -> 1/3 -> 1.
	_check(flips[0] == 1.0 and squashed >= 3 and squashed <= 14 and held.size() <= 4 and flips[flips.size() - 1] == 1.0,
		"and it turns in a few held frames, not at once and not gliding",
		"first %.2f, squashed %d frames, %d positions %s" % [flips[0], squashed, held.size(), held.keys()])
	var turned := _span(skin)
	var slack := float(drawn["width"]) * 0.1
	_check(absf(float(turned["left"]) - float(drawn["left"])) < slack and absf(float(turned["right"]) - float(drawn["right"])) < slack,
		"turned round, its ink spans the same width it was drawn in -- its bodies still fit it",
		"drawn %.0f..%.0f, turned %.0f..%.0f" % [drawn["left"], drawn["right"], turned["left"], turned["right"]])
	for frame in range(30):
		_drive(skin, 0.0)
	_check(_head_side(skin) > 0.0, "and it keeps looking that way when it stops", "head %.1f" % _head_side(skin))
	for frame in range(30):
		_drive(skin, -1.0)
	_check(_head_side(skin) < 0.0, "driven left again, it turns back", "head %.1f" % _head_side(skin))
	skin.get_parent().queue_free()


func _a_right_facing_horse_going_right_does_not_turn() -> void:
	var skin := _build("horse", _fixture("horse facing right"))
	_check(float(skin.debug_facing()["drawn"]) == 1.0, "a horse drawn facing right is read as looking right",
		"drawn %s" % skin.debug_facing()["drawn"])
	var lowest := 1.0
	for frame in range(30):
		_drive(skin, 1.0)
		lowest = minf(lowest, float(skin.debug_facing()["flip"]))
	_check(lowest == 1.0 and _head_side(skin) > 0.0, "and driven right it never turns", "lowest flip %.2f" % lowest)
	skin.get_parent().queue_free()


func _a_butterfly_never_turns() -> void:
	var skin := _build("butterfly", _fixture("butterfly"))
	var lowest := 1.0
	for frame in range(30):
		_drive(skin, -1.0)
		lowest = minf(lowest, float(skin.debug_facing()["flip"]))
	_check(float(skin.debug_facing()["drawn"]) == 0.0 and lowest == 1.0,
		"a butterfly looks no way, and driven left it never turns",
		"drawn %s, lowest flip %.2f" % [skin.debug_facing()["drawn"], lowest])
	skin.get_parent().queue_free()


## Walking leans the body forward. Turned round by a mirror, the lean would turn round with it
## and the horse would walk leaning back -- so a left-drawn horse going right must lean the same
## way as a right-drawn one going right.
func _turned_round_it_leans_the_way_it_goes() -> void:
	var drops: Array[float] = []
	for strokes in [_fixture("horse facing right"), Fixtures.mirrored(_fixture("horse facing right"))]:
		var skin := _build("horse", strokes)
		# As drawn, before it has moved or leaned (a mirror leaves heights alone).
		var rest := _head_height(skin)
		for frame in range(30):
			_drive(skin, 1.0)
		var total := 0.0
		for frame in range(60):
			_drive(skin, 1.0)
			total += _head_height(skin) - rest
		drops.append(total / 60.0)
		skin.get_parent().queue_free()
	_check(absf(drops[0]) > 1.0 and signf(drops[0]) == signf(drops[1]),
		"turned round, it leans the way it goes, like one drawn that way",
		"head drop drawn right %.2f, turned %.2f" % [drops[0], drops[1]])


func _head_height(skin: RuntimeRig2D) -> float:
	var ink := _world_ink(skin)
	return _middle(ink[1]).y - _middle(ink[0]).y


func _with_motion_reduced_it_turns_at_once() -> void:
	_reduce(true)
	var skin := _build("horse", Fixtures.mirrored(_fixture("horse facing right")))
	_drive(skin, 1.0)
	_check(float(skin.debug_facing()["flip"]) == 1.0 and bool(skin.debug_facing()["bodies_turned"]) and _head_side(skin) > 0.0,
		"with motion reduced it turns at once, no squash",
		"flip %.2f, bodies turned %s after one frame" % [skin.debug_facing()["flip"], skin.debug_facing()["bodies_turned"]])
	_reduce(false)
	skin.get_parent().queue_free()


## With the physics running: a left-drawn horse standing on a floor, driven right. Its
## bodies must turn round under the ink -- the head's collider ends at the front too -- and
## the turned rig must still hold together, keep its speed, stand, and sit under its ink.
func _its_bodies_turn_round_with_it() -> void:
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var slab := RectangleShape2D.new()
	slab.size = Vector2(4000.0, 60.0)
	floor_shape.shape = slab
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(600.0, 460.0)
	world.add_child(floor_body)
	var instance := registry.instantiate_entity("horse") as Node2D
	world.add_child(instance)
	instance.global_position = Vector2(600.0, 360.0)
	if instance.has_method("set_world_bounds"):
		instance.call("set_world_bounds", Rect2(-1000.0, -1000.0, 4000.0, 3000.0))
	instance.call("apply_drawing", _blank_image(), Fixtures.mirrored(_fixture("horse facing right")))
	instance.set_physics_process(false)
	var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
	for frame in range(60):
		skin.set_motion_state("idle", {"moving": false, "direction": 0.0})
		await physics_frame
	var before_head := _head_collider_side(skin)
	var drawn_drift := _pose_drift(skin)
	var drawn_off := _colliders_off_ink(skin)
	var stood := skin.get_primary_body().global_position
	var recoveries := skin.debug_recovery_count()
	var worst := 0.0
	for frame in range(60):
		skin.set_motion_state("walk", {"moving": true, "speed_ratio": 1.0, "direction": 1.0})
		await physics_frame
		worst = maxf(worst, skin.debug_max_joint_error())
	_check(before_head < 0.0 and _head_collider_side(skin) > 0.0 and bool(skin.debug_facing()["bodies_turned"]),
		"its bodies turn round with it: the head's collider ends at the front too",
		"head collider %.1f before, %.1f after" % [before_head, _head_collider_side(skin)])
	_check(worst < 4.0 and skin.debug_recovery_count() == recoveries,
		"and the turned bodies hold together", "worst joint gap %.2f px, recoveries %d" % [worst, skin.debug_recovery_count() - recoveries])
	for frame in range(60):
		skin.set_motion_state("idle", {"moving": false, "direction": 0.0})
		await physics_frame
	_check(_pose_drift(skin) < drawn_drift + 6.0,
		"and stopped, it holds its drawn pose the mirror way round",
		"bodies %.1f px off their pose (as drawn: %.1f)" % [_pose_drift(skin), drawn_drift])
	_check(_colliders_off_ink(skin) < drawn_off + 6.0,
		"and every collider lies along its own ink, the way it did as drawn",
		"worst collider end %.1f px off the ink (as drawn: %.1f)" % [_colliders_off_ink(skin), drawn_off])
	var after := skin.get_primary_body()
	_check(absf(after.global_position.y - stood.y) < 12.0 and absf(after.global_rotation) < 0.3,
		"and it still stands", "moved %.1f px down, leaning %.2f rad" % [after.global_position.y - stood.y, after.global_rotation])
	var span := _span(skin)
	var outside := 0.0
	for centre in _collider_centres(skin):
		outside = maxf(outside, maxf(float(span["left"]) - centre.x, centre.x - float(span["right"])))
	_check(outside < 6.0, "and its ink still sits on its bodies", "furthest collider %.1f px outside the ink" % outside)
	skin.translate_rig(Vector2.ZERO, Vector2(150.0, 0.0))
	skin.call("_mirror_physics")
	var kept := skin.get_primary_body().linear_velocity.x
	# And straight back, so the rig is the way round its state says it is.
	skin.call("_mirror_physics")
	_check(kept > 100.0, "turning round keeps it going the way it was going", "x speed %.0f after" % kept)
	for frame in range(30):
		skin.set_motion_state("walk", {"moving": true, "speed_ratio": 1.0, "direction": -1.0})
		await physics_frame
	_check(_head_collider_side(skin) < 0.0 and not bool(skin.debug_facing()["bodies_turned"]),
		"driven back, its bodies turn back", "head collider %.1f" % _head_collider_side(skin))
	instance.queue_free()
	floor_body.queue_free()


## A side-on bird glides holding its wings in a pose (a lift to one side). Turned round, it
## must hold the MIRROR of that pose -- the same glide seen from the other side -- not the
## same angles, which on a mirrored body are the opposite lift.
func _turned_round_it_holds_poses_the_mirror_way() -> void:
	var held: Array = []
	for direction in [1.0, -1.0]:
		var instance := registry.instantiate_entity("bird") as Node2D
		world.add_child(instance)
		instance.global_position = Vector2(1400.0 + direction * 300.0, 200.0)
		if instance.has_method("set_world_bounds"):
			instance.call("set_world_bounds", Rect2(-1000.0, -1000.0, 4000.0, 3000.0))
		instance.call("apply_drawing", _blank_image(), _fixture("bird from the side, facing right"))
		instance.set_physics_process(false)
		var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
		for body in skin.get_rigid_bodies():
			body.gravity_scale = 0.0
		for frame in range(70):
			skin.set_motion_state("glide", {"moving": true, "speed_ratio": 1.0, "direction": direction})
			await physics_frame
		var angles: Array[float] = []
		for segment in skin.get("_segments"):
			angles.append(float((segment as Dictionary).get("tracked_angle", 0.0)))
		held.append(angles)
		if direction < 0.0:
			await _a_turned_flier_stays_upright_when_tipped(skin)
		instance.queue_free()
	var together := 0.0
	var size := 0.0
	for index in range(mini((held[0] as Array).size(), (held[1] as Array).size())):
		together += float(held[0][index]) * float(held[1][index])
		size += float(held[0][index]) * float(held[0][index])
	_check(size > 0.01 and together < -0.5 * size,
		"turned round, a gliding bird holds its wings the mirror way, like one drawn that way",
		"pose agreement %.2f of %.2f (mirror = -1)" % [together, size])


## A flier's drawing cancels its torso's spin so it flies level. Seen through the mirror a
## turned bird carries, the spin runs the other way -- so tipping a turned bird's torso must
## still leave its drawing level.
func _a_turned_flier_stays_upright_when_tipped(skin: RuntimeRig2D) -> void:
	var torso := skin.get_primary_body()
	for body in skin.get_rigid_bodies():
		body.freeze = true
	skin.call("_animate_skinned_ink", 0.0)
	var level := _ink_heading(skin)
	torso.global_rotation += 0.4
	skin.call("_animate_skinned_ink", 0.0)
	var tipped := _ink_heading(skin)
	_check(bool(skin.debug_facing()["bodies_turned"]) and absf(angle_difference(level, tipped)) < 0.05,
		"turned round and tipped, a flier's drawing stays level",
		"drawing turned %.2f rad when its torso tipped 0.40" % angle_difference(level, tipped))


## Which way the bird's head lies from its body, on screen (strokes 0 body, 1 head).
func _ink_heading(skin: RuntimeRig2D) -> float:
	var ink := _world_ink(skin)
	return (_middle(ink[1]) - _middle(ink[0])).angle()


## How far the end of any capsule collider sits from the ink it was built along, at worst.
func _colliders_off_ink(skin: RuntimeRig2D) -> float:
	var ink := PackedVector2Array()
	for line in _world_ink(skin):
		ink.append_array(line as PackedVector2Array)
	var worst := 0.0
	for body in skin.get_rigid_bodies():
		for child in body.get_children():
			var collision := child as CollisionShape2D
			if collision == null or not (collision.shape is CapsuleShape2D):
				continue
			var capsule := collision.shape as CapsuleShape2D
			var place := collision.global_transform
			var reach := place.y.normalized() * maxf(0.0, capsule.height * 0.5 - capsule.radius)
			for end in [place.origin + reach, place.origin - reach]:
				var nearest := INF
				for point in ink:
					nearest = minf(nearest, point.distance_to(end))
				worst = maxf(worst, nearest - capsule.radius)
	return worst


## How far the bodies sit from where the rig's rest pose puts them, at worst.
func _pose_drift(skin: RuntimeRig2D) -> float:
	var rests: Dictionary = skin.get("_rest_transforms")
	var primary := skin.get_primary_body()
	var worst := 0.0
	for body in skin.get_rigid_bodies():
		var rest: Transform2D = rests.get(body.get_instance_id(), Transform2D.IDENTITY)
		worst = maxf(worst, body.global_position.distance_to((primary.global_transform * rest).origin))
	return worst


## How far right of the ink's middle the highest collision shape sits -- on a horse, its head.
func _head_collider_side(skin: RuntimeRig2D) -> float:
	var top := Vector2(0.0, INF)
	for centre in _collider_centres(skin):
		if centre.y < top.y:
			top = centre
	var span := _span(skin)
	return top.x - (float(span["left"]) + float(span["right"])) * 0.5


func _collider_centres(skin: RuntimeRig2D) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for body in skin.get_rigid_bodies():
		for child in (body as Node).get_children():
			if child is CollisionShape2D:
				out.append((child as CollisionShape2D).global_position)
	return out


# --- helpers ------------------------------------------------------------------

func _fixture(label: String) -> Array:
	for fixture_value in Fixtures.all():
		if String((fixture_value as Dictionary)["label"]) == label:
			return (fixture_value as Dictionary)["strokes"]
	return []


func _build(entity_id: String, strokes: Array) -> RuntimeRig2D:
	var instance := registry.instantiate_entity(entity_id) as Node2D
	world.add_child(instance)
	instance.call("apply_drawing", _blank_image(), strokes)
	instance.set_physics_process(false)
	instance.set_process(false)
	var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
	skin.set_physics_process(false)
	skin.set_process(false)
	return skin


## One frame of being driven `direction` (-1 left, 1 right, 0 standing).
func _drive(skin: RuntimeRig2D, direction: float) -> void:
	skin.set_motion_state("walk" if direction != 0.0 else "idle",
		{"moving": direction != 0.0, "speed_ratio": absf(direction), "direction": direction})
	skin.call("_animate_skinned_ink", STEP)


## How far right of its body's middle the horse's head is drawn now, on screen (stroke 1 is
## the head). On screen, because a turned creature's ink rides a mirrored transform.
func _head_side(skin: RuntimeRig2D) -> float:
	var ink := _world_ink(skin)
	return _middle(ink[1]).x - _middle(ink[0]).x


func _world_ink(skin: RuntimeRig2D) -> Array:
	var place := skin.debug_skin_transform()
	var out: Array = []
	for line in skin.debug_skin_points():
		out.append(place * line)
	return out


func _middle(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for point in points:
		sum += point
	return sum / float(maxi(1, points.size()))


## The ink's left and right edges and its width.
func _span(skin: RuntimeRig2D) -> Dictionary:
	var low := INF
	var high := -INF
	for line in _world_ink(skin):
		for point in line:
			low = minf(low, point.x)
			high = maxf(high, point.x)
	return {"left": low, "right": high, "width": high - low}


func _reduce(on: bool) -> void:
	var profile := root.get_node_or_null(^"PlayerProfile")
	if profile != null:
		profile.call(&"set_setting", "reduce_motion", on)


func _blank_image() -> Image:
	var image := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return image


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if not ok:
		failures += 1
	print("  %s\t%s\t%s" % ["OK" if ok else "FAIL", what, detail])
