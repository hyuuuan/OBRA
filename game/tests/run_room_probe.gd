extends SceneTree
## The two insides, and whether they hold what is put in them.
##
##	 godot --headless --path game --script res://tests/run_room_probe.gd
##
## Three things, and every one of them was reported by a player before it was caught here.
##
## 1. A DRAWING PLACED IN A ROOM STAYS IN THE ROOM. The reach circle is 360 units wide,
##    which is arm's length in a valley; a room's floor is a few hundred units long and is
##    parked in the empty sky two thousand units above the terraces. Aiming past the boards
##    put the object down in mid-air and confirming dropped it out of the room and onto the
##    valley floor -- "it gets thrown off the map", exactly.
## 2. THE PICTURE COVERS THE SCREEN. Ang Bale's inside is one 557x314 painting seen at a
##    fixed zoom. If a screenful is bigger than the painting on either axis, the room is a
##    postcard in the middle of a black screen.
## 3. A CHECKPOINT'S FLAG STANDS ON THE GROUND. It used to be planted at the foot of its
##    trigger box, which at CP0 is sixty units under the terrace -- so the one thing a
##    checkpoint does to say it happened was buried.

const VIEW := Vector2(1600.0, 900.0)

var results: Array[String] = []
var failures := 0
var level: Node


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	results.append("  %s  %-34s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _run() -> void:
	await _open()
	_audit_room_fills_the_screen()
	_audit_the_canvas_is_a_walk_in()
	_audit_checkpoint_flags()
	await _audit_placement(&"straw_rooms", Vector2(-120.0, 220.0))
	await _audit_placement(&"bale_interiors", Vector2(330.0, 210.0))
	_close()

	print("\n===== ROOMS =====")
	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_ROOM_PROBE_OK")
		quit(0)
	else:
		print("OBRA_ROOM_PROBE_FAILED=%d" % failures)
		quit(1)


func _open() -> void:
	var packed := load("res://game_level.tscn") as PackedScene
	level = packed.instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	# A beat stops the tree until somebody turns the page, and nobody is here to.
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(30):
		await physics_frame


func _close() -> void:
	if level != null and is_instance_valid(level):
		level.queue_free()
	level = null


## A room seen at its own zoom must be at least a screenful in both directions, or the void
## it is standing in is on screen around it.
func _audit_room_fills_the_screen() -> void:
	var room := level.get_tree().get_first_node_in_group(&"bale_interiors") as Node2D
	if room == null:
		_check(false, "the bale has an inside", "no node in group bale_interiors")
		return
	var zoom := float(room.call("how_far_in"))
	var seen := VIEW / zoom
	var picture := Rect2(room.call("camera_rect")).size
	_check(picture.x >= seen.x and picture.y >= seen.y, "the room fills the screen",
		"%.0fx%.0f of picture against %.0fx%.0f of view at zoom %.2f"
			% [picture.x, picture.y, seen.x, seen.y, zoom])


## The canvas must not be collected by arriving.
##
## The apo is put down at `entry_point` and `_sweep_for_taker` hands over anything they are
## already standing on -- which is deliberate, because a teleport generates no `body_entered`.
## The cost of that is that moving the canvas a little way toward the doorway makes it free:
## the player is handed the thing the whole node is for before they have looked at the room.
func _audit_the_canvas_is_a_walk_in() -> void:
	var room := level.get_tree().get_first_node_in_group(&"bale_interiors") as Node2D
	if room == null:
		return
	var area := room.get_node_or_null(^"Painting") as Area2D
	var shape := area.get_node_or_null(^"CollisionShape2D") as CollisionShape2D \
		if area != null else null
	if shape == null and area != null:
		for child in area.get_children():
			shape = child as CollisionShape2D
			if shape != null:
				break
	if shape == null or not (shape.shape is RectangleShape2D):
		_check(false, "the canvas is a walk in", "no rectangular trigger to measure")
		return
	var box := (shape.shape as RectangleShape2D).size
	var rect := Rect2(shape.global_position - box * 0.5, box)
	var entry := Vector2(room.call("entry_point"))
	# A body's half-width around where they land, and a little either side of that.
	var clear := not rect.grow(28.0).has_point(entry)
	_check(clear, "the canvas is a walk in",
		"they land at %.0f, the trigger runs %.0f..%.0f"
			% [entry.x, rect.position.x, rect.end.x])


## Every planted flag is standing on something, rather than inside it or over it.
func _audit_checkpoint_flags() -> void:
	var space := (level as Node2D).get_world_2d().direct_space_state
	var planted := 0
	var buried: Array[String] = []
	for node in level.get_tree().get_nodes_in_group(&"checkpoint_areas"):
		var area := node as Area2D
		var flag := area.get_node_or_null(^"Flag") as Node2D
		if flag == null:
			continue
		planted += 1
		# A short ray from just above the foot of the pole. It has to hit ground within a
		# stride, and the foot itself must not already be inside it.
		var query := PhysicsRayQueryParameters2D.create(
			flag.global_position - Vector2(0.0, 24.0),
			flag.global_position + Vector2(0.0, 24.0))
		query.collision_mask = 1
		query.exclude = [area.get_rid()]
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			buried.append("%s stands on nothing at %s"
				% [String(area.get("checkpoint_id")), flag.global_position])
			continue
		var surface := Vector2(hit["position"]).y
		if absf(surface - flag.global_position.y) > 2.0:
			buried.append("%s is %.0f off the ground"
				% [String(area.get("checkpoint_id")), flag.global_position.y - surface])
	_check(planted > 0 and buried.is_empty(), "flags stand on the ground",
		"%d planted" % planted if buried.is_empty() else ", ".join(buried))


## Put the player in a room, aim a drawing well outside it, and confirm. The object has to
## still be in the room a few seconds later.
func _audit_placement(group: StringName, aim: Vector2) -> void:
	var player := level.get("player") as Node2D
	var room := level.get_tree().get_first_node_in_group(group) as Node2D
	if player == null or room == null:
		_check(false, "%s takes a placement" % group, "no player or no room")
		return
	player.global_position = Vector2(room.call("entry_point"))
	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO
	for _frame in range(30):
		await physics_frame

	var registry: Node = level.get("registry")
	var placement := level.get_node("PlacementController") as PlacementController
	var item := DrawnItemData.new()
	item.entity_id = "square"
	item.display_name = "Square"
	item.ink_committed = true
	item.entity_metadata = registry.call("get_entity", "square")
	if not placement.begin_placement(item, player, -1):
		_check(false, "%s takes a placement" % group, "placement would not start")
		return
	placement.update_target(player.global_position + aim)
	var preview := placement.get("_preview") as Node2D
	var placed_at := preview.global_position
	if not placement.confirm_placement():
		_check(false, "%s takes a placement" % group, "the aim was refused outright")
		return
	for _frame in range(150):
		await physics_frame
	var bounds := Rect2(room.call("bounds"))
	var landed := preview.global_position if is_instance_valid(preview) else Vector2.INF
	_check(bounds.grow(90.0).has_point(landed), "%s keeps what is put in it" % group,
		"aimed %s, set down at %s, ended at %s" % [aim, placed_at, landed])
	if is_instance_valid(preview):
		preview.queue_free()
	await process_frame
