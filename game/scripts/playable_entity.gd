extends CharacterBody2D
## Shared entity metadata, skinning, and runtime-rig forwarding.

@export var skin_node_path: NodePath = NodePath("DrawingSkin")
@export var body_node_path: NodePath = NodePath("Body")
@export var punch_white_background: bool = true
@export_range(0.0, 1.0) var paper_threshold: float = 0.92

var entity_metadata: Dictionary = {}
var rig_profile: Dictionary = {}


func configure_entity(entry: Dictionary) -> void:
	entity_metadata = entry.duplicate(true)
	rig_profile = _load_rig_profile(String(entry.get("rig_profile", "")))
	if not rig_profile.has("rig_type"):
		rig_profile["rig_type"] = String(entry.get("rig_type", "none"))

	var skin := _get_skin()
	if skin != null:
		if skin.has_method("configure_rig"):
			skin.configure_rig(rig_profile, entity_metadata)
		elif skin.has_method("configure_skin"):
			skin.configure_skin(rig_profile, entity_metadata)


func apply_drawing(drawing: Image, strokes: Array = []) -> void:
	var skin := _get_skin()
	if skin != null and skin.has_method("apply_drawing"):
		skin.apply_drawing(drawing, strokes)
		return

	var sprite := _get_body_sprite()
	if sprite == null:
		push_warning("%s has no Body Sprite2D to skin" % name)
		return

	var image := drawing.duplicate()
	image.convert(Image.FORMAT_RGBA8)
	if punch_white_background:
		_make_paper_transparent(image)
	sprite.texture = ImageTexture.create_from_image(image)


func _make_paper_transparent(image: Image) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.r >= paper_threshold and color.g >= paper_threshold and color.b >= paper_threshold:
				color.a = 0.0
			else:
				color.a = 1.0
			image.set_pixel(x, y, color)


func set_rig_state(state: String, params: Dictionary = {}) -> void:
	var skin := _get_skin()
	if skin != null and skin.has_method("set_motion_state"):
		skin.set_motion_state(state, params)


func _get_skin() -> Node:
	var skin := get_node_or_null(skin_node_path)
	if skin == null:
		skin = find_child("DrawingSkin", true, false)
	return skin


func _get_body_sprite() -> Sprite2D:
	var sprite := get_node_or_null(body_node_path) as Sprite2D
	if sprite == null:
		sprite = find_child("Body", true, false) as Sprite2D
	return sprite


func _load_rig_profile(profile_path: String) -> Dictionary:
	if profile_path.is_empty():
		return {}

	var text := FileAccess.get_file_as_string(profile_path)
	if text.is_empty():
		push_warning("Could not read rig profile: %s" % profile_path)
		return {}

	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed

	push_warning("Rig profile is not a JSON object: %s" % profile_path)
	return {}
