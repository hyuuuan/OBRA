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
