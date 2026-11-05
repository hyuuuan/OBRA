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
var _stage: Node2D
var staging: Dictionary = {}
const StageScript = preload("res://scripts/mayon_memory_stage.gd")
const TERRACE_GROUND := preload("res://shaders/mayon_terrace_ground.gdshader")
const TERRACE_LIP := 8.0
const TERRACE_ROUND := 34.0
const TERRACE_JOIN_SCALE := 2048.0
const CROSSING_HALF_WIDTH := 210.0

const BACKDROPS := {
 "terraces": ["Level5/journey/payyo_sky.png"], "crossing": ["Level5/journey/payyo_sky.png"],
 "bale": ["Level5/journey/payyo_sky.png"], "plaza": ["Level5/journey/plaza_sky.png"],
 "church": ["Level5/journey/church_sky.png"], "alley": ["Level5/journey/alley_sky.png"],
 "shore": ["Level5/journey/shore_sky.png"], "sea": ["Level5/journey/sea_sky.png"],
 "island": ["Level5/journey/shore_sky.png"], "forest": ["Level5/journey/forest_sky.png"],
 "waterfall": ["Level5/journey/forest_sky.png"], "dawn": ["Level5/journey/dawn_sky.png"], "summit": [],
}
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
	"forest": Color("1c2739"),
	"waterfall": Color("1c2739"),
	"dawn": Color("434646"),
}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -20
	if kind not in ["plaza", "church", "alley", "summit"]:
		_stage = StageScript.new()
		_stage.name = "RememberedLife"
		_stage.set("kind",kind)
		_stage.set("props",staging.get("props",[]))
		_stage.set("span",span)
		if kind == "crossing":
			var opening := Rect2(span * 0.5 - CROSSING_HALF_WIDTH, 0.0,
				CROSSING_HALF_WIDTH * 2.0, 1400.0)
			# Tuck the water under the rounded turf lips so no sky peeks through.
			_stage.set("river_bounds", opening.grow_individual(16.0, 0.0, 16.0, 0.0))
		add_child(_stage)
	_ground = Node2D.new()
	_ground.name = "WalkSurface"
	_ground.z_index = 1
	if kind in ["terraces", "crossing", "bale"]:
		var material := ShaderMaterial.new()
		material.shader = TERRACE_GROUND
		_ground.material = material
	_ground.draw.connect(_draw_walk_surface)
	add_child(_ground)
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
	camera_position = camera
	view_size = extent
	if _stage != null:
		_stage.set("visitor",player_position-global_position)
		_stage.set("route",route)
		_stage.set("world_origin",global_position)
	queue_redraw()
	_ground.queue_redraw()


func _art(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load("res://assets/" + path)
	return _textures[path] as Texture2D


func _draw() -> void:
	var eye := camera_position - global_position
	var bounds := Rect2(eye - view_size * 0.5 - Vector2(200, 200), view_size + Vector2(400, 400))
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
			# The plaza already has sky extended on both sides. Its cut IS the walk line.
			height = 720.0
			width = height * texture.get_width() / texture.get_height()
			x = span * .5 - width * .5
			y = -height
		elif kind == "church":
			height = 820.0
			width = height * texture.get_width() / texture.get_height()
			x = span * .5 - width * .5
			y = -height
		elif kind == "alley":
			# Grounded buildings share the walk line's world motion.
			x = span * .5 - width * .5
		# Repeat only the authored sky/landscape, with mirrored neighbours at the ends.
		for repeat_index in [-1, 0, 1]:
			var rect := Rect2(x + repeat_index * width, y, width, height)
			if repeat_index == 0:
				draw_texture_rect(texture, rect, false, tint)
			else:
				draw_set_transform(Vector2(rect.end.x,rect.position.y),0.0,Vector2(-1,1))
				draw_texture_rect(texture,Rect2(Vector2.ZERO,rect.size),false,tint)
				draw_set_transform(Vector2.ZERO)
	# The island's palms are the stage's now: the surf passes behind them (RememberedLife).


func _draw_walk_surface() -> void:
	var eye := camera_position - global_position
	var bounds := Rect2(eye-view_size*.5-Vector2(200,200),view_size+Vector2(400,400))
	_draw_ground(bounds)
	if kind == "dawn":
		var rock := _art("Level5/terrain/basalt.png")
		for ledge in ledges:
			_ground.draw_texture_rect(rock,Rect2(ledge.position-global_position,ledge.size),false)
	if kind in ["shore", "sea"]:
		var water := Color(.16,.52,.68,.38) if kind == "shore" else Color(.12,.47,.63,.3)
		for rect in route:
			var local := Rect2(rect.position-global_position,rect.size)
			if local.position.x < 0 or local.position.x >= span or local.position.y <= 0: continue
			# The visible shallows end on the actual seabed, including every lowered step.
			_ground.draw_rect(Rect2(local.position.x,0,local.size.x,local.position.y),water)
			for ripple in range(floori(local.size.x/70.0)):
				var x := local.position.x+15+ripple*70
				_ground.draw_line(Vector2(x,12),Vector2(x+37,12),Color(.65,.88,.91,.6),2)


func _draw_ground(bounds: Rect2) -> void:
	var ground := Color("544638")
	var surface := "Level1/cliff/face.png"
	if kind == "church":
		surface = "Level2/interiors/church_floor.png"
		ground = Color("88785d")
	elif kind in ["plaza", "alley"]:
		surface = "Level2/plaza/retaining.png"
		ground = Color("8a7660")
	elif kind in ["shore", "island", "sea"]:
		surface = "Level3/authored/seabed_floor.png" if kind == "sea" else "Level5/journey/sand_ground.png"
		ground = Color("a08661") if kind != "sea" else Color("264c57")
	elif kind in ["forest", "waterfall", "dawn"]:
		surface = "Level4/ground_forest/face.png"
		ground = Color("35463a")
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
		if kind in ["terraces", "crossing", "bale"]:
			_draw_terrace_bank(rect, local, ground_rects, texture)
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


func _draw_terrace_bank(world: Rect2, local: Rect2, neighbours: Array[Rect2], texture: Texture2D) -> void:
	var top := local.position.y - TERRACE_LIP
	var outline := PackedVector2Array()
	var meets_higher := [false, false]
	for side in [-1, 1]:
		var edge := world.position.x if side == -1 else world.end.x
		var radius := minf(TERRACE_ROUND, local.size.x * 0.5)
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
		var start := PI if side == -1 else 1.5 * PI
		for step in range(9):
			outline.append(centre + Vector2.from_angle(start + step * PI / 16.0) * radius)
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
