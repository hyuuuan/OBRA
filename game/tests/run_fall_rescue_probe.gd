extends SceneTree
## A fall below a level ends at her last safe place, not on top of the sky.
##
##   godot --headless --path game --script res://tests/run_fall_rescue_probe.gd
##
## Falling past a level's bottom moved the apo to the top of the world, a frame before the level's
## own fall line could take her back -- so it never did. Terraces' bottom is a hand under its
## ground: from the top she landed on the lid over the valley or on a room parked in the sky, and
## stayed there; in Pista she landed on the sky's props, or fell and wrapped for ever. Dropped below
## the bottom at the spots that stuck, she must come back down to the ground, never up top; and a
## drawn body that falls is brought back the same way.

const CHECKS := 3
## Where she stuck: x positions in each level, found by dropping her below the bottom.
const STUCK_AT := {
	"res://game_level.tscn": [600.0, 1792.0, 4520.0],
	"res://level_2.tscn": [3440.0, 6040.0, 9600.0],
}

var level: Node2D
var failures := 0
var checked := 0


func _initialize() -> void:
	call_deferred("_run")


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _run() -> void:
	create_timer(240.0).timeout.connect(func() -> void:
		print("OBRA_FALL_RESCUE_FAILED=watchdog")
		quit(2))
	for path: String in STUCK_AT:
		await _open(path)
		var bounds := Rect2(level.get("environment").get("world_bounds"))
		var start := (level.get("player") as Node2D).global_position
		var up_top: Array[String] = []
		for x: float in STUCK_AT[path]:
			var highest := await _drop(Vector2(x, bounds.end.y - 4.0), 4.0)
			var apo := level.get("player") as Node2D
			# Back in the world on the ground, and never sent up into the sky on the way.
			var ended := apo.global_position.y
			if highest < start.y - 250.0 or ended < start.y - 250.0 or ended > bounds.end.y:
				up_top.append("x %.0f: rose to %.0f, ended at %.0f" % [x, highest, ended])
		_check(up_top.is_empty(), "fallen below %s, she comes back down, never up top" % path.get_file(),
			"%d drops" % STUCK_AT[path].size() if up_top.is_empty() else "; ".join(up_top))
		if path == "res://game_level.tscn":
			await _a_drawn_body_that_falls_comes_back(bounds, start)
		level.queue_free()
		await _wait(0.3)
	_finish()


func _a_drawn_body_that_falls_comes_back(bounds: Rect2, start: Vector2) -> void:
	var drawing := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	drawing.fill(Color.WHITE)
	level.call("_on_drawing_ready", "frog", "Frog", drawing, {},
		preload("res://tests/drawn_like_people_fixtures.gd")._frog(), 0.0)
	await _wait(0.6)
	var highest := await _drop(Vector2(600.0, bounds.end.y - 4.0), 4.0, false)
	var body := level.get("player") as Node2D
	var at := (body.call("get_physics_anchor") as Node2D).global_position if body.has_method("get_physics_anchor") \
		else body.global_position
	_check(at.y < bounds.end.y and highest >= start.y - 250.0,
		"a drawn body that falls below is brought back too", "ended at %.0f, highest %.0f" % [at.y, highest])


## Below the bottom at `at`, falling; how high she went in the next `seconds`.
func _drop(at: Vector2, seconds: float, as_apo: bool = true) -> float:
	if as_apo:
		level.call("_revert_to_base_form")
		await _wait(0.2)
	(level.get("player") as Node2D).call("apply_morph_state", {"position": at, "linear_velocity": Vector2(0.0, 600.0)})
	var highest := INF
	var clock := 0.0
	while clock < seconds:
		await physics_frame
		if paused:
			call_group(DialogueBox.GROUP, &"hide_line")
			paused = false
		clock += 1.0 / 60.0
		var body := level.get("player") as Node2D
		if body != null and is_instance_valid(body):
			var y := (body.call("get_physics_anchor") as Node2D).global_position.y \
				if body.has_method("get_physics_anchor") else body.global_position.y
			highest = minf(highest, y)
	return highest


func _open(path: String) -> void:
	level = (load(path) as PackedScene).instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.2)


func _finish() -> void:
	if checked != CHECKS:
		print("OBRA_FALL_RESCUE_FAILED: %d checks ran, %d expected" % [checked, CHECKS])
		quit(1)
	elif failures == 0:
		print("OBRA_FALL_RESCUE_OK")
		quit(0)
	else:
		print("OBRA_FALL_RESCUE_FAILED=%d" % failures)
		quit(1)


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
