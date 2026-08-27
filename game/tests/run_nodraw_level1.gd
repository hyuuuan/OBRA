extends SceneTree
## Can the level be beaten without drawing anything?
##
##	 godot --headless --path game --script res://tests/run_nodraw_level1.gd
##
## The whole premise of the game is that the player draws to get past things. If a person
## can walk, jump and wade from the spawn to the goal in their own body, every obstacle in
## the level is scenery and the drawing is a side activity.
##
## So this drives the wanderer as hard as a determined player would -- hold right, jump
## whenever it is stopped, swim in water, answer Lolo's questions (answering is free) --
## and reports how far it got. It asserts the level does NOT complete, and prints the
## furthest point reached so a hole can be found on the map.

## Long enough to cross a stretch, short enough that five of them are a test and not an
## afternoon.
const SEGMENT_SECONDS := 22.0

## Where a no-draw player can plausibly find themselves, and what is supposed to stop them
## there. Testing only from the spawn tells you about the FIRST gate and nothing else: the
## bot stops at Beat 0 and the whole level behind it goes unexamined.
const SEGMENTS: Array = [
	{"name": "the paddy and Ang Hagdan", "at": Vector2(260, 460.0)},
	{"name": "above the stair, to the gorge", "at": Vector2(1220, 360.0)},
	# All three, because they are physically different crossings: the Artist route puts a
	# post mid-gorge, the Pragmatist route drops ledges down and leaves a bare wall out, and
	# the Protector route stands a tree up to be felled. Testing whichever answer happens to
	# be first tests one of them.
	{"name": "the gorge, Artist route", "at": Vector2(3000, 200.0), "route": 0},
	{"name": "the gorge, Pragmatist route", "at": Vector2(3000, 200.0), "route": 1},
	{"name": "the gorge, Protector route", "at": Vector2(3000, 200.0), "route": 2},
	{"name": "past the gorge, along Terrace5", "at": Vector2(3660, 200.0)},
	{"name": "the Overlook and the bale", "at": Vector2(4380, 40.0)},
]

var level: Node
var player: CharacterBody2D
var completed := false
var answered := 0
## Which of Lolo's answers to take when a question comes up. The gorge's three routes are
## three different crossings and only one of them gets tested if this is always the first.
var _route_choice := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _open_level()
	var goal := level.get_node_or_null(
		"EnvironmentBaseplate/GameplayPlane/GoalMarker") as Node2D
	var goal_x: float = goal.global_position.x if goal != null else 0.0
	_close_level()

	var report: Array[String] = []
	var broken := 0
	for entry: Variant in SEGMENTS:
		var segment: Dictionary = entry
		_route_choice = int(segment.get("route", 0))
		var reached := await _try_segment(segment["at"])
		var line := "  %-34s x %.0f -> %.0f" % [segment["name"], Vector2(segment["at"]).x, reached]
		if completed:
			broken += 1
			line += "	FINISHED THE LEVEL"
		report.append(line)
		if completed:
			break

	print("\n===== NO-DRAW RUN =====")
	print("	 goal is at x %.0f. Nothing below may reach it." % goal_x)
	for line in report:
		print(line)
	print("	 questions answered: %d (answering Lolo costs no ink)" % answered)
	if broken == 0:
		print("	 OK	   the level cannot be finished without drawing")
		print("OBRA_NODRAW_OK")
		quit(0)
	else:
		print("	 FAIL  the level can be finished in the player's own body")
		print("OBRA_NODRAW_FAILED=%d" % broken)
		quit(1)


## Drop the player at the start of a stretch and drive them as hard as a determined person
## would: hold right, jump constantly, swim in water, answer anything Lolo asks.
func _open_level() -> void:
	var packed := load("res://game_level.tscn") as PackedScene
	level = packed.instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	# The level opens on a line of dialogue, and a conversation stops the tree until the
	# player turns the page. Nobody is here to press a key, so dismiss it the way a skip
	# button would, and keep dismissing them -- otherwise the first obstacle the
	# walker reaches stops the world and it reports the level as a wall.
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(30):
		await physics_frame
	player = level.get("player") as CharacterBody2D


func _close_level() -> void:
	if level != null and is_instance_valid(level):
		level.queue_free()
	level = null
	player = null


func _try_segment(at: Vector2) -> float:
	completed = false
	await _open_level()
	if player == null or not is_instance_valid(player):
		return 0.0
	player.velocity = Vector2.ZERO
	player.global_position = at
	for _settle in range(20):
		await physics_frame
	var overlay := level.get_node_or_null("LevelCompleteOverlay")
	var reached := player.global_position.x
	var last_progress := reached
	var stuck := 0

	Input.action_press(&"move_right")
	for frame in range(int(SEGMENT_SECONDS * 60.0)):
		if frame % 26 == 0:
			Input.action_press(&"jump")
		elif frame % 26 == 16:
			Input.action_release(&"jump")
		if bool(player.call("is_in_water")):
			Input.action_press(&"move_up")
		else:
			Input.action_release(&"move_up")
		await physics_frame
		_answer_any_question()
		var here := player.global_position.x
		reached = maxf(reached, here)
		if here > last_progress + 8.0:
			last_progress = here
			stuck = 0
		else:
			stuck += 1
		if stuck > 200:
			# Back off and try again rather than holding right into a wall forever.
			Input.action_release(&"move_right")
			for _back in range(20):
				await physics_frame
			Input.action_press(&"move_right")
			stuck = 0
		if overlay != null and bool(overlay.call("is_open")):
			completed = true
			break
	Input.action_release(&"move_right")
	Input.action_release(&"jump")
	Input.action_release(&"move_up")
	if completed and overlay != null:
		overlay.call("close")
		await process_frame
	paused = false
	_close_level()
	await process_frame
	return reached


## Clear anything modal standing in the way, the way a player does: answer Lolo, press
## CONTINUE on the memory. None of it costs ink.
##
## This matters more than it looks. The memory of Lola opens when the player crosses x
## 2980 and it PAUSES the game, so a bot that ignores it stands still for the rest of the
## segment -- which reads in the report as a stretch that is properly gated when it is
## really a stretch nobody has walked.
func _answer_any_question() -> void:
	for node in level.get_tree().get_nodes_in_group(&"modal_overlays"):
		if not node.has_method("is_open") or not bool(node.call("is_open")):
			continue
		if node.name == "LevelCompleteOverlay":
			continue    # that one is the result, not an obstacle
		var buttons := _buttons_in(node)
		if buttons.is_empty():
			continue
		var button: Button = buttons[mini(_route_choice, buttons.size() - 1)]
		if not button.disabled:
			button.emit_signal("pressed")
			answered += 1
			return


func _buttons_in(node: Node) -> Array[Button]:
	var out: Array[Button] = []
	for child in node.get_children():
		if child is Button and (child as Button).visible:
			out.append(child as Button)
		out.append_array(_buttons_in(child))
	return out
