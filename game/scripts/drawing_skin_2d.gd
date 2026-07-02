extends Node2D
class_name DrawingSkin2D
## Turns the submitted canvas image into a transparent, cropped runtime skin.

@export var body_node_path: NodePath = NodePath("Body")
@export_range(0.0, 1.0) var paper_threshold: float = 0.92
@export var visible_padding: int = 10
@export var default_target_size: Vector2 = Vector2(96, 96)
@export var min_texture_scale: float = 0.05
@export var max_texture_scale: float = 1.0

var profile: Dictionary = {}
var entity_metadata: Dictionary = {}
var analysis: Dictionary = {}

var _body: Sprite2D
var _texture: ImageTexture
var _texture_scale: float = 1.0
var _target_size: Vector2 = Vector2(96, 96)
var _pivot: Vector2 = Vector2(0.5, 0.5)
var _body_base_position: Vector2 = Vector2.ZERO
var _body_base_scale: Vector2 = Vector2.ONE
var _body_base_rotation: float = 0.0
var _segment_roots: Array = []
var _segment_base_positions: Array = []


func _ready() -> void:
	_ensure_body()


func configure_skin(new_profile: Dictionary, new_entity_metadata: Dictionary = {}) -> void:
	profile = new_profile.duplicate(true)
	entity_metadata = new_entity_metadata.duplicate(true)
	_target_size = _profile_vector2("target_size", default_target_size)
	_pivot = _profile_vector2("pivot", Vector2(0.5, 0.5))
	_ensure_body()


func apply_drawing(drawing: Image) -> Dictionary:
	if drawing == null:
		analysis = {"empty": true, "reason": "drawing is null"}
		return analysis

	var image := drawing.duplicate()
	image.convert(Image.FORMAT_RGBA8)
	_make_paper_transparent(image)

	var visible_rect := _find_visible_rect(image)
	if visible_rect.size.x <= 0 or visible_rect.size.y <= 0:
		visible_rect = Rect2i(Vector2i.ZERO, image.get_size())

	var padded_rect := _rect_with_padding(visible_rect, image.get_size())
	var cropped: Image = image.get_region(padded_rect)
	var ink_pixels := _count_visible_pixels(cropped)
	var crop_area := float(maxi(1, cropped.get_width() * cropped.get_height()))

	analysis = {
		"empty": ink_pixels == 0,
		"source_size": [image.get_width(), image.get_height()],
		"bounds": {
			"x": visible_rect.position.x,
			"y": visible_rect.position.y,
			"width": visible_rect.size.x,
			"height": visible_rect.size.y
		},
		"crop": {
			"x": padded_rect.position.x,
			"y": padded_rect.position.y,
			"width": padded_rect.size.x,
			"height": padded_rect.size.y
		},
		"center": [
			float(visible_rect.position.x) + float(visible_rect.size.x) * 0.5,
			float(visible_rect.position.y) + float(visible_rect.size.y) * 0.5
		],
		"aspect_ratio": float(visible_rect.size.x) / float(maxi(1, visible_rect.size.y)),
		"stroke_density": float(ink_pixels) / crop_area
	}

	_texture = ImageTexture.create_from_image(cropped)
	_apply_texture_to_body(cropped.get_size())
	return analysis


func get_analysis() -> Dictionary:
	return analysis.duplicate(true)


func reset_body_transform() -> void:
	_ensure_body()
	if _body == null:
		return
	_body.position = _body_base_position
	_body.scale = _body_base_scale
	_body.rotation = _body_base_rotation


func has_texture() -> bool:
	return _texture != null


func _ensure_body() -> void:
	if _body != null:
		return
	_body = get_node_or_null(body_node_path) as Sprite2D
	if _body == null:
		_body = find_child("Body", true, false) as Sprite2D


func _make_paper_transparent(image: Image) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.r >= paper_threshold and color.g >= paper_threshold and color.b >= paper_threshold:
				color.a = 0.0
			else:
				color.a = 1.0
			image.set_pixel(x, y, color)


func _find_visible_rect(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1

	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.01:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)

	if max_x < min_x or max_y < min_y:
		return Rect2i(0, 0, 0, 0)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _rect_with_padding(rect: Rect2i, image_size: Vector2i) -> Rect2i:
	var left := maxi(rect.position.x - visible_padding, 0)
	var top := maxi(rect.position.y - visible_padding, 0)
	var right := mini(rect.position.x + rect.size.x + visible_padding, image_size.x)
	var bottom := mini(rect.position.y + rect.size.y + visible_padding, image_size.y)
	return Rect2i(left, top, maxi(1, right - left), maxi(1, bottom - top))


func _count_visible_pixels(image: Image) -> int:
	var total := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.01:
				total += 1
	return total


func _apply_texture_to_body(texture_size: Vector2i) -> void:
	_ensure_body()
	if _body == null:
		push_warning("%s has no Body Sprite2D to skin" % name)
		return

	var scale_x := _target_size.x / float(maxi(1, texture_size.x))
	var scale_y := _target_size.y / float(maxi(1, texture_size.y))
	_texture_scale = clampf(minf(scale_x, scale_y), min_texture_scale, max_texture_scale)

	_body.texture = _texture
	_body.centered = true
	_body.region_enabled = false
	_body.visible = true
	_body_base_position = _pivot_offset(Vector2(texture_size))
	_body_base_scale = Vector2(_texture_scale, _texture_scale)
	_body_base_rotation = 0.0
	reset_body_transform()


func _pivot_offset(texture_size: Vector2) -> Vector2:
	return (Vector2(0.5, 0.5) - _pivot) * texture_size * _texture_scale


func _rebuild_segments(count: int) -> void:
	_clear_segments()
	_ensure_body()
	if _texture == null:
		return

	var texture_size := _texture.get_size()
	var tex_width := maxi(1, int(texture_size.x))
	var tex_height := maxi(1, int(texture_size.y))
	var safe_count := maxi(1, count)

	for index in range(safe_count):
		var slice_x := int(round(float(index) * float(tex_width) / float(safe_count)))
		var next_x := int(round(float(index + 1) * float(tex_width) / float(safe_count)))
		var slice_width := maxi(1, next_x - slice_x)

		var segment := Node2D.new()
		segment.name = "Segment%02d" % index
		add_child(segment)

		var sprite := Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture = _texture
		sprite.centered = true
		sprite.region_enabled = true
		sprite.region_rect = Rect2(float(slice_x), 0.0, float(slice_width), float(tex_height))
		sprite.scale = Vector2(_texture_scale, _texture_scale)
		segment.add_child(sprite)

		var local_x := (float(slice_x) + float(slice_width) * 0.5 - texture_size.x * 0.5) * _texture_scale
		segment.position = _pivot_offset(texture_size) + Vector2(local_x, 0.0)
		_segment_roots.append(segment)
		_segment_base_positions.append(segment.position)


func _clear_segments() -> void:
	for segment in _segment_roots:
		if is_instance_valid(segment):
			segment.queue_free()
	_segment_roots.clear()
	_segment_base_positions.clear()


func _set_body_visible(is_visible: bool) -> void:
	_ensure_body()
	if _body != null:
		_body.visible = is_visible


func _profile_float(key: String, default_value: float) -> float:
	var value: Variant = profile.get(key, default_value)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return default_value


func _profile_int(key: String, default_value: int) -> int:
	var value: Variant = profile.get(key, default_value)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return int(value)
	return default_value


func _profile_string(key: String, default_value: String) -> String:
	var value: Variant = profile.get(key, default_value)
	if value is String:
		return value
	return default_value


func _profile_vector2(key: String, default_value: Vector2) -> Vector2:
	var value: Variant = profile.get(key)
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return default_value
