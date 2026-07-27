class_name GaitDriver
extends RefCounted
## Turns a skeleton's authored gait into bone angles and whole-body motion.
##
## Stages 0 and 1 made anatomy a LOOKUP and made deformation safe; neither of them
## moves anything. This is the piece that does, and it is deliberately the only place
## that decides how a creature animates. Everything it needs is authored beside the
## bones in skeletons.json -- amplitude, phase, mirroring, per-state weighting, gait
## frequency, bob/tilt/squash -- so tuning a class is editing data, not editing code.
##
## Named amplitudes resolve against the entity's rigs/<id>.json. That is what finally
## gives the ~25 profile fields (wing_flap_degrees, flap_cycle_hz, walk_bob, ...) an
## effect: until now they were written, loaded, and read by nothing.
##
## The plan is resolved ONCE, when the skeleton is bound, into flat arrays. Per frame
## this is then pure arithmetic over those arrays, with no dictionary lookups and no
## allocation, because it runs for every creature on screen at 60 Hz.

## States in which a creature animates even though `moving` is false -- it is in the
## air, and a bird that stops flapping mid-flight reads as a bug.
const AIRBORNE_STATES := ["jump", "fall", "fly", "flap", "glide", "swim"]

## Gait speed relative to the authored frequency: a slow idle tick, and a moving
## range that stretches with speed_ratio so a run reads faster than a walk.
const IDLE_RATE_SCALE := 0.35
const MOVING_RATE_MIN := 0.7
const MOVING_RATE_MAX := 1.5

## Bob and squash run at twice the limb frequency: two footfalls per stride, two
## lifts per wingbeat.
const BODY_BEAT := 2.0

## Angle smoothing. The sinusoid is already continuous; this exists so that a CHANGE
## OF STATE eases in. Snapping the amplitude when walk becomes idle is a visible pop.
const ANGLE_RESPONSE := 12.0

## Lean added by jump/fall on top of the directional lean.
const AIR_PITCH_DEG := 4.0

var _rig: Skeleton2D_Rig = null
var _phase: float = 0.0

# --- resolved plan, one entry per bone -------------------------------------
var _amplitude := PackedFloat32Array()     ## radians, before the state weight
var _bias := PackedFloat32Array()          ## radians, a static pose offset
var _phase_offset := PackedFloat32Array()  ## cycles
var _sign := PackedFloat32Array()          ## +1, or the bone's side when mirrored
var _limit := PackedFloat32Array()         ## radians
var _states: Array = []                    ## Dictionary per bone; empty == always on
var _angles := PackedFloat32Array()

# --- resolved whole-body motion --------------------------------------------
var _frequency_hz: float = 0.0
var _bob_px: float = 0.0
var _tilt_rad: float = 0.0
var _squash: float = 0.0
var _cancel_anchor: bool = false
var _root_pivot := Vector2.ZERO

# --- current motion ---------------------------------------------------------
var _state: String = "idle"
var _moving: bool = false
var _active: bool = false
var _speed: float = 0.0
var _direction: float = 0.0
## Eased whole-body motion, so coming to rest does not snap the drawing.
var _bob: float = 0.0
var _tilt: float = 0.0
var _squash_now: float = 0.0


## Resolve `rig`'s authored gait against `profile` (the entity's rigs/<id>.json).
## Call once per bind; `advance` is then cheap.
func prepare(rig: Skeleton2D_Rig, profile: Dictionary) -> void:
	_rig = rig
	_phase = 0.0
	_bob = 0.0
	_tilt = 0.0
	_squash_now = 0.0
	var count := rig.bones.size() if rig != null else 0
	_amplitude.resize(count)
	_bias.resize(count)
	_phase_offset.resize(count)
	_sign.resize(count)
	_limit.resize(count)
	_angles.resize(count)
	_states.clear()
	_states.resize(count)
	if rig == null:
		return

	_frequency_hz = maxf(0.0, rig.frequency_hz)
	var motion := rig.body_motion
	_bob_px = _resolved(motion, "bob_key", "bob_px", profile, 0.0)
	_tilt_rad = deg_to_rad(_resolved(motion, "tilt_key", "tilt_deg", profile, 0.0))
	_squash = _resolved(motion, "squash_key", "squash", profile, 0.0)
	_cancel_anchor = bool(motion.get("cancel_anchor_rotation", false))
	_root_pivot = rig.bones[0].pivot if count > 0 else Vector2.ZERO

	for index in range(count):
		var bone := rig.bones[index]
		var gait: Dictionary = bone.gait
		_limit[index] = bone.limit
		_angles[index] = 0.0
		if gait.is_empty():
			_amplitude[index] = 0.0
			_bias[index] = 0.0
			_phase_offset[index] = 0.0
			_sign[index] = 1.0
			_states[index] = {}
			continue
		_amplitude[index] = deg_to_rad(_resolved(gait, "amplitude_key", "amplitude_deg", profile, 0.0))
		_bias[index] = deg_to_rad(_resolved(gait, "bias_key", "bias_deg", profile, 0.0))
		_phase_offset[index] = float(gait.get("phase", 0.0))
		# `mirror` makes a pair beat symmetrically: the two bones point opposite ways,
		# so opposite rotation signs are what reads as the SAME motion mirrored. A bone
		# with no side cannot mirror, and must not be silently frozen by a zero sign.
		var mirrored := bool(gait.get("mirror", false)) and bone.side != 0.0
		_sign[index] = bone.side if mirrored else 1.0
		_states[index] = gait.get("states", {})


## Step the gait by `delta` under the given motion, and recompute the bone angles.
func advance(delta: float, state: String, params: Dictionary) -> void:
	if _rig == null:
		return
	_state = state
	_moving = bool(params.get("moving", false))
	_active = _moving or state in AIRBORNE_STATES
	_speed = clampf(float(params.get("speed_ratio", 0.0)), 0.0, 1.5)
	_direction = clampf(float(params.get("direction", 0.0)), -1.0, 1.0)

	var rate := _frequency_hz * (lerpf(MOVING_RATE_MIN, MOVING_RATE_MAX, minf(1.0, _speed)) \
		if _active else IDLE_RATE_SCALE)
	_phase = fposmod(_phase + delta * rate, 1.0)

	var weight := 1.0 - exp(-ANGLE_RESPONSE * maxf(0.0, delta))
	for index in range(_angles.size()):
		var swing := _amplitude[index] * _state_weight(index) \
			* sin(TAU * (_phase + _phase_offset[index]))
		var offset := _bias[index] * _bias_weight(index)
		var target := clampf((swing + offset) * _sign[index], -_limit[index], _limit[index])
		_angles[index] = lerpf(_angles[index], target, weight)

	# Whole-body motion is eased on the same curve as the bones, and for the same
	# reason: a creature that stops walking drops its bob to zero in one frame
	# otherwise, and the drawing visibly jumps at the moment it comes to rest.
	var bob_target := 0.0
	var tilt_target := 0.0
	var squash_target := 0.0
	if _active:
		bob_target = -absf(sin(TAU * _phase * BODY_BEAT)) * _bob_px
		tilt_target = _tilt_rad * _direction * minf(1.0, _speed)
		squash_target = _squash * sin(TAU * _phase * BODY_BEAT)
	if _state == "jump":
		tilt_target -= deg_to_rad(AIR_PITCH_DEG)
	elif _state == "fall":
		tilt_target += deg_to_rad(AIR_PITCH_DEG)
	_bob = lerpf(_bob, bob_target, weight)
	_tilt = lerpf(_tilt, tilt_target, weight)
	_squash_now = lerpf(_squash_now, squash_target, weight)


## Per-bone local rotation, for Skeleton2D_Rig.pose.
func angles() -> PackedFloat32Array:
	return _angles


## Whole-body bob, lean and squash, as the `root_extra` the pose flows through.
##
## Deliberately NOT a transform on the node holding the ink: scaling a Node2D scales
## its Line2D widths with it, so a squashing creature's outline would visibly thicken
## and thin. Carrying it here deforms the ink's POSITIONS only, and the drawn line
## keeps the weight the player drew it with.
##
## `anchor_rotation` is the physics torso's rotation and `anchor_local` is that
## torso's origin in rig space. A walker's torso is upright by lock_rotation, but a
## flier's and a swimmer's are free to tumble, and the drawing hangs off them -- so
## those archetypes ask for it to be cancelled out and the creature reads the way it
## was drawn, keeping only its deliberate lean. The cancellation turns about the
## torso's own origin because that is the point the ink was rotated around; undoing
## it about anything else would leave the creature upright but swinging on an arc.
func body_transform(anchor_rotation: float = 0.0, anchor_local: Vector2 = Vector2.ZERO) -> Transform2D:
	if _rig == null:
		return Transform2D.IDENTITY
	var bob := _bob
	var scale_y := 1.0 + _squash_now
	var scale_x := 1.0 - _squash_now * 0.5
	var cosine := cos(_tilt)
	var sine := sin(_tilt)
	var basis := Transform2D(
		Vector2(cosine, sine) * scale_x,
		Vector2(-sine, cosine) * scale_y,
		Vector2.ZERO
	)
	# About the root bone's pivot, not the rig-space origin -- the creature leans on
	# its own body, and rotating about a distant origin would swing it off screen.
	var motion := Transform2D(0.0, _root_pivot + Vector2(0.0, bob)) * basis \
		* Transform2D(0.0, -_root_pivot)
	if not _cancel_anchor:
		return motion
	return Transform2D(0.0, anchor_local) * Transform2D(-anchor_rotation, Vector2.ZERO) \
		* Transform2D(0.0, -anchor_local) * motion


## Cycles elapsed, wrapped to [0, 1). Exposed for the tests and debug readouts.
func phase() -> float:
	return _phase


# --- internals ---------------------------------------------------------------

## How much of its amplitude a bone uses in the current state. An unlisted state means
## the author did not give this bone a motion for it, so it holds its idle pose rather
## than inventing one -- a bird's wings do not walk-cycle.
func _state_weight(index: int) -> float:
	var states: Dictionary = _states[index]
	if states.is_empty():
		return 1.0
	if states.has(_state):
		return float(states[_state])
	return float(states.get("idle", 0.0))


## How much of its bias a bone holds. Scaled with the state, so an idle creature sits
## in the pose it was DRAWN in -- a frog whose legs fold 26 degrees to launch must not
## be standing folded the moment it is created, or it is no longer the player's
## drawing at rest, which is the one thing the whole rig is built to guarantee.
##
## With one exception, and it is the reason bias exists at all: a state the author
## listed with NO swing is a hold, not an absence. Gliding is authored as wings that
## do not beat; what they do instead is sit at glide_raise_degrees. So a listed zero
## means the bias IS the pose for that state, and applies in full.
func _bias_weight(index: int) -> float:
	var states: Dictionary = _states[index]
	if states.is_empty():
		return 1.0
	if states.has(_state):
		var weight := float(states[_state])
		return 1.0 if is_zero_approx(weight) else weight
	return float(states.get("idle", 0.0))


## A value that may be named in the profile (`<field>_key`) or given inline. The named
## form wins when the profile defines it, so a per-entity rig file retunes a shared
## archetype without copying the skeleton.
static func _resolved(
	source: Dictionary,
	key_field: String,
	inline_field: String,
	profile: Dictionary,
	fallback: float
) -> float:
	var value := float(source.get(inline_field, fallback))
	if source.has(key_field):
		value = float(profile.get(String(source[key_field]), value))
	return value
