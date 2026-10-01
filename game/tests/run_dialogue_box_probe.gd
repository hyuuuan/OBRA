extends SceneTree
## THE DIALOGUE BOX, AT THE ONE MOMENT IT COULD STRAND A PLAYER.
##   godot --headless --path game --script res://tests/run_dialogue_box_probe.gd
##
## A conversation stops the world until it is read, and the box fades out over 0.16 s when one
## ends. A conversation begun on the frame the last one ended -- from `conversation_finished`,
## or from the first physics step of the world the last one gave back -- found the box still at
## full opacity, so the fade-out was left running and hid the box 0.16 s later with the new
## conversation open. The world stayed paused under an invisible box, and the key that would
## have read on was ignored because the box was not visible. Played in Dagat's dive: Lolo's
## ink lines start on the frame his "Go on then" ends, and about one run in three the level
## froze there for good.
##
## run_click_ui drives the box with real keys and holds the second half (a hidden conversation
## still takes the key). This holds the first, headless, because the frame it needs can be made
## to happen exactly by starting the next beat from the box's own `conversation_finished`.

var level: Node
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-50s %s" % ["OK  " if ok else "FAIL", what, detail])


func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _run() -> void:
	print("\n===== THE DIALOGUE BOX =====")
	level = (load("res://level_3.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	await _frames(30)
	var box = level.get("dialogue_box")
	if box == null:
		print("OBRA_DIALOGUE_BOX_FAILED=1  (the level built no dialogue box)")
		quit(1)
		return
	box.call("set_auto_dismiss", false)
	box.call("skip_all")
	await _frames(30)

	# One beat, read to its end -- and the next begun from the end of it, as a level does.
	box.call("speak", [{"text": "The last line of one beat.", "speaker": "Lolo"}])
	await _frames(30)
	(box as Object).connect(&"conversation_finished", func() -> void:
		box.call("speak", [{"text": "Begun as that one ended.", "speaker": "Lolo"}]),
		CONNECT_ONE_SHOT)
	_press(box)
	_press(box)
	# Well past the 0.16 s the old fade took.
	await _frames(30)
	var shown: CanvasItem = box
	_check(bool(box.call("is_open")) and shown.visible and shown.modulate.a > 0.9,
		"a beat begun as the last one ends stays on screen",
		"open %s, visible %s, alpha %.2f, showing '%s'" % [box.call("is_open"), shown.visible,
			shown.modulate.a, box.call("current_line")])
	_check(paused == bool(box.call("is_open")), "and the world is paused only while it is up",
		"paused %s" % paused)

	var presses := 0
	while bool(box.call("is_open")) and presses < 12:
		_press(box)
		await _frames(2)
		presses += 1
	await _frames(20)
	_check(not bool(box.call("is_open")) and not paused, "and it can be read to the end",
		"closed after %d presses, paused %s" % [presses, paused])

	print("OBRA_DIALOGUE_BOX_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)


## The advance key, handed to the box the way the viewport hands it: the first press of a line
## still typing catches it up, the next turns the page.
func _press(box) -> void:
	var event := InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	box.call("_unhandled_input", event)
