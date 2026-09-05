class_name UtilityObject
extends "res://scripts/physics_shape_object.gd"
## One placed/equipped instance of a drawn utility. Unique behavior is selected
## by manifest metadata; future level targets integrate through method checks.

signal equipped(utility: UtilityObject, actor: Node2D)
signal utility_used(behavior: String, item: DrawnItemData)
signal utility_consumed(utility: UtilityObject)
## E reached this and it declined, with a reason. A refusal the player cannot hear is
## indistinguishable from a broken key -- which is exactly how an unsettled ladder read.
signal interaction_note(text: String)

## Carried and worked with (F). Everything else is a prop: it is stood up in the world
## and does its job by being there (stairs, bridge, tree, bread) or by being stepped
## on (door). The split comes from the In-Game Function column of the 50-class
## table, not from what happened to be implemented.
const HELD_TOOLS := [
	"axe", "sword", "cannon", "boomerang", "flashlight", "cloud", "sun", "fan",
	"parachute", "hot_air_balloon", "key", "rake", "scissors", "clock", "anvil",
	"bucket", "umbrella", "wheel",
]
## Tools whose F is a state that stays on until pressed again, rather than one action.
const TOGGLE_TOOLS := ["flashlight", "umbrella", "fan", "parachute", "hot_air_balloon", "wheel"]
## ⚠ THE PROPS YOU GO UP, AND ALL THREE ARE IN THE CLIMB TAG. It was only the ladder for a
## long time, while `stairs` and `tree` sat in the same tag with no interaction at all -- so
## an obstacle asking for Climb accepted a drawn tree, and the tree was then a shape on the
## ground. Climb is the most required tag in the game; two of its eight members answering it
## with nothing is the tag layer lying to the player, which is worse than refusing them.
const CLIMBABLE_PROPS := ["ladder", "stairs", "tree"]

## How far a tool reaches for things to act on.
const TOOL_REACH := 96.0
## HOW FAR EACH WAY OF HITTING SOMETHING ACTUALLY REACHES, named so a level audit can read
## the constant instead of keeping a copy of it -- the same discipline R1 uses for the jump.
##
## This exists because Level 2 asked `strike` to knock a bird out of the air and the tag
## resolved to boomerang, axe and sword. Only one of those leaves the hand: a blade swings
## inside TOOL_REACH, so two of that route's three answers were accepted by the tag layer
## and then did nothing. A reach that lives only inside a function body cannot be checked.
const BOOMERANG_THROW := 320.0
## The shot is a body under gravity rather than a fixed arc, so this is where it lands on
## the flat, measured from the muzzle velocity below. Conservative on purpose.
const CANNON_RANGE := 640.0
## What each behaviour can touch. A behaviour absent from this table reaches TOOL_REACH.
const BEHAVIOUR_REACH := {
	"boomerang": BOOMERANG_THROW,
	"cannon": CANNON_RANGE,
}


## How far this behaviour can hit, for an obstacle that needs to know before it accepts it.
static func reach_of(behaviour: String) -> float:
	return float(BEHAVIOUR_REACH.get(behaviour, TOOL_REACH))
## Continuous per-frame accelerations (px/s^2) the tools push the player with.
const FAN_PUSH := 620.0
const BALLOON_LIFT := -1180.0
const PARACHUTE_DRAG := -820.0
const PARACHUTE_FALL_LIMIT := 120.0
## How long the clock holds nearby movement still.
const CLOCK_FREEZE_SECONDS := 4.0
## Long enough that one landing is one bounce, short enough to feel like a trampoline.
## Radius the weather tools work over.
const WEATHER_RADIUS := 220.0
## How fast a drawn hull will go, however long the player holds the stick.
const VEHICLE_TOP_SPEED := 240.0

var utility_behavior: String = ""
var required_medium: String = "any"

var _active: bool = false
## Seconds left on a timed effect (the clock's stopped time).
var _effect_time: float = 0.0
## Bodies the clock is holding still, and the freeze state each had before.
var _held_bodies: Dictionary = {}
## The bucket carries water between places; nothing else uses this yet.
var _carried_water: bool = false
## The player a door just moved, so the pair does not bounce them back immediately.
var _door_recent: Node2D = null
var _settle_time: float = 0.0
var _equipped_actor: Node2D
var _boarded_actor: Node2D
var _light_cone: Polygon2D
var _point_light: PointLight2D
var _interaction_area: Area2D
var _vehicle_joint: PinJoint2D


func _ready() -> void:
	controllable = false
	super._ready()
	_create_interaction_area()
	if utility_behavior == "flashlight":
		_create_flashlight_nodes()
	elif utility_behavior == "campfire":
		# Warmth: a campfire is a light that is simply on, wherever it was set down.
		_create_flashlight_nodes()
		_active = true
		_set_light_active(true)
	add_to_group("drawn_utilities")
	if utility_behavior in ["sailboat", "submarine"]:
		# Hulls do their own buoyancy in _integrate_forces. Without this the pool lifts
		# them too and the two together launch the boat clean out of the water.
		set_meta(&"self_buoyant", true)


func configure_entity(entry: Dictionary) -> void:
	super.configure_entity(entry)
	controllable = false
	utility_behavior = String(entry.get("utility_behavior", entry.get("id", "")))
	required_medium = String(entry.get("required_medium", "any"))


func apply_item_data(item: DrawnItemData) -> void:
	# The base class records item_data now, for every shape and not just utilities.
	super.apply_item_data(item)
	if not item.runtime_state.is_empty():
		restore_utility_state(item.runtime_state)


## A utility also has an interaction area, which must not react while it is a ghost.
func set_preview(enabled: bool) -> void:
	super.set_preview(enabled)
	if _interaction_area != null:
		_interaction_area.monitoring = not enabled
	# A doorway you cannot walk into is not a doorway. Every other placed object is
	# meant to be solid; the teleport door's whole job is to be stepped through, and a
	# solid one simply shoved the player back out of its own threshold before the
	# portal could ever see them standing in it.
	if not enabled and utility_behavior == "door":
		collision_layer = 0
		freeze = true


func interact(actor: Node2D) -> void:
	if actor == null:
		return
	if utility_behavior in CLIMBABLE_PROPS:
		if actor.has_method("is_using_ladder") and bool(actor.call("is_using_ladder", self)):
			actor.call("end_ladder")
			super.interact(actor)
			return
		# ⚠ SETTLED, OR SAY SO. This used to read `and freeze`, and an unsettled ladder fell
		# straight through to the pickup below -- so the answer to "I drew a ladder and E just
		# put it back in my bag" is that E did exactly what it was told. A ladder still rolling
		# is not climbable, but the player pressed E to climb it, and silently doing the
		# opposite of what they asked is the worst reading of an ambiguous key.
		if not _standing_still():
			interaction_note.emit("%s is still settling — give it a moment" % _display_name())
			return
		if actor.has_method("begin_ladder"):
			actor.call("begin_ladder", self)
			utility_used.emit(utility_behavior, item_data)
		return
	if utility_behavior in ["sailboat", "submarine"] and _is_in_water():
		if _boarded_actor == actor:
			_unboard_actor()
			return
		_board_actor(actor)
		return
	if _equipped_actor == actor:
		super.interact(actor)
		return
	if is_held_tool():
		equip_to(actor)
	else:
		super.interact(actor)


## A tool the player carries and works with (F), as opposed to a prop they stand a
## thing up in the world and leave (ladder, bridge, tree, bread, door...). Only the
## first four were listed here, so drawing any of the other fifteen tools produced
## something that could be put in a pocket and never used -- which is most of what
## "21 of 27 utilities do nothing on F" actually was.
func is_held_tool() -> bool:
	return utility_behavior in HELD_TOOLS


func equip_to(actor: Node2D) -> void:
	var grip: Node2D = actor.call("get_grip_anchor") as Node2D if actor.has_method("get_grip_anchor") else actor
	if grip == null:
		return
	_equipped_actor = actor
	freeze = true
	collision_layer = 0
	collision_mask = 0
	reparent(grip, false)
	position = Vector2.ZERO
	rotation = 0.0
	if actor.has_method("set_equipped_utility"):
		actor.call("set_equipped_utility", self)
	equipped.emit(self, actor)


func prepare_for_inventory() -> DrawnItemData:
	var item := super.prepare_for_inventory()
	if item == null:
		return null
	if _equipped_actor != null and is_instance_valid(_equipped_actor):
		if utility_behavior == "umbrella" and _equipped_actor.has_method("set_umbrella_open"):
			_equipped_actor.call("set_umbrella_open", false)
		if _equipped_actor.has_method("set_equipped_utility"):
			_equipped_actor.call("set_equipped_utility", null)
	_equipped_actor = null
	_unboard_actor()
	return item


func drop_to_world(world_root: Node2D, at: Vector2) -> void:
	if world_root == null:
		return
	if _equipped_actor != null and is_instance_valid(_equipped_actor):
		if utility_behavior == "umbrella" and _equipped_actor.has_method("set_umbrella_open"):
			_equipped_actor.call("set_umbrella_open", false)
		if _equipped_actor.has_method("set_equipped_utility"):
			_equipped_actor.call("set_equipped_utility", null)
	_equipped_actor = null
	reparent(world_root, true)
	global_position = at
	freeze = false
	gravity_scale = 1.0
	collision_layer = 1
	collision_mask = 1
	sleeping = false


## What pressing F does. Every behavior in the 50-class table answers here: the `_:`
## branch used to swallow twenty-one of them, so most of the objects the player could
## draw were pocket lint. Returns the line to show, or "" when the tool genuinely
## could not act (nothing in reach, wrong medium) -- never silence.
func use_utility(actor: Node2D) -> bool:
	return not describe_use(actor).is_empty()


## The same action, reporting what happened. `use_utility` is kept as the boolean
## contract the older call sites and the requirement hooks were written against.
func describe_use(actor: Node2D) -> String:
	if actor == null or (_equipped_actor != null and actor != _equipped_actor):
		return ""
	var outcome := _perform_use(actor)
	if outcome.is_empty():
		return ""
	utility_used.emit(utility_behavior, item_data)
	return outcome


func _perform_use(actor: Node2D) -> String:
	match utility_behavior:
		"axe", "sword", "scissors":
			return _swing_blade(actor)
		"cannon":
			return _fire_cannon(actor)
		"boomerang":
			return _throw_boomerang(actor)
		"key":
			return _use_key(actor)
		"rake":
			return _rake_pull(actor)
		"anvil":
			return _drop_anvil(actor)
		"clock":
			return _freeze_time(actor)
		"cloud":
			return _make_rain(actor)
		"sun":
			return _evaporate(actor)
		"bucket":
			return _use_bucket(actor)
		"umbrella":
			_active = not _active
			if actor.has_method("set_umbrella_open"):
				actor.call("set_umbrella_open", _active)
			scale = Vector2(1.22, 0.86) if _active else Vector2.ONE
			return "Umbrella %s" % ("open — falling things bounce off" if _active else "folded")
		"flashlight":
			_active = not _active
			_set_light_active(_active)
			return "Flashlight %s" % ("on" if _active else "off")
		"fan":
			_active = not _active
			return "Fan %s" % ("blowing" if _active else "still")
		"parachute":
			_active = not _active
			return "Parachute %s" % ("open — you fall slowly" if _active else "packed away")
		"hot_air_balloon":
			_active = not _active
			return "Balloon %s" % ("rising" if _active else "vented")
		"wheel":
			_active = not _active
			return "Wheel %s" % ("spinning — it carries what rests on it" if _active else "stopped")
		"sailboat":
			return "Sailing — move to steer" if _boarded_actor == actor else ""
		"submarine":
			return "Diving — move to steer" if _boarded_actor == actor else ""
		"bridge", "campfire", "bread", "door":
			# Props: they work by standing where they were put. Saying so is the honest
			# answer to F, and better than the silence that read as a broken button.
			return "%s works where it stands — place it, then use it" % _display_name()
	return ""


## Resting where it was put, whether or not the settle timer has got round to freezing it.
## `freeze` alone was too strict: it needs three quarters of a second of stillness, and a
## player who walks up to a ladder the instant it lands is inside that window.
func _standing_still() -> bool:
	return freeze or (_grounded and linear_velocity.length() < 24.0
		and absf(angular_velocity) < 0.4)


func _display_name() -> String:
	if item_data != null and not item_data.display_name.is_empty():
		return item_data.display_name
	return utility_behavior.capitalize()


func serialize_utility_state() -> Dictionary:
	return {
		"active": _active,
		"settled": freeze and utility_behavior == "ladder"
	}


func restore_utility_state(state: Dictionary) -> void:
	_active = bool(state.get("active", false))
	if utility_behavior == "flashlight":
		_set_light_active(_active)
	if utility_behavior == "ladder" and bool(state.get("settled", false)):
		freeze = true


func _physics_process(delta: float) -> void:
	if is_preview:
		return
	if not is_held_tool() and utility_behavior not in ["sailboat", "submarine"] and not freeze:
		if _grounded and linear_velocity.length() < 8.0 and absf(angular_velocity) < 0.18:
			_settle_time += delta
			if _settle_time >= 0.75:
				freeze = true
				linear_velocity = Vector2.ZERO
				angular_velocity = 0.0
		else:
			_settle_time = 0.0
	if utility_behavior in ["sailboat", "submarine"] and _boarded_actor != null and not _is_in_water():
		# Run aground. Putting the passenger down where the hull stopped is the honest
		# outcome; carrying on without them meant the boat sailed off across dry land
		# and the player was left standing at the water's edge with no way to say so.
		_unboard_actor()
	if utility_behavior in ["sailboat", "submarine"] and _is_in_water() and _boarded_actor != null:
		_seat_carried_actor()
		var horizontal := Input.get_axis("move_left", "move_right")
		apply_central_force(Vector2(horizontal * mass * 900.0, 0.0))
		apply_torque(horizontal * 240.0)
		if utility_behavior == "submarine":
			# Dive: it goes down and stays down, which is the whole point of it.
			var vertical := Input.get_axis("move_up", "move_down")
			apply_central_force(Vector2(0.0, (140.0 + vertical * 620.0) * mass))
	if _effect_time > 0.0:
		_effect_time = maxf(0.0, _effect_time - delta)
		if _effect_time <= 0.0:
			_release_frozen_bodies()
	_apply_held_effects(delta)
	_apply_prop_effects(delta)


## The tools whose F turns something ON rather than doing something once. They are
## re-applied every frame, so switching one off simply stops doing it -- there is no
## state to unwind on the player.
func _apply_held_effects(_delta: float) -> void:
	if not _active or _equipped_actor == null or not is_instance_valid(_equipped_actor):
		return
	match utility_behavior:
		"parachute":
			# Glide: drag that only exists while falling, and a hard cap so a long
			# drop is survivable however far it is.
			_push_actor(_equipped_actor, Vector2(0.0, PARACHUTE_DRAG))
			if _equipped_actor.has_method("limit_fall_speed"):
				_equipped_actor.call("limit_fall_speed", PARACHUTE_FALL_LIMIT)
		"hot_air_balloon":
			_push_actor(_equipped_actor, Vector2(0.0, BALLOON_LIFT))
		"fan":
			# Wind: it pushes the world, not the holder -- so it moves what is in front
			# of you rather than shoving you backwards.
			var facing := _facing_of(_equipped_actor)
			for target in _reachable_targets(WEATHER_RADIUS):
				var body := target as RigidBody2D
				if body == null or body == self or body.freeze or _is_player_body(body):
					continue
				body.apply_central_force(Vector2(facing * FAN_PUSH, -FAN_PUSH * 0.35) * body.mass)


## Props act by being where they were left. Nothing here needs the player to be
## holding it, which is exactly what makes them props.
func _apply_prop_effects(_delta: float) -> void:
	if _equipped_actor != null or is_preview:
		return
	match utility_behavior:
		# `bread` has no case here on purpose. It is the one prop whose effect is not
		# something it does -- the birds in Level 2 come to it, so the reaching is on
		# their side. Nothing to apply per frame.
		"wheel":
			# Roll/Fix: a driven roller. What rests on it is carried along.
			if not _active:
				return
			angular_velocity = 6.5
			for target in _reachable_targets(_target_size().x * 0.5 + 64.0):
				var body := target as RigidBody2D
				if body != null and body != self and not body.freeze and body.global_position.y < global_position.y:
					body.apply_central_force(Vector2(240.0, 0.0) * body.mass)
		"door":
			_run_door()


## Teleport: two placed doors are a pair, and stepping into one puts the player at the
## other. With fewer than two placed there is nowhere to go, which is why a single
## door does nothing and says so.
func _run_door() -> void:
	var partner := _door_partner()
	if partner == null:
		return
	for target in _reachable_targets(_target_size().length() * 0.5 + 32.0):
		if not _is_player_body(target):
			continue
		var player := _player_of(target)
		if player == null or player == _door_recent:
			continue
		partner.set("_door_recent", player)
		_door_recent = player
		var landing := partner.global_position + Vector2(0.0, -_target_size().y * 0.25)
		if player.has_method("apply_morph_state"):
			player.call("apply_morph_state", {"position": landing})
		else:
			player.global_position = landing
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			_door_recent = null
			if is_instance_valid(partner):
				partner.set("_door_recent", null))
		return


func _door_partner() -> UtilityObject:
	for node in get_tree().get_nodes_in_group("drawn_utilities"):
		var other := node as UtilityObject
		if other != null and other != self and other.utility_behavior == "door" \
			and not other.is_preview and other._equipped_actor == null:
			return other
	return null


func _player_of(node: Node) -> Node2D:
	var current := node
	while current != null:
		if current.is_in_group(&"player_character") or current is ActiveRagdollMorph:
			return current as Node2D
		current = current.get_parent()
	return null


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# The base pass first, and this override existed for a long time without it: the
	# world-bounds clamp, the non-finite-transform recovery and the speed ceiling all
	# live up there, so no drawn utility had any of them. A boat that got loose left the
	# level entirely instead of being stopped at its edge. It sets _grounded too, so
	# there is nothing left here to repeat.
	super._integrate_forces(state)
	if utility_behavior not in ["sailboat", "submarine"] or not _is_in_water():
		return
	# The submarine was left out of this entirely, so the one vessel whose whole job is
	# to sit in water had no buoyancy and no drag at all.
	# The hull floats ITSELF, and tells the water to keep its hands off (see the meta in
	# _ready). Letting the pool lift it as well double-counted the buoyancy and threw it
	# out of the water; letting the pool do it INSTEAD is the tidier design but it is not
	# a swap to make while the vehicles are still unreliable, so the hull keeps the
	# behaviour its own test documents.
	gravity_scale = 0.18 if utility_behavior == "sailboat" else 0.62
	var velocity := state.linear_velocity
	state.apply_central_force(-state.total_gravity * mass * 0.82)
	state.apply_central_force(-velocity * mass * 2.4)
	state.apply_torque(-state.angular_velocity * mass * 1.8)
	# A hull has a top speed. Clamped HERE and not in _physics_process, because a write
	# to linear_velocity outside the physics callback is overwritten by the solver --
	# which is why the cap did nothing and the boat crossed the level in two seconds.
	# Assigned as a whole vector. Writing state.linear_velocity.x on its own left the
	# cap doing nothing at all, which is why the hull still crossed the level in seconds
	# after the cap had supposedly been moved into the physics callback.
	state.linear_velocity = Vector2(
		clampf(state.linear_velocity.x, -VEHICLE_TOP_SPEED, VEHICLE_TOP_SPEED),
		clampf(state.linear_velocity.y, -VEHICLE_TOP_SPEED, VEHICLE_TOP_SPEED))


## Chop, slash and snip are one motion against different things: the tool name is
## passed through so a target can decide what bites it (a rope yields to scissors, a
## barricade wants the axe). It also shoves loose bodies, so a swing does something
## visible even where the level has put nothing to cut.
func _swing_blade(actor: Node2D) -> String:
	var struck := 0
	var shoved := 0
	var facing := _facing_of(actor)
	for target in _reachable_targets():
		if target.has_method("apply_tool_hit") and bool(target.call("apply_tool_hit", utility_behavior, 420.0, actor)):
			struck += 1
			continue
		var body := target as RigidBody2D
		if body != null and body != self and not body.freeze:
			body.apply_central_impulse(Vector2(facing * 210.0, -90.0) * body.mass)
			shoved += 1
		elif body != null and body != self and body.freeze and utility_behavior == "scissors":
			# Snip: what scissors cut here is whatever has been pinned in place -- a
			# settled ladder comes loose again so it can be repositioned.
			body.freeze = false
			struck += 1
	var swing := create_tween()
	swing.tween_property(self, "rotation", deg_to_rad(72.0 * facing), 0.11).set_trans(Tween.TRANS_QUAD)
	swing.tween_property(self, "rotation", 0.0, 0.16).set_trans(Tween.TRANS_BACK)
	if struck > 0:
		return "%s cut through %d" % [_display_name(), struck]
	if shoved > 0:
		return "%s knocked %d loose" % [_display_name(), shoved]
	return "%s swings — nothing in reach" % _display_name()


## Blast: a heavy shot that carries its own damage to whatever it lands on. Spawned
## rather than raycast so the player can see where the force went.
func _fire_cannon(actor: Node2D) -> String:
	var shot := RigidBody2D.new()
	shot.mass = 4.0
	shot.gravity_scale = 0.85
	shot.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	shot.contact_monitor = true
	shot.max_contacts_reported = 4
	var ball := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 11.0
	ball.shape = circle
	shot.add_child(ball)
	var ink := Polygon2D.new()
	ink.polygon = _circle_points(11.0)
	ink.color = Color(0.1, 0.1, 0.12)
	shot.add_child(ink)
	var facing := _facing_of(actor)
	var world := get_parent()
	world.add_child(shot)
	shot.global_position = global_position + Vector2(facing * 44.0, -14.0)
	shot.linear_velocity = Vector2(facing * 980.0, -190.0)
	shot.body_entered.connect(func(hit: Node) -> void: _on_shot_landed(shot, hit, actor))
	# Recoil, so firing is something the player feels rather than only sees.
	_push_actor_impulse(actor, Vector2(-facing * 120.0, -40.0))
	# The despawn timer is a CHILD of the shot, so it dies with it. A SceneTree timer
	# holding the shot in a lambda outlives the shot when something else frees it first,
	# and Godot rightly complains that the capture was freed out from under it.
	var despawn := Timer.new()
	despawn.one_shot = true
	despawn.wait_time = 6.0
	shot.add_child(despawn)
	despawn.timeout.connect(shot.queue_free)
	despawn.start()
	return "Cannon fired"


func _on_shot_landed(shot: RigidBody2D, hit: Node, actor: Node2D) -> void:
	if not is_instance_valid(shot):
		return
	var target := _tool_target(hit)
	if target != null and target.has_method("apply_tool_hit"):
		target.call("apply_tool_hit", "cannon", 900.0, actor)
	shot.queue_free()


## Retrieve: it leaves the hand, flies out, and comes back dragging what it met. The
## return trip is what makes it a boomerang rather than a thrown rock, so it is flown
## by hand instead of left to physics.
func _throw_boomerang(actor: Node2D) -> String:
	if _active:
		return ""
	_active = true
	var origin := _actor_position(actor)
	var facing := _facing_of(actor)
	var world := _world_root()
	if world == null:
		_active = false
		return ""
	if _equipped_actor != null:
		reparent(world, true)
	freeze = true
	collision_layer = 0
	collision_mask = 0
	var flight := create_tween()
	flight.tween_method(
		func(t: float) -> void: _fly_boomerang(actor, origin, facing, t),
		0.0, 1.0, 1.1
	)
	flight.tween_callback(func() -> void: _catch_boomerang(actor))
	return "Boomerang thrown"


func _fly_boomerang(actor: Node2D, origin: Vector2, facing: float, t: float) -> void:
	# Out and back along an arc, so the far end of the throw is the only place it can
	# reach and the player can see it get there.
	var out := sin(t * PI)
	global_position = origin + Vector2(facing * BOOMERANG_THROW * out, -120.0 * out * out - 40.0 * out)
	rotation += 0.55
	for target in _reachable_targets():
		if target.has_method("apply_tool_hit"):
			target.call("apply_tool_hit", "boomerang", 180.0, actor)
		var body := target as RigidBody2D
		if body != null and body != self and not body.freeze:
			# Retrieve: what it touches is dragged back the way it came.
			body.apply_central_force((origin - body.global_position).normalized() * 900.0 * body.mass)


func _catch_boomerang(actor: Node2D) -> void:
	_active = false
	if not is_instance_valid(actor):
		drop_to_world(_world_root(), global_position)
		return
	equip_to(actor)


func _use_key(_actor: Node2D) -> String:
	for target in _reachable_targets():
		if target.has_method("try_unlock"):
			var result: Variant = target.call("try_unlock", "drawn_key", item_data)
			_handle_unlock_result(result)
			if result is Dictionary and bool(result.get("unlocked", false)):
				return "Unlocked"
	return "Key turns on nothing here"


## Gather/Pull: drags loose things toward the player instead of making them walk to
## every key and block.
func _rake_pull(actor: Node2D) -> String:
	var origin := _actor_position(actor)
	var pulled := 0
	for target in _reachable_targets(240.0):
		var body := target as RigidBody2D
		if body == null or body == self or body.freeze:
			continue
		var toward := origin - body.global_position
		if toward.length() < 24.0:
			continue
		body.apply_central_impulse(toward.normalized() * 260.0 * body.mass + Vector2(0.0, -70.0) * body.mass)
		pulled += 1
	return "Raked %d thing%s closer" % [pulled, "" if pulled == 1 else "s"] if pulled > 0 \
		else "Nothing within reach to pull"


## Crush: it leaves the hand and goes straight down, hard.
func _drop_anvil(actor: Node2D) -> String:
	var world := _world_root()
	if world == null:
		return ""
	var at := _actor_position(actor) + Vector2(_facing_of(actor) * 56.0, -120.0)
	drop_to_world(world, at)
	mass = maxf(mass, 6.0)
	gravity_scale = 3.4
	linear_velocity = Vector2(0.0, 900.0)
	angular_velocity = 0.0
	lock_rotation = true
	return "Anvil dropped"


## Freeze Time: everything loose nearby stops where it is for a few seconds. The
## player is deliberately exempt -- freezing yourself is not a mechanic.
func _freeze_time(_actor: Node2D) -> String:
	if _effect_time > 0.0:
		return "Time is already stopped"
	var frozen := 0
	for target in _reachable_targets(WEATHER_RADIUS):
		var body := target as RigidBody2D
		if body == null or body == self or body.freeze or _is_player_body(body):
			continue
		_held_bodies[body.get_instance_id()] = body
		body.freeze = true
		body.linear_velocity = Vector2.ZERO
		body.angular_velocity = 0.0
		frozen += 1
	if frozen == 0:
		return "Nothing moving to stop"
	_effect_time = CLOCK_FREEZE_SECONDS
	return "Time stopped for %d thing%s" % [frozen, "" if frozen == 1 else "s"]


func _release_frozen_bodies() -> void:
	for body_value in _held_bodies.values():
		var body := body_value as RigidBody2D
		if body != null and is_instance_valid(body):
			body.freeze = false
			body.sleeping = false
	_held_bodies.clear()


## Rain: puts water where there was none. The level already has a water medium that
## fish swim in and boats float on, so raining is spawning one of those.
func _make_rain(actor: Node2D) -> String:
	var world := _world_root()
	if world == null:
		return ""
	var pool := WaterArea2D.new()
	pool.surface_size = Vector2(260.0, 90.0)
	world.add_child(pool)
	pool.global_position = _actor_position(actor) + Vector2(_facing_of(actor) * 120.0, 60.0)
	return "Rain fills a pool"


## Evaporate: the counterpart, so a flooded route can be undone.
func _evaporate(actor: Node2D) -> String:
	var origin := _actor_position(actor)
	var dried := 0
	for node in get_tree().get_nodes_in_group("water_medium"):
		var pool := node as Node2D
		if pool != null and pool.global_position.distance_to(origin) <= WEATHER_RADIUS * 1.6:
			pool.queue_free()
			dried += 1
	return "Dried up %d pool%s" % [dried, "" if dried == 1 else "s"] if dried > 0 \
		else "Nothing here to dry out"


## Catch/Carry: full in water, empty anywhere else — water moved from one place to
## another by hand.
func _use_bucket(actor: Node2D) -> String:
	if not _carried_water:
		if not _actor_is_in_water(actor) and not _is_in_water():
			return "Bucket is empty — fill it in water"
		_carried_water = true
		return "Bucket filled"
	_carried_water = false
	return _make_rain(actor).replace("Rain fills", "Bucket empties into")


## Everything a tool could act on from where it is. Targets are resolved through
## _tool_target, so a Destructible2D that owns a body answers for that body -- the old
## code open-coded "or its parent" at each call site and only ever checked one level.
func _reachable_targets(reach: float = TOOL_REACH) -> Array[Node]:
	var found: Array[Node] = []
	var raw: Array = []
	if _interaction_area != null:
		raw.append_array(_interaction_area.get_overlapping_bodies())
		raw.append_array(_interaction_area.get_overlapping_areas())
	var shape := CircleShape2D.new()
	shape.radius = maxf(reach, _target_size().length() * 0.5)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 1
	query.collide_with_areas = true
	query.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 24):
		var collider: Variant = hit.get("collider")
		if collider is Node:
			raw.append(collider)
	for candidate in raw:
		var target := _tool_target(candidate as Node)
		if target != null and target != self and not found.has(target):
			found.append(target)
	return found


## The node that answers for a collider: the collider itself if it implements a tool
## contract, otherwise the nearest ancestor that does, otherwise the collider.
func _tool_target(collider: Node) -> Node:
	var node := collider
	while node != null:
		if node.has_method("apply_tool_hit") or node.has_method("try_unlock"):
			return node
		node = node.get_parent()
	return collider


func _world_root() -> Node2D:
	var node := get_parent()
	while node != null and not (node is Node2D):
		node = node.get_parent()
	return node as Node2D


func _actor_position(actor: Node2D) -> Vector2:
	if actor == null or not is_instance_valid(actor):
		return global_position
	if actor.has_method("get_physics_anchor"):
		var anchor := actor.call("get_physics_anchor") as Node2D
		if anchor != null:
			return anchor.global_position
	return actor.global_position


## Which way the player is pointing, taken from how they are moving and falling back
## to the tool's own side of them. A tool has to swing somewhere.
func _facing_of(actor: Node2D) -> float:
	var axis := Input.get_axis("move_left", "move_right")
	if absf(axis) > 0.05:
		return signf(axis)
	var offset := global_position.x - _actor_position(actor).x
	return signf(offset) if absf(offset) > 1.0 else 1.0


func _push_actor(actor: Node2D, acceleration: Vector2) -> void:
	if actor != null and is_instance_valid(actor) and actor.has_method("apply_external_force"):
		actor.call("apply_external_force", acceleration)


func _push_actor_impulse(actor: Node2D, velocity_change: Vector2) -> void:
	if actor != null and is_instance_valid(actor) and actor.has_method("apply_external_impulse"):
		actor.call("apply_external_impulse", velocity_change)


func _is_player_body(body: Node) -> bool:
	var node := body
	while node != null:
		if node.is_in_group(&"player_character") or node is ActiveRagdollMorph:
			return true
		node = node.get_parent()
	return false


func _actor_is_in_water(actor: Node2D) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	if actor.has_method("is_in_water"):
		return bool(actor.call("is_in_water"))
	var origin := _actor_position(actor)
	for node in get_tree().get_nodes_in_group("water_medium"):
		var pool := node as WaterArea2D
		if pool != null and Rect2(pool.global_position - pool.surface_size * 0.5, pool.surface_size).has_point(origin):
			return true
	return false


func _circle_points(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in range(12):
		var angle := TAU * float(step) / 12.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _handle_unlock_result(result: Variant) -> void:
	if result is Dictionary and bool(result.get("consumed", false)):
		if _equipped_actor != null and is_instance_valid(_equipped_actor) and _equipped_actor.has_method("set_equipped_utility"):
			_equipped_actor.call("set_equipped_utility", null)
		utility_consumed.emit(self)


func _board_actor(actor: Node2D) -> void:
	_unboard_actor()
	var anchor := actor.call("get_physics_anchor") as RigidBody2D if actor.has_method("get_physics_anchor") else null
	var seat_position := global_position + Vector2(0.0, -_target_size().y * 0.25).rotated(global_rotation)
	if anchor == null:
		# The player is not a rigid body -- the wanderer is a CharacterBody2D, and it is
		# who the player IS until they draw an animal. Refusing to board it meant the
		# boat was unusable for most of a first playthrough. Carry them instead of
		# pinning them; _seat_carried_actor keeps them aboard.
		_boarded_actor = actor
		actor.global_position = seat_position
		_ignore_collisions_with(actor, true)
		if actor.has_method("begin_ride"):
			actor.call("begin_ride", self)
		utility_used.emit(utility_behavior, item_data)
		return
	_boarded_actor = actor
	_ignore_collisions_with(actor, true)
	if actor.has_method("begin_ride"):
		actor.call("begin_ride", self)
	if actor.has_method("apply_morph_state"):
		actor.call("apply_morph_state", {
			"position": seat_position,
			"linear_velocity": linear_velocity,
			"rotation": global_rotation,
			"angular_velocity": angular_velocity
		})
	_vehicle_joint = PinJoint2D.new()
	_vehicle_joint.name = "BoardingJoint"
	_vehicle_joint.global_position = seat_position
	get_parent().add_child(_vehicle_joint)
	_vehicle_joint.node_a = _vehicle_joint.get_path_to(self)
	_vehicle_joint.node_b = _vehicle_joint.get_path_to(anchor)
	_vehicle_joint.disable_collision = true
	utility_used.emit(utility_behavior, item_data)


## Holds a non-rigid passenger on the deck. A pinned rigid rider is held by its joint;
## a CharacterBody2D has to be put there, because nothing else will move it.
func _seat_carried_actor() -> void:
	if _vehicle_joint != null and is_instance_valid(_vehicle_joint):
		return
	if _boarded_actor == null or not is_instance_valid(_boarded_actor):
		return
	_boarded_actor.global_position = global_position \
		+ Vector2(0.0, -_target_size().y * 0.25).rotated(global_rotation)


## A passenger is cargo, not an obstacle. The seat is inside the hull and the rider is
## force-placed there every frame, so with both on the same collision layer the solver
## saw a body teleporting into the boat and blew them apart -- which is where the hull's
## impossible speed came from AND why the rider ended up somewhere else. It was one
## fault presenting as two, and no amount of clamping the velocity would have fixed
## either, because the clamp was never the thing being outrun.
func _ignore_collisions_with(actor: Node2D, ignore: bool) -> void:
	var body := actor as PhysicsBody2D
	if body == null:
		return
	if ignore:
		add_collision_exception_with(body)
		body.add_collision_exception_with(self)
	else:
		remove_collision_exception_with(body)
		body.remove_collision_exception_with(self)


func _unboard_actor() -> void:
	if _boarded_actor != null and is_instance_valid(_boarded_actor):
		_ignore_collisions_with(_boarded_actor, false)
	if _boarded_actor != null and is_instance_valid(_boarded_actor) \
		and _boarded_actor.has_method("end_ride"):
		_boarded_actor.call("end_ride")
	_boarded_actor = null
	if _vehicle_joint != null and is_instance_valid(_vehicle_joint):
		_vehicle_joint.queue_free()
	_vehicle_joint = null


func _create_interaction_area() -> void:
	_interaction_area = Area2D.new()
	_interaction_area.name = "InteractionArea"
	_interaction_area.collision_layer = 0
	_interaction_area.collision_mask = 1
	_interaction_area.monitoring = true
	add_child(_interaction_area)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = _target_size() + Vector2(72.0, 72.0)
	collision.shape = shape
	_interaction_area.add_child(collision)


func _create_flashlight_nodes() -> void:
	_light_cone = Polygon2D.new()
	_light_cone.name = "VisibleLightCone"
	_light_cone.polygon = PackedVector2Array([
		Vector2(20.0, -8.0), Vector2(230.0, -92.0),
		Vector2(230.0, 92.0), Vector2(20.0, 8.0)
	])
	_light_cone.color = Color(1.0, 0.92, 0.55, 0.22)
	_light_cone.z_index = -1
	add_child(_light_cone)
	_point_light = PointLight2D.new()
	_point_light.name = "LightCone"
	_point_light.texture = _make_cone_texture()
	_point_light.texture_scale = 1.2
	_point_light.energy = 1.25
	_point_light.position = Vector2(96.0, 0.0)
	add_child(_point_light)
	_set_light_active(_active)


func _make_cone_texture() -> ImageTexture:
	var image := Image.create(256, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for x in range(128, 256):
		var ratio := float(x - 128) / 128.0
		var half_height := 6.0 + ratio * 56.0
		for y in range(64 - int(half_height), 64 + int(half_height) + 1):
			var edge := absf(float(y - 64)) / maxf(1.0, half_height)
			var alpha := (1.0 - edge) * (1.0 - ratio * 0.7)
			image.set_pixel(x, y, Color(1.0, 0.94, 0.68, alpha))
	return ImageTexture.create_from_image(image)


func _set_light_active(enabled: bool) -> void:
	if _light_cone != null:
		_light_cone.visible = enabled
	if _point_light != null:
		_point_light.enabled = enabled


func _is_in_water() -> bool:
	return int(get_meta("water_overlap_count", 0)) > 0
