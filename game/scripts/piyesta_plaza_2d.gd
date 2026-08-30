class_name PiyestaPlaza2D
extends Node2D
## The plaza, built from authored 8-bit pieces rather than pasted as one painting.
##
## ⚠ THE ONE RULE THIS EXISTS TO ENFORCE: THERE IS EXACTLY ONE GROUND LINE.
##
## The plaza used to be `Level2_CompletedLook` pasted in as a single picture with collision
## fitted underneath it. It never read right, and the reason is not the pasting -- it is that
## the painting is a wide painterly VISTA, a thing seen from one viewpoint, and a
## side-scroller needs a thing to walk along. That vista has a grass-topped retaining wall
## behind the dancers AND another one in front of them, so standing a character between them
## put two identical ledges on screen with a strip of ground between: *"the background has the
## platform and also the actual platform"*.
##
## So everything here stands ON `GROUND`. The buildings' feet are on it, the paving's top face
## is it, the collision's top is it, and the only thing drawn in front of the player is a KERB
## -- ankle height, not a second wall.
##
## THEME: THE BASILICA DEL SANTO NINO, CEBU. Coral stone in three tiers with the belfry beside
## it, bahay na bato along the street, an arcade, and Sinulog's red and gold overhead. The art
## is authored by `tools/build_plaza_art.py`; this places it.
##
## ⚠ THE SANTO NINO IS DRAWN AND NEVER BUILT. The image in the facade's niche is part of a
## texture. It owns no node, no area and no collision, which is the same rule
## `ChurchInterior2D` enforces indoors for the retablo. Nothing in this level may make it a
## thing to touch.

## Which half of the plaza this node draws. The kerb and its footing are nearer the viewer
## than the player is, so they cannot be in the same node as the buildings.
enum Layer { BACKDROP, FRONT }

@export var layer_kind: Layer = Layer.BACKDROP
## Where the player's feet go, in this node's own space. Everything is measured off it.
@export var ground := 0.0
## How far the plaza runs. The walls stand just outside these.
@export var from_x := 60.0
@export var to_x := 2600.0

## The sky, as a short ramp dithered down to the horizon.
## Off the painting: a vivid saturated blue, not the pale one I had guessed.
const SKY_HIGH := Color(0.059, 0.475, 0.831, 1.0)   # 0F79D4
const SKY_LOW := Color(0.604, 0.839, 0.992, 1.0)    # 9AD6FD
const HAZE := Color(0.745, 0.867, 0.961, 1.0)       # BEDDF5

## ⚠ THE COMPOSITION IS THE DELIVERED PAINTING'S, not a street of house fronts.
##
## The first authored pass laid out ten facades in a row, which is a corridor. The painting
## has a SHAPE: a raised bandstand at one end, the town along the middle with a garlanded arch
## over the dancers, the church and its belfry at the other end, and a market stall past it.
## That is what a plaza is, and it is what this follows -- in Sinulog's terms rather than
## Pahiyas's, so the arch is garlanded with red and gold and crowned with a starburst instead
## of woven palm and kiping.
##
## `at` is the x a piece's CENTRE sits on; its base always lands on the ground line.
const SKYLINE: Array[Dictionary] = [
	{"tile": "kiosko", "at": 200.0},
	{"tile": "townhouse_a", "at": 420.0},
	{"tile": "townhouse_b", "at": 660.0},
	{"tile": "townhouse_a", "at": 900.0},
	{"tile": "arch", "at": 1450.0},
	{"tile": "basilica", "at": 1900.0},
	{"tile": "belfry", "at": 2250.0},
	{"tile": "stall", "at": 2650.0},
]

## Palms, lamps and banner poles: what stops a plaza reading as a wall of buildings, and what
## the painting fills its middle distance with.
const DRESSING: Array[Dictionary] = [
	{"tile": "banner_pole", "at": 310.0},
	{"tile": "palm", "at": 1120.0},
	{"tile": "banner_pole", "at": 1250.0},
	{"tile": "palm", "at": 1330.0},
	{"tile": "palm", "at": 1580.0},
	{"tile": "lamp_post", "at": 1700.0},
	{"tile": "lamp_post", "at": 2100.0},
	{"tile": "banner_pole", "at": 2440.0},
	{"tile": "palm", "at": 2520.0},
]

## Hung from the lamp posts, in the Santo Nino's colours. The poles carry their own.
const BANNERS: Array[float] = [1700.0, 2100.0]


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 20 if layer_kind == Layer.FRONT else -100
	queue_redraw()


func _draw() -> void:
	if layer_kind == Layer.FRONT:
		_draw_kerb()
		return
	_draw_sky()
	_draw_clouds()
	_draw_hills()
	_draw_hedge()
	_draw_skyline()
	_draw_dressing()
	_draw_paving()


## A dithered ramp rather than a flat fill, so the sky belongs to the same idiom as
## everything drawn on it. Reaches well past the plaza because the camera does.
func _draw_sky() -> void:
	var top := ground - 1400.0
	var height := 1400.0
	var bands := 22
	for index in range(bands):
		var t := float(index) / float(bands - 1)
		var band := Color(
			lerpf(SKY_HIGH.r, SKY_LOW.r, t * t),
			lerpf(SKY_HIGH.g, SKY_LOW.g, t * t),
			lerpf(SKY_HIGH.b, SKY_LOW.b, t * t), 1.0)
		draw_rect(Rect2(from_x - 3000.0, top + height * t,
			(to_x - from_x) + 6000.0, height / float(bands) + 2.0), band)


## ⚠ THE PAINTING'S SKY IS HALF CLOUD. A flat blue gradient behind a warm town reads as a
## menu screen, which is most of why the first authored pass looked nothing like the plate.
## Two runs at different heights and sizes, the higher one paler, so the sky has depth.
func _draw_clouds() -> void:
	var band := PiyestaTiles.size_of("clouds_a")
	if band.y <= 0.0:
		return
	var left := from_x - 3000.0
	var wide := (to_x - from_x) + 6000.0
	# ⚠ INSIDE WHAT THE CAMERA ACTUALLY SEES. The first placement was a thousand units above
	# the ground line and the camera tops out around five hundred, so the sky had clouds in it
	# that nobody could ever look at.
	PiyestaTiles.fill_varied(self, Rect2(left, ground - 540.0, wide, band.y),
		["clouds_a", "clouds_b"], Color(1.0, 1.0, 1.0, 0.62))
	PiyestaTiles.fill_varied(self, Rect2(left + 300.0, ground - 400.0, wide, band.y),
		["clouds_b", "clouds_a"], Color(1.0, 1.0, 1.0, 0.95))


## Cebu's ridge behind the town, hazed by distance.
func _draw_hills() -> void:
	var hills := PiyestaTiles.size_of("hills")
	if hills.y <= 0.0:
		return
	# Hazed toward the sky and sat lower, so the ridge reads as distance rather than as a
	# green stripe pinned across the middle of the picture.
	PiyestaTiles.fill(self, Rect2(from_x - 3000.0, ground - hills.y - 46.0,
		(to_x - from_x) + 6000.0, hills.y), "hills", Color(0.80, 0.88, 0.92, 0.85))


## ⚠ EVERY BUILDING'S FEET ARE ON THE GROUND LINE. That is the whole fix: nothing stands on a
## second ledge behind the player, because there is no second ledge.
func _draw_skyline() -> void:
	for entry in SKYLINE:
		var name := String(entry["tile"])
		var size := PiyestaTiles.size_of(name)
		if size.y <= 0.0:
			continue
		PiyestaTiles.stand(self, name, Vector2(float(entry["at"]), ground + 4.0))
		# The shadow a building casts on the paving at its foot. Without it the facades look
		# stuck onto the ground rather than standing on it.
		draw_rect(Rect2(float(entry["at"]) - size.x * 0.5, ground, size.x, 7.0),
			Color(0.0, 0.0, 0.0, 0.28))


## Greenery along the plaza's back edge, behind everything built. The painting has it running
## the whole width and it is most of why that plaza looks planted rather than paved over.
func _draw_hedge() -> void:
	var hedge := PiyestaTiles.size_of("hedge")
	if hedge.y <= 0.0:
		return
	PiyestaTiles.run(self, Vector2(from_x - 600.0, ground - hedge.y + 8.0),
		(to_x - from_x) + 1200.0, "hedge")


func _draw_dressing() -> void:
	for entry in DRESSING:
		PiyestaTiles.stand(self, String(entry["tile"]),
			Vector2(float(entry["at"]), ground + 2.0))
	for at in BANNERS:
		PiyestaTiles.hang(self, "banner", Vector2(at + 26.0, ground - 268.0))
	# ⚠ PLANTING, AND A LOT OF IT. The painting has bushes and potted plants at the foot of
	# everything, and their absence was a large part of why the authored plaza read as bare.
	var at_x := from_x + 70.0
	var index := 0
	while at_x < to_x:
		var kind := "bush_b" if index % 4 == 1 else "bush_a"
		# Varied in size and settled a little into the paving, or a row of identical shrubs
		# at identical heights reads as a hedge somebody has stood on end.
		var scale := 0.78 + float((index * 29) % 7) * 0.07
		PiyestaTiles.stand(self, kind, Vector2(at_x, ground + 6.0), scale,
			Color(0.92, 0.96, 0.88, 1.0))
		at_x += 168.0 + float((index * 37) % 5) * 34.0
		index += 1


## The floor the player walks on. Its TOP FACE is the ground line, so what the collision says
## and what the picture says are the same number.
## ⚠ SHALLOW. The paving is the TOP FACE of the plaza, seen at a glancing angle, so it is a
## strip -- not a slab. Drawn a hundred and ninety deep it became a band as tall as the
## buildings, and with the kerb and the footing under it the bottom half of the screen was
## three stacked stripes of stone. The player is standing on a surface, not in front of one.
const PAVING_DEPTH := 38.0
const KERB_TOP := PAVING_DEPTH


func _draw_paving() -> void:
	var names: Array = ["paving_a", "paving_b", "paving_c"]
	PiyestaTiles.fill_varied(self, Rect2(from_x - 600.0, ground,
		(to_x - from_x) + 1200.0, PAVING_DEPTH), names)


## The kerb, and the footing under it. DELIBERATELY LOW: a full wall here is the second ledge
## that made the plaza unreadable, and a kerb says "the ground stops" without pretending to be
## somewhere else you could stand.
func _draw_kerb() -> void:
	var kerb := PiyestaTiles.size_of("kerb")
	if kerb.y <= 0.0:
		return
	var left := from_x - 600.0
	var width := (to_x - from_x) + 1200.0
	var top := ground + KERB_TOP
	PiyestaTiles.run(self, Vector2(left, top), width, "kerb")
	var wall := 128.0
	PiyestaTiles.fill(self, Rect2(left, top + kerb.y, width, wall), "retaining")
	# ⚠ AND THEN THE TOWN, BECAUSE THE CAMERA INSISTS. The vertical follow keeps the player
	# near the middle of the frame, so about four hundred units below their feet is always on
	# screen -- and four hundred units of retaining wall is a blank band across the bottom
	# third of every shot. The Basilica stands on high ground in a city; what is under the
	# plaza is the rest of the city.
	var roofs := PiyestaTiles.size_of("rooftops_a")
	var below := top + kerb.y + wall
	if roofs.y > 0.0:
		# Three cuts of roof, and each run further down is dimmer and bluer -- the town
		# receding. One cut repeated put the same roofline every 128 units, which at this
		# width is the same house nine times.
		var cuts: Array = ["rooftops_a", "rooftops_b", "rooftops_c"]
		for row in range(3):
			var t := float(row) / 2.0
			var haze := Color(0.62 + 0.20 * (1.0 - t), 0.70 + 0.16 * (1.0 - t),
				0.82 + 0.10 * (1.0 - t), 1.0)
			PiyestaTiles.fill_varied(self, Rect2(left + float(row) * 47.0,
				below + float(row) * roofs.y * 0.78, width, roofs.y),
				[cuts[row % 3], cuts[(row + 1) % 3], cuts[(row + 2) % 3]], haze)
	draw_rect(Rect2(left, below + roofs.y * 2.4, width, 900.0),
		Color(0.612, 0.741, 0.851, 1.0))
