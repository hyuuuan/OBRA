extends SceneTree
## Actual input through each remembered place, all ordinary targets and the optional footholds.
const Fixture = preload("res://tests/level5_journey_fixture.gd")
var level: Node
var player: Node2D
var failures := 0
var checked := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	level = load("res://level_5.tscn").instantiate()
	level.get_node("BackendSupervisor").auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP,"set_auto_dismiss",true)
	await create_timer(.3).timeout
	level.call("_on_backend_ready")
	level.set("_corridor_seen",true)
	level.set("_lolo_moment","probe")
	player = level.get("player")
	var journey: Node = level.get("_journey")
	for index in range(12):
		var spec: Dictionary = journey.places[index]
		Fixture.prepare(level,Vector2(float(spec.start)+170,140))
		for frame in range(12): await physics_frame
		var seen: Array[String] = []
		Input.action_press("move_right")
		for frame in range(400):
			if frame%48==0: Input.action_press("jump")
			if frame%48==26: Input.action_release("jump")
			await physics_frame
			var target: MemoryFragment2D = level.call("_fragment_here")
			if target != null and target.fragment_id not in seen: seen.append(target.fragment_id)
			if player.global_position.x >= float(spec.start)+1100: break
		Input.action_release("move_right")
		Input.action_release("jump")
		var expected: Array[String] = []
		for fragment: MemoryFragment2D in journey.fragments:
			if fragment.vignette_id == String(spec.id) and fragment.fragment_id != "flower": expected.append(fragment.fragment_id)
		var reachable := true
		for id in expected: reachable = reachable and id in seen
		_check(reachable and player.global_position.x >= float(spec.start)+1100,
			"%s crosses with normal movement and reaches its targets: %s" % [spec.id,seen])
		_check(level.call("_world_camera").room_bounds == Rect2(),"%s keeps the continuous camera" % spec.id)
	Fixture.prepare(level,Vector2(20930,140))
	for frame in range(16): await physics_frame
	var flower: MemoryFragment2D = level.call("_fragment","flower")
	_check(level.call("_fragment_here") != flower,"the flower is outside reach from the main path")
	Fixture.prepare(level,Vector2(20180,140))
	for frame in range(12): await physics_frame
	Input.action_press("move_right")
	var reached := false
	for frame in range(450):
		if frame%48==20: Input.action_press("jump")
		if frame%48==46: Input.action_release("jump")
		await physics_frame
		if player.is_on_floor() and level.call("_fragment_here") == flower:
			reached=true
			break
	Input.action_release("move_right")
	Input.action_release("jump")
	_check(reached and is_equal_approx(level.get("ink_manager").remaining(),6),"the flower detour is physically reachable without drawing")
	level.queue_free()
	for frame in range(5): await process_frame
	print("OBRA_LEVEL5_MEMORY_WALK_%s (%d checks)" % ["OK" if failures==0 else "FAILED",checked])
	quit(0 if failures==0 else 1)

func _check(ok: bool, what: String) -> void:
	checked+=1
	failures+=int(not ok)
	print("  %s\t%s" % ["OK" if ok else "FAIL",what])
