extends SceneTree
## THE SERVER THE GAME STARTED IS STOPPED FROM WHEREVER THE PLAYER QUITS.
##   godot --headless --path game --script res://tests/run_backend_ownership_probe.gd
##
## A recognition server ran on port 8000 for eighteen days after the game that started it
## had gone, and served the old preprocessing after the fix for circles read as clocks was
## merged. Two holes let it: the pid was held on the level's supervisor, which dies on every
## level change, so a level that had not started the server had nothing to stop; and the
## title screen and the house have no supervisor at all, so quitting from them stopped
## nothing. The server now also exits on its own when the game does (backend/lifecycle.py,
## tested in tests/test_backend_lifecycle.py) -- this is the game's half.
##
## So: one supervisor starts the server and dies, as Payyo's does on the way to Piyesta. A
## second finds it running and starts nothing. That one dies too, as it does on the way back
## to the house. Then the server is stopped with no supervisor left anywhere, the way the
## title screen's Quit stops it, and it has to be gone.

## Not 8000, so a server left over from an earlier run cannot answer in this one's place.
const PROBE_PORT := 8766

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-52s %s" % ["OK  " if ok else "FAIL", what, detail])


func _run() -> void:
	print("\n===== WHO STOPS THE SERVER =====")
	_check(not await _answers(), "nothing is on the probe's port to begin with",
		"port %d free" % PROBE_PORT)

	# Payyo's supervisor: starts the server, then the level changes and it is freed.
	var first := await _supervisor()
	_check(bool(first.get("_started_process")), "the first level starts the server", "launched")
	_check(OS.get_environment("OBRA_GAME_PID") == str(OS.get_process_id()),
		"and tells it which process to end with", "OBRA_GAME_PID %s" % OS.get_environment("OBRA_GAME_PID"))
	await _free(first)

	# Piyesta's: finds it running, starts nothing, and is freed on the way to the house.
	var second := await _supervisor()
	_check(not bool(second.get("_started_process")), "the next level uses it and starts nothing",
		"reused")
	await _free(second)

	# The house, or the title screen: no supervisor anywhere, and Quit.
	_check(get_nodes_in_group(BackendSupervisor.GROUP).is_empty(), "no supervisor is left in the tree",
		"as in the house")
	BackendSupervisor.stop_owned_backend()
	var gone := false
	for _try in range(20):
		if not await _answers():
			gone = true
			break
		await create_timer(0.25).timeout
	_check(gone, "quitting from there stops the server", "gone" if gone
		else "STILL ANSWERING -- it outlives the game")

	# Nothing to clean up when that fails: the server ends itself once this process has gone.
	print("OBRA_BACKEND_OWNERSHIP_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)


func _supervisor() -> BackendSupervisor:
	var supervisor := BackendSupervisor.new()
	supervisor.backend_port = PROBE_PORT
	var up := [false]
	supervisor.backend_ready.connect(func() -> void: up[0] = true)
	root.add_child(supervisor)
	supervisor.ensure_backend()
	var waited := 0.0
	while waited < 60.0 and not up[0]:
		await create_timer(0.25).timeout
		waited += 0.25
	_check(up[0], "a server answers on port %d" % PROBE_PORT, "%.1f s" % waited)
	return supervisor


func _free(node: Node) -> void:
	node.queue_free()
	await process_frame
	await process_frame


func _answers() -> bool:
	var request := HTTPRequest.new()
	request.timeout = 1.0
	root.add_child(request)
	var error := request.request("http://127.0.0.1:%d/" % PROBE_PORT)
	var code := -1
	if error == OK:
		var reply: Array = await request.request_completed
		if int(reply[0]) == HTTPRequest.RESULT_SUCCESS:
			code = int(reply[1])
	request.queue_free()
	return code == 200
