extends SceneTree
## THE KEYS AND LOLO'S HINT STAND OVER THE APO, NEVER ON HER -- at every zoom a room uses.
##   godot --headless --path game --script res://tests/run_head_clear_probe.gd
##
## Both ride over her in SCREEN space, on purpose: a key cap must not triple in size when she
## walks indoors. But the rooms zoom in -- the straw room to 2, Ang Bale to 3, the Piyesta
## alleys and the lit house to 1.6 -- and both were placed a fixed distance over her FEET, 118px
## for the row and 172px for the bar. Outdoors she is 92px tall and that clears her. Indoors
## she grew around them: E PICK UP and W CLIMB across her face in Alley 1, Lolo's "Cold ash in
## the hearth" across her face in Ang Bale. Found by photographing the rooms; no suite asked,
## because every HUD check measured the HUD against itself and none measured it against her.
##
## So this stands her outside and in both of Payyo's rooms, puts up a key prompt and a line of
## Lolo's, lets them settle, and fails if either covers her. Outdoors it also holds the row to
## exactly where it always was: the fix is a lift that is zero at the outdoor zoom.

const OUTDOORS := Vector2(1110.0, 380.0)
## The row bobs two pixels while it shows; a little over that is "where it always was".
const BOB := 3.0

var level: Node2D
var keys: ActionPromptHUD
var hint: HintBar
var spot: TutorialSpotlight
var failures := 0
## How far the row stood over her head outdoors, where it has always been right.
var _outdoor_clearance := INF


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-48s %s" % ["OK  " if ok else "FAIL", what, detail])


func _run() -> void:
	print("\n===== HEAD CLEAR =====")
	level = (load("res://game_level.tscn") as PackedScene).instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.2)
	keys = level.get("action_prompts") as ActionPromptHUD
	hint = level.get("hint_bar") as HintBar
	spot = level.get("tutorial_spotlight") as TutorialSpotlight
	if keys == null or hint == null:
		_check(false, "the level has its key row and hint bar", "missing")
		_finish()
		return
	# The level clears E and CLIMB in every physics step from what is actually in reach; this
	# puts them back after it, every frame, before the row lays itself out.
	process_frame.connect(_hold_the_prompts_up)

	await _stand(OUTDOORS)
	await _measure("outdoors", true)
	for room_group: StringName in [&"straw_rooms", &"bale_interiors"]:
		var room := level.get_tree().get_first_node_in_group(room_group) as Node2D
		if room == null:
			_check(false, "%s exists" % room_group, "not in the level")
			continue
		await _stand(Vector2(room.call("entry_point")))
		await _stand(room.global_position)
		await _measure(String(room_group), false)
	_finish()


func _finish() -> void:
	print("OBRA_HEAD_CLEAR_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)


func _hold_the_prompts_up() -> void:
	if keys != null and is_instance_valid(keys):
		keys.set_pickup_available(true, "Ladder")
		keys.set_climb_available(true, "Ladder")
	if spot != null and is_instance_valid(spot) and spot.is_open():
		spot.close()


func _stand(at: Vector2) -> void:
	var player := level.get("player") as Node2D
	player.global_position = at
	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO
	await _wait(1.0)


## Wait for the story box to have finished (the bar stands down while anyone speaks), say a
## line, let both ease into place, then read what each paints against where she stands.
func _measure(where: String, outdoors: bool) -> void:
	# ⚠ A READING TAKEN IN A CLOSE-UP IS NOT A READING OF THE ROOM. Lolo says a `lead` line
	# before a lesson card, through the story box, and the camera zooms in on him to 1.15 for
	# it; the hint bar stands aside while he talks. So wait for the quiet, and if a line starts
	# while the bar settles, wait again and take it again.
	# In auto-dismiss nobody is ever seen speaking -- a story beat is dropped as it is said -- but
	# the beat still takes the hint bar down (two channels never talk at once), so the line is
	# checked for as well, and said again if a beat took it.
	for attempt in 4:
		await _quiet()
		hint.show_hint("Cold ash in the hearth, and the rack still hung over it.", "Lolo", 30.0)
		await _wait(1.6)
		if not _someone_speaking() and _at_rest() and _hint_up():
			break
	var row := keys.find_child("FloatingActions", true, false) as Control
	var bar := hint.find_child("Panel", true, false) as Control
	var apo: Rect2 = level.call("_player_on_screen")
	var zoom := level.get_viewport().get_canvas_transform().get_scale().y
	print("  ..    %-48s zoom %.2f, apo %s" % [where, zoom, _show(apo)])
	_check(row != null and row.is_visible_in_tree(), "%s: the key row is up" % where,
		_show(row.get_global_rect()) if row != null else "none")
	_check(bar != null and bar.is_visible_in_tree() and bar.modulate.a > 0.5,
		"%s: Lolo's line is up" % where, _show(bar.get_global_rect()) if bar != null else "none")
	if row == null or bar == null:
		return
	var row_rect := row.get_global_rect()
	var bar_rect := bar.get_global_rect()
	_check(not row_rect.intersects(apo), "%s: the keys are not on her" % where,
		"row bottom %.0f, her head %.0f" % [row_rect.end.y, apo.position.y])
	# NOT JUST OFF HER BOX: as far off it as outdoors. The box stops at 92 and her hair at
	# about 96, so a row that only cleared the box sat on her hair in Alley 1. Measured
	# against what outdoors actually showed, not against the constant that sets it.
	var clearance := apo.position.y - row_rect.end.y
	if outdoors:
		_outdoor_clearance = clearance
	else:
		# Both readings bob, so they may sit two bobs apart.
		_check(clearance >= _outdoor_clearance - 2.0 * BOB,
			"%s: with the room it has outdoors" % where,
			"%.0f px over her head, outdoors %.0f" % [clearance, _outdoor_clearance])
	_check(not bar_rect.intersects(apo), "%s: Lolo's line is not on her" % where,
		"bar bottom %.0f, her head %.0f" % [bar_rect.end.y, apo.position.y])
	_check(not bar_rect.intersects(row_rect), "%s: nor on the keys" % where,
		"bar %s, row %s" % [_show(bar_rect), _show(row_rect)])
	if outdoors:
		var feet := apo.end.y
		var usual := feet + ActionPromptHUD.FOLLOW_OFFSET.y
		_check(absf(row_rect.end.y - usual) <= BOB, "outdoors: the row is where it always was",
			"bottom %.0f, %.0f over her feet as before" % [row_rect.end.y, -ActionPromptHUD.FOLLOW_OFFSET.y])
	hint.clear()


## Nobody talking, and the camera at the room's own zoom rather than a close-up on a speaker.
##
## ⚠ AND LET GO OF A CLOSE-UP NOBODY IS IN. The level zooms in on whoever speaks and lets go
## on the story box's `conversation_finished` -- but in auto-dismiss, which every unattended
## probe runs in, DialogueBox.speak() drops the lines without emitting it, so the camera stays
## at 1.15 for good. Played for real (lines pressed through) it lets go at once; checked on
## 2026-10-09. So once nobody is talking, a focus still held is released here, as the level
## would have.
func _quiet() -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while _someone_speaking() and Time.get_ticks_msec() < deadline:
		await process_frame
	var camera := level.call("_world_camera") as WorldCameraController
	if camera != null and camera.get("_focus") != null:
		camera.release_focus(0.0)
	while not _at_rest() and Time.get_ticks_msec() < deadline:
		await process_frame


func _hint_up() -> bool:
	var bar := hint.find_child("Panel", true, false) as Control
	return bar != null and bar.is_visible_in_tree() and bar.modulate.a > 0.5


func _at_rest() -> bool:
	var camera := level.call("_world_camera") as Camera2D
	if camera == null:
		return true
	return absf(camera.zoom.y - float(camera.get("base_zoom"))) < 0.005


func _someone_speaking() -> bool:
	for node in get_nodes_in_group(DialogueBox.GROUP):
		if (node as CanvasItem).visible:
			return true
	return false


func _show(rect: Rect2) -> String:
	return "(%.0f, %.0f) %.0fx%.0f" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout
