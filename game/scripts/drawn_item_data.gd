class_name DrawnItemData
extends RefCounted
## One non-stackable drawing instance. Images and strokes are copied so an item
## keeps its exact appearance through inventory, placement, and pickup cycles.

static var _next_instance_id: int = 1

var instance_id: int
var entity_id: String = ""
var display_name: String = ""
var image: Image
var strokes: Array = []
var ink_cost: float = 0.0
var entity_metadata: Dictionary = {}
var runtime_state: Dictionary = {}
var placement_transform: Transform2D = Transform2D.IDENTITY
var ink_committed: bool = false


func _init() -> void:
	instance_id = _next_instance_id
	_next_instance_id += 1


static func from_prediction(
	p_entity_id: String,
	p_display_name: String,
	p_image: Image,
	p_strokes: Array,
	p_ink_cost: float,
	p_metadata: Dictionary
) -> DrawnItemData:
	var item := DrawnItemData.new()
	item.entity_id = p_entity_id
	item.display_name = p_display_name
	item.image = p_image.duplicate() if p_image != null else null
	item.strokes = copy_strokes(p_strokes)
	item.ink_cost = maxf(0.0, p_ink_cost)
	item.entity_metadata = p_metadata.duplicate(true)
	return item


static func copy_strokes(source: Array) -> Array:
	var copied: Array = []
	for value in source:
		if not (value is Dictionary):
			continue
		var stroke: Dictionary = value
		var next := stroke.duplicate(true)
		var points: Variant = stroke.get("points")
		if points is PackedVector2Array:
			next["points"] = points.duplicate()
		copied.append(next)
	return copied


func save_world_state(world_object: Node2D) -> void:
	placement_transform = world_object.global_transform
	if world_object.has_method("serialize_utility_state"):
		var state: Variant = world_object.call("serialize_utility_state")
		if state is Dictionary:
			runtime_state = state.duplicate(true)

