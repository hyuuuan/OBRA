extends SceneTree
## The apo can be hurt: the lantern as health, its grace, and what a fight does to her.
##
##   godot --headless --path game --script res://tests/run_combat_probe.gd

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _the_lantern_counts_down()
	await _the_grace_is_physics_time()
	await _guttering_puts_it_out()
	await _a_blow_beats_her_steering()
	await _the_hurtbox_follows_and_passes_blows_on()
	await _a_level_that_fights()

	if failures == 0:
		print("OBRA_COMBAT_OK")
		quit(0)
	else:
		print("OBRA_COMBAT_FAILED=%d" % failures)
		quit(1)


func _the_lantern_counts_down() -> void:
	var health := _health()
	var body := Node2D.new()
	root.add_child(body)
	health.set_flicker_target(body)
	var heard: Array[int] = []
	health.stage_changed.connect(func(stage: int) -> void: heard.append(stage))
	_check(health.take_hit() and health.stage == PlayerHealth.DIM and heard == [3],
		"a hit takes the flame down one stage", "stage %d, heard %s" % [health.stage, heard])
	_check(not health.take_hit() and health.stage == PlayerHealth.DIM,
		"a second hit inside the grace does not land", "stage %d" % health.stage)
	var faintest := 1.0
	for _frame in range(30):
		await physics_frame
		faintest = minf(faintest, body.modulate.a)
	_check(faintest < 1.0, "and she blinks during it", "faintest alpha %.2f" % faintest)
	await _seconds(0.6)
	_check(not health.is_invulnerable() and is_equal_approx(body.modulate.a, 1.0),
		"the grace ends and she is solid again", "alpha %.2f" % body.modulate.a)
	_check(health.take_hit() and health.stage == PlayerHealth.LOW,
		"after it, the next hit lands", "stage %d" % health.stage)
	health.refill(5)
	_check(health.stage == PlayerHealth.FULL, "oil fills it, never past full",
		"stage %d" % health.stage)
	body.queue_free()
	health.queue_free()
	await physics_frame


## A line of dialogue pauses the tree: the grace waits for it.
func _the_grace_is_physics_time() -> void:
	var health := _health()
	health.take_hit()
	paused = true
	await create_timer(1.3, true).timeout
	var held := health.is_invulnerable()
	paused = false
	_check(held, "the grace does not run out behind a paused line", "still graced after 1.3 s")
	health.queue_free()
	await physics_frame


func _guttering_puts_it_out() -> void:
	var health := _health()
	health.invulnerable_seconds = 0.0
	var out := [0]
	health.snuffed.connect(func() -> void: out[0] += 1)
	for _hit in range(3):
		health.take_hit()
	_check(health.stage == PlayerHealth.GUTTERING and out[0] == 0,
		"three hits leave it guttering, still lit", "stage %d" % health.stage)
	health.take_hit()
	_check(out[0] == 1 and health.stage == PlayerHealth.GUTTERING,
		"a hit while guttering puts it out", "snuffed %d time(s)" % out[0])
	health.reset_full()
	_check(health.stage == PlayerHealth.FULL and health.is_invulnerable()
			and not health.take_hit(),
		"back from it, full and graced", "stage %d" % health.stage)
	health.queue_free()
	await physics_frame


## Knocked back while running the other way: the blow decides, and then she does again.
func _a_blow_beats_her_steering() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var ground := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(4000.0, 40.0)
	shape.shape = box
	ground.add_child(shape)
	world.add_child(ground)
	ground.position = Vector2(600.0, 420.0)
	var apo := (load("res://creatures/wanderer.tscn") as PackedScene).instantiate() as Wanderer
	apo.set_world_bounds(Rect2(-1000.0, -1000.0, 4000.0, 3000.0))
	world.add_child(apo)
	apo.global_position = Vector2(600.0, 400.0)
	await _frames(20)
	Input.action_press(&"move_right")
	await _frames(10)
	var from := apo.global_position.x
	apo.knock_back(Vector2(-300.0, -220.0))
	_check(apo.is_staggered(), "a blow takes the controls", "staggered")
	await _frames(2)
	var facing := float(apo.get(&"_facing"))
	apo.face_toward(apo.global_position.x - 200.0)
	_check(float(apo.get(&"_facing")) == facing,
		"a swing cannot turn her mid-blow", "facing %+.0f" % facing)
	var furthest := from
	for _frame in range(24):
		await physics_frame
		furthest = minf(furthest, apo.global_position.x)
	# Friction against the held key, which is what a one-frame shove met, gave about 25.
	_check(from - furthest >= 50.0, "it carries her back though she runs the other way",
		"%.0f px back" % (from - furthest))
	_check(not apo.is_staggered(), "and the controls come back", "after 0.43 s")
	var turned := apo.global_position.x
	await _frames(30)
	_check(apo.global_position.x > turned + 40.0, "she runs on the way she was going",
		"%.0f px forward" % (apo.global_position.x - turned))
	# Shift where the level has not allowed it changes nothing; where it has, she walks.
	Input.action_press(&"walk")
	await _frames(20)
	var running := absf(apo.velocity.x)
	apo.can_walk = true
	await _frames(20)
	var walking := absf(apo.velocity.x)
	apo.can_walk = false
	Input.action_release(&"walk")
	_check(is_equal_approx(running, Wanderer.SPEED) and is_equal_approx(walking, Wanderer.WALK_SPEED),
		"Shift walks her only where a level allows it", "%.0f px/s, then %.0f" % [running, walking])
	Input.action_release(&"move_right")
	await _frames(20)
	apo.knock_back(Vector2(300.0, -220.0))
	_check(float(apo.get(&"_facing")) < 0.0, "hit from behind, she turns to face it",
		"facing %+.0f" % float(apo.get(&"_facing")))
	await _frames(40)
	apo.face_toward(apo.global_position.x + 200.0)
	_check(float(apo.get(&"_facing")) > 0.0, "out of it, a swing aimed the other way turns her",
		"facing %+.0f" % float(apo.get(&"_facing")))
	world.queue_free()
	await physics_frame


## The level's hurtbox: on her middle, found by an enemy's hitbox and by nothing a weapon asks.
func _the_hurtbox_follows_and_passes_blows_on() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var ground := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(4000.0, 40.0)
	shape.shape = box
	ground.add_child(shape)
	world.add_child(ground)
	ground.position = Vector2(600.0, 420.0)
	var apo := (load("res://creatures/wanderer.tscn") as PackedScene).instantiate() as Wanderer
	apo.set_world_bounds(Rect2(-1000.0, -1000.0, 4000.0, 3000.0))
	world.add_child(apo)
	apo.global_position = Vector2(600.0, 400.0)
	var health := _health()
	health.invulnerable_seconds = 0.5
	var hurtbox := PlayerHurtbox2D.new()
	world.add_child(hurtbox)
	hurtbox.health = health
	hurtbox.player = apo
	var claws := _probe_area(PhysicsLayers.PLAYER_HURTBOX)
	var blade := _probe_area(PhysicsLayers.WORLD)
	world.add_child(claws)
	world.add_child(blade)
	await _frames(20)
	claws.global_position = hurtbox.global_position
	blade.global_position = hurtbox.global_position
	await _frames(3)
	var middle := apo.global_position.y - hurtbox.global_position.y
	_check(absf(middle - PlayerHurtbox2D.FEET_TO_MIDDLE) < 1.0, "the hurtbox rides on her middle",
		"%.0f px above her feet" % middle)
	_check(claws.get_overlapping_areas().has(hurtbox), "an enemy's hitbox finds it",
		"on PLAYER_HURTBOX")
	_check(not blade.get_overlapping_areas().has(hurtbox),
		"and nothing that asks the world layer does, so no weapon strikes her",
		"%d found" % blade.get_overlapping_areas().size())
	_check(hurtbox.receive_hit(apo.global_position + Vector2(80.0, -40.0))
			and health.stage == PlayerHealth.DIM and apo.velocity.x < -100.0,
		"a blow from the right dims the lantern and knocks her left",
		"stage %d, %.0f px/s" % [health.stage, apo.velocity.x])
	_check(not hurtbox.receive_hit(apo.global_position + Vector2(80.0, -40.0)),
		"and the next, inside the grace, does nothing", "stage %d" % health.stage)
	await _frames(60)
	health.invulnerable_seconds = 0.0
	hurtbox.receive_hit(apo.global_position)
	hurtbox.receive_hit(apo.global_position)
	await _frames(30)
	var out := [0]
	health.snuffed.connect(func() -> void: out[0] += 1)
	var resting := apo.velocity
	_check(hurtbox.receive_hit(apo.global_position + Vector2(-80.0, -40.0)) and out[0] == 1
			and apo.velocity == resting and not apo.is_staggered(),
		"the blow that puts the lantern out does not also throw her",
		"snuffed %d, velocity %s" % [out[0], apo.velocity])
	world.queue_free()
	health.queue_free()
	await physics_frame


## Payyo as it is builds nothing; the same level told it fights arms the lantern, points the
## hurtbox at her, and when the light goes out puts her back with a full flame.
func _a_level_that_fights() -> void:
	var plain := await _open_level(null)
	_check(plain.get("player_health") == null and plain.get("player_hurtbox") == null,
		"a level that does not fight builds no lantern and no hurtbox",
		"Payyo as it is")
	plain.queue_free()
	await _frames(3)
	var fights := GDScript.new()
	fights.source_code = "extends \"res://scripts/game_level.gd\"\n" \
		+ "func _has_player_health() -> bool:\n\treturn true\n"
	fights.reload()
	var level := await _open_level(fights)
	var health := level.get("player_health") as PlayerHealth
	var hurtbox := level.get("player_hurtbox") as PlayerHurtbox2D
	var apo := level.get("player") as Node2D
	_check(health != null and hurtbox != null and hurtbox.player == apo,
		"told it fights, the level arms the lantern and points the hurtbox at her",
		"armed")
	if health == null or hurtbox == null or apo == null:
		level.queue_free()
		await _frames(3)
		return
	var spawn := (level.get("spawn_point") as Node2D).global_position
	apo.call("apply_morph_state", {"position": spawn + Vector2(500.0, -10.0),
		"linear_velocity": Vector2.ZERO})
	await _frames(10)
	health.invulnerable_seconds = 0.0
	for _blow in range(PlayerHealth.FULL):
		hurtbox.receive_hit(hurtbox.global_position + Vector2(60.0, 0.0))
	await _frames(4)
	var now := level.get("player") as Node2D
	_check(health.stage == PlayerHealth.FULL and health.is_invulnerable()
			and absf(now.global_position.x - spawn.x) < 150.0,
		"when the light goes out she is back, full and graced",
		"stage %d, %.0f px from the start" % [health.stage, absf(now.global_position.x - spawn.x)])
	level.queue_free()
	await _frames(3)


func _open_level(script: GDScript) -> Node:
	var level := (load("res://game_level.tscn") as PackedScene).instantiate()
	if script != null:
		level.set_script(script)
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(40):
		await physics_frame
	call_group(DialogueBox.GROUP, &"hide_line")
	paused = false
	await _frames(4)
	return level


func _probe_area(mask: int) -> Area2D:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = mask
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	area.add_child(shape)
	return area


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func _health() -> PlayerHealth:
	var health := PlayerHealth.new()
	root.add_child(health)
	return health


func _seconds(seconds: float) -> void:
	await create_timer(seconds, false, true).timeout


func _check(ok: bool, what: String, detail: String) -> void:
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
