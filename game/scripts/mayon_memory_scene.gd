extends Node2D
## A piece of a remembered place, not another level host. All collision lives in the journey.
## Its camera-registered scenery and ground are rendered only into the assigned scenery pass.

@export var place_id := ""
@export var kind := "terraces"
var span := 1280.0
var route: Array[Rect2] = []
var ledges: Array[Rect2] = []
var camera_position := Vector2.ZERO
var view_size := Vector2(1600, 900)
var _textures: Dictionary = {}
var _ground: Node2D
var _stage: StageScript
var _framed := false
var _dilim_ground_registered := false
var staging: Dictionary = {}
const StageScript = preload("res://scripts/mayon_memory_stage.gd")
const TERRACE_GROUND := preload("res://shaders/mayon_terrace_ground.gdshader")
const SHORE_GROUND := preload("res://shaders/mayon_shore_ground.gdshader")
const SEABED_GROUND := preload("res://shaders/mayon_seabed_ground.gdshader")
const TERRACE_LIP := 8.0
const TERRACE_ROUND := 34.0
const TERRACE_JOIN_SCALE := 2048.0
const CROSSING_HALF_WIDTH := 210.0
# The assembled Alley 1 plate includes its road and wall below this source row.
const ALLEY_WALK_ROW := 895.0
const ALLEY_ART_SCALE := 1.14

const BACKDROPS := {
 "terraces": ["Level5/journey/payyo_sky.png"], "crossing": ["Level5/journey/payyo_sky.png"],
 "bale": ["Level5/journey/payyo_sky.png"], "plaza": ["Level5/journey/plaza_sky.png"],
 "church": ["Level5/journey/church_sky.png"], "alley": ["Level5/journey/alley_plate.png"],
 "shore": ["Level5/journey/shore_sky.png"], "sea": ["Level5/journey/sea_sky.png"],
 "island": ["Level5/journey/shore_sky.png"], "summit": [],
}
const DILIM_LIGHT := {"forest": 0.22, "waterfall": 0.38, "dawn": 1.0}
const DILIM_GROUND := "res://assets/Level4/ground_moonlit"
const DILIM_SKY_EDGE := Color8(1, 119, 225)
enum DilimRepeat { ONCE, STRAIGHT, MIRROR }
# Level 4's own plates and sizes, with their tops relative to the remembered walk line.
# Texture, scale, top, scroll rate, repeat mode.
const DILIM_BANDS := [
	["Level4/backdrop_reference/sky.png", Vector2(1, 1.1), -660.0, 0.02, DilimRepeat.MIRROR],
	["Level4/backdrop_reference/makiling.png", Vector2(1.25, 0.83), -628.0, 0.044, DilimRepeat.ONCE],
	["Level4/backdrop_reference/canopy.png", Vector2(1, 1.22), -745.0, 0.29, DilimRepeat.MIRROR],
	["Level4/trees/forest_plate.png", Vector2.ONE, -740.0, 0.62, DilimRepeat.STRAIGHT],
]
# Match the registered sky above each plate, including a jump above the painted top.
const SKY_COLOURS := {
	"terraces": Color("208dee"),
	"crossing": Color("208dee"),
	"bale": Color("208dee"),
	"plaza": Color("0087fd"),
	"alley": Color("d17f56"),
	"shore": Color("2490f5"),
	"sea": Color("0498cb"),
	"island": Color("2490f5"),
}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -20
	if kind == "alley":
		# The complete plate is registered to the same flat route as the player.
		return
	if kind not in ["plaza", "church", "summit"]:
		_stage = StageScript.new()
		_stage.name = "RememberedLife"
		_stage.kind = kind
		_stage.props = staging.get("props", [])
		_stage.span = span
		if kind == "crossing":
			var opening := Rect2(span * 0.5 - CROSSING_HALF_WIDTH, 0.0,
				CROSSING_HALF_WIDTH * 2.0, 1400.0)
			# Tuck the water under the rounded turf lips so no sky peeks through.
			_stage.river_bounds = opening.grow_individual(16.0, 0.0, 16.0, 0.0)
		add_child(_stage)
	if kind == "plaza":
		var plaza := PiyestaPlaza2D.new()
		# The painted plaza is centred here. Extend the tiled surface under
		# both sides of the transition into the neighbouring memories.
		plaza.from_x = -240.0
		plaza.to_x = span + 190.0
		plaza.wall_extension = _art("Level5/journey/plaza_masonry.png")
		_ground = plaza
	elif kind in DILIM_LIGHT:
		var cliff := CliffDressing2D.new()
		cliff.kit = DILIM_GROUND
		_ground = cliff
	else:
		_ground = Node2D.new()
		_ground.draw.connect(_draw_walk_surface)
	_ground.name = "WalkSurface"
	if kind in ["terraces", "crossing", "bale", "shore", "sea", "island"]:
		var material := ShaderMaterial.new()
		match kind:
			"shore", "island": material.shader = SHORE_GROUND
			"sea": material.shader = SEABED_GROUND
			_: material.shader = TERRACE_GROUND
		_ground.material = material
	add_child(_ground)
	_ground.z_index = 1
	if kind == "crossing":
		# The bridge sits in front of the banks and uses its own artwork.
		var bridge := Sprite2D.new()
		bridge.name = "BridgeDeck"
		bridge.texture = _art("Level5/props/old_crossing.png")
		bridge.scale = Vector2.ONE * 460.0 / bridge.texture.get_width()
		bridge.position = Vector2(span * 0.5, 20.0 - bridge.texture.get_height() * bridge.scale.y * 0.5)
		bridge.z_index = _ground.z_index
		add_child(bridge)


func frame(camera: Vector2, extent: Vector2, player_position := Vector2.INF) -> void:
	if _stage != null:
		var origin := global_position
		var bounds := Rect2(camera - origin - extent * 0.5, extent).grow(640.0)
		_stage.frame(bounds, player_position - origin, origin, route)
	if _framed and camera == camera_position and extent == view_size:
		return
	_framed = true
	camera_position = camera
	view_size = extent
	queue_redraw()
	if _ground is CliffDressing2D:
		# The journey supplies the route and flower ledges after _ready.
		if not _dilim_ground_registered:
			var local_ground: Array[Rect2] = []
			for rect in route + ledges:
				local_ground.append(Rect2(rect.position - global_position, rect.size))
			(_ground as CliffDressing2D).dress(local_ground)
			_dilim_ground_registered = true
	elif _ground != null and kind != "plaza":
		_ground.queue_redraw()


func _art(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load("res://assets/" + path)
	return _textures[path] as Texture2D


func _draw() -> void:
	var eye := camera_position - global_position
	var bounds := Rect2(eye - view_size * 0.5 - Vector2(200, 200), view_size + Vector2(400, 400))
	if kind in DILIM_LIGHT:
		_draw_dilim_backdrop(eye.x, bounds)
		return
	var sky: Color = SKY_COLOURS.get(kind,Color("94c7ce"))
	if kind == "church": sky = Color("6a5140")
	elif kind == "summit": sky = Color("f4efe4")
	draw_rect(bounds, sky)
	var layers: Array = BACKDROPS.get(kind, [])
	for index in range(layers.size()):
		var texture := _art(String(layers[index]))
		var height := 920.0
		var width := height * texture.get_width() / texture.get_height()
		var parallax := 0.18 + index * 0.10
		var x := span * .5 - width * .5 + (eye.x-span*.5) * (1.0-parallax)
		var y := -height
		var tint := Color.WHITE
		if kind == "plaza":
			# Piyesta's painting is a single plate registered to the walk line.
			height = 720.0
			width = height * texture.get_width() / texture.get_height()
			draw_texture_rect(texture, Rect2((span - width) * 0.5, -height, width, height), false)
			continue
		elif kind == "church":
			height = 820.0
			width = height * texture.get_width() / texture.get_height()
			x = span * .5 - width * .5
			y = -height
		elif kind == "alley":
			height = texture.get_height() * ALLEY_ART_SCALE
			width = texture.get_width() * ALLEY_ART_SCALE
			x = span * .5 - width * .5
			y = -ALLEY_WALK_ROW * ALLEY_ART_SCALE
		# Repeat only the authored sky/landscape, with mirrored neighbours at the ends.
		for repeat_index in [-1, 0, 1]:
			var rect := Rect2(x + repeat_index * width, y, width, height)
			# Coastal scenery can see the lowered banks of its neighbours. Extend
			# the painted water behind the ground so the plate ends out of sight.
			if kind in ["shore", "sea", "island"]:
				var ocean_depth := 90.0
				var rows := ocean_depth * texture.get_height() / height
				var origin_x := rect.position.x if repeat_index == 0 else rect.end.x
				draw_set_transform(Vector2(origin_x, rect.end.y + ocean_depth),
					0.0, Vector2(1 if repeat_index == 0 else -1, -1))
				draw_texture_rect_region(texture, Rect2(0, 0, width, ocean_depth),
					Rect2(0, texture.get_height() - rows, texture.get_width(), rows), tint)
				draw_set_transform(Vector2.ZERO)
			if repeat_index == 0:
				draw_texture_rect(texture, rect, false, tint)
			else:
				draw_set_transform(Vector2(rect.end.x,rect.position.y),0.0,Vector2(-1,1))
				draw_texture_rect(texture,Rect2(Vector2.ZERO,rect.size),false,tint)
				draw_set_transform(Vector2.ZERO)
	# The island's palms are the stage's now: the surf passes behind them (RememberedLife).


func _draw_dilim_backdrop(eye_x: float, bounds: Rect2) -> void:
	var tint := MakilingBackdrop2D.NIGHT_TINT.lerp(MakilingBackdrop2D.MORNING_TINT, DILIM_LIGHT[kind])
	draw_rect(bounds, DILIM_SKY_EDGE * tint)
	var centre := span * 0.5
	for band in DILIM_BANDS:
		var texture := _art(band[0])
		var size: Vector2 = texture.get_size() * band[1]
		var left: float = centre - size.x * 0.5 + (eye_x - centre) * (1.0 - band[3])
		var repeat_mode: int = band[4]
		var first := 0
		var last := 0
		if repeat_mode != DilimRepeat.ONCE:
			first = floori((bounds.position.x - left) / size.x)
			last = floori((bounds.end.x - left) / size.x)
		for index in range(first, last + 1):
			var x := left + index * size.x
			var mirrored := repeat_mode == DilimRepeat.MIRROR and posmod(index, 2) == 1
			draw_set_transform(Vector2(x + size.x if mirrored else x, band[2]),
				0.0, Vector2(-1 if mirrored else 1, 1))
			draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false, tint)
	draw_set_transform(Vector2.ZERO)


func _draw_walk_surface() -> void:
	var eye := camera_position - global_position
	var bounds := Rect2(eye-view_size*.5-Vector2(200,200),view_size+Vector2(400,400))
	_draw_ground(bounds)


func _draw_ground(bounds: Rect2) -> void:
	var ground := Color("544638")
	var surface := "Level1/cliff/face.png"
	if kind == "church":
		surface = "Level2/interiors/church_floor.png"
		ground = Color("88785d")
	elif kind in ["shore", "island", "sea"]:
		surface = "Level3/authored/seabed_floor.png" if kind == "sea" else "Level5/journey/sand_ground.png"
		ground = Color("a08661")
	elif kind == "summit":
		_ground.draw_rect(Rect2(bounds.position.x, 0, bounds.size.x, 1600), Color("ded9cf"))
		return
	var texture := _art(surface)
	# The same world rectangles feed collision and BOTH scene passes, including overlaps.
	var ground_rects: Array[Rect2] = []
	var crossing_left := global_position.x + span * 0.5 - CROSSING_HALF_WIDTH
	var crossing_right := crossing_left + CROSSING_HALF_WIDTH * 2.0
	for rect in route:
		if kind != "crossing" or rect.end.x <= crossing_left or rect.position.x >= crossing_right:
			ground_rects.append(rect)
			continue
		# The bridge's deck is the continuous collision surface; open the scenery beneath
		# it so the crossing reads as a bridge, rather than a railing lying on grass.
		if rect.position.x < crossing_left:
			ground_rects.append(Rect2(rect.position,Vector2(crossing_left-rect.position.x,rect.size.y)))
		if rect.end.x > crossing_right:
			ground_rects.append(Rect2(crossing_right,rect.position.y,rect.end.x-crossing_right,rect.size.y))
	for rect in ground_rects:
		var local := Rect2(rect.position - global_position, rect.size)
		if local.end.x < bounds.position.x or local.position.x > bounds.end.x: continue
		if kind in ["terraces", "crossing", "bale", "shore", "sea", "island"]:
			_draw_rounded_bank(rect, local, ground_rects, texture)
			continue
		_ground.draw_rect(local, ground)
		# Keep the delivered material's scale; the plaza strip is only 96px tall.
		var height := float(texture.get_height())
		var tile_width := float(texture.get_width()) * height / texture.get_height()
		for x_index in range(floori(local.position.x / tile_width), ceili(local.end.x / tile_width)):
			var left := maxf(local.position.x, x_index * tile_width)
			var right := minf(local.end.x, (x_index + 1) * tile_width)
			# Continue the rock face below high steps; never expose a flat fill under a cliff.
			if kind == "church":
				# ⚠ THE NAVE'S FLOOR GOES DOWN TO THE FRAME TOO. It was one 64px row of tiles over a
				# flat fill, and the bottom of every church frame was a plain brown band (Kent: parts of
				# the runway "not rendering properly"). Whole tiles, darker course by course: the floor
				# is tiles all the way down, with no ragged edge to hide.
				for depth in range(7,0,-1):
					var shade := pow(.86,float(depth))
					_ground.draw_texture_rect_region(texture,
						Rect2(left,local.position.y-4+depth*height,right-left,height),
						Rect2((left-x_index*tile_width)/tile_width*texture.get_width(),0,
							(right-left)/tile_width*texture.get_width(),texture.get_height()),
						Color(shade,shade,shade))
			else:
				for depth in range(7,0,-1):
					var depth_y := local.position.y-4+height*.55+(depth-1)*height*.44
					var light := pow(.87,float(depth))
					# Repeat opaque interior stone under the irregular alpha cut, never
					# its ragged bottom edge as a horizontal stripe through the ground.
					_ground.draw_texture_rect_region(texture,Rect2(left,depth_y,right-left,height*.46),
						Rect2((left-x_index*tile_width)/tile_width*texture.get_width(),texture.get_height()*.22,
							(right-left)/tile_width*texture.get_width(),texture.get_height()*.46),Color(light,light,light))
			_ground.draw_texture_rect_region(texture, Rect2(left, local.position.y - 4, right-left, height),
				Rect2((left-x_index*tile_width) / tile_width * texture.get_width(), 0,
					(right-left) / tile_width * texture.get_width(), texture.get_height()))


func _draw_rounded_bank(world: Rect2, local: Rect2, neighbours: Array[Rect2], texture: Texture2D) -> void:
	var curved_face := kind in ["shore", "sea", "island"]
	var top := local.position.y if curved_face else local.position.y - TERRACE_LIP
	var max_radius := TERRACE_ROUND
	match kind:
		"shore": max_radius = 40.0
		"sea", "island": max_radius = 60.0
	var outline := PackedVector2Array()
	var meets_higher := [false, false]
	for side in [-1, 1]:
		var edge := world.position.x if side == -1 else world.end.x
		var radius := minf(max_radius, local.size.x * 0.5)
		for other in neighbours:
			var contact := other.end.x if side == -1 else other.position.x
			if is_equal_approx(edge, contact):
				var drop := other.position.y - world.position.y
				radius = minf(radius, maxf(0.0, drop))
				if drop < 0.0:
					meets_higher[int(side == 1)] = true
		var x := edge - global_position.x
		if is_zero_approx(radius):
			outline.append(Vector2(x, top))
			continue
		var centre := Vector2(x - side * radius, top + radius)
		if kind in ["sea", "island"]:
			# Ease into the basin floor as well as out of the high bank. Keep
			# most of the visible drop close to the collision step.
			for step in range(9):
				var t := float(step) / 8.0
				var from_high := t if side == 1 else 1.0 - t
				var slope := smoothstep(0.0, 1.0, pow(from_high, 2.4))
				outline.append(Vector2(lerpf(centre.x, x, from_high), top + radius * slope))
			continue
		var start := PI if side == -1 else 1.5 * PI
		for step in range(9):
			outline.append(centre + Vector2.from_angle(start + step * PI / 16.0) * radius)
	if curved_face:
		_draw_curved_face(outline, local.end.y, texture)
		return
	outline.append(Vector2(local.end.x, local.end.y))
	outline.append(Vector2(local.position.x, local.end.y))

	var uv := PackedVector2Array()
	var joins := PackedColorArray()
	for point in outline:
		uv.append(Vector2(point.x + global_position.x, point.y - top) / texture.get_size())
		# The shader reads distance to each uphill join from the vertex colours.
		var left := (point.x - local.position.x) / TERRACE_JOIN_SCALE if meets_higher[0] else 1.0
		var right := (local.end.x - point.x) / TERRACE_JOIN_SCALE if meets_higher[1] else 1.0
		joins.append(Color(left, right, 0.0))
	_ground.draw_polygon(outline, joins, uv, texture)


func _draw_curved_face(outline: PackedVector2Array, bottom: float, texture: Texture2D) -> void:
	# The UVs measure depth from the curved surface and keep the texture on the bank.
	for index in range(outline.size() - 1):
		var a := outline[index]
		var b := outline[index + 1]
		var vertices := PackedVector2Array([a, b, Vector2(b.x, bottom), Vector2(a.x, bottom)])
		var u_a := (a.x + global_position.x) / texture.get_width()
		var u_b := (b.x + global_position.x) / texture.get_width()
		var uv := PackedVector2Array([Vector2(u_a, 0), Vector2(u_b, 0),
			Vector2(u_b, (bottom - b.y) / texture.get_height()),
			Vector2(u_a, (bottom - a.y) / texture.get_height())])
		_ground.draw_polygon(vertices, PackedColorArray([Color.WHITE]), uv, texture)
