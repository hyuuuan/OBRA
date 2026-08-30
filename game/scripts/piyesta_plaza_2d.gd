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
const SKY_HIGH := Color(0.180, 0.494, 0.800, 1.0)   # 2E7ECC
const SKY_LOW := Color(0.588, 0.867, 0.976, 1.0)    # 96DDF9
const HAZE := Color(0.745, 0.867, 0.961, 1.0)       # BEDDF5

## What stands along the street, west to east, as {tile, at, base_offset}. `at` is the x its
## CENTRE sits on; the base always lands on the ground line.
##
## The order is deliberate: houses, then the Basilica with its belfry, then the arcade that
## runs along the pilgrim courtyard, then more houses. A town has a middle.
const SKYLINE: Array[Dictionary] = [
	{"tile": "townhouse_a", "at": 260.0},
	{"tile": "townhouse_b", "at": 520.0},
	{"tile": "townhouse_a", "at": 800.0},
	{"tile": "basilica", "at": 1180.0},
	{"tile": "belfry", "at": 1500.0},
	{"tile": "arcade", "at": 1700.0},
	{"tile": "arcade", "at": 1844.0},
	{"tile": "arcade", "at": 1988.0},
	{"tile": "townhouse_b", "at": 2200.0},
	{"tile": "townhouse_a", "at": 2440.0},
]

## Palms and lamps, which are what stops a street of facades reading as a wall of facades.
const DRESSING: Array[Dictionary] = [
	{"tile": "palm", "at": 400.0},
	{"tile": "lamp_post", "at": 640.0},
	{"tile": "palm", "at": 960.0},
	{"tile": "lamp_post", "at": 1340.0},
	{"tile": "palm", "at": 1620.0},
	{"tile": "lamp_post", "at": 2080.0},
	{"tile": "palm", "at": 2320.0},
]

## Banners hung from the lamp posts, in the Santo Nino's colours.
const BANNERS: Array[float] = [640.0, 1340.0, 2080.0]


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 20 if layer_kind == Layer.FRONT else -100
	queue_redraw()


func _draw() -> void:
	if layer_kind == Layer.FRONT:
		_draw_kerb()
		return
	_draw_sky()
	_draw_hills()
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


## Cebu's ridge behind the town, hazed by distance.
func _draw_hills() -> void:
	var hills := PiyestaTiles.size_of("hills")
	if hills.y <= 0.0:
		return
	PiyestaTiles.fill(self, Rect2(from_x - 3000.0, ground - hills.y - 118.0,
		(to_x - from_x) + 6000.0, hills.y), "hills", Color(1.0, 1.0, 1.0, 0.92))


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


func _draw_dressing() -> void:
	for entry in DRESSING:
		PiyestaTiles.stand(self, String(entry["tile"]),
			Vector2(float(entry["at"]), ground + 2.0))
	for at in BANNERS:
		PiyestaTiles.hang(self, "banner", Vector2(at + 26.0, ground - 268.0))


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
	var roofs := PiyestaTiles.size_of("rooftops")
	var below := top + kerb.y + wall
	if roofs.y > 0.0:
		for row in range(3):
			# Each run further down is smaller, dimmer and bluer: the town receding.
			var t := float(row) / 2.0
			var haze := Color(0.62 + 0.20 * (1.0 - t), 0.70 + 0.16 * (1.0 - t),
				0.82 + 0.10 * (1.0 - t), 1.0)
			PiyestaTiles.fill(self, Rect2(left, below + float(row) * roofs.y * 0.82,
				width, roofs.y), "rooftops", haze)
	draw_rect(Rect2(left, below + roofs.y * 2.5, width, 900.0),
		Color(0.612, 0.741, 0.851, 1.0))
