extends SceneTree
## Eyes on the two insides, the hint bar and the checkpoint. Needs a REAL viewport:
##   godot --path game --script res://tests/run_visual_rooms.gd
## Frames land in /tmp/obra_rooms_*.png
##
## Every one of these was reported by a player looking at the screen, and not one of them
## would have been caught by a green headless suite: a room that does not fill the frame, a
## hint bar sitting across the middle of the path, a decision framed on empty terrace, and a
## checkpoint flag planted underneath the terrace it belongs to.

const OUTPUT_DIR := "/tmp"

var level: Node2D
var player: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://game_level.tscn") as PackedScene
	level = scene.instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.2)
	player = level.get("player") as Node2D
	# The canvas is taken once and stays taken, so a second run of this probe would
	# photograph an empty room. Put it back, the way the level-1 audit does when it wants to
	# run a route again. Nothing else on the profile is touched.
	var profile := root.get_node_or_null("PlayerProfile")
	if profile != null:
		(profile.get("_data")["acquired_objects"] as Array).erase("canvas_2_pista")
		for room in level.get_tree().get_nodes_in_group(&"bale_interiors"):
			if room.has_method("refresh_from_profile"):
				room.call("refresh_from_profile")

	# --- The checkpoint on the way up Ang Hagdan ----------------------------
	_put(Vector2(940.0, 380.0))
	await _wait(0.6)
	await _capture("00_checkpoint_before")
	_put(Vector2(990.0, 400.0))
	await _wait(0.35)
	await _capture("01_checkpoint_hoisting")
	await _wait(1.2)
	await _capture("02_checkpoint_raised")
	# And again from a step away, because the apo stands on top of the thing they just
	# raised and a flag behind a player is not a flag anybody has looked at.
	_put(Vector2(1120.0, 400.0))
	await _wait(0.8)
	await _capture("02b_checkpoint_from_a_step_away")

	# --- The hint bar, which used to sit across the middle of the path -------
	var hint_bar: Node = level.get("hint_bar")
	hint_bar.call("show_hint", "Draw something that can bear your weight, and set it on top.")
	await _wait(0.5)
	await _capture("03_hint_bar")
	hint_bar.call("clear")

	# --- The route decision, framed on the player rather than on the terrace -
	_put(Vector2(2330.0, 200.0))
	await _wait(0.8)
	level.call("_on_dialogue_node_approached")
	await _wait(1.0)
	await _capture("04_decision")
	for node in level.get_tree().get_nodes_in_group(&"modal_overlays"):
		if node.has_method("is_open") and bool(node.call("is_open")) \
				and node.has_method("close"):
			node.call("close")
	await _wait(0.4)

	# --- Inside the heap, and the brass coming off the nail -----------------
	var heap := await _step_into(&"straw_rooms", "05_straw_room")
	if heap != null:
		_put(heap.global_position + Vector2(-40.0, -250.0))
		await _wait(0.3)
		await _capture("05a_key_taken")
		await _wait(0.6)
		await _capture("05b_key_gone")

	# --- Inside Ang Bale, which is the one that had to fill the screen ------
	var bale := await _step_into(&"bale_interiors", "06_bale_room")
	# And walking up to what is in it: the hearth, then the canvas.
	if bale != null:
		_put(bale.global_position + Vector2(-23.0, 0.0))
		await _wait(0.9)
		await _capture("07_bale_notice")
		_put(bale.global_position + Vector2(-92.0, 0.0))
		await _wait(0.5)
		await _capture("08_bale_canvas_taken")
		await _wait(0.6)
		await _capture("09_bale_after")

	print("frames in %s/obra_rooms_*.png" % OUTPUT_DIR)
	quit(0)


## Put the player somewhere and let the level notice. The camera re-frames itself from the
## player's position every physics frame, so a teleport is enough -- which is the whole point
## of _refresh_room_framing asking where they ARE rather than trusting a doorway.
func _put(at: Vector2) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.global_position = at
	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO


func _step_into(group: StringName, label: String) -> Node2D:
	var room := level.get_tree().get_first_node_in_group(group) as Node2D
	if room == null:
		return null
	_put(Vector2(room.call("entry_point")))
	await _wait(1.0)
	await _capture(label)
	return room


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/obra_rooms_%s.png" % [OUTPUT_DIR, label])


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout
