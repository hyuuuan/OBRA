class_name SkeletonLibrary
extends RefCounted
## Resolves the canonical skeleton for a recognised class.
##
## Anatomy comes from WHAT THE DRAWING WAS RECOGNISED AS, not from inspecting the
## player's strokes. The previous rig inferred anatomy geometrically -- electing a
## torso by score, classifying limbs by direction, deciding what to absorb -- and
## every one of those decisions could pick the wrong stroke on a perfectly ordinary
## drawing. The class is already known by the time a creature is built, so the
## skeleton is simply looked up.
##
## Bone coordinates are fractions of the drawing's bounding box, so one skeleton per
## archetype fits every drawing of that archetype regardless of size or proportions.
##
## Per-entity overrides live in game/config/rigs/<id>.json under a "skeleton" block and
## merge BY BONE NAME over the archetype: a bone with a new name is added, an existing
## name is overridden field-by-field, and {"remove": true} drops it.

const SKELETONS_PATH := "res://config/skeletons.json"
const RIG_DIR := "res://config/rigs"

## Bone fields that carry no meaning on their own and must not be merged blindly.
const _MERGE_SKIP := ["name", "remove"]

static var _cache: Dictionary = {}
static var _document: Dictionary = {}


## Skeleton for one entity: {archetype, aspect, frequency_hz, frequency_key,
## foot_planting, body_motion, bones:[...]}. Returns an empty Dictionary only if the
## document itself is unreadable, which the manifest test catches.
static func resolve(entity_id: String, rig_type: String) -> Dictionary:
	var key := "%s|%s" % [entity_id, rig_type]
	if _cache.has(key):
		return _cache[key]
	var document := _load_document()
	var archetypes: Dictionary = document.get("archetypes", {})
	var archetype_name := rig_type if archetypes.has(rig_type) else "none"
	var base: Dictionary = archetypes.get(archetype_name, {})
	if base.is_empty():
		return {}

	var skeleton := _duplicate_archetype(base)
	skeleton["archetype"] = archetype_name
	skeleton["entity_id"] = entity_id
	_apply_entity_override(skeleton, entity_id)
	_resolve_gait_refs(skeleton)
	_cache[key] = skeleton
	return skeleton


## Names of every archetype in the document, for the manifest test.
static func archetype_names() -> Array:
	return (_load_document().get("archetypes", {}) as Dictionary).keys()


## Fields a skeleton refers to by name in rigs/<id>.json (amplitude_key, bias_key,
## frequency_key, and the body_motion keys). The manifest test checks these resolve.
static func referenced_profile_keys(skeleton: Dictionary) -> Array:
	var keys: Array = []
	if skeleton.has("frequency_key"):
		keys.append(String(skeleton["frequency_key"]))
	var motion: Dictionary = skeleton.get("body_motion", {})
	for field in ["bob_key", "tilt_key", "squash_key"]:
		if motion.has(field):
			keys.append(String(motion[field]))
	for bone_value in skeleton.get("bones", []):
		var gait: Dictionary = (bone_value as Dictionary).get("gait", {})
		for field in ["amplitude_key", "bias_key"]:
			if gait.has(field):
				keys.append(String(gait[field]))
	return keys


## Structural problems, as human-readable strings. Empty means the skeleton is sound.
## A data-driven design fails by typo, so this is checked in the test suite rather
## than discovered as a creature that will not move.
static func validate(skeleton: Dictionary) -> Array:
	var problems: Array = []
	var bones: Array = skeleton.get("bones", [])
	if bones.is_empty():
		problems.append("no bones")
		return problems

	var by_name: Dictionary = {}
	var roots := 0
	for bone_value in bones:
		var bone: Dictionary = bone_value
		var name := String(bone.get("name", ""))
		if name.is_empty():
			problems.append("a bone has no name")
			continue
		if by_name.has(name):
			problems.append("duplicate bone name '%s'" % name)
		by_name[name] = bone
		if String(bone.get("parent", "")).is_empty():
			roots += 1
		for field in ["pivot", "tip"]:
			var point: Array = bone.get(field, [])
			if point.size() != 2:
				problems.append("%s.%s must be [u, v]" % [name, field])
				continue
			for component: Variant in point:
				# Slightly outside the box is legitimate -- a drawn tail can overhang.
				if float(component) < -0.25 or float(component) > 1.25:
					problems.append("%s.%s %s is far outside the drawing" % [name, field, str(point)])
					break
		var influence := float(bone.get("influence", 0.0))
		if influence < 0.0 or influence > 2.0:
			problems.append("%s.influence %.2f out of range" % [name, influence])

	if roots != 1:
		problems.append("expected exactly one root bone, found %d" % roots)
	for name: String in by_name.keys():
		var parent := String((by_name[name] as Dictionary).get("parent", ""))
		if not parent.is_empty() and not by_name.has(parent):
			problems.append("%s has unknown parent '%s'" % [name, parent])
	problems.append_array(_cycle_problems(by_name))
	return problems


# --- internals ---------------------------------------------------------------

static func _load_document() -> Dictionary:
	if not _document.is_empty():
		return _document
	var text := FileAccess.get_file_as_string(SKELETONS_PATH)
	if text.is_empty():
		push_error("SkeletonLibrary: could not read %s" % SKELETONS_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("SkeletonLibrary: %s is not a JSON object" % SKELETONS_PATH)
		return {}
	_document = parsed
	return _document


static func _duplicate_archetype(base: Dictionary) -> Dictionary:
	var skeleton := base.duplicate(true)
	var bones: Array = []
	for bone_value in skeleton.get("bones", []):
		bones.append((bone_value as Dictionary).duplicate(true))
	skeleton["bones"] = bones
	return skeleton


static func _apply_entity_override(skeleton: Dictionary, entity_id: String) -> void:
	var path := "%s/%s.json" % [RIG_DIR, entity_id]
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return
	var override: Dictionary = (parsed as Dictionary).get("skeleton", {})
	if override.is_empty():
		return
	for field: String in override.keys():
		if field != "bones":
			skeleton[field] = override[field]

	var bones: Array = skeleton["bones"]
	var index_of: Dictionary = {}
	for index in range(bones.size()):
		index_of[String((bones[index] as Dictionary).get("name", ""))] = index
	for bone_value in override.get("bones", []):
		var incoming: Dictionary = bone_value
		var name := String(incoming.get("name", ""))
		if name.is_empty():
			continue
		if bool(incoming.get("remove", false)):
			if index_of.has(name):
				bones.remove_at(int(index_of[name]))
				index_of = _reindex(bones)
			continue
		if index_of.has(name):
			var existing: Dictionary = bones[int(index_of[name])]
			for field: String in incoming.keys():
				if field not in _MERGE_SKIP:
					existing[field] = incoming[field]
		else:
			bones.append(incoming.duplicate(true))
			index_of = _reindex(bones)


static func _reindex(bones: Array) -> Dictionary:
	var index_of: Dictionary = {}
	for index in range(bones.size()):
		index_of[String((bones[index] as Dictionary).get("name", ""))] = index
	return index_of


## `{"$ref": "other_bone"}` copies that bone's gait, so a mirrored pair cannot drift
## apart when one side is retuned. Fields beside the $ref still override it.
static func _resolve_gait_refs(skeleton: Dictionary) -> void:
	var gait_by_name: Dictionary = {}
	for bone_value in skeleton.get("bones", []):
		var bone: Dictionary = bone_value
		gait_by_name[String(bone.get("name", ""))] = bone.get("gait", {})
	for bone_value in skeleton.get("bones", []):
		var bone: Dictionary = bone_value
		var gait: Dictionary = bone.get("gait", {})
		if not gait.has("$ref"):
			continue
		var source: Dictionary = gait_by_name.get(String(gait["$ref"]), {})
		var merged := (source as Dictionary).duplicate(true)
		for field: String in gait.keys():
			if field != "$ref":
				merged[field] = gait[field]
		bone["gait"] = merged


static func _cycle_problems(by_name: Dictionary) -> Array:
	var problems: Array = []
	for name: String in by_name.keys():
		var seen: Dictionary = {name: true}
		var cursor := String((by_name[name] as Dictionary).get("parent", ""))
		while not cursor.is_empty() and by_name.has(cursor):
			if seen.has(cursor):
				problems.append("bone parent cycle through '%s'" % cursor)
				break
			seen[cursor] = true
			cursor = String((by_name[cursor] as Dictionary).get("parent", ""))
	return problems
