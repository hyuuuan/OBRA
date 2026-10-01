class_name BandaritaLine2D
extends Node2D
## The bunting, and it is three things at once.
##
## 1. **THE CEILING.** The design's flight rule is not a number somebody chose -- *"the
##    ceiling is the bandarita line itself, set per scene... the player is not stopped by an
##    invisible wall, they are stopped by the strings that are visibly in the way. The
##    warning band should be drawn at the bandarita line so the boundary is the art, not a
##    HUD element."* So the line owns its own Y and the level reads the ceiling off it. A
##    scene with no line has no ceiling, which is the correct answer and not an oversight.
## 2. **WHERE THE FLOCK NESTS.** The birds carrying the painting's pieces fly the alley and go
##    back to their nests in the bunting between flights. One of the three ways to get the
##    pieces is to get up to the line and cut it down: the nests come down with it and the
##    birds bolt, dropping what they carry.
## 3. **THE TRADE.** Cutting a line lifts that scene's ceiling, which is what makes it a
##    choice rather than a free win. *"The restriction was never an arbitrary rule: it was an
##    obstacle the player was always able to remove."* It is also the one player action in the
##    level that permanently changes the town.
##
## ⚠ THE PLAZA'S LINE IS PAINTED INTO THE BACKDROP AND THIS ONE IS NOT. `BG_Clouds` and
## `FG_Huts` both have bunting drawn into them, which is why the design flags "no-bandarita
## variants of both" as required by the cut route. The alleys' lines are this class and the
## only ones a player can cut.

## The line has come down.
signal cut()

## How wide the run of bunting is. Set by whoever builds it, off the room's own length.
@export var span := 900.0
## How many nests are in it. Birds are handed one each; two can share.
@export var nest_count := 3
## Whether the strings are still up.
@export var intact := true

## THE CEILING SITS JUST UNDER THE STRINGS, not at them: a flier at exactly the line has not
## crossed anything, and a boundary that triggers where the art is drawn reads as the art
## being a hitbox. Twenty pixels is a quarter of the apo's height.
const CEILING_DROP := 20.0
## How far below the line the flags hang, which is what a player actually sees and ducks.
const FLAG_DROP := 34.0
## Flag spacing along the run. Close enough to read as bunting, far enough not to be a wall.
const FLAG_STEP := 52.0
## The catenary's sag at the middle of the run.
const SAG := 26.0

## Fiesta bunting is printed paper in four or five colours, repeating.
const FLAGS: Array[Color] = [
	Color(0.898, 0.286, 0.263, 1.0),   # E54943  red
	Color(0.961, 0.741, 0.239, 1.0),   # F5BD3D  yellow
	Color(0.318, 0.643, 0.804, 1.0),   # 51A4CD  blue
	Color(0.482, 0.741, 0.376, 1.0),   # 7BBD60  green
	Color(0.898, 0.529, 0.239, 1.0),   # E5873D  orange
]
const STRING := Color(0.302, 0.267, 0.220, 1.0)     # 4D4438
const STRING_LIT := Color(0.475, 0.427, 0.353, 1.0) # 796D5A
## A nest: dry grass and twigs, darker underneath, so it reads against the flags as a THING
## caught in the bunting rather than as one more pennant.
const NEST := Color(0.541, 0.431, 0.278, 1.0)       # 8A6E47
const NEST_DARK := Color(0.337, 0.259, 0.161, 1.0)  # 564229
const NEST_LIT := Color(0.690, 0.580, 0.400, 1.0)   # B09466

## Drives the sway.
var _drift := 0.0
## How far through the cut it is, 0 to 1. The one-shot the design calls "being cut".
var _falling := 0.0


func _ready() -> void:
	add_to_group(&"bandarita_lines")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(true)


func _process(delta: float) -> void:
	_drift += delta
	if _falling > 0.0 and _falling < 1.0:
		_falling = minf(1.0, _falling + delta * 1.4)
		if _falling >= 1.0:
			intact = false
	queue_redraw()


## The world Y the flight rule reads. Just under the strings -- see CEILING_DROP.
func ceiling_y() -> float:
	return global_position.y + CEILING_DROP


## Whether this line still stops anything. A cut line does not.
func still_a_ceiling() -> bool:
	return intact and _falling <= 0.0


## Where the string is at `t` along the run (0 at one wall, 1 at the other), in this node's
## space, sag and sway and all.
func _string_at(t: float) -> Vector2:
	var x := -span * 0.5 + t * span
	var y := sin(t * PI) * SAG + sin(_drift * 0.8 + t * 4.0) * 3.0
	return Vector2(x, y + _falling * 220.0 * t)


func _nest_t(index: int) -> float:
	return (float(index % maxi(1, nest_count)) + 1.0) / float(maxi(1, nest_count) + 1)


## Where a bird sits on nest `index`, globally: on top of it, on the string. Asked every frame
## by a bird on it, because the line sways.
func nest_point(index: int) -> Vector2:
	return to_global(_string_at(_nest_t(index)) + Vector2(0.0, -9.0))


## How far `point` (global) is from the string, which is what a cutting edge has to reach.
func reach_distance(point: Vector2) -> float:
	var local := to_local(point)
	var best := INF
	var steps := maxi(8, int(span / 24.0))
	var previous := _string_at(0.0)
	for index in range(1, steps + 1):
		var here := _string_at(float(index) / float(steps))
		best = minf(best, Geometry2D.get_closest_point_to_segment(local, previous, here)
			.distance_to(local))
		previous = here
	return best


## The middle of the run, globally: what the objective points at when the strings are the
## thing to reach.
func middle() -> Vector2:
	return to_global(_string_at(0.5))


## The cut route, and the one player action in this level that changes the town for good. The
## nests come down with the strings, and the level scatters whatever is living in them.
func cut_it_down() -> bool:
	if is_cut():
		return false
	_falling = 0.001
	cut.emit()
	return true


## Down, or on its way down.
func is_cut() -> bool:
	return not intact or _falling > 0.0


func is_falling() -> bool:
	return _falling > 0.0 and _falling < 1.0


## Set straight to down, for a restore after it was cut: without replaying the fall.
func set_already_cut() -> void:
	_falling = 1.0
	intact = false
	queue_redraw()


## Strung again, for a restore to before it was cut.
func put_back_up() -> void:
	_falling = 0.0
	intact = true
	queue_redraw()


func _draw() -> void:
	if not intact and _falling >= 1.0:
		# The pegs stay in the wall. An empty line is the scene telling a player who comes
		# back that something used to be strung here, which "nothing at all" cannot say.
		for side: float in [-1.0, 1.0]:
			draw_rect(Rect2(side * span * 0.5 - 4.0, -10.0, 8.0, 20.0), STRING)
		return
	var fall := _falling
	var count := int(span / FLAG_STEP)
	# The catenary. A string strung between two points sags, and a straight line across the
	# top of a scene reads as a HUD element -- which is the one thing the design says this
	# must not be.
	var points := PackedVector2Array()
	for index in range(count + 1):
		points.append(_string_at(float(index) / float(count)))
	draw_polyline(points, STRING, 3.0)
	draw_polyline(points, STRING_LIT, 1.0)
	for index in range(count):
		var at := points[index]
		var colour := FLAGS[index % FLAGS.size()]
		if fall > 0.0:
			colour.a = 1.0 - fall * 0.5
		# A pennant: two corners on the string and a point below it.
		draw_colored_polygon(PackedVector2Array([
			at, at + Vector2(FLAG_STEP * 0.8, 0.0),
			at + Vector2(FLAG_STEP * 0.4, FLAG_DROP)]), colour)
	for index in range(nest_count):
		_draw_nest(_string_at(_nest_t(index)))


## A cup of grass hung on the string: dark underside, lit rim, a few stray stalks.
func _draw_nest(at: Vector2) -> void:
	var cup := PackedVector2Array([
		at + Vector2(-14.0, -3.0), at + Vector2(14.0, -3.0), at + Vector2(10.0, 7.0),
		at + Vector2(-10.0, 7.0)])
	draw_colored_polygon(cup, NEST)
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-11.0, 3.0), at + Vector2(11.0, 3.0), at + Vector2(10.0, 7.0),
		at + Vector2(-10.0, 7.0)]), NEST_DARK)
	draw_line(at + Vector2(-15.0, -3.0), at + Vector2(15.0, -3.0), NEST_LIT, 2.0)
	for stalk: Vector2 in [Vector2(-16.0, -1.0), Vector2(12.0, 5.0), Vector2(4.0, 8.0)]:
		draw_line(at + stalk, at + stalk + Vector2(signf(stalk.x) * 5.0, 2.0), NEST_DARK, 1.0)
