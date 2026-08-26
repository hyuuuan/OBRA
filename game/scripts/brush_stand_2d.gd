class_name BrushStand2D
extends Area2D
## The case at the end of the hall, with Lola's brush under the glass.
##
## THE GAME HAS TO HAND THE PLAYER ITS VERB. Everything in O.B.R.A. is done by drawing, and
## until this existed the apo walked into Payyo already able to do it, with no moment where
## anyone gave them anything. So the wall of paintings runs on past the fifth picture into a
## stretch of bare end wall with one thing standing on it: her brush, in its case. You walk
## up, you press E, and it comes to you. That is the first thing that happens in this game.
##
## It is the same brush the HUD then shows draining in every level -- `InkBrush` draws that
## gauge from the sheets this case's artwork was cut from. One object, taken once, carried
## everywhere.
##
## ONE PIECE OF ART, TWO STATES. `brush_container.png` is a glass case: a gold plinth, a
## bell dome over it in white keyline, and the brush hanging inside among sparks. The sheet
## separates along one horizontal line -- the bottom eight art pixels are the plinth,
## everything above them is dome and contents -- so the taken state costs no second export.
## The case gives up what is in it and the plinth stays, which is what an emptied display
## case in a hall looks like.
##
## THE DOME GOES WITH THE BRUSH, and that is a decision rather than a shortcut. The two
## share pixels on the sheet -- the glass runs behind and around the brush, and the smallest
## rectangle holding the brush swallows a fifth of the glass with it -- so there is no way
## to lift one and leave the other without a second drawing nobody has made. It reads well
## anyway: the case dissolves as the brush comes to the apo, which is a better beat than a
## glass box left standing with a hole in it.
##
## NOTHING HERE ANIMATES ON ITS OWN. An earlier pass had the dome breathing gently on a
## sine, which is what you would do for a brush hanging in mid-air and is exactly wrong for
## one under glass: it floated the case off its own plinth. The sparks are in the artwork,
## the movement is the take, and the room photographs the same every time.

## Emitted once, when the apo takes it. The house listens and opens the paintings.
signal taken

const SHEET: Texture2D = preload("res://assets/hud/brush_container.png")

## The artwork's own grid. The sheet is 384 square with the case drawn on a six-pixel
## pixel, and the region below is measured in those pixels rather than in sheet pixels so
## nothing here can land off the grid.
const ART_PIXEL := 6.0
## The whole case, in art pixels, measured from the top-left of the sheet.
const ART_ORIGIN := Vector2i(13, 4)
const ART_SIZE := Vector2i(38, 52)
## How many rows off the bottom of that are the plinth. The rest is dome and contents.
const PLINTH_ROWS := 8

## World pixels to the art pixel. Three, which at the house's camera zoom of 2 puts six
## screen pixels on every pixel the artist drew, and makes the case 114 wide by 156 tall.
##
## SIZED AGAINST THE APO, who is 96 tall and about 40 across. This is a floor object and the
## apo walks in front of it, so anything near their own width is a thing they stand on top
## of and hide: at two pixels to the art pixel the case came out 76 wide and the child
## covered it. At three it is half again their height and nearly three times their width, so
## the plinth shows either side of them and the dome stands clear over their head -- which
## is also simply what a case in a hall looks like next to a child.
const SCALE := 3

## How far ALONG THE WALL the apo has to be for the case to answer. The same reach a
## painting has, for the same reason: you stand in front of a thing to take it, and the
## prompt should not carry halfway down an empty wall.
@export var reach: float = 110.0

var _holds_brush := true
## The take: the dome rises a little and dissolves, and the brush goes with it.
##
## REDRAWN FROM THE SETTER rather than from a _process that runs forever. A Tween writes
## through the setter, so these two repaint the case exactly on the frames they change and
## on no others -- which is what lets this node have no idle work at all.
var _lift := 0.0:
	set(value):
		_lift = value
		queue_redraw()
var _fade := 1.0:
	set(value):
		_fade = value
		queue_redraw()
var _plate: Label


func _ready() -> void:
	add_to_group(&"brush_stand")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	monitoring = false
	monitorable = false
	var profile := get_node_or_null(^"/root/PlayerProfile")
	_holds_brush = profile == null or not bool(profile.call("has_brush"))
	if not _holds_brush:
		_fade = 0.0
	# The area exists only so the room can measure to it cheaply; nothing collides with a
	# case, the same way nothing collides with a painting.
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(ART_SIZE) * float(SCALE)
	shape.shape = box
	shape.position = Vector2(0.0, -box.size.y * 0.5)
	add_child(shape)
	_build_plate()
	queue_redraw()


## Whether the brush is still under the glass. The room asks before it offers the prompt.
func holds_brush() -> bool:
	return _holds_brush


func distance_to_point(point: Vector2) -> float:
	return absf(point.x - global_position.x)


func within_reach(point: Vector2) -> bool:
	return distance_to_point(point) <= reach


## Walked up to and pressed E on. Idempotent: a second press on an emptied case is a no-op
## rather than a second acquisition, because the room still offers the prompt for the frame
## in which the take begins.
func take() -> void:
	if not _holds_brush:
		return
	_holds_brush = false
	var profile := get_node_or_null(^"/root/PlayerProfile")
	if profile != null:
		profile.call("record_brush_acquired")
	_write_plate()
	# THE DISSOLVE IS THE EVENT, not the lift. A glass case that flies off the top of the
	# screen reads as something going wrong; one that rises a hand's breadth and fades reads
	# as it opening. So the travel is small and the fade carries it.
	#
	# The tween drives only the drawing. `taken` fires now, because nothing downstream
	# should wait on an animation to know the brush has been picked up -- the profile is
	# already written and the paintings are already open.
	var opening := create_tween()
	opening.set_parallel(true)
	opening.tween_property(self, "_lift", 26.0, 0.6) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	opening.tween_property(self, "_fade", 0.0, 0.5).set_delay(0.14)
	taken.emit()
	queue_redraw()


func _draw() -> void:
	var plinth_top := -float(PLINTH_ROWS * SCALE)
	# The plinth, always. Its base sits on this node's origin, which is the floor line, so
	# the room places the case by standing it on the ground rather than by guessing a centre.
	_blit(ART_SIZE.y - PLINTH_ROWS, ART_SIZE.y, Vector2(0.0, plinth_top), Color.WHITE)
	if _fade <= 0.0:
		return
	# Everything above the plinth: the dome, the brush inside it, and the sparks around it.
	var dome := plinth_top - float((ART_SIZE.y - PLINTH_ROWS) * SCALE) - _lift
	_blit(0, ART_SIZE.y - PLINTH_ROWS, Vector2(0.0, dome), Color(1.0, 1.0, 1.0, _fade))


## Blit art rows [from, to) with the given top-left, centred on this node horizontally.
func _blit(from: int, to: int, at: Vector2, modulate: Color) -> void:
	if to <= from:
		return
	var source := Rect2(
		Vector2(ART_ORIGIN) * ART_PIXEL + Vector2(0.0, float(from) * ART_PIXEL),
		Vector2(float(ART_SIZE.x) * ART_PIXEL, float(to - from) * ART_PIXEL))
	var target := Rect2(
		at - Vector2(float(ART_SIZE.x * SCALE) * 0.5, 0.0),
		Vector2(float(ART_SIZE.x * SCALE), float((to - from) * SCALE)))
	draw_texture_rect_region(SHEET, target, source, modulate)


## The brass plate, the same one the pictures wear, because this stands against the same
## wall and a gallery labels what it is showing. It is also the only place the house says in
## words what the thing under the glass is.
func _build_plate() -> void:
	_plate = Label.new()
	_plate.name = "Plate"
	_plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plate.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	_plate.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	_plate.add_theme_constant_override(&"shadow_offset_x", 2)
	_plate.add_theme_constant_override(&"shadow_offset_y", 2)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Half size, in a room the camera draws at double -- see Painting2D._build_plate, which
	# carries the full account of why this is scaled rather than set to a smaller font, and
	# why it is measured only after it is in the tree.
	_plate.scale = Vector2(0.5, 0.5)
	add_child(_plate)
	_write_plate()


func _write_plate() -> void:
	if _plate == null:
		return
	_plate.text = "LOLA'S BRUSH" if _holds_brush else "LOLA'S BRUSH  —  TAKEN"
	_plate.add_theme_color_override(&"font_color",
		UISkin.GILT_HI if _holds_brush else UISkin.GILT_DARK)
	_plate.size = Vector2(float(ART_SIZE.x * SCALE) * 2.0, 28.0)
	# Centred on the width it GOT rather than the width it asked for, and set on the floor
	# at the foot of the plinth, where the plate in front of a case goes.
	_plate.position = Vector2(-_plate.size.x * _plate.scale.x * 0.5, 8.0)
