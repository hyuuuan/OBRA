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
	await _the_camera_can_keep_step()
	await _weapons_wear_where_a_level_says()
	await _a_redrawn_tool_costs_where_a_level_says()

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
	var figure := apo.get_node("Figure") as Node2D
	var body := figure.get_node("Body") as Sprite2D
	_check(figure.get("pose") == &"hurt" and body.rotation < -0.1,
		"and she is drawn taking it, leaning back", "%s at %.2f rad" % [figure.get("pose"), body.rotation])
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
	_check(not apo.is_staggered() and figure.get("pose") != &"hurt" and absf(body.rotation) < 0.01,
		"and the controls come back, and she stands up", "after 0.43 s, %s" % figure.get("pose"))
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
	_check(plain.get("player_health") == null and plain.get("player_hurtbox") == null
			and not (plain.call("_world_camera") as WorldCameraController).follow_on_physics,
		"a level that does not fight builds no lantern and no hurtbox, and its camera is as it was",
		"Payyo as it is")
	plain.queue_free()
	await _frames(3)
	var fights := GDScript.new()
	fights.source_code = "extends \"res://scripts/game_level.gd\"\n" \
		+ "func _has_player_health() -> bool:\n\treturn true\n" \
		+ "func _camera_follows_physics() -> bool:\n\treturn true\n"
	fights.reload()
	var level := await _open_level(fights)
	var health := level.get("player_health") as PlayerHealth
	var hurtbox := level.get("player_hurtbox") as PlayerHurtbox2D
	var apo := level.get("player") as Node2D
	_check(health != null and hurtbox != null and hurtbox.player == apo
			and (level.call("_world_camera") as WorldCameraController).follow_on_physics,
		"told it fights, the level arms the lantern, points the hurtbox at her, steps its camera",
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


## Opted in, the camera moves on physics ticks only; left alone, on render frames as before.
func _the_camera_can_keep_step() -> void:
	var camera := WorldCameraController.new()
	camera.world_bounds = Rect2(-5000.0, -5000.0, 10000.0, 10000.0)
	root.add_child(camera)
	var target := Node2D.new()
	root.add_child(target)
	camera.set_target(target)
	camera.set_process(false)
	camera.set_physics_process(false)
	var moved := func(step: Callable) -> bool:
		target.global_position += Vector2(300.0, 0.0)
		var before := camera.global_position
		step.call(1.0 / 60.0)
		return not camera.global_position.is_equal_approx(before)
	var idle_default: bool = moved.call(camera._process)
	var physics_default: bool = moved.call(camera._physics_process)
	camera.follow_on_physics = true
	var idle_opted: bool = moved.call(camera._process)
	var physics_opted: bool = moved.call(camera._physics_process)
	_check(idle_default and not physics_default and not idle_opted and physics_opted,
		"the camera follows on render frames, or on physics ticks once a level asks",
		"default %s/%s, opted %s/%s" % [idle_default, physics_default, idle_opted, physics_opted])
	camera.queue_free()
	target.queue_free()
	await physics_frame


## Dilim's sword is good for fourteen swings; Payyo's, as it is, never wears.
func _weapons_wear_where_a_level_says() -> void:
	# Dilim's rows in both runs, so the level's hook is the only thing deciding.
	root.get_node(^"LevelManager").set(&"current_level_id", "level_4")
	var plain := await _open_level(null)
	var kept := await _swing_a_drawn_sword(plain, 16, SWING_GAP)
	_check(kept["held"] and not kept["bar"], "where a level does not wear weapons, a sword never wears",
		"16 swings, still in hand")
	root.get_node(^"LevelManager").set(&"current_level_id", "")
	plain.queue_free()
	await _frames(3)
	var wears := GDScript.new()
	wears.source_code = "extends \"res://scripts/game_level.gd\"\n" \
		+ "func _tool_wear_enabled() -> bool:\n\treturn true\n"
	wears.reload()
	var level := await _open_level(wears)
	# Dilim's rows: the level's own configs are loaded, so only the table reads this.
	root.get_node(^"LevelManager").set(&"current_level_id", "level_4")
	var uses := WeaponTable.uses("sword")
	var nearly := await _swing_a_drawn_sword(level, uses - 1, SWING_GAP, true)
	_check(nearly["drawn_full"] and nearly["held"] and nearly["left"] == 1 and nearly["bar"],
		"a drawn sword arrives full, and %d swings leave it one" % (uses - 1),
		"%d left, bar %s" % [nearly["left"], nearly["bar"]])
	var last := await _swing_a_drawn_sword(level, 1, SWING_GAP, false)
	_check(not last["held"] and int(level.call("_slot_holding", "sword")) < 0,
		"and the last swing wears it out", "gone from hand and bag")
	root.get_node(^"LevelManager").set(&"current_level_id", "")
	level.queue_free()
	await _frames(3)


## Wider than Dilim's 300 ms sword swing by a loaded frame or two: the press lands mid-frame,
## after the frame's own clock, and 0.31 s was refused now and then with other suites running.
const SWING_GAP := 0.40


## A second sword is free in Payyo (FR-7: paid once, kept); where every drawing costs, it is not.
func _a_redrawn_tool_costs_where_a_level_says() -> void:
	var spent: Array[float] = []
	for script in [null, _level_saying("_every_drawing_costs_ink")]:
		var level := await _open_level(script)
		var ink := level.get("ink_manager") as InkManager
		await _swing_a_drawn_sword(level, 0, SWING_GAP)
		var before := ink.remaining()
		await _swing_a_drawn_sword(level, 0, SWING_GAP)
		spent.append(before - ink.remaining())
		level.queue_free()
		await _frames(3)
	_check(spent == [0.0, 1.0], "a sword drawn again is free, or a unit where every drawing costs",
		"second sword cost %s" % [spent])


## Payyo, told one hook says yes.
func _level_saying(hook: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = "extends \"res://scripts/game_level.gd\"\nfunc %s(_a = null) -> bool:\n\treturn true\n" % hook
	script.reload()
	return script


## Draw a sword (unless one is in hand already) and swing it `swings` times, `gap` seconds apart,
## with an extra press inside each swing that must cost nothing.
func _swing_a_drawn_sword(level: Node, swings: int, gap: float, draw: bool = true) -> Dictionary:
	var report := {"drawn_full": false}
	if draw:
		var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		sheet.fill(Color.WHITE)
		level.call("_on_drawing_ready", "sword", "Sword", sheet, {"confidence": 0.9},
			[{"points": PackedVector2Array([Vector2(0, 0), Vector2(0, 80)]), "width": 6.0,
				"color": Color.BLACK}], 1.0)
		await _frames(4)
		var slot := int(level.call("_slot_holding", "sword"))
		var items: Array = (level.get("inventory_manager") as InventoryManager).items()
		report["drawn_full"] = slot >= 0 and InventoryHUD.wear_of(items[slot]) == 1.0
		if slot >= 0 and level.get("_equipped_utility") == null:
			level.call("_on_inventory_slot_pressed", slot)
			await _frames(4)
	for _swing in range(swings):
		level.call("_use_equipped_utility")
		level.call("_use_equipped_utility")
		await create_timer(gap).timeout
	var held := level.get("_equipped_utility") as UtilityObject
	report["held"] = held != null and is_instance_valid(held)
	report["left"] = int(held.item_data.runtime_state.get("uses_left", -1)) if report["held"] else -1
	var bar := false
	var hud := level.get("inventory_hud") as InventoryHUD
	for wear in hud.find_children("Wear", "Panel", true, false):
		bar = bar or (wear as Panel).visible
	report["bar"] = bar
	return report


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
