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
## A morph is several physics bodies but one visible player. Count those bodies here so
## one leg leaving the pool does not clear the effect from the torso still underwater.
var _player_body_counts: Dictionary = {}


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
	_refresh_player_appearances()
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
	# AND THE WATER SAYS SO. The paddy is the first gate in the game and the thing the player
	# spends the most time standing in, and going into it did nothing visible whatsoever --
	# the apo simply became a character in a blue rectangle. Rings on the surface, scaled by
	# how hard the thing arrived. Only on the FIRST overlap: a body straddling two of this
	# area's shapes would otherwise splash twice.
	if count == 0:
		_splash_for(body)
	_track_player_body(body, 1)


## Rings where something broke the surface. Drawn at the WATERLINE rather than at the body,
## because the ripple belongs to the water and not to the thing that fell in it.
func _splash_for(body: Node2D) -> void:
	var speed := 0.0
	if body is CharacterBody2D:
		speed = absf((body as CharacterBody2D).velocity.y)
	elif body is RigidBody2D:
		speed = absf((body as RigidBody2D).linear_velocity.y)
	var surface_y := global_position.y - surface_size.y * 0.5
	SceneryPuff2D.burst(self, to_local(Vector2(body.global_position.x, surface_y)),
		SceneryPuff2D.Kind.SPLASH, clampf(0.3 + speed / 700.0, 0.3, 1.0))


func _on_body_exited(body: Node2D) -> void:
	var count := maxi(0, int(body.get_meta("water_overlap_count", 0)) - 1)
	body.set_meta("water_overlap_count", count)
	if count == 0:
		body.remove_meta("water_area")
	_track_player_body(body, -1)


func _exit_tree() -> void:
	for entry_value in _player_body_counts.values():
		var entry: Dictionary = entry_value
		var player := entry.get("player") as Node2D
		if player != null and is_instance_valid(player):
			_set_player_appearance(player, false)
	_player_body_counts.clear()


func _track_player_body(body: Node2D, amount: int) -> void:
	var player := _player_for(body)
	if player == null or not player.has_method("set_underwater_appearance"):
		return
	var player_id := player.get_instance_id()
	var entry: Dictionary = _player_body_counts.get(player_id, {"player": player, "count": 0})
	entry["count"] = maxi(0, int(entry["count"]) + amount)
	if int(entry["count"]) == 0:
		_player_body_counts.erase(player_id)
		_set_player_appearance(player, false)
		return
	_player_body_counts[player_id] = entry
	_set_player_appearance(player, true)


func _player_for(body: Node) -> Node2D:
	var cursor := body
	while cursor != null:
		if cursor.is_in_group(&"player_character"):
			return cursor as Node2D
		cursor = cursor.get_parent()
	return null


func _refresh_player_appearances() -> void:
	var stale: Array[int] = []
	for player_id in _player_body_counts:
		var entry: Dictionary = _player_body_counts[player_id]
		var player := entry.get("player") as Node2D
		if player == null or not is_instance_valid(player):
			stale.append(int(player_id))
			continue
		_set_player_appearance(player, true)
	for player_id in stale:
		_player_body_counts.erase(player_id)


func _set_player_appearance(player: Node2D, active: bool) -> void:
	player.call(&"set_underwater_appearance", get_instance_id(), active,
		global_position.y - surface_size.y * 0.5,
		global_position.y + surface_size.y * 0.5,
		water_color, deep_color, highlight_color)


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
