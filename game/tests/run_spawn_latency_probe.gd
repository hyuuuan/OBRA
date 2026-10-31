extends SceneTree
## An accepted drawing is timed all the way to its appearance: the level measures from the
## Paint press to the first frame rendered with the entity in it, after the entity has been
## made, and logs it as a "spawn" event (thesis Eq. 12, §4.10.3).
##
##   godot --headless --path game --script res://tests/run_spawn_latency_probe.gd

## Every check this probe makes. A script error that skips them must not pass as quiet.
const CHECKS := 2

var failures := 0
var checked := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := (load("res://game_level.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(40):
		await physics_frame
	var panel := level.get("draw_panel") as DrawPanel
	var order: Array[String] = []
	for connection: Dictionary in panel.drawing_ready.get_connections():
		order.append(String((connection["callable"] as Callable).get_method()))
	var made := order.find("_on_drawing_ready")
	var timed := order.find("_measure_spawn_latency")
	_check(made >= 0 and timed > made, "the wait is timed after the entity is made",
		" -> ".join(order))
	var file := root.get_node("Telemetry").get("_file") as FileAccess
	var path := file.get_path_absolute() if file != null else ""
	panel.set("_submit_started_usec", Time.get_ticks_usec() - 50_000)
	level.call("_measure_spawn_latency", "spider", "Spider", null, {}, [], 1.0)
	for _frame in range(6):
		await process_frame
	var logged := -1.0
	if not path.is_empty():
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var event: Variant = JSON.parse_string(line) if not line.is_empty() else null
			if event is Dictionary and String(event.get("type", "")) == "spawn":
				logged = float(event.get("latency_ms", -1.0))
	_check(logged >= 50.0, "a spawn logs the time from Paint to its first frame",
		"%.1f ms in %s" % [logged, path.get_file()])
	if checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_SPAWN_LATENCY_OK")
		quit(0)
	else:
		print("OBRA_SPAWN_LATENCY_FAILED=%d" % failures)
		quit(1)


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
