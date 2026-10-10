extends SceneTree
## LEAVE A LEVEL AND COME BACK: YOU ARE AT YOUR LAST CHECKPOINT, NOT AT THE START.
##   godot --headless --path game --script res://tests/run_resume_probe.gd
##
## Checkpoints used to live only as long as the level did, so walking out to the house and
## back in put the apo at the very beginning however far they had got. The last one is now
## kept on disk per level. Each level here: walk to its first fork, answer it (which writes
## the checkpoint), leave, come back -- and the apo must be standing at the fork, with the
## fork answered and its route's branch the one standing. Finishing the level forgets it.

const FORKS := [
	{"level": "level_1", "scene": "res://game_level.tscn", "obstacle": "L1_N1", "route": "artist"},
	{"level": "level_2", "scene": "res://level_2.tscn", "obstacle": "L2_N1", "route": "pragmatist"},
	{"level": "level_3", "scene": "res://level_3.tscn", "obstacle": "L3_N2", "route": "pragmatist"},
]
const RosterFixtures = preload("res://tests/roster_fixtures.gd")
## Where Dagat's sea checkpoint is: its volume runs from the seabed to above the deck, so a
## boat player sailing past writes it sitting in the bangka.
const CP3B_X := 6160.0

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-56s %s" % ["OK  " if ok else "FAIL", what, detail])


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _open(spec: Dictionary) -> Node2D:
	root.get_node("LevelManager").set("current_level_id", spec["level"])
	var level := (load(String(spec["scene"])) as PackedScene).instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	level.set("resume_enabled", true)
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	return level


func _anchor(level: Node2D) -> Vector2:
	return level.call("_player_anchor_position")


func _run() -> void:
	for spec: Dictionary in FORKS:
		print("\n===== %s =====" % String(spec["level"]).to_upper())
		var level := _open(spec)
		await _wait(1.5)
		var start := _anchor(level)
		# Somewhere well along the level, where the fork is.
		var fork := level.call("_fork_for", spec["obstacle"]) as Node2D
		var there := fork.global_position if fork != null else start + Vector2(900.0, 0.0)
		var player := level.get("player") as Node2D
		player.call("apply_morph_state", {"position": there, "linear_velocity": Vector2.ZERO})
		await _wait(0.3)
		var director = level.get("director")
		director.call("commit_route", spec["obstacle"], spec["route"])
		await _wait(0.5)
		var saved: bool = level.call("_has_saved_checkpoint")
		_check(saved, "answering the fork keeps a checkpoint on disk", str(level.call("_checkpoint_save_path")))
		var where := _anchor(level)
		level.queue_free()
		await _wait(0.4)

		level = _open(spec)
		await _wait(1.8)
		var back := _anchor(level)
		# Across, not up and down: the probe drops the apo at the fork's marker, which can be in
		# the air, and they fall after the snapshot just as they did before it.
		_check(absf(back.x - where.x) < 120.0 and absf(back.x - start.x) > 150.0,
			"coming back puts the apo at the checkpoint, not the start",
			"back at %s, checkpoint at %s, start %s" % [back.round(), where.round(), start.round()])
		director = level.get("director")
		var committed: Dictionary = (director.call("obstacle_state") as Dictionary).get("committed", {})
		_check(String(committed.get(spec["obstacle"], "")) == spec["route"],
			"and the route chosen there is still chosen", str(committed))
		var node := level.call("_fork_for", spec["obstacle"]) as Node
		_check(node == null or bool(node.get("_answered")), "and the fork does not ask again",
			"answered" if node != null and bool(node.get("_answered")) else "no fork node")
		var layout = level.get("route_layout")
		if spec["level"] == "level_1" and layout != null:
			_check(String(layout.call("chosen_route")) == spec["route"],
				"and its branch is the one standing", String(layout.call("chosen_route")))
		# Finishing forgets it: the next visit is a replay from the start.
		level.call("_forget_saved_checkpoint")
		_check(not bool(level.call("_has_saved_checkpoint")), "a finished level keeps no checkpoint",
			"forgotten")
		level.queue_free()
		await _wait(0.4)

	await _boat_player_resumes()
	await _diver_resumes_as_their_shape()
	print("OBRA_RESUME_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(failures)


## AND A BOAT PLAYER LEFT AT SEA COMES BACK IN THE BOAT. Inside one visit the launched bangka
## survives a restore -- LevelBase keeps what was placed before the checkpoint, by instance id
## -- but a level resumed from disk has no boat to keep, and the fork that launched it is
## already answered. Quit at CP3b, come back, and the apo was in the open sea out of the boat
## and without it, where the current holds a swimmer short of the island.
func _boat_player_resumes() -> void:
	print("\n===== LEVEL_3, BY BOAT =====")
	var spec := {"level": "level_3", "scene": "res://level_3.tscn"}
	var level := _open(spec)
	level.call("_forget_saved_checkpoint")
	await _wait(1.0)
	var director = level.get("director")
	director.call("solve_with_item", "L3_B0_SHORE", "new_brush")
	director.call("enter_obstacle", "L3_N1")
	director.call("commit_route", "L3_N1", "artist")
	await _settle()
	# Something strong drawn, and E at the hull: the route's own way into the water.
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	level.call("_spawn_or_replace", "horse", "Horse", sheet, RosterFixtures.for_rig("walker", "horse"))
	await _settle()
	var beached := level.get("_bangka") as Node2D
	_put(level, beached.global_position + Vector2(-60.0, -40.0))
	await _wait(0.3)
	level.call("press_interact")
	await _settle(2.5)
	var boat := level.get("_launched_boat") as RigidBody2D
	if boat == null:
		_check(false, "the bangka is launched", "no boat")
		level.queue_free()
		return
	_put(level, boat.global_position + Vector2(0.0, -40.0))
	await _wait(0.1)
	level.call("press_interact")
	await _settle()
	# Out to the sea checkpoint, aboard -- carried there rather than rowed past the creature.
	var out := Vector2(CP3B_X, boat.global_position.y)
	PhysicsServer2D.body_set_state(boat.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM,
		Transform2D(0.0, out))
	boat.global_position = out
	await _settle(1.5)
	var player := level.get("player") as Node2D
	var aboard_before := bool(boat.call("has_passenger", player))
	var latest := String((level.get("checkpoints") as Object).call("latest_id"))
	_check(aboard_before and latest == "CP3b", "sailing past CP3b writes it, aboard",
		"%s, aboard %s" % [latest, aboard_before])
	level.queue_free()
	await _wait(0.4)

	level = _open(spec)
	await _settle(1.8)
	var again := level.get("_launched_boat") as Node2D
	player = level.get("player") as Node2D
	_check(again != null and is_instance_valid(again) and absf(again.global_position.x - CP3B_X) < 120.0,
		"coming back, the bangka is afloat where it was",
		"boat at %s" % (again.global_position.round() if again != null and is_instance_valid(again) else "NONE"))
	_check(again != null and is_instance_valid(again) and bool(again.call("has_passenger", player)),
		"and the apo is in it", "riding %s" % player.call("is_riding"))
	level.call("_forget_saved_checkpoint")
	level.queue_free()
	await _wait(0.4)


## AND A DIVER LEFT IN DEEP WATER COMES BACK AS WHAT THEY DREW. A deep checkpoint keeps the
## shape held there -- the drawing's picture and strokes -- so a restore gives it back instead of
## a drowning apo. On disk the picture, an Image, was not "plain" and the whole shape was dropped:
## quit at CP3b as a fish and Continue put the apo in the middle of the sea without it.
func _diver_resumes_as_their_shape() -> void:
	print("\n===== LEVEL_3, DIVING =====")
	var spec := {"level": "level_3", "scene": "res://level_3.tscn"}
	var level := _open(spec)
	level.call("_forget_saved_checkpoint")
	await _wait(1.0)
	var director = level.get("director")
	director.call("solve_with_item", "L3_B0_SHORE", "new_brush")
	director.call("enter_obstacle", "L3_N1")
	director.call("commit_route", "L3_N1", "pragmatist")
	await _settle()
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	level.call("_spawn_or_replace", "fish", "Fish", sheet, RosterFixtures.for_rig("swimmer", "fish"))
	await _settle(1.0)
	_put(level, Vector2(CP3B_X, 1240.0))
	await _settle(1.5)
	var latest := String((level.get("checkpoints") as Object).call("latest_id"))
	_check(latest == "CP3b" and String(level.get("_current_form_id")) == "fish",
		"a fish at the seabed clam writes CP3b", "%s, as %s" % [latest, level.get("_current_form_id")])
	level.queue_free()
	await _wait(0.4)

	level = _open(spec)
	await _settle(2.0)
	var form := String(level.get("_current_form_id"))
	var anchor: Vector2 = level.call("_anchor_now")
	_check(form == "fish" and absf(anchor.x - CP3B_X) < 120.0,
		"coming back, they are the fish again, at the clam",
		"as '%s' at %s" % [form, anchor.round()])
	level.call("_forget_saved_checkpoint")
	level.queue_free()
	await _wait(0.4)


func _put(level: Node2D, at: Vector2) -> void:
	(level.get("player") as Node2D).call("apply_morph_state",
		{"position": at, "linear_velocity": Vector2.ZERO})


## Wait, closing whatever stops the world on the way: a drawing's card, a line of Lolo's.
func _settle(seconds: float = 0.6) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await physics_frame
		for node in get_nodes_in_group(&"modal_overlays"):
			if node.has_method("is_open") and node.has_method("close") and bool(node.call("is_open")):
				node.call("close")
		if paused:
			call_group(DialogueBox.GROUP, &"hide_line")
			paused = false
