extends SceneTree
## Does Dagat's encounter actually resolve, all three ways?
##
##   godot --headless --path game --script res://tests/run_bakunawa_probe.gd
##
## The most expensive single item in the level, and the one with the most ways to be quietly
## wrong: a channel that never opens is a level that cannot be finished, a sweep that never
## sees anybody is a stealth section with no stealth in it, and a creature that cannot be hit
## is a Protector route that is a second Pragmatist.
##
## ⚠ EVERY SEGMENT UNPAUSES THE TREE FIRST. Committing a route speaks the apo's line, a
## DialogueBox pauses the tree, and nothing moves after that -- a creature frozen mid-sweep
## reads exactly like a creature whose logic is broken. Three rounds of this level's own
## development went into bodies that "would not simulate" and were simply standing still.

const BakunawaClass = preload("res://scripts/bakunawa_2d.gd")

var level: Node
var results: Array[String] = []
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	results.append("  %s  %-40s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _run() -> void:
	print("\n===== THE BAKUNAWA =====")
	await _the_light()
	await _the_dark()
	await _the_fight()
	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_BAKUNAWA_OK")
		quit(0)
	else:
		print("OBRA_BAKUNAWA_FAILED=%d" % failures)
		quit(1)


# --- The three resolutions ---------------------------------------------------------------

func _the_light() -> void:
	var bits := await _open_at_the_encounter("artist")
	if bits.is_empty():
		_check(false, "the light: set up", "could not reach the encounter")
		return
	var creature: BakunawaClass = bits["bakunawa"]
	var director = bits["director"]
	var profile = root.get_node_or_null("PlayerProfile")
	# The flashlight is accepted, which answers the beat. The flower comes from what the
	# creature then does, not from the drawing.
	director.call("note_submission", "flashlight")
	await physics_frame
	_check(creature.state() == BakunawaClass.State.FOLLOWING,
		"the light: it goes to the light",
		"state %d" % creature.state())
	for _frame in range(360):
		await physics_frame
		if creature.state() == BakunawaClass.State.CALM:
			break
	_check(creature.state() == BakunawaClass.State.CALM,
		"and it finds what it lost", "state %d" % creature.state())
	_check(bool(profile.call("is_collectible_found", "L3_HF")),
		"and hands over the flower", "L3_HF recorded")
	_check(String(profile.call("bakunawa_outcome")) == "LIT",
		"and the run remembers how", String(profile.call("bakunawa_outcome")))
	_check(not creature.sees(creature.global_position + Vector2(120.0, 0.0)),
		"and a calm one sees nobody", "the sweep is down")
	_check(await _channel_is_open(creature), "and the way on is open", "coils disabled")
	_close()


func _the_dark() -> void:
	var bits := await _open_at_the_encounter("pragmatist")
	if bits.is_empty():
		_check(false, "the dark: set up", "could not reach the encounter")
		return
	var creature: BakunawaClass = bits["bakunawa"]
	var director = bits["director"]
	_check(await _channel_is_open(creature),
		"the dark: a gap opens on the commit", "coils disabled")
	# THE SWEEP HAS TO CATCH SOMEBODY. A cone that never returns true is a stealth section
	# with no stealth in it, and it looks identical to a well-played one in a report.
	var caught := false
	var missed := false
	for _frame in range(240):
		await physics_frame
		if creature.sees(creature.global_position + Vector2(300.0, 0.0)):
			caught = true
		else:
			missed = true
		if caught and missed:
			break
	_check(caught, "and the sweep catches somebody in it", "a point ahead of it was seen")
	_check(missed, "and misses them the rest of the time",
		"the same point was unseen as the sweep travelled")
	# Straight down, below the body, is where the design says to swim.
	var below: Vector2 = creature.global_position + Vector2(0.0, 340.0)
	_check(not creature.sees(below), "and below it is dark", "the way past is under it")
	# A lit flashlight gives the player away wherever they are.
	_check(creature.sees(below, true), "unless you brought a light",
		"drawing one and then sneaking is a harder encounter, on purpose")
	# Reaching the far side answers the beat.
	var player := level.get("player") as Node2D
	player.global_position = creature.global_position + Vector2(520.0, -80.0)
	for _frame in range(20):
		await physics_frame
	_check(bool(director.call("is_solved", "L3_N2")),
		"and getting past answers the beat", "solved by the dark, with nothing drawn at it")
	_close()


func _the_fight() -> void:
	var bits := await _open_at_the_encounter("protector")
	if bits.is_empty():
		_check(false, "the fight: set up", "could not reach the encounter")
		return
	var creature: BakunawaClass = bits["bakunawa"]
	var profile = root.get_node_or_null("PlayerProfile")
	_check(creature.state() == BakunawaClass.State.FIGHTING,
		"the fight: it turns on the commit", "state %d" % creature.state())
	_check(not await _channel_is_open(creature), "and the channel stays shut", "coils active")
	# ⚠ EVERY `strike` CLASS HAS TO BITE. The tag resolves five and the design asks that they
	# differ in more than damage -- which is only true if they all work at all.
	var refused: Array[String] = []
	for tool in ["boomerang", "axe", "sword", "anvil", "cannon"]:
		if not creature.accepts_tool(tool):
			refused.append(tool)
	_check(refused.is_empty(), "and every drawn weapon bites",
		"5 of 5 accepted" if refused.is_empty() else "refused: %s" % ", ".join(refused))
	# And nothing else does.
	_check(not creature.accepts_tool("bread"), "and nothing that is not a weapon does",
		"bread is refused")
	var hits := 0
	for _swing in range(6):
		if creature.state() != BakunawaClass.State.FIGHTING:
			break
		if creature.apply_tool_hit("cannon", 420.0, null):
			hits += 1
		await physics_frame
	_check(creature.state() == BakunawaClass.State.SUBDUED,
		"and it goes quiet rather than dying", "%d hits, state %d" % [hits, creature.state()])
	_check(String(profile.call("bakunawa_outcome")) == "FOUGHT",
		"and the run remembers that too", String(profile.call("bakunawa_outcome")))
	_check(await _channel_is_open(creature), "and the way on opens", "coils disabled")
	_check(not creature.accepts_tool("cannon"), "and a subdued one cannot be hit again",
		"there is no killing it")
	_close()


# --- Harness -------------------------------------------------------------------------------

## Put the run at the encounter with a route committed, the way a player arrives: the shore
## beat answered, the crossing taken, and the fork answered out loud.
func _open_at_the_encounter(route: String) -> Dictionary:
	level = (load("res://level_3.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(40):
		await physics_frame
	var director = level.get("director")
	var creature: BakunawaClass = level.get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/Bakunawa")
	if director == null or creature == null:
		return {}
	# The shore, then the crossing, then the fork -- in the order the level asks for them.
	#
	# ⚠ enter_obstacle FIRST. note_submission answers whatever the CURRENT obstacle is, and
	# a probe that never walked into a volume has no current obstacle -- so every drawing it
	# makes is judged against nothing and silently solves nothing.
	director.call("enter_obstacle", "L3_B0_SHORE")
	director.call("note_submission", "fish")
	director.call("exit_obstacle", "L3_B0_SHORE")
	director.call("enter_obstacle", "L3_N1")
	director.call("commit_route", "L3_N1", "pragmatist")
	director.call("note_submission", "fish")
	director.call("exit_obstacle", "L3_N1")
	director.call("enter_obstacle", "L3_N2")
	director.call("commit_route", "L3_N2", route)
	await _unpause()
	return {"director": director, "bakunawa": creature}


## Close whatever the commit opened and let the world run. See the header.
func _unpause() -> void:
	for node in root.get_tree().get_nodes_in_group(&"modal_overlays"):
		if node.has_method("is_open") and bool(node.call("is_open")):
			node.call("close")
	call_group(DialogueBox.GROUP, &"hide_line")
	root.get_tree().paused = false
	for _frame in range(4):
		await physics_frame


func _channel_is_open(creature: BakunawaClass) -> bool:
	await physics_frame
	var coils := creature.get_node_or_null(^"Coils") as StaticBody2D
	if coils == null:
		return true
	for child in coils.get_children():
		if child is CollisionShape2D and not (child as CollisionShape2D).disabled:
			return false
	return true


func _close() -> void:
	if level != null and is_instance_valid(level):
		level.queue_free()
	level = null
