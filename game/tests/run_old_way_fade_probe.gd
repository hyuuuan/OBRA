extends SceneTree
## The old way fades (LevelBase._fades_the_old_way), in every level that opts in: the marked
## scenery is whole until she nears it, fades in the level's own colours (never Mayon's white)
## to its mark once she passes fade_at, keeps its collision-free scenery standing, and a
## checkpoint restore puts it back ahead of her and settles it at once behind her.
##
##   godot --headless --path game --script res://tests/run_old_way_fade_probe.gd

const MAYON_PAPER := Color(0.957, 0.937, 0.894)
const WandererClass = preload("res://scripts/wanderer.gd")
## Each level that opts in: its scene and the one thing that must fade there.
const LEVELS := [
	["res://game_level.tscn", "EnvironmentBaseplate/GameplayPlane/Hagdan/OldSteps"],
	["res://game_level.tscn", "EnvironmentBaseplate/GameplayPlane/Gorge/RuinedBridge"],
	["res://game_level.tscn", "EnvironmentBaseplate/GameplayPlane/Bale/OldLadder"],
	["res://level_4.tscn", "EnvironmentBaseplate/GameplayPlane/OldLog"],
]
const CHECKS := 9 * 4

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
	var where := "%s %s" % [scene.get_file(), path.get_name(path.get_name_count() - 1)]
	var at := float(thing.get_meta("fade_at"))
	var to := float(thing.get_meta("fade_to", 1.0))
	# ⚠ Gone before she can get to it, at a run: an old way still showing at her feet looks like
	# somewhere to stand, and it holds nobody up.
	var reached := at + WandererClass.SPEED * float(thing.get_meta("fade_over", 1.5))
	var near := _leftmost(thing)
	_check(to < Drainable.BLANK or reached <= near, "%s: it is gone before she reaches it" % where,
		"blank at x %.0f, its near edge at %.0f" % [reached, near])
	var drainable := thing.get_node_or_null(^"Drainable") as Drainable
	_check(drainable != null and is_zero_approx(drainable.drain),
		"%s: the old way wears the fade and is whole at the start" % where)
	var material := thing.material as ShaderMaterial
	var paper: Color = material.get_shader_parameter("paper") if material != null else MAYON_PAPER
	var wash: float = material.get_shader_parameter("wash") if material != null else 1.0
	var painted: bool = material.get_shader_parameter("texture_in_colour") if material != null else false
	# Godot 4's COLOR already carries the texture: sampling it again draws the old way darker
	# than it was painted, from the very start (drain.gdshader).
	_check(painted, "%s: it is drawn in its painted colours until it goes" % where)
	# In a dark level it must be seen to be seen going, and not before: the dark stays dark
	# until then. In a lit level it cuts no holes at all.
	var dark := float(level.call("_darkness")) > 0.0
	var before := not (drainable.dark_reveal() as Dictionary).is_empty()
	drainable.set_drain(0.5)
	var going := not (drainable.dark_reveal() as Dictionary).is_empty()
	drainable.restore()
	_check(not before and going == dark and drainable.is_in_group(DarknessLayer.REVEAL_GROUP) == dark,
		"%s: it shows itself in the dark only as it goes, and only where there is dark" % where,
		"dark %s, revealed before %s, while going %s" % [dark, before, going])
	# Never the ash: neither Mayon's paper nor its whitening all the way to a flat slab.
	_check(not paper.is_equal_approx(MAYON_PAPER) and wash < 1.0,
		"%s: it fades in its own colours, not Mayon's white" % where, "%s, wash %.2f" % [paper, wash])

	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": Vector2(at + 40.0, player.global_position.y - 40.0),
		"linear_velocity": Vector2.ZERO})
	var waited := 0.0
	while drainable.drain < to - 0.001 and waited < 5.0:
		await physics_frame
		waited += 1.0 / 60.0
	_check(absf(drainable.drain - to) < 0.001, "%s: past fade_at it fades to its mark" % where,
		"drain %.3f, want %.3f" % [drainable.drain, to])
	# Long enough for a fade that overshot its mark to have gone all the way.
	for _frame in range(int((float(thing.get_meta("fade_over", 1.5)) + 0.5) * 60.0)):
		await physics_frame
	var gone_dark := to < Drainable.BLANK or (drainable.dark_reveal() as Dictionary).is_empty()
	_check(absf(drainable.drain - to) < 0.001 and (to >= Drainable.BLANK or not drainable.is_blank())
		and gone_dark, "%s: it stays at its mark, and once gone shows nothing in the dark" % where,
		"drain %.3f, still revealed %s" % [drainable.drain, not gone_dark])

	level.call("_settle_the_fading", at - 400.0)
	_check(is_zero_approx(drainable.drain), "%s: a restore ahead of it brings it back" % where)
	level.call("_settle_the_fading", at + 400.0)
	_check(absf(drainable.drain - to) < 0.001, "%s: a restore past it settles it at once" % where)
	level.queue_free()
	await process_frame


## The near (left) edge of everything drawn in it, in the world.
func _leftmost(thing: Node2D) -> float:
	var left := INF
	# ⚠ The thing itself, too: an old way that is one sprite (the ladder, the log) has no
	# Sprite2D children, and without it its edge was INF and the check could not fail.
	var sprites: Array[Node] = thing.find_children("*", "Sprite2D", true, false)
	if thing is Sprite2D:
		sprites.append(thing)
	for node in sprites:
		var sprite := node as Sprite2D
		left = minf(left, (sprite.get_global_transform() * sprite.get_rect()).position.x)
	return left


func _check(ok: bool, label: String, detail: String = "") -> void:
	checked += 1
	if ok:
		print("  ok    %s" % label)
	else:
		failures += 1
		print("  FAIL  %s  %s" % [label, detail])
