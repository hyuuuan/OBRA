extends Node2D
## Sparse gusts at three actual draw depths, with independent camera travel.
## The ordinary gameplay clock holds them during dialogue and drawing.
const ART := preload("res://assets/Level5/weather/wind_streaks.png")
const COLUMNS := 3
const FRAMES := 4
const CYCLE := 7.2
const LIFETIME := 3.8
const PLACES := [Vector2(0.79, 0.29), Vector2(0.48, 0.46),
	Vector2(0.73, 0.62), Vector2(0.55, 0.37)]
## The closest gust is the previous maximum size. Far gusts sit behind the trees
## and ground; middle gusts behind the actors; near gusts in front of the actors.
const DEPTHS := [
	{"z": -60, "size": 0.38, "scroll": 0.32, "opacity": 0.28, "height": Vector2(0.24, 0.50)},
	{"z": -4, "size": 0.65, "scroll": 0.78, "opacity": 0.37, "height": Vector2(0.36, 0.64)},
	{"z": 16, "size": 1.0, "scroll": 1.18, "opacity": 0.46, "height": Vector2(0.60, 0.84)},
]

@export var enabled := true:
	set(value):
		if enabled == value:
			return
		enabled = value
		_refresh_gusts()

var _time := 0.0
var _frame := -1
var _reduced := false
var _gusts: Array[Sprite2D] = []
var _passes: Array[int] = []
var _birth_eyes: Array[Vector2] = []
var _starts: Array[Vector2] = []


func _ready() -> void:
	# A dialogue camera may process while paused; weather must keep the world clock.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for index in range(PLACES.size()):
		var gust := Sprite2D.new()
		gust.name = "Gust%d" % (index + 1)
		gust.texture = ART
		gust.hframes = COLUMNS
		gust.vframes = FRAMES
		gust.z_as_relative = false
		gust.hide()
		add_child(gust)
		_gusts.append(gust)
		_passes.append(-2147483648)
		_birth_eyes.append(Vector2.ZERO)
		_starts.append(Vector2.ZERO)
	var camera := get_parent() as Camera2D
	if camera != null and camera.has_signal(&"camera_moved"):
		camera.connect(&"camera_moved", _on_camera_moved)
	_refresh_gusts()


func _process(delta: float) -> void:
	var reduced := Motion.reduced()
	if _reduced != reduced:
		_reduced = reduced
		_refresh_gusts()
	if not enabled or reduced:
		return
	_time += delta
	var frame := floori(_time * Motion.PIXEL_FPS)
	if frame != _frame:
		_frame = frame
		_refresh_gusts()


func _on_camera_moved(_at: Vector2) -> void:
	# Reproject even during a paused camera pan, without advancing the gust's age.
	_refresh_gusts()


func _refresh_gusts() -> void:
	if _gusts.is_empty():
		return
	var hidden := not enabled or Motion.reduced() or _frame < 0
	var camera := get_parent() as Camera2D
	var zoom := camera.zoom if camera != null else Vector2.ONE
	var eye := camera.global_position if camera != null else Vector2.ZERO
	var view := get_viewport_rect().size / zoom
	var clock := float(maxi(0, _frame)) / Motion.PIXEL_FPS
	var cell := ART.get_size() / Vector2(COLUMNS, FRAMES)
	for index in range(PLACES.size()):
		var gust := _gusts[index]
		var elapsed := clock + index * CYCLE / PLACES.size()
		var age := fposmod(elapsed, CYCLE)
		if hidden or age >= LIFETIME:
			gust.hide()
			continue
		var progress := age / LIFETIME
		var fade := smoothstep(0.0, 0.18, progress) * (1.0 - smoothstep(0.72, 1.0, progress))
		var pass_index := floori(elapsed / CYCLE)
		# Spawn order cycles far -> middle -> near without adding any extra gusts.
		var layer: Dictionary = DEPTHS[posmod(pass_index * PLACES.size() - index, DEPTHS.size())]
		if _passes[index] != pass_index:
			_passes[index] = pass_index
			_birth_eyes[index] = eye
			var height: Vector2 = layer.height
			var place := Vector2(PLACES[index].x,
				lerpf(height.x, height.y, fposmod(index * 0.47 + pass_index * 0.31, 1.0)))
			_starts[index] = place * view - view * 0.5 + Vector2(
				sin(pass_index * 2.3 + index) * 70.0, sin(pass_index * 1.7 + index) * 24.0)
		var drift := Vector2(-240.0 * progress, sin(progress * PI) * 15.0) * float(layer.size)
		var at := _starts[index] + drift - (eye - _birth_eyes[index]) * float(layer.scroll)
		var variant := posmod(index + pass_index * 2, COLUMNS)
		var frame := mini(FRAMES - 1, int(progress * FRAMES))
		gust.z_index = int(layer.z)
		gust.frame = frame * COLUMNS + variant
		gust.position = at.round()
		gust.scale = Vector2.ONE * ((180.0 + variant * 15.0) / cell.x) * float(layer.size)
		gust.modulate.a = fade * float(layer.opacity)
		gust.show()
