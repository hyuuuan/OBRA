extends SceneTree
## Dilim's first stretch, played headless: the santelmo, the nuno's mound, the first clearing.
##
##   godot --headless --path game --script res://tests/run_level4_seg1_probe.gd
##
## Each part is driven the way a player drives it -- the movement keys held, E pressed -- and read
## back off what the level and the things in it say happened.

const GROUND_Y := 600.0
## A frame or two over the time anything here is measured against: a press lands mid-frame.
const MARGIN := 0.15

var failures := 0
var level: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(240.0).timeout.connect(func() -> void:
		print("OBRA_L4_SEG1_FAILED=watchdog")
		quit(2))
	level = await _open_level()
	await _walking_past_the_santelmo_is_safe()
	_its_flame_teaches_walking()
	await _running_brings_it_and_it_burns()
	await _it_forms_again_at_home()
	await _walking_away_it_loses_interest()
	await _a_knockout_puts_the_woods_back()
	_release_all()
	level.queue_free()
	await _frames(3)
	if failures == 0:
		print("OBRA_L4_SEG1_OK")
		quit(0)
	else:
		print("OBRA_L4_SEG1_FAILED=%d" % failures)
		quit(1)


# --- The santelmo ------------------------------------------------------------------------

## A flame of the probe's own, so each check starts from a known place, at her middle's height.
func _flame_at(x: float) -> Santelmo2D:
	var flame := Santelmo2D.new()
	flame.position = Vector2(x, GROUND_Y - 70.0)
	(level.get("entity_root") as Node2D).add_child(flame)
	return flame


func _walking_past_the_santelmo_is_safe() -> void:
	var flame := _flame_at(1500.0)
	await _put_her_at(1000.0)
	var wanted := false
	Input.action_press(&"walk")
	Input.action_press(&"move_right")
	for _frame in range(60 * 9):
		await physics_frame
		wanted = wanted or flame.is_chasing()
	_release_all()
	var past := _her_x() > 1600.0
	_check(past and not wanted and _stage() == PlayerHealth.FULL,
		"walking past the santelmo, it never wants her", "at %.0f, chased %s, stage %d"
			% [_her_x(), wanted, _stage()])
	flame.queue_free()
	await _frames(2)


## Within its sight is where walking is taught: the card with the walk key on it.
func _its_flame_teaches_walking() -> void:
	var tutorial := level.get("tutorial") as Node
	var told := bool(tutorial.call("has_taught", "walk_past")) or bool(tutorial.call("is_coming", "walk_past"))
	_check(told, "near a santelmo, the walk is taught", "walk_past %s" % ("shown" if told else "never offered"))


func _running_brings_it_and_it_burns() -> void:
	var flame := _flame_at(1500.0)
	await _put_her_at(900.0)
	_health().reset_full()
	await _seconds(2.2)
	var lit_before := not flame.light_hole().is_empty()
	var touched := [false]
	flame.touched_her.connect(func() -> void: touched[0] = true)
	var chased := false
	Input.action_press(&"move_right")
	for _frame in range(60 * 4):
		await physics_frame
		chased = chased or flame.is_chasing()
		if touched[0]:
			break
	_release_all()
	_check(chased and touched[0] and _stage() == PlayerHealth.DIM,
		"running, it comes for her and burns a stage", "chased %s, touched %s, stage %d"
			% [chased, touched[0], _stage()])
	_check(lit_before and flame.is_out() and flame.light_hole().is_empty() and not flame.visible,
		"it is a light, and goes out when it touches her", "lit %s, out %s" % [lit_before, flame.is_out()])
	set_meta(&"flame", flame)


func _it_forms_again_at_home() -> void:
	var flame := get_meta(&"flame") as Santelmo2D
	await _seconds(Santelmo2D.REFORM_SECONDS - 0.6)
	var still_out := flame.is_out()
	await _seconds(0.6 + MARGIN * 2.0)
	_check(still_out and not flame.is_out() and flame.visible
			and flame.global_position.distance_to(flame.home()) < 1.0,
		"it forms again at home after %.0f s" % Santelmo2D.REFORM_SECONDS,
		"out at %.1f s %s, then at home %s" % [Santelmo2D.REFORM_SECONDS - 0.6, still_out,
			flame.global_position.distance_to(flame.home()) < 1.0])
	flame.queue_free()
	await _frames(2)


func _walking_away_it_loses_interest() -> void:
	# Behind her, so running away is what it sees.
	var flame := _flame_at(1300.0)
	await _put_her_at(1700.0)
	_health().reset_full()
	await _seconds(2.2)
	Input.action_press(&"move_right")
	await _seconds(0.6)
	var wanted := flame.is_chasing()
	Input.action_press(&"walk")
	# The design's rule, not the script's constant: interest gone within about three seconds.
	await _seconds(3.2)
	var gave_up := not flame.is_chasing()
	var from_home := flame.global_position.distance_to(flame.home())
	await _seconds(1.0)
	var heading_home := flame.global_position.distance_to(flame.home()) < from_home
	_release_all()
	_check(wanted and gave_up and heading_home and _stage() == PlayerHealth.FULL,
		"walking away, it loses interest and goes home",
		"wanted %s, gave up %s, homing %s, stage %d" % [wanted, gave_up, heading_home, _stage()])
	flame.queue_free()
	await _frames(2)


## Whatever was after her goes back to before, with her: the flame home, wanting nothing.
func _a_knockout_puts_the_woods_back() -> void:
	var flame := _flame_at(1500.0)
	await _put_her_at(900.0)
	_health().reset_full()
	await _seconds(0.3)
	Input.action_press(&"move_right")
	await _seconds(0.5)
	_release_all()
	var away := flame.global_position.distance_to(flame.home()) > 40.0 and flame.is_chasing()
	level.call("_knockout")
	await _frames(4)
	_check(away and not flame.is_chasing() and flame.global_position.distance_to(flame.home()) < 1.0,
		"a knockout puts the woods back: the flame home, wanting nothing",
		"was away and chasing %s; now %.0f px from home" % [away, flame.global_position.distance_to(flame.home())])
	flame.queue_free()
	await _frames(2)


# --- Helpers -----------------------------------------------------------------------------

func _open_level() -> Node:
	var scene := (load("res://level_4.tscn") as PackedScene).instantiate()
	(scene.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(scene)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(30)
	return scene


## Puts her down on the ground at x, still, with nothing said over it.
func _put_her_at(x: float) -> void:
	_release_all()
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": Vector2(x, GROUND_Y - 4.0), "linear_velocity": Vector2.ZERO})
	await _frames(6)


func _her_x() -> float:
	return (level.get("player") as Node2D).global_position.x


func _health() -> PlayerHealth:
	return level.get("player_health") as PlayerHealth


func _stage() -> int:
	return _health().stage


func _release_all() -> void:
	for action in [&"move_left", &"move_right", &"walk", &"jump", &"interact"]:
		Input.action_release(action)


## Frames with every line put away as it comes, so the level never sits paused on one.
func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		if paused:
			call_group(DialogueBox.GROUP, &"hide_line")
			paused = false


func _seconds(seconds: float) -> void:
	await _frames(int(ceil(seconds * 60.0)))


func _check(ok: bool, what: String, detail: String) -> void:
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
