class_name EntityRegistry
extends Node

const ALLOWED_RUNTIME_ROLES := ["active_ragdoll_morph", "physics_morph", "utility"]
const ALLOWED_MEDIA := ["any", "water"]
const ALLOWED_ABILITY_RELATIONS := ["CapableOf", "UsedFor", "hand_authored"]
const PRIMITIVE_IDS := ["circle", "square", "triangle"]
## Loads game/config/entities.json and instantiates manifest-defined scenes. The
## ConceptNet-grounded ability table (config/abilities.json) is merged into each entry.

@export var manifest_path: String = "res://config/entities.json"
@export var abilities_path: String = "res://config/abilities.json"

var _entities_by_id: Dictionary = {}
var _abilities_by_id: Dictionary = {}


func _ready() -> void:
	if _entities_by_id.is_empty():
		load_manifest()


func load_manifest() -> void:
	_entities_by_id.clear()
	var text := FileAccess.get_file_as_string(manifest_path)
	if text.is_empty():
		push_error("Could not read entity manifest: %s" % manifest_path)
		return

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary) or not parsed.has("entities"):
		push_error("Entity manifest must contain an entities array")
		return
	if int(parsed.get("version", 0)) != 2:
		push_error("Entity manifest version 2 is required")
		return

	_abilities_by_id = _load_abilities()

	for entry: Dictionary in parsed["entities"]:
		if not bool(entry.get("enabled", true)):
			continue
		var entity_id := String(entry.get("id", ""))
		if entity_id.is_empty():
			push_error("Entity manifest contains an enabled entry without an id")
			continue
		var role := String(entry.get("runtime_role", ""))
		if role not in ALLOWED_RUNTIME_ROLES:
			push_error("%s has invalid runtime_role: %s" % [entity_id, role])
			continue
		var medium := String(entry.get("required_medium", "any"))
		if medium not in ALLOWED_MEDIA:
			push_error("%s has invalid required_medium: %s" % [entity_id, medium])
			continue
		if role == "utility" and String(entry.get("utility_behavior", "")).is_empty():
			push_error("%s utility is missing utility_behavior" % entity_id)
			continue
		var ability: Dictionary = _abilities_by_id.get(entity_id, {})
		if ability.is_empty():
			push_error("%s is missing a ConceptNet ability entry" % entity_id)
			continue
		if entity_id in PRIMITIVE_IDS and String(ability.get("ability_relation", "")) != "hand_authored":
			push_error("%s is a primitive and must use a hand_authored ability" % entity_id)
			continue
		entry["ability"] = String(ability.get("ability", ""))
		entry["ability_relation"] = String(ability.get("ability_relation", ""))
		entry["ability_assertion"] = String(ability.get("ability_assertion", ""))
		entry["ability_weight"] = ability.get("ability_weight")
		_entities_by_id[entity_id] = entry


func _load_abilities() -> Dictionary:
	var result: Dictionary = {}
	var text := FileAccess.get_file_as_string(abilities_path)
	if text.is_empty():
		push_error("Could not read ability table: %s" % abilities_path)
		return result
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("Ability table must be a JSON object")
		return result
	var raw: Variant = parsed.get("abilities", parsed)
	if not (raw is Dictionary):
		push_error("Ability table must contain an 'abilities' object")
		return result
	for ability_id: String in raw.keys():
		var entry: Dictionary = raw[ability_id]
		var relation := String(entry.get("ability_relation", ""))
		if relation not in ALLOWED_ABILITY_RELATIONS:
			push_error("%s has invalid ability_relation: %s" % [ability_id, relation])
			continue
		result[ability_id] = entry
	return result


func get_ability(entity_id: String) -> Dictionary:
	if _entities_by_id.is_empty():
		load_manifest()
	return _abilities_by_id.get(entity_id, {})


func get_entity(entity_id: String) -> Dictionary:
	if _entities_by_id.is_empty():
		load_manifest()
	return _entities_by_id.get(entity_id, {})


func get_entity_ids() -> Array:
	if _entities_by_id.is_empty():
		load_manifest()
	return _entities_by_id.keys()


func instantiate_entity(entity_id: String) -> Node:
	var entry := get_entity(entity_id)
	if entry.is_empty():
		push_error("Unknown entity id: %s" % entity_id)
		return null

	var scene_path := String(entry.get("scene_path", ""))
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Could not load scene for %s: %s" % [entity_id, scene_path])
		return null
	var instance := packed.instantiate()
	if instance.has_method("configure_entity"):
		instance.configure_entity(entry)
	return instance
