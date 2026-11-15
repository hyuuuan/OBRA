extends SceneTree
## A drawing set down in a room stands where it was aimed, and never in the way out.
##
##   godot --headless --path game --script res://tests/run_room_placement_probe.gd
##
## Kent: "how you place objects inside the haybale, in cases where you place it at the very
## bottom of the platform, it places it at the door at the bottom which is very bad". Two things
## did that, and this holds both, in the heap, in Ang Bale and in Piyesta's church:
##
## 1. THE DRAWING STANDS WHERE ITS GHOST STOOD. On its first physics step a confirmed drawing
##    was swept from the world's origin to the spot it was set down (see
##    PhysicsShapeObject._unfrozen_where_it_stands). Every room is parked up and to the right
##    of the origin, so the sweep ran down through the room's own floor, and the floor threw the
##    drawing up and back toward the doorway: 30 to 60 px out of its ghost in the heap, onto the
##    apo's head beside the door, or into the doorway.
## 2. NOTHING IS SET DOWN IN THE DOORWAY. It is the only way out, and a drawing standing in it
##    is one she has to climb over to leave (LevelBase._placement_rect_for).
##
## Played the real way: the pointer moved to the spot and the left button clicked, through the
## viewport. ⚠ A confirm called straight after a physics frame never showed the sweep, so the
## older room checks, which confirm from a script, passed on it.

const CHECKS := 9

var level: Node
var results: Array[String] = []
var failures := 0
var checked := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	results.append("  %s  %-46s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _run() -> void:
	await _open("res://game_level.tscn")
	await _audit(level.get_tree().get_first_node_in_group(&"straw_rooms") as Node2D, "the heap")
	await _audit(level.get_tree().get_first_node_in_group(&"bale_interiors") as Node2D, "Ang Bale")
	await _close()
	await _open("res://level_2.tscn")
	await _audit(level.get("church") as Node2D, "the church")
	await _close()

	print("\n===== A DRAWING SET DOWN IN A ROOM =====")
	for line in results:
		print(line)
	if checked != CHECKS:
		failures += 1
		print("  FAIL  ran %d of %d checks" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_ROOM_PLACEMENT_OK")
		quit(0)
	else:
		print("OBRA_ROOM_PLACEMENT_FAILED=%d" % failures)
		quit(1)


func _open(path: String) -> void:
	level = (load(path) as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(10)
	# The opening cards pause the tree, and nobody is here to turn them.
	var tutorial := level.get("tutorial") as TutorialDirector
	if tutorial != null:
		tutorial.skip_rest()
	await _frames(30)


func _close() -> void:
	if level != null and is_instance_valid(level):
		level.queue_free()
	level = null
	await _frames(2)


func _audit(room: Node2D, label: String) -> void:
	if room == null:
		_check(false, "%s is there" % label, "no room")
		return
	var floor_y := room.global_position.y
	var box := Rect2(room.call("bounds"))
	var door := Rect2(room.call("exit_rect"))
	door.position += room.global_position
	var entry := Vector2(room.call("entry_point"))

	# The bottom of the room's floor, well clear of the doorway: "the very bottom of the platform".
	var low := Vector2(entry.x + 160.0, box.end.y - 12.0)
	var placed := await _place_at(entry, low)
	var landed: Rect2 = placed.get("landed", Rect2())
	var ghost: Rect2 = placed.get("ghost", Rect2())
	# What the player is shown: the ghost, standing on the boards under where they pointed.
	_check(placed.has("ghost") and absf(ghost.get_center().x - low.x) <= 1.0
			and absf(ghost.end.y - floor_y) <= 2.0,
		"%s: a low aim's ghost is on the floor" % label,
		"centre x %.1f under an aim at %.1f, bottom %.1f on a floor at %.1f"
			% [ghost.get_center().x, low.x, ghost.end.y, floor_y])
	# And what they get: the drawing, standing where its ghost stood.
	_check(placed.has("landed") and landed.position.distance_to(ghost.position) <= 1.5,
		"%s: it stands where its ghost stood" % label,
		"ghost %s, stood at %s" % [ghost.position.round(), landed.position.round()])

	# And at the foot of the doorway itself, from further in: standing at the way in, the apo's
	# own body holds a drawing clear of the doorway (PlacementController._clear_of_the_actor) and
	# says nothing about whether the room would have.
	placed = await _place_at(entry + Vector2(200.0, 0.0),
		Vector2(door.get_center().x, floor_y - 20.0))
	landed = placed.get("landed", Rect2())
	_check(placed.has("landed") and (landed.position.x >= door.end.x or landed.end.x <= door.position.x)
			and absf(landed.end.y - floor_y) <= 2.0,
		"%s: not in the doorway" % label,
		"stood %.0f..%.0f, the doorway %.0f..%.0f" % [landed.position.x, landed.end.x,
			door.position.x, door.end.x])


## Stand at `stand`, point at `aim`, click, and wait for the drawing to come to rest. The
## ghost's box and where it ended up, or nothing if it was refused.
func _place_at(stand: Vector2, aim: Vector2) -> Dictionary:
	var player := level.get("player") as Node2D
	player.global_position = stand
	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO
	await _frames(60)
	var registry: Node = level.get("registry")
	var placement := level.get_node("PlacementController") as PlacementController
	var item := DrawnItemData.new()
	item.entity_id = "square"
	item.display_name = "Square"
	item.ink_committed = true
	item.placement_paid = true
	item.entity_metadata = registry.call("get_entity", "square")
	item.strokes = [{"points": PackedVector2Array([Vector2(0, 0), Vector2(80, 0), Vector2(80, 80),
		Vector2(0, 80), Vector2(0, 0)]), "width": 6.0, "color": Color.BLACK}]
	if not placement.begin_placement(item, player, -1):
		return {}
	# ⚠ AIMED BY HAND, as `_process` aims it at the pointer every frame. Headless there is no
	# pointer: the dummy display server answers every read of the mouse with its own corner of a
	# 64-pixel window, whatever was pushed, so the ghost would follow that instead.
	placement.set_process(false)
	for _frame in range(10):
		placement.update_target(aim)
		await process_frame
	var preview := placement.get("_preview") as PhysicsShapeObject
	var ghost := PlacementController.body_bounds(preview)
	# The click itself is a real one, through the input queue: it lands where a player's does,
	# between one frame and the next.
	var pointer := root.get_final_transform() * (root.get_canvas_transform() * aim)
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = pointer
		click.global_position = pointer
		Input.parse_input_event(click)
		await process_frame
	placement.set_process(true)
	if placement.is_placing():
		placement.cancel_placement()
		return {}
	# Until it has stopped moving: a drawing thrown across the room is still moving at 20 frames.
	var still := 0
	for _frame in range(240):
		await physics_frame
		still = still + 1 if preview.linear_velocity.length() < 1.0 else 0
		if still >= 30:
			break
	var landed := PlacementController.body_bounds(preview)
	preview.queue_free()
	await process_frame
	return {"ghost": ghost, "landed": landed}


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
