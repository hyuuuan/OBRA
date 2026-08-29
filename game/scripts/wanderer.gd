class_name Wanderer
extends CharacterBody2D
## The player character: who the journey belongs to, and what a drawn animal replaces.
##
## DELIBERATELY A PLACEHOLDER. It is drawn in code from a handful of primitives rather
## than from art, so it can be thrown away whole when the real design lands without
## anything else having to change. What is NOT placeholder is the interface: the level
## talks to whoever is the player through get_physics_anchor / get_camera_target /
## capture_morph_state / set_world_bounds, and a drawn creature answers exactly the
## same calls. That is what lets the two swap.
##
## It is a CharacterBody2D and not a ragdoll on purpose. The morphs are ragdolls
## because they are the player's own drawing and have to keep its shape; the wanderer
## has no drawing to preserve, and a character controller is what makes it reliable to
## walk around with while everything else is being built.

const SPEED := 260.0
const ACCELERATION := 1800.0
const FRICTION := 2200.0
const JUMP_VELOCITY := -430.0
const MAX_FALL := 900.0

## Platformer forgiveness. None of these change how high the jump goes -- the peak is
## still JUMP_VELOCITY^2 / 2g = 94.3px, which is what every gate in Level 1 is measured
## against and what run_level1_audit asserts the 108px stair against.
##
## They change how easy it is to GET that jump. Before them, the jump fired only on the
## exact frame the key went down while is_on_floor() was true: press a frame early and
## nothing happened, walk off a lip and nothing happened. On a level whose first gate is
## 108px against 94.3px, every dropped input is felt as the character not obeying.
const COYOTE_TIME := 0.10
const JUMP_BUFFER_TIME := 0.12
## How much of the rise survives letting go of the button early, so a tap is a hop and a
## hold is a full jump. It can only ever make the jump shorter.
const JUMP_CUT := 0.45

## How fast the walk cycle plays, in cycles per second at full speed.
const STRIDE_HZ := 2.2
## Above this share of SPEED the character is running rather than walking. Placed so the
## acceleration ramp is visible -- set it near 1.0 and the walk cycle never plays, set it
## near 0 and the run cycle is the only one anybody sees.
const RUN_FRACTION := 0.72

## Climbing a drawn ladder. Slower than walking, and sideways movement is throttled so
## stepping off is deliberate rather than something that happens while aiming upward.
const CLIMB_SPEED := 190.0
const CLIMB_DRIFT := 0.35
## How far from the ladder you can get before you are no longer on it.
const CLIMB_RELEASE := 120.0
## How far past the top of a ladder the climb keeps working, so the player can get their
## feet above the last rung and step off onto whatever they climbed up to.
const CLIMB_OVERSHOOT := 40.0
## An open umbrella is a parachute you are holding.
const UMBRELLA_FALL_LIMIT := 190.0

## Wading. Deep water is meant to stop a walker, so it costs most of your speed, pulls
## you steadily down, and leaves you barely able to jump out of it.
const WADE_DRAG := 0.55
const WADE_SINK := 0.42
const WADE_SINK_SPEED := 120.0
## All a jump gets you in water: a kick far weaker than the sink rate. THE APO CANNOT
## SWIM, and that has to be true of every jump, not most of them.
##
## This is what made water free. The old kick was -193px/s against a sink capped at 120,
## so a player who held jump ROSE, and holding jump while walking right carried them over
## the surface of a paddy as if it were a floor -- both paddies in Level 1 are 300px of
## water and both were being walked across.
##
## An earlier version of this fix gave a strong jump when is_on_floor() was true, on the
## reasoning that you can push off the bottom. It turned the floating tread into a
## launchpad: standing on it counts as standing on a floor, and a full-strength jump from
## the middle of the paddy cleared the far bank. There is no version of "sometimes you can
## jump properly in water" that does not hand the player a way across.
const WADE_KICK := 55.0

@onready var _figure: Node2D = $Figure

var world_bounds := Rect2(0.0, -520.0, 3760.0, 1200.0)

var _gravity: float = 980.0
var _phase: float = 0.0
var _facing: float = 1.0
var _carrying := ""
## Outside forces, in acceleration and in velocity, both cleared every physics frame.
var _assist := Vector2.ZERO
var _impulse := Vector2.ZERO
## Seconds of grace left after walking off an edge, and how long a jump pressed in the air
## keeps waiting for the ground.
var _coyote_left := 0.0
var _jump_buffered := 0.0
var _fall_limit := MAX_FALL
## The rest of the contract the utilities call on whoever the player is. None of this
## was answered before, so for the character the player actually starts as, a drawn
## ladder was scenery and a drawn umbrella did nothing.
var _ladder: Node2D = null
## How tall the ladder in hand is, measured from its own collision when it is taken hold
## of. A ladder is a thing with a top; without this, climbing had no end.
var _ladder_half_height := 0.0
var _vehicle: Node2D = null
var _equipped_utility: Node2D = null
var _umbrella_open := false
var _grip: Marker2D = null


## One jump, from wherever it was allowed. Spends both the buffer and the grace so a
## single press cannot be cashed twice on the way up.
func _jump() -> void:
	velocity.y = JUMP_VELOCITY
	_jump_buffered = 0.0
	_coyote_left = 0.0


## How fast you have to be coming down before a landing throws real dust, and the speed at
## which it throws all of it. Below the floor a hop off a kerb would kick up a cloud.
const LAND_DUST_FLOOR := 240.0
const LAND_DUST_FULL := 900.0
## How far she walks between footfalls. MEASURED IN DISTANCE, not in time: dust that arrives
## on a timer keeps coming while she is standing against a wall pushing into it.
const STEP_DUST_STRIDE := 46.0

var _stride_dust := 0.0


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	add_to_group(&"player_character")


## WHAT THE GROUND SAYS BACK. Dust off the heel every stride, and a cloud when a fall lands.
##
## The apo moved across Payyo without the world acknowledging any of it -- and she has a
## six-frame run and a jump pose, so the character was animating against scenery that never
## admitted she was touching it. This is the cheapest half of that fixed: it costs one
## self-freeing node per footfall and it is the difference between walking on the terrace and
## sliding over a picture of one.
##
## Nothing here happens in water: a splash is the paddy's business, and it already knows.
func _leave_a_mark(delta: float, was_airborne: bool, fall_speed: float) -> void:
	if is_in_water() or _riding():
		_stride_dust = 0.0
		return
	var host := get_parent() as Node2D
	if host == null:
		return
	var feet := global_position
	if was_airborne and is_on_floor() and fall_speed > LAND_DUST_FLOOR:
		var force := clampf((fall_speed - LAND_DUST_FLOOR)
			/ (LAND_DUST_FULL - LAND_DUST_FLOOR), 0.2, 1.0)
		SceneryPuff2D.burst(host, feet, SceneryPuff2D.Kind.LAND, force)
		_stride_dust = 0.0
		return
	if not is_on_floor():
		_stride_dust = 0.0
		return
	_stride_dust += absf(velocity.x) * delta
	if _stride_dust < STEP_DUST_STRIDE:
		return
	_stride_dust = 0.0
	# Behind the heel rather than under the middle of her, and scaled by how fast she is
	# going, so a walk scuffs and a run kicks.
	var force := clampf(absf(velocity.x) / SPEED, 0.2, 1.0)
	SceneryPuff2D.burst(host, feet - Vector2(_facing * 9.0, 0.0),
		SceneryPuff2D.Kind.STEP, force * 0.55)


func _physics_process(delta: float) -> void:
	_coyote_left = COYOTE_TIME if is_on_floor() else maxf(0.0, _coyote_left - delta)
	if Input.is_action_just_pressed(&"jump"):
		_jump_buffered = JUMP_BUFFER_TIME
	else:
		_jump_buffered = maxf(0.0, _jump_buffered - delta)

	var direction := Input.get_axis(&"move_left", &"move_right")
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)
		_facing = signf(direction)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	if _riding():
		# A passenger does not walk. The vehicle puts us where it is going, and our own
		# locomotion would otherwise carry us straight off the deck -- which is exactly
		# what a boat "leaving the player behind" was.
		velocity = Vector2.ZERO
		if Input.is_action_just_pressed(&"jump"):
			end_ride()
			_jump()
		_advance_stride(delta, 0.0)
		return
	if _climbing():
		# On a ladder the whole point is that gravity is not the thing deciding where
		# you go. Up and down drive directly; sideways is throttled so stepping off is
		# something you mean rather than something that happens while aiming upward.
		velocity.y = Input.get_axis(&"move_up", &"move_down") * CLIMB_SPEED
		velocity.x = direction * SPEED * CLIMB_DRIFT
		if Input.is_action_just_pressed(&"jump"):
			end_ladder()
			_jump()
	elif is_in_water():
		# WADING, NOT WALKING. Water used to be scenery you strolled through at full
		# speed, which made a drawn boat pointless and a swimmer morph a novelty. It
		# drags now, and it pulls you down: you can cross a shallow paddy on foot and
		# you cannot cross deep water, which is the whole reason to draw something that
		# floats or something that swims.
		velocity.x *= WADE_DRAG
		velocity.y = minf(velocity.y + _gravity * WADE_SINK * delta, WADE_SINK_SPEED)
		if Input.is_action_just_pressed(&"jump"):
			# The press is still spent: wading out of a paddy must not also cash a full jump
			# the moment a foot touches the bank.
			_jump_buffered = 0.0
			velocity.y = -WADE_KICK
	elif is_on_floor():
		# Buffered, so a press that arrived a few frames before landing still counts.
		if _jump_buffered > 0.0:
			_jump()
	elif _jump_buffered > 0.0 and _coyote_left > 0.0:
		# Coyote time: the ground was there a moment ago, and a player who pressed jump
		# as they ran off the lip meant to jump.
		_jump()
	else:
		if _umbrella_open:
			_fall_limit = minf(_fall_limit, UMBRELLA_FALL_LIMIT)
		velocity.y = minf(velocity.y + (_gravity + _assist.y) * delta, _fall_limit)
	# Let go early and the rise is cut short. Only ever downward, so the 94.3px peak
	# stands as the maximum rather than becoming a new minimum.
	if Input.is_action_just_released(&"jump") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT
	velocity.x += _assist.x * delta
	velocity += _impulse
	_impulse = Vector2.ZERO
	# One frame's worth. A utility that means it re-applies every frame, which is what
	# makes a parachute stop lifting the moment it is folded away.
	_assist = Vector2.ZERO
	_fall_limit = MAX_FALL

	var falling := velocity.y
	var airborne := not is_on_floor()
	move_and_slide()
	_leave_a_mark(delta, airborne, falling)
	# Keep it inside the level rather than letting it walk off the end of the world.
	global_position.x = clampf(global_position.x, world_bounds.position.x, world_bounds.end.x)
	if global_position.y > world_bounds.end.y:
		global_position = Vector2(global_position.x, world_bounds.position.y)
		velocity = Vector2.ZERO

	_advance_stride(delta, velocity.x)


## The stride advances with actual speed, so it cannot look like it is running on the
## spot while sliding to a stop -- or while sitting still on a boat.
func _advance_stride(delta: float, horizontal_speed: float) -> void:
	var moving := absf(horizontal_speed) > 12.0
	_phase += delta * STRIDE_HZ * (absf(horizontal_speed) / SPEED if moving else 0.0)
	_figure.scale.x = _facing
	_figure.set(&"pose", _pose_for(horizontal_speed))
	_figure.set(&"stride", _phase)
	_figure.set(&"carrying", _carrying)
	_figure.call(&"refresh")


## Which drawing of the character to show. Written here and not in the figure because
## every fact it needs -- on a ladder, in the air, in the water, riding something, how
## fast -- is already known here, and asking the art to work it out again from a position
## and a velocity is how the two end up disagreeing.
func _pose_for(horizontal_speed: float) -> StringName:
	if _climbing():
		return &"climb"
	# OFF THE GROUND BEATS MOVING, and this test has to come first.
	#
	# It used to sit under the speed check, which meant it only ever ran when the player was
	# standing still -- and nobody jumps standing still. Every jump in the game is taken at a
	# run, so the pose stayed on the walk cycle the whole way up and down and the apo crossed
	# the gap paddling his legs, which is what "hovering while jumping" was. The one case the
	# old order got right was the vertical hop, which is the case players never do.
	if not is_on_floor() and not is_in_water() and not _riding() and not _climbing():
		return &"air"
	var speed := absf(horizontal_speed)
	# Riding is standing on something that is moving. The deck carries the player, so the
	# hull's speed is not theirs and a walk cycle here is running on the spot.
	if not _riding() and speed > 12.0:
		# Both cycles get used. There is one SPEED in this game, but there is also an
		# acceleration ramp up to it, so setting off reads as a walk that breaks into a
		# run -- which is what the artist drew two cycles for.
		return &"run" if speed > SPEED * RUN_FRACTION else &"walk"
	# Standing still, and only then, the look poses. Held while moving they would fight
	# the walk cycle for the same frames.
	if Input.is_action_pressed(&"move_up"):
		return &"look_up"
	if Input.is_action_pressed(&"move_down"):
		return &"look_down"
	return &"idle"


# --- the contract every player answers ---------------------------------------

## A utility pushing on the player: an acceleration held for one frame. A fan, a
## parachute's drag, a balloon's lift all arrive here and are re-applied every frame
## for as long as the utility is doing it. Drawn creatures answer the same call by
## pushing their whole rig, so an effect feels identical whoever the player is --
## which matters because the wanderer is who the player IS until they draw an animal.
func apply_external_force(acceleration: Vector2) -> void:
	_assist += acceleration


## An instant velocity change: a cannon's recoil.
func apply_external_impulse(velocity_change: Vector2) -> void:
	_impulse += velocity_change


## Caps how fast the player may fall this frame. A parachute is mostly this.
func limit_fall_speed(limit: float) -> void:
	_fall_limit = minf(_fall_limit, maxf(0.0, limit))


## Where a held tool sits: the forward hand, so an equipped axe is in a hand rather
## than at the character's feet. equip_to falls back to the actor itself when this is
## missing, which is why every tool used to hang off the wanderer's origin.
func get_grip_anchor() -> Node2D:
	if _grip == null or not is_instance_valid(_grip):
		_grip = Marker2D.new()
		_grip.name = "GripAnchor"
		add_child(_grip)
	_grip.position = Vector2(14.0 * _facing, -48.0)
	return _grip


func set_equipped_utility(utility: Node2D) -> void:
	_equipped_utility = utility
	if utility == null:
		_umbrella_open = false


## Riding a drawn vehicle. Same shape as the ladder: the thing you are on takes over
## where you go, and you get off deliberately.
func begin_ride(vehicle: Node2D) -> void:
	_vehicle = vehicle


func end_ride() -> void:
	_vehicle = null


func is_riding(vehicle: Node2D = null) -> bool:
	if _vehicle == null or not is_instance_valid(_vehicle):
		_vehicle = null
		return false
	return vehicle == null or vehicle == _vehicle


func _riding() -> bool:
	return is_riding()


func begin_ladder(ladder: Node2D) -> void:
	_ladder = ladder
	_ladder_half_height = _measure_half_height(ladder)
	# You climb THROUGH a ladder, not beside it. A placed ladder freezes into a solid body,
	# so without this the player was pressed against its face the whole way up and could
	# never step off at the top -- which made a ladder leaned against a cliff a wall with
	# rungs.
	var body := ladder as PhysicsBody2D
	if body != null:
		add_collision_exception_with(body)


func end_ladder() -> void:
	var body := _ladder as PhysicsBody2D
	if body != null and is_instance_valid(body):
		remove_collision_exception_with(body)
	_ladder = null


func is_using_ladder(ladder: Node2D) -> bool:
	return _ladder == ladder


func set_umbrella_open(is_open: bool) -> void:
	_umbrella_open = is_open


## WaterArea2D tags the bodies inside it, so this is the same answer a drawn creature
## gives -- a boat asking "is my passenger in the water" gets a real reply either way.
func is_in_water() -> bool:
	return int(get_meta("water_overlap_count", 0)) > 0


## Letting go of a ladder by walking away from it, rather than only by pressing E again.
## A ladder you can drift off and still be silently attached to is a ladder that eats
## the next jump.
func _climbing() -> bool:
	if _ladder == null or not is_instance_valid(_ladder):
		_ladder = null
		return false
	# Measured HORIZONTALLY, and generously: a ladder is a tall thing whose origin sits
	# at its middle, so a straight distance check released the player the moment they
	# had climbed a bit of it -- which read as the ladder simply not working.
	var ladder := _ladder as Node2D
	if absf(global_position.x - ladder.global_position.x) > CLIMB_RELEASE:
		end_ladder()
		return false
	# AND vertically, past its top. The horizontal-only check meant holding up on a ladder
	# raised the player forever: place one anywhere, climb into the sky, walk over every
	# gate in the level. A ladder reaches as far as a ladder reaches.
	if global_position.y < ladder.global_position.y - _ladder_half_height - CLIMB_OVERSHOOT:
		end_ladder()
		return false
	return true


## The ladder's own vertical half-extent, from whatever collision it carries.
func _measure_half_height(ladder: Node2D) -> float:
	var half := 0.0
	for child in ladder.get_children():
		var collision := child as CollisionShape2D
		if collision == null or collision.shape == null:
			continue
		var reach := absf(collision.position.y)
		if collision.shape is RectangleShape2D:
			reach += (collision.shape as RectangleShape2D).size.y * 0.5
		elif collision.shape is CapsuleShape2D:
			reach += (collision.shape as CapsuleShape2D).height * 0.5
		else:
			reach += CLIMB_RELEASE
		half = maxf(half, reach)
	return half if half > 0.0 else CLIMB_RELEASE


func set_world_bounds(bounds: Rect2) -> void:
	world_bounds = bounds


## The morphs return a rigid body here; the level only ever reads its position, so a
## plain node is a valid answer.
func get_physics_anchor() -> Node2D:
	return self


func get_camera_target() -> Node2D:
	return self


## Carried across a morph so the drawn creature appears where the wanderer stood
## rather than back at the spawn point.
func capture_morph_state() -> Dictionary:
	return {
		"position": global_position,
		"velocity": velocity,
		"facing": _facing,
	}


func apply_morph_state(state: Dictionary) -> void:
	if state.has("position"):
		global_position = state["position"]
	if state.has("velocity"):
		velocity = state["velocity"]
	elif state.has("linear_velocity"):
		# The two players describe the same thing with different words. A drawn creature is
		# a rigid body and calls its momentum linear_velocity; this read only "velocity",
		# which did not matter while the swap only ever went wanderer -> creature. Changing
		# BACK goes the other way, and without this a player who pressed Q mid-leap landed
		# in the right place with every bit of their speed silently thrown away.
		var inherited := Vector2(state["linear_velocity"])
		# Capped for the same reason PlayableEntity caps it: a diving bird moves far faster
		# than a walker ever does, and inheriting all of that is a launch, not a landing.
		velocity = inherited.limit_length(520.0) \
			if is_finite(inherited.x) and is_finite(inherited.y) else Vector2.ZERO
	if state.has("facing"):
		_facing = float(state["facing"])
	elif absf(velocity.x) > 1.0:
		# A drawn creature has no notion of facing at all -- PlayableEntity never reports
		# one -- so a revert carries no "facing" key and the wanderer kept whichever way it
		# was last pointed, which is right by default. A player running left as a horse
		# turned around on the spot the moment they changed back. The direction they were
		# actually travelling is the honest answer. Guarded above zero because signf(0)
		# is 0, and _facing scales the figure: a zero would make it vanish.
		_facing = signf(velocity.x)


## Show an item in the character's hand. The level calls this when a utility is
## equipped, so what the player is holding is visible on the character rather than
## only in a status line that has already scrolled away.
func set_carried(entity_id: String) -> void:
	_carrying = entity_id
	if _figure != null:
		_figure.queue_redraw()


## Phase of the stride, so the morph flash can start from the pose it was standing in.
func stride_phase() -> float:
	return _phase
