extends SceneTree
## The recognition gate is the level's: each level_NN.json's `recognition` block sets it, the
## client is the one place the rule is written, and the drawing panel asks the client rather
## than repeating numbers of its own -- so "gold" on the live guess always means Paint will
## take it, and a decline names the half of the gate that refused it.
##
##   godot --headless --path game --script res://tests/run_gate_probe.gd

const LEVEL_FILES := [
	"res://config/level_01.json", "res://config/level_02.json", "res://config/level_03.json",
	"res://config/level_04.json", "res://config/level_05.json",
]
## The manuscript's correctness floor (FR-3, Eq. 4). It never moves, in any level.
const FLOOR_CONFIDENCE := 0.60
const FLOOR_MARGIN := 0.15

## Every check this probe makes. A script error that skips them must not pass as quiet.
const CHECKS := 6

var failures := 0
var checked := 0
## Set by a signal; a lambda would capture a local by value and never see it change.
var declined_reason := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_the_client_takes_its_gate_from_a_block()
	_every_level_file_states_the_floor()
	await _the_panel_asks_the_client()
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


func _on_declined(_entity: String, _confidence: float, _margin: float, reason: String) -> void:
	declined_reason = reason


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
