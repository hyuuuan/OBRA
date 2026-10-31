extends SceneTree
## The recognition gate is the level's: each level_NN.json's `recognition` block sets it, the
## client is the one place the rule is written, and the drawing panel asks the client rather
## than repeating numbers of its own -- so "gold" on the live guess always means Paint will
## take it, and a decline names the half of the gate that refused it.
##
## Above the fixed floor, the NEW BRUSH asks more the further from home it is (thesis
## §4.5.4.2): each level's own bar, only once the brush from Dagat is in hand, easing to the
## floor after a run of declines so no level can strand her, and said in the story's words
## rather than as a failure.
##
##   godot --headless --path game --script res://tests/run_gate_probe.gd

const LEVEL_FILES := [
	"res://config/level_01.json", "res://config/level_02.json", "res://config/level_03.json",
	"res://config/level_04.json", "res://config/level_05.json",
]
## The manuscript's correctness floor (FR-3, Eq. 4). It never moves, in any level.
const FLOOR_CONFIDENCE := 0.60
const FLOOR_MARGIN := 0.15
## Each level's bar for the new brush (the team's "gentle rise", 2026-10-31).
const BARS := {1: 0.60, 2: 0.60, 3: 0.65, 4: 0.70, 5: 0.75}

## Every check this probe makes. A script error that skips them must not pass as quiet.
const CHECKS := 12

var failures := 0
var checked := 0
## Set by a signal; a lambda would capture a local by value and never see it change.
var declined_reason := ""
var eased_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_the_client_takes_its_gate_from_a_block()
	_every_level_file_states_the_floor()
	await _the_panel_asks_the_client()
	_the_new_brush_asks_more_and_eases()
	_every_level_names_its_bar()
	await _a_brush_decline_says_so_in_dagat()
	if checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_GATE_OK")
		quit(0)
	else:
		print("OBRA_GATE_FAILED=%d" % failures)
		quit(1)


func _the_client_takes_its_gate_from_a_block() -> void:
	var client: Node = (load("res://scripts/sketch_client.gd") as GDScript).new()
	client.call("configure_gate", {"confidence_threshold": 0.7, "margin_threshold": 0.2})
	_check(is_equal_approx(float(client.get("confidence_threshold")), 0.7)
		and is_equal_approx(float(client.get("margin_threshold")), 0.2),
		"a recognition block sets the client's gate",
		"%.2f / %.2f" % [float(client.get("confidence_threshold")), float(client.get("margin_threshold"))])
	_check(bool(client.call("passes_gate", 0.7, 0.2)) and not bool(client.call("passes_gate", 0.69, 0.5))
		and not bool(client.call("passes_gate", 0.9, 0.19))
		and String(client.call("decline_reason", 0.65, 0.5)) == "confidence"
		and String(client.call("decline_reason", 0.75, 0.1)) == "margin",
		"the gate and its reasons follow the configured numbers", "0.70 / 0.20")
	client.free()


func _every_level_file_states_the_floor() -> void:
	var wrong: Array[String] = []
	for path: String in LEVEL_FILES:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		var block: Dictionary = (data as Dictionary).get("recognition", {}) if data is Dictionary else {}
		if not is_equal_approx(float(block.get("confidence_threshold", -1.0)), FLOOR_CONFIDENCE) \
				or not is_equal_approx(float(block.get("margin_threshold", -1.0)), FLOOR_MARGIN):
			wrong.append(path.get_file())
	_check(wrong.is_empty(), "every level states the 0.60 / 0.15 floor",
		"wrong: %s" % ", ".join(wrong) if not wrong.is_empty() else "5 levels")


func _the_panel_asks_the_client() -> void:
	var level := (load("res://game_level.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	# ⚠ Payyo's file says what the export defaults say, so a level that never read its file
	# would look right. Start the client wrong, and only the file can put it back.
	level.get_node("DrawPanel/PanelRoot/SketchClient").set("confidence_threshold", 0.99)
	level.get_node("DrawPanel/PanelRoot/SketchClient").set("margin_threshold", 0.99)
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(40):
		await physics_frame
	var panel := level.get("draw_panel") as DrawPanel
	var client: Node = panel.client
	_check(is_equal_approx(float(client.get("confidence_threshold")), FLOOR_CONFIDENCE)
		and is_equal_approx(float(client.get("margin_threshold")), FLOOR_MARGIN),
		"Payyo's client carries Payyo's gate",
		"%.2f / %.2f" % [float(client.get("confidence_threshold")), float(client.get("margin_threshold"))])
	# Raise the client's bar past a guess the old literal 0.6 would have called sure.
	client.set("confidence_threshold", 0.9)
	panel.open_panel()
	await physics_frame
	panel.call("_on_live_prediction", "fish", "Fish", 0.8, 0.5, {})
	var colour := panel.guess_label.get_theme_color(&"font_color")
	_check(colour == UISkin.PENDING, "the live guess is gold only when the client's gate passes",
		"0.80 against a 0.90 bar reads %s" % ("pending" if colour == UISkin.PENDING else "SURE"))
	panel.recognition_declined.connect(_on_declined)
	panel.set("_submitting", true)
	panel.call("_on_entity_declined", "fish", 0.8, 0.5, {})
	_check(declined_reason == "confidence", "a decline names the half the client's gate refused",
		"0.80 against a 0.90 bar: '%s'" % declined_reason)
	level.queue_free()
	await physics_frame


func _the_new_brush_asks_more_and_eases() -> void:
	var profile := root.get_node("PlayerProfile")
	var data: Dictionary = profile.get("_data")
	var had_brush := bool(data.get("new_brush", false))
	var client: Node = (load("res://scripts/sketch_client.gd") as GDScript).new()
	root.add_child(client)
	client.call("configure_gate", {"confidence_threshold": 0.6, "margin_threshold": 0.15,
		"acceptance_threshold": 0.75, "eases_after_declines": 2, "ease_step": 0.05})
	data["new_brush"] = false
	_check(is_equal_approx(float(client.call("current_bar")), FLOOR_CONFIDENCE),
		"before the new brush is in hand, the bar is the floor",
		"bar %.2f" % float(client.call("current_bar")))
	data["new_brush"] = true
	_check(is_equal_approx(float(client.call("current_bar")), 0.75)
		and not bool(client.call("passes_gate", 0.70, 0.5)) and bool(client.call("passes_floor", 0.70, 0.5))
		and String(client.call("decline_reason", 0.70, 0.5)) == "brush"
		and String(client.call("decline_reason", 0.55, 0.5)) == "confidence",
		"with it, a reading the floor takes and the bar refuses is a brush decline",
		"bar %.2f, 0.70 -> %s" % [float(client.call("current_bar")),
			String(client.call("decline_reason", 0.70, 0.5))])
	client.connect(&"bar_eased", _on_bar_eased)
	var bars: Array[String] = ["%.2f" % float(client.call("current_bar"))]
	for _decline in range(5):
		client.call("_note_outcome", false)
		bars.append("%.2f" % float(client.call("current_bar")))
	var eased_to_floor := bars == ["0.75", "0.75", "0.70", "0.65", "0.60", "0.60"]
	client.call("_note_outcome", true)
	_check(eased_to_floor and eased_count == 3 and is_equal_approx(float(client.call("current_bar")), 0.75),
		"after two declines it eases a step a time to the floor, and a take resets it",
		"%s, eased %d times, then %.2f" % [" ".join(bars), eased_count, float(client.call("current_bar"))])
	data["new_brush"] = had_brush
	client.queue_free()


func _every_level_names_its_bar() -> void:
	var wrong: Array[String] = []
	for level: int in BARS:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEVEL_FILES[level - 1]))
		var block: Dictionary = (data as Dictionary).get("recognition", {})
		if not is_equal_approx(float(block.get("acceptance_threshold", -1.0)), BARS[level]) 				or int(block.get("eases_after_declines", 0)) < 1 				or float(block.get("ease_step", 0.0)) <= 0.0:
			wrong.append("level %d" % level)
	_check(wrong.is_empty(), "each level names its bar and how it eases",
		", ".join(wrong) if not wrong.is_empty() else "0.60 0.60 0.65 0.70 0.75")


## Dagat, with the brush taken: the level's file reaches the client, and a decline only the
## bar refused is told in the brush's words -- leaving the "could not tell it apart" beat,
## which would be untrue of it, unspent.
func _a_brush_decline_says_so_in_dagat() -> void:
	var data: Dictionary = root.get_node("PlayerProfile").get("_data")
	var had_brush := bool(data.get("new_brush", false))
	data["new_brush"] = true
	var level := (load("res://level_3.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(40):
		await physics_frame
	var client: Node = (level.get("draw_panel") as DrawPanel).client
	_check(is_equal_approx(float(client.call("current_bar")), 0.65),
		"Dagat's client carries Dagat's bar", "%.2f" % float(client.call("current_bar")))
	level.call("_on_recognition_declined", "fish", 0.62, 0.5, "brush")
	var lines: DialogueScript = level.get("script_lines")
	var fired: Dictionary = lines.get("_fired_once")
	_check(fired.has("L3_BRUSH_002") and not bool(level.get("_refusal_spoken")),
		"a brush decline speaks the brush's line, not the refusal beat",
		"brush line %s, refusal spent %s" % [fired.has("L3_BRUSH_002"), level.get("_refusal_spoken")])
	data["new_brush"] = had_brush
	level.queue_free()
	await physics_frame


func _on_bar_eased(_bar: float) -> void:
	eased_count += 1


func _on_declined(_entity: String, _confidence: float, _margin: float, reason: String) -> void:
	declined_reason = reason


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
