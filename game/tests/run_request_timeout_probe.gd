extends SceneTree
## A recogniser that never answers lets go of the drawing: both requests carry a timeout, and
## a timed-out submission frees Paint and says why, instead of holding "Recognizing..." with
## the button disabled forever (thesis §4.10.2, timeout behaviour).
##
##   godot --headless --path game --script res://tests/run_request_timeout_probe.gd

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
	var client: Node = panel.client
	var http := client.get("_http") as HTTPRequest
	var live := client.get("_live_http") as HTTPRequest
	_check(http.timeout > 0.0 and live.timeout > 0.0 and live.timeout <= http.timeout,
		"both requests give up in the end", "submit %.0f s, live guess %.0f s" % [http.timeout, live.timeout])
	panel.open_panel()
	await physics_frame
	panel.set("_submitting", true)
	panel.transform_button.disabled = true
	client.call("_on_request_completed", HTTPRequest.RESULT_TIMEOUT, 0, PackedStringArray(), PackedByteArray())
	await physics_frame
	_check(not panel.transform_button.disabled and not bool(panel.get("_submitting"))
		and panel.status.text.contains("too long"),
		"a timed-out drawing frees Paint and says why",
		"Paint %s, status '%s'" % ["free" if not panel.transform_button.disabled else "HELD",
			panel.status.text])
	if checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_REQUEST_TIMEOUT_OK")
		quit(0)
	else:
		print("OBRA_REQUEST_TIMEOUT_FAILED=%d" % failures)
		quit(1)


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
