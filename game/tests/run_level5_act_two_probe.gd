extends SceneTree
## Mayon's Act Two, played: the fragments go white once seen and in seconds once passed; a drawing
## that belongs saves one for a unit of ink -- never the hidden reserve -- and one that does not is
## handed back free; the flower is saved only from its ledge, and is the fifth flower and the
## artist's choice; a fall gives back the fragments as they were; lolo thins, steadies, and at
## the top the brush is raised to him, refuses, and he is gone.
##
##   godot --headless --path game --script res://tests/run_level5_act_two_probe.gd

## Every check this probe makes. A script error that skips them must not pass as quiet.
const CHECKS := 10

var failures := 0
var checked := 0
var level: Node
var ink: InkManager


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	level = await _open_level()
	ink = level.get("ink_manager") as InkManager
	_check(not bool(level.call("_brush_refuses_here")), "below the top the page is an ordinary page",
		"refusing %s" % level.call("_brush_refuses_here"))
	await _a_fragment_goes_white_once_seen()
	await _a_drawing_that_belongs_saves_it_for_one_unit()
	await _with_the_gauge_empty_the_reserve_does_not_pay()
	await _a_drawing_that_does_not_belong_is_handed_back()
	await _passed_by_it_is_lost_in_seconds()
	await _the_flower_is_saved_only_from_its_ledge()
	await _a_fall_gives_back_the_fragments_as_they_were()
	await _lolo_thins_by_where_she_is()
	await _at_the_top_the_brush_refuses_him_and_he_is_gone()
	if checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_LEVEL5_ACT_TWO_OK")
		quit(0)
	else:
		print("OBRA_LEVEL5_ACT_TWO_FAILED=%d" % failures)
		quit(1)


func _a_fragment_goes_white_once_seen() -> void:
	var kubo := _fragment("kubo")
	var far := _fragment("terraces")
	var before := kubo.drain()
	await _put(5600.0, 0.0)
	await create_timer(1.5).timeout
	_check(is_zero_approx(before) and kubo.drain() > 0.0 and kubo.drain() < 0.2 and is_zero_approx(far.drain()),
		"a fragment goes white once she has seen it, slowly, and one out of sight does not",
		"kubo %.3f -> %.3f, terraces still %.3f" % [before, kubo.drain(), far.drain()])


func _a_drawing_that_belongs_saves_it_for_one_unit() -> void:
	var kubo := _fragment("kubo")
	await _put(5900.0, 0.0)
	_set_ink(1.0, 2.0)
	_draw("door")
	await create_timer(1.6).timeout
	_check(kubo.state() == "saved" and is_zero_approx(ink.remaining()) and is_equal_approx(ink.hidden_reserve, 2.0)
		and kubo.drain() < 0.02 and not kubo.strokes().is_empty(),
		"a drawing that belongs saves it for one unit, never the reserve, and her lines go into it",
		"kubo %s, gauge %.1f, reserve %.1f, drain %.2f, lines %d" % [kubo.state(), ink.remaining(),
			ink.hidden_reserve, kubo.drain(), kubo.strokes().size()])


func _with_the_gauge_empty_the_reserve_does_not_pay() -> void:
	var terraces := _fragment("terraces")
	await _put(6380.0, 0.0)
	_set_ink(0.0, 2.0)
	_draw("stairs")
	await _frames(4)
	_check(terraces.is_open() and is_equal_approx(ink.hidden_reserve, 2.0),
		"with the gauge empty a fragment cannot be saved, and the reserve does not pay",
		"terraces %s, reserve %.1f" % [terraces.state(), ink.hidden_reserve])


func _a_drawing_that_does_not_belong_is_handed_back() -> void:
	var terraces := _fragment("terraces")
	_set_ink(2.0, 2.0)
	_draw("sword")
	await _frames(4)
	var after_wrong := ink.remaining()
	var open_after_wrong := terraces.is_open()
	_draw("tree")
	await _frames(6)
	var lolo := level.get("lolo") as Lolo
	_check(open_after_wrong and is_equal_approx(after_wrong, 2.0) and terraces.state() == "saved"
		and is_equal_approx(ink.remaining(), 1.0) and is_zero_approx(lolo.thinness()),
		"a drawing that does not belong is handed back free; one that does saves it, and lolo steadies",
		"after the wrong one: gauge %.1f, open %s; after the right one: %s, gauge %.1f, lolo thinness %.2f" % [
			after_wrong, open_after_wrong, terraces.state(), ink.remaining(), lolo.thinness()])


func _passed_by_it_is_lost_in_seconds() -> void:
	var bandaritas := _fragment("bandaritas")
	await _put(6860.0 + 690.0, 0.0)
	var lost := await _until(func() -> bool: return bandaritas.state() == "lost", 7.0)
	_check(lost, "passed by, a fragment goes white and blank in seconds and is lost",
		"bandaritas %s" % bandaritas.state())


func _the_flower_is_saved_only_from_its_ledge() -> void:
	var flower := _fragment("flower")
	var profile := root.get_node("PlayerProfile")
	var artist_before: int = profile.call("route_count", "artist")
	await _put(8330.0, 0.0)
	var from_the_path: bool = level.call("_fragment_here") == flower
	await _put(8330.0, -180.0)
	var from_the_ledge: bool = level.call("_fragment_here") == flower
	_set_ink(2.0, 2.0)
	_draw("butterfly")
	await _frames(6)
	var found: bool = profile.call("is_collectible_found", "L5_HF")
	var artist_after: int = profile.call("route_count", "artist")
	_check(not from_the_path and from_the_ledge and flower.state() == "saved" and found
		and artist_after == artist_before + 1,
		"the flower is saved only from its ledge, and it is the fifth flower and the artist's",
		"from the path %s, from the ledge %s, %s, found %s, artist %d -> %d" % [from_the_path,
			from_the_ledge, flower.state(), found, artist_before, artist_after])


func _a_fall_gives_back_the_fragments_as_they_were() -> void:
	var coral := _fragment("coral")
	await _put(9740.0, -100.0)
	_set_ink(2.0, 2.0)
	level.call("_write_checkpoint", "CP1")
	_draw("crab")
	await _frames(4)
	var saved_then := coral.state()
	level.call("_restore_checkpoint")
	await _frames(4)
	var kubo := _fragment("kubo")
	_check(saved_then == "saved" and coral.is_open() and kubo.state() == "saved" and not kubo.strokes().is_empty()
		and is_equal_approx(ink.remaining(), 2.0),
		"a fall gives back the fragments as they were at the checkpoint, and the ink",
		"coral %s then %s, kubo %s with %d lines, gauge %.1f" % [saved_then, coral.state(),
			kubo.state(), kubo.strokes().size(), ink.remaining()])


func _lolo_thins_by_where_she_is() -> void:
	var lolo := level.get("lolo") as Lolo
	level.set("_steady_left", 0.0)
	await _put(10500.0, -100.0)
	var thinned := await _until(func() -> bool: return lolo.thinness() >= 0.65, 5.0)
	_check(thinned, "away from his fragments lolo thins toward what the corridor leaves of him",
		"thinness %.2f" % lolo.thinness())


func _at_the_top_the_brush_refuses_him_and_he_is_gone() -> void:
	var lolo := level.get("lolo") as Lolo
	var goes_at: float = level.call("lolo_goes_at")
	# One of his fragments saved (the terraces): he goes 2 x 250 sooner than with all three.
	var where_ok := is_equal_approx(goes_at, 12400.0 - 500.0)
	await _put(goes_at + 40.0, -100.0)
	var panel := level.get("draw_panel") as DrawPanel
	var raised := await _until(func() -> bool: return panel.is_open() and panel.is_refusing(), 14.0)
	panel.call("_on_transform_pressed")
	var gone := await _until(func() -> bool: return lolo.is_gone(), 12.0)
	_check(where_ok and raised and gone and not lolo.visible,
		"at the top the brush is raised to him, refuses, and he is gone in a frame",
		"goes at %.0f, raised by itself %s, gone %s, seen %s" % [goes_at, raised, gone, lolo.visible])


# --- Helpers ----------------------------------------------------------------------------

func _fragment(id: String) -> MemoryFragment2D:
	return level.call("_fragment", id) as MemoryFragment2D


func _set_ink(gauge: float, reserve: float) -> void:
	ink.committed = ink.capacity - gauge
	ink.hidden_reserve = reserve


func _draw(entity: String) -> void:
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	level.call("_on_drawing_ready", entity, entity.capitalize(), sheet, {"confidence": 0.9},
		[{"points": PackedVector2Array([Vector2(0, 0), Vector2(40, 60), Vector2(80, 0)]),
			"width": 6.0, "color": Color.BLACK}], 1.0)


func _put(x: float, y: float) -> void:
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": Vector2(x, y), "linear_velocity": Vector2.ZERO})
	await _frames(30)
	call_group(DialogueBox.GROUP, &"hide_line")
	paused = false


func _until(done: Callable, seconds: float) -> bool:
	var left := seconds
	while left > 0.0:
		if done.call():
			return true
		call_group(DialogueBox.GROUP, &"hide_line")
		await create_timer(0.1).timeout
		left -= 0.1
	return bool(done.call())


func _open_level() -> Node:
	var scene := (load("res://level_5.tscn") as PackedScene).instantiate()
	(scene.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(scene)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(40):
		await physics_frame
	call_group(DialogueBox.GROUP, &"hide_line")
	paused = false
	await _frames(4)
	return scene


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
