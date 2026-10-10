extends SceneTree
## Real input and sprite registration for the shared player, followed by every shipped
## level's spawn path. Run alone: all --script probes share an isolated test profile.
## godot --headless --path game --script res://tests/run_locomotion_probe.gd

const PLAYER := preload("res://creatures/wanderer.tscn")
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2000, 40)
	shape.shape = rectangle
	floor_body.position = Vector2(700, 320)
	floor_body.add_child(shape)
	world.add_child(floor_body)
	var player := PLAYER.instantiate() as CharacterBody2D
	player.position = Vector2(500, 300)
	world.add_child(player)
	await _frames(12)
	_expect(player.is_on_floor(), "harness: player must settle on the test floor")
	var figure := player.get_node("Figure") as Node2D
	var body := figure.get_node("Body") as Sprite2D
	_expect(figure.get("pose") == &"idle", "stationary player is idle")

	# Low action strength exercises a sustained walk; normal keyboard input accelerates
	# through the same state into running. Both go through the real controller.
	Input.action_press(&"move_right", 0.4)
	await _frames(12)
	_expect(figure.get("pose") == &"walk", "slow movement selects walk")
	var walking_region := body.region_rect
	await _frames(12)
	_expect(body.region_rect != walking_region, "walking advances actual atlas frames")
	Input.action_press(&"move_right")
	await _frames(15)
	_expect(figure.get("pose") == &"run", "full movement selects run")
	var running_region := body.region_rect
	paused = true
	await create_timer(0.08, true).timeout
	_expect(body.region_rect == running_region, "pause freezes animation")
	paused = false
	await _frames(12)
	_expect(body.region_rect != running_region, "running advances actual atlas frames")
	_expect(figure.scale.x > 0.0, "right input faces right")
	Input.action_release(&"move_right")
	Input.action_press(&"move_left")
	await _frames(20)
	_expect(player.velocity.x < 0.0 and figure.scale.x < 0.0, "left input moves and mirrors left")
	Input.action_press(&"jump")
	await _frames(4)
	_expect(not player.is_on_floor() and figure.get("pose") == &"air",
		"running jump uses the jump pose, not the ground cycle")
	_expect(not body.region_enabled and body.scale == Vector2.ONE,
		"leaving the atlas restores the legacy pose scale and region")
	Input.action_release(&"jump")
	Input.action_release(&"move_left")
	await _frames(70)
	_expect(player.is_on_floor() and figure.get("pose") == &"idle", "landing and stopping restores idle")
	var stopped_phase := float(player.call("stride_phase"))
	await _frames(12)
	_expect(is_equal_approx(float(player.call("stride_phase")), stopped_phase), "idle does not keep stepping")
	var wall := StaticBody2D.new()
	var wall_shape := CollisionShape2D.new()
	var wall_rectangle := RectangleShape2D.new()
	wall_rectangle.size = Vector2(30, 160)
	wall_shape.shape = wall_rectangle
	wall.add_child(wall_shape)
	wall.position = Vector2(player.position.x + 110.0, 230.0)
	world.add_child(wall)
	Input.action_press(&"move_right")
	await _frames(45)
	_expect(player.is_on_wall(), "harness: movement reaches the wall")
	_expect(figure.get("pose") == &"idle", "pushing a wall does not run in place")
	Input.action_release(&"move_right")
	player.set_physics_process(false)
	_check_registration(figure, body)
	world.queue_free()
	await process_frame

	# Read shipped paths, rather than assuming only Payyo and Piyesta exist.
	var levels: Array = JSON.parse_string(FileAccess.get_file_as_string("res://config/levels.json"))
	for entry: Dictionary in levels:
		var path := str(entry.get("scene_path", ""))
		if path.is_empty():
			continue
		var level := (load(path) as PackedScene).instantiate()
		var backend := level.get_node_or_null("BackendSupervisor")
		if backend != null:
			backend.set("auto_start_backend", false)
		root.add_child(level)
		var spawned := level.get("player") as Node
		_expect(spawned != null, "%s spawns a player" % path)
		if spawned != null:
			var spawned_figure := spawned.get_node("Figure")
			spawned_figure.set("pose", &"run")
			spawned_figure.call("refresh")
			var spawned_body := spawned_figure.get_node("Body") as Sprite2D
			_expect(spawned_body.texture.resource_path.ends_with("apo_locomotion.png"),
				"%s uses the replacement atlas" % path)
		level.queue_free()
		await process_frame
		paused = false
	await _check_water()
	print("LOCOMOTION_PROBE failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


## IN DEEP WATER SHE SWIMS OR KEEPS AFLOAT; SHE DOES NOT WALK. Kent: "apo can walk in the
## water". The water was left out of the jump-pose test, so it fell through to the speed check:
## swimming Dagat's crossing she was drawn upright and striding along the surface, and sinking in
## Payyo's lake she walked on the way down. A real pool, a real WaterArea2D, real input.
func _check_water() -> void:
	var world := Node2D.new()
	root.add_child(world)
	_block(world, Vector2(700.0, 900.0), Vector2(2000.0, 40.0))
	# A ledge under the water at the far end: a shallow wade, feet on a bottom.
	_block(world, Vector2(1150.0, 380.0), Vector2(300.0, 40.0))
	var pool := WaterArea2D.new()
	pool.surface_size = Vector2(1200.0, 500.0)
	pool.position = Vector2(700.0, 550.0)
	var water_shape := CollisionShape2D.new()
	var water_rect := RectangleShape2D.new()
	water_rect.size = pool.surface_size
	water_shape.shape = water_rect
	pool.add_child(water_shape)
	world.add_child(pool)
	var player := PLAYER.instantiate() as Wanderer
	player.position = Vector2(400.0, 330.0)
	world.add_child(player)
	var figure := player.get_node("Figure") as Node2D
	var body := figure.get_node("Body") as Sprite2D
	await _frames(6)
	_expect(player.is_in_water(), "harness: the apo is in the pool")

	# Payyo: she cannot swim. Going under with a direction held, she struggles -- not a walk.
	Input.action_press(&"move_right")
	await _frames(20)
	_expect(not player.is_on_floor() and figure.get("pose") == &"tread",
		"sinking where she cannot swim is not a walk (was %s)" % figure.get("pose"))
	Input.action_release(&"move_right")

	# Dagat: she can. A direction held is a stroke, laid flat, head first either way.
	player.can_swim = true
	player.global_position = Vector2(400.0, 330.0)
	player.velocity = Vector2.ZERO
	Input.action_press(&"move_right")
	await _frames(20)
	_expect(figure.get("pose") == &"swim" and absf(body.rotation) > 1.0 and figure.scale.x > 0.0,
		"swimming right is a stroke, laid flat (pose %s, turned %.2f)" % [figure.get("pose"), body.rotation])
	Input.action_release(&"move_right")
	Input.action_press(&"move_left")
	await _frames(20)
	_expect(figure.get("pose") == &"swim" and figure.scale.x < 0.0,
		"and swimming left is the same stroke, mirrored")
	Input.action_release(&"move_left")
	# Nothing held: afloat, upright, the surface at her chest rather than her ankles -- and AT
	# the surface, not bobbing clear of it: rising until the water let go of her, she spent a frame
	# in five entirely above the sea, drawn mid-jump.
	var clear_of_it := 0
	for _frame in range(90):
		await physics_frame
		if not player.is_in_water() or figure.get("pose") == &"air":
			clear_of_it += 1
	_expect(clear_of_it == 0, "afloat she stays in the water (%d of 90 frames out of it)" % clear_of_it)
	_expect(figure.get("pose") == &"tread" and absf(body.rotation) < 0.01 and body.position.y > 0.0,
		"afloat with nothing held she treads water, drawn down (pose %s, %.0f)" % [
			figure.get("pose"), body.position.y])

	# A shallow wade, feet on the ledge, where she cannot swim: that IS a walk.
	player.can_swim = false
	player.global_position = Vector2(1100.0, 355.0)
	player.velocity = Vector2.ZERO
	await _frames(10)
	Input.action_press(&"move_right")
	await _frames(10)
	_expect(player.is_in_water() and player.is_on_floor()
			and figure.get("pose") in [&"walk", &"run"],
		"wading with her feet on the bottom is still a walk (pose %s)" % figure.get("pose"))
	Input.action_release(&"move_right")
	# Out of the water, the swimmer stands up: nothing laid flat on dry land.
	player.global_position = Vector2(200.0, 860.0)
	player.velocity = Vector2.ZERO
	pool.queue_free()
	await _frames(20)
	_expect(not player.is_in_water() and absf(body.rotation) < 0.01 and body.position == Vector2.ZERO,
		"out of the water she stands up again")
	world.queue_free()
	await process_frame


func _block(world: Node2D, at: Vector2, size: Vector2) -> void:
	var block := StaticBody2D.new()
	var block_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	block_shape.shape = rect
	block.position = at
	block.add_child(block_shape)
	world.add_child(block)


func _check_registration(figure: Node2D, body: Sprite2D) -> void:
	for pose: StringName in [&"walk", &"run"]:
		var distinct: Array[Rect2] = []
		for frame in range(6):
			figure.set("pose", pose)
			figure.set("stride", (float(frame) + 0.01) / 6.0)
			figure.call("refresh")
			var rect := Rect2i(body.region_rect)
			var image := body.texture.get_image().get_region(rect)
			# Measure visible pixels, not the transparent padding or the declared anchor.
			var lowest := -1
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					if image.get_pixel(x, y).a > 0.5:
						lowest = maxi(lowest, y)
			var feet_y := (float(lowest + 1) + body.offset.y) * body.scale.y
			if pose == &"walk" or frame % 3 != 2:
				_expect(absf(feet_y) < 0.6, "%s frame %d has grounded feet (%.2f)" % [pose, frame, feet_y])
			else:
				_expect(feet_y < -3.0, "run frame %d retains airborne feet" % frame)
			distinct.append(body.region_rect)
		_expect(distinct[0] != distinct[3], "%s has separate opposite steps" % pose)
	# Atlas -> five-frame turnaround -> idle used to be prone to stale divisions.
	for pose: StringName in [&"climb", &"idle", &"walk", &"air", &"run"]:
		figure.set("pose", pose)
		figure.call("refresh")
		_expect(body.texture != null, "%s transition has a texture" % pose)


func _frames(count: int) -> void:
	for frame in range(count):
		await physics_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
