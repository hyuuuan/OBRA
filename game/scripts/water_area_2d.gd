class_name WaterArea2D
extends Area2D
## Future levels can add this area without changing fish or sailboat code.

## How many times its own weight the water pushes back with when a body is FULLY
## under. It has to be greater than 1 or nothing can ever float: at 1.0 a submerged
## body is exactly weightless and anything less than fully under still sinks, which is
## how a cork ended up resting on the riverbed. A body settles where lift matches
## weight -- at 2.4 that is a little under half submerged, which is what a boat sitting
## in water looks like.
@export var buoyancy: float = 2.4
@export var linear_drag: float = 2.8
@export var angular_drag: float = 1.8
@export var surface_size: Vector2 = Vector2(240.0, 40.0)
@export var water_color: Color = Color(0.13, 0.55, 0.76, 0.72)
@export var deep_color: Color = Color(0.055, 0.28, 0.46, 0.82)
@export var highlight_color: Color = Color(0.62, 0.9, 0.91, 0.9)

var _ripple_phase := 0.0


func _ready() -> void:
	add_to_group("water_medium")
	collision_layer = 0
	monitoring = true
	monitorable = true
	_ensure_collision()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()


func _process(delta: float) -> void:
	_ripple_phase = fmod(_ripple_phase + delta * 18.0, 32.0)
	queue_redraw()


## Water that does nothing is a blue rectangle. `buoyancy` and the two drag numbers
## were declared and then never read by anything, so a drawn boat did not float, a
## dropped anvil did not sink, and the only thing water meant was a flag saying you
## were standing in it.
##
## Lift scales with how deep a body is, which is what makes the surface a surface: a
## body barely in gets barely pushed, one fully under gets pushed hard enough to rise,
## and something heavy still loses. Drag is what stops all of that oscillating.
func _physics_process(_delta: float) -> void:
	var surface_y := global_position.y - surface_size.y * 0.5
	for node in get_overlapping_bodies():
		var body := node as RigidBody2D
		if body == null or body.freeze or body.has_meta(&"self_buoyant"):
			continue
		var depth := clampf((body.global_position.y - surface_y) / maxf(1.0, surface_size.y), 0.0, 1.0)
		if depth <= 0.0:
			continue
		var gravity_pull := float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
		body.apply_central_force(Vector2(0.0, -gravity_pull * buoyancy * depth * body.mass))
		body.apply_central_force(-body.linear_velocity * linear_drag * body.mass)
		body.apply_torque(-body.angular_velocity * angular_drag * body.mass)


func _draw() -> void:
	var rect := Rect2(-surface_size * 0.5, surface_size)
	draw_rect(rect, water_color)
	draw_rect(Rect2(rect.position + Vector2(0.0, surface_size.y * 0.58), Vector2(surface_size.x, surface_size.y * 0.42)), deep_color)
	var offset := floorf(_ripple_phase / 4.0) * 4.0
	var y := rect.position.y + 5.0
	var x := rect.position.x - 32.0 + offset
	while x < rect.end.x:
		draw_rect(Rect2(Vector2(x, y), Vector2(18.0, 3.0)), highlight_color)
		x += 48.0
	draw_line(Vector2(rect.position.x, rect.position.y), Vector2(rect.end.x, rect.position.y), highlight_color, 3.0, false)


func _on_body_entered(body: Node2D) -> void:
	var count := int(body.get_meta("water_overlap_count", 0))
	body.set_meta("water_overlap_count", count + 1)
	body.set_meta("water_area", self)


func _on_body_exited(body: Node2D) -> void:
	var count := maxi(0, int(body.get_meta("water_overlap_count", 0)) - 1)
	body.set_meta("water_overlap_count", count)
	if count == 0:
		body.remove_meta("water_area")


func _ensure_collision() -> void:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		collision = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		add_child(collision)
	var rectangle := collision.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		collision.shape = rectangle
	rectangle.size = surface_size
