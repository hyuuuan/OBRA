extends SceneTree
## The HUD's motion (Motion, 2026-10-23), headless: what answers, and only when it should.
##
##   godot --headless --path game --script res://tests/run_hud_motion_probe.gd

var failures := 0
## Every check that ran, so one skipped by a script error is a failure rather than a silence.
var checked := 0
const CHECKS := 8


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(60.0, true).timeout.connect(func() -> void:
		print("OBRA_HUD_MOTION_FAILED=watchdog")
		quit(2))
	await process_frame
	_reduce(false)
	await _the_ink_count_answers_a_whole_unit()
	await _the_lantern_pops_only_brighter()
	await _a_slot_that_gains_brightens()
	await _the_form_card_pops_in_as_it_arrives()
	await _the_answers_come_one_after_another()
	await _reduced_the_hud_keeps_still()
	_reduce(false)
	if checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_HUD_MOTION_OK")
		quit(0)
	else:
		print("OBRA_HUD_MOTION_FAILED=%d" % failures)
		quit(1)


func _the_ink_count_answers_a_whole_unit() -> void:
	var panel := HudPanel.new()
	root.add_child(panel)
	await process_frame
	var value := panel.get("_value") as Label
	panel.set_ink(4.9, 6.0, 0.0)
	panel.set_ink(4.2, 6.0, 0.0)
	var still := await _largest(value, 0.3)
	panel.set_ink(3.9, 6.0, 0.0)
	var spent := await _largest(value, 0.3)
	panel.set_ink(6.0, 6.0, 0.0)
	var back := await _largest(value, 0.3)
	_check(is_equal_approx(still, 1.0) and spent > 1.02,
		"the ink count pulses when a whole unit goes, not for a fraction", "fraction %.3f, a unit %.3f" % [still, spent])
	_check(back > spent + 0.05, "and pops bigger when ink comes back", "back %.3f vs spent %.3f" % [back, spent])
	panel.queue_free()


func _the_lantern_pops_only_brighter() -> void:
	var health := PlayerHealth.new()
	root.add_child(health)
	var chip := LanternHud.new()
	root.add_child(chip)
	chip.size = Vector2(120.0, 40.0)
	chip.bind(health)
	health.take_hit()
	var hit := await _largest(chip, 0.3)
	health.refill(PlayerHealth.FULL)
	var refilled := await _largest(chip, 0.3)
	_check(is_equal_approx(hit, 1.0) and refilled > 1.05,
		"the lantern chip pops when the flame comes back, and not when it is hit (it shakes then)",
		"hit %.3f, refilled %.3f" % [hit, refilled])
	chip.queue_free()
	health.queue_free()


func _a_slot_that_gains_brightens() -> void:
	var satchel := Satchel.new()
	var bar := QuickSlotBar.new()
	root.add_child(bar)
	bar.bind(satchel)
	var id: String = satchel.ids()[0]
	satchel.add(id)
	var flash: Array = bar.get("_flash")
	_check(float(flash[0]) > 0.0, "a quick slot brightens when it gains something", "flash %s" % [flash])
	bar.queue_free()


func _the_form_card_pops_in_as_it_arrives() -> void:
	var card := MorphCard.new()
	root.add_child(card)
	await process_frame
	card.visible = false
	card.show_form("BIRD", null, 0.9)
	var arriving := card.scale.x
	await _seconds(Motion.POP_SECONDS + 0.25)
	card.show_form("BIRD", null, 0.9)
	var again := await _smallest(card, 0.2)
	_check(arriving < 0.95 and is_equal_approx(again, 1.0),
		"the form card pops in as it arrives, and holds still while it is shown again",
		"arriving %.2f, shown again %.2f" % [arriving, again])
	card.queue_free()


func _the_answers_come_one_after_another() -> void:
	var overlay := (load("res://ui/dialogue_choice_overlay.tscn") as PackedScene).instantiate() as ModalOverlay
	root.add_child(overlay)
	overlay.call(&"present_options", "lolo", "Which way?", ["The long way", "The short way", "Back home"])
	# Stepped (Motion.PIXEL_FPS), each fade holds its first frame: looked at once the first is well in.
	await _seconds(0.2)
	var buttons := (overlay.get("_buttons") as Control).get_children()
	var first := (buttons[0] as CanvasItem).modulate.a
	var last := (buttons[buttons.size() - 1] as CanvasItem).modulate.a
	_check(buttons.size() == 3 and first > last, "the answers fade in one after another",
		"first %.2f, last %.2f" % [first, last])
	await _seconds(0.6)
	var settled := true
	for button in buttons:
		settled = settled and (button as CanvasItem).modulate.a > 0.99
	_check(settled, "and all of them are there in the end", "settled %s" % settled)
	overlay.queue_free()


func _reduced_the_hud_keeps_still() -> void:
	_reduce(true)
	var panel := HudPanel.new()
	root.add_child(panel)
	await process_frame
	var value := panel.get("_value") as Label
	panel.set_ink(5.0, 6.0, 0.0)
	panel.set_ink(3.0, 6.0, 0.0)
	var largest := await _largest(value, 0.3)
	var card := MorphCard.new()
	root.add_child(card)
	await process_frame
	card.visible = false
	card.show_form("BIRD", null, 0.9)
	var arriving := card.scale.x
	_check(is_equal_approx(largest, 1.0) and is_equal_approx(arriving, 1.0),
		"with motion reduced the count and the card keep still", "count %.3f, card %.2f" % [largest, arriving])
	panel.queue_free()
	card.queue_free()
	_reduce(false)


## The largest / smallest scale an item reaches over the next `seconds`.
func _largest(item: CanvasItem, seconds: float) -> float:
	var most := 0.0
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(seconds * 1000.0):
		await process_frame
		most = maxf(most, (item as Control).scale.x)
	return most


func _smallest(item: CanvasItem, seconds: float) -> float:
	var least := 9.0
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(seconds * 1000.0):
		await process_frame
		least = minf(least, (item as Control).scale.x)
	return least


func _reduce(on: bool) -> void:
	var profile := root.get_node_or_null(^"PlayerProfile")
	if profile != null:
		profile.call(&"set_setting", "reduce_motion", on)


func _seconds(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
