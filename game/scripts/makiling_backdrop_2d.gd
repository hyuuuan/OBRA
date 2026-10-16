class_name MakilingBackdrop2D
extends Node2D
## One of Dilim's painted parallax bands: a Makiling plate, repeated across the level, scrolling at
## its own rate and graded to night.
##
## Like DagatBackdrop2D it is driven by EnvironmentBaseplate through set_camera_origin and
## update_for_camera, and sorted by `depth`. Unlike it, it is one plate per node: the Makiling
## plates are separate pictures (a far peak, a jungle, a vine frame), not one registered scene.
##
## ⚠ EVERY PLATE IS PINNED BY ITS TOP EDGE at `plate_top`, untrimmed (tools/build_dilim.py), so
## the bands keep the registration they were painted with. Opaque plates (the sky) are mirrored on
## every other repeat: they were not drawn to tile, and a mirrored seam meets itself.

const FOLDER := "res://assets/Level4/backdrop/"
const PLATE_WIDTH := 1672.0

@export_enum("sky", "mountain_far", "mountain_near", "ground_far", "ground_near", "frame")
var plate: String = "mountain_far"
## 0 holds still with the camera (infinitely far); 1 moves with the world; above 1 is in front.
@export var scroll_scale: float = 0.08
## EnvironmentBaseplate sorts by this; higher is further back.
@export var depth: float = 5.0
## The world x the camera can see across, start to end, for working out how many repeats.
@export var span := Vector2(0.0, 22800.0)
## Where the plate's top edge sits in the world.
@export var plate_top: float = -300.0
## The night: the day-painted plates are graded down to it.
@export var tint := Color(0.34, 0.38, 0.55, 1.0)
## The viewport's width in world px at the camera's zoom, padded either side.
@export var view_width: float = 1800.0

var _origin := Vector2.ZERO
var _built := false


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
	var texture := load(FOLDER + plate + ".png") as Texture2D
	if texture == null:
		push_warning("MakilingBackdrop2D: no plate %s" % plate)
		return
	var drift := 1.0 - scroll_scale
	var low := span.x - view_width - (span.x - _origin.x) * drift
	var high := span.y + view_width - (span.y - _origin.x) * drift
	var from := floorf(low / PLATE_WIDTH)
	var to := ceilf(high / PLATE_WIDTH)
	var opaque := plate == "sky"
	for index in range(int(from), int(to) + 1):
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.position = Vector2(index * PLATE_WIDTH, plate_top)
		sprite.flip_h = opaque and posmod(index, 2) == 1
		sprite.modulate = tint
		add_child(sprite)
