class_name MakilingBackdrop2D
extends Node2D
## One painted plane driven by EnvironmentBaseplate. Mirroring repeats joins each painted
## edge to itself. The mountain is a single landmark that drifts across the whole route.

const FOLDER := "res://assets/Level4/backdrop/"
const NIGHT_TINT := Color(0.34, 0.38, 0.55, 1.0)
const MORNING_TINT := Color(1.0, 0.98, 0.9, 1.0)

@export_enum("sky", "mountain_far", "mountain_near", "ground_far", "ground_near", "frame")
var plate: String = "mountain_far"
## Optional replacement plate. Repeats are spaced from the actual texture width.
@export var plate_texture: Texture2D
@export var plate_scale := Vector2.ONE
@export var repeat_plate := true
@export var mirror_repeats := false
## 0 holds still with the camera (infinitely far); 1 moves with the world; above 1 is in front.
@export var scroll_scale: float = 0.08
## EnvironmentBaseplate sorts by this; higher is further back.
@export var depth: float = 5.0
## The world x the camera can see across, start to end, for working out how many repeats.
@export var span := Vector2(0.0, 22800.0)
## Where the plate's top edge sits in the world.
@export var plate_top: float = -300.0
## The night: the day-painted plates are graded down to it.
@export var tint := NIGHT_TINT
## The viewport's width in world px at the camera's zoom, padded either side.
@export var view_width: float = 1800.0

var _origin := Vector2.ZERO
var _built := false
var _daylight := 0.0


## Restore the day-painted plates as dawn arrives; a white modulate alone cannot undo night.
func set_daylight(share: float) -> void:
	share = clampf(share, 0.0, 1.0)
	if is_equal_approx(share, _daylight):
		return
	_daylight = share
	for child in get_children():
		if child is Sprite2D:
			child.modulate = tint.lerp(MORNING_TINT, _daylight)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func set_camera_origin(camera_position: Vector2) -> void:
	_origin = camera_position
	if not _built:
		_build()
	update_for_camera(camera_position)


func update_for_camera(camera_position: Vector2) -> void:
	var next := Vector2((camera_position.x - _origin.x) * (1.0 - scroll_scale), 0.0)
	if position != next:
		position = next


## How many repeats it holds, for a probe.
func repeats() -> int:
	return get_child_count()


## The repeats needed so that every camera x across `span` sees plate, at this scroll rate.
func _build() -> void:
	_built = true
	var texture := plate_texture if plate_texture != null else load(FOLDER + plate + ".png") as Texture2D
	if texture == null:
		push_warning("MakilingBackdrop2D: no plate %s" % plate)
		return
	var tile_width := texture.get_width() * plate_scale.x
	var first := 0
	var last := 0
	if repeat_plate:
		var drift := 1.0 - scroll_scale
		var low := span.x - view_width - (span.x - _origin.x) * drift
		var high := span.y + view_width - (span.y - _origin.x) * drift
		first = floori(low / tile_width)
		last = floori(high / tile_width)
	var mirror := mirror_repeats or plate == "sky"
	for index in range(first, last + 1):
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.position = Vector2(index * tile_width, plate_top)
		sprite.scale = plate_scale
		sprite.flip_h = mirror and posmod(index, 2) == 1
		sprite.modulate = tint.lerp(MORNING_TINT, _daylight)
		add_child(sprite)
