extends SceneTree
## The things that fight back: that they chase sensibly, warn before they strike, take the blows
## the weapon table says, and never pass through what the world says is solid.
##
##   godot --headless --path game --script res://tests/run_enemy_probe.gd
##
## Everything here is driven the way a fight drives it: a real wanderer, the level's own hurtbox
## and lantern, and weapons used through describe_use -- never apply_tool_hit called by hand,
## which is how the bakunawa probe once hid four weapon faults.

const FLOOR_Y := 400.0

var failures := 0
var world: Node2D
var apo: Wanderer
var health: PlayerHealth
var hurtbox: PlayerHurtbox2D
var registry: EntityRegistry


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node(^"LevelManager").set(&"current_level_id", "level_4")
	await _a_dog_hops_a_step_to_reach_her()
	await _a_dog_stops_at_a_drop_it_cannot_take()
	await _a_strike_is_warned_and_lands_once()
	await _four_dilim_sword_swings_bring_a_dog_down()
	await _an_axe_throws_it_further_than_a_sword()
	await _she_runs_through_it_and_it_never_stands_on_her()
	await _a_far_one_sleeps_and_a_restore_puts_one_back()
	root.get_node(^"LevelManager").set(&"current_level_id", "")
	if failures == 0:
		print("OBRA_ENEMIES_OK")
		quit(0)
	else:
		print("OBRA_ENEMIES_FAILED=%d" % failures)
		quit(1)


func _a_dog_hops_a_step_to_reach_her() -> void:
	await _fresh_world()
	# A 40 px step from x 560 on, and she stands on it.
	_block(Vector2(1000.0, FLOOR_Y - 20.0), Vector2(880.0, 40.0))
	await _place_apo(Vector2(900.0, FLOOR_Y - 40.0))
	var dog := _enemy(GroundEnemy2D, "aswang_dog", Vector2(300.0, FLOOR_Y - 14.0))
	var stood_on_it := false
	for _frame in range(180):
		await physics_frame
		var bottom := dog.global_position.y + dog.body_size.y * 0.5
		stood_on_it = stood_on_it or (dog.is_on_floor() and dog.global_position.x > 600.0
			and absf(bottom - (FLOOR_Y - 40.0)) < 4.0)
	_check(stood_on_it, "a dog hops a 40 px step to reach her", "at x %.0f" % dog.global_position.x)


func _a_dog_stops_at_a_drop_it_cannot_take() -> void:
	await _fresh_world()
	# Two shelves 200 px up with a gap between them; she is on the far one, level with it.
	_block(Vector2(300.0, FLOOR_Y - 220.0), Vector2(400.0, 40.0))
	_block(Vector2(1000.0, FLOOR_Y - 220.0), Vector2(400.0, 40.0))
	await _place_apo(Vector2(950.0, FLOOR_Y - 240.0))
	# Inside its sight, so it does set off after her; the gap is what stops it.
	var dog := _enemy(GroundEnemy2D, "aswang_dog", Vector2(380.0, FLOOR_Y - 254.0))
	var chased := false
	for _frame in range(180):
		await physics_frame
		chased = chased or dog.state_name() == "CHASE"
	_check(chased and dog.global_position.y < FLOOR_Y - 200.0
			and dog.global_position.x > 420.0 and dog.global_position.x <= 500.0 + dog.body_size.x,
		"a dog runs to the edge after her, and will not drop 240 px across the gap",
		"chased %s, at (%.0f, %.0f)" % [chased, dog.global_position.x, dog.global_position.y])


func _a_strike_is_warned_and_lands_once() -> void:
	await _fresh_world()
	await _place_apo(Vector2(600.0, FLOOR_Y))
	health.invulnerable_seconds = 0.0
	var dog := _enemy(GroundEnemy2D, "aswang_dog", Vector2(520.0, FLOOR_Y - 14.0))
	var windup_at := -1.0
	var glint := false
	var hit_at := -1.0
	var hits := [0]
	health.hit_taken.connect(func(_stage: int) -> void: hits[0] += 1)
	var attacks := 0
	var was := ""
	for frame in range(150):
		await physics_frame
		var now := float(frame) / 60.0
		var name := dog.state_name()
		if name == "WINDUP" and was != "WINDUP" and windup_at < 0.0:
			windup_at = now
		if name == "WINDUP":
			glint = glint or dog.telegraph.visible
		if name == "ATTACK" and was != "ATTACK":
			attacks += 1
			if attacks > 1:
				break
		if hits[0] > 0 and hit_at < 0.0:
			hit_at = now
		was = name
	_check(windup_at >= 0.0 and hit_at - windup_at >= 0.4 and glint,
		"a strike comes 0.4 s or more after a windup she can see", "%.2f s after the glint" % (hit_at - windup_at))
	_check(hits[0] == 1, "and one strike lands once", "%d blow(s) from one strike" % hits[0])


func _four_dilim_sword_swings_bring_a_dog_down() -> void:
	await _fresh_world()
	await _place_apo(Vector2(600.0, FLOOR_Y))
	var sword := await _in_hand("sword")
	var dog := _enemy(GroundEnemy2D, "aswang_dog", Vector2(660.0, FLOOR_Y - 14.0))
	var alive_after: Array[bool] = []
	for _swing in range(4):
		# In front of her and still, so every swing is a fair one.
		dog.global_position = apo.global_position + Vector2(55.0, -14.0)
		dog.velocity = Vector2.ZERO
		await _frames(2)
		sword.describe_use(apo)
		await _frames(2)
		alive_after.append(not dog.is_dead())
		await _seconds(0.4)
	_check(alive_after == [true, true, true, false],
		"a dog takes exactly four Dilim sword swings (damage 1 against 4)", "alive after each: %s" % [alive_after])
	_check(dog.is_dead() and dog.hurtbox.collision_layer == 0,
		"and down, nothing can strike it again", "hurtbox layer %d" % dog.hurtbox.collision_layer)


func _an_axe_throws_it_further_than_a_sword() -> void:
	var shoves: Array[float] = []
	for weapon in ["sword", "axe"]:
		await _fresh_world()
		await _place_apo(Vector2(600.0, FLOOR_Y))
		var held := await _in_hand(weapon)
		var pig := _enemy(GroundEnemy2D, "aswang_pig", Vector2(655.0, FLOOR_Y - 17.0))
		await _frames(2)
		pig.global_position = apo.global_position + Vector2(55.0, -17.0)
		pig.velocity = Vector2.ZERO
		await _frames(1)
		held.describe_use(apo)
		shoves.append(pig.velocity.x)
		await _frames(2)
	_check(shoves.size() == 2 and shoves[1] > shoves[0] and shoves[0] > 0.0,
		"an axe (damage 2) throws it further than a sword (damage 1)",
		"%.0f vs %.0f px/s" % [shoves[0], shoves[1]] if shoves.size() == 2 else "-")


func _she_runs_through_it_and_it_never_stands_on_her() -> void:
	await _fresh_world()
	await _place_apo(Vector2(400.0, FLOOR_Y))
	var pig := _enemy(GroundEnemy2D, "aswang_pig", Vector2(560.0, FLOOR_Y - 17.0))
	pig.sight = 0.0
	await _frames(10)
	Input.action_press(&"move_right")
	await _seconds(1.2)
	Input.action_release(&"move_right")
	_check(apo.global_position.x > 640.0, "she runs straight through it: only a strike hurts",
		"from 400 to %.0f past a pig at 560" % apo.global_position.x)
	# And one falling on her goes through to the ground rather than landing on her head.
	var dog := _enemy(GroundEnemy2D, "aswang_dog", apo.global_position + Vector2(0.0, -160.0))
	dog.sight = 0.0
	await _frames(60)
	var bottom := dog.global_position.y + dog.body_size.y * 0.5
	_check(absf(bottom - FLOOR_Y) < 4.0, "and one dropping onto her lands on the ground, not on her",
		"its feet at %.0f, the ground at %.0f" % [bottom, FLOOR_Y])


func _a_far_one_sleeps_and_a_restore_puts_one_back() -> void:
	await _fresh_world()
	await _place_apo(Vector2(200.0, FLOOR_Y))
	var far := _enemy(GroundEnemy2D, "aswang_dog", Vector2(1800.0, FLOOR_Y - 14.0))
	# It could see her from there; only sleeping keeps it still.
	far.sight = 5000.0
	await _seconds(1.0)
	_check(far.state_name() == "IDLE" and absf(far.global_position.x - 1800.0) < 1.0,
		"one 1600 px away sleeps: it does not move", "%s at x %.0f" % [far.state_name(), far.global_position.x])
	var home := far.global_position
	far.global_position = Vector2(700.0, FLOOR_Y - 14.0)
	far.apply_tool_hit("anvil", 0.0, apo)
	far.apply_tool_hit("anvil", 0.0, apo)
	await _frames(4)
	var was_dead := far.is_dead()
	far.reset_for_restore()
	await _frames(4)
	_check(was_dead and not far.is_dead() and far.hp == far.max_hp and far.visible
			and far.global_position.distance_to(home) < 1.0
			and far.hurtbox.collision_layer & PhysicsLayers.WORLD != 0,
		"a restore puts a dead one back where it started, whole and hittable",
		"hp %d at %s" % [far.hp, far.global_position.round()])


# --- fixture ---------------------------------------------------------------------------

func _fresh_world() -> void:
	Input.action_release(&"move_right")
	if world != null and is_instance_valid(world):
		world.queue_free()
		await _frames(3)
	world = Node2D.new()
	root.add_child(world)
	_block(Vector2(600.0, FLOOR_Y + 20.0), Vector2(6000.0, 40.0))
	registry = EntityRegistry.new()
	world.add_child(registry)
	registry.load_manifest()
	health = PlayerHealth.new()
	world.add_child(health)
	hurtbox = PlayerHurtbox2D.new()
	hurtbox.health = health
	world.add_child(hurtbox)


func _place_apo(at: Vector2) -> void:
	apo = (load("res://creatures/wanderer.tscn") as PackedScene).instantiate() as Wanderer
	apo.set_world_bounds(Rect2(-2000.0, -2000.0, 8000.0, 6000.0))
	world.add_child(apo)
	apo.global_position = at
	hurtbox.player = apo
	await _frames(20)


func _enemy(script: Variant, enemy_kind: String, at: Vector2) -> Enemy2D:
	var enemy: Enemy2D = (script as GDScript).new()
	enemy.kind = enemy_kind
	world.add_child(enemy)
	enemy.global_position = at
	enemy.reset_home()
	return enemy


func _in_hand(entity_id: String) -> UtilityObject:
	var tool := registry.instantiate_entity(entity_id) as UtilityObject
	world.add_child(tool)
	var entry := registry.get_entity(entity_id)
	var strokes := [{"points": PackedVector2Array([Vector2(130, 256), Vector2(382, 256)]),
		"width": 8.0, "color": Color.BLACK}]
	var page := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	page.fill(Color.WHITE)
	tool.apply_item_data(DrawnItemData.from_prediction(
		entity_id, entity_id.capitalize(), page, strokes, 0.9, entry))
	tool.global_position = apo.global_position + Vector2(30.0, -40.0)
	await physics_frame
	tool.interact(apo)
	await _frames(3)
	return tool


func _block(at: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)
	body.global_position = at


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func _seconds(seconds: float) -> void:
	await create_timer(seconds, false, true).timeout


func _check(ok: bool, what: String, detail: String) -> void:
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
