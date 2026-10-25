class_name MayonBackdrop2D
extends Node2D
## One of Mayon's painted parallax bands: a plate off tools/build_mayon.py, repeated across the
## level and scrolling at its own rate.
##
## Like MakilingBackdrop2D it is one plate per node, driven by EnvironmentBaseplate through
## set_camera_origin and update_for_camera and sorted by `depth`. Unlike it, **it follows the
## camera UP as well as along**: Mayon is a climb, and a band pinned in the world would leave the
## screen as she rose. `rise_scale` is the vertical twin of `scroll_scale` -- 0 holds still with
## the camera, 1 is fixed in the world -- so the meadow at the volcano's foot sinks away below her
## as she climbs, and the volcano itself hardly moves.
##
## ⚠ EVERY PLATE IS PINNED BY ITS TOP EDGE at `plate_top`, untrimmed, so the bands keep the
## registration they were painted with. The tint is the band's own `modulate`, so a level can
## grade it as the light turns by tweening one property.

const FOLDER := "res://assets/Level5/backdrop/"
const PLATE_WIDTH := 1672.0

@export_enum("sky", "volcano", "meadow", "ground") var plate: String = "volcano"
## Along: 0 holds still with the camera (infinitely far); 1 moves with the world.
@export var scroll_scale: float = 0.08
## Up: the same, for height.
@export var rise_scale: float = 0.08
## EnvironmentBaseplate sorts by this; higher is further back.
@export var depth: float = 5.0
## The world x the camera can see across, start to end, for working out how many repeats.
@export var span := Vector2(0.0, 16000.0)
## Where the plate's top edge sits, measured from where the camera started.
@export var plate_top: float = -300.0
## Opaque plates were not drawn to tile: every other repeat is mirrored so a seam meets itself.
@export var mirrored := false
## The light on the band.
@export var tint := Color(1.0, 1.0, 1.0, 1.0)
## The viewport's width in world px at the camera's zoom, padded either side.
@export var view_width: float = 1800.0

var _origin := Vector2.ZERO
var _built := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	modulate = tint


func set_camera_origin(camera_position: Vector2) -> void:
	_origin = camera_position
	if not _built:
		_build()
	update_for_camera(camera_position)


func update_for_camera(camera_position: Vector2) -> void:
	var next := Vector2((camera_position.x - _origin.x) * (1.0 - scroll_scale),
		(camera_position.y - _origin.y) * (1.0 - rise_scale))
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
		push_warning("MayonBackdrop2D: no plate %s" % plate)
		return
	var drift := 1.0 - scroll_scale
	var low := span.x - view_width - (span.x - _origin.x) * drift
	var high := span.y + view_width - (span.y - _origin.x) * drift
	var from := floorf(low / PLATE_WIDTH)
	var to := ceilf(high / PLATE_WIDTH)
	for index in range(int(from), int(to) + 1):
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.position = Vector2(index * PLATE_WIDTH, plate_top)
		sprite.flip_h = mirrored and posmod(index, 2) == 1
		# The band's material (Mayon's drain) reaches every repeat.
		sprite.use_parent_material = true
		add_child(sprite)
