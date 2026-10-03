extends SceneTree
## The drawing recogniser is waited for, not given up on -- and when it cannot start, it says why.
##
##   godot --headless --path game --script res://tests/run_backend_start_probe.gd
##
## Kent's friend pulled the game on Windows and "had to wait minutes for a drawing to be
## recognized". The server's first start on a Windows machine is slow -- Windows Defender reads
## every file numpy and onnxruntime are made of -- and the game gave up after 45 seconds, and a
## drawing sent before the server answered failed outright. Held here, against the real server
## (backend/serve.py), with Python slowed down to stand in for that first start:
##
##   a drawing sent while the recogniser is starting waits, and goes through by itself
##   a port something else is holding is passed over for a spare one
##   a recogniser that cannot start says why, in words a player can act on

const UserData = preload("res://scripts/user_data.gd")
## Not 8000, and not one of the spares, so nothing left over answers in this run's place.
const PORT := 8777
const HELD_PORT := 8778
const SLOW_START_SEC := 4

var failures := 0
var results: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	results.append("  %s  %-58s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _run() -> void:
	print("\n===== THE RECOGNISER STARTING =====")
	await _a_drawing_sent_early_waits_and_goes_through()
	BackendSupervisor.stop_owned_backend()
	await create_timer(0.5).timeout
	await _a_held_port_is_passed_over()
	BackendSupervisor.stop_owned_backend()
	await create_timer(0.5).timeout
	await _a_recogniser_that_cannot_start_says_why()
	BackendSupervisor.stop_owned_backend()
	for line in results:
		print(line)
	print("OBRA_BACKEND_START_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)


func _a_drawing_sent_early_waits_and_goes_through() -> void:
	var supervisor := _supervisor(PORT)
	supervisor.python_executable = _slow_python()
	var ready := [false]
	supervisor.backend_ready.connect(func() -> void: ready[0] = true)
	supervisor.ensure_backend()
	var started := Time.get_ticks_msec()
	while not BackendSupervisor.owned_backend_running() and Time.get_ticks_msec() - started < 5000:
		await process_frame
	_check(BackendSupervisor.is_waking(), "the recogniser is starting", "pid launched, not answering yet")

	var client := (load("res://scripts/sketch_client.gd") as GDScript).new() as Node
	root.add_child(client)
	await process_frame
	var heard: Dictionary = {}
	client.connect("prediction_waiting", func(m: String) -> void: heard["waiting"] = m)
	client.connect("prediction_failed", func(m: String) -> void: heard["failed"] = m)
	client.connect("entity_prediction_received", func(entity: String, _n: String, _c: float,
			_i: Image, _r: Dictionary) -> void: heard["answer"] = entity)
	client.connect("entity_declined", func(entity: String, _c: float, _m: float,
			_r: Dictionary) -> void: heard["answer"] = entity)
	# The panel's Transform press, with a drawing of a circle on paper.
	client.set("_pending_body", JSON.stringify({"image_data":
		Marshalls.raw_to_base64(_a_circle().save_png_to_buffer())}))
	client.call("_send_pending")
	var waited := 0.0
	while waited < 60.0 and not heard.has("answer") and not heard.has("failed"):
		await create_timer(0.25).timeout
		waited += 0.25
	_check(heard.has("waiting"), "sent too early, the drawing waits instead of failing",
		"\"%s\"" % heard.get("waiting", "no word of waiting"))
	_check(heard.has("answer") and not heard.has("failed"), "and goes through by itself once it answers",
		"recognised as %s after %.1f s" % [heard["answer"], waited] if heard.has("answer")
			else "failed: %s" % heard.get("failed", "nothing after 60 s"))
	_check(ready[0] and not BackendSupervisor.is_waking(), "and the recogniser is up, not waking",
		"ready on %s" % BackendSupervisor.url())
	client.queue_free()
	supervisor.queue_free()
	await process_frame


## Windows keeps ranges of ports for Hyper-V and WSL, and 8000 can fall in one; anything else
## on the machine can hold it too. The server goes to a spare and the game follows it there.
func _a_held_port_is_passed_over() -> void:
	var holder := TCPServer.new()
	holder.listen(HELD_PORT, "127.0.0.1")
	var supervisor := _supervisor(HELD_PORT)
	supervisor.startup_timeout_sec = 3.0
	var ready := [false]
	supervisor.backend_ready.connect(func() -> void: ready[0] = true)
	supervisor.ensure_backend()
	var waited := 0.0
	while waited < 60.0 and not ready[0]:
		await create_timer(0.25).timeout
		waited += 0.25
	var at := BackendSupervisor.url()
	_check(ready[0] and not at.contains(":%d/" % HELD_PORT),
		"a port something else holds is passed over for a spare", "ready at %s, %d held" % [at, HELD_PORT])
	holder.stop()
	supervisor.queue_free()
	await process_frame


func _a_recogniser_that_cannot_start_says_why() -> void:
	OS.set_environment("OBRA_MODEL", "/no/such/model.onnx")
	var supervisor := _supervisor(PORT)
	var said := [""]
	supervisor.backend_failed.connect(func(message: String) -> void: said[0] = message)
	supervisor.ensure_backend()
	var waited := 0.0
	while waited < 30.0 and said[0].is_empty():
		await create_timer(0.25).timeout
		waited += 0.25
	OS.unset_environment("OBRA_MODEL")
	_check(said[0].contains("Model not found"), "a recogniser that cannot start says why",
		"\"%s\"" % said[0].left(110))
	_check(BackendSupervisor.failure_reason() == said[0], "and a drawing sent then is told the same",
		"failure_reason() matches")
	supervisor.queue_free()
	await process_frame


func _supervisor(port: int) -> BackendSupervisor:
	var supervisor := BackendSupervisor.new()
	supervisor.backend_port = port
	root.add_child(supervisor)
	return supervisor


## The project's Python, made to take its time the way a first start on Windows does.
func _slow_python() -> String:
	var venv := ProjectSettings.globalize_path("res://").path_join("../.venv").simplify_path()
	var real := BackendSupervisor.python_in(venv, OS.has_feature("windows"))
	if OS.has_feature("windows"):
		var bat := ProjectSettings.globalize_path(UserData.path("slow_python.bat"))
		_write(bat, "@echo off\r\ntimeout /t %d /nobreak >nul\r\n\"%s\" %%*\r\n" % [SLOW_START_SEC, real])
		return bat
	var sh := ProjectSettings.globalize_path(UserData.path("slow_python.sh"))
	_write(sh, "#!/bin/sh\nsleep %d\nexec \"%s\" \"$@\"\n" % [SLOW_START_SEC, real])
	OS.execute("chmod", ["+x", sh])
	return sh


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _a_circle() -> Image:
	var image := Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.965, 0.95, 0.9))
	for y in range(256):
		for x in range(256):
			var r := Vector2(x - 128, y - 128).length()
			if absf(r - 80.0) < 6.0:
				image.set_pixel(x, y, Color.BLACK)
	return image
