extends SceneTree
## Dilim's satchel: Lola's things in stacks, the quick slots, and what a checkpoint keeps of them.
##
##   godot --headless --path game --script res://tests/run_satchel_probe.gd

const SatchelScript = preload("res://scripts/satchel.gd")

var failures := 0
var level: Node
var checked := 0
const CHECKS := 13


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		print("OBRA_SATCHEL_FAILED=watchdog")
		quit(2))
	_it_knows_lolas_five_things()
	_a_stack_stops_at_its_cap()
	_the_slots_fill_in_pickup_order()
	_a_spent_slot_goes_to_the_next_new_thing()
	_nothing_is_used_from_nothing()
	_it_is_kept_as_plain_data()
	_kept_data_is_held_to_the_file()
	level = await _open_level()
	await _z_pours_lamp_oil()
	await _oil_is_not_wasted_on_a_full_lamp()
	await _the_keys_stay_with_whoever_has_them()
	level.queue_free()
	await _frames(3)
	level = await _open_level()
	await _walking_into_one_takes_it()
	await _a_full_kind_leaves_it_lying()
	level.queue_free()
	await _frames(3)
	level = await _open_level()
	await _a_continue_does_not_find_a_taken_one()
	level.queue_free()
	await _frames(3)
	if checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_SATCHEL_OK")
		quit(0)
	else:
		print("OBRA_SATCHEL_FAILED=%d" % failures)
		quit(1)


func _it_knows_lolas_five_things() -> void:
	var satchel = SatchelScript.new()
	var ids: Array[String] = satchel.ids()
	_check(ids == ["asin", "abo", "bawang", "kandila", "langis"] and satchel.cap("asin") == 12
			and satchel.cap("langis") == 3,
		"it knows Lola's five things, with their caps", "%s" % [ids])


func _a_stack_stops_at_its_cap() -> void:
	var satchel = SatchelScript.new()
	var taken := int(satchel.add("asin", 20))
	var again := int(satchel.add("asin", 1))
	var stranger := int(satchel.add("feather", 1))
	_check(taken == 12 and again == 0 and satchel.count("asin") == 12 and stranger == 0,
		"a stack stops at its cap, and a stranger is not taken",
		"took %d of 20, then %d; a stranger %d" % [taken, again, stranger])


func _the_slots_fill_in_pickup_order() -> void:
	var satchel = SatchelScript.new()
	for id in ["bawang", "asin", "bawang", "kandila"]:
		satchel.add(id)
	_check(satchel.slots() == ["bawang", "asin", "kandila", ""] and satchel.count("bawang") == 2,
		"the quick slots fill in the order things are first picked up", "%s" % [satchel.slots()])


func _a_spent_slot_goes_to_the_next_new_thing() -> void:
	var satchel = SatchelScript.new()
	for id in ["bawang", "asin", "kandila", "abo"]:
		satchel.add(id)
	var full := satchel.slots()
	satchel.take("bawang")
	var held := satchel.slots()
	satchel.add("langis")
	_check(held == full and satchel.slots() == ["langis", "asin", "kandila", "abo"],
		"a spent slot stays put, then goes to the next new thing",
		"spent %s, then %s" % [held, satchel.slots()])


func _nothing_is_used_from_nothing() -> void:
	var satchel = SatchelScript.new()
	satchel.add("abo")
	var first := bool(satchel.take("abo"))
	var second := bool(satchel.take("abo"))
	_check(first and not second and satchel.count("abo") == 0, "nothing is used from nothing",
		"%s then %s" % [first, second])


## A checkpoint's run state drops any dictionary holding an object: plain counts and ids only,
## through JSON and back.
func _it_is_kept_as_plain_data() -> void:
	var satchel = SatchelScript.new()
	satchel.add("asin", 5)
	satchel.add("kandila")
	var saved: Variant = JSON.parse_string(JSON.stringify(satchel.to_data()))
	var back = SatchelScript.new()
	back.from_data(saved as Dictionary)
	_check(back.count("asin") == 5 and back.count("kandila") == 1 and back.slots() == satchel.slots(),
		"it is kept as plain data, and comes back the same", "%s" % [satchel.to_data()])


func _kept_data_is_held_to_the_file() -> void:
	var back = SatchelScript.new()
	back.from_data({"counts": {"asin": 99, "feather": 3}, "slots": ["feather", "asin", "", ""]})
	_check(back.count("asin") == 12 and back.count("feather") == 0 and back.slots() == ["", "asin", "", ""],
		"what comes back is held to the file: caps, and only its kinds",
		"asin %d, slots %s" % [back.count("asin"), back.slots()])


# --- In Dilim ---------------------------------------------------------------------------

## Z, as the keyboard sends it: the physical key the first quick slot is bound to.
func _press_z() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Z
	key.pressed = true
	level.call("_unhandled_input", key)
	await _frames(2)


func _z_pours_lamp_oil() -> void:
	var satchel = level.get("satchel")
	var health := level.get("player_health") as PlayerHealth
	satchel.add("langis", 1)
	health.dim(PlayerHealth.LOW)
	health.dim(PlayerHealth.LOW)
	var low := health.stage
	await _press_z()
	_check(low == PlayerHealth.LOW and health.stage == PlayerHealth.FULL and satchel.count("langis") == 0,
		"in Dilim, Z pours the lamp oil on its slot: two stages back",
		"stage %d -> %d, langis %d left" % [low, health.stage, satchel.count("langis")])


func _oil_is_not_wasted_on_a_full_lamp() -> void:
	var satchel = level.get("satchel")
	satchel.add("langis", 1)
	await _press_z()
	_check(satchel.count("langis") == 1, "and none is wasted on a full lantern",
		"langis %d" % satchel.count("langis"))


## While a drawing is being placed Z turns it; while one is drawn, or the bag is open, it is theirs.
func _the_keys_stay_with_whoever_has_them() -> void:
	var satchel = level.get("satchel")
	var health := level.get("player_health") as PlayerHealth
	health.dim(PlayerHealth.LOW)
	var kept: Array[String] = []
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	level.call("_on_drawing_ready", "campfire", "Campfire", sheet, {"confidence": 0.9},
		[{"points": PackedVector2Array([Vector2(0, 0), Vector2(40, 0)]), "width": 6.0, "color": Color.BLACK}], 1.0)
	await _frames(4)
	# Into the bag; setting it down starts from its slot.
	var slot := int(level.call("_slot_holding", "campfire"))
	if slot >= 0 and not bool((level.get("placement_controller") as Node).call("is_placing")):
		level.call("_on_inventory_slot_pressed", slot)
		await _frames(4)
	var placing := bool((level.get("placement_controller") as Node).call("is_placing"))
	await _press_z()
	if satchel.count("langis") == 1:
		kept.append("placing")
	(level.get("placement_controller") as Node).call("cancel_placement")
	await _frames(2)
	(level.get("draw_panel") as Node).call("open_panel")
	await _frames(2)
	await _press_z()
	if satchel.count("langis") == 1:
		kept.append("drawing")
	(level.get("draw_panel") as Node).call("close_panel")
	await _frames(2)
	(level.get("inventory_screen") as Node).call("open")
	await _frames(2)
	await _press_z()
	if satchel.count("langis") == 1:
		kept.append("the bag")
	(level.get("inventory_screen") as Node).call("close")
	await _frames(2)
	_check(placing and kept == ["placing", "drawing", "the bag"],
		"while placing, drawing or in the bag, Z is not the satchel's", "placing %s, kept for %s" % [placing, kept])


func _pickup(pickup_name: String) -> SatchelPickup2D:
	return level.get_node_or_null(NodePath("EnvironmentBaseplate/GameplayPlane/Pickups/" + pickup_name)) as SatchelPickup2D


## Walks her (Shift held: the santelmo is near) from `from` for `seconds`.
func _walk_her(from: float, seconds: float) -> void:
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": Vector2(from, 596.0), "linear_velocity": Vector2.ZERO})
	await _frames(6)
	Input.action_press(&"walk")
	Input.action_press(&"move_right")
	await _frames(int(seconds * 60.0))
	Input.action_release(&"move_right")
	Input.action_release(&"walk")
	await _frames(4)


func _walking_into_one_takes_it() -> void:
	var satchel = level.get("satchel")
	var pickup := _pickup("Asin1")
	await _walk_her(1000.0, 1.6)
	var said := (level.get("hint_bar") as HintBar).current_text()
	_check(satchel.count("asin") == 2 and (pickup == null or not is_instance_valid(pickup) or pickup.is_taken())
			and bool(level.call("pickup_taken_this_run", "L4_P_ASIN1")) and said.begins_with("Asin -- salt. It is on Z"),
		"walking into one takes it, and the first of a kind says its key",
		"asin %d, said \"%s\"" % [satchel.count("asin"), said])


func _a_full_kind_leaves_it_lying() -> void:
	var satchel = level.get("satchel")
	satchel.add("asin", 99)
	var pickup := _pickup("Asin2")
	await _walk_her(19650.0, 1.6)
	_check(satchel.count("asin") == 12 and pickup != null and is_instance_valid(pickup) and not pickup.is_taken(),
		"with no room for more, it stays where it lies", "asin %d, still there %s"
			% [satchel.count("asin"), pickup != null and is_instance_valid(pickup) and not pickup.is_taken()])


func _a_continue_does_not_find_a_taken_one() -> void:
	level.call("note_pickup_taken", "L4_P_KANDILA1")
	level.call("_show_taken_pickups")
	await _frames(2)
	var pickup := _pickup("Kandila1")
	_check(pickup == null or not is_instance_valid(pickup) or pickup.is_queued_for_deletion(),
		"a Continue does not find one this run already took", "kandila there %s"
			% (pickup != null and is_instance_valid(pickup) and not pickup.is_queued_for_deletion()))


func _open_level() -> Node:
	var scene := (load("res://level_4.tscn") as PackedScene).instantiate()
	(scene.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(scene)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(30)
	return scene


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		if paused:
			call_group(DialogueBox.GROUP, &"hide_line")
			paused = false


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
