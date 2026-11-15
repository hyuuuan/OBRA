extends SceneTree
## A drawn submarine in Dagat, boarded and dived: it is driven, not rowed, and the apo inside it
## keeps her breath.
##
##   godot --headless --path game --script res://tests/run_level3_submarine_probe.gd
##
## Kent: "when i try to ride it, it rows but then my oxygen is affected which should not be
## happening". Seated in a submarine that had dived, the apo was in the water by every test the
## breath makes, and ran out of it at seven seconds inside a sealed hull; and she held the
## bangka's paddle and stroked with it the whole way down. Drawn, set down in the sea, boarded
## with E and dived with the keys, the way a player does it.

const RosterFixtures = preload("res://tests/roster_fixtures.gd")
const CHECKS := 4
## Longer than the seven seconds of breath a swimmer has, so a breath that drains runs out.
const DIVE_SECONDS := 10.0

var level: Node
var results: Array[String] = []
var failures := 0
var checked := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	results.append("  %s  %-48s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _run() -> void:
	print("\n===== A SUBMARINE IN DAGAT =====")
	level = (load("res://level_3.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	var waited := 0.0
	while waited < 8.0 and (level.get("player") == null or level.get("director") == null):
		await _wait(0.1)
		waited += 0.1
	if level.has_method("_end_the_opening"):
		level.call("_end_the_opening", true)
	await _unpause()
	var director = level.get("director")
	var constants: Dictionary = level.get_script().get_script_constant_map()
	var air_full := float(constants.get("AIR_SECONDS", 7.0))
	var waterline := float(level.get("_waterline_y"))
	# The shore is the brush; the crossing is chosen, so a drawing is taken.
	director.call("solve_with_item", "L3_B0_SHORE", "new_brush")
	director.call("enter_obstacle", "L3_N1")
	director.call("commit_route", "L3_N1", "artist")
	await _unpause()
	# Drawn through the drawing panel's door, then set down in the sea from the beach.
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	level.call("_on_drawing_ready", "submarine", "Submarine", sheet, {"confidence": 0.9},
		RosterFixtures.for_rig("", "submarine"), 1.0)
	await _unpause()
	var edges: Vector2 = level.call("level_data_shore_edges")
	var sand := (level.get_node(^"EnvironmentBaseplate/GameplayPlane/Marks/BrushMark") as Node2D) \
		.global_position.y
	_place(Vector2(edges.x - 60.0, sand - 2.0))
	await _frames(10)
	var placement := level.get("placement_controller") as PlacementController
	var slot := int(level.call("_slot_holding", "submarine"))
	if slot >= 0:
		level.call("_on_inventory_slot_pressed", slot)
	placement.update_target(Vector2(edges.x + 220.0, waterline + 120.0))
	var set_down := placement.confirm_placement()
	await _unpause()
	await _frames(30)
	var sub := level.get("_last_placed") as UtilityObject
	if not set_down or sub == null:
		_check(false, "a drawn submarine is set down in the sea", "set down %s" % set_down)
		_finish()
		return
	# Boarded with E, from beside it.
	_place(sub.global_position + Vector2(0.0, -40.0))
	await _frames(4)
	level.call("press_interact")
	await _unpause()
	var apo := level.get("player") as Node2D
	var aboard := bool(sub.call("has_passenger", apo))
	_check(aboard, "a drawn submarine is boarded with E", "riding %s" % apo.call("is_riding"))
	# Dived with the keys, a little forward, for longer than a breath lasts.
	var deepest := -INF
	var least_air := INF
	var rowed := false
	var winded := false
	var status := level.get("status_label") as Label
	var seconds := 0.0
	Input.action_press(&"move_down")
	Input.action_press(&"move_right")
	while seconds < DIVE_SECONDS:
		await physics_frame
		if paused:
			Input.action_release(&"move_down")
			Input.action_release(&"move_right")
			await _unpause()
			Input.action_press(&"move_down")
			Input.action_press(&"move_right")
		seconds += 1.0 / 60.0
		apo = level.get("player") as Node2D
		deepest = maxf(deepest, apo.global_position.y)
		least_air = minf(least_air, float(level.get("_air")))
		rowed = rowed or apo.get_node_or_null(^"Paddle") != null
		winded = winded or status.text.begins_with("Out of breath")
	Input.action_release(&"move_down")
	Input.action_release(&"move_right")
	var still_aboard := bool(sub.call("has_passenger", level.get("player")))
	_check(still_aboard and deepest > waterline + 120.0, "and it dives, with her in it",
		"down to y %.0f, the surface at %.0f, aboard %s" % [deepest, waterline, still_aboard])
	_check(least_air >= air_full - 0.01 and not winded, "and she keeps her breath inside it",
		"breath at least %.1f of %.1f over %.0f s%s" % [least_air, air_full, DIVE_SECONDS,
			", OUT OF BREATH" if winded else ""])
	_check(not rowed, "and it is driven, not rowed", "no paddle" if not rowed else "she rowed it")
	_finish()


func _finish() -> void:
	for line in results:
		print(line)
	if checked != CHECKS:
		print("OBRA_LEVEL3_SUBMARINE_FAILED: %d checks ran, %d expected" % [checked, CHECKS])
		quit(1)
	elif failures == 0:
		print("OBRA_LEVEL3_SUBMARINE_OK")
		quit(0)
	else:
		print("OBRA_LEVEL3_SUBMARINE_FAILED=%d" % failures)
		quit(1)


func _place(at: Vector2) -> void:
	var body := level.get("player") as Node2D
	if body.has_method("apply_morph_state"):
		body.call("apply_morph_state", {"position": at, "linear_velocity": Vector2.ZERO})
	else:
		body.global_position = at


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _unpause() -> void:
	for _attempt in range(30):
		for node in get_nodes_in_group(&"modal_overlays"):
			if node.has_method("is_open") and node.has_method("close") and bool(node.call("is_open")):
				node.call("close")
		call_group(DialogueBox.GROUP, &"hide_line")
		paused = false
		await physics_frame
		if not paused:
			await physics_frame
			if not paused:
				return
