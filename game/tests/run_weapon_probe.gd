extends SceneTree
## Every weapon, used the way a player uses it, against targets that count what reaches them.
##
##   godot --headless --path game --script res://tests/run_weapon_probe.gd
##
## ⚠ WHY THIS EXISTS. The bakunawa probe proved the fight by calling apply_tool_hit itself.
## That cannot fail the way a swing can, and it hid four faults for as long as the fight
## existed: a boomerang struck every frame of its flight, a cannon flew straight through
## anything hurt through an area, a dropped anvil hurt nothing, and a sword cut what stood
## behind her. Here nothing is called but the weapon's own use.

const FLOOR_Y := 400.0

var world: Node2D
var registry: EntityRegistry
var apo: Node2D
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	world = Node2D.new()
	root.add_child(world)
	_add_floor()
	registry = EntityRegistry.new()
	world.add_child(registry)
	registry.load_manifest()
	apo = (load("res://creatures/wanderer.tscn") as PackedScene).instantiate() as Node2D
	world.add_child(apo)
	apo.global_position = Vector2(600.0, FLOOR_Y)
	for _frame in range(30):
		await physics_frame

	await _a_blade_cuts_in_front_and_not_behind()
	await _a_blade_finishes_its_swing_first()
	await _a_blade_never_shoves_its_holder()
	await _a_boomerang_strikes_once_per_throw()
	await _a_cannon_lands_on_an_area_once()
	await _an_anvil_crushes_once_and_leaves_the_hand()

	if failures == 0:
		print("OBRA_WEAPONS_OK")
		quit(0)
	else:
		print("OBRA_WEAPONS_FAILED=%d" % failures)
		quit(1)


func _a_blade_cuts_in_front_and_not_behind() -> void:
	var sword := await _in_hand("sword")
	var at := _anchor()
	var ahead := _target("Area2D", at + Vector2(70.0, 0.0))
	var behind := _target("Area2D", at + Vector2(-70.0, 0.0))
	await _frames(2)
	sword.describe_use(apo)
	await _frames(2)
	_check(ahead.get("hits") == 1, "a sword cuts what is in front of her",
		"%d blows ahead" % ahead.get("hits"))
	_check(behind.get("hits") == 0, "and not what stands behind her",
		"%d blows behind" % behind.get("hits"))
	await _clear([sword, ahead, behind])


func _a_blade_finishes_its_swing_first() -> void:
	var sword := await _in_hand("sword")
	var ahead := _target("Area2D", _anchor() + Vector2(60.0, 0.0))
	await _frames(2)
	sword.describe_use(apo)
	sword.describe_use(apo)
	sword.describe_use(apo)
	await _frames(2)
	_check(ahead.get("hits") == 1, "three presses inside one swing land one blow",
		"%d blows" % ahead.get("hits"))
	await create_timer(0.35).timeout
	sword.describe_use(apo)
	await _frames(2)
	_check(ahead.get("hits") == 2, "and the next swing lands once the first is done",
		"%d blows" % ahead.get("hits"))
	await _clear([sword, ahead])


## A drawn creature holding a blade is a rig of loose rigid bodies, all hers.
func _a_blade_never_shoves_its_holder() -> void:
	var sword := await _in_hand("sword")
	var limb := RigidBody2D.new()
	limb.gravity_scale = 0.0
	limb.add_to_group(&"player_character")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	limb.add_child(shape)
	world.add_child(limb)
	limb.global_position = _anchor() + Vector2(50.0, -30.0)
	await _frames(2)
	sword.describe_use(apo)
	await _frames(4)
	_check(limb.linear_velocity.length() < 1.0, "a swing never shoves her own body",
		"limb moving at %.0f px/s" % limb.linear_velocity.length())
	await _clear([sword, limb])


func _a_boomerang_strikes_once_per_throw() -> void:
	var boomerang := await _in_hand("boomerang")
	# On the arc: out to its full reach at the top of the throw.
	var on_the_arc := _target("Area2D", _anchor() + Vector2(300.0, -150.0), 44.0)
	await _frames(2)
	boomerang.describe_use(apo)
	await create_timer(1.4).timeout
	_check(on_the_arc.get("hits") == 1, "a boomerang strikes a target once per throw",
		"%d blows in one flight" % on_the_arc.get("hits"))
	await _clear([boomerang, on_the_arc])


func _a_cannon_lands_on_an_area_once() -> void:
	var cannon := await _in_hand("cannon")
	# Hurt only through an area, the way every sea creature and the bakunawa are.
	var creature := _target("Area2D", _anchor() + Vector2(420.0, -60.0), 48.0)
	await _frames(2)
	cannon.describe_use(apo)
	await create_timer(1.2).timeout
	_check(creature.get("hits") == 1, "a cannon shot lands on a creature hurt through an area",
		"%d blows" % creature.get("hits"))
	await _clear([cannon, creature])


func _an_anvil_crushes_once_and_leaves_the_hand() -> void:
	var anvil := await _in_hand("anvil")
	var left := [0]
	anvil.left_the_hand.connect(func(_u: UtilityObject) -> void: left[0] += 1)
	# Under the drop point: 56 px ahead of her, on the ground.
	var under := _target("Area2D", Vector2(_anchor().x + 56.0, FLOOR_Y - 20.0), 30.0)
	await _frames(2)
	anvil.describe_use(apo)
	await create_timer(1.2).timeout
	_check(under.get("hits") == 1, "a dropped anvil crushes what it lands on, once",
		"%d blows" % under.get("hits"))
	_check(anvil.get("_equipped_actor") == null and left[0] == 1,
		"and it has left her hand", "left_the_hand emitted %d time(s)" % left[0])
	await _clear([anvil, under])


# --- fixture -------------------------------------------------------------------------

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
	# The grip is placed from her facing every physics frame; give it a frame to land.
	await _frames(3)
	return tool


## A thing that counts the blows that reach it, hurt through a body or an area.
func _target(kind: String, at: Vector2, radius: float = 20.0) -> Node2D:
	var script := GDScript.new()
	script.source_code = "extends %s\nvar hits := 0\nfunc apply_tool_hit(_tool: String, _impulse: float, _actor: Node2D) -> bool:\n\thits += 1\n\treturn true\n" % kind
	script.reload()
	var node: Node2D = Area2D.new() if kind == "Area2D" else StaticBody2D.new()
	node.set_script(script)
	node.collision_layer = 1
	node.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	node.add_child(shape)
	world.add_child(node)
	node.global_position = at
	return node


func _anchor() -> Vector2:
	if apo.has_method("get_physics_anchor"):
		var anchor := apo.call("get_physics_anchor") as Node2D
		if anchor != null:
			return anchor.global_position
	return apo.global_position


func _add_floor() -> void:
	var ground := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(4000.0, 40.0)
	shape.shape = box
	ground.add_child(shape)
	world.add_child(ground)
	ground.global_position = Vector2(600.0, FLOOR_Y + 20.0)


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func _clear(nodes: Array) -> void:
	for node: Variant in nodes:
		if node is Node and is_instance_valid(node):
			(node as Node).queue_free()
	await _frames(3)


func _check(ok: bool, what: String, detail: String) -> void:
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
