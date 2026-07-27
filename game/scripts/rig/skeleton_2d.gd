class_name Skeleton2D_Rig
extends RefCounted
## A resolved skeleton placed onto one particular drawing.
##
## SkeletonLibrary supplies bone positions as fractions of the drawing's bounding box;
## this turns them into concrete points in rig space for the drawing actually made, so
## the same archetype fits a tall thin butterfly and a wide squat one without any
## per-drawing decisions being taken.
##
## Bones are stored parents-before-children so a single forward pass can compose the
## hierarchy. Rotating a bone rotates everything hanging off it, which is what lets a
## shin swing with its thigh while remaining rigidly attached to it.

class Bone extends RefCounted:
	var name: String
	var role: String
	var parent: int = -1          ## index into the bones array, -1 for the root
	var side: float = 0.0         ## -1 / 0 / +1, mirrors the gait
	var index: int = 0            ## ordering within a role, drives phase stepping
	var pivot: Vector2            ## rig space: where this bone turns
	var tip: Vector2              ## rig space: where it reaches to
	var rest_angle: float = 0.0
	var influence: float = 0.0    ## falloff radius in px; 0 == unbounded (root only)
	var limit: float = 0.0        ## radians
	var capture: Dictionary = {}  ## soft {u:[lo,hi], v:[lo,hi]} region bias
	var gait: Dictionary = {}
	var rest_transform: Transform2D = Transform2D.IDENTITY
	var rest_inverse: Transform2D = Transform2D.IDENTITY
	var rest_local: Transform2D = Transform2D.IDENTITY  ## relative to parent

var bones: Array[Bone] = []
var bounds: Rect2
var diagonal: float = 1.0
var archetype: String = ""
var body_motion: Dictionary = {}
var frequency_hz: float = 0.0
var foot_planting: bool = false


## Place `skeleton` (from SkeletonLibrary.resolve) onto a drawing occupying `bbox`.
## `profile` is the entity's rigs/<id>.json, consulted for named gait amplitudes.
static func build(skeleton: Dictionary, bbox: Rect2, profile: Dictionary) -> Skeleton2D_Rig:
	var rig := Skeleton2D_Rig.new()
	rig.archetype = String(skeleton.get("archetype", ""))
	rig.body_motion = skeleton.get("body_motion", {})
	rig.foot_planting = bool(skeleton.get("foot_planting", false))
	# A drawing can be degenerate (a single dot, a perfectly straight line). Give it a
	# floor so bone placement and falloff radii stay finite.
	rig.bounds = Rect2(bbox.position, bbox.size.max(Vector2(4.0, 4.0)))
	rig.diagonal = maxf(1.0, rig.bounds.size.length())
	rig.frequency_hz = float(skeleton.get("frequency_hz", 0.0))
	if skeleton.has("frequency_key"):
		rig.frequency_hz = float(profile.get(String(skeleton["frequency_key"]), rig.frequency_hz))

	var source: Array = skeleton.get("bones", [])
	var index_of: Dictionary = {}
	for entry_value in source:
		index_of[String((entry_value as Dictionary).get("name", ""))] = index_of.size()

	for entry_value in source:
		var entry: Dictionary = entry_value
		var bone := Bone.new()
		bone.name = String(entry.get("name", ""))
		bone.role = String(entry.get("role", "limb"))
		bone.side = float(entry.get("side", 0.0))
		bone.index = int(entry.get("index", 0))
		bone.pivot = rig._to_rig_space(entry.get("pivot", [0.5, 0.5]))
		bone.tip = rig._to_rig_space(entry.get("tip", [0.5, 0.9]))
		bone.rest_angle = (bone.tip - bone.pivot).angle()
		bone.influence = float(entry.get("influence", 0.0)) * rig.diagonal
		bone.limit = deg_to_rad(float(entry.get("limit_deg", 55.0)))
		bone.capture = entry.get("capture", {})
		bone.gait = entry.get("gait", {})
		var parent_name := String(entry.get("parent", ""))
		bone.parent = int(index_of.get(parent_name, -1)) if not parent_name.is_empty() else -1
		bone.rest_transform = Transform2D(bone.rest_angle, bone.pivot)
		bone.rest_inverse = bone.rest_transform.affine_inverse()
		rig.bones.append(bone)

	rig._sort_parents_first()
	for bone in rig.bones:
		bone.rest_local = bone.rest_transform if bone.parent < 0 \
			else rig.bones[bone.parent].rest_inverse * bone.rest_transform
	return rig


## World-ish transforms for the current bone angles, composed down the hierarchy.
## `angles` is per-bone local rotation in radians; `root_extra` carries whole-body
## bob/tilt/squash so it flows through every bone without a second mechanism.
func pose(angles: PackedFloat32Array, root_extra: Transform2D = Transform2D.IDENTITY) -> Array:
	var out: Array = []
	out.resize(bones.size())
	for i in range(bones.size()):
		var bone := bones[i]
		var local := bone.rest_local * Transform2D(angles[i] if i < angles.size() else 0.0, Vector2.ZERO)
		out[i] = (root_extra * local) if bone.parent < 0 else ((out[bone.parent] as Transform2D) * local)
	return out


func find(bone_name: String) -> int:
	for i in range(bones.size()):
		if bones[i].name == bone_name:
			return i
	return -1


func _to_rig_space(fraction: Variant) -> Vector2:
	var pair: Array = fraction
	if pair.size() != 2:
		return bounds.get_center()
	return bounds.position + Vector2(float(pair[0]), float(pair[1])) * bounds.size


## Stable topological order. A child must never be composed before its parent, and the
## JSON is authored by hand so it cannot be trusted to already be in that order.
func _sort_parents_first() -> void:
	var ordered: Array[Bone] = []
	var remap: Dictionary = {}
	var placed: Dictionary = {}
	var guard := 0
	while ordered.size() < bones.size() and guard <= bones.size():
		guard += 1
		for i in range(bones.size()):
			if placed.has(i):
				continue
			if bones[i].parent >= 0 and not placed.has(bones[i].parent):
				continue
			remap[i] = ordered.size()
			ordered.append(bones[i])
			placed[i] = true
	# A cycle would leave stragglers; append them rootward rather than drop their ink.
	for i in range(bones.size()):
		if not placed.has(i):
			bones[i].parent = -1
			remap[i] = ordered.size()
			ordered.append(bones[i])
	for bone in ordered:
		if bone.parent >= 0:
			bone.parent = int(remap[bone.parent])
	bones = ordered
