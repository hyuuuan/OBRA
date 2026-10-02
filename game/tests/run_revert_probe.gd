extends SceneTree
## Changing back with Q puts the apo's feet where the creature's feet were.
##
##   godot --headless --path game --script res://tests/run_revert_probe.gd
##
## Kent: "fix the Q revert drop". A drawn creature's position is its anchor -- the torso the rig
## hangs from -- and the apo's is the soles of its feet, so changing back out of a tall creature
## put the apo's feet where its back had been and dropped it a body's height onto the ground. It
## showed worst in Dagat, at the bangka, where the helper is a horse or an elephant; it was true
## of every level and every tall creature. Short ones had the opposite fault, smaller: the apo's
## feet went where a crab's middle was, a little into the ground.
##
## Measured the way a player sees it: stood still on flat ground as each creature, change back,
## and how far the apo then moves up or down before it is standing.

const LEVEL_SCENE := "res://game_level.tscn"
## Tall, middling and short, and one that stands on two legs.
const CREATURES := ["horse", "elephant", "pig", "monkey", "crab", "frog"]
## How far the apo may settle once it is back: a few pixels of the capsule finding the floor.
const SETTLE := 8.0

var level: Node
var results: Array[String] = []
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	results.append("  %s  %-44s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _run() -> void:
	print("\n===== CHANGING BACK =====")
	level = (load(LEVEL_SCENE) as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(30):
		await physics_frame
	var spawn := (level.get_node("EnvironmentBaseplate/GameplayPlane/SpawnPoint") as Node2D).global_position
	var ground := await _ground_under(spawn)
	for entity_id in CREATURES:
		await _change_back_from(entity_id, spawn, ground)
	for line in results:
		print(line)
	level.queue_free()
	if failures == 0:
		print("OBRA_REVERT_OK")
		quit(0)
	else:
		print("OBRA_REVERT_FAILED=%d" % failures)
		quit(1)


## Where the apo's own feet rest at the spawn: the floor every creature here stands on.
func _ground_under(spawn: Vector2) -> float:
	var apo := level.get("player") as Node2D
	apo.call("apply_morph_state", {"position": spawn + Vector2(0.0, -20.0), "velocity": Vector2.ZERO})
	for _frame in range(60):
		await physics_frame
	return apo.global_position.y


func _change_back_from(entity_id: String, spawn: Vector2, ground: float) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://config/rigs/%s.json" % entity_id))
	var rig_type := String((parsed as Dictionary).get("rig_type", "walker")) if parsed is Dictionary else "walker"
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	level.call("_spawn_or_replace", entity_id, entity_id.capitalize(), sheet,
		RosterFixtures.for_rig(rig_type, entity_id))
	for _frame in range(6):
		await physics_frame
	var creature := level.get("player") as Node2D
	if creature == null or creature is Wanderer:
		_check(false, "%s: set up" % entity_id, "the creature was not drawn")
		return
	creature.call("apply_morph_state", {"position": spawn + Vector2(0.0, -120.0),
		"linear_velocity": Vector2.ZERO})
	# Long enough to land and stand: a rig that is still falling is not a fair test of where
	# it stood.
	for _frame in range(150):
		await physics_frame
	var anchor := creature.call("get_physics_anchor") as Node2D
	var anchor_height := ground - anchor.global_position.y
	level.call("_revert_to_base_form")
	var apo := level.get("player") as Node2D
	if not apo is Wanderer:
		_check(false, "%s: changes back" % entity_id, "Q left %s" % apo)
		return
	var started := apo.global_position.y
	var lowest := started
	var highest := started
	for _frame in range(60):
		await physics_frame
		lowest = maxf(lowest, apo.global_position.y)
		highest = minf(highest, apo.global_position.y)
	var fell := lowest - started
	var rose := started - highest
	_check(fell <= SETTLE and rose <= SETTLE,
		"%s: the apo stands where it stood" % entity_id,
		"fell %.0f px, rose %.0f px (its anchor rode %.0f px above the ground)"
			% [fell, rose, anchor_height])
