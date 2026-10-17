extends SceneTree
## Dilim's satchel: Lola's things in stacks, the quick slots, and what a checkpoint keeps of them.
##
##   godot --headless --path game --script res://tests/run_satchel_probe.gd

const SatchelScript = preload("res://scripts/satchel.gd")

var failures := 0
var level: Node
var checked := 0
const CHECKS := 18


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
	level = await _open_level()
	await _falls_drop_by_their_chances()
	await _a_drop_is_taken_like_any_other()
	await _no_lamp_oil_falls_in_the_night()
	level.queue_free()
	await _frames(3)
	level = await _open_level()
	await _a_candle_lights_without_ink()
	await _a_candle_burns_down()
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


## An aswang standing still and asleep, far from her, to fall as often as a check needs.
func _sleeper(x: float) -> Enemy2D:
	var foe := GroundEnemy2D.new()
	foe.position = Vector2(x, 560.0)
	(level.get("entity_root") as Node2D).add_child(foe)
	return foe


## What fell since `before`, by kind: every pickup in the gameplay plane that is no placed one.
func _dropped() -> Dictionary:
	var counts: Dictionary = {}
	for node in level.find_children("*", "Area2D", true, false):
		var pickup := node as SatchelPickup2D
		if pickup != null and pickup.pickup_id.is_empty() and not pickup.is_taken():
			counts[pickup.item] = int(counts.get(pickup.item, 0)) + 1
	return counts


func _clear_drops() -> void:
	for node in level.find_children("*", "Area2D", true, false):
		var pickup := node as SatchelPickup2D
		if pickup != null and pickup.pickup_id.is_empty():
			pickup.free()


## Three hundred falls from a known stream: each kind near its share (within four deviations).
func _falls_drop_by_their_chances() -> void:
	level.call("set_drop_seed", 4401)
	var foe := _sleeper(9000.0)
	await _frames(2)
	for _fall in range(300):
		foe.died.emit(foe)
	await _frames(2)
	var counts := _dropped()
	var satchel = level.get("satchel")
	var off: Array[String] = []
	for id: String in satchel.ids():
		var chance := float(satchel.row(id).get("drop_chance", 0.0))
		var expected := 300.0 * chance
		var spread := 4.0 * sqrt(300.0 * chance * (1.0 - chance)) + 1.0
		if absf(float(counts.get(id, 0)) - expected) > spread:
			off.append("%s %d (about %.0f)" % [id, counts.get(id, 0), expected])
	_check(off.is_empty() and int(counts.get("asin", 0)) > int(counts.get("langis", 0)),
		"a fallen aswang drops Lola's things, each by its chance", "%s" % [counts] if off.is_empty()
		else "off: " + ", ".join(off))
	foe.queue_free()
	_clear_drops()
	await _frames(2)


## One that falls at her feet drops what she walks into and takes.
func _a_drop_is_taken_like_any_other() -> void:
	var satchel = level.get("satchel")
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": Vector2(9000.0, 596.0), "linear_velocity": Vector2.ZERO})
	await _frames(6)
	var before := 0
	for id: String in satchel.ids():
		before += satchel.count(id)
	var foe := _sleeper(9000.0)
	await _frames(2)
	level.call("set_drop_seed", 7)
	var tries := 0
	while _dropped().is_empty() and tries < 20:
		foe.died.emit(foe)
		tries += 1
		await _frames(1)
	await _frames(6)
	var after := 0
	for id: String in satchel.ids():
		after += satchel.count(id)
	_check(after > before, "and what falls at her feet she takes like any other",
		"held %d, then %d" % [before, after])
	foe.queue_free()
	_clear_drops()
	await _frames(2)


func _no_lamp_oil_falls_in_the_night() -> void:
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": Vector2(21520.0, 596.0), "linear_velocity": Vector2.ZERO})
	(level.get("player_health") as PlayerHealth).call("_start_grace", 600.0)
	await _frames(30)
	var night := bool((level.get("_finale") as Node).call("is_running"))
	level.call("set_drop_seed", 4402)
	var foe := _sleeper(9000.0)
	await _frames(2)
	for _fall in range(300):
		foe.died.emit(foe)
	await _frames(2)
	var counts := _dropped()
	_check(night and int(counts.get("langis", 0)) == 0 and int(counts.get("asin", 0)) > 0,
		"no lamp oil falls while the night runs", "night %s, %s" % [night, counts])
	foe.queue_free()
	_clear_drops()


# --- What each thing does ---------------------------------------------------------------

## The slot a kind sits on, used as its key would.
func _use(id: String) -> void:
	var satchel = level.get("satchel")
	level.call("use_quick_slot", satchel.slots().find(id))
	await _frames(2)


func _candles() -> Array[CandleFlame2D]:
	var out: Array[CandleFlame2D] = []
	for node in level.find_children("*", "Node2D", true, false):
		if node is CandleFlame2D and not node.is_queued_for_deletion():
			out.append(node)
	return out


func _a_candle_lights_without_ink() -> void:
	var satchel = level.get("satchel")
	var ink := level.get("ink_manager") as InkManager
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": Vector2(7000.0, 596.0), "linear_velocity": Vector2.ZERO})
	await _frames(6)
	satchel.add("kandila", 1)
	var before := ink.remaining()
	await _use("kandila")
	var candles := _candles()
	# Its own hole among the lights, not her lantern's: the lantern lights her wherever she is.
	var lit := 0.0
	for hole: Dictionary in LightField.holes_in(self):
		if not candles.is_empty() and absf(float(hole.get("radius", 0.0)) - 220.0) < 2.0 \
				and (hole["position"] as Vector2).distance_to(candles[0].global_position) < 40.0:
			lit = LightField.contribution(hole, player.global_position + Vector2(0.0, -40.0))
	_check(candles.size() == 1 and candles[0].global_position.distance_to(player.global_position) < 8.0
			and is_equal_approx(candles[0].radius, 220.0) and lit > 0.9 and is_equal_approx(ink.remaining(), before)
			and satchel.count("kandila") == 0,
		"a candle from its slot is lit at her feet, a light that costs no ink",
		"%d candle(s), lit %.2f, ink %.1f -> %.1f" % [candles.size(), lit, before, ink.remaining()])


func _a_candle_burns_down() -> void:
	var candles := _candles()
	var lit := candles[0].seconds_left() if not candles.is_empty() else 0.0
	# Shrinking, on one well short of its last guttering seconds; gone, on one a second long.
	var long := CandleFlame2D.new()
	long.seconds = 20.0
	var short := CandleFlame2D.new()
	short.seconds = 1.0
	(level.get("entity_root") as Node2D).add_child(long)
	(level.get("entity_root") as Node2D).add_child(short)
	await _frames(30)
	var halfway := long.light_radius()
	await _frames(60)
	long.queue_free()
	_check(lit > 44.0 and lit <= 45.0 and halfway < 219.5 and halfway > 210.0 and not is_instance_valid(short),
		"it burns down, its light shrinking, and is gone", "%.1f s left of 45; half a second in, %.1f px; a one-second candle gone %s"
			% [lit, halfway, not is_instance_valid(short)])


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
