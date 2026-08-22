extends SceneTree
## Beat 0, walked rather than solved on paper.
##
##	 godot --headless --path game --script res://tests/run_walk_level1.gd
##
## run_level1_audit proves the obstacle ACCEPTS a square: it calls _judge_submission and
## reads the director's answer. That is a statement about bookkeeping. It says nothing
## about whether a player who draws the square can then put it somewhere and climb it,
## which is the only question Beat 0 actually asks -- and the answer was no, because every
## click aimed at the foot of the stair was landing in the inventory bar.
##
## So this one drives the character: place the step, then hold the keys a player holds and
## see where the body ends up.

const WandererClass = preload("res://scripts/wanderer.gd")
const StairTreadClass = preload("res://scripts/stair_tread_2d.gd")
## Read off the level, not restated here: a test that carries its own copy of the
## geometry stops testing the geometry the moment somebody moves it.
var tread_top := 0.0
var bank_top := 0.0

var passes := 0
var failures := 0
var results: Array[String] = []

var level: Node
var player: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://game_level.tscn") as PackedScene
	level = packed.instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	for _frame in range(30):
		await physics_frame
	player = level.get("player") as Node2D
	var hagdan := level.get_node_or_null("EnvironmentBaseplate/GameplayPlane/Hagdan")
	var bank := level.get_node_or_null(
		"EnvironmentBaseplate/GameplayPlane/Terrain/LowerRight") as Node2D
	if hagdan != null and bank != null:
		bank_top = bank.global_position.y
		for child in hagdan.get_children():
			if child.get_script() == StairTreadClass and not bool(child.get("is_broken")):
				tread_top = maxf(tread_top, float(child.call("surface_y")))
	if player == null:
		print("OBRA_WALK_L1_FAILED=1  (no player)")
		quit(1)
		return

	var jump_height: float = pow(WandererClass.JUMP_VELOCITY, 2.0) / (2.0 * float(
		ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)))
	_check(bank_top - tread_top > jump_height, "the stair is a real gate",
		"%.0fpx of rise against a %.0fpx jump" % [bank_top - tread_top, jump_height])

	await _cannot_be_climbed_bare()
	await _can_be_climbed_with_a_step()

	print("\n===== BEAT 0 WALKTHROUGH =====")
	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_WALK_L1_OK")
		quit(0)
	else:
		print("OBRA_WALK_L1_FAILED=%d" % failures)
		quit(1)


## The beat has to ASK for something. If the bare stair can be climbed, Beat 0 is scenery.
func _cannot_be_climbed_bare() -> void:
	_stand_on_the_bank()
	var reached := await _run_at_the_stair()
	_check(not reached, "the bare stair cannot be climbed",
		"the player is still below it after 4s of running and jumping" if not reached
		else "CLIMBED IT -- the beat asks for nothing")


## And it has to be answerable. A step is placed at the foot of the stair, which is what
## the player does after drawing something that spans the gap.
func _can_be_climbed_with_a_step() -> void:
	var inventory := level.get("inventory_manager") as Node
	var placement := level.get("placement_controller") as Node2D
	_stand_on_the_bank()

	var item := DrawnItemData.new()
	item.entity_id = "square"
	item.display_name = "Square"
	var slot: int = inventory.call("add_item", item)
	level.call("_on_inventory_slot_pressed", slot)
	await process_frame
	if not bool(placement.call("is_placing")):
		_fail("placing the step", "the placement never started")
		return

	# In the gap the missing stones left, which is the only place it helps:
	# clear of the surviving tread that overhangs the bank to the right.
	# The controller re-aims at the live cursor every frame in _process, and a
	# headless run has no cursor -- the preview was being dragged to (0,0) and
	# clamped to the reach radius, which put the step in the paddy. Hold the aim.
	placement.set_process(false)
	placement.call("update_target", Vector2(712.0, 505.0))
	for _frame in range(4):
		await physics_frame
	var placed: bool = placement.call("confirm_placement")
	_check(placed, "a step can be set down at the foot of the stair",
		"placed" if placed else "REFUSED -- there is nowhere to put it")
	if not placed:
		return

	var reached := await _run_at_the_stair()
	_check(reached, "and the stair can then be climbed",
		"the player reached the top" if reached
		else "STILL STUCK -- the step is down and the beat is unbeatable")


## Hold right, tap jump, the way a person does it. Polled input, so the actions are held
## through the Input singleton rather than fed as events.
func _run_at_the_stair() -> bool:
	Input.action_press(&"move_right")
	# STANDING on the stone, not passing over it. A peak height alone is satisfied by a
	# jump that clears the tread and lands back where it started, which is the failure
	# this is meant to catch.
	var arrived := false
	for frame in range(240):
		if frame % 24 == 0:
			Input.action_press(&"jump")
		elif frame % 24 == 18:
			Input.action_release(&"jump")
		await physics_frame
		if bool(player.call("is_on_floor")) and player.global_position.y <= tread_top + 2.0:
			arrived = true
			break
	Input.action_release(&"move_right")
	Input.action_release(&"jump")
	return arrived


## On the bank below the gap, standing still.
func _stand_on_the_bank() -> void:
	player.set("velocity", Vector2.ZERO)
	player.global_position = Vector2(645.0, bank_top - 40.0)
	for _frame in range(20):
		await physics_frame


func _check(ok: bool, what: String, detail: String) -> void:
	if ok:
		passes += 1
		results.append("  OK	%s	%s" % [what, detail])
	else:
		_fail(what, detail)


func _fail(what: String, detail: String) -> void:
	failures += 1
	results.append("  FAIL	%s	%s" % [what, detail])
