extends SceneTree
## Which pose Lolo is actually in while the level runs.
##   godot --headless --path game --script res://tests/run_companion_pose_probe.gd
##
## THE SHEET HAS TWELVE FRAMES OF MOTION IN IT AND THE GAME SHOWED NONE OF THEM. `float` and
## `hurry` are six cells each -- the drift and the chase -- and across a whole playthrough
## the figure never left cell 0 of the turnaround. Nothing in the suite could see it: every
## other test drives the figure directly (`run_visual_tutorial` sets `pose` itself), so the
## one thing never checked was whether LOLO EVER ASKS FOR THOSE POSES.
##
## What is held here:
##   he does not stay turned to camera once his line is gone from the bar
##   chasing the player puts him in the run cycle
##   keeping pace puts him in the drift, and the drift advances through its cells

var level: Node2D
var lolo: Node2D
var figure: Node2D
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-46s %s" % ["OK  " if ok else "FAIL", what, detail])


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _pose() -> String:
	return String(figure.get("pose"))


func _run() -> void:
	level = (load("res://game_level.tscn") as PackedScene).instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.2)
	lolo = level.get("lolo") as Node2D
	if lolo == null:
		print("OBRA_COMPANION_POSE_FAILED=1  (no companion in the level)")
		quit(1)
		return
	figure = lolo.get_node("Figure") as Node2D

	await _audit_he_turns_back_when_the_line_is_gone()
	await _audit_chasing_runs()
	await _audit_keeping_pace_drifts()

	print("OBRA_COMPANION_POSE_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)


## ⚠ `talking` WAS A LATCH AND THE LEVEL'S FIRST LINE SET IT.
##
## `say(text)` defaults to `seconds = 0`, which means "stand until something replaces it" --
## and the greeting fired at spawn is exactly that call. `_speech_time` was therefore 0 from
## the first frame, the countdown that clears the mouth never ran, and only `hush()` could
## unset it. So Lolo held `face` -- cell 0 of the turnaround, head-on -- for the whole level,
## whatever he was doing.
func _audit_he_turns_back_when_the_line_is_gone() -> void:
	# NOT `hush()`. That is the level telling him to shut up, which is the one path that
	# always worked; what broke was him finishing a line on his own. So this waits him out.
	var waited := 0.0
	while _pose() == "face" and waited < 12.0:
		await _wait(0.2)
		waited += 0.2
	_check(_pose() != "face", "he turns back when his line is read",
		"pose is '%s' after %.1fs" % [_pose(), waited])
	# And the turn back is its own animation, so let it play out before anything below
	# reads a pose.
	await _wait(0.6)


## Put the player a long way off -- but inside the teleport distance, because a jump across
## the level is deliberately NOT read as a sprint -- and he should be visibly chasing.
func _audit_chasing_runs() -> void:
	var player := level.get("player") as Node2D
	if player == null:
		_check(false, "chasing puts him in the run cycle", "no player")
		return
	var seen: Dictionary = {}
	var frames: Dictionary = {}
	var sprite := figure.get_node("Body") as Sprite2D
	for step in range(40):
		player.global_position += Vector2(24.0, 0.0)
		await process_frame
		seen[_pose()] = true
		frames[sprite.frame] = true
	_check(seen.has("hurry"), "chasing puts him in the run cycle",
		"poses seen: %s" % ", ".join(PackedStringArray(seen.keys())))
	_check(frames.size() > 1, "and the run cycle advances through its cells",
		"%d distinct frames" % frames.size())


## KEEPING UP IS NOT CHASING, and this is the audit that says so.
##
## Driven at the apo's own run speed, in real time, because that is the only speed this game
## actually travels at. Under the old speed threshold he spent 225 of 240 frames in the chase
## and 13 in the drift -- the hover cycle the sheet was drawn for never played.
func _audit_keeping_pace_drifts() -> void:
	var player := level.get("player") as Node2D
	if player == null:
		_check(false, "keeping pace puts him in the drift", "no player")
		return
	# Let him close the gap the audit above tore open first, or the first second of this
	# one measures that catch-up rather than what it is here for.
	await _wait(1.5)
	var tally: Dictionary = {}
	var frames: Dictionary = {}
	var sprite := figure.get_node("Body") as Sprite2D
	for step in range(180):
		await process_frame
		player.global_position += Vector2(260.0 / 60.0, 0.0)
		var pose := _pose()
		tally[pose] = int(tally.get(pose, 0)) + 1
		if pose == "float":
			frames[sprite.frame] = true
	var drifting := int(tally.get("float", 0))
	var chasing := int(tally.get("hurry", 0))
	_check(drifting > chasing, "keeping pace at a run is the drift, not the chase",
		"drift %d frames, chase %d" % [drifting, chasing])
	_check(frames.size() > 1, "and the drift advances through its cells",
		"%d distinct frames" % frames.size())
	_check(not tally.has("face"), "and nothing in that stretch is the held turnaround",
		"poses seen: %s" % ", ".join(PackedStringArray(tally.keys())))
