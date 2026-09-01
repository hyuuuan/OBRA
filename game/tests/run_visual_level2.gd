extends SceneTree
## Eyes on Piyesta. Needs a REAL viewport, so no --headless:
##   godot --path game --script res://tests/run_visual_level2.gd
## Frames land in /tmp/obra_l2_*.png
##
## The headless probes prove the plaza's numbers. They cannot see whether the six parallax
## layers register against each other, whether the collision agrees with the picture, or
## whether the bandarita line the flight ceiling is pinned to is actually on screen where
## the rule says it is. Four defects in this project passed green suites and were caught
## only by screenshotting, and this level's whole boundary is a painted string.

const OUTPUT_DIR := "/tmp"

var level: Node2D
var player: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://level_2.tscn") as PackedScene
	level = scene.instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.4)

	player = level.get("player") as Node2D
	if player == null:
		print("OBRA_VISUAL_L2_FAILED: no player")
		quit(1)
		return

	await _capture("01_spawn")

	# The dialogue node stands at the dancers, and walking into it opens the route choice
	# and PAUSES THE TREE -- which is exactly right, and is why the camera never moved on
	# the first two runs of this file: every frame after the first was the same paused
	# frame. Disarmed so the tour can pass through, not because it is wrong.
	var node := level.get("dialogue_node") as Node2D
	if node != null:
		node.set_process_mode(Node.PROCESS_MODE_DISABLED)
	var choice := level.get_node_or_null(^"DialogueChoiceOverlay")
	if choice != null and choice.has_method("close"):
		choice.call("close")
	await _wait(0.4)

	# A TOUR, not a walk. Walking east reaches the dialogue node, which opens the route
	# choice and stops the tree -- correct behaviour, and it froze five of the six frames
	# on the first run of this file. Teleporting past it is what a camera does.
	# The marks moved when the plaza was re-authored off the painting, and these are read
	# off them: 660 start, 995 dancers, 1330 the lit house, 1650 the church. The old
	# waypoints ran to 2400, which is now past the east wall -- the tour photographed the
	# apo falling through the sky and called it "the church".
	for step in [[220.0, "02_kiosko"], [450.0, "03_start"], [720.0, "04_dancers"],
			[1060.0, "05_lit_house"], [1400.0, "06_church"]]:
		var at := Vector2(float(step[0]), 480.0)
		if player.has_method("apply_morph_state"):
			player.call("apply_morph_state", {"position": at, "linear_velocity": Vector2.ZERO})
		else:
			player.global_position = at
		await _wait(0.9)
		var cam := level.get_node_or_null(^"EnvironmentBaseplate/WorldCamera") as Camera2D
		print("  %s: asked for x=%.0f, player at %s, camera at %s"
			% [step[1], at.x, player.global_position,
			   cam.global_position if cam != null else Vector2.ZERO])
		await _capture(String(step[1]))

	await _watch_them_leave()
	await _tour_the_insides()
	await _look_at_scene_3()
	await _look_at_the_dance()

	print("OBRA_VISUAL_L2_OK")
	quit(0)


## PROBLEM 1's PROTECTOR ROUTE, WHICH NOBODY HAS EVER SEEN. The dancers were painted into the
## plate for most of this level's life, so `DancerGroup2D` drew nothing and scaring them off
## changed the picture not at all. They are cut-out sprites now, so there is finally something
## to photograph -- and a flee animation is exactly the kind of thing that can be wired up,
## pass every headless probe, and draw nothing at all.
func _watch_them_leave() -> void:
	var groups := level.get_tree().get_nodes_in_group(&"dancer_groups")
	if groups.is_empty():
		print("  scare: no dancer group")
		return
	var group := groups[0] as DancerGroup2D
	var player := level.get("player") as Node2D
	if player != null:
		player.global_position = Vector2(1000.0, 480.0)
	await _wait(0.6)
	if not group.scatter():
		print("  scare: they were not dancing")
		return
	await _wait(0.45)
	await _capture("06b_scare_running")
	await _wait(1.4)
	await _capture("06c_plaza_empty")
	print("  scare: state %d after the run" % group.state())


## THE FOUR ROOMS, which is where three of this level's four beats happen and which nothing
## had ever looked at. They are parked thousands of units above the plaza and they draw
## themselves only while somebody is standing in them, so a room that comes up black or a
## room painted over the plaza is invisible to every headless check in the project.
func _tour_the_insides() -> void:
	for room_name in ["ChurchInterior", "HouseInterior", "Alley1", "Alley2"]:
		var room := level.get_node_or_null(NodePath(
			"EnvironmentBaseplate/GameplayPlane/Rooms/%s" % room_name)) as Node2D
		if room == null:
			print("  %s: not in the scene" % room_name)
			continue
		# Half way in rather than at the entry, so the frame has the room in it rather than
		# the doorway. The camera follows on its own once the body is inside.
		var at: Vector2 = Vector2(room.call("entry_point")) + Vector2(
			float(room.get("room_length")) * 0.34, -20.0)
		if player.has_method("apply_morph_state"):
			player.call("apply_morph_state", {"position": at, "linear_velocity": Vector2.ZERO})
		else:
			player.global_position = at
		await _wait(1.1)
		print("  %s: player at %s" % [room_name, player.global_position])
		await _capture("07_%s" % room_name.to_lower())


## SCENE 3, half mended and then whole. Both states are worth looking at: the scatter has to
## read as a picture knocked sideways rather than as clutter, and the assembled one has to be
## the painting the player was shown in Level 1.
func _look_at_scene_3() -> void:
	var table := level.get("assembly_screen") as AssemblyOverlay
	if table == null:
		print("  scene 3: no table")
		return
	table.present()
	await _wait(0.6)
	await _capture("10_scene3_scattered")
	var ids := table.piece_ids()
	for index in range(ids.size()):
		# All but the last, so the frame has one piece still out and the ghost of where it
		# goes -- which is the assist, and the thing most likely to be drawn wrong.
		if index < ids.size() - 1:
			table.drag_to(ids[index], table.slot_of(ids[index]))
	await _wait(0.3)
	await _capture("11_scene3_nearly")
	table.drag_to(ids[ids.size() - 1], table.slot_of(ids[ids.size() - 1]))
	await _wait(0.5)
	await _capture("12_scene3_whole")
	table.close()
	await _wait(0.3)


## THE DANCE, WHICH IS THE ONLY SCREEN IN THIS LEVEL THAT IS NOT THE WORLD. It pauses the
## tree, so it goes last: everything after it would be photographed frozen.
##
## Three frames, because the three things worth looking at happen at different moments -- the
## lane before anything has been struck, a verdict at the line, and the pips part-way through
## with some landed and some missed.
func _look_at_the_dance() -> void:
	var director = level.get("director")
	if director == null:
		return
	director.call("commit_route", "L2_N1", "artist")
	var screen := level.get("dance_screen") as DanceOverlay
	for _frame in range(240):
		if screen != null and screen.is_open():
			break
		await process_frame
	if screen == null or not screen.is_open():
		print("  dance: never opened")
		return
	await _wait(0.8)
	await _capture("07_dance_lane")
	# On the beat, so the frame catches a PERFECT at the line.
	var track: PackedFloat32Array = (level.get("dance") as DanceMinigame).track()
	for index in range(3):
		while screen.clock() < track[index] and screen.is_open():
			await process_frame
		var verdict := screen.perform_stroke()
		if index == 0:
			await _capture("08_dance_verdict")
		print("  dance: cue %d -> %s at t=%.2f" % [index, verdict, screen.clock()])
	await _wait(0.6)
	await _capture("09_dance_pips")


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/obra_l2_%s.png" % [OUTPUT_DIR, label])


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout
