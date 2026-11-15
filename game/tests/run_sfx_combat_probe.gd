extends SceneTree
## Combat, headless: each sound asked for where the screen already shows the blow.
##
##   godot --headless --path game --script res://tests/run_sfx_combat_probe.gd
##
## Headless hears nothing, so what is checked is the ASKING (AudioDirector.sfx_requested) and,
## at that moment, the visual the sound plays beside (Dilim's rule). AUDIO_PLAN.md's table D: a
## swing, a cannon, a throw (boomerang, stone, Dilim's salt and ash), the whip, and a foe hit or
## felled -- the ground foes, the manananggal, the sea creatures and the bakunawa.
##
## `-- <words>` runs only the scenarios whose name holds them (for a mutant); the every-check-ran
## guard stands down for such a run.

const COMBAT := [&"swing", &"cannon", &"throw", &"whip", &"foe_hit", &"foe_down"]
const FLOOR_Y := 600.0
## ⚠ BY PATH: the sea creatures have no class_name (see sea_creature_2d.gd).
const SeaCreature = preload("res://scripts/sea_creature_2d.gd")

var failures := 0
var checked := 0
const CHECKS := 11
var world: Node2D
var registry: EntityRegistry
var apo: Node2D
var level: Node
## Every sound asked for in the current scenario, with what the screen showed as it was asked:
## [id, snapshot]. ⚠ A member, not a local: a lambda captures locals by value.
var heard: Array = []
## What a scenario wants recorded beside each sound, read the moment it is asked for.
var snapshot: Callable = func() -> Dictionary: return {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(300.0).timeout.connect(func() -> void:
		print("OBRA_SFX_COMBAT_FAILED=watchdog")
		quit(2))
	root.get_node(^"AudioDirector").connect(&"sfx_requested", _on_sfx_requested)
	await _build_the_world()
	var only := " ".join(OS.get_cmdline_user_args())
	for scenario: Callable in [_every_combat_sound_has_a_file, _a_blade_is_heard_with_its_arc_and_its_blows,
			_a_cannon_is_heard_at_its_muzzle, _a_throw_is_heard_as_it_leaves,
			_the_sea_is_heard_hit_and_felled, _the_bakunawa_is_heard_hit,
			_the_manananggal_is_heard_going, _dilim_is_heard_throwing_and_lashing]:
		if not only.is_empty() and not String(scenario.get_method()).contains(only):
			continue
		heard.clear()
		snapshot = func() -> Dictionary: return {}
		await scenario.call()
	if only.is_empty() and checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_SFX_COMBAT_OK")
		quit(0)
	else:
		print("OBRA_SFX_COMBAT_FAILED=%d" % failures)
		quit(1)


func _on_sfx_requested(id: StringName, _loudness: float) -> void:
	heard.append([String(id), snapshot.call()])


# --- The scenarios -------------------------------------------------------------------------

func _every_combat_sound_has_a_file() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/audio.json"))
	var sfx: Dictionary = catalog.get("sfx", {})
	var silent: Array[String] = []
	for id: StringName in COMBAT:
		var path := String(sfx.get(String(id), ""))
		if path.is_empty() or not (load(path) is AudioStreamWAV):
			silent.append(String(id))
	_check(silent.is_empty(), "every combat sound has a file", "%d of %d" % [COMBAT.size() - silent.size(),
		COMBAT.size()] if silent.is_empty() else "silent: " + ", ".join(silent))


## A swing, a blow that lands (the foe flashes), and the last blow (it falls, and only that).
func _a_blade_is_heard_with_its_arc_and_its_blows() -> void:
	_set_level("level_1")
	var sword := await _in_hand("sword")
	var foe := GroundEnemy2D.new()
	world.add_child(foe)
	foe.global_position = _anchor() + Vector2(70.0, 0.0)
	await _frames(2)
	# Its hit points are its table's, set in _ready: plenty for the first blow, one for the last.
	foe.hp = 99
	snapshot = func() -> Dictionary: return {"posed": float(apo.get(&"_swing_left")) > 0.0,
		"flashed": foe.modulate.r > 1.0, "dead": foe.is_dead()}
	sword.describe_use(apo)
	var swung := _first("swing")
	_check(_count("swing") == 1 and bool(swung.get("posed", false)), "a swing is heard as she strikes the pose",
		"%s" % [heard])
	var blow := _first("foe_hit")
	_check(_count("foe_hit") == 1 and bool(blow.get("flashed", false)) and not bool(blow.get("dead", true))
			and _count("foe_down") == 0,
		"a blow that lands is heard as the foe flashes", "%s" % [heard])
	heard.clear()
	foe.hp = 1
	foe.apply_tool_hit("sword", 0.0, apo)
	var fell := _first("foe_down")
	_check(_ids() == ["foe_down"] and bool(fell.get("dead", false)),
		"and the last blow is heard as its fall, not as a hit", "%s" % [heard])
	await _clear([sword, foe])


func _a_cannon_is_heard_at_its_muzzle() -> void:
	var cannon := await _in_hand("cannon")
	snapshot = func() -> Dictionary:
		var shots := world.find_children("*", "", true, false).filter(func(node: Node) -> bool:
			return node is CannonShot2D)
		return {"shot": not shots.is_empty()}
	cannon.describe_use(apo)
	_check(_count("cannon") == 1 and bool(_first("cannon").get("shot", false)),
		"a cannon is heard as its shot leaves the muzzle", "%s" % [heard])
	await _frames(2)
	await _clear([cannon])


## The boomerang from the hand, and a stone from the alley's sling.
func _a_throw_is_heard_as_it_leaves() -> void:
	var boomerang := await _in_hand("boomerang")
	snapshot = func() -> Dictionary: return {"flying": bool(boomerang.get(&"_active"))}
	boomerang.describe_use(apo)
	var away := _first("throw")
	var stone := StoneThrow2D.new()
	stone.hand = func() -> Vector2: return _anchor()
	stone.floor_y = FLOOR_Y
	world.add_child(stone)
	stone.give_stone()
	stone.hold(StoneThrow2D.Kind.STONE)
	stone.aim_at(_anchor() + Vector2(300.0, -100.0))
	await _frames(1)
	heard.clear()
	snapshot = func() -> Dictionary: return {"flying": stone.in_flight(StoneThrow2D.Kind.STONE)}
	var thrown := stone.throw()
	var sling := _first("throw")
	_check(bool(away.get("flying", false)) and thrown and _count("throw") == 1 and bool(sling.get("flying", false)),
		"a throw is heard as it leaves the hand: the boomerang, and a stone",
		"boomerang %s, stone %s" % [away, heard])
	await create_timer(1.4).timeout
	await _clear([boomerang, stone])


## Struck, a sea creature is knocked back hurt; at its last point it dies, and only that is heard.
func _the_sea_is_heard_hit_and_felled() -> void:
	var fish: Node2D = SeaCreature.new()
	fish.set(&"kind", "bangus")
	world.add_child(fish)
	fish.global_position = _anchor() + Vector2(200.0, -200.0)
	await _frames(2)
	snapshot = func() -> Dictionary: return {"hurt": float(fish.get(&"_hurt")) > 0.0,
		"alive": bool(fish.call(&"is_alive"))}
	for _blow in range(SeaCreature.HIT_POINTS):
		fish.call(&"apply_tool_hit", "sword", 0.0, apo)
	var hits := heard.filter(func(entry: Array) -> bool: return entry[0] == "foe_hit")
	var all_hurt := hits.all(func(entry: Array) -> bool: return bool((entry[1] as Dictionary).get("hurt", false)))
	_check(hits.size() == SeaCreature.HIT_POINTS - 1 and all_hurt and _count("foe_down") == 1
			and _ids().back() == "foe_down" and not bool(fish.call(&"is_alive")),
		"a sea creature is heard hit as it is hurt, and its last blow as its death", "%s" % [_ids()])
	await _clear([fish])


## Subdued, never felled: every blow is a hit, the last one too.
func _the_bakunawa_is_heard_hit() -> void:
	var serpent := Bakunawa2D.new()
	world.add_child(serpent)
	await _frames(2)
	serpent.enter_fight()
	snapshot = func() -> Dictionary: return {"hurt": float(serpent.get(&"_hurt")) > 0.0}
	var weapon := String(Bakunawa2D.BITE.keys()[0])
	var landed := serpent.apply_tool_hit(weapon, 0.0, apo)
	_check(landed and _ids() == ["foe_hit"] and bool(_first("foe_hit").get("hurt", false)),
		"a blow on the bakunawa is heard as it shows red", "%s" % [heard])
	await _clear([serpent])


## Its upper half does not fall: it flies off. That end is still heard.
func _the_manananggal_is_heard_going() -> void:
	_set_level("level_4")
	var upper := ManananggalUpper2D.new()
	world.add_child(upper)
	upper.global_position = _anchor() + Vector2(120.0, -160.0)
	await _frames(2)
	upper.hp = 1
	snapshot = func() -> Dictionary: return {"leaving": bool(upper.get(&"_leaving"))}
	upper.apply_tool_hit("buntot_pagi", 0.0, apo)
	_check(_ids() == ["foe_down"] and bool(_first("foe_down").get("leaving", false)),
		"the manananggal is heard ending as it flies off", "%s" % [heard])
	await _clear([upper])
	_set_level("level_1")


## Dilim's satchel: a handful of salt ahead, ash into the air, and the whip.
func _dilim_is_heard_throwing_and_lashing() -> void:
	_set_level("level_4")
	level = (load("res://level_4.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(40)
	var plane := level.get_node(^"EnvironmentBaseplate/GameplayPlane")
	snapshot = func() -> Dictionary:
		var kinds: Array[String] = []
		for child in plane.get_children():
			if child is AsinThrow2D:
				kinds.append("salt")
			elif child is AboDust2D:
				kinds.append("ash")
			elif child is WhipLash2D:
				kinds.append("lash")
		return {"shown": kinds}
	heard.clear()
	level.call("_throw_salt", {})
	level.call("_throw_ash", {})
	var throws := heard.filter(func(entry: Array) -> bool: return entry[0] == "throw") \
		.map(func(entry: Array) -> Array: return (entry[1] as Dictionary).get("shown", []))
	_check(throws == [["salt"], ["salt", "ash"]], "salt and ash are each heard as they leave her hand",
		"%s" % [throws])
	heard.clear()
	level.call("_lash_the_whip")
	var lash: Array = _first("whip").get("shown", [])
	_check(_count("whip") == 1 and lash.has("lash"), "the whip is heard with its lash", "%s" % [heard])
	level.queue_free()
	await _frames(4)


# --- Fixture -------------------------------------------------------------------------------

func _build_the_world() -> void:
	world = Node2D.new()
	root.add_child(world)
	var ground := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(4000.0, 40.0)
	shape.shape = box
	ground.add_child(shape)
	world.add_child(ground)
	ground.global_position = Vector2(600.0, FLOOR_Y + 20.0)
	registry = EntityRegistry.new()
	world.add_child(registry)
	registry.load_manifest()
	apo = (load("res://creatures/wanderer.tscn") as PackedScene).instantiate() as Node2D
	world.add_child(apo)
	apo.global_position = Vector2(600.0, FLOOR_Y)
	await _frames(30)


## A drawn tool in her hand, as run_weapon_probe holds one.
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
	tool.global_position = _anchor() + Vector2(30.0, 0.0)
	await physics_frame
	tool.interact(apo)
	await _frames(3)
	heard.clear()
	return tool


func _anchor() -> Vector2:
	if apo.has_method("get_physics_anchor"):
		var anchor := apo.call("get_physics_anchor") as Node2D
		if anchor != null:
			return anchor.global_position
	return apo.global_position


func _set_level(level_id: String) -> void:
	root.get_node(^"LevelManager").set(&"current_level_id", level_id)


func _clear(nodes: Array) -> void:
	for node: Variant in nodes:
		if node != null and is_instance_valid(node):
			(node as Node).queue_free()
	await _frames(3)


func _ids() -> Array:
	return heard.map(func(entry: Array) -> String: return entry[0])


func _count(id: String) -> int:
	return _ids().count(id)


## What the screen showed when `id` was first asked for, or {} if it never was.
func _first(id: String) -> Dictionary:
	for entry: Array in heard:
		if entry[0] == id:
			return entry[1]
	return {}


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
