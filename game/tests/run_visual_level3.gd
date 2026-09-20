extends SceneTree
## Eyes on Dagat. Needs a REAL viewport, so no --headless:
##   godot --path game --script res://tests/run_visual_level3.gd
## Frames land in /tmp/obra_l3_*.png
##
## Every headless probe in this level proves a number. None of them can see whether the sea
## reads as sea, whether the creature reads as a creature, or whether the sweep the whole
## stealth resolution is built on is actually visible on screen -- and the art is all
## code-drawn placeholder, so what these frames are really for is checking that the SHAPES
## and the SPACES are right before anybody paints over them.
##
## ⚠ THE TOUR IS DRIVEN, NOT WALKED, AND IT UNPAUSES AS IT GOES. A lore line stops the tree,
## and this level's crossing is a lore scene: the first run of a file like this photographs
## the same paused frame six times. See run_visual_level2.gd, which learned it first.

const RosterFixtures = preload("res://tests/roster_fixtures.gd")
const OUTPUT_DIR := "/tmp"

var level: Node2D
var player: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	level = (load("res://level_3.tscn") as PackedScene).instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.4)

	player = level.get("player") as Node2D
	if player == null:
		print("OBRA_VISUAL_L3_FAILED: no player")
		quit(1)
		return
	var director = level.get("director")
	var marks := ^"EnvironmentBaseplate/GameplayPlane/Marks"

	# THE SHORE, as the player arrives: sand, the waterline, and the brush in it.
	await _capture("01_shore")
	await _go(Vector2(620.0, 500.0))
	await _capture("02_the_new_brush")

	# The practice beat is at the waterline, which is where the level teaches the drain.
	await _go(Vector2(930.0, 520.0))
	await _capture("03_the_waterline")

	# ⚠ DISARMED SO THE TOUR CAN PASS. Walking into either fork opens the choice overlay and
	# stops the tree -- correct, and it is what freezes a tour. Not a fault being hidden.
	for node_name in ["DialogueNode", "BakunawaNode"]:
		var fork := level.get_node_or_null(
			NodePath("EnvironmentBaseplate/GameplayPlane/%s" % node_name)) as Node2D
		if fork != null:
			fork.set_process_mode(Node.PROCESS_MODE_DISABLED)
	var choice := level.get_node_or_null(^"DialogueChoiceOverlay")
	if choice != null and choice.has_method("close"):
		choice.call("close")
	await _unpause()

	# THE BOAT, found on the sand and put in the water. This is the Artist crossing.
	director.call("enter_obstacle", "L3_N1")
	director.call("commit_route", "L3_N1", "artist")
	await _unpause()
	level.call("_launch_the_bangka")
	await _wait(0.8)
	await _go(Vector2(930.0, 500.0))
	await _capture("04_the_bangka")

	# ⚠ ON THE BOAT, NOT IN THE SEA. The surface route is ridden, and an apo teleported over
	# open water has nothing under it: it falls, the drowning rescue takes it back to the
	# shore, and the tour photographs an empty stretch of sea and calls it the crossing.
	await _board_the_bangka()
	await _sail_to(2400.0)
	await _capture("05_open_water")
	level.call("_cast_the_shadow")
	await _wait(1.6)
	await _capture("06_the_shadow")

	# THE CREATURE, staged at the surface for a boat player. Staged by hand here because the
	# level does it at the SOLVE and this tour only commits -- it never finds the boat.
	var creature := level.get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/Bakunawa") as Node2D
	var surface_mark := level.get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/Marks/SurfaceMark") as Node2D
	creature.call("stage_at", surface_mark.global_position.y)
	await _sail_to(3620.0)
	await _capture("07_bakunawa_surface")

	# AND AT DEPTH, which is the same creature moved. A diver is inside its space.
	creature.call("stage_at", 1150.0)
	await _become_a_fish()
	await _go(Vector2(3500.0, 1120.0))
	await _capture("08_bakunawa_depth")

	# THE SWEEP, which IS the stealth rule and is the one thing here that has to be legible.
	await _go(Vector2(3620.0, 1420.0))
	await _capture("09_under_the_sweep")

	# THE CORAL FIELD, where the crossing is a place rather than a distance.
	await _go(Vector2(2100.0, 1300.0))
	await _capture("10_coral_field")
	await _go(Vector2(1500.0, 1400.0))
	await _capture("11_a_refill")

	# CALM, once the light has shown it what it lost.
	creature.call("give_it_up")
	await _go(Vector2(3600.0, 1150.0))
	await _wait(0.8)
	await _capture("12_bakunawa_calm")

	# THE FAR SAND, where he stops.
	await _go(Vector2(4700.0, 500.0))
	await _capture("13_the_island")

	print("OBRA_VISUAL_L3_OK")
	quit(0)


## Put the player somewhere and let the camera catch up, dialogue and all.
func _go(at: Vector2) -> void:
	await _unpause()
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("apply_morph_state"):
		player.call("apply_morph_state", {"position": at, "linear_velocity": Vector2.ZERO})
	else:
		player.global_position = at
	await _wait(0.9)
	await _unpause()
	await _wait(0.3)


func _bangka() -> Node2D:
	var items := level.get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/WorldItemRoot")
	if items == null:
		return null
	for child in items.get_children():
		if String(child.name).begins_with("Sailboat"):
			return child as Node2D
	return null


func _board_the_bangka() -> void:
	var boat := _bangka()
	if boat == null:
		return
	await _wait(0.6)
	if player.has_method("apply_morph_state"):
		player.call("apply_morph_state", {
			"position": boat.global_position + Vector2(0.0, -30.0),
			"linear_velocity": Vector2.ZERO})
	await _wait(0.4)
	level.call("press_interact")
	await _wait(0.4)


## Move the hull and let the passenger come with it. Frozen first: writing global_position on
## an active RigidBody2D is the thing AGENTS.md says not to do.
func _sail_to(x: float) -> void:
	var boat := _bangka()
	if boat == null:
		return
	var body := boat as RigidBody2D
	body.freeze = true
	body.global_position = Vector2(x, body.global_position.y)
	await process_frame
	body.freeze = false
	if player != null and is_instance_valid(player) and player.has_method("apply_morph_state"):
		player.call("apply_morph_state", {
			"position": body.global_position + Vector2(0.0, -30.0),
			"linear_velocity": Vector2.ZERO})
	await _wait(1.0)
	await _unpause()
	await _wait(0.3)


func _become_a_fish() -> void:
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	level.call("_spawn_or_replace", "fish", "Fish", sheet,
		RosterFixtures.for_rig("swimmer", "fish"))
	await _wait(0.4)
	player = level.get("player") as Node2D


func _unpause() -> void:
	for _attempt in range(30):
		for node in root.get_tree().get_nodes_in_group(&"modal_overlays"):
			if node.name == "LevelCompleteOverlay":
				continue
			if node.has_method("is_open") and bool(node.call("is_open")):
				node.call("close")
		call_group(DialogueBox.GROUP, &"hide_line")
		root.get_tree().paused = false
		await process_frame
		if not root.get_tree().paused:
			return


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/obra_l3_%s.png" % [OUTPUT_DIR, label])
	print("  captured %s" % label)


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout
