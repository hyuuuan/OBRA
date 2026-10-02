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
	print("LOCOMOTION_PROBE failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)


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
