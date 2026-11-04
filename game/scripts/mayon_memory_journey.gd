extends Node
## Two visual canvases share the gameplay camera transform. There is exactly one physics route;
## the render canvases contain no bodies, players, level hosts or input handlers.

const FragmentScript = preload("res://scripts/memory_fragment_2d.gd")
const DIVIDER = preload("res://shaders/memory_divider.gdshader")
const FACTOR := 2.2
const COLUMN_PIXELS := 280.0
const SOFTNESS_PIXELS := 360.0

var parallax_factor := FACTOR
var column_pixels := COLUMN_PIXELS
var column_softness_pixels := SOFTNESS_PIXELS
var enabled := false
var places: Array = []
var route: Array[Rect2] = []
var scenes: Array[Node2D] = []
var fragments: Array[MemoryFragment2D] = []
var pair := Vector2i(-1, -1)
var divider := 2.0
var travel_camera_x := 0.0
var _camera: Camera2D
var _views: Array[SubViewport] = []
var _scenery: CanvasLayer
var _foreground: CanvasLayer
var _composite: TextureRect
var _column: ColorRect
var _material: ShaderMaterial
var _column_material: ShaderMaterial
var _storage: Node
var _owner_level: Node
var _data: Dictionary


func build(level: Node, data: Dictionary) -> void:
	_owner_level = level
	_data = data
	parallax_factor = float(data.journey.get("parallax_factor",FACTOR))
	column_pixels = float(data.journey.get("column_pixels",COLUMN_PIXELS))
	column_softness_pixels = float(data.journey.get("column_softness_pixels",SOFTNESS_PIXELS))
	_camera = level.call("_world_camera")
	places = data.journey.vignettes.duplicate(true)
	_storage = Node.new()
	_storage.name = "RememberedPlaces"
	_storage.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_storage)
	for spec: Dictionary in places:
		var scene := (load(String(spec.scene)) as PackedScene).instantiate() as Node2D
		scene.name = String(spec.id)
		scene.position = Vector2(float(spec.start), float(data.journey.floor_y))
		scene.set("span", float(spec.length))
		scene.visible = false
		_storage.add_child(scene)
		scenes.append(scene)
		_build_route(spec)
	# A one-screen first place also shows the approach on its left. Render the existing
	# far crater rim there, without creating a new collider across the crater opening.
	var scenery_route: Array[Rect2] = route.duplicate()
	var cone: Array = level.get_node("EnvironmentBaseplate/GameplayPlane/Terrain/Cone").get("platforms")
	scenery_route.append(cone[-1])
	for scene in scenes: scene.set("route", scenery_route)
	_build_landmarks(data.memories)
	_build_collision()
	_build_views()
	set_process(true)


func anchor(key: String) -> Vector2:
	var point: Array = _data.journey.anchors[key]
	return Vector2(float(point[0]), float(point[1]))


func _build_route(spec: Dictionary) -> void:
	var x := float(spec.start)
	var width := float(spec.length)
	var y := float(_data.journey.floor_y)
	# Only the middle of a place changes height. Every boundary has a long, identical floor.
	var profile: Array = spec.get("profile", [[0, 0], [width, 0]])
	for index in range(profile.size() - 1):
		var point: Array = profile[index]
		var next: Array = profile[index+1]
		route.append(Rect2(x+float(point[0]), y+float(point[1]),
			float(next[0])-float(point[0]), 1400.0))
	if float(profile[-1][0]) < width:
		route.append(Rect2(x+float(profile[-1][0]),y,width-float(profile[-1][0]),1400))


func _build_landmarks(memories: Array) -> void:
	for entry: Dictionary in memories:
		var index := index_of(String(entry.vignette))
		assert(index >= 0,"Unknown Mayon vignette for memory: " + String(entry.id))
		var fragment := FragmentScript.new()
		fragment.name = String(entry.id).to_pascal_case()
		fragment.fragment_id = String(entry.id)
		fragment.landmark_mode = true
		fragment.landmark_art = String(entry.landmark_art)
		fragment.landmark_width = float(entry.landmark_width)
		var spot: Array = entry.landmark_position
		fragment.position = Vector2(float(spot[0]), float(spot[1]))
		scenes[index].add_child(fragment)
		fragment.configure_memory(entry)
		fragments.append(fragment)


func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "MemoryRoute"
	body.collision_layer = 1
	body.collision_mask = 0
	_owner_level.get_node("EnvironmentBaseplate/GameplayPlane/Terrain").add_child(body)
	for rect in route:
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.get_center()
		body.add_child(shape)
	# The optional rocks' authored colliders are also the visual source of truth.
	var flower := _owner_level.get_node("EnvironmentBaseplate/GameplayPlane/Terrain/FlowerLedge")
	scenes[index_of("dilim_dawn")].set("ledges",flower.get("platforms"))


func _build_views() -> void:
	for index in range(2):
		var view := SubViewport.new()
		view.name = "SceneryPass%d" % index
		view.disable_3d = true
		view.world_2d = World2D.new()
		view.gui_disable_input = true
		view.transparent_bg = false
		view.process_mode = Node.PROCESS_MODE_PAUSABLE
		view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(view)
		_views.append(view)
	_scenery = CanvasLayer.new()
	_scenery.name = "MemoryScenery"
	_scenery.layer = -1
	_scenery.add_to_group(&"transition_world")
	add_child(_scenery)
	_composite = TextureRect.new()
	_composite.name = "ComplementaryScenes"
	_composite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_composite.texture = _views[0].get_texture()
	_material = ShaderMaterial.new()
	_material.shader = DIVIDER
	_material.set_shader_parameter("incoming", _views[1].get_texture())
	_composite.material = _material
	_scenery.add_child(_composite)
	_foreground = CanvasLayer.new()
	_foreground.name = "NearShadow"
	_foreground.layer = 1
	_foreground.add_to_group(&"transition_world")
	add_child(_foreground)
	_column = ColorRect.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column_material = ShaderMaterial.new()
	_column_material.shader = DIVIDER
	_column_material.set_shader_parameter("foreground", true)
	_column.material = _column_material
	_foreground.add_child(_column)
	_scenery.hide()
	_foreground.hide()
	process_mode = Node.PROCESS_MODE_ALWAYS


func activate(on: bool) -> void:
	enabled = on
	_scenery.visible = on
	_foreground.visible = on
	for view in _views:
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if on:
		travel_camera_x = _camera.global_position.x
		sync()
	else:
		for scene in scenes: scene.hide()


func _process(_delta: float) -> void:
	if enabled: sync()


func sync() -> void:
	if not enabled or _camera == null: return
	_camera.force_update_scroll()
	var viewport := _owner_level.get_viewport()
	var size := viewport.get_visible_rect().size
	var canvas := viewport.get_canvas_transform()
	if not get_tree().paused and not _camera.call("is_focused"):
		travel_camera_x = _camera.global_position.x
	for view in _views:
		view.size = Vector2i(size)
		view.canvas_transform = canvas
	_composite.size = size
	_column.size = size
	var next_pair := _pair_at(travel_camera_x, size.x, canvas.get_scale().x)
	if pair != next_pair: _mount_pair(next_pair)
	for scene in scenes:
		if scene.visible:
			scene.call("frame", _camera.global_position, size / canvas.get_scale())
	var column_width := column_pixels / size.x
	for mat in [_material, _column_material]:
		mat.set_shader_parameter("divider", divider)
		mat.set_shader_parameter("column_width", column_width)
		mat.set_shader_parameter("column_softness", column_softness_pixels / size.x)
	# The minimap uses the active scenery canvas, so it never stacks two places or duplicates her.
	var map = _owner_level.get("minimap")
	if map != null and map.get("_view") != null:
		var side := 1 if pair.x != pair.y and active_index(_owner_level.call("_player_anchor_position")) == pair.y else 0
		var world := _views[side].find_world_2d()
		if map.get("_view").world_2d != world:
			map.get("_view").world_2d = world
			map.refresh()


func _pair_at(camera_x: float, width: float, zoom: float) -> Vector2i:
	for index in range(1, places.size()):
		var seam := width * 0.5 - (camera_x - float(places[index].start)) * zoom * parallax_factor
		var margin := column_pixels * 0.5 + column_softness_pixels
		if seam > -margin and seam < width + margin:
			divider = seam / width
			return Vector2i(index-1, index)
	var current := 0
	for index in range(places.size()):
		if camera_x >= float(places[index].start): current = index
	divider = 2.0
	return Vector2i(current, current)


func _mount_pair(next_pair: Vector2i) -> void:
	for scene in scenes:
		scene.hide()
		if scene.get_parent() != _storage: scene.reparent(_storage, false)
	pair = next_pair
	for side in range(2):
		var index := pair.x if side == 0 else pair.y
		if side == 1 and pair.x == pair.y: continue
		scenes[index].reparent(_views[side], false)
		scenes[index].show()
	# Outside a wipe the second pass does no work. The shader samples the first everywhere.
	_views[1].render_target_update_mode = SubViewport.UPDATE_ALWAYS if pair.x != pair.y else SubViewport.UPDATE_DISABLED


func active_index(world_point: Vector2) -> int:
	if pair.x < 0: return 0
	if pair.x == pair.y: return pair.x
	var screen := _owner_level.get_viewport().get_canvas_transform() * world_point
	return pair.y if screen.x >= divider * _owner_level.get_viewport().get_visible_rect().size.x else pair.x


func index_of(id: String) -> int:
	for index in range(places.size()):
		if String(places[index].id) == id: return index
	return -1


func current_id(world_point: Vector2) -> String:
	return String(places[active_index(world_point)].id)


func region(world_point: Vector2) -> Rect2:
	var place: Dictionary = places[active_index(world_point)]
	return Rect2(float(place.start),float(_data.journey.floor_y)-760,float(place.length),900)
