extends SceneTree
## Dagat ends however the apo comes to the island.
##
##   godot --headless --path game --script res://tests/run_level3_island_arrival_probe.gd
##
## A playtest stood the apo on the island's sand in front of the painting, and nothing happened.
## The island lands through a checkpoint area that fires once, and the landing is refused until
## the bakunawa is answered: so a swimmer who reached the far sand first spent the only entry
## the level would ever count, and wrote the island's checkpoint while the encounter was still
## open. Drowning there put her back on that checkpoint with the painting never armed, and the
## level could not end. This reaches the island too early, answers the creature from there,
## restores at the island, and then takes the painting.

const RosterFixtures = preload("res://tests/roster_fixtures.gd")
const CHECKS := 5

var level: Node
var failures := 0
var checked := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(240.0).timeout.connect(func() -> void:
		print("OBRA_LEVEL3_ISLAND_ARRIVAL_FAILED=watchdog")
		quit(2))
	print("\n===== REACHING THE ISLAND =====")
	var supervisor := root.get_node_or_null("BackendSupervisor")
	if supervisor != null:
		supervisor.set("auto_start_backend", false)
	level = (load("res://level_3.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(40):
		await physics_frame
	var director = level.get("director")
	var checkpoints = level.get("checkpoints")
	var arrival := level.get_node(^"EnvironmentBaseplate/GameplayPlane/IslandArrival") as Node2D
	var creature := level.get_node(^"EnvironmentBaseplate/GameplayPlane/Bakunawa") as Node2D

	# The brush first, or a form runs on Terraces' clock instead of Dagat's ink.
	_place((level.get_node(^"EnvironmentBaseplate/GameplayPlane/Marks/BrushMark") as Node2D)
		.global_position)
	for _frame in range(20):
		await physics_frame
	director.call("enter_obstacle", "L3_N1")
	director.call("commit_route", "L3_N1", "pragmatist")
	director.call("note_submission", "fish")
	director.call("exit_obstacle", "L3_N1")
	await _unpause()
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	level.call("_spawn_or_replace", "fish", "Fish", sheet, RosterFixtures.for_rig("swimmer", "fish"))
	await physics_frame
	var ink = level.get("ink_manager")

	# She meets the creature, chooses to fight it, and swims on to the far sand before it is done.
	director.call("enter_obstacle", "L3_N2")
	director.call("commit_route", "L3_N2", "protector")
	await _unpause()
	director.call("exit_obstacle", "L3_N2")
	_place(arrival.global_position)
	await _frames(60, ink)
	_check(not bool(level.get("_arrived")) and not checkpoints.call("ids").has("CP4"),
		"reached with the creature unanswered, the island waits and is not saved",
		"arrived %s; checkpoints %s" % [level.get("_arrived"), checkpoints.call("ids")])

	# Answered from there, while she is still at the island.
	director.call("enter_obstacle", "L3_N2")
	director.call("note_submission", "cannon")
	for _swing in range(int(creature.get("HITS_TO_SUBDUE"))):
		creature.call("apply_tool_hit", "cannon", 420.0, null)
		await physics_frame
	director.call("exit_obstacle", "L3_N2")
	_place(arrival.global_position)
	await _frames(120, ink, "_arrived")
	_check(bool(director.call("is_solved", "L3_N2")) and bool(level.get("_arrived")),
		"answered while she is there, the island lands",
		"solved %s; arrived %s" % [director.call("is_solved", "L3_N2"), level.get("_arrived")])

	# Back in the water at the island and drowned: the restore puts her at the island, and she
	# lands again, as the level's restore says she does.
	var restored := String(level.call("_restore_checkpoint"))
	var painting := level.get("_next_painting") as Node2D
	# Before a frame has run: walked into before she has landed again, it would be taken with the
	# level not listening.
	_check(not bool(painting.get("_armed")) and not bool(painting.call("is_taken")),
		"a restore disarms the painting until she lands again", "armed %s" % painting.get("_armed"))
	await _frames(120, ink, "_arrived")
	_check(restored == "CP4" and bool(level.get("_arrived")),
		"restored at the island, she lands again", "restored to '%s'; arrived %s"
			% [restored, level.get("_arrived")])

	# The landing is deferred and sets her on the sand mark, so let it finish before she walks.
	await _frames(30, ink)
	_place(painting.global_position + Vector2(0.0, -40.0))
	var overlay := level.get_node_or_null("LevelCompleteOverlay")
	for _frame in range(1200):
		await physics_frame
		if paused:
			await _unpause()
		if overlay != null and bool(overlay.call("is_open")):
			break
	_check(bool(painting.call("is_taken")) and overlay != null and bool(overlay.call("is_open")),
		"and walking into the painting ends the level",
		"taken %s; completion panel up %s" % [painting.call("is_taken"),
			overlay != null and bool(overlay.call("is_open"))])

	if failures == 0 and checked == CHECKS:
		print("OBRA_LEVEL3_ISLAND_ARRIVAL_OK")
		quit(0)
	else:
		print("OBRA_LEVEL3_ISLAND_ARRIVAL_FAILED=%d (%d of %d checks)" % [failures, checked, CHECKS])
		quit(1)


## Frames with the world running, the ink kept up so a held form never lapses into the water,
## and early out once `until` is true on the level.
func _frames(count: int, ink: Variant, until: String = "") -> void:
	for _frame in range(count):
		await physics_frame
		if paused:
			await _unpause()
		if ink != null:
			ink.call("add_ink", float(ink.get("capacity")))
		if not until.is_empty() and bool(level.get(until)):
			return


func _place(at: Vector2) -> void:
	var body := level.get("player") as Node2D
	if body == null or not is_instance_valid(body):
		return
	if body.has_method("apply_morph_state"):
		body.call("apply_morph_state", {"position": at, "linear_velocity": Vector2.ZERO})
	else:
		body.global_position = at


## Every open line and overlay closed, until the world has run two frames in a row.
func _unpause() -> void:
	for _attempt in range(60):
		for node in root.get_tree().get_nodes_in_group(&"modal_overlays"):
			if node.name == "LevelCompleteOverlay":
				continue
			if node.has_method("is_open") and bool(node.call("is_open")):
				node.call("close")
		call_group(DialogueBox.GROUP, &"hide_line")
		root.get_tree().paused = false
		await physics_frame
		if not root.get_tree().paused:
			await physics_frame
			if not root.get_tree().paused:
				return


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
