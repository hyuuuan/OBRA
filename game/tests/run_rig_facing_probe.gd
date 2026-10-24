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
const CHECKS := 12
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
	_check(flips[0] > -1.0 and held.size() >= 3 and held.size() <= 6,
		"and it turns in a few held frames, not at once and not gliding",
		"first %.2f, %d positions %s" % [flips[0], held.size(), held.keys()])
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
	var ink := skin.debug_skin_points()
	return _middle(ink[1]).y - _middle(ink[0]).y


func _with_motion_reduced_it_turns_at_once() -> void:
	_reduce(true)
	var skin := _build("horse", Fixtures.mirrored(_fixture("horse facing right")))
	_drive(skin, 1.0)
	_check(float(skin.debug_facing()["flip"]) == -1.0 and _head_side(skin) > 0.0,
		"with motion reduced it turns at once, no squash",
		"flip %.2f after one frame" % skin.debug_facing()["flip"])
	_reduce(false)
	skin.get_parent().queue_free()


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


## How far right of its body's middle the horse's head is drawn now (stroke 1 is the head).
func _head_side(skin: RuntimeRig2D) -> float:
	var ink := skin.debug_skin_points()
	return _middle(ink[1]).x - _middle(ink[0]).x


func _middle(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for point in points:
		sum += point
	return sum / float(maxi(1, points.size()))


## The ink's left and right edges and its width.
func _span(skin: RuntimeRig2D) -> Dictionary:
	var low := INF
	var high := -INF
	for line in skin.debug_skin_points():
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
