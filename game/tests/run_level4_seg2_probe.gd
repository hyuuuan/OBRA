extends SceneTree
## Dilim's middle stretch, headless: a drawn body's ink, the sigbin, the tikbalang and the kapre.
##
##   godot --headless --path game --script res://tests/run_level4_seg2_probe.gd
##
## Driven the way a player drives it -- drawings handed in as the recogniser would, keys held --
## and read back off what the level and the things in it say happened.

const GROUND_Y := 600.0

var failures := 0
var checked := 0
const CHECKS := 3
var level: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(240.0).timeout.connect(func() -> void:
		print("OBRA_L4_SEG2_FAILED=watchdog")
		quit(2))
	level = await _open_level()
	await _a_drawn_body_costs_ink_and_has_no_clock()
	await _at_no_ink_she_is_herself()
	level.queue_free()
	await _frames(3)
	if checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_L4_SEG2_OK")
		quit(0)
	else:
		print("OBRA_L4_SEG2_FAILED=%d" % failures)
		quit(1)


# --- A drawn body ------------------------------------------------------------------------

func _become(entity_id: String) -> void:
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	level.call("_on_drawing_ready", entity_id, entity_id.capitalize(), sheet, {"confidence": 0.9},
		[{"points": PackedVector2Array([Vector2(0, 0), Vector2(40, 0)]), "width": 6.0, "color": Color.BLACK}], 1.0)
	await _frames(10)


## A horse held for twelve seconds: past the ten a body lasts anywhere else, and a quarter of a
## unit gone each second.
func _a_drawn_body_costs_ink_and_has_no_clock() -> void:
	var ink := level.get("ink_manager") as InkManager
	await _become("horse")
	var from := ink.remaining()
	await _frames(2 * 60)
	var after_two := from - ink.remaining()
	await _frames(10 * 60)
	var still := String(level.get("_current_form_id")) == "horse"
	_check(absf(after_two - 0.5) < 0.05, "a drawn body costs a quarter of a unit a second",
		"%.2f in two seconds" % after_two)
	_check(still, "and it has no ten-second clock", "still a horse at twelve seconds: %s" % still)


func _at_no_ink_she_is_herself() -> void:
	var ink := level.get("ink_manager") as InkManager
	ink.drain(ink.remaining() - 0.05)
	await _frames(60)
	_check(String(level.get("_current_form_id")).is_empty() and level.get("player") is Wanderer,
		"at no ink she is herself again", "form '%s'" % level.get("_current_form_id"))


# --- Helpers -----------------------------------------------------------------------------

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
