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
## 4. EVERY CHECKPOINT THE PLAYER CAN REACH HAS A MARK, and nothing decorative is standing
##    on one. CP0 was the only one of Payyo's six that had anything on screen at all, and
##    the level had planted a 94x58 fence sprite ten pixels from it -- which is what "the
##    checkpoints are just random fences" was.
## 5. A ROOM STILL FRAMES A PLAYER WHO IS A DRAWING. Every check here used to be run as the
##    apo, and a morph is a different shape of object: its rig bodies are top_level and its
##    scene root does not move with them, so `_room_holding_player` -- which reads that root
##    -- answered "nowhere" for every drawn creature. The camera snapped back to valley
##    framing a thousand units below the room and the room stopped drawing itself. Testing
##    only the wanderer is what let that ship.

const VIEW := Vector2(1600.0, 900.0)
const RosterFixtures = preload("res://tests/roster_fixtures.gd")

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
	_audit_checkpoint_marks()
	_audit_nothing_stands_on_a_checkpoint()
	_audit_every_checkpoint_is_marked()
	await _audit_the_chest_can_be_read()
	await _audit_placement(&"straw_rooms", Vector2(-120.0, 220.0))
	await _audit_placement(&"bale_interiors", Vector2(330.0, 210.0))
	await _audit_a_morph_stays_in_the_room(&"straw_rooms")
	await _audit_a_morph_stays_in_the_room(&"bale_interiors")
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


## Every planted mark is standing on something, rather than inside it or over it.
func _audit_checkpoint_marks() -> void:
	var space := (level as Node2D).get_world_2d().direct_space_state
	var planted := 0
	var buried: Array[String] = []
	for node in level.get_tree().get_nodes_in_group(&"checkpoint_areas"):
		var area := node as Area2D
		var flag := area.get_node_or_null(^"Checkpoint") as Node2D
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
	_check(planted > 0 and buried.is_empty(), "marks stand on the ground",
		"%d planted" % planted if buried.is_empty() else ", ".join(buried))


## Nothing decorative may stand where a checkpoint stands.
##
## CP0's flag is at x 990 and the level had `FenceA`, a 94x58 atlas sprite, at x 980 -- so
## the only visible checkpoint in Payyo was drawn inside a picture of a fence. The flag is
## the smaller of the two by a wide margin, so what the player saw was the fence, and what
## they concluded was that the fences are the checkpoints.
func _audit_nothing_stands_on_a_checkpoint() -> void:
	var decor := level.get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/Decor") as Node2D
	if decor == null:
		return
	var clashes: Array[String] = []
	for flag in level.get_tree().get_nodes_in_group(&"checkpoint_areas"):
		var mark := (flag as Node).get_node_or_null(^"Checkpoint") as Node2D
		if mark == null:
			continue
		for child in decor.get_children():
			var sprite := child as Sprite2D
			if sprite == null or sprite.texture == null:
				continue
			var half := sprite.texture.get_size() * sprite.scale * 0.5
			var box := Rect2(sprite.global_position - half, half * 2.0)
			# The flag is about 48 wide and a pole tall; a box round its foot is enough to
			# catch anything drawn over it.
			if box.intersects(Rect2(mark.global_position - Vector2(30.0, 100.0),
					Vector2(60.0, 104.0))):
				clashes.append("%s stands on %s" % [sprite.name, mark.get_parent().name])
	_check(clashes.is_empty(), "no decor stands on a checkpoint",
		"clear" if clashes.is_empty() else ", ".join(clashes))


## Every checkpoint that can actually be reached carries a mark.
##
## Payyo declares six. Only CP0 was a node in the scene; CP1, CP2 and CP3 are written the
## instant a route is committed and had no visual of any kind, so three of the four
## checkpoints a player actually reaches happened in total silence.
func _audit_every_checkpoint_is_marked() -> void:
	var director = level.get("director")
	if director == null:
		return
	var marked: Array[String] = []
	var missing: Array[String] = []
	for node in level.get_tree().get_nodes_in_group(&"checkpoint_areas"):
		if (node as Node).get_node_or_null(^"Checkpoint") != null:
			marked.append(String((node as Node).get("checkpoint_id")))
	for node in level.get_tree().get_nodes_in_group(&"level_obstacles"):
		var id := String((node as Node).get("obstacle_id"))
		var declares := String(director.obstacle(id).get("checkpoint_on_commit", ""))
		if declares.is_empty():
			continue
		if (node as Node).get_node_or_null(^"Checkpoint") != null:
			marked.append(declares)
		else:
			missing.append(declares)
	_check(missing.is_empty() and marked.size() >= 4, "every checkpoint has a mark",
		"marked: %s" % ", ".join(marked) if missing.is_empty()
			else "unmarked: %s" % ", ".join(missing))


## THE CHEST IN THE STRAW ROOM ANSWERS THE INTERACT KEY.
##
## It did not, and neither did the board beside it: `Baul2D` planted its signpost with no
## hook, and `GameLevel._readable_sign` skips any board whose hook has not already played --
## so the board could never be offered, in any run, ever. The one object in the heap's inside
## that the player is meant to walk up to and think about was a picture of a chest with a
## picture of a sign next to it, and pressing E at either did nothing at all. That is most of
## "I can't interact with the sign, as well as the chest".
func _audit_the_chest_can_be_read() -> void:
	level.call("_uncover_the_baul")
	for _frame in range(8):
		await physics_frame
	var chest := level.get_tree().get_first_node_in_group(&"baul") as Node2D
	if chest == null:
		_check(false, "the chest can be read", "no baul in the level")
		return
	var board: Node2D = null
	for node in level.get_tree().get_nodes_in_group(&"signposts"):
		if (node as Node).get_parent() == chest:
			board = node as Node2D
			break
	if board == null:
		_check(false, "the chest can be read", "the chest carries no board")
		return
	# Standing at it, the level must offer the board -- which is the whole of the fix: a
	# hook it can have heard, and a player inside its reading range.
	var player := level.get("player") as Node2D
	player.global_position = board.global_position
	for _frame in range(6):
		await physics_frame
	var readable = level.call("_readable_sign")
	_check(readable == board, "the chest can be read",
		"offered %s" % ("the chest's board" if readable == board else str(readable)))


## A DRAWN CREATURE IS STILL IN THE ROOM IT WAS DRAWN IN.
##
## This is the check that would have caught the whole class of "drawing something inside a
## small world breaks the game". A morph's rig bodies are `top_level`, so `apply_morph_state`
## moving them left the scene root behind at the level spawn point forever -- and three
## room-critical predicates read that root. The room decided the player had left, hid itself,
## released the camera back to valley framing (which clamps a thousand units below the room)
## and cleared the box a placement may not leave.
func _audit_a_morph_stays_in_the_room(group: StringName) -> void:
	var room := level.get_tree().get_first_node_in_group(group) as Node2D
	var player := level.get("player") as Node2D
	if room == null or player == null:
		_check(false, "%s frames a morph" % group, "no player or no room")
		return
	player.global_position = Vector2(room.call("entry_point"))
	for _frame in range(20):
		await physics_frame

	var drawing := Image.create_empty(400, 400, false, Image.FORMAT_RGBA8)
	drawing.fill(Color.WHITE)
	var made: bool = level.call("_spawn_or_replace", "frog", "Frog", drawing,
		RosterFixtures.for_rig("hopper"))
	if not made:
		_check(false, "%s frames a morph" % group, "the rig would not build")
		return
	for _frame in range(40):
		await physics_frame

	var morph := level.get("player") as Node2D
	var holding = level.call("_room_holding_player")
	var bounds := Rect2(room.call("bounds")).grow(90.0)
	_check(holding == room and bool(room.visible)
			and bounds.has_point(morph.global_position),
		"%s frames a morph" % group,
		"room=%s visible=%s at %s" % [
			"held" if holding == room else "lost", room.visible, morph.global_position])

	# And back to the apo, so the next case starts from the same place this one did.
	level.call("_revert_to_base_form")
	for _frame in range(20):
		await physics_frame


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
