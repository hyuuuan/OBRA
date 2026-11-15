extends SceneTree
## The creatures that fight her show their health over them, in Dilim, when it means something.
##
##   godot --headless --path game --script res://tests/run_foe_health_probe.gd
##
## Kent: "show the like hp/life of the creatures in Dilim level". A struck creature only flashed, so
## a blow that landed read as one that missed (his "the cannon ... seems to not work"). The bars are
## over the dark, over the creature's head, one pip a blow; they show once a creature is after her or
## hurt, and never while it waits, once it is dead, while the tiyanak is still a child, once the
## bungisngis has sat aside or the manananggal has been driven off, or over its lower half, which no
## blow can touch. Payyo, which does not fight, builds none.

const CHECKS := 13
const SIGBIN_STAND := 6950.0

var level: Node
var failures := 0
var checked := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(240.0).timeout.connect(func() -> void:
		print("OBRA_FOE_HEALTH_FAILED=watchdog")
		quit(2))
	level = await _open("res://game_level.tscn")
	_check(level.get("foe_health_bars") == null, "Payyo, which does not fight, builds no bars",
		"bars %s" % str(level.get("foe_health_bars")))
	level.queue_free()
	await _frames(3)
	level = await _open("res://level_4.tscn")
	var bars := level.get("foe_health_bars") as FoeHealthBars
	_check(bars != null and bars.layer > DarknessLayer.LAYER and bars.layer < 5,
		"Dilim builds them, over the dark and under the HUD", "layer %s" % (str(bars.layer) if bars != null else "-"))
	if bars == null:
		_finish()
		return
	await _a_creature_shows_its_health_when_it_means_something(bars)
	_its_disguise_or_its_ending_hides_it(bars)
	_finish()


func _a_creature_shows_its_health_when_it_means_something(bars: FoeHealthBars) -> void:
	var sigbin := _foe("sigbin")
	_check(sigbin != null and sigbin.state == Enemy2D.State.IDLE and not bars.shown().has(sigbin),
		"a creature waiting, unhurt, shows no bar", "state %s" % (sigbin.state_name() if sigbin != null else "-"))
	if sigbin == null:
		return
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": Vector2(SIGBIN_STAND, 596.0), "linear_velocity": Vector2.ZERO})
	(level.get("player_health") as PlayerHealth).call("_start_grace", 600.0)
	var after_her := false
	for _frame in range(120):
		await _frames(1)
		if sigbin.state != Enemy2D.State.IDLE:
			after_her = true
			break
	await _frames(2)
	_check(after_her and bars.shown().has(sigbin), "once it is after her, its bar is up",
		"state %s" % sigbin.state_name())
	# Over its head, centred: the bottom of the bar clear of the highest painted pixel of its art,
	# and no more than a gap and a little above it -- not floating off the top of a tall frame.
	var canvas := level.get_viewport().get_canvas_transform()
	var rect := bars.bar_rect(sigbin)
	var head := canvas * (sigbin.global_position + Vector2(0.0, sigbin.art.position.y + sigbin.art.ink_top()))
	var middle := canvas * sigbin.global_position
	_check(rect.end.y <= head.y and head.y - rect.end.y <= Enemy2D.HEALTH_BAR_GAP + 2.0
			and absf(rect.get_center().x - middle.x) <= 1.0
			and rect.position == rect.position.round(),
		"over its head, centred, on whole pixels", "bar %s, head at %.0f, middle %.0f" % [str(rect), head.y, middle.x])
	_check(is_equal_approx(rect.size.x, sigbin.max_hp * FoeHealthBars.PIP_WIDE
			+ (sigbin.max_hp - 1) * FoeHealthBars.PIP_GAP + FoeHealthBars.PAD * 2.0),
		"one pip for each blow it can take", "%.0f px for %d" % [rect.size.x, sigbin.max_hp])
	var before := sigbin.hp
	sigbin.apply_tool_hit("sword", 0.0, player)
	await _frames(2)
	var seen: Dictionary = (bars.get("_seen") as Dictionary).get(sigbin.get_instance_id(), {})
	_check(sigbin.hp == before - 1 and int(seen.get("hp", -1)) == sigbin.hp and int(seen.get("lost", 0)) == 1,
		"a blow takes a pip, and lights the one it took", "hp %d -> %d, lit %d" % [before, sigbin.hp,
			int(seen.get("lost", 0))])
	# Hurt, and given up on her: the bar stays, because the hurt is still in it.
	sigbin.call("_enter", Enemy2D.State.IDLE)
	_check(bars.shown().has(sigbin), "hurt, it keeps its bar even waiting", "state %s, hp %d/%d" % [
		sigbin.state_name(), sigbin.hp, sigbin.max_hp])
	while not sigbin.is_dead():
		sigbin.apply_tool_hit("sword", 0.0, player)
	await _frames(2)
	_check(not bars.shown().has(sigbin), "dead, it has none", "state %s" % sigbin.state_name())


## Each of these, hurt and after her, still shows nothing: what would make a bar wrong is its own.
func _its_disguise_or_its_ending_hides_it(bars: FoeHealthBars) -> void:
	var tiyanak := _foe("tiyanak") as Tiyanak2D
	_hurt_and_after_her(tiyanak)
	var as_child := bars.shown().has(tiyanak)
	tiyanak.set("_revealed", true)
	_check(not as_child and bars.shown().has(tiyanak), "the tiyanak shows none while it is a child, and one once it is not",
		"as a child %s, revealed %s" % [as_child, bars.shown().has(tiyanak)])
	var bungisngis := _foe("bungisngis")
	_hurt_and_after_her(bungisngis)
	var standing := bars.shown().has(bungisngis)
	bungisngis.set("_aside", true)
	_check(standing and not bars.shown().has(bungisngis), "the bungisngis shows none once it has sat aside",
		"standing %s, aside %s" % [standing, bars.shown().has(bungisngis)])
	var upper := _foe("manananggal_upper")
	_hurt_and_after_her(upper)
	var fighting := bars.shown().has(upper)
	upper.set("_leaving", true)
	_check(fighting and not bars.shown().has(upper), "the manananggal shows none once it is driven off",
		"fighting %s, leaving %s" % [fighting, bars.shown().has(upper)])
	var lower := _foe("manananggal_lower")
	_hurt_and_after_her(lower)
	_check(not bars.shown().has(lower), "and its lower half, which no blow touches, never shows one",
		"shown %s" % bars.shown().has(lower))


func _hurt_and_after_her(foe: Enemy2D) -> void:
	if foe == null:
		return
	foe.hp = maxi(1, foe.max_hp - 1)
	foe.state = Enemy2D.State.CHASE


func _foe(kind: String) -> Enemy2D:
	for node in get_nodes_in_group(Enemy2D.FOES):
		if (node as Enemy2D).kind == kind:
			return node as Enemy2D
	return null


func _open(path: String) -> Node:
	var scene := (load(path) as PackedScene).instantiate()
	(scene.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(scene)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(30)
	return scene


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		if paused:
			call_group(DialogueBox.GROUP, &"hide_line")
			paused = false


func _finish() -> void:
	if checked != CHECKS:
		print("OBRA_FOE_HEALTH_FAILED: %d checks ran, %d expected" % [checked, CHECKS])
		quit(1)
	elif failures == 0:
		print("OBRA_FOE_HEALTH_OK")
		quit(0)
	else:
		print("OBRA_FOE_HEALTH_FAILED=%d" % failures)
		quit(1)


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
