extends SceneTree
## Actual movement through both gates. Bare travel must fail; two drawn answers must work.
const CHECKS := 7
var checked := 0
var failures := 0
var level: Node
var player: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for gate in ["span", "climb"]:
		await _open()
		await _stand(gate)
		var bare := await _walk(gate, 180)
		_check(not bare, gate + " cannot be passed by running, jumping, and holding up", str(player.global_position))
		await _close()
		for answer in (["bridge", "ladder"] if gate == "span" else ["stairs", "ladder"]):
			await _open()
			await _stand(gate)
			var placed := await _place(answer, gate)
			var reached := false
			if placed:
				reached = await _walk(gate, 360)
			_check(placed and reached, gate + " is physically passed with " + answer,
				"placed %s, reached %s, at %s" % [placed, reached, player.global_position])
			await _close()
	await _open()
	player.call("apply_morph_state", {"position": Vector2(9410, -200), "linear_velocity": Vector2.ZERO})
	for i in range(30):
		await physics_frame
	var flower_reached := await _walk("flower", 900)
	_check(flower_reached and is_equal_approx((level.get("ink_manager") as InkManager).remaining(), 6.0),
		"the flower detour is reached with movement and no extra drawing", str(player.global_position))
	await _close()
	if checked == CHECKS and failures == 0:
		print("OBRA_WALK_LEVEL5_OK")
	else:
		failures += int(checked != CHECKS)
		print("OBRA_WALK_LEVEL5_FAILED=%d (%d/%d)" % [failures, checked, CHECKS])
	quit(0 if failures == 0 else 1)


func _open() -> void:
	level = load("res://level_5.tscn").instantiate()
	level.get_node("BackendSupervisor").auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, "set_auto_dismiss", true)
	for i in range(35):
		await physics_frame
	player = level.get("player")


func _close() -> void:
	for action in ["move_right", "move_up", "jump"]:
		Input.action_release(action)
	level.queue_free()
	for i in range(5):
		await process_frame


func _stand(gate: String) -> void:
	player.call("apply_morph_state", {"position": Vector2(2200, 400) if gate == "span" else Vector2(3980, 320), "linear_velocity": Vector2.ZERO})
	for i in range(30):
		await physics_frame


func _place(entity: String, gate: String) -> bool:
	var points := PackedVector2Array([Vector2(0, 0), Vector2(340, 0)])
	if entity == "ladder":
		points = PackedVector2Array([Vector2(0, 244), Vector2(0, 0), Vector2(72, 0), Vector2(72, 244)])
	elif entity == "stairs":
		points = PackedVector2Array()
		for i in range(5):
			points.append(Vector2(i*50, 200-i*50))
			points.append(Vector2((i+1)*50, 200-i*50))
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	level.call("_on_drawing_ready", entity, entity.capitalize(), image, {"confidence": .95},
		[{"points": points, "width": 6.0, "color": Color.BLACK}], 1.0)
	await process_frame
	level.call("_on_inventory_slot_pressed", int(level.call("_slot_holding", entity)))
	var placement := level.get("placement_controller") as PlacementController
	if not placement.is_placing():
		return false
	placement.set_process(false)
	var aim := Vector2(2450, 420) if gate == "span" else Vector2(4140, 350)
	if entity == "ladder" and gate == "span":
		# The existing pinch/wheel controls lay a longer ladder across the 300px gap.
		var pinch := InputEventMagnifyGesture.new()
		pinch.factor = 1.5
		placement.call("_unhandled_input", pinch)
		for i in range(6):
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel.pressed = true
			placement.call("_unhandled_input", wheel)
	for i in range(4):
		placement.update_target(aim)
		await physics_frame
	var confirmed := placement.confirm_placement()
	placement.set_process(true)
	for i in range(30):
		await physics_frame
	return confirmed


func _walk(gate: String, frames: int) -> bool:
	Input.action_press("move_right")
	Input.action_press("move_up")
	var arrived := false
	for i in range(frames):
		if i % 48 == 20:
			Input.action_press("jump")
		elif i % 48 == 46:
			Input.action_release("jump")
		await physics_frame
		if player.is_on_floor() and ((gate == "span" and player.global_position.x > 2625 and player.global_position.y <= 444) \
			or (gate == "climb" and player.global_position.x > 4220 and player.global_position.y <= 144)
			or (gate == "flower" and level.call("_fragment_here") == level.call("_fragment", "flower"))):
			arrived = true
			break
	for action in ["move_right", "move_up", "jump"]:
		Input.action_release(action)
	return arrived


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	failures += int(not ok)
	print("  %s\t%s\t%s" % ["OK" if ok else "FAIL", what, detail])
