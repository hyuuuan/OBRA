extends SceneTree
## Drawing and morphing, headless: each sound asked for where the screen already shows its moment.
##
##   godot --headless --path game --script res://tests/run_sfx_drawing_probe.gd
##
## Headless hears nothing, so what is checked is the ASKING (AudioDirector.sfx_requested) and,
## at that moment, the visual the sound plays beside (Dilim's rule). AUDIO_PLAN.md's table B: the
## page going to be read, an answer, a decline, a drawing into the bag and set down (or refused
## its spot), becoming a drawing and coming back, and the ink running low and out. The brush's
## refusal (Mayon's) is checked to be silent: it must reuse nothing of the decline's.
##
## `-- <words>` runs only the scenarios whose name holds them (for a mutant); the every-check-ran
## guard stands down for such a run.

## Stands in for the recogniser, counting what is sent to it.
class StubClient extends Node:
	var sent := 0

	func request_live_guess() -> bool:
		return false

	func send_drawing() -> void:
		sent += 1

	func decline_reason(_confidence: float, _margin: float) -> String:
		return "confidence"


const DRAWING := [&"draw_submit", &"recognised", &"declined", &"morph", &"revert", &"place",
	&"place_refused", &"ink_low", &"ink_empty"]
const PAYYO := "res://game_level.tscn"
const RosterFixtures = preload("res://tests/roster_fixtures.gd")
const DAGAT := "res://level_3.tscn"

var failures := 0
var checked := 0
const CHECKS := 12
var level: Node
## Every sound asked for in the current scenario, with what the screen showed as it was asked:
## [id, snapshot]. ⚠ A member, not a local: a lambda captures locals by value.
var heard: Array = []
## What a scenario wants recorded beside each sound, read the moment it is asked for.
var snapshot: Callable = func() -> Dictionary: return {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(300.0).timeout.connect(func() -> void:
		print("OBRA_SFX_DRAWING_FAILED=watchdog")
		quit(2))
	root.get_node(^"AudioDirector").connect(&"sfx_requested", _on_sfx_requested)
	var only := " ".join(OS.get_cmdline_user_args())
	for scenario: Callable in [_every_drawing_sound_has_a_file, _a_page_goes_to_be_read_and_comes_back_unsure,
			_a_refusing_page_says_nothing, _a_drawing_goes_into_the_bag_and_down,
			_she_becomes_the_drawing_and_comes_back, _running_out_is_heard_on_its_screen,
			_dagat_is_heard_running_low_and_out]:
		if not only.is_empty() and not String(scenario.get_method()).contains(only):
			continue
		heard.clear()
		snapshot = func() -> Dictionary: return {}
		await scenario.call()
		if level != null and is_instance_valid(level):
			level.queue_free()
			level = null
			await _frames(4)
	if only.is_empty() and checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_SFX_DRAWING_OK")
		quit(0)
	else:
		print("OBRA_SFX_DRAWING_FAILED=%d" % failures)
		quit(1)


func _on_sfx_requested(id: StringName, _loudness: float) -> void:
	heard.append([String(id), snapshot.call()])


# --- The scenarios -------------------------------------------------------------------------

func _every_drawing_sound_has_a_file() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/audio.json"))
	var sfx: Dictionary = catalog.get("sfx", {})
	var silent: Array[String] = []
	for id: StringName in DRAWING:
		var path := String(sfx.get(String(id), ""))
		if path.is_empty() or not (load(path) is AudioStreamWAV):
			silent.append(String(id))
	_check(silent.is_empty(), "every drawing sound has a file", "%d of %d" % [DRAWING.size() - silent.size(),
		DRAWING.size()] if silent.is_empty() else "silent: " + ", ".join(silent))


func _a_page_goes_to_be_read_and_comes_back_unsure() -> void:
	await _open(PAYYO, "level_1")
	var panel := level.get("draw_panel") as DrawPanel
	var stub := _stub(panel)
	snapshot = func() -> Dictionary: return {"status": panel.status.text, "sent": stub.sent,
		"open": panel.is_open()}
	level.call("_on_draw_button_pressed")
	_draw_two_lines(panel)
	await _frames(2)
	heard.clear()
	panel.call("_on_transform_pressed")
	var sending := _first("draw_submit")
	_check(_count("draw_submit") == 1 and String(sending.get("status", "")) == "Recognizing...",
		"a page is heard going to be read, as it says so", "%s, sent %d" % [heard, stub.sent])
	heard.clear()
	panel.call("_on_entity_declined", "", 0.1, 0.0, {"gate_reason": "confidence"})
	var unsure := _first("declined")
	_check(_ids() == ["declined"] and String(unsure.get("status", "")).begins_with("not sure what that is")
			and bool(unsure.get("open", false)),
		"and a drawing it cannot tell is heard as the page says so, still open", "%s" % [heard])
	panel.close_panel()


## The brush's refusal (Mayon's) sends nothing and says nothing, and so is heard as nothing.
func _a_refusing_page_says_nothing() -> void:
	var script := GDScript.new()
	script.source_code = "extends \"res://scripts/game_level.gd\"\n" \
		+ "func _brush_refuses_here() -> bool:\n\treturn true\n"
	script.reload()
	await _open(PAYYO, "level_1", script)
	var panel := level.get("draw_panel") as DrawPanel
	var stub := _stub(panel)
	level.call("_on_draw_button_pressed")
	_draw_two_lines(panel)
	await _frames(2)
	heard.clear()
	panel.call("_on_transform_pressed")
	await create_timer(DrawPanel.REFUSAL_FADE + 0.4).timeout
	var drawing_sounds := _ids().filter(func(id: String) -> bool: return DRAWING.has(StringName(id)))
	_check(not panel.is_open() and stub.sent == 0 and drawing_sounds.is_empty(),
		"a page the brush refuses is not heard as a decline, or as anything",
		"closed %s, sent %d, %s" % [not panel.is_open(), stub.sent, _ids()])


func _a_drawing_goes_into_the_bag_and_down() -> void:
	await _open(PAYYO, "level_1")
	var hud := level.get("inventory_hud") as Node
	var status := level.get("status_label") as Label
	snapshot = func() -> Dictionary: return {"arriving": bool(hud.call("is_arriving")),
		"status": status.text}
	_draw_into_the_bag("ladder", [Vector2(0, 0), Vector2(0, 180), Vector2(40, 180), Vector2(40, 0)])
	var answered := _first("recognised")
	_check(_count("recognised") == 1 and bool(answered.get("arriving", false))
			and not _ids().has("morph"),
		"a drawing is heard as it flies into the bag", "%s" % [heard])
	await _settle()
	heard.clear()
	var apo := level.get("player") as Node2D
	var spawn := (level.get_node("EnvironmentBaseplate/GameplayPlane/SpawnPoint") as Node2D).global_position
	apo.call("apply_morph_state", {"position": spawn + Vector2(200.0, -10.0), "velocity": Vector2.ZERO})
	await _frames(60)
	level.call("_on_inventory_slot_pressed", int(level.call("_slot_holding", "ladder")))
	var placement := level.get("placement_controller") as Node
	var spot := apo.global_position + Vector2(160.0, -40.0)
	placement.call("update_target", spot)
	await physics_frame
	placement.call("update_target", spot)
	# A click where it cannot go, while the ghost is up.
	placement.emit_signal(&"placement_rejected")
	var refused := _first("place_refused")
	_check(_count("place_refused") == 1 and String(refused.get("status", "")).begins_with("Can't build"),
		"a spot it cannot go is heard as the line says so", "%s" % [heard])
	heard.clear()
	var confirmed := bool(placement.call("confirm_placement"))
	var down := _first("place")
	_check(confirmed and _count("place") == 1 and String(down.get("status", "")).contains("placed"),
		"and set down, it is heard as it is placed", "confirmed %s, %s" % [confirmed, heard])


## Payyo's clock: a drawn creature lives a few seconds, fades, and she comes back.
func _she_becomes_the_drawing_and_comes_back() -> void:
	await _open(PAYYO, "level_1")
	(level.get("morph_life") as MorphLife).seconds = 2.0
	var hint := level.get("hint_bar") as Node
	var roots := level.get("entity_root") as Node
	snapshot = func() -> Dictionary:
		var flash := roots.get_children().any(func(child: Node) -> bool: return child is MorphFlash)
		return {"flash": flash, "hint": String(hint.call("current_text"))}
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	level.call("_spawn_or_replace", "frog", "Frog", sheet, RosterFixtures.for_rig("hopper", "frog"))
	var became := _first("morph")
	_check(_count("morph") == 1 and bool(became.get("flash", false)) and not (level.get("player") is Wanderer),
		"she is heard becoming the drawing, in its flash", "%s" % [heard])
	for _frame in range(60 * 4):
		if _ids().has("revert"):
			break
		await _frames(1)
	var fading := _first("ink_low")
	_check(_count("ink_low") == 1 and String(fading.get("hint", "")).contains("fading"),
		"its fading is heard as the line says so", "%s" % [heard])
	var back := _first("revert")
	var reverts := _count("revert")
	level.call("_revert_to_base_form")
	_check(reverts == 1 and bool(back.get("flash", false)) and level.get("player") is Wanderer
			and _count("revert") == 1,
		"and coming back is heard in the flash back, and not again when she is already herself",
		"%s" % [heard])


func _running_out_is_heard_on_its_screen() -> void:
	await _open(PAYYO, "level_1")
	var screen := level.get("out_of_ink_overlay") as ModalOverlay
	snapshot = func() -> Dictionary: return {"open": screen.is_open()}
	screen.open()
	var empty := _first("ink_empty")
	_check(bool(empty.get("open", false)) and _ids() == ["ink_empty"],
		"running out of ink is heard as its screen comes up, and nothing else is", "%s" % [heard])
	screen.close()


## Dagat's drain has no clock and no screen: its warnings are lines.
func _dagat_is_heard_running_low_and_out() -> void:
	await _open(DAGAT, "level_3")
	var hint := level.get("hint_bar") as Node
	snapshot = func() -> Dictionary: return {"hint": String(hint.call("current_text"))}
	level.call("_on_low_ink", 0.5, 6.0)
	level.call("_on_drain_emptied")
	var low := _first("ink_low")
	var out := _first("ink_empty")
	_check(String(low.get("hint", "")).contains("nearly gone") and String(out.get("hint", "")).contains("Out of ink"),
		"Dagat's ink is heard running low and out as Lolo says so", "%s" % [heard])


# --- Helpers -------------------------------------------------------------------------------

func _open(scene: String, level_id: String, script: GDScript = null) -> void:
	root.get_node(^"LevelManager").set("current_level_id", level_id)
	level = (load(scene) as PackedScene).instantiate()
	if script != null:
		level.set_script(script)
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(40)
	for _frame in range(60 * 10):
		if not bool(level.get("_opening_running")):
			break
		await _frames(1)
	await _settle()
	heard.clear()


func _stub(panel: DrawPanel) -> StubClient:
	var stub := StubClient.new()
	panel.add_child(stub)
	panel.client = stub
	return stub


func _draw_into_the_bag(entity_id: String, points: Array) -> void:
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	# Ink on the page: the bag flies the drawing with its paper knocked out, and a blank page
	# leaves nothing to fly.
	sheet.fill_rect(Rect2i(20, 8, 24, 48), Color.BLACK)
	level.call("_on_drawing_ready", entity_id, entity_id.capitalize(), sheet, {"confidence": 0.9},
		[{"points": PackedVector2Array(points), "width": 6.0, "color": Color.BLACK}], 1.0)


## Two short strokes across the middle of the page (as run_brush_refusal_probe draws them).
func _draw_two_lines(panel: DrawPanel) -> void:
	var canvas := panel.canvas
	var middle := canvas.size * 0.5
	for row in [-30.0, 30.0]:
		canvas.call("_start_stroke", middle + Vector2(-60.0, row))
		for step in range(1, 13):
			canvas.call("_append_point", middle + Vector2(-60.0 + step * 10.0, row), true)


## Close what is up, as a player pressing on would: UIRouter derives the pause from the open
## overlays, so writing `paused` alone is overruled on the next refresh.
func _settle() -> void:
	for _attempt in range(10):
		for node in get_nodes_in_group(ModalOverlay.GROUP):
			if node is InventoryScreen:
				continue
			if bool(node.call(&"is_open")):
				node.call(&"close")
		call_group(DialogueBox.GROUP, &"hide_line")
		paused = false
		await physics_frame


func _ids() -> Array:
	return heard.map(func(entry: Array) -> String: return entry[0])


func _count(id: String) -> int:
	return _ids().count(id)


## What the screen showed when `id` was first asked for, or {} if it never was.
func _first(id: String) -> Dictionary:
	for entry: Array in heard:
		if entry[0] == id:
			return entry[1]
	return {}


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
