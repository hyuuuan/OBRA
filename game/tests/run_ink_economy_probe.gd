extends SceneTree
## The ink economy, priced against thesis FR-7 rather than against itself.
##
##   godot --headless --path game --script res://tests/run_ink_economy_probe.gd
##
## FR-7, in the manuscript's own words: "The system shall enforce a limited ink budget of
## six units. Creature transformation at a checkpoint is free. A tool costs one unit of ink
## on its first successful recognition, is then held in the toolbelt, and is thereafter
## selectable and reusable at no ink cost and with no redraw. A placeable object ... costs
## one unit of ink on each placement and is not retained."
##
## ⚠ WHY THIS FILE EXISTS RATHER THAN AN ASSERTION IN THE FINISH PROBE. The obvious place
## to check the budget is the suite that plays Payyo to the end, and it is the wrong place:
## `run_level1_finish_probe` hands itself items and calls `_judge_submission` directly, so
## it never touches the placement path and spends nothing at all. A budget assertion there
## reported "0 of 6 spent" and would have passed with the capacity set to zero. A green
## check over a path the test never walks is this project's most expensive recurring bug.
##
## So this one spends. Every number below is read back off the InkManager after the real
## call that should have moved it.

const OVERLOOK := Vector2(4250.0, 200.0)

var level: Node2D
var ink: InkManager
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-52s %s" % ["OK  " if ok else "FAIL", what, detail])


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout


## A drawing of `entity_id`, made the way the level makes one from a prediction.
func _drawn(entity_id: String) -> DrawnItemData:
	var registry := level.get("registry") as EntityRegistry
	var entry := registry.get_entity(entity_id)
	var item := DrawnItemData.new()
	item.entity_id = entity_id
	item.display_name = String(entry.get("display_name", entity_id))
	return item


## Put `entity_id` in the bag and set it down, through the level's own placement path.
func _place(entity_id: String, at: Vector2 = Vector2.ZERO) -> bool:
	var inventory := level.get("inventory_manager") as Node
	var placement := level.get("placement_controller") as Node2D
	var slot: int = inventory.call("add_item", _drawn(entity_id))
	if slot < 0:
		return false
	level.call("_on_inventory_slot_pressed", slot)
	await process_frame
	if not bool(placement.call("is_placing")):
		return false
	placement.set_process(false)
	placement.call("update_target",
		(OVERLOOK + Vector2(0.0, 40.0)) if at == Vector2.ZERO else at)
	for _frame in range(4):
		await physics_frame
	var ok: bool = placement.call("confirm_placement")
	for _frame in range(4):
		await physics_frame
	return ok


func _run() -> void:
	level = (load("res://game_level.tscn") as PackedScene).instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.2)
	ink = level.get("ink_manager") as InkManager
	var player := level.get("player") as Node2D
	player.global_position = OVERLOOK
	for _frame in range(20):
		await physics_frame

	_check(is_equal_approx(ink.capacity, 6.0),
		"the budget is six units", "%.0f" % ink.capacity)
	_check(is_equal_approx(InkManager.BUDGET, 6.0) and is_equal_approx(InkManager.UNIT, 1.0),
		"and one thing costs one unit",
		"BUDGET %.0f, UNIT %.0f" % [InkManager.BUDGET, InkManager.UNIT])

	# --- a placeable is priced on EVERY placement -------------------------------------
	ink.committed = 0.0
	var before := ink.committed
	var first: bool = await _place("ladder")
	var after_one := ink.committed
	_check(first and is_equal_approx(after_one - before, 1.0),
		"setting a placeable down costs one unit",
		"%.0f -> %.0f" % [before, after_one])
	# ⚠ CLEAR THE FIRST ONE OUT OF THE WAY FIRST. A ladder is 72x244 and the placement is
	# refused for want of room anywhere near where the last one is standing -- and a refused
	# placement is charged nothing, which reads exactly like the economy failing to charge.
	# The question here is the PRICE of a second placement, not whether two ladders fit on
	# one terrace, so the first is taken back out of the world by hand.
	var world_items := level.get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/WorldItemRoot") as Node2D
	for child in world_items.get_children():
		child.queue_free()
	for _frame in range(4):
		await physics_frame
	var second: bool = await _place("ladder")
	# ⚠ THE DETAIL HAS TO SAY WHICH FAILED. "1 -> 1" is true both when the placement was
	# charged nothing and when it never happened, and those are opposite bugs.
	_check(second and is_equal_approx(ink.committed - after_one, 1.0),
		"and setting the same one down again costs another",
		"%.0f -> %.0f  (FR-7: 'on each placement and is not retained')"
			% [after_one, ink.committed] if second
		else "the second placement was refused, so nothing was charged to test")

	# --- a tool is priced once, ever ---------------------------------------------------
	ink.committed = 0.0
	var profile := root.get_node_or_null("PlayerProfile")
	(profile.get("_data")["acquired_objects"] as Array).erase("axe")
	before = ink.committed
	level.call("_begin_new_utility", _drawn("axe"), true)
	await process_frame
	var after_tool := ink.committed
	_check(is_equal_approx(after_tool - before, 1.0),
		"a tool costs one unit the first time it is recognised",
		"%.0f -> %.0f" % [before, after_tool])
	# The second axe of the run comes out of the toolbelt free -- which is what the level
	# does when the class is already on the profile.
	var item := _drawn("axe")
	item.ink_committed = true
	level.call("_begin_new_utility", item, false)
	await process_frame
	_check(is_equal_approx(ink.committed, after_tool),
		"and never again after that",
		"still %.0f  (FR-7: 'no ink cost and no redraw')" % ink.committed)

	# --- a creature is free ------------------------------------------------------------
	ink.committed = 0.0
	level.call("_spawn_or_replace", "frog", "Frog", null, [])
	await _wait(0.4)
	_check(is_equal_approx(ink.committed, 0.0),
		"becoming a creature costs nothing",
		"%.0f spent  (FR-7: 'Creature transformation at a checkpoint is free')"
			% ink.committed)

	# --- an empty purse refuses, and says which doors are still open --------------------
	ink.committed = ink.capacity
	var refused: bool = await _place("ladder")
	_check(not refused, "an empty purse refuses a placement",
		"the ladder stayed in the bag" if not refused else "it was set down for free")
	_check(ink.committed <= ink.capacity + 0.0001,
		"and never runs a deficit", "%.0f of %.0f" % [ink.committed, ink.capacity])

	print("OBRA_INK_ECONOMY_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)
