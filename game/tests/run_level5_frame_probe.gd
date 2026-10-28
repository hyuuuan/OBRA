extends SceneTree
## Mayon's last shot: the frame returns -- the real room, the stories of what she saved in the
## order she saved them, lolo last -- then black, then home.
##
##   godot --headless --path game --script res://tests/run_level5_frame_probe.gd

## Every check this probe makes. A script error that skips them must not pass as quiet.
const CHECKS := 3

var failures := 0
var checked := 0
var level: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	level = await _open_level()
	var bare: Array = level.call("frame_hooks")
	for id in ["church", "kubo"]:
		(level.call("_fragment", id) as MemoryFragment2D).restore_to("saved", [[0.0, 0.0, 9.0, 9.0]])
		(level.get("_save_order") as Array).append(id)
	var told: Array = level.call("frame_hooks")
	_check(bare == ["FRAME.open", "FRAME.lolo", "FRAME.brush"]
		and told == ["FRAME.open", "FRAME.church", "FRAME.kubo", "FRAME.lolo", "FRAME.brush"],
		"she tells lola what she saved, in the order she saved it, and lolo last",
		"nothing saved: %s; two saved: %s" % [bare, told])
	level.call("_play_own_ending")
	await _frames(10)
	var frame := level.get_node_or_null("FrameReturn") as FrameReturn
	var shown := frame != null and frame.layer > 5 and frame.layer < 8
	var black := await _until(func() -> bool: return frame != null and is_instance_valid(frame) and frame.is_black(), 40.0)
	_check(shown and black, "the real room comes up over the painting, under the lines, and cuts to black",
		"room on layer %s, black %s" % [frame.layer if frame != null else -1, black])
	var home := await _until(func() -> bool: return not is_instance_valid(level) or bool(level.call("went_home")), 10.0)
	_check(home, "then she is home", "went home %s" % home)
	if failures == 0 and checked == CHECKS:
		print("OBRA_LEVEL5_FRAME_OK")
		quit(0)
	else:
		if checked != CHECKS:
			print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
		print("OBRA_LEVEL5_FRAME_FAILED=%d" % maxi(1, failures))
		quit(1)


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
