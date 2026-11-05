extends Node2D
## Scenery only. Each stop has an authored composition and a small ambient phrase.
## No bodies, pickups, dialogue, sounds or extra actors enter either scenery viewport.

const CROSSING_WATER_SHADER := preload("res://shaders/mayon_crossing_water.gdshader")
const CROSSING_WATER_FRAMES: Array[String] = [
	"Level5/journey/crossing_falls_01.png",
	"Level5/journey/crossing_falls_02.png",
	"Level5/journey/crossing_falls_04.png",
]
const CROSSING_WATER_FPS := 6.0

var kind := ""
var props: Array = []
var route: Array[Rect2] = []
var world_origin := Vector2.ZERO
var river_bounds := Rect2()
var visitor := Vector2.INF
var view_bounds := Rect2(-800, -500, 2880, 1000)
var clock := 0.0
var _time := 0.0
var _scatter := 0.0
var _textures := {}
var _air: Node2D
## How long the place is. Its landmark palms stand at its middle.
var span := 1280.0
## The sea's moving surf, drawn BEHIND every prop on the shore and the island. It was drawn last, at
## half alpha over the palms and their rocks, and laid see-through wave bands and boxes across them.
var _water: Node2D
var _crossing_waterfall: Sprite2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if kind == "crossing":
		_crossing_waterfall = Sprite2D.new()
		_crossing_waterfall.name = "CrossingWaterfall"
		_crossing_waterfall.texture = _art(CROSSING_WATER_FRAMES[0])
		_crossing_waterfall.position = river_bounds.get_center()
		var frame_size := _crossing_waterfall.texture.get_size()
		_crossing_waterfall.scale = river_bounds.size / frame_size
		var material := ShaderMaterial.new()
		material.shader = CROSSING_WATER_SHADER
		var art_height := river_bounds.size.x * frame_size.y / frame_size.x
		material.set_shader_parameter("art_fraction", art_height / river_bounds.size.y)
		_crossing_waterfall.material = material
		add_child(_crossing_waterfall)
	_air = Node2D.new()
	_air.name = "WaterLightAndWildlife"
	_air.z_index = 2
	_air.draw.connect(_draw_air)
	add_child(_air)
	_water = Node2D.new()
	_water.name = "Surf"
	_water.show_behind_parent = true
	_water.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_water.draw.connect(_draw_water)
	add_child(_water)


func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	var reduced := Motion.reduced()
	if not reduced:
		clock += delta
		if kind in ["terraces", "crossing", "bale"] and visitor.is_finite():
			var distance_to_birds := visitor.distance_to(Vector2(980,_floor(980)-16))
			if distance_to_birds < 250: _scatter = minf(1.0,_scatter+delta*.65)
	_time = 0.0 if reduced else floorf(clock*15.0)/15.0
	if _crossing_waterfall != null:
		var frame := 0 if reduced else int(clock * CROSSING_WATER_FPS) % CROSSING_WATER_FRAMES.size()
		_crossing_waterfall.texture = _art(CROSSING_WATER_FRAMES[frame])
	queue_redraw()
	_air.queue_redraw()
	_water.queue_redraw()


func _art(path: String) -> Texture2D:
	if not _textures.has(path): _textures[path] = load("res://assets/"+path)
	return _textures[path] as Texture2D


func _floor(x: float) -> float:
	for rect in route:
		if x+world_origin.x >= rect.position.x and x+world_origin.x < rect.end.x:
			return rect.position.y-world_origin.y
	return 0.0


func _prop(canvas: Node2D, path: String, x: float, y: float, width: float,
		tint: Color = Color.WHITE, mirror: bool = false, angle: float = 0.0) -> void:
	var texture := _art(path)
	var height := width*texture.get_height()/texture.get_width()
	var point := Vector2(x-width*.5,y-height).round()
	if mirror or not is_zero_approx(angle):
		canvas.draw_set_transform(Vector2(x,y).round(),angle,Vector2(-1 if mirror else 1,1))
		canvas.draw_texture_rect(texture,Rect2(-width*.5,-height,width,height),false,tint)
		canvas.draw_set_transform(Vector2.ZERO)
	else:
		canvas.draw_texture_rect(texture,Rect2(point,Vector2(width,height)),false,tint)


func _draw() -> void:
	if kind == "island":
		var palms := _art("Level5/journey/palms_landmark.png")
		var width := 310.0
		var height := width * palms.get_height() / palms.get_width()
		draw_texture_rect(palms, Rect2(span*.5-180, -height, width, height), false)
	if kind in ["forest", "waterfall", "dawn"]:
		var shade := Color(.62,.72,.82) if kind != "dawn" else Color(.94,.99,.78)
		# The supplied tree frame encloses a clearing; it belongs to the same forest
		# as the distant mountain plates, and is registered to the walk line.
		_prop(self,"Level4/backdrop/frame.png",640,70,1900,shade)
	for spec: Dictionary in props:
		var tint := Color.WHITE
		if spec.has("tint"):
			var c: Array = spec.tint
			tint = Color(float(c[0]),float(c[1]),float(c[2]),float(c[3]))
		var x := float(spec.x)
		var y := _floor(x)+float(spec.get("lift",0)) if bool(spec.get("floor",false)) else float(spec.get("y",0))
		_prop(self,String(spec.art),x,y,float(spec.width),tint,bool(spec.get("mirror",false)),float(spec.get("rotation",0)))
	match kind:
		"bale": _yard()
		"sea": _reef()


func _yard() -> void:
	# A warm lamp and the stored harvest make this a lived-in Bale yard.
	var lamp := Vector2(410,_floor(410)-28)
	for ring in range(4,0,-1): draw_circle(lamp,ring*11,Color(1,.72,.26,.018))
	draw_circle(lamp,3,Color("ffd885"))


func _draw_water() -> void:
	if kind not in ["shore", "island"]:
		return
	var frame := int(_time/.32)%3
	var surf := _art("Level5/journey/surf_%02d.png" % frame)
	if kind == "shore":
		# Carry the ocean colour into the lowered sand, behind the bank and boat.
		# The transparent upper edge merges into the distant water.
		var near := Color(.12, .51, .68, .38)
		var clear := Color(near, 0.0)
		var left := view_bounds.position.x
		var right := view_bounds.end.x
		_water.draw_polygon(PackedVector2Array([
			Vector2(left, -38), Vector2(right, -38), Vector2(right, 80), Vector2(left, 80),
		]), PackedColorArray([clear, clear, near, near]))
	_surf_strip(surf, Rect2(Vector2.ZERO, surf.get_size()), -42.0, 0.0, 0.48)
	if kind == "shore":
		# The nearest crest meets the sand; the banks hide the part under dry land.
		_surf_strip(surf, Rect2(0, 0, surf.get_width(), 66), 43.0, 243.0, 0.45)
	if kind == "island":
		_prop(_water,"Level3/authored/bangka_afloat.png",210+sin(_time*.22)*7,-106,150,Color(.66,.79,.84))


func _surf_strip(texture: Texture2D, source: Rect2, bottom: float, phase: float, opacity: float) -> void:
	var width := 1450.0
	var height := width * source.size.y / source.size.x
	var origin := (span - width) * 0.5 + phase
	var first := floori((view_bounds.position.x - origin) / width)
	var end := ceili((view_bounds.end.x - origin) / width)
	var tint := Color(1, 1, 1, opacity)
	# Mirror neighbours in the same frame so their crests share the edge pixels.
	for index in range(first, end):
		var x := origin + index * width
		var mirror := posmod(index, 2) == 1
		_water.draw_set_transform(Vector2(x + width if mirror else x, bottom - height),
			0.0, Vector2(-1 if mirror else 1, 1))
		_water.draw_texture_rect_region(texture, Rect2(0, 0, width, height), source, tint)
	_water.draw_set_transform(Vector2.ZERO)


## The shore and island's surf, behind everything standing on them (see _water).
func draws_surf_behind_scenery() -> bool:
	return _water != null and _water.show_behind_parent and kind in ["shore", "island"]


func _reef() -> void:
	for spec in [[130.0,100.0,0.0],[330.0,65.0,1.0],[1125.0,105.0,2.0],[1215.0,70.0,1.0]]:
		var frame := (int(_time/.36)+int(spec[2]))%3
		_prop(self,"Level5/journey/kelp_long_%02d.png"%frame,float(spec[0]),_floor(float(spec[0])),float(spec[1]),Color(.58,.86,.73))
	for spec in [[240.0,95.0,0.0],[1020.0,100.0,1.0]]:
		var frame := (int(_time/.4)+int(spec[2]))%3
		_prop(self,"Level5/journey/coral_red_%02d.png"%frame,float(spec[0]),_floor(float(spec[0])),float(spec[1]))
	for x in [430.0,960.0]:
		_prop(self,"Level5/journey/kelp_short_%02d.png"%(int(_time/.38)%3),x,_floor(x),48,Color(.64,.9,.73))
	_prop(self,"Level5/journey/coral_orange_%02d.png"%(int(_time/.4)%3),1080,_floor(1080),64)
	for index in range(2):
		var x := -220.0+fposmod(_time*(22+index*8)+index*790,1740)
		var y := -300.0-index*135+sin(_time*.35+index)*18
		_prop(self,"Level5/journey/fish_school_%02d.png"%(int(_time/.22)%4),x,y,200+index*70,Color(.35,.69,.79,.65))
	_prop(self,"Level3/authored/jelly_%d.png"%(int(_time/.34)%4),390+sin(_time*.3)*22,-180+sin(_time*.6)*15,42,Color(.72,.82,1,.72))


func _landmark_colour(id: String) -> float:
	for child in get_parent().get_children():
		if child is MemoryFragment2D and child.fragment_id == id:
			return 0.0 if child.state() == "lost" else 1.0-child.drain()
	return 0.0


func _draw_air() -> void:
	match kind:
		"terraces", "crossing", "bale":
			_payyo_air()
		"shore", "island":
			for index in range(3):
				var x := -150.0+fposmod(_time*(28+index*9)+index*480,1580)
				var y := -470.0+index*55+sin(_time*.4+index)*16
				_prop(_air,"Level3/authored/gull_%d.png"%(int(_time/.2+index)%4),x,y,39,Color(.92,.96,1,.8))
		"sea": _bubbles()
		"forest", "waterfall", "dawn": _forest_air()
	if kind == "waterfall": _falling_water()


func _payyo_air() -> void:
	for index in range(3):
		var x := 900.0+index*42+_scatter*(180+index*35)
		var y := _floor(980)-18.0-_scatter*(170+index*38)
		var wing := sin(_time*(7+index)+index)*4
		_air.draw_polyline(PackedVector2Array([Vector2(x-6,y-wing),Vector2(x,y+1),Vector2(x+6,y-wing)]),Color("483c24"),2)
	if kind != "crossing":
		for index in range(3):
			var x := 230+index*310+sin(_time*.7+index*2)*48
			var y := -90-index%2*85+cos(_time*.8+index)*22
			_butterfly(Vector2(x,y),Color("f4cf69"),index)


func _butterfly(point: Vector2, colour: Color, phase: int) -> void:
	var wing := 2+int(absf(sin(_time*6+phase))*4)
	_air.draw_rect(Rect2(point-Vector2(wing,3),Vector2(wing-1,5)),colour)
	_air.draw_rect(Rect2(point+Vector2(1,-3),Vector2(wing-1,5)),colour)
	_air.draw_rect(Rect2(point-Vector2(1,2),Vector2(2,5)),colour.darkened(.55))


func _bubbles() -> void:
	for index in range(18):
		var x := 150+fposmod(index*179.0,1000)+sin(_time*.6+index)*6
		var y := 30-fposmod(_time*(24+index%5*5)+index*47,620)
		_air.draw_arc(Vector2(x,y),2+index%3,0,TAU,8,Color(.55,.88,.94,.32),1)


func _forest_air() -> void:
	if kind == "dawn":
		# Light comes through the opening in the original canopy, toward the flower.
		for index in range(4):
			var x := 150+index*160
			_air.draw_colored_polygon(PackedVector2Array([Vector2(x,-780),Vector2(x+22,-780),Vector2(x+500,0),Vector2(x+310,0)]),Color(1,.87,.5,.035))
		for index in range(4):
			_butterfly(Vector2(260+index*230+sin(_time*.5+index)*34,-90-index%2*65+cos(_time*.7+index)*18),Color("ffe3a0"),index)
	else:
		for index in range(16):
			var x := 70+index*77+sin(_time*.35+index)*25
			var y := -30-fposmod(index*59.0,230)+sin(_time*.5+index)*15
			var near := 0.0 if not visitor.is_finite() else clampf(1.0-visitor.distance_to(Vector2(x,y))/330,0,1)
			var alpha := .24+near*.45+sin(_time*1.4+index)*.1
			_air.draw_circle(Vector2(x,y),7,Color(.72,.93,.43,alpha*.08))
			_air.draw_rect(Rect2(x,y,2,2),Color(.83,1,.55,alpha))
	# A low, broken mist follows the clearing, leaving the route and apo readable.
	for index in range(5):
		var x := -100+fposmod(index*330+_time*8,1550)
		var y := -18-index%2*30
		_air.draw_set_transform(Vector2(x+105,y+7),0,Vector2(1,.067))
		_air.draw_circle(Vector2.ZERO,105,Color(.72,.86,.81,.035 if kind == "dawn" else .06))
		_air.draw_set_transform(Vector2.ZERO)


func _falling_water() -> void:
	var strength := _landmark_colour("waterfall")
	if strength <= 0: return
	for index in range(34):
		var x := 617+fposmod(index*23.0,94)
		var y := -364+fposmod(_time*(100+index%4*15)+index*47,337)
		_air.draw_rect(Rect2(x,y,2,7+index%6),Color(.74,.95,.95,.35*strength))
	for index in range(7):
		var x := 620+index*17+sin(_time*.9+index)*12
		var y := 17-absf(sin(_time*1.5+index))*24
		_air.draw_circle(Vector2(x,y),12+index%3*4,Color(.72,.94,.92,.035*strength))
