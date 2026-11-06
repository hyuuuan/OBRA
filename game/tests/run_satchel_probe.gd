extends SceneTree
## Dilim's satchel: Lola's things in stacks, the quick slots, and what a checkpoint keeps of them.
##
##   godot --headless --path game --script res://tests/run_satchel_probe.gd

const SatchelScript = preload("res://scripts/satchel.gd")

var failures := 0
var level: Node
var checked := 0
const CHECKS := 59


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		print("OBRA_SATCHEL_FAILED=watchdog")
		quit(2))
	_it_knows_lolas_six_things()
	_each_says_what_it_is_for()
	_a_stack_stops_at_its_cap()
	_the_slots_fill_in_pickup_order()
	_a_spent_slot_goes_to_the_next_new_thing()
	_the_five_in_the_woods_all_have_a_slot()
	_a_sixth_kind_waits_then_moves_in()
	_nothing_is_used_from_nothing()
	_it_is_kept_as_plain_data()
	_kept_data_is_held_to_the_file()
	_an_old_save_gives_the_oil_its_slot()
	level = await _open_level()
	await _z_pours_lamp_oil()
	await _oil_is_not_wasted_on_a_full_lamp()
	await _the_keys_stay_with_whoever_has_them()
	level.queue_free()
	await _frames(3)
	level = await _open_level()
	await _b_pours_the_oil_found_last()
	level.queue_free()
	await _frames(3)
	level = await _open_level()
	var bar_before := (level.get("quick_slots") as QuickSlotBar).visible
	await _its_name_shows_as_she_nears()
	await _walking_into_one_takes_it()
	await _the_bar_comes_with_the_first_find(bar_before)
	await _a_new_kind_lights_its_slot()
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
	level = await _open_level()
	await _without_a_ward_it_reaches_her()
	await _a_ward_holds_it_off()
	await _a_spent_ward_lets_it_in()
	level.queue_free()
	await _frames(3)
	level = await _open_level()
	await _salt_burns_what_it_lands_on()
	await _salt_goes_the_way_she_faces()
	await _salt_falls_short_of_what_is_far()
	level.queue_free()
	await _frames(3)
	level = await _open_level()
	await _ash_blinds_what_is_near()
	await _ash_shows_what_hides()
	level.queue_free()
	await _frames(3)
	level = await _open_level()
	await _the_oil_is_asked_for_when_the_lamp_is_low()
	await _a_press_that_does_nothing_says_why()
	level.queue_free()
	await _frames(3)
	level = await _open_level()
	await _a_candle_where_a_drawing_is_asked_says_so()
	await _salt_and_garlic_are_asked_for_when_they_would_help()
	level.queue_free()
	await _frames(3)
	level = await _open_level()
	await _ash_is_asked_for_only_within_its_reach()
	level.queue_free()
	await _frames(3)
	level = await _open_level()
	await _the_sixth_thing_says_it_has_no_slot()
	await _the_bar_steps_back_for_a_line()
	level.queue_free()
	await _frames(3)
	level = await _open_level(true)
	await _a_knockout_keeps_what_she_carries()
	level.queue_free()
	await _frames(3)
	level = await _open_level(true)
	await _a_continue_gives_it_back()
	await _the_controls_screen_names_the_slots()
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


## Five, then six: the buntot pagi came with the finale, one at a time (cap 1).
func _it_knows_lolas_six_things() -> void:
	var satchel = SatchelScript.new()
	var ids: Array[String] = satchel.ids()
	_check(ids == ["asin", "abo", "bawang", "kandila", "langis", "buntot_pagi"] and satchel.cap("asin") == 12
			and satchel.cap("langis") == 3 and satchel.cap("buntot_pagi") == 1,
		"it knows Lola's six things, with their caps", "%s" % [ids])


## Found, each says what it does and which key it is on -- never only its name -- and when it is for.
func _each_says_what_it_is_for() -> void:
	var satchel = SatchelScript.new()
	var silent: Array[String] = []
	for id: String in satchel.ids():
		var said := String(satchel.row(id).get("found", ""))
		var name := String(satchel.row(id).get("display_name", id))
		if not said.contains("{key}") or not said.begins_with(name) or said.length() < name.length() + 24:
			silent.append(id)
	_check(silent.is_empty(), "each of Lola's things, found, says what it does and its key",
		"all six" if silent.is_empty() else "only named: %s" % [silent])
	# The things it took a player to be told are the ones the old words left out.
	var said := {}
	for id: String in satchel.ids():
		said[id] = String(satchel.row(id).get("found", "")).to_lower()
	_check(said["abo"].contains("keep it") and said["langis"].contains("low")
			and said["kandila"].contains("when the lamp is low") and said["bawang"].contains("ten seconds")
			and said["asin"].contains("ahead of me"),
		"and when: ash kept for what she cannot see, oil and the candle for a low lamp, garlic's ten seconds",
		"%s" % [said])


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
	_check(satchel.slots() == ["bawang", "asin", "kandila", "", ""] and satchel.count("bawang") == 2,
		"the quick slots fill in the order things are first picked up", "%s" % [satchel.slots()])


func _a_spent_slot_goes_to_the_next_new_thing() -> void:
	var satchel = SatchelScript.new()
	for id in ["bawang", "asin", "kandila", "abo", "langis"]:
		satchel.add(id)
	var full := satchel.slots()
	satchel.take("bawang")
	var held := satchel.slots()
	satchel.add("buntot_pagi")
	_check(held == full and satchel.slots() == ["buntot_pagi", "asin", "kandila", "abo", "langis"],
		"a spent slot stays put, then goes to the next new thing",
		"spent %s, then %s" % [held, satchel.slots()])


## Kent's fifth key. Whoever saves everything still has a key for everything the woods give: with
## four slots the lamp oil, found last, could never be poured.
func _the_five_in_the_woods_all_have_a_slot() -> void:
	var satchel = SatchelScript.new()
	for id in ["asin", "kandila", "abo", "bawang", "langis"]:
		satchel.add(id)
	_check(satchel.slots() == ["asin", "kandila", "abo", "bawang", "langis"] and satchel.waiting().is_empty(),
		"everything lying in the woods, saved in the order it is found, has a slot",
		"%s, waiting %s" % [satchel.slots(), satchel.waiting()])


## All five held, the whip has no key -- and takes the first slot spent, at once, not on the next
## pickup, which for a thing that drops once in a night might never come.
func _a_sixth_kind_waits_then_moves_in() -> void:
	var satchel = SatchelScript.new()
	for id in ["asin", "kandila", "abo", "bawang", "langis", "buntot_pagi"]:
		satchel.add(id)
	var waited: Array[String] = satchel.waiting()
	set_meta(&"moved_in", [])
	satchel.moved_in.connect(func(id: String, index: int) -> void:
		(get_meta(&"moved_in") as Array).append([id, index]))
	satchel.take("kandila")
	var said: Array = get_meta(&"moved_in")
	_check(waited == ["buntot_pagi"] and satchel.slots() == ["asin", "buntot_pagi", "abo", "bawang", "langis"]
			and satchel.waiting().is_empty() and said == [["buntot_pagi", 1]],
		"a sixth kind waits with no slot, and moves in as soon as one is spent",
		"waited %s, then %s, said %s" % [waited, satchel.slots(), said])


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
	# What it hands over is a copy: emptying the satchel afterwards must not empty what was kept.
	var kept: Dictionary = satchel.to_data()
	satchel.from_data({})
	_check((kept["slots"] as Array).has("asin") and int((kept["counts"] as Dictionary).get("asin", 0)) == 5,
		"and what it keeps is a copy, not the satchel itself", "kept %s" % [kept])


## A save from when there were four slots: four listed, and the oil carried with none.
func _an_old_save_gives_the_oil_its_slot() -> void:
	var back = SatchelScript.new()
	back.from_data({"counts": {"asin": 1, "kandila": 1, "abo": 1, "bawang": 1, "langis": 2},
		"slots": ["asin", "kandila", "abo", "bawang"]})
	_check(back.slots() == ["asin", "kandila", "abo", "bawang", "langis"] and back.waiting().is_empty()
			and back.count("langis") == 2,
		"a save from when there were four slots gives the oil it carried the new one",
		"%s, waiting %s" % [back.slots(), back.waiting()])


func _kept_data_is_held_to_the_file() -> void:
	var back = SatchelScript.new()
	back.from_data({"counts": {"asin": 99, "feather": 3}, "slots": ["feather", "asin", "", ""]})
	_check(back.count("asin") == 12 and back.count("feather") == 0 and back.slots() == ["", "asin", "", "", ""],
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


func _press_key(code: Key) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = true
	level.call("_unhandled_input", key)
	await _frames(2)


## The fifth key, as the keyboard sends it, on the thing the fifth slot was added for.
func _b_pours_the_oil_found_last() -> void:
	var satchel := level.get("satchel") as Satchel
	var health := level.get("player_health") as PlayerHealth
	for id in ["asin", "kandila", "abo", "bawang", "langis"]:
		satchel.add(id, 1)
	health.dim(PlayerHealth.LOW)
	health.dim(PlayerHealth.LOW)
	var low := health.stage
	var bar := level.get("quick_slots") as QuickSlotBar
	await _press_key(KEY_B)
	_check(satchel.slots()[4] == "langis" and low == PlayerHealth.LOW and health.stage == PlayerHealth.FULL
			and satchel.count("langis") == 0 and bar.slot_name(4) == "Langis",
		"B pours the oil she found last, on the fifth slot", "stage %d -> %d, slot %s, %d left"
			% [low, health.stage, satchel.slots()[4], satchel.count("langis")])
	var unbound: Array[String] = []
	for index in range(Satchel.SLOTS):
		if not InputMap.has_action("quick_slot_%d" % (index + 1)):
			unbound.append(str(index + 1))
	var file_says := int((JSON.parse_string(FileAccess.get_file_as_string(Satchel.CONFIG)) as Dictionary).get("quick_slots", 0))
	_check(unbound.is_empty() and file_says == Satchel.SLOTS, "and every slot has a key bound, as many as the file says",
		"%d slots, the file says %d, unbound %s" % [Satchel.SLOTS, file_says, unbound])


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


## Far off it is a glint; near, its name stands over it; taken, the name goes with it.
func _its_name_shows_as_she_nears() -> void:
	var pickup := _pickup("Asin1")
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": Vector2(2300.0 - SatchelPickup2D.TAG_NEAR - 120.0, 596.0),
		"linear_velocity": Vector2.ZERO})
	await _frames(30)
	var far := pickup.tag_shown()
	player.call("apply_morph_state", {"position": Vector2(2300.0 - SatchelPickup2D.TAG_NEAR + 80.0, 596.0),
		"linear_velocity": Vector2.ZERO})
	await _frames(30)
	var near := pickup.tag_shown()
	_check(far == 0.0 and near == 1.0 and pickup.title == "Asin · salt",
		"one of Lola's things shows its name as she nears it, and not from afar",
		"far %.2f, near %.2f, \"%s\"" % [far, near, pickup.title])
	# Taken, its name goes at once -- not back for the moment the thing itself takes to lift away.
	var spare := SatchelPickup2D.new()
	spare.item = "abo"
	spare.title = "Abo · ash"
	spare.position = pickup.position + Vector2(-60.0, -120.0)
	pickup.get_parent().add_child(spare)
	await _frames(30)
	var spare_near := spare.tag_shown()
	spare.take()
	await _frames(6)
	_check(spare_near == 1.0 and is_instance_valid(spare) and spare.tag_shown() == 0.0,
		"and taken, its name goes at once", "near %.2f, lifting %.2f" % [spare_near,
			spare.tag_shown() if is_instance_valid(spare) else -1.0])


func _walking_into_one_takes_it() -> void:
	var satchel = level.get("satchel")
	var pickup := _pickup("Asin1")
	await _walk_her(2200.0, 1.6)
	var said := (level.get("hint_bar") as HintBar).current_text()
	_check(satchel.count("asin") == 2 and (pickup == null or not is_instance_valid(pickup)
			or (pickup.is_taken() and pickup.tag_shown() == 0.0))
			and bool(level.call("pickup_taken_this_run", "L4_P_ASIN1")) and said == "Asin, salt. Z throws it ahead of me, and it burns whatever it lands on.",
		"walking into one takes it, and the first of a kind says what it does and its key",
		"asin %d, said \"%s\"" % [satchel.count("asin"), said])


## No slots before there is anything to put in them; the first find brings the bar, and a
## checkpoint from before that find takes it away again.
func _the_bar_comes_with_the_first_find(shown_before: bool) -> void:
	var bar := level.get("quick_slots") as QuickSlotBar
	var shown_after := bar.visible
	_check(not shown_before and shown_after, "the quick slots are not on screen until the first find brings them",
		"before %s, after %s" % [shown_before, shown_after])
	var names := [bar.slot_name(0), bar.slot_does(0), bar.slot_name(1), bar.slot_does(1)]
	_check(names == ["Asin", "Burns them", "", ""]
			and bar.size.y >= bar.slot_rect(0).end.y + QuickSlotBar.NAME_GAP + QuickSlotBar.NAME_ROW * 2.0,
		"a filled slot says under it what it is and what it does, inside the bar; an empty one is silent",
		"%s, bar %.0f tall" % [names, bar.size.y])
	# Held to the floor, and to the room each slot has: no name brought down to fit any more.
	var font := bar.get_theme_default_font()
	var room := QuickSlotBar.SLOT.x + QuickSlotBar.GAP - 4.0
	var over: Array[String] = []
	for id: String in (level.get("satchel") as Satchel).ids():
		for text: String in [String((level.get("satchel") as Satchel).row(id).get("display_name", "")),
				String((level.get("satchel") as Satchel).row(id).get("does", ""))]:
			if text.is_empty() or font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, QuickSlotBar.NAME_FONT).x > room:
				over.append("%s '%s'" % [id, text])
	_check(over.is_empty() and QuickSlotBar.CAP_FONT >= 20 and QuickSlotBar.COUNT_FONT >= 20
			and QuickSlotBar.NAME_FONT >= 20,
		"the key, the count, every name and every use read at 20 px and fit under their slots",
		"room %.0f px" % room if over.is_empty() else "too long or missing: %s" % [over])
	var kept: Dictionary = (level.get("satchel") as Satchel).to_data().duplicate(true)
	(level.get("satchel") as Satchel).from_data({})
	await _frames(2)
	var emptied := bar.visible
	(level.get("satchel") as Satchel).from_data(kept)
	await _frames(2)
	_check(not emptied and bar.visible, "a checkpoint from before the find takes them away, and one after brings them back",
		"emptied %s, restored %s" % [emptied, bar.visible])


## The first of a kind rings its slot long enough to be looked for; a second of it does not.
func _a_new_kind_lights_its_slot() -> void:
	var bar := level.get("quick_slots") as QuickSlotBar
	var satchel := level.get("satchel") as Satchel
	var first := await _touch_a_new("kandila")
	var slot := satchel.slots().find("kandila")
	var welcomed := bar.is_welcoming(slot)
	await _frames(int((QuickSlotBar.WELCOME_SECONDS + 0.2) * 60.0))
	var after := bar.is_welcoming(slot)
	await _touch_a_new("kandila")
	_check(first and welcomed and not after and not bar.is_welcoming(slot),
		"the first of a kind rings its slot for a while; a second of it does not",
		"first %s, after %.1f s %s, again %s" % [welcomed, QuickSlotBar.WELCOME_SECONDS + 0.2, after,
			bar.is_welcoming(slot)])


func _touch_a_new(id: String) -> bool:
	var pickup := SatchelPickup2D.new()
	pickup.item = id
	_pickup("Asin2").get_parent().add_child(pickup)
	await _frames(2)
	level.call("_on_pickup_touched", pickup)
	await _frames(2)
	return pickup.is_taken()


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


const WARD_X := 5800.0


## Her at WARD_X in a long grace, and an aswang awake 300 px off; its nearest approach in `seconds`.
func _how_near_it_comes(seconds: float, foe: Enemy2D = null) -> Array:
	var player := level.get("player") as Node2D
	if foe == null:
		player.call("apply_morph_state", {"position": Vector2(WARD_X, 596.0), "linear_velocity": Vector2.ZERO})
		(level.get("player_health") as PlayerHealth).call("_start_grace", 600.0)
		await _frames(6)
		foe = GroundEnemy2D.new()
		foe.position = Vector2(WARD_X + 300.0, 560.0)
		(level.get("entity_root") as Node2D).add_child(foe)
	var nearest := INF
	for _frame in range(int(seconds * 60.0)):
		await _frames(1)
		nearest = minf(nearest, absf(foe.global_position.x - WARD_X))
	return [nearest, foe]


func _without_a_ward_it_reaches_her() -> void:
	var seen: Array = await _how_near_it_comes(3.0)
	(seen[1] as Node).queue_free()
	await _frames(2)
	_check(float(seen[0]) < 100.0, "without a ward, an aswang reaches her", "%.0f px" % float(seen[0]))


func _a_ward_holds_it_off() -> void:
	var satchel = level.get("satchel")
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": Vector2(WARD_X, 596.0), "linear_velocity": Vector2.ZERO})
	await _frames(6)
	satchel.add("bawang", 1)
	await _use("bawang")
	var ward: BawangWard2D = null
	for node in level.find_children("*", "Node2D", true, false):
		if node is BawangWard2D:
			ward = node
	var seen: Array = await _how_near_it_comes(3.0)
	_check(ward != null and absf(ward.global_position.x - WARD_X) < 8.0 and float(seen[0]) >= 140.0,
		"a ward of bawang at her feet holds it off at its edge", "nearest %.0f px of a 150 px ward" % float(seen[0]))
	# Three seconds into ten: the ring has closed by that much, and it is drawn over the dark.
	_check(ward != null and ward.ring_layer() > DarknessLayer.LAYER and absf(ward.ring_share() - 0.7) < 0.05,
		"and its ring stands over the dark, closing as it runs out",
		"layer %d over %d, %.2f of it left" % [ward.ring_layer(), DarknessLayer.LAYER, ward.ring_share()])
	set_meta(&"held_foe", seen[1])
	if ward != null:
		ward.queue_free()
	await _frames(2)


func _a_spent_ward_lets_it_in() -> void:
	var foe := get_meta(&"held_foe") as Enemy2D
	var short := BawangWard2D.new()
	short.seconds = 1.0
	short.position = Vector2(WARD_X, 600.0)
	level.get_node(^"EnvironmentBaseplate/GameplayPlane").add_child(short)
	var held: Array = await _how_near_it_comes(0.8, foe)
	var after: Array = await _how_near_it_comes(2.5, foe)
	_check(float(held[0]) >= 140.0 and not is_instance_valid(short) and float(after[0]) < 100.0,
		"and once it is spent, it comes in", "held at %.0f, then %.0f px" % [float(held[0]), float(after[0])])
	foe.queue_free()
	await _frames(2)


## An aswang `ahead` px from her, asleep and still until it is touched -- sight 0 keeps it from
## coming for her and spoiling the count.
func _still_aswang(ahead: float) -> Enemy2D:
	var foe := GroundEnemy2D.new()
	foe.position = Vector2(WARD_X + ahead, 586.0)
	(level.get("entity_root") as Node2D).add_child(foe)
	foe.sight = 0.0
	return foe


## Facing right or left: a tap of the key.
func _face(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(6)


func _salt_burns_what_it_lands_on() -> void:
	var satchel = level.get("satchel")
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": Vector2(WARD_X, 596.0), "linear_velocity": Vector2.ZERO})
	(level.get("player_health") as PlayerHealth).call("_start_grace", 600.0)
	await _frames(6)
	await _face(&"move_right")
	var foe := _still_aswang(200.0)
	await _frames(4)
	satchel.add("asin", 2)
	await _use("asin")
	await _frames(int(0.8 * 60.0))
	var landed := foe.is_burning()
	var hp_at_once := foe.hp
	await _frames(int(2.0 * 60.0))
	_check(landed and hp_at_once >= foe.max_hp - 1 and foe.hp == foe.max_hp - 3 and satchel.count("asin") == 1,
		"thrown salt lands on an aswang ahead and burns it, three ticks over time",
		"burning %s; hp %d of %d soon after, %d at the end" % [landed, hp_at_once, foe.max_hp, foe.hp])
	foe.queue_free()
	await _frames(2)


func _salt_goes_the_way_she_faces() -> void:
	await _face(&"move_left")
	var foe := _still_aswang(200.0)
	await _frames(4)
	await _use("asin")
	await _frames(int(1.6 * 60.0))
	_check(not foe.is_burning() and foe.hp == foe.max_hp, "and it goes the way she faces",
		"facing away, the one behind her: burning %s, hp %d" % [foe.is_burning(), foe.hp])
	foe.queue_free()
	await _frames(2)


## Each alone, so the near one cannot take a throw meant to be measured against the far one.
func _salt_falls_short_of_what_is_far() -> void:
	await _face(&"move_right")
	var burnt: Array[bool] = []
	for ahead in [280.0, 420.0]:
		var foe := _still_aswang(ahead)
		await _frames(4)
		(level.get("satchel")).add("asin", 1)
		await _use("asin")
		await _frames(int(1.0 * 60.0))
		burnt.append(foe.is_burning())
		foe.queue_free()
		await _frames(2)
	_check(burnt == [true, false], "and it lands near its reach, no further",
		"at 280 px burning %s, at 420 px %s" % [burnt[0], burnt[1]])


## One awake and coming for her 120 px off, one 300 px off: the near one blinded and still for the
## moment, then hunting again; the far one never touched.
func _ash_blinds_what_is_near() -> void:
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": Vector2(WARD_X, 596.0), "linear_velocity": Vector2.ZERO})
	(level.get("player_health") as PlayerHealth).call("_start_grace", 600.0)
	await _frames(6)
	var near := GroundEnemy2D.new()
	near.position = Vector2(WARD_X + 120.0, 586.0)
	var far := GroundEnemy2D.new()
	far.position = Vector2(WARD_X - 300.0, 586.0)
	(level.get("entity_root") as Node2D).add_child(near)
	(level.get("entity_root") as Node2D).add_child(far)
	await _frames(3)
	(level.get("satchel")).add("abo", 1)
	await _use("abo")
	var blinded := near.state_name() == "STUN"
	var far_untouched := far.state_name() != "STUN"
	var at := near.global_position.x
	await _frames(int(1.2 * 60.0))
	var still := absf(near.global_position.x - at) < 4.0 and near.state_name() == "STUN"
	await _frames(int(0.6 * 60.0))
	var hunting := near.state_name() != "STUN"
	_check(blinded and still and hunting and far_untouched,
		"ash blinds the aswang near her, and it stands still for the moment",
		"blinded %s, still %s, hunting after %s; the far one untouched %s" % [blinded, still, hunting, far_untouched])
	near.queue_free()
	far.queue_free()
	await _frames(2)


## Something that hides in the dark, standing within the dust: asked to show itself, for six seconds.
func _ash_shows_what_hides() -> void:
	var hiding := GDScript.new()
	hiding.source_code = "extends Node2D\nvar shown := 0.0\nfunc reveal(seconds: float) -> void:\n\tshown = seconds\n"
	hiding.reload()
	var hider := Node2D.new()
	hider.set_script(hiding)
	hider.position = Vector2(WARD_X + 80.0, 560.0)
	hider.add_to_group(AboDust2D.REVEALS)
	(level.get("entity_root") as Node2D).add_child(hider)
	(level.get("satchel")).add("abo", 1)
	await _use("abo")
	_check(is_equal_approx(float(hider.get(&"shown")), 6.0), "and shows what hides in shadow, for six seconds",
		"shown for %.1f s" % float(hider.get(&"shown")))
	hider.queue_free()


## Seen in a window: the row of names stood half out from under the story box. It steps back as the
## other pieces along the bottom do, and comes back after. Frames counted here by hand: a line stops
## the tree, and this probe's own wait lets it go.
func _the_bar_steps_back_for_a_line() -> void:
	var bar := level.get("quick_slots") as QuickSlotBar
	var box := level.get("dialogue_box") as Node
	var before := bar.modulate.a
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", false)
	box.call("speak", [{"text": "Listen.", "speaker": "Apo", "at": "apo"}])
	for _frame in range(40):
		await physics_frame
	var during := bar.modulate.a
	call_group(DialogueBox.GROUP, &"hide_line")
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	paused = false
	await _frames(40)
	_check(before == 1.0 and during == 0.0 and bar.modulate.a == 1.0,
		"the quick slots step back under a line of story, and come back after",
		"%.2f, then %.2f, then %.2f" % [before, during, bar.modulate.a])


# --- When each one is the thing to press --------------------------------------------------

func _said() -> String:
	var hints := level.get("hint_bar") as HintBar
	return hints.current_text() if hints.is_showing() else ""


func _quiet() -> void:
	(level.get("hint_bar") as HintBar).clear()
	# Showing until its fade ends.
	await _frames(12)


func _stand_her_at(x: float) -> void:
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": Vector2(x, 596.0), "linear_velocity": Vector2.ZERO})
	(level.get("player_health") as PlayerHealth).call("_start_grace", 600.0)
	await _frames(6)


## Not lit on a full lamp, lit and said with its key once it burns low, and said once only.
func _the_oil_is_asked_for_when_the_lamp_is_low() -> void:
	var satchel := level.get("satchel") as Satchel
	var health := level.get("player_health") as PlayerHealth
	var bar := level.get("quick_slots") as QuickSlotBar
	await _stand_her_at(7800.0)
	health.reset_full()
	satchel.add("langis", 2)
	var slot := satchel.slots().find("langis")
	await _quiet()
	await _frames(45)
	var at_full := bar.is_wanted(slot)
	health.dim(PlayerHealth.LOW)
	health.dim(PlayerHealth.LOW)
	await _frames(4)
	var low := bar.is_wanted(slot)
	var said := _said()
	await _quiet()
	await _frames(4)
	var again := _said()
	_check(not at_full and health.stage == PlayerHealth.LOW and low
			and said == "The lamp is low. %s pours the oil." % _key_on(slot) and again.is_empty(),
		"the oil's slot is not lit on a full lamp; burning low it says Now, with its key, once",
		"full %s, low %s, said \"%s\", then \"%s\"" % [at_full, low, said, again])


func _key_on(slot: int) -> String:
	return String(level.call("_slot_key", slot))


## Oil on a full lamp, and a slot gone empty: each says so and shakes, and spends nothing.
func _a_press_that_does_nothing_says_why() -> void:
	var satchel := level.get("satchel") as Satchel
	var health := level.get("player_health") as PlayerHealth
	var bar := level.get("quick_slots") as QuickSlotBar
	health.reset_full()
	var slot := satchel.slots().find("langis")
	var had := satchel.count("langis")
	await _quiet()
	level.call("use_quick_slot", slot)
	await _frames(2)
	var said := _said()
	var shook := bar.is_refusing(slot)
	_check(said == "The lamp is full. I will keep the oil." and shook and satchel.count("langis") == had,
		"oil on a full lamp says so, shakes its slot and spends nothing", "\"%s\", shook %s, %d of %d" % [said,
			shook, satchel.count("langis"), had])
	while satchel.count("langis") > 0:
		satchel.take("langis")
	await _quiet()
	await _frames(int(QuickSlotBar.REFUSED_SECONDS * 60.0) + 2)
	var settled := bar.is_refusing(slot)
	level.call("use_quick_slot", slot)
	await _frames(2)
	_check(not settled and bar.is_refusing(slot) and _said() == "No more lamp oil.",
		"and a slot with none left says that", "\"%s\"" % _said())


## The first candle lies beside the first "Draw a light here". Pressed there, or at what flees a light
## she draws, it says it is not that; pressed anywhere else, how it burns.
func _a_candle_where_a_drawing_is_asked_says_so() -> void:
	var satchel := level.get("satchel") as Satchel
	var director := level.get("director") as Object
	satchel.add("kandila", 3)
	var slot := satchel.slots().find("kandila")
	var wanted := "A candle shows the way, but this wants a light I draw."
	await _stand_her_at(5000.0)
	await _quiet()
	level.call("use_quick_slot", slot)
	await _frames(2)
	var in_clearing := _said()
	var solved_clearing := bool(director.call("is_solved", "L4_REST1"))
	await _stand_her_at(6800.0)
	await _quiet()
	level.call("use_quick_slot", slot)
	await _frames(2)
	var at_sigbin := _said()
	await _stand_her_at(7800.0)
	await _quiet()
	level.call("use_quick_slot", slot)
	await _frames(2)
	_check(in_clearing == wanted and not solved_clearing and at_sigbin == wanted
			and _said() == "It burns here for 45 seconds. It does not follow me.",
		"a candle in the clearing or at the sigbin says it wants a light she draws; elsewhere, how it burns",
		"\"%s\" / \"%s\" / \"%s\"" % [in_clearing, at_sigbin, _said()])


## Salt when something is ahead of her and in reach, not behind her. Garlic when two are close, or
## one on a low lamp, and not while a ward holds her.
func _salt_and_garlic_are_asked_for_when_they_would_help() -> void:
	var satchel := level.get("satchel") as Satchel
	var health := level.get("player_health") as PlayerHealth
	satchel.add("asin", 2)
	satchel.add("bawang", 2)
	await _stand_her_at(WARD_X)
	health.reset_full()
	await _face(&"move_right")
	var alone := bool(level.call("_wanted_now", "asin"))
	var foe := GroundEnemy2D.new()
	foe.position = Vector2(WARD_X + 200.0, 586.0)
	(level.get("entity_root") as Node2D).add_child(foe)
	await _frames(4)
	var ahead := bool(level.call("_wanted_now", "asin"))
	# Near her on a full lamp, one is not a crowd.
	foe.global_position.x = WARD_X + 200.0
	var one_on_full := bool(level.call("_wanted_now", "bawang"))
	await _face(&"move_left")
	foe.global_position.x = WARD_X + 200.0
	await _frames(1)
	var behind := bool(level.call("_wanted_now", "asin"))
	_check(not alone and ahead and not behind, "salt is wanted with one ahead in reach, not with one behind or none",
		"none %s, ahead %s, behind %s" % [alone, ahead, behind])
	var second := GroundEnemy2D.new()
	second.position = Vector2(WARD_X - 200.0, 586.0)
	(level.get("entity_root") as Node2D).add_child(second)
	await _frames(4)
	var two := bool(level.call("_wanted_now", "bawang"))
	second.queue_free()
	foe.global_position.x = WARD_X + 200.0
	await _frames(2)
	health.dim(PlayerHealth.LOW)
	health.dim(PlayerHealth.LOW)
	await _frames(1)
	var one_on_low := bool(level.call("_wanted_now", "bawang"))
	level.call("use_quick_slot", satchel.slots().find("bawang"))
	await _frames(2)
	var warded := bool(level.call("_wanted_now", "bawang"))
	var told := _said()
	_check(not one_on_full and two and one_on_low and not warded,
		"garlic is wanted with two close or one on a low lamp, and not while a ward holds her",
		"one on full %s, two %s, one on low %s, warded %s" % [one_on_full, two, one_on_low, warded])
	_check(told == "Ten seconds inside the ring. Stay in it.", "and crushed, she says how long and to stay in it",
		"\"%s\"" % told)
	foe.queue_free()


## The design's 160: ash shows nothing past it, so the slot does not say Now past it. Said without
## waiting for the bar, its window is a second long. Thrown too soon, she is told why it did nothing.
func _ash_is_asked_for_only_within_its_reach() -> void:
	var satchel := level.get("satchel") as Satchel
	var bar := level.get("quick_slots") as QuickSlotBar
	var finale := level.get("_finale") as DilimFinale2D
	satchel.add("abo", 2)
	var slot := satchel.slots().find("abo")
	await _stand_her_at(21900.0)
	finale.elapsed = 60.0
	await _frames(4)
	var tiktik := finale.tiktik()
	if tiktik == null:
		_check(false, "the tik-tik comes to be asked about", "none")
		return
	var her := (level.get("player") as Node2D).global_position
	tiktik.stun(30.0)
	tiktik.global_position = her + Vector2(0.0, -300.0)
	await _frames(int(QuickSlotBar.WANTED_HOLD * 60.0) + 4)
	var far := bar.is_wanted(slot)
	await _quiet()
	level.call("use_quick_slot", slot)
	await _frames(2)
	var thrown_far := _said()
	var shown_far := tiktik.is_revealed()
	(level.get("hint_bar") as HintBar).show_hint("something else", "", 30.0)
	tiktik.global_position = her + Vector2(0.0, -120.0)
	await _frames(3)
	var near := bar.is_wanted(slot)
	var said := _said()
	_check(not far and thrown_far == "Nothing near enough. Ash only reaches this close." and not shown_far,
		"the ash's slot is not lit with the tik-tik out of its reach, and thrown then, she is told why",
		"lit %s, \"%s\", shown %s" % [far, thrown_far, shown_far])
	_check(near and said == "It is close. %s, now: ash shows it." % _key_on(slot),
		"within its reach it says Now, and says so over whatever the bar was saying",
		"lit %s, \"%s\"" % [near, said])


## All five held: the whip found says it has no slot, shows as waiting, and has its key the moment
## one is spent. Named on the bar so she can see she carries it.
func _the_sixth_thing_says_it_has_no_slot() -> void:
	var satchel := level.get("satchel") as Satchel
	var bar := level.get("quick_slots") as QuickSlotBar
	for id in ["asin", "kandila", "abo", "bawang", "langis"]:
		satchel.add(id, 1)
	await _quiet()
	await _touch_a_new("buntot_pagi")
	var said := _said()
	var waited := bar.waiting_names()
	await _stand_her_at(7800.0)
	await _quiet()
	var freed := satchel.slots().find("kandila")
	level.call("use_quick_slot", freed)
	await _frames(2)
	_check(said == "Buntot Pagi, stingray-tail whip. All the slots are full: use up one of my things and it moves in."
			and waited == ["Buntot Pagi"],
		"a thing found with every slot full says so, and stands on the bar as having none",
		"\"%s\", waiting %s" % [said, waited])
	_check(satchel.slots()[freed] == "buntot_pagi" and bar.waiting_names().is_empty() and bar.is_welcoming(freed)
			and _said() == "A slot is free. Buntot Pagi is on %s now." % _key_on(freed),
		"and when one is spent it moves in, rung, with its key said", "\"%s\", slots %s" % [_said(), satchel.slots()])


## Five at the checkpoint, two more found after it, then knocked out: all seven still hers.
func _a_knockout_keeps_what_she_carries() -> void:
	var satchel = level.get("satchel")
	# Counted from what she starts with: an earlier check may have left a checkpoint on disk.
	await _frames(60)
	var start: int = satchel.count("asin")
	satchel.add("asin", 5)
	level.call("_write_checkpoint", "CP1")
	var kept: Variant = JSON.parse_string(JSON.stringify((level.get("checkpoints") as Node).call("peek", "CP1")))
	satchel.add("asin", 2)
	level.call("_knockout")
	await _frames(4)
	var saved_asin := -1
	# Read as data, and anything else -- an object JSON could not carry -- reads as nothing kept.
	if kept is Dictionary and (kept as Dictionary).get("level") is Dictionary:
		var held: Variant = ((kept as Dictionary)["level"] as Dictionary).get("satchel")
		if held is Dictionary and (held as Dictionary).get("counts") is Dictionary:
			saved_asin = int(((held as Dictionary)["counts"] as Dictionary).get("asin", -1))
	set_meta(&"saved_asin", saved_asin)
	_check(saved_asin == start + 5, "a checkpoint keeps the satchel as plain data",
		"asin %d in the checkpoint (%d + 5)" % [saved_asin, start])
	_check(satchel.count("asin") == start + 7, "a knockout keeps what she carries, found since included",
		"asin %d (%d + 5 at the checkpoint, 2 after)" % [satchel.count("asin"), start])


## A fresh level, resuming from that checkpoint on disk: the five it held.
func _a_continue_gives_it_back() -> void:
	await _frames(60)
	var satchel = level.get("satchel")
	var saved := int(get_meta(&"saved_asin", -1))
	_check(saved > 0 and satchel.count("asin") == saved, "a Continue gives back what the checkpoint held",
		"asin %d of %d" % [satchel.count("asin"), saved])


func _the_controls_screen_names_the_slots() -> void:
	var overlay := level.get_node(^"ControlsOverlay")
	var shown: Array[bool] = []
	var keys_named := false
	for level_id in ["level_1", "level_4"]:
		root.get_node(^"LevelManager").set(&"current_level_id", level_id)
		overlay.call("_build")
		await _frames(2)
		var named := false
		for label in overlay.find_children("*", "Label", true, false):
			named = named or (label as Label).text.begins_with("Use one of Lola's things")
			keys_named = keys_named or (label as Label).text == "Z  -  B"
		shown.append(named)
	root.get_node(^"LevelManager").set(&"current_level_id", "level_4")
	_check(shown == [false, true], "the controls screen names the quick slots in Dilim and nowhere else",
		"shown in Payyo / Dilim: %s" % [shown])
	_check(keys_named, "and it names them from Z to B", "named %s" % keys_named)


func _open_level(resuming: bool = false) -> Node:
	var scene := (load("res://level_4.tscn") as PackedScene).instantiate()
	# Resume is off in test runs unless asked for; the Continue checks are about it.
	scene.set(&"resume_enabled", resuming)
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
