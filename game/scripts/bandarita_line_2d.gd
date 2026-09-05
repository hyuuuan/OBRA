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
## 2. **PROBLEM 3.** Two scraps are strung up in Alley 2's line, and whatever birds were
##    deferred out of Alley 1 are tangled in it. Climbing to them keeps the town; cutting
##    them down marks it.
## 3. **THE TRADE.** Cutting lifts the ceiling for the rest of the level, which is what
##    makes it a choice rather than a free win. *"The restriction was never an arbitrary
##    rule: it was an obstacle the player was always able to remove."*
##
## FOUR STATES, which is what the design asks the art for: intact, tangled with birds,
## being cut, removed. `cut` is a one-shot -- the flags fall, and after that the line is
## gone from this scene and from every scene after it.
##
## ⚠ THE PLAZA'S LINE IS PAINTED INTO THE BACKDROPS AND THIS ONE IS NOT.
## `BG_Clouds` and `FG_Huts` both have bunting drawn into them, which is why the design
## flags "no-bandarita variants of both" as required by the cut route. Until those land,
## cutting Alley 2's line cannot visibly change the plaza -- the plaza's bunting is paint.
## That is a known art debt, recorded in CONTENT_NEEDED.md, and it is exactly trap 2 of
## `ART_PLACEHOLDERS.md`: two bunting lines at different depths, one interactive and one
## not. This class is the interactive one and it is the only one this level reads.

## The line has come down. Carries how many scraps and how many birds it was holding, so
## the level does not have to ask twice.
signal cut(scraps: int, birds: int)
## Something strung up here has been reached -- climbed to rather than cut down.
signal reached(scraps: int, birds: int)

## How wide the run of bunting is. Set by whoever builds it, off the room's own length.
@export var span := 900.0
## How many painting scraps are pegged to it. Two in Alley 2, none anywhere else.
@export var scraps_held := 0
## How many birds are tangled in it. Written by Problem 2 -- zero if they were fed, five if
## they were chased, and whatever the timer did not reach on the Protector route.
@export var birds_tangled := 0
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
## A scrap of the painting, pegged up. Canvas, not paper -- it has to read as a different
## material from the flags around it or it is one more flag.
const SCRAP := Color(0.878, 0.827, 0.729, 1.0)      # E0D3BA
const SCRAP_EDGE := Color(0.678, 0.616, 0.502, 1.0) # AD9D80
const SCRAP_INK := Color(0.404, 0.475, 0.522, 1.0)  # 677985
## A bird caught in the strings. Dark, and it moves, which is what tells them apart from
## the flags at a glance.
const BIRD := Color(0.208, 0.204, 0.216, 1.0)       # 353437
const BIRD_LIT := Color(0.353, 0.345, 0.365, 1.0)   # 5A585D

## Drives the sway and the tangled birds' struggling.
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
	return intact


## Everything strung up here, without taking it down. Problem 3's Artist route: the town
## keeps its bunting and the player climbs.
func take_what_is_up_here() -> int:
	var taken := scraps_held + birds_tangled
	scraps_held = 0
	birds_tangled = 0
	reached.emit(taken, 0)
	queue_redraw()
	return taken


## Problem 3's Protector route, and the one player action in this level that permanently
## changes the town. Everything on the line comes down with it -- neither route can lose a
## scrap, which the design states outright.
func cut_it_down() -> int:
	if not intact or _falling > 0.0:
		return 0
	var scraps := scraps_held
	var birds := birds_tangled
	scraps_held = 0
	birds_tangled = 0
	_falling = 0.001
	cut.emit(scraps, birds)
	return scraps + birds


func is_falling() -> bool:
	return _falling > 0.0 and _falling < 1.0


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
	var sag := 26.0
	var points := PackedVector2Array()
	for index in range(count + 1):
		var t := float(index) / float(count)
		var x := -span * 0.5 + t * span
		var y := sin(t * PI) * sag + sin(_drift * 0.8 + t * 4.0) * 3.0
		points.append(Vector2(x, y + fall * 220.0 * t))
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
	_draw_the_scraps(points)
	_draw_the_birds(points)


## Pegged along the run, evenly, so two scraps on a nine-metre line are found rather than
## stumbled over.
func _draw_the_scraps(points: PackedVector2Array) -> void:
	if scraps_held <= 0 or points.size() < 2:
		return
	for index in range(scraps_held):
		var t := (float(index) + 1.0) / float(scraps_held + 1)
		var at := points[clampi(int(t * float(points.size() - 1)), 0, points.size() - 1)]
		var rect := Rect2(at + Vector2(-22.0, 6.0), Vector2(44.0, 52.0))
		draw_rect(rect.grow(2.0), SCRAP_EDGE)
		draw_rect(rect, SCRAP)
		# A little of the picture on it, so it reads as a piece of a painting rather than as
		# a blank card.
		draw_rect(Rect2(rect.position + Vector2(4.0, 26.0), Vector2(36.0, 12.0)), SCRAP_INK)
		draw_rect(Rect2(rect.position + Vector2(4.0, 8.0), Vector2(16.0, 10.0)), SCRAP_INK)


## And whatever came through from Alley 1. They struggle, which is the only movement on the
## line and therefore the thing the eye finds first.
func _draw_the_birds(points: PackedVector2Array) -> void:
	if birds_tangled <= 0 or points.size() < 2:
		return
	for index in range(birds_tangled):
		var t := (float(index) + 0.5) / float(birds_tangled)
		var at := points[clampi(int(t * float(points.size() - 1)), 0, points.size() - 1)]
		var flap := sin(_drift * 6.0 + float(index) * 1.7) * 7.0
		draw_rect(Rect2(at + Vector2(-11.0, 4.0), Vector2(22.0, 15.0)), BIRD)
		# One wing up and one down, out of phase, which is a struggle rather than a flight.
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(-9.0, 8.0), at + Vector2(-26.0, 8.0 - flap),
			at + Vector2(-9.0, 15.0)]), BIRD_LIT)
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(9.0, 8.0), at + Vector2(26.0, 8.0 + flap),
			at + Vector2(9.0, 15.0)]), BIRD_LIT)
