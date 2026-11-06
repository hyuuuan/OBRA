extends SceneTree
## A FLIER STAYS IN THE PAINTING.
##   godot --headless --path game --script res://tests/run_level1_flight_ceiling_probe.gd
##
## Kent: "when i try to fly up above in level 1, i get to go to the houses, hay, which is very
## wrong and weird". Both insides are parked in the sky over the valley -- the heap at y -900,
## Ang Bale at y -1180 -- and the only thing between the terrace and them was air. The camera
## stops at the top of the painted sky, so a bird kept climbing off the top of the screen until
## `_room_holding_player` read its position as "inside" and the camera jumped into the room.
##
## Flown with real flaps, under each room, because a test that writes a position would prove the
## ceiling exists and not that a flier meets it.

const CHECKS := 13
## Under the heap, under Ang Bale, and the open sky between them.
##
## ⚠ THE SECOND IS ON THE OPEN OVERLOOK, STILL UNDER THE ROOM, AND NOT UNDER THE HOUSE. This stood
## at x 4640 until a third of its runs came back with a bird at y -1977: that is inside the sealed
## pocket between Ang Bale's posts, under its deck, and a rig built overlapping those bodies blows
## apart and throws itself anywhere, which no ceiling can stop. It looked exactly like the lid
## leaking. Nobody can stand there: walking in, the first post stops her at x 4509.
const COLUMNS := [2580.0, 4440.0, 3400.0]
## The top of the Overlook, and where a test may ask her to stand on it.
const OVERLOOK_Y := 80.0
const OVERLOOK_FROM_X := 4340.0
const FLAP_SECONDS := 9.0

var level: Node2D
var failures := 0
var checked := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if not ok:
		failures += 1
	print("  %s  %-54s %s" % ["OK  " if ok else "FAIL", what, detail])


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _run() -> void:
	print("\n===== A FLIER STAYS IN THE PAINTING =====")
	level = (load("res://game_level.tscn") as PackedScene).instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.2)
	(level.get("tutorial") as TutorialDirector).set_enabled(false)
	var rooms := get_nodes_in_group(&"interiors")
	_check(rooms.size() >= 2, "the level has its two parked rooms", "%d rooms" % rooms.size())

	for column: float in COLUMNS:
		await _fly_up_at(column)

	await _the_rooms_still_work()

	print("OBRA_FLIGHT_CEILING_%s" % ("OK" if failures == 0 and checked == CHECKS
		else "FAILED=%d checked=%d of %d" % [failures, checked, CHECKS]))
	quit(1 if failures > 0 or checked != CHECKS else 0)


## Become a bird at the top of the terraces and flap for as long as a drawing lasts.
func _fly_up_at(column: float) -> void:
	level.call("_revert_to_base_form")
	await _wait(0.3)
	var ground := 240.0 if column < OVERLOOK_FROM_X else OVERLOOK_Y
	var apo := level.get("player") as Node2D
	apo.global_position = Vector2(column, ground - 60.0)
	await _wait(0.2)
	if column >= OVERLOOK_FROM_X:
		# The premise, and a harness fault if it fails: she came down onto the ground, not out of
		# something solid. Let her land before asking.
		await _wait(0.5)
		_check(absf(apo.global_position.y - OVERLOOK_Y) < 4.0,
			"at x %.0f she is standing on open ground" % column, "y %.1f" % apo.global_position.y)
	var drawing := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	drawing.fill(Color.WHITE)
	var strokes: Array = preload("res://tests/drawn_like_people_fixtures.gd")._bird_side()
	level.call("_on_drawing_ready", "bird", "Bird", drawing, {}, strokes, 0.0)
	await _wait(0.6)
	var flier := level.get("player") as Node2D
	var became := String((flier.get("entity_metadata") as Dictionary).get("id", "")) \
		if flier != null and flier.get("entity_metadata") is Dictionary else "not a creature"
	_check(became == "bird", "she is a bird at x %.0f" % column, became)

	var highest := INF
	var entered := false
	var clock := 0.0
	var sky_top := float(level.get("environment").get("camera").get("sky_top_y"))
	while clock < FLAP_SECONDS:
		Input.action_press(&"jump")
		await physics_frame
		await physics_frame
		Input.action_release(&"jump")
		for _frame in range(12):
			await physics_frame
		clock += 14.0 / 60.0
		var body := level.get("player") as Node2D
		if body == null or not is_instance_valid(body):
			break
		highest = minf(highest, body.global_position.y)
		if level.call("_room_holding_player") != null:
			entered = true
	_check(not entered, "at x %.0f no flap takes her into a room" % column,
		"highest y %.0f" % highest if not entered else "ENTERED A ROOM, highest y %.0f" % highest)
	# Asked of the painted sky, not of where the camera is: a camera that has jumped into a room
	# has a frame a thousand units higher, and she would pass this from inside the hay.
	_check(highest >= sky_top, "at x %.0f she stays under the painted sky" % column,
		"highest y %.0f, sky ends at %.0f" % [highest, sky_top])


## The ceiling is a lid on the valley, and the insides are above it: nothing about walking into
## them, or standing in them, may have changed.
func _the_rooms_still_work() -> void:
	level.call("_revert_to_base_form")
	await _wait(0.3)
	var apo := level.get("player") as Node2D
	for node in get_nodes_in_group(&"interiors"):
		var room := node as Node2D
		apo.global_position = room.global_position + Vector2(0.0, -30.0)
		await _wait(0.4)
		var here := level.call("_room_holding_player") as Node2D
		var stands := apo.global_position.y <= room.global_position.y + 60.0
		_check(here == room and stands, "she can still stand in %s" % room.name,
			"at %s, room %s" % [apo.global_position, here.name if here != null else "none"])
