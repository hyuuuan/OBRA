extends SceneTree
## Photographs the house: the wall of paintings, the prompt when the apo stands at one, and
## the brush in its case at the end of the hall.
##
## Needs a REAL viewport -- no --headless -- like every other visual runner here. Four
## defects in this project passed green suites and were caught only by looking at frames.
##
## THE WALL IS SHOT BRUSHLESS, ON PURPOSE. That is the state a player opens this game in
## now, and it is the one where a picture has to refuse in words -- the prompt under a
## painting reads NEEDS LOLA'S BRUSH before the case is opened, and none of the five frames
## along the wall would show that if the runner handed itself a brush first.
##
## THE PROFILE FILE IS PUT BACK. The brushless state is arranged by setting the flag on the
## loaded dictionary, which touches nothing on disk -- but the take photographed below is
## the real one and it commits, so by the last frame user://profile.json genuinely claims a
## brush. Photographing this room must not hand whoever ran it one they did not walk over
## and take.

const HUB := "res://levels/hub/hub.tscn"

var hub: Node2D
var _had_brush := false
var _had_profile := false


func _init() -> void:
	root.set_content_scale_size(Vector2i(1600, 900))
	_run.call_deferred()


func _run() -> void:
	# Before the house is built: BrushStand2D asks the profile whether the brush is still
	# under the glass in its _ready(), so a state set afterwards sets nothing.
	var profile := root.get_node_or_null("PlayerProfile")
	var data: Dictionary = profile.get("_data") if profile != null else {}
	_had_brush = bool(data.get("brush_acquired", false))
	_had_profile = FileAccess.file_exists("user://profile.json")
	data["brush_acquired"] = false

	hub = (load(HUB) as PackedScene).instantiate()
	root.add_child(hub)
	for _frame in range(20):
		await process_frame
	await _shot("00_arrival")

	# Along the wall, stopping in front of each painting.
	var room: Node2D = hub.get_node("Room")
	for index in range(5):
		var at: Vector2 = room.call("painting_anchor", index)
		var apo: Node2D = hub.get_node("Apo")
		apo.set("velocity", Vector2.ZERO)
		apo.global_position = Vector2(at.x, room.call("ground_y"))
		for _frame in range(24):
			await process_frame
		await _shot("%02d_%s" % [index + 1, String(hub.WALL[index]["plate"]).to_lower()])

	# The end of the hall. Shot from where a player actually stops -- short of the case,
	# coming from the left -- and then again standing dead on it, because a floor object the
	# apo can walk on top of has to survive its worst case.
	var apo: Node2D = hub.get_node("Apo")
	var stand: Node2D = hub.get_node("BrushStand")
	apo.set("velocity", Vector2.ZERO)
	apo.global_position = Vector2(stand.global_position.x - 74.0, room.call("ground_y"))
	for _frame in range(24):
		await process_frame
	await _shot("06_the_case")

	apo.global_position = Vector2(stand.global_position.x, room.call("ground_y"))
	for _frame in range(12):
		await process_frame
	await _shot("07_standing_on_it")

	# The take: the case rises and dissolves, the plate changes, and the brush appears in
	# the corner chip. Caught mid-dissolve and again once it has settled.
	stand.call("take")
	for _frame in range(14):
		await process_frame
	await _shot("08_taking")
	for _frame in range(44):
		await process_frame
	await _shot("09_case_empty")

	# And back at Payyo, which now offers to open.
	apo.global_position = Vector2(room.call("painting_anchor", 0).x, room.call("ground_y"))
	for _frame in range(24):
		await process_frame
	await _shot("10_painting_open")

	_restore_profile(profile)
	print("OBRA_VISUAL_HUB_DONE")
	quit()


## Leave user://profile.json exactly as it was found.
func _restore_profile(profile: Node) -> void:
	if profile == null:
		return
	(profile.get("_data") as Dictionary)["brush_acquired"] = _had_brush
	if _had_profile:
		profile.call("save_profile")
	elif FileAccess.file_exists("user://profile.json"):
		DirAccess.remove_absolute("user://profile.json")


## WAITS FOR THE DRAW, not for two more frames of logic. Every other visual runner here
## already does; this one did not, and the last frame it wrote was always a copy of the one
## before it, because the tree had moved the apo on and the renderer had not yet been asked
## for a picture of that. It photographed a room the apo had already left -- which is a
## particularly bad failure in a runner whose whole job is that four defects in this project
## passed green suites and were caught only by looking at frames.
func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("/tmp/obra_hub_%s.png" % name)
