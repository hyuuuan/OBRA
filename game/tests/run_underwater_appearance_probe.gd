extends SceneTree
## Fast, isolated render contract for water lighting. It loads no level, dialogue,
## backend, profile, or general test runner.
##   godot --headless --path game --script res://tests/run_underwater_appearance_probe.gd

var _failures := 0


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	RenderingServer.set_default_clear_color(Color(0.55, 0.77, 0.76))
	var world := Node2D.new()
	root.add_child(world)

	var water := WaterArea2D.new()
	water.position = Vector2(500.0, 280.0)
	water.surface_size = Vector2(500.0, 220.0)
	world.add_child(water)

	var dry := _wanderer(Vector2(150.0, 300.0), world)
	var wet := _wanderer(Vector2(390.0, 300.0), world)
	var vector_player := _vector_player(Vector2(590.0, 270.0), world)

	for frame in range(8):
		await physics_frame

	_expect_strength(dry.get_node("Figure"), 0.0, "dry apo")
	_expect_strength(wet.get_node("Figure"), 1.0, "wet apo")
	var skin := vector_player.get_node_or_null("DrawingSkin")
	_expect_strength(skin, 1.0, "wet vector morph")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/obra_underwater_appearance.png")

	# Leaving the pool must restore the original palette instead of leaving a material
	# tint stuck to the player for the rest of the level.
	wet.global_position = Vector2(150.0, 300.0)
	for frame in range(3):
		await physics_frame
	_expect_strength(wet.get_node("Figure"), 0.0, "apo after exiting")

	if _failures == 0:
		print("UNDERWATER_APPEARANCE_OK")
	quit(_failures)


func _wanderer(at: Vector2, world: Node2D) -> Node2D:
	var player := (load("res://creatures/wanderer.tscn") as PackedScene).instantiate() as Node2D
	world.add_child(player)
	player.global_position = at
	return player


func _vector_player(at: Vector2, world: Node2D) -> Node2D:
	# Build only the rendering seam used by a morph. Running the complete recognition and
	# rig decomposition here made this small visual check take longer than the feature.
	var fish := (load("res://creatures/fish.tscn") as PackedScene).instantiate() as Node2D
	world.add_child(fish)
	fish.global_position = at
	var skin := fish.get_node("DrawingSkin") as Node2D
	# Initialise the shared material before making the line, exactly as a water entry does.
	skin.call(&"set_underwater_appearance", false, 170.0, 390.0,
		Color(0.13, 0.55, 0.76), Color(0.055, 0.28, 0.46), Color(0.62, 0.9, 0.91))
	var body := RigidBody2D.new()
	body.freeze = true
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(120.0, 58.0)
	collision.shape = shape
	body.add_child(collision)
	var ink := skin.call(&"_new_ink_line", 9.0, 1) as Line2D
	ink.default_color = Color(0.92, 0.35, 0.15)
	ink.points = PackedVector2Array([
		Vector2(-55.0, 0.0), Vector2(-15.0, -24.0), Vector2(42.0, -18.0),
		Vector2(62.0, 0.0), Vector2(42.0, 18.0), Vector2(-15.0, 24.0),
		Vector2(-55.0, 0.0),
	])
	body.add_child(ink)
	skin.add_child(body)
	return fish


func _expect_strength(target: Node, expected: float, label: String) -> void:
	if target == null or not target.has_method(&"debug_underwater_strength"):
		push_error("%s has no underwater renderer" % label)
		_failures += 1
		return
	var actual := float(target.call(&"debug_underwater_strength"))
	if not is_equal_approx(actual, expected):
		push_error("%s strength %.2f, expected %.2f" % [label, actual, expected])
		_failures += 1
