extends Node2D
class_name DrawingSkin2D
## Builds the runtime skin for a submitted drawing.
## Vector mode (preferred): keeps the raw stroke polylines captured by the
## drawing canvas so the rig can articulate the player's actual ink.
## Bitmap mode (fallback): crops the rasterized canvas onto a Sprite2D when
## no stroke data is available.

@export var body_node_path: NodePath = NodePath("Body")
@export_range(0.0, 1.0) var paper_threshold: float = 0.92
@export var visible_padding: int = 10
@export var default_target_size: Vector2 = Vector2(96, 96)

const VECTOR_MIN_SCALE := 0.02
const VECTOR_MAX_SCALE := 4.0
const MAX_POINTS_PER_STROKE := 150

var profile: Dictionary = {}
var entity_metadata: Dictionary = {}
var analysis: Dictionary = {}

var _mode: String = "none" # none | bitmap | vector
var _body: Sprite2D
var _texture: ImageTexture
var _texture_scale: float = 1.0
var _target_size: Vector2 = Vector2(96, 96)
var _align: String = "center" # center | bottom
var _ground_offset: float = 0.0
var _body_base_position: Vector2 = Vector2.ZERO
var _body_base_scale: Vector2 = Vector2.ONE

# Normalized strokes in creature-local space:
# [{points: PackedVector2Array, width: float, color: Color}]
var _vector_strokes: Array = []
var _stroke_bounds: Rect2 = Rect2()


func _ready() -> void:
	_ensure_body()


func configure_skin(new_profile: Dictionary, new_entity_metadata: Dictionary = {}) -> void:
	profile = new_profile.duplicate(true)
	entity_metadata = new_entity_metadata.duplicate(true)
	_target_size = _profile_vector2("target_size", default_target_size)
	_align = _profile_string("align", "center")
	_ground_offset = _profile_float("ground_offset", 0.0)
	_ensure_body()


func apply_drawing(drawing: Image, strokes: Array = []) -> Dictionary:
	_vector_strokes.clear()
	_mode = "none"

	if not strokes.is_empty():
		_build_vector_strokes(strokes)

	if _mode != "vector":
		_build_bitmap_skin(drawing)

	_on_skin_rebuilt()
	return analysis


func skin_mode() -> String:
	return _mode


func get_vector_strokes() -> Array:
	return _vector_strokes


func get_stroke_bounds() -> Rect2:
	return _stroke_bounds


func get_analysis() -> Dictionary:
	return analysis.duplicate(true)


func has_texture() -> bool:
	return _texture != null


func reset_body_transform() -> void:
	_ensure_body()
	if _body == null:
		return
	_body.position = _body_base_position
	_body.scale = _body_base_scale
	_body.rotation = 0.0


## Subclasses rebuild their rig here after the skin data changes.
func _on_skin_rebuilt() -> void:
	pass


# --- Vector skin ------------------------------------------------------------


func _build_vector_strokes(raw_strokes: Array) -> void:
	var canvas_points: Array = [] # Array[PackedVector2Array]
	var widths: Array = []
	var colors: Array = []
	var bounds_min := Vector2(INF, INF)
	var bounds_max := Vector2(-INF, -INF)
	var max_width := 0.0

	for raw in raw_strokes:
		if not (raw is Dictionary):
			continue
		var stroke: Dictionary = raw
		var points_value: Variant = stroke.get("points")
		if not (points_value is PackedVector2Array):
			continue
		var points: PackedVector2Array = points_value
		if points.is_empty():
			continue
		var width := 8.0
		var width_value: Variant = stroke.get("width")
		if typeof(width_value) == TYPE_FLOAT or typeof(width_value) == TYPE_INT:
			width = float(width_value)
		var color := Color.BLACK
		var color_value: Variant = stroke.get("color")
		if color_value is Color:
			color = color_value

		canvas_points.append(points)
		widths.append(width)
		colors.append(color)
		max_width = maxf(max_width, width)
		for point in points:
			bounds_min = bounds_min.min(point)
			bounds_max = bounds_max.max(point)

	if canvas_points.is_empty():
		analysis = {"empty": true, "reason": "no stroke data"}
		return

	var pad := max_width * 0.5
	bounds_min -= Vector2(pad, pad)
	bounds_max += Vector2(pad, pad)
	var size := (bounds_max - bounds_min).max(Vector2(1.0, 1.0))
	var center := (bounds_min + bounds_max) * 0.5
	var scale := minf(_target_size.x / size.x, _target_size.y / size.y)
	scale = clampf(scale, VECTOR_MIN_SCALE, VECTOR_MAX_SCALE)

	var offset := Vector2.ZERO
	if _align == "bottom":
		offset.y = _ground_offset - size.y * scale * 0.5

	var local_min := Vector2(INF, INF)
	var local_max := Vector2(-INF, -INF)
	var diag_local := size.length() * scale
	var step := clampf(diag_local / 70.0, 1.5, 6.0)

	for index in range(canvas_points.size()):
		var source: PackedVector2Array = canvas_points[index]
		var local := PackedVector2Array()
		local.resize(source.size())
		for point_index in range(source.size()):
			local[point_index] = (source[point_index] - center) * scale + offset
		local = _resample_polyline(local, step)
		for point in local:
			local_min = local_min.min(point)
			local_max = local_max.max(point)
		_vector_strokes.append({
			"points": local,
			"width": clampf(float(widths[index]) * scale, 1.2, 12.0),
			"color": colors[index]
		})

	_stroke_bounds = Rect2(local_min, (local_max - local_min).max(Vector2(0.1, 0.1)))
	_mode = "vector"
	_set_body_visible(false)
	analysis = {
		"empty": false,
		"mode": "vector",
		"stroke_count": _vector_strokes.size(),
		"bounds": {
			"x": _stroke_bounds.position.x,
			"y": _stroke_bounds.position.y,
			"width": _stroke_bounds.size.x,
			"height": _stroke_bounds.size.y
		},
		"aspect_ratio": _stroke_bounds.size.x / maxf(0.001, _stroke_bounds.size.y)
	}


func _resample_polyline(points: PackedVector2Array, step: float) -> PackedVector2Array:
	if points.size() == 1:
		# Single tap: keep a tiny segment so the round caps render a dot.
		return PackedVector2Array([points[0], points[0] + Vector2(0.35, 0.0)])
	var total := 0.0
	for index in range(points.size() - 1):
		total += points[index].distance_to(points[index + 1])
	if total <= 0.001:
		return PackedVector2Array([points[0], points[0] + Vector2(0.35, 0.0)])

	var spacing := maxf(step, total / float(MAX_POINTS_PER_STROKE))
	var out := PackedVector2Array()
	out.append(points[0])
	var carried := 0.0
	for index in range(points.size() - 1):
		var from := points[index]
		var to := points[index + 1]
		var segment := from.distance_to(to)
		if segment <= 0.0001:
			continue
		var direction := (to - from) / segment
		var traveled := spacing - carried
		while traveled < segment:
			out.append(from + direction * traveled)
			traveled += spacing
		carried = fmod(carried + segment, spacing)
	if out[out.size() - 1].distance_to(points[points.size() - 1]) > 0.01:
		out.append(points[points.size() - 1])
	return out


# --- Bitmap fallback --------------------------------------------------------


func _build_bitmap_skin(drawing: Image) -> void:
	if drawing == null:
		analysis = {"empty": true, "reason": "drawing is null"}
		_mode = "none"
		return

	var image := drawing.duplicate()
	image.convert(Image.FORMAT_RGBA8)
	_make_paper_transparent(image)

	var visible_rect := _find_visible_rect(image)
	if visible_rect.size.x <= 0 or visible_rect.size.y <= 0:
		visible_rect = Rect2i(Vector2i.ZERO, image.get_size())

	var padded_rect := _rect_with_padding(visible_rect, image.get_size())
	var cropped: Image = image.get_region(padded_rect)

	analysis = {
		"empty": false,
		"mode": "bitmap",
		"source_size": [image.get_width(), image.get_height()],
		"bounds": {
			"x": visible_rect.position.x,
			"y": visible_rect.position.y,
			"width": visible_rect.size.x,
			"height": visible_rect.size.y
		}
	}

	_texture = ImageTexture.create_from_image(cropped)
	_apply_texture_to_body(cropped.get_size())
	_mode = "bitmap"


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


func _apply_texture_to_body(texture_size: Vector2i) -> void:
	_ensure_body()
	if _body == null:
		push_warning("%s has no Body Sprite2D to skin" % name)
		return

	var scale_x := _target_size.x / float(maxi(1, texture_size.x))
	var scale_y := _target_size.y / float(maxi(1, texture_size.y))
	_texture_scale = clampf(minf(scale_x, scale_y), 0.05, 1.0)

	_body.texture = _texture
	_body.centered = true
	_body.region_enabled = false
	_body.visible = true
	_body_base_position = Vector2.ZERO
	if _align == "bottom":
		_body_base_position.y = _ground_offset - float(texture_size.y) * _texture_scale * 0.5
	_body_base_scale = Vector2(_texture_scale, _texture_scale)
	reset_body_transform()


# --- Shared helpers ---------------------------------------------------------


func _ensure_body() -> void:
	if _body != null:
		return
	_body = get_node_or_null(body_node_path) as Sprite2D
	if _body == null:
		_body = find_child("Body", true, false) as Sprite2D


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
