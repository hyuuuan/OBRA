class_name MemoryFragment2D
extends Node2D
## One of Mayon's memory fragments: a torn piece of an earlier painting, broken loose from the
## mountain and drifting, going white (LEVEL_5.md, Act Two).
##
## It goes white once she first comes within SIGHT of it -- slowly, as if there were time -- and
## all at once when she has gone PASSED_BY on beyond it: there is no going back down. White, then
## blank: at blank it is lost. Drawing something that belongs in it, while she is near, saves it:
## the colour comes back and stays, and her lines are inked into it.
##
## Nothing about it says what it is worth: no value, no cost, no count (the design: the player
## must not be able to optimise).

signal saved(fragment_id: String)
signal lost(fragment_id: String)

const FOLDER := "res://assets/Level5/fragments/"
## How near she must come before it begins to go.
const SIGHT := 700.0
## How long it takes to go to paper on its own, from when she first sees it.
const FADE_SECONDS := 90.0
## Gone this far past it, it goes in PASSED_SECONDS.
const PASSED_BY := 600.0
const PASSED_SECONDS := 4.0
## Where it stops fading on its own: flat paper, not yet blank -- the passing takes it the rest.
const PAPER := 0.85
## How fast a saved fragment's colour comes back.
const RECOVER_SECONDS := 1.2
## The drift and the bob, in px and per second.
const BOB := 6.0
const INK := Color(0.12, 0.1, 0.09, 0.95)
## The rim on the fragment a drawing would go into: the interface's gold, soft-cornered, breathing.
## It sits behind the picture and outside it, so the drain never whitens it.
const RIM_MARGIN := 7.0
const RIM_BREATH := 2.4

@export var fragment_id: String = ""
## The classes that belong in it: drawing one, near it, saves it.
@export var accepts: PackedStringArray = []
## Whether lolo is in it: saving it steadies him for a while.
@export var holds_lolo := false
## How near she must stand for a drawing to go into it. The flower's is short: it is saved from
## its ledge, off the path, not from the path beneath.
@export var reach := 320.0
## Cluster-managed fragments start together, rather than reacting to x through a wall.
var cluster_managed := false
var cluster_id := ""
var summit_texture: Texture2D
var bloom_width := 800.0
var bloom_elevation := 0.0
var bloom_tint := Color.WHITE


func configure_memory(entry: Dictionary) -> void:
	accepts = PackedStringArray(entry.get("accepts", []))
	holds_lolo = bool(entry.get("holds_lolo", false))
	cluster_id = String(entry.get("cluster", ""))
	cluster_managed = not cluster_id.is_empty()
	reach = float(entry.get("reach", reach))
	summit_texture = load(String(entry.get("summit_art", FOLDER + fragment_id + ".png"))) as Texture2D
	bloom_width = float(entry.get("bloom_width", 800.0))
	bloom_elevation = float(entry.get("bloom_elevation", 0.0))
	var shade: Array = entry.get("bloom_tint", [1,1,1,1])
	bloom_tint = Color(float(shade[0]),float(shade[1]),float(shade[2]),float(shade[3]))


func begin_whitening() -> void:
	if _state == "whole":
		_state = "draining"
		_drainable.drain_to(PAPER, FADE_SECONDS * (1.0 - drain() / PAPER))


func leave_behind() -> void:
	if is_open():
		_state = "passing"
		_drainable.drain_to(1.0, PASSED_SECONDS)


func snapshot() -> Dictionary:
	return {"state": _state, "strokes": _strokes.duplicate(true), "drain": drain()}


func restore_snapshot(entry: Dictionary) -> void:
	restore_to(String(entry.get("state", "whole")), entry.get("strokes", []))
	if _state not in ["whole", "saved", "lost"]:
		_drainable.drain_to(float(entry.get("drain", 0.0)), 0.0)
		if _state == "passing":
			_drainable.drain_to(1.0, PASSED_SECONDS * (1.0 - drain()))
		else:
			_drainable.drain_to(PAPER, FADE_SECONDS * (1.0 - drain() / PAPER))

var _state := "whole"
var _sprite: Sprite2D
var _drainable: Drainable
var _ink: Node2D
var _strokes: Array = []
var _time := 0.0
var _phase := 0.0
var _targeted := false
var _rim: Node2D
var _rim_style: StyleBoxFlat


func _ready() -> void:
	add_to_group(&"memory_fragments")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rim = Node2D.new()
	_rim.name = "Rim"
	_rim.visible = false
	_rim.draw.connect(_draw_rim)
	add_child(_rim)
	_rim_style = StyleBoxFlat.new()
	_rim_style.bg_color = Color(UISkin.GOLD_PALE, 0.22)
	_rim_style.border_color = UISkin.GOLD
	_rim_style.set_border_width_all(3)
	_rim_style.set_corner_radius_all(8)
	_sprite = Sprite2D.new()
	_sprite.name = "Picture"
	_sprite.texture = load(FOLDER + fragment_id + ".png") as Texture2D
	add_child(_sprite)
	_ink = Node2D.new()
	_ink.name = "Ink"
	_ink.draw.connect(_draw_ink)
	_sprite.add_child(_ink)
	_drainable = Drainable.new()
	_drainable.name = "Drainable"
	_sprite.add_child(_drainable)
	_drainable.blanked.connect(_on_blanked)
	_phase = float(fragment_id.hash() % 628) / 100.0


func state() -> String:
	return _state


## Whether it can still be saved.
func is_open() -> bool:
	return _state == "whole" or _state == "draining"


## Lit as the one a drawing would go into now. Only while it can still be saved.
func set_targeted(on: bool) -> void:
	var lit := on and is_open()
	if lit == _targeted:
		return
	_targeted = lit
	_rim.visible = lit


func is_targeted() -> bool:
	return _targeted


func belongs(entity_id: String) -> bool:
	return accepts.has(entity_id)


func drain() -> float:
	return _drainable.drain if _drainable != null else 0.0


func strokes() -> Array:
	return _strokes


## Called by the level every physics frame with where she is.
func notice(her_x: float) -> void:
	if cluster_managed or not is_open():
		return
	var ahead := global_position.x - her_x
	if _state == "whole" and absf(ahead) <= SIGHT:
		_state = "draining"
		_drainable.drain_to(PAPER, FADE_SECONDS * (1.0 - drain() / PAPER))
	if _state == "draining" and -ahead >= PASSED_BY:
		_state = "passing"
		_drainable.drain_to(1.0, PASSED_SECONDS * (1.0 - drain()))


## Saved: the colour comes back and stays, and her lines are inked into it.
func save(strokes: Array) -> void:
	if not is_open():
		return
	_state = "saved"
	set_targeted(false)
	_strokes = _plain(strokes)
	_drainable.drain_to(0.0, RECOVER_SECONDS)
	_ink.queue_redraw()
	saved.emit(fragment_id)


## For a checkpoint: as it was when the checkpoint was written.
func restore_to(state_name: String, plain_strokes: Array = []) -> void:
	_strokes = plain_strokes.duplicate(true)
	_ink.queue_redraw()
	_drainable.restore()
	visible = true
	match state_name:
		"saved":
			_state = "saved"
		"lost":
			_state = "lost"
			_drainable.drain_to(1.0, 0.0)
		"draining", "passing":
			_state = state_name
		_:
			_state = "whole"


## The strokes as plain data -- [[x, y, x, y, ...], ...] -- so a checkpoint can keep them.
func _plain(strokes: Array) -> Array:
	var out: Array = []
	for stroke: Variant in strokes:
		var points: Variant = (stroke as Dictionary).get("points", []) if stroke is Dictionary else stroke
		var flat: Array = []
		for point: Vector2 in points:
			flat.append(point.x)
			flat.append(point.y)
		if flat.size() >= 4:
			out.append(flat)
	return out


func _on_blanked() -> void:
	if _state == "saved":
		return
	_state = "lost"
	lost.emit(fragment_id)


func _process(delta: float) -> void:
	_time += delta
	# Loose: it bobs and drifts a little, never quite still.
	_sprite.position = Vector2.ZERO if Motion.reduced() else Vector2(
		sin(_time * 0.37 + _phase) * BOB * 1.5, sin(_time * 0.9 + _phase) * BOB).round()
	if _targeted:
		_rim.position = _sprite.position
		_rim.modulate.a = 0.9 if Motion.reduced() else 0.7 + 0.3 * sin(_time * TAU / RIM_BREATH)
		_rim.queue_redraw()


func _draw_rim() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	# Follow the torn silhouette. A rounded UI frame made these read as menu cards.
	var size := _sprite.texture.get_size() + Vector2.ONE * RIM_MARGIN * 2.0
	_rim.draw_texture_rect(_sprite.texture,Rect2(-size*.5+Vector2(0,3),size),false,
		Color(0.12,0.08,0.04,.8))
	_rim.draw_texture_rect(_sprite.texture,Rect2(-size*.5,size),false,
		Color(UISkin.GOLD_PALE,.65))


## Her lines, fitted into the middle of the picture, in the ink she drew them in.
func _draw_ink() -> void:
	if _strokes.is_empty() or _sprite.texture == null:
		return
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for flat: Array in _strokes:
		for index in range(0, flat.size(), 2):
			var point := Vector2(float(flat[index]), float(flat[index + 1]))
			low = low.min(point)
			high = high.max(point)
	var span := (high - low).max(Vector2.ONE)
	var room := _sprite.texture.get_size() * 0.5
	var fit := minf(room.x / span.x, room.y / span.y)
	var centre := (low + high) * 0.5
	for flat: Array in _strokes:
		var line := PackedVector2Array()
		for index in range(0, flat.size(), 2):
			line.append(((Vector2(float(flat[index]), float(flat[index + 1])) - centre) * fit).round())
		_ink.draw_polyline(line, INK, 2.0)
