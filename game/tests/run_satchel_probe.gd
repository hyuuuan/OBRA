extends SceneTree
## Dilim's satchel: Lola's things in stacks, the quick slots, and what a checkpoint keeps of them.
##
##   godot --headless --path game --script res://tests/run_satchel_probe.gd

const SatchelScript = preload("res://scripts/satchel.gd")

var failures := 0
var checked := 0
const CHECKS := 7


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_it_knows_lolas_five_things()
	_a_stack_stops_at_its_cap()
	_the_slots_fill_in_pickup_order()
	_a_spent_slot_goes_to_the_next_new_thing()
	_nothing_is_used_from_nothing()
	_it_is_kept_as_plain_data()
	_kept_data_is_held_to_the_file()
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


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
