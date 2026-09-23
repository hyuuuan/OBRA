class_name DagatBackdrop2D
extends Node2D
## Dagat's painted parallax, in three bands: the shore by day, the sea under a storm, and
## the deep. One node per band, each building its own stack of layers from the manifest
## tools/build_dagat.py writes.
##
## WHY A NODE AND NOT TWENTY SPRITES IN THE SCENE. The delivered art is 1672px wide and the
## level is 5400, so every layer has to repeat; each layer scrolls at its own rate; and four
## of them are animations. Authored by hand that is sixty-odd scene nodes whose z-order,
## parallax factor and frame timing all have to agree with each other, and the first one
## somebody nudges in the editor is the one that breaks registration. Here the stack is a
## table with a reason beside each row.
##
## ⚠ THE LAYERS ARE REGISTERED TO EACH OTHER BY THEIR MARGINS, so every one of them is drawn
## on the same 1672x941 plate and pinned by the SAME top edge. `plate_top` is where that edge
## sits in the world, and it is derived from the art rather than chosen: the shore's sand
## surface is at plate-y 790 and the apo stands at y 560, so the plate's top is at -230.
## Moving one layer's y independently is how a horizon leaves its own waterline.
##
## Parallax comes for free: EnvironmentBaseplate drives anything with set_camera_origin and
## update_for_camera, which is the same hook DepthLayer2D uses.

const MANIFEST := "res://assets/Level3/dagat.json"
## Authored by tools/build_dagat_props.py, not cut from the delivery. See that tool's header.
const SHELF_FILL := "res://assets/Level3/authored/shelf_fill.png"
const SHELF_FACE := "res://assets/Level3/authored/shelf_face.png"

## ⚠ EnvironmentBaseplate SORTS ITS LAYERS BY THIS. It collects anything with
## set_camera_origin/update_for_camera -- which is how a backdrop gets parallax for free --
## and then sorts them with float(child.get("depth")). A layer without the property hands it
## null and throws "Nonexistent 'float' constructor" once per sort, forever. DepthLayer2D has
## carried it since Level 1; this is the same contract, not a new one.
@export var depth: float = 0.0

## WHICH BAND. Each is a separate delivery and a separate place in the level.
@export_enum("shore", "storm", "deep") var band: String = "shore"
## The world x range this band covers. Layers tile across it and stop at its edges, so the
## shore does not go on being drawn a thousand pixels out to sea.
@export var span := Vector2(0.0, 1100.0)
## World y of the plate's TOP edge. See the header -- derived, not chosen.
@export var plate_top: float = -230.0
## Stretch the plate vertically. The deep band fills a water column that is not 941 tall.
@export var plate_scale: float = 1.0
## ⚠ WHERE THE LAND IS. A layer marked `ground` -- the sand -- is laid only across these x
## ranges instead of the whole band, because sand is not sky: tiled across the band it ran
## straight out over the sea. ZERO means "no land here". The home beach is the first; the
## island the crossing arrives at is the second, and it faces the other way.
@export var home_ground := Vector2.ZERO
@export var island_ground := Vector2.ZERO
## ⚠ HOW FAR BELOW THE PLATE'S TOP THE DEEP'S FLOOR GOES. The delivered underwater picture
## puts its seabed 789 rows under the surface, which is less than a screen: from the boat the
## ruins stood just under the keel, and a dive was over before it had started. So the deep has
## TWO registrations, not one -- its water is pinned at the surface, where the light in it
## comes from, and the layers marked `floor` are pinned this much lower, where the seabed is.
## The collision, the refills and the coral field follow the floor, never the other way.
@export var floor_drop := 0.0
## Where the camera stands when each of the storm's two landmarks is centred on screen. They
## are halves of one plate -- a headland with a jetty at its left, an island with the ink buoy
## at its right -- and each is shown ONCE, where it belongs in the crossing.
@export var headland_x := 0.0
@export var far_island_x := 0.0
## A flat sky behind the band, down to this plate row. The storm's clouds are a strip across
## the middle of the plate with nothing painted above them, so under a storm the daylight sky
## showed through over the top of the clouds. Its colour is the storm CompletedLook's own
## top rows. Transparent means "no sky of its own".
@export var sky_colour := Color(0.0, 0.0, 0.0, 0.0)
@export var sky_bottom_row := 0.0
## ⚠ WHERE THE BAND FADES UP, IN WORLD X. Dagat crosses from a bright shore into a storm, and
## the design asks for exactly that: "the field has to get darker and emptier as the player
## nears the bakunawa, or the encounter arrives without buildup." Two bands butted against
## each other cut from noon to night at one pixel; a band that fades in over a thousand
## pixels is the buildup. Zero means "always at full", which is what the other two want.
@export var fade_span := Vector2.ZERO
## ⚠ WHERE THIS BAND'S SEA AND SKY LEAVE, THE LAND STAYING. The shore band cannot use
## `fade_span`: the island the crossing arrives at is ITS sand and ITS palms, four thousand
## pixels into the storm, so fading the whole band out takes the island with it. But its far
## layers are a beach SEEN FROM THE FRONT -- a horizon, a band of sea receding to it, and
## breakers running up a beach -- and the storm's are the same sea SEEN FROM THE SIDE. The two
## plates do not even agree on how far the horizon is above the waterline: 157 rows on the
## shore's, 84 on the storm's. Cross-faded over fourteen hundred pixels, that is two horizons
## at two heights with two sets of waves between them, which is what the whole first third of
## the crossing looked like. Layers marked `far` leave across this instead, so exactly one sea
## is ever being looked at.
@export var far_fade_span := Vector2.ZERO

## ⚠ THE STACK, FURTHEST FIRST. `rate` is the parallax factor: 0 is painted on the far wall
## and never moves, 1 travels with the world. `fps` turns a layer into an animation.
##
## ⚠ `z` IS ABSOLUTE ACROSS ALL THREE BANDS, NOT A PLACE WITHIN ONE. The bands share a
## screen -- the storm fades in over the shore's sky, the deep sits under both -- and when each
## band numbered its own stack from -200 the three interleaved: the deep's ruins drew over the
## storm's underside, the storm's waves tied with the deep's terraces and fell back on tree
## order, and the frame read as three pictures shuffled together. So the whole level is one
## ordering, back to front:
##
##   shore far layers  -250..-235   the daylight sky and sea, behind everything
##   deep              -230..-215   the water column and its floor -- with the storm's
##                                  underside slotted at -228, between the two
##   storm             -212..-193   sky, clouds, islands, the waves, the shores
##   shore ground      -165..-160   sand, the rock under it, then the palms: nearer than
##                                  any sea, behind the player. ⚠ THE SHELF GOES BEHIND THE
##                                  PALMS, not in front. At -150 the face's sand lip was
##                                  drawn over the rocks the clump ends the beach with, as a
##                                  pale smear across them.
##   storm rain          60         in front of everything
const BANDS := {
	"shore": [
		# The sky's clouds drift of their own accord, slowly; the storm's are driven.
		{"key": "shore/sky", "rate": 0.15, "z": -250, "drift": 5.0, "far": true},
		{"key": "shore/mountains", "rate": 0.35, "z": -245, "far": true},
		{"key": "shore/ocean", "rate": 0.55, "z": -240, "far": true},
		# The surf is foam over a still sea, so it moves a little faster than the water it
		# sits on and slower than the sand -- which is what makes the beach read as nearer.
		{"key": "shore/surf", "rate": 0.70, "z": -235, "fps": 3.0, "far": true},
		# ⚠ 64 PAST THE LAND AT THE SEAWARD END, which is a NEGATIVE trim. The palm clump's
		# mirrored twin below stands 64 out over the water, and sand that stopped on the
		# collision edge left it standing on nothing: a rock in the shallows with a notch of
		# open sea under it. The picture runs to where the picture ends, not to where the
		# player stops -- the shelf face already lands at the same 1060.
		{"key": "shore/sand", "rate": 1.00, "z": -165, "ground": true,
			"seaward_trim": -64.0},
		# ⚠ PIECES, NOT TILES. Each palm plate is one clump drawn at one edge of a 1672 canvas:
		# a palm and rocks at the far left, or a sand spit ending in rocks and a palm at the
		# right. Tiled and mirrored, a clump of palms stood every screen along the beach and
		# out across the open sea. So each is cut to the clump and set down once, at an end of
		# the land -- and at the island, which faces the other way, mirrored.
		# ⚠ WHAT THE LAND STANDS ON, UNDER THE WATER. The sand plate stops 150 pixels below
		# the walking surface and the sea goes on for a thousand more, so the deep's ruins
		# showed through under the beach. Authored rock from the plate's last row down, and a
		# ragged face with lit ledges where it meets the water -- the face's rock edge lands
		# on the land's own collision edge, so a diver stops where the rock looks to be.
		{"key": SHELF_FILL, "rate": 1.00, "z": -163, "ground": true, "top_row": 941.0,
			"mirror": false, "seaward_trim": 48.0},
		# ⚠ 790, THE SURFACE THE APO WALKS ON, not 941. See the lip in build_dagat_props.py:
		# the face begins where the sand does, so the land's seaward edge is ragged the whole way
		# down instead of a ruled cut through the sand with a ragged rock starting under it.
		{"key": SHELF_FACE, "rate": 1.00, "z": -162, "top_row": 790.0, "pieces": [
			{"at": "home_ground.y", "nudge": 64.0, "align": "right"},
			{"at": "island_ground.x", "nudge": -64.0, "align": "left", "flip": true},
		]},
		# The palms lean in the wind -- see shaders/wind_sway.gdshader. A shear of the whole
		# clump with its foot held, so the rocks it stands on do not move with it.
		#
		# ⚠ THE TWO PLATES ARE ONE CLUMP SPLIT ACROSS THE PLATE'S BORDER, and the seaward end of
		# the land is where that shows. `palms_left` tapers to nothing by its column 478 and is
		# CUT at its column 0; `palms_right` starts from nothing at its column 690 and is CUT at
		# 1672. Set down with a cut against open water, the beach ended in a ruled vertical line
		# from the palm tops to the sand -- the land guillotined, which is exactly what it looked
		# like. But the plate tiles: its column 1672 and its column 0 are the same rock, so the
		# head of one laid against the tail of the other rebuilds the whole clump and lets it
		# taper away into the shallows the way the picture was painted to.
		#
		# ⚠ SO THE TWO ROWS MUST SWAY AS ONE. They had their own gusts, which is right for two
		# clumps a beach apart and wrong for two halves of one: the fronds either side of the
		# join drift apart and the seam reappears in the wind.
		{"key": "shore/palms_left", "rate": 1.00, "z": -160, "sway": Vector2(5.0, 0.28),
			"pieces": [
			{"crop": Vector2(0, 478), "at": "home_ground.x", "align": "left"},
			# The head of the clump whose tail ends the home beach, and the island's.
			{"crop": Vector2(0, 360), "at": "home_ground.y", "align": "left"},
			{"crop": Vector2(0, 360), "at": "island_ground.x", "align": "right",
				"flip": true},
			{"crop": Vector2(0, 478), "at": "island_ground.y", "align": "right",
				"flip": true},
		]},
		{"key": "shore/palms_right", "rate": 1.00, "z": -160, "sway": Vector2(5.0, 0.28),
			"pieces": [
			{"crop": Vector2(690, 1672), "at": "home_ground.y", "align": "right"},
			{"crop": Vector2(690, 1672), "at": "island_ground.x", "align": "left",
				"flip": true},
		]},
	],
	"deep": [
		{"key": "deep/water", "rate": 0.15, "z": -230},
		{"key": "deep/ridges", "rate": 0.35, "z": -225, "floor": true},
		{"key": "deep/ruins", "rate": 0.55, "z": -220, "floor": true},
		{"key": "deep/terraces", "rate": 0.80, "z": -215, "floor": true},
	],
	"storm": [
		{"key": "storm/clouds", "rate": 0.15, "z": -210, "drift": -16.0},
		{"key": "storm/islands", "rate": 0.35, "z": -205},
		# ⚠ UNDER THE DEEP'S FLOOR, NOT OVER IT, AND CARRIED DOWN BELOW ITS OWN LAST ROW. The
		# underside is the storm plate's own seabed -- rocks and weed down to the plate's edge
		# -- and the level's water goes on for a thousand pixels past that, so drawn as it
		# comes it ended in a ruled line with the deep's sunlit water carrying on underneath.
		# Dithering the edge away only made the line into a checkerboard band. Instead the
		# storm REPLACES the deep's water: this sits between that water and the deep's ridges
		# and ruins, and its bottom row's colour carries on down, so under a storm the column
		# is dark all the way to the seabed and the floor still stands in front of it.
		{"key": "storm/undersea", "rate": 0.50, "z": -228,
			"fill_below": Color(0.012, 0.094, 0.208, 1.0)},
		{"key": "storm/waves", "rate": 0.80, "z": -195, "fps": 4.0},
		# In FRONT of the waves and at their rate: the jetty's posts stand in the water, and a
		# headland behind the sea it stands in reads as a picture of a headland pasted on.
		#
		# ⚠ EACH WITH A MIRRORED TWIN ON ITS CUT SIDE. Both were painted as the edges of one
		# picture: the headland's rocks run off the plate's left border and the island's off
		# its right, so set down on their own in open sea each ended in a ruled vertical line.
		# The land part (not the jetty, not the buoy) is mirrored against that line, which
		# turns the cut into the middle of an islet. The twin shares its piece's landmark, so
		# the two drift as one thing.
		# A storm leans them much harder.
		{"key": "storm/shores", "rate": 0.80, "z": -193, "sway": Vector2(11.0, 0.55),
			"pieces": [
			{"crop": Vector2(0, 536), "at": "headland_x", "align": "center"},
			{"crop": Vector2(0, 270), "at": "headland_x", "nudge": -268.0, "align": "right",
				"flip": true},
			# ⚠ LIFTED 110. The two halves of this plate were not drawn on one waterline:
			# with the jetty's deck at the boat's, the buoy's float sat a hundred pixels under
			# the front wave. The CompletedLook has both in the same water.
			{"crop": Vector2(1306, 1672), "at": "far_island_x", "align": "center",
				"lift": 110.0},
			{"crop": Vector2(1480, 1672), "at": "far_island_x", "nudge": 183.0,
				"align": "left", "flip": true, "lift": 110.0},
		]},
		# Rain falls in front of everything, fast, and never repeats the sea's rhythm.
		{"key": "storm/rain", "rate": 1.00, "z": 60, "fps": 10.0},
	],
}

## ⚠ NIGHT, AS A TINT ON A BAND THAT IS NOT THE STORM. The storm fades in over the crossing,
## but the deep under it and the island ahead of it are painted in daylight: under a night sky
## the island glowed like noon and the water under the storm was the sunlit water of the
## beach. A band with a night_span darkens toward night_tint across that stretch -- the same
## stretch the storm fades in over, so the two arrive together.
@export var night_span := Vector2.ZERO
@export var night_tint := Color.WHITE
## ⚠ AND WHAT THE BAND LOOKS LIKE BEFORE THE NIGHT ARRIVES. The storm's sea is painted for the
## END of the crossing -- thunderheads, dark water -- and it now replaces the beach's sea where
## the player leaves the sand, a screen and a half out, where the design still wants daylight.
## WHITE leaves a band at its painted value, which is right for the shore and the deep; the
## storm brightens back toward the light it is arriving in and darkens into its own across
## night_span, so the buildup is carried by the LIGHT rather than by which picture is drawn.
@export var day_tint := Color.WHITE

var _layers: Array[Node2D] = []
## How far the storm has cleared, 0..1. The storm is over when the bakunawa is -- see
## clear_the_sky -- and this is what every band's night and every storm's alpha answer to.
var _clearing := 0.0
var _clear_tween: Tween
var _last_camera := Vector2.ZERO


func _ready() -> void:
	if sky_colour.a > 0.0:
		var sky := Polygon2D.new()
		sky.name = "Sky"
		sky.color = sky_colour
		sky.z_index = -212
		var reach := _Layer.HALF_VIEW * 3.0
		var bottom := plate_top + sky_bottom_row
		sky.polygon = PackedVector2Array([
			Vector2(span.x - reach, -4000.0), Vector2(span.y + reach, -4000.0),
			Vector2(span.y + reach, bottom), Vector2(span.x - reach, bottom)])
		add_child(sky)
	var manifest := _manifest()
	for row_value: Variant in BANDS.get(band, []):
		var row: Dictionary = row_value
		var frames := _frames(manifest, String(row["key"]))
		if frames.is_empty():
			push_warning("DagatBackdrop2D: nothing in the manifest for %s" % row["key"])
			continue
		if row.has("pieces"):
			var pieces: Array = row["pieces"]
			for index in range(pieces.size()):
				var piece: Dictionary = pieces[index]
				var at := _landmark(String(piece["at"]))
				if is_nan(at):
					continue
				var layer := _new_layer(row, frames, manifest)
				layer.name = "%s_%d" % [layer.name, index]
				layer.crop = piece.get("crop", Vector2(0.0, float(frames[0].get_width())))
				layer.flipped = bool(piece.get("flip", false))
				layer.lift = float(piece.get("lift", 0.0))
				layer.place_piece(at, float(piece.get("nudge", 0.0)),
					String(piece.get("align", "center")))
				add_child(layer)
				_layers.append(layer)
		elif bool(row.get("ground", false)):
			for ground: Vector2 in [home_ground, island_ground]:
				if ground == Vector2.ZERO:
					continue
				var layer := _new_layer(row, frames, manifest)
				layer.name = "%s_%d" % [layer.name, int(ground.x)]
				# The home beach has the sea to its east and the island has it to its west;
				# a row that stops short of the water stops short at that end.
				var trim := float(row.get("seaward_trim", 0.0))
				if ground == home_ground:
					layer.span = Vector2(ground.x, ground.y - trim)
				else:
					layer.span = Vector2(ground.x + trim, ground.y)
				layer.mirrored_tiles = bool(row.get("mirror", true))
				layer.grounded = true
				add_child(layer)
				_layers.append(layer)
		else:
			var layer := _new_layer(row, frames, manifest)
			add_child(layer)
			_layers.append(layer)


func _new_layer(row: Dictionary, frames: Array[Texture2D], manifest: Dictionary) -> _Layer:
	var layer := _Layer.new()
	layer.name = String(row["key"]).replace("/", "_")
	layer.frames = frames
	layer.origin = _origin_of(manifest, String(row["key"]))
	layer.canvas_width = float(manifest.get("plate_size", [1672, 941])[0])
	layer.span = span
	layer.plate_scale = plate_scale
	layer.rate = float(row["rate"])
	layer.z_index = int(row["z"])
	layer.fps = float(row.get("fps", 0.0))
	layer.plate_top = plate_top + (floor_drop if bool(row.get("floor", false)) else 0.0)
	if row.has("sway"):
		layer.sway = row["sway"]
	layer.slide_speed = float(row.get("drift", 0.0))
	layer.far = bool(row.get("far", false))
	if row.has("top_row"):
		# An authored texture is not on the plate at all; it says which plate row it
		# starts at, and it repeats at its own width rather than the plate's.
		layer.origin = Vector2(0.0, float(row["top_row"]))
		layer.canvas_width = float(frames[0].get_width())
	if row.has("fill_below"):
		var fill := Polygon2D.new()
		fill.name = layer.name + "_below"
		fill.color = row["fill_below"]
		fill.z_index = layer.z_index
		var reach := _Layer.HALF_VIEW * 3.0
		# ⚠ EDGE TO EDGE, NOT OVERLAPPING BY EVEN ONE ROW. The storm band fades in by its
		# own alpha, which every child draws with separately -- so wherever the plate and
		# the fill overlap, that strip is drawn twice at half strength and comes out darker
		# than both. A one-row overlap was a hairline across the whole crossing; "fixing" it
		# by overlapping three rows made it three times as thick. Both edges are whole pixels.
		var top := plate_top + float(frames[0].get_height()) + layer.origin.y
		fill.polygon = PackedVector2Array([
			Vector2(span.x - reach, top), Vector2(span.y + reach, top),
			Vector2(span.y + reach, top + 4000.0), Vector2(span.x - reach, top + 4000.0)])
		add_child(fill)
	return layer


## A landmark by name: an export, or one end of a ground ("home_ground.y"). NAN when the band
## does not have that piece of land, which is how the island's palms stay out of a band that
## has no island.
func _landmark(name_path: String) -> float:
	var parts := name_path.split(".")
	var value: Variant = get(parts[0])
	if value is Vector2:
		var ground := value as Vector2
		if ground == Vector2.ZERO:
			return NAN
		return ground.x if parts.size() < 2 or parts[1] == "x" else ground.y
	if value is float and not is_zero_approx(float(value)):
		return float(value)
	return NAN


## ⚠ WHERE AN ANIMATION'S FRAMES SIT ON THE PLATE THEY WERE CUT FROM. A group is trimmed to
## the union of its frames, so frame 0 of the storm's waves is 867 tall and starts 48 rows
## down the 941 plate everything else is registered to. Drawn at the plate's top edge, the
## waves rode 48 pixels above the sea they belong to, the surf 21 above the sand, and the rain
## 18 to the left of its own sky. A single plate has no origin, which is (0, 0).
func _origin_of(manifest: Dictionary, key: String) -> Vector2:
	var groups: Dictionary = manifest.get("groups", {})
	if not groups.has(key):
		return Vector2.ZERO
	var origin: Array = (groups[key] as Dictionary).get("origin", [0, 0])
	return Vector2(float(origin[0]), float(origin[1]))


func _manifest() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return parsed as Dictionary if parsed is Dictionary else {}


## A key is either a single plate or an animation group. Both come back as a frame list, so
## the layer below does not have to care which it was handed.
func _frames(manifest: Dictionary, key: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var plates: Dictionary = manifest.get("plates", {})
	var groups: Dictionary = manifest.get("groups", {})
	var paths: Array = []
	if key.begins_with("res://"):
		paths = [key]
	elif plates.has(key):
		paths = [String((plates[key] as Dictionary).get("file", ""))]
	elif groups.has(key):
		paths = (groups[key] as Dictionary).get("frames", [])
	for path_value: Variant in paths:
		var texture := load(String(path_value)) as Texture2D
		if texture != null:
			out.append(texture)
	return out


## ⚠ THE CAMERA'S ORIGIN IS NOT KEPT, deliberately. EnvironmentBaseplate hands every layer a
## fresh origin whenever the player's body changes -- set_target resyncs them -- and parallax
## measured from "wherever the camera was at the last transformation" snaps every far layer
## back to its starting place the moment the player draws something mid-crossing. The whole
## sky jumped sideways. Parallax here is measured from a fixed point in the world instead, so
## the backdrop is a function of where the camera IS, never of how it got there.
func set_camera_origin(camera_position: Vector2) -> void:
	update_for_camera(camera_position)


## THE STORM BREAKS. Called when the encounter is resolved, however it was resolved, so the
## crossing's last stretch and the farewell on the island are in daylight: the buildup the
## design asks for ("darker and emptier as the player nears the bakunawa") has somewhere to go
## once it is over. It runs through the pause, because the farewell is a DialogueBox and the
## sky should clear while he is talking, not after.
func clear_the_sky(seconds: float) -> void:
	if _clearing >= 1.0 or (_clear_tween != null and _clear_tween.is_valid()):
		return
	_clear_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_clear_tween.tween_method(_set_clearing, _clearing, 1.0, maxf(0.01, seconds))


## Back to the storm at once, for a checkpoint restored to before the encounter was over.
func restore_the_storm() -> void:
	if _clear_tween != null and _clear_tween.is_valid():
		_clear_tween.kill()
	_set_clearing(0.0)


func is_clear() -> bool:
	return _clearing >= 1.0


## How much storm there is over this x, 0..1: this band's own fade, times however far the sky
## has cleared. DagatLife2D asks, so gulls stay out of the storm and rain stays out of the sun.
## ⚠ THE NIGHT'S RAMP, NOT THE ALPHA'S, WHEREVER THERE IS ONE. Two different things happen
## across this crossing and they are no longer on the same stretch. The storm's sea REPLACES
## the beach's as the player leaves the sand -- a change of viewpoint, over a few hundred
## pixels, because two seas drawn at once is two horizons. The LIGHT goes later and slower,
## over the stretch the design asks the field to darken across. Read from the alpha, the rain
## and the lightning came with the picture and it was pouring on a bright sea one screen out
## from a sunny beach.
func weather_at(x: float) -> float:
	var span := night_span if night_span != Vector2.ZERO else fade_span
	if span == Vector2.ZERO:
		return 0.0
	return _ramp(span, x) * (1.0 - _clearing)


func _set_clearing(value: float) -> void:
	_clearing = clampf(value, 0.0, 1.0)
	update_for_camera(_last_camera)


static func _ramp(span_x: Vector2, x: float) -> float:
	# ⚠ THE RAMP ALWAYS RUNS LEFT TO RIGHT ACROSS THE WORLD; only its SENSE is reversed.
	var lo := minf(span_x.x, span_x.y)
	var hi := maxf(span_x.x, span_x.y)
	var ramp := clampf((x - lo) / maxf(1.0, hi - lo), 0.0, 1.0)
	return ramp if span_x.y > span_x.x else 1.0 - ramp


func update_for_camera(camera_position: Vector2) -> void:
	_last_camera = camera_position
	var weather := 1.0 - _clearing
	var night := 1.0
	if night_span != Vector2.ZERO:
		night = _ramp(night_span, camera_position.x) * weather
		modulate = Color(lerpf(day_tint.r, night_tint.r, night),
			lerpf(day_tint.g, night_tint.g, night),
			lerpf(day_tint.b, night_tint.b, night), modulate.a)
	if fade_span != Vector2.ZERO:
		# x < y fades the band UP across that stretch; x > y fades it DOWN. The shore and the
		# storm are the same crossing seen twice, so one has to leave as the other arrives --
		# otherwise a low-rate layer from the daylight band drifts far enough right to hang a
		# palm tree over the storm.
		# ⚠ THE RAMP ALWAYS RUNS LEFT TO RIGHT ACROSS THE WORLD; only its SENSE is reversed.
		# Reading it from fade_span.x meant a fade-out started where it should have finished,
		# so the daylight band stayed at full alpha across the whole crossing and hung a palm
		# tree over the storm.
		modulate.a = _ramp(fade_span, camera_position.x) * weather
	# ⚠ ON THE LAYERS, NOT ON THE BAND. See far_fade_span: the shore's land has to stay while
	# its sea goes, so this cannot be the node's own modulate.
	if far_fade_span != Vector2.ZERO:
		var gone := _ramp(far_fade_span, camera_position.x) * weather
		for layer in _layers:
			if layer.far:
				layer.modulate.a = 1.0 - gone
	for layer in _layers:
		# ⚠ HORIZONTAL ONLY. Parallax on Y unmoors the composition from the thing it is
		# registered to: this level is a thousand pixels tall, so let the far layers lag on Y
		# and the sky, the horizon and the surf all slide up out of frame the moment the
		# player goes under. That is exactly what it did, and it looked like four layers
		# failing to render.
		#
		# A rate of 1 sits still relative to the world; anything less lags behind the camera,
		# which is what reads as distance. At the reference point every layer is where it was
		# authored; everywhere else it has drifted by (1 - rate) of the distance from there.
		layer.parallax_x = layer.base_x \
			+ (camera_position.x - layer.reference_x) * (1.0 - layer.rate)
		layer.place()


## One tiled, optionally animated plate.
##
## ⚠ SPRITES, NOT A CUSTOM _draw. The first version of this drew
## with draw_texture_rect(..., tile = true) and produced nothing at all for four of the seven
## layers -- _draw ran, with the right texture, the right rect and the right position, and the
## screen stayed empty where they should have been. Sprite2D with region_enabled and
## TEXTURE_REPEAT_ENABLED is the path level_2.tscn already uses for its backdrop, and it
## repeats across a span wider than the texture without any of that.
class _Layer extends Node2D:
	## The far edge of the camera's travel past either end of a band, in world pixels: half a
	## screen at the widest zoom this level uses, with room to spare.
	const HALF_VIEW := 1200.0

	var frames: Array[Texture2D] = []
	var span := Vector2.ZERO
	var plate_scale := 1.0
	var plate_top := 0.0
	var rate := 1.0
	var fps := 0.0
	## Where frame 0 sits on the plate it was cut from. Zero for a plate.
	var origin := Vector2.ZERO
	## The width every layer repeats at: the PLATE's, not the trimmed frame's, or a trimmed
	## animation tiles at a different period from the sea it is painted on.
	var canvas_width := 1672.0
	## The world x the camera is at when this layer is exactly where it was authored.
	var reference_x := 0.0
	## Where the layer's left edge sits at that moment.
	var base_x := 0.0
	## A piece is one cut of a plate (`crop` is its x range on the canvas) set down once.
	var crop := Vector2.ZERO
	var flipped := false
	## Laid across `span` at world rate and cut off at its ends, rather than widened for drift.
	var grounded := false
	## A painted plate is mirrored every second copy to hide its seam; an authored texture is
	## drawn to tile straight and a mirror would only put a seam back in.
	var mirrored_tiles := true
	## How far a piece is raised off the plate's registration. See the far island.
	var lift := 0.0
	## Part of this band's sea and sky rather than its land. See far_fade_span.
	var far := false
	## (lean in texels, gusts per second) for a layer the wind moves. ZERO holds it still.
	var sway := Vector2.ZERO
	## Pixels a second a layer slides on its own -- clouds -- wrapped at the width it repeats
	## at, which for mirrored tiles is two plates, so the seam never arrives.
	var slide_speed := 0.0
	var _slid := 0.0
	## Where the camera's parallax alone puts the left edge; the slide is added on top.
	var parallax_x := 0.0
	const SWAY := preload("res://shaders/wind_sway.gdshader")
	var _frame := 0
	var _clock := 0.0

	var _tiles: Array[Sprite2D] = []

	## Set a piece down so it sits where it belongs when the camera is looking at it. For a
	## layer at world rate that is simply where it is; for a slower one, it is where it is when
	## the camera stands at `at`, and it drifts from there like everything else at its depth.
	##
	## `nudge` moves the piece without moving its landmark. Parallax is referenced from the
	## LANDMARK, so every piece hung on the same one drifts as one rigid thing -- referenced
	## from each piece's own middle, a twin set beside its original slid away from it.
	func place_piece(at: float, nudge: float, align: String) -> void:
		var width := crop.y - crop.x
		var edge := at + nudge
		match align:
			"left":
				base_x = edge
			"right":
				base_x = edge - width
			_:
				base_x = edge - width * 0.5
		reference_x = at

	func _ready() -> void:
		if crop != Vector2.ZERO:
			_build_piece()
		elif grounded:
			_build_ground()
		else:
			_build_tiles()
		parallax_x = base_x
		place()
		set_process((fps > 0.0 and frames.size() > 1) or slide_speed != 0.0)

	## ⚠ WHOLE PIXELS. Every layer moves at its own fraction of the camera, so at any moment
	## the ten of them sit at ten different sub-pixel offsets -- and with nearest filtering a
	## sub-pixel offset is not a soft half-pixel, it is a column of texels that snaps a whole
	## pixel across when the offset crosses a half. Ten layers each snapping on its own
	## schedule is the crawl you see in the sky while the sea underneath it holds still. Put
	## them all on the world's pixel grid and they snap together or not at all, which reads as
	## the painting moving rather than as the painting boiling.
	func place() -> void:
		var slid := 0.0
		if slide_speed != 0.0:
			slid = wrapf(_slid, -canvas_width, canvas_width)
		position = Vector2(roundf(parallax_x + slid), roundf(plate_top))

	func _add_tile(x: float, flip: bool, region: Rect2) -> Sprite2D:
		var tile := Sprite2D.new()
		tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Top-left anchored, because every layer in a band is pinned by the SAME top edge.
		tile.centered = false
		tile.texture = frames[0]
		tile.flip_h = flip
		if region.size != Vector2.ZERO:
			tile.region_enabled = true
			tile.region_rect = region
		if sway != Vector2.ZERO:
			var wind := ShaderMaterial.new()
			wind.shader = SWAY
			wind.set_shader_parameter("lean", sway.x)
			wind.set_shader_parameter("gust", sway.y)
			wind.set_shader_parameter("phase", fposmod(x * 0.011 + float(_tiles.size()), TAU))
			tile.material = wind
		tile.position = Vector2(x, origin.y * plate_scale)
		tile.scale = Vector2(1.0, plate_scale)
		add_child(tile)
		_tiles.append(tile)
		return tile

	func _build_piece() -> void:
		var height := float(frames[0].get_height())
		var tile := _add_tile(0.0, flipped,
			Rect2(crop.x - origin.x, 0.0, crop.y - crop.x, height))
		tile.position.y -= lift

	## ⚠ A CUT MIRRORED TILE SHOWS THE FAR END OF THE TEXTURE, not the near one. Mirrored
	## copies meet edge to matching edge: an upright tile ends on the texture's last column, so
	## the flipped one after it has to START on that column -- and when it is cut short, what
	## is kept is the texture's right-hand part, reversed.
	func _build_ground() -> void:
		base_x = span.x
		reference_x = span.x
		var height := float(frames[0].get_height())
		var texture_width := float(frames[0].get_width())
		var x := 0.0
		var index := 0
		while x < span.y - span.x - 0.5:
			var width := minf(texture_width, span.y - span.x - x)
			var flip := mirrored_tiles and index % 2 == 1
			var region := Rect2(0.0, 0.0, width, height)
			if flip:
				region.position.x = texture_width - width
			_add_tile(x, flip, region)
			x += texture_width
			index += 1

	func _build_tiles() -> void:
		# ⚠ MIRRORED TILES, NOT A REPEATING REGION. Every plate is a self-contained painting
		# 1672 wide and the bands are two to four times that, so it has to repeat -- and a
		# straight repeat puts a hard vertical cut through the ruins every 1672 pixels, which
		# the eye finds immediately. Flipping every second copy turns the cut into a mirror
		# line, which reads as more of the same place rather than as the same place again.
		#
		# ⚠ A SLOW LAYER HAS TO COVER MORE GROUND THAN THE BAND IS WIDE. At rate 0.15 the sky
		# lags the camera by 85% of everything it travels, so it slides sideways by nearly as
		# much as the band is wide. It is referenced from the band's middle, so it drifts by
		# (1 - rate) of half the band plus half a screen at most in either direction, and the
		# tiles are laid out to cover exactly that.
		reference_x = (span.x + span.y) * 0.5
		var drift := ((span.y - span.x) * 0.5 + HALF_VIEW) * (1.0 - rate)
		base_x = span.x - drift
		var count := int(ceil((span.y - span.x + drift * 2.0) / canvas_width))
		if slide_speed != 0.0:
			# Two plates more at each end for the slide to travel into -- an even number, so
			# the mirror pattern keeps its phase.
			base_x -= canvas_width * 2.0
			count += 4
		for index in range(count):
			var flip := index % 2 == 1
			# ⚠ flip_h mirrors the texture INSIDE the sprite's own rect; it does not move the
			# rect. A trimmed frame mirrored on its canvas lands the same distance from the
			# canvas's OTHER edge, which is the only thing that has to be worked out here.
			var inset := origin.x
			if flip:
				inset = canvas_width - origin.x - float(frames[0].get_width())
			_add_tile(canvas_width * float(index) + inset, flip, Rect2())

	func _process(delta: float) -> void:
		if slide_speed != 0.0:
			_slid += slide_speed * delta
			place()
		if fps <= 0.0 or frames.size() < 2:
			return
		_clock += delta
		var step := 1.0 / maxf(0.01, fps)
		if _clock < step:
			return
		_clock -= step
		_frame = (_frame + 1) % frames.size()
		for tile in _tiles:
			tile.texture = frames[_frame]
