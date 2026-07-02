class_name EntityRegistry
extends Node
## Loads game/config/entities.json and instantiates manifest-defined scenes.

@export var manifest_path: String = "res://config/entities.json"

var _entities_by_id: Dictionary = {}


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

	for entry: Dictionary in parsed["entities"]:
		if not bool(entry.get("enabled", true)):
			continue
		var entity_id := String(entry.get("id", ""))
		if entity_id.is_empty():
			push_error("Entity manifest contains an enabled entry without an id")
			continue
		_entities_by_id[entity_id] = entry


func get_entity(entity_id: String) -> Dictionary:
	if _entities_by_id.is_empty():
		load_manifest()
	return _entities_by_id.get(entity_id, {})


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
	return packed.instantiate()
