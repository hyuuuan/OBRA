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

	print("OBRA_RESUME_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(failures)
