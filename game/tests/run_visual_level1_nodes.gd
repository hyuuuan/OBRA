extends SceneTree
## Eyes on Ang Dayami and Ang Bale. Needs a REAL viewport, so no --headless:
##
##	 godot --path game --script res://tests/run_visual_level1_nodes.gd
##
## Frames land in /tmp/obra_l1n_*.png and have to be LOOKED AT. run_level1_audit already
## proves the straw remembers which route searched it, that the chest turns up either way,
## and that no bulul carries collision. None of that says whether a combed heap looks any
## different from an intact one on screen, whether the chest rises out of the straw
## somewhere the player can see it, or whether the bale reads as a house standing on posts
## rather than as terrain. Four defects in this project passed green suites and were caught
## only by screenshotting.
##
## Every frame is printed with the state it is meant to be showing. A frame that disagrees
## with its own caption is the finding.

const OUTPUT_DIR := "/tmp"
const StrawPileClass = preload("res://scripts/straw_pile_2d.gd")
const STATE_NAMES := ["intact", "combed", "tunnelled", "scattered"]
## Solve each route the way it asks to be solved -- same labels the audit uses, so the
## frames show the same walkthrough the headless suite signs off on.
const SOLVERS := {"artist": "rake", "pragmatist": "ant", "protector": "fan"}

var _shots := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# A profile from an earlier run arrives with tags already unlocked and the canvas
	# already creased. The frames are supposed to be a first playthrough.
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://profile.json"))
	var profile := root.get_node_or_null("PlayerProfile")
	if profile != null:
		profile.call("load_profile")

	for route in ["artist", "pragmatist", "protector"]:
		await _look_at_node_two(route)
	await _look_at_node_three()

	print("OBRA_VISUAL_L1_NODES_DONE (%d frames in %s)" % [_shots, OUTPUT_DIR])
	quit(0)


## Ang Dayami. The straw is the whole visual question here: three routes leave three
## different marks, and if those marks are not legible side by side then the difference
## between the routes exists only in the telemetry.
func _look_at_node_two(route: String) -> void:
	var level := await _open_level()
	if level == null:
		return
	var director = level.get("director")
	var dayami := level.get_node_or_null("EnvironmentBaseplate/GameplayPlane/Dayami")
	var volume := level.get_node_or_null(
		"EnvironmentBaseplate/GameplayPlane/Obstacles/L1_N2") as Node2D
	if director == null or dayami == null or volume == null:
		push_error("node 2: the level has no Dayami, no obstacle volume, or no director")
		level.queue_free()
		return

	await _stand_at(level, volume.global_position)
	if route == "artist":
		# Once: nothing has happened yet, so the arrival frame is the same for all three.
		print("[n2_00_arrival] straw %s, chest hidden=%s, at obstacle '%s'"
			% [_straw_states(dayami), not _chest_visible(dayami), director.current_obstacle()])
		await _capture("n2_00_arrival")

	director.commit_route("L1_N2", route)
	await _wait(0.6)
	if route == "artist":
		print("[n2_01_committed] Lolo should be answering the choice out loud")
		await _capture("n2_01_committed")

	level.call("_judge_submission", String(SOLVERS[route]))
	# The artist route combs in three passes over about two seconds; the other two are
	# immediate. Waiting the long time for all three keeps the frames comparable.
	await _wait(3.2)
	print("[n2_02_%s] straw %s, chest visible=%s, solved=%s"
		% [route, _straw_states(dayami), _chest_visible(dayami), director.is_solved("L1_N2")])
	await _capture("n2_02_%s" % route)

	level.queue_free()
	await process_frame


## Ang Bale. The architecture is the puzzle, so the architecture has to read: four posts,
## a rat guard on each, a deck out of reach and a thatch slope over it.
func _look_at_node_three() -> void:
	var level := await _open_level()
	if level == null:
		return
	var director = level.get("director")
	var bale_root := level.get_node_or_null("EnvironmentBaseplate/GameplayPlane/Bale")
	if director == null or bale_root == null:
		push_error("node 3: the level has no Bale or no director")
		level.queue_free()
		return

	# Beside the house, not inside it: the posts, deck and thatch are all solid and
	# dropping the player into the middle of them wedges them in the geometry.
	await _stand_at(level, Vector2(3360.0, 50.0))
	print("[n3_00_arrival] at obstacle '%s' -- four posts, four halipan, a deck and a roof"
		% director.current_obstacle())
	await _capture("n3_00_arrival")

	# The bulul do exactly one thing, and it is a refusal. Walk into the notice radius.
	var figure := bale_root.get_node_or_null("Bulul1") as Node2D
	if figure != null:
		await _stand_at(level, figure.global_position + Vector2(-56.0, 0.0))
		await _wait(0.4)
		print("[n3_01_bulul] spoken=%s -- Lolo refuses, and nothing unlocks"
			% figure.call("has_spoken"))
		await _capture("n3_01_bulul")

	# Back beside the house to answer the obstacle.
	await _stand_at(level, Vector2(3360.0, 50.0))
	director.commit_route("L1_N3", "artist")
	await _wait(0.6)
	print("[n3_02_committed] over the thatch and in under the eaves")
	await _capture("n3_02_committed")

	level.call("_judge_submission", "spider")
	await _wait(2.4)
	print("[n3_03_attic] the search runs 1.6s blind -- no Node 2 in this run, so no page")
	await _capture("n3_03_attic")
	await _wait(1.6)
	print("[n3_04_photo] solved=%s" % director.is_solved("L1_N3"))
	await _capture("n3_04_photo")

	level.queue_free()
	await process_frame


func _open_level() -> Node:
	var packed := load("res://game_level.tscn") as PackedScene
	var level := packed.instantiate()
	# No backend: these frames are about what is on the terrace, and starting a Python
	# process to photograph a straw pile would make the run flaky for nothing.
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	await _wait(1.2)
	return level


## Put the player somewhere and let the camera catch up. The camera lerps toward its
## target, so a frame taken straight after a teleport is a picture of where the player
## used to be.
func _stand_at(level: Node, where: Vector2) -> void:
	var player := level.get("player") as Node2D
	if player == null:
		return
	player.global_position = where
	var camera := level.get_node_or_null("EnvironmentBaseplate/WorldCamera")
	if camera != null and camera.has_method("snap_to_target"):
		camera.call("snap_to_target")
	for _frame in range(14):
		await physics_frame


func _straw_states(dayami: Node) -> String:
	var out: Array[String] = []
	for child in dayami.get_children():
		if child.get_script() == StrawPileClass:
			out.append(STATE_NAMES[int(child.call("state"))])
	return "[%s]" % ", ".join(out)


func _chest_visible(dayami: Node) -> bool:
	var chest := dayami.get_node_or_null("Baul") as Node2D
	return chest != null and chest.visible


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/obra_l1n_%s.png" % [OUTPUT_DIR, label])
	_shots += 1


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout
