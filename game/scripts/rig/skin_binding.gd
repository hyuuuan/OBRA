class_name SkinBinding
extends RefCounted
## Binds a drawing's ink to a skeleton, then deforms it each frame.
##
## This is the piece that makes the old failures unrepresentable. Every ink point is
## influenced by up to K bones with weights that vary SMOOTHLY across the drawing and
## always sum to one. Two consequences follow, and neither depends on tuning:
##
##   * A stroke is never cut, welded or reparented. One drawn stroke stays one
##     polyline for the life of the creature, so it cannot tear in half or leave part
##     of itself behind on the body -- both of which players saw.
##   * With every bone at rest the transforms cancel exactly (p' = Σ w·p = p), so the
##     creature at rest is the drawing, to the pixel.
##
## Weights use a smoothstep falloff (C¹, exactly zero past a bone's radius) times a
## Shepard-style inverse-distance kernel (biases toward the nearest bone without a
## singularity when a point sits on one) times a soft region bias. The ROOT bone's
## falloff is 1 at any distance, which is what guarantees the weight sum is never
## zero -- so "ink nowhere near a bone" needs no special case, it simply rides the
## body. That single rule replaces a whole family of degenerate-case handling.

const MAX_BONES_PER_POINT := 4
const KERNEL_SHARPNESS := 3.0
const CAPTURE_BIAS_MIN := 0.15
const CAPTURE_MARGIN := 0.10
## A fitted part's ink eases from its parent onto its own bone over this share of its length,
## so the joint where it meets the body bends rather than tears.
const JOINT_BLEND := 0.15

var _skeleton: Skeleton2D_Rig
## Per stroke: bone indices, weights and rest-local positions, flattened K-per-point.
var _bone_ids: Array[PackedInt32Array] = []
var _weights: Array[PackedFloat32Array] = []
var _rest_local: Array[PackedVector2Array] = []
var _rest_points: Array[PackedVector2Array] = []
var _scratch: Array[PackedVector2Array] = []


func skeleton() -> Skeleton2D_Rig:
	return _skeleton


func stroke_count() -> int:
	return _rest_points.size()


func rest_points(stroke_index: int) -> PackedVector2Array:
	return _rest_points[stroke_index]


## `strokes` is the normalised vector stroke list (each {points, width, color}). `regions`
## (SkeletonFit.Regions) says which fitted bone owns which part of the drawing; ink in a part
## follows that bone alone, and fitted bones never reach for ink outside their part.
func bind(strokes: Array, skeleton: Skeleton2D_Rig, regions: SkeletonFit.Regions = null) -> void:
	_skeleton = skeleton
	_bone_ids.clear()
	_weights.clear()
	_rest_local.clear()
	_rest_points.clear()
	_scratch.clear()
	if skeleton == null or skeleton.bones.is_empty():
		return
	var epsilon := maxf(1.0, skeleton.diagonal * 0.05)
	var slot_bone := PackedInt32Array()
	if regions != null:
		for name in regions.names:
			slot_bone.append(skeleton.find(name))

	for stroke_value in strokes:
		var points := PackedVector2Array((stroke_value as Dictionary).get("points", PackedVector2Array()))
		var count := points.size()
		var ids := PackedInt32Array()
		var weights := PackedFloat32Array()
		var locals := PackedVector2Array()
		ids.resize(count * MAX_BONES_PER_POINT)
		weights.resize(count * MAX_BONES_PER_POINT)
		locals.resize(count * MAX_BONES_PER_POINT)

		for p in range(count):
			var point := points[p]
			var slot := regions.slot_at(point) if regions != null else -1
			var owner := slot_bone[slot] if slot >= 0 else -1
			var chosen := _weigh_in_part(point, owner) if owner >= 0 else _weigh_point(point, epsilon)
			var base := p * MAX_BONES_PER_POINT
			for k in range(MAX_BONES_PER_POINT):
				var bone_index: int = chosen[0][k]
				ids[base + k] = bone_index
				weights[base + k] = chosen[1][k]
				locals[base + k] = skeleton.bones[bone_index].rest_inverse * point if bone_index >= 0 else Vector2.ZERO
		_bone_ids.append(ids)
		_weights.append(weights)
		_rest_local.append(locals)
		_rest_points.append(points.duplicate())
		var buffer := PackedVector2Array()
		buffer.resize(count)
		_scratch.append(buffer)


## Deform one stroke for the given posed bone transforms. Returns a buffer reused
## across frames; assign it straight to Line2D.points (Godot needs the reassignment,
## writing into the property's copy does not propagate).
func deform(stroke_index: int, posed: Array) -> PackedVector2Array:
	var ids := _bone_ids[stroke_index]
	var weights := _weights[stroke_index]
	var locals := _rest_local[stroke_index]
	var out := _scratch[stroke_index]
	var count := out.size()
	for p in range(count):
		var base := p * MAX_BONES_PER_POINT
		var accumulated := Vector2.ZERO
		for k in range(MAX_BONES_PER_POINT):
			var weight := weights[base + k]
			if weight <= 0.0:
				continue
			accumulated += (posed[ids[base + k]] as Transform2D) * locals[base + k] * weight
		out[p] = accumulated
	return out


## Share of the total ink each bone carries. A bone that owns almost nothing can swing
## as hard as it likes and the player will see nothing move -- the failure mode a
## class-driven skeleton introduces, and the reason this is measured in the tests.
func bone_ink_mass() -> PackedFloat32Array:
	var mass := PackedFloat32Array()
	mass.resize(_skeleton.bones.size() if _skeleton != null else 0)
	var total := 0.0
	for s in range(_weights.size()):
		var weights := _weights[s]
		var ids := _bone_ids[s]
		for i in range(weights.size()):
			if weights[i] > 0.0 and ids[i] >= 0:
				mass[ids[i]] += weights[i]
				total += weights[i]
	if total > 0.0:
		for i in range(mass.size()):
			mass[i] /= total
	return mass


## Share of one stroke's ink each KIND of bone carries ({role: share}, summing to 1). What
## tells a wing that flaps from a wing left riding the body, per stroke the player drew.
func stroke_role_share(stroke_index: int) -> Dictionary:
	var shares: Dictionary = {}
	var ids := _bone_ids[stroke_index]
	var weights := _weights[stroke_index]
	var total := 0.0
	for i in range(weights.size()):
		if weights[i] > 0.0 and ids[i] >= 0:
			var role := _skeleton.bones[ids[i]].role
			shares[role] = float(shares.get(role, 0.0)) + weights[i]
			total += weights[i]
	if total > 0.0:
		for role in shares:
			shares[role] = float(shares[role]) / total
	return shares


## Diagnostics for the test suite: weight sums and any point left unbound.
func report() -> Dictionary:
	var minimum_sum := INF
	var unbound := 0
	var points := 0
	for s in range(_weights.size()):
		var weights := _weights[s]
		var per_point := weights.size() / MAX_BONES_PER_POINT
		for p in range(per_point):
			var sum := 0.0
			for k in range(MAX_BONES_PER_POINT):
				sum += weights[p * MAX_BONES_PER_POINT + k]
			minimum_sum = minf(minimum_sum, sum)
			if sum <= 0.0:
				unbound += 1
			points += 1
	return {
		"stroke_count": _rest_points.size(),
		"point_count": points,
		"min_weight_sum": 0.0 if not is_finite(minimum_sum) else minimum_sum,
		"unbound_points": unbound,
	}


# --- weighting ---------------------------------------------------------------

func _weigh_point(point: Vector2, epsilon: float) -> Array:
	var ids := PackedInt32Array()
	var weights := PackedFloat32Array()
	ids.resize(MAX_BONES_PER_POINT)
	weights.resize(MAX_BONES_PER_POINT)
	for k in range(MAX_BONES_PER_POINT):
		ids[k] = -1
		weights[k] = 0.0

	for b in range(_skeleton.bones.size()):
		var bone := _skeleton.bones[b]
		# A fitted bone owns its part and nothing else, however near other ink lies.
		if bone.fitted:
			continue
		var nearest := Geometry2D.get_closest_point_to_segment(point, bone.pivot, bone.tip)
		var distance := point.distance_to(nearest)
		# influence == 0 marks the root: it reaches everywhere, so no point can end up
		# with nothing to follow.
		var falloff := 1.0
		if bone.influence > 0.0:
			var s := clampf(1.0 - distance / bone.influence, 0.0, 1.0)
			falloff = s * s * (3.0 - 2.0 * s)
		if falloff <= 0.0:
			continue
		var kernel := pow(epsilon / (distance + epsilon), KERNEL_SHARPNESS)
		var raw := falloff * kernel * _capture_bias(point, bone)
		if raw <= 0.0:
			continue
		# Keep the strongest K, replacing the weakest slot.
		var weakest := 0
		for k in range(1, MAX_BONES_PER_POINT):
			if weights[k] < weights[weakest]:
				weakest = k
		if raw > weights[weakest]:
			weights[weakest] = raw
			ids[weakest] = b

	var total := 0.0
	for k in range(MAX_BONES_PER_POINT):
		total += weights[k]
	if total > 0.0:
		for k in range(MAX_BONES_PER_POINT):
			weights[k] /= total
	return [ids, weights]


## Ink inside a fitted part: its bone, eased in from the parent near the joint.
func _weigh_in_part(point: Vector2, owner: int) -> Array:
	var ids := PackedInt32Array([-1, -1, -1, -1])
	var weights := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var bone := _skeleton.bones[owner]
	var reach := bone.tip - bone.pivot
	var along := clampf((point - bone.pivot).dot(reach) / maxf(1.0, reach.length_squared()), 0.0, 1.0)
	var own := smoothstep(0.0, JOINT_BLEND, along)
	ids[0] = owner
	weights[0] = own
	if bone.parent >= 0 and own < 1.0:
		ids[1] = bone.parent
		weights[1] = 1.0 - own
	else:
		weights[0] = 1.0
	return [ids, weights]


## Smoothly favours ink inside a bone's authored region without ever excluding ink
## outside it. A hard cut here is what used to slice a wing away from a body.
func _capture_bias(point: Vector2, bone: Skeleton2D_Rig.Bone) -> float:
	if bone.capture.is_empty():
		return 1.0
	var size := _skeleton.bounds.size
	var u := (point.x - _skeleton.bounds.position.x) / maxf(1.0, size.x)
	var v := (point.y - _skeleton.bounds.position.y) / maxf(1.0, size.y)
	var inside := _band(u, bone.capture.get("u", [0.0, 1.0])) * _band(v, bone.capture.get("v", [0.0, 1.0]))
	return lerpf(CAPTURE_BIAS_MIN, 1.0, inside)


func _band(value: float, range_value: Variant) -> float:
	var pair: Array = range_value
	if pair.size() != 2:
		return 1.0
	var low := float(pair[0])
	var high := float(pair[1])
	return smoothstep(low - CAPTURE_MARGIN, low + CAPTURE_MARGIN, value) \
		* (1.0 - smoothstep(high - CAPTURE_MARGIN, high + CAPTURE_MARGIN, value))
