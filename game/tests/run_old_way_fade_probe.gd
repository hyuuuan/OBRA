extends SceneTree
## The old way fades (LevelBase._fades_the_old_way), in every level that opts in: the marked
## scenery is whole until she nears it, fades into the level's own colour (never Mayon's paper)
## to its mark once she passes fade_at, keeps its collision-free scenery standing, and a
## checkpoint restore puts it back ahead of her and settles it at once behind her.
##
##   godot --headless --path game --script res://tests/run_old_way_fade_probe.gd

const MAYON_PAPER := Color(0.957, 0.937, 0.894)
## Each level that opts in: its scene and the one thing that must fade there.
const LEVELS := [
	["res://game_level.tscn", "EnvironmentBaseplate/GameplayPlane/Gorge/RuinedBridge"],
]
const CHECKS := 6 * 1

var checked := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for entry: Array in LEVELS:
		await _level_fades_its_old_way(String(entry[0]), NodePath(String(entry[1])))
	if failures == 0 and checked == CHECKS:
		print("OBRA_OLD_WAY_FADE_OK checks=%d" % checked)
		quit(0)
	else:
		print("OBRA_OLD_WAY_FADE_FAILED=%d checked=%d/%d" % [failures, checked, CHECKS])
		quit(1)


func _level_fades_its_old_way(scene: String, path: NodePath) -> void:
	var level := (load(scene) as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(30):
		await physics_frame
	var thing := level.get_node(path) as Node2D
	var at := float(thing.get_meta("fade_at"))
	var to := float(thing.get_meta("fade_to", 1.0))
	var drainable := thing.get_node_or_null(^"Drainable") as Drainable
	_check(drainable != null and is_zero_approx(drainable.drain),
		"%s: the old way wears the fade and is whole at the start" % scene)
	var material := thing.material as ShaderMaterial
	var paper: Color = material.get_shader_parameter("paper") if material != null else MAYON_PAPER
	_check(not paper.is_equal_approx(MAYON_PAPER), "%s: it fades into its own colour" % scene,
		str(paper))

	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": Vector2(at + 40.0, player.global_position.y - 40.0),
		"linear_velocity": Vector2.ZERO})
	var waited := 0.0
	while drainable.drain < to - 0.001 and waited < 5.0:
		await physics_frame
		waited += 1.0 / 60.0
	_check(absf(drainable.drain - to) < 0.001, "%s: past fade_at it fades to its mark" % scene,
		"drain %.3f, want %.3f" % [drainable.drain, to])
	# Long enough for a fade that overshot its mark to have gone all the way.
	for _frame in range(int((float(thing.get_meta("fade_over", 1.5)) + 0.5) * 60.0)):
		await physics_frame
	_check(absf(drainable.drain - to) < 0.001 and (to >= Drainable.BLANK or not drainable.is_blank()),
		"%s: it stays at its mark" % scene, "drain %.3f" % drainable.drain)

	level.call("_settle_the_fading", at - 400.0)
	_check(is_zero_approx(drainable.drain), "%s: a restore ahead of it brings it back" % scene)
	level.call("_settle_the_fading", at + 400.0)
	_check(absf(drainable.drain - to) < 0.001, "%s: a restore past it settles it at once" % scene)
	level.queue_free()
	await process_frame


func _check(ok: bool, label: String, detail: String = "") -> void:
	checked += 1
	if ok:
		print("  ok    %s" % label)
	else:
		failures += 1
		print("  FAIL  %s  %s" % [label, detail])
