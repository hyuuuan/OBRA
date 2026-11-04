extends Node2D
## A real opening in the mountain. The player's physics anchor enters it; there is no E prompt.
const WIDTH := 500.0
const BASALT := preload("res://assets/Level5/props/basalt_spires.png")
const FACE := preload("res://assets/Level5/terrain/basalt.png")
const LAVA := preload("res://shaders/crater_lava.gdshader")
var _clock := 0.0
var _lava: Polygon2D
var _molten: ShaderMaterial

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 12
	var throat := Polygon2D.new()
	throat.polygon = PackedVector2Array([Vector2(-200,45),Vector2(200,45),Vector2(200,550),Vector2(-200,550)])
	throat.color = Color("381c22")
	throat.z_index = -2
	add_child(throat)
	_lava = Polygon2D.new()
	_lava.name = "MoltenSurface"
	_lava.z_index = -1
	_molten = ShaderMaterial.new()
	_molten.shader = LAVA
	_lava.material = _molten
	add_child(_lava)
	visibility_changed.connect(func() -> void: set_process(is_visible_in_tree()))
	_refresh_surface()

func _process(delta: float) -> void:
	if not Motion.reduced(): _clock += delta
	_molten.set_shader_parameter("lava_clock",_clock)
	_refresh_surface()
	queue_redraw()

func _refresh_surface() -> void:
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	for step in range(39):
		var x := -190.0+step*10.0
		var y := snappedf(75.0+pow(x/190.0,2)*24.0+sin(x*.035+_clock*1.6)*4,3.0)
		points.append(Vector2(x,y))
	points.append(Vector2(190,540))
	points.append(Vector2(-190,540))
	for point in points: uv.append(Vector2((point.x+190.0)/380.0,(point.y-65.0)/475.0))
	_lava.polygon=points
	_lava.uv=uv

func _draw() -> void:
	# The mountain's own basalt textures cover the irregular lips. No decorative collider.
	_rock(PackedVector2Array([Vector2(-340,90),Vector2(-310,-15),Vector2(-250,-50),
		Vector2(-210,-18),Vector2(-180,140),Vector2(-170,330),Vector2(-350,330)]),Color(.8,.66,.6))
	_rock(PackedVector2Array([Vector2(180,140),Vector2(210,-18),Vector2(250,-45),
		Vector2(310,-5),Vector2(340,90),Vector2(350,330),Vector2(170,330)]),Color(.95,.73,.6))
	for i in range(16):
		var rise := fposmod(_clock*(30+i%4*9)+i*53,500)
		var x := sin(i*9.7+_clock*.3)*160
		draw_rect(Rect2(x,180-rise,4+i%3*2,5+i%2*3),Color(1,.53,.19,(1-rise/500)*.9))
	for i in range(9):
		var rise := fposmod(_clock*26+i*74,610)
		var x := sin(i*4.2+rise*.004)*90
		draw_circle(Vector2(x,180-rise),44+rise*.12,Color(.19,.17,.21,(1-rise/610)*.30))
	draw_texture_rect(BASALT,Rect2(-335,-55,165,360),false,Color(.55,.46,.47))
	draw_set_transform(Vector2(335,-55),0,Vector2(-1,1))
	draw_texture_rect(BASALT,Rect2(0,0,165,360),false,Color(.68,.53,.48))
	draw_set_transform(Vector2.ZERO)

func _rock(points: PackedVector2Array,shade: Color) -> void:
	var uv := PackedVector2Array()
	for point in points:
		uv.append(Vector2(.3+absf(point.x)/FACE.get_width(),(point.y+55.0)/400.0))
	draw_polygon(points,PackedColorArray([shade]),uv,FACE)
