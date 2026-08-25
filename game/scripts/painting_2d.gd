class_name Painting2D
extends Area2D
## One of Lola's paintings, hanging in the house, and the way into the level it is of.
##
## THE LEVEL SELECT IS A ROOM, not a menu. Every level in this game is somewhere Lola
## painted, so the place you choose one from is her house, and what you choose is the
## picture. A grid of cards with the same five images on it would say the same thing and
## mean none of it.
##
## A LOCKED PAINTING IS STILL A PAINTING. It hangs, it is lit, you can walk up to it and
## read its name -- it simply is not finished being a place you can go yet. Hiding the four
## that are not built would leave one picture on a long wall and no sense of what the game
## is; greying them out would say "disabled button". They are dimmed the way a picture in a
## dark corner is dimmed, and the plate underneath says so in words.

signal chosen(level_id: String)

## Which level this is a painting of. The catalog is asked about it rather than the node
## carrying its own copy of the title -- one list of levels, in config/levels.json.
@export var level_id: String = ""
## The painting, at the size it hangs. Set by the room from the level id.
@export var art: Texture2D
## What the little brass plate under it says.
@export var plate_text: String = ""
## How wide the gilt moulding is around the picture. Eight, against a picture 128 wide: a
## frame is a hand's breadth of gold round the edge of a canvas, not a border round it.
@export var moulding: float = 8.0
## How far ALONG THE WALL the apo has to be standing for this painting to answer.
##
## Horizontal only, because you stand under a picture to look at it, not next to it. Judged
## as a straight distance to the painting's middle -- which is what it was first -- the apo
## is a room's height below it at all times and no painting ever answers.
##
## Under half the gap between two pictures, so that standing at one never reaches the next.
## run_hub_audit asserts exactly that, from where the apo actually stands.
@export var reach: float = 110.0

var _playable := false
var _art_size := Vector2(128.0, 72.0)


func _ready() -> void:
	add_to_group(&"paintings")
	monitoring = false
	monitorable = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if art != null:
		_art_size = art.get_size()
	var manager := get_node_or_null(^"/root/LevelManager")
	_playable = manager != null and bool(manager.call("is_playable", level_id))
	# The reach is an Area2D only so the room can find the nearest one cheaply; nothing
	# collides with a painting.
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = _art_size + Vector2.ONE * moulding * 2.0
	shape.shape = box
	add_child(shape)
	_build_plate()
	queue_redraw()


## The little brass plate under the picture, which is where a gallery puts the name and is
## the only place in this room that says a level is not finished yet. Saying it in words
## beats greying the picture out: dimmed art reads as "disabled", a plate reads as a label.
func _build_plate() -> void:
	var plate := Label.new()
	plate.name = "Plate"
	plate.text = plate_text if _playable else "%s  —  NOT YET PAINTED" % plate_text
	plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	plate.add_theme_color_override(&"font_color",
		UISkin.GILT_HI if _playable else UISkin.GILT_DARK)
	plate.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	plate.add_theme_constant_override(&"shadow_offset_x", 2)
	plate.add_theme_constant_override(&"shadow_offset_y", 2)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# HALF SIZE, IN A ROOM THE CAMERA DRAWS AT DOUBLE. The plate hangs on the wall, so it is
	# in world space and the hub's zoom of 2 applies to it: at the caption size it came out
	# forty screen pixels tall, which is HUD lettering on a brass plate the size of a hand.
	# Halved, it reads at the size the label under a picture in a gallery reads at -- and it
	# lands back on whole screen pixels, because the caption size is two font units and half
	# of it is one, which is the rule HUD_SKIN.md gives for keeping a pixel face crisp.
	plate.scale = Vector2(0.5, 0.5)
	var width := (_art_size.x + moulding * 4.0) * 2.0
	plate.size = Vector2(width, 28.0)
	plate.position = Vector2(-width * 0.25, _art_size.y * 0.5 + moulding + 6.0)
	add_child(plate)


func is_playable() -> bool:
	return _playable


## How far the apo is from this painting, measured to its middle. The room uses it to pick
## which one the prompt belongs to.
func distance_to_point(point: Vector2) -> float:
	return absf(point.x - global_position.x)


func within_reach(point: Vector2) -> bool:
	return distance_to_point(point) <= reach


## Walked up to and pressed E on.
func choose() -> void:
	chosen.emit(level_id)


func _draw() -> void:
	var half := _art_size * 0.5
	var picture := Rect2(-half, _art_size)
	# The picture first, then the moulding over its edge, so the frame sits on the painting
	# rather than beside it.
	if art != null:
		draw_texture_rect(art, picture, false,
			Color.WHITE if _playable else Color(0.42, 0.40, 0.44, 1.0))
	else:
		draw_rect(picture, UISkin.PANEL)
	_draw_moulding(picture)


## A rectangular gilt moulding, stepped rather than smooth: four bands, lighter on the top
## and left where the light is and darker on the bottom and right, with a keyline round
## both edges. The oval on the canvas is the same gold and the same light; this is its
## square cousin, because a picture frame on a wall is square and a mirror is not.
func _draw_moulding(picture: Rect2) -> void:
	var bands := 4
	var step := moulding / float(bands)
	for band in range(bands):
		var inset := step * float(band)
		var rect := picture.grow(inset + step)
		# Across the moulding: brightest at the crown, which is the middle.
		var crown := 1.0 - absf(float(band) / float(bands - 1) * 2.0 - 1.0)
		var thickness := step
		# Top and left catch the light; bottom and right are in shadow.
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, thickness)), _tone(0.86, crown))
		draw_rect(Rect2(rect.position, Vector2(thickness, rect.size.y)), _tone(0.78, crown))
		draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - thickness),
			Vector2(rect.size.x, thickness)), _tone(0.16, crown))
		draw_rect(Rect2(Vector2(rect.end.x - thickness, rect.position.y),
			Vector2(thickness, rect.size.y)), _tone(0.24, crown))
	draw_rect(picture.grow(1.0), UISkin.GILT_EDGE, false, 1.0)
	draw_rect(picture.grow(moulding), UISkin.GILT_EDGE, false, 1.0)


## `lit` is how much this side faces the light, 0 to 1. Same ramp the canvas frame uses, so
## the gold in the house and the gold round the canvas are the same gold.
func _tone(lit: float, crown: float) -> Color:
	var ramp: Array[Color] = [UISkin.GILT_EDGE, UISkin.GILT_DARK, UISkin.GILT_MID,
		UISkin.GILT, UISkin.GILT_LIT, UISkin.GILT_HI]
	var step := int(round(clampf(lit * 0.68 + crown * 0.40, 0.0, 1.0) * float(ramp.size() - 1)))
	var colour := ramp[step]
	# A painting you cannot walk into yet keeps its frame, dimmed with it.
	return colour if _playable else colour.darkened(0.45)
