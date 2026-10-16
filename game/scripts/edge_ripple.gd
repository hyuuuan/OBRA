class_name EdgeRipple
extends CanvasLayer
## WHERE A SOUND CAME FROM, for something heard in the dark rather than seen.
##
## A cue puts rings on the screen where the sound is -- or, when it is off screen, on the edge in
## its direction -- that grow and fade over LIFE seconds. The colour says what it is: violet for
## the tik-tik, amber for the tiyanak's cry (amber: something wants her to come closer). Strength
## is how loud: a far call faint, a near one strong. Above the dark (layer 3), under the HUD (5).

const LAYER := 4
const LIFE := 0.9
## How far in from the screen's edge an off-screen sound's rings sit.
const INSET := 28.0
const RINGS := 3
const REACH := 46.0
const COLORS := {
	"tiktik": Color(0.66, 0.45, 1.0),
	"tiyanak": Color(1.0, 0.741, 0.239),
}

var _ripples: Array[Dictionary] = []
var _canvas: Control


func _ready() -> void:
	layer = LAYER
	_canvas = Control.new()
	_canvas.name = "Rings"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_rings)
	add_child(_canvas)


## A sound of `kind` at `world_position`, `strength` 0 (silent) to 1 (right beside her).
func cue(kind: String, world_position: Vector2, strength: float) -> void:
	var loud := clampf(strength, 0.0, 1.0)
	if loud <= 0.0:
		return
	_ripples.append({"kind": kind, "at": world_position, "strength": loud, "age": 0.0})
	_canvas.queue_redraw()


func active() -> int:
	return _ripples.size()


## Where on screen a sound at `world_position` shows: itself when on screen, else the nearest
## point INSET in from the edge along the line from the centre toward it.
func screen_point(world_position: Vector2) -> Vector2:
	var viewport := get_viewport()
	var rect := viewport.get_visible_rect()
	var at := viewport.get_canvas_transform() * world_position
	var inner := rect.grow(-INSET)
	if inner.has_point(at):
		return at
	var centre := inner.get_center()
	var toward := at - centre
	var scale_x := (inner.size.x * 0.5) / maxf(absf(toward.x), 0.001)
	var scale_y := (inner.size.y * 0.5) / maxf(absf(toward.y), 0.001)
	return centre + toward * minf(scale_x, scale_y)


func _process(delta: float) -> void:
	if _ripples.is_empty():
		return
	for ripple in _ripples:
		ripple["age"] = float(ripple["age"]) + delta
	_ripples = _ripples.filter(func(ripple: Dictionary) -> bool: return float(ripple["age"]) < LIFE)
	_canvas.queue_redraw()


func _draw_rings() -> void:
	for ripple in _ripples:
		var t := float(ripple["age"]) / LIFE
		var colour: Color = COLORS.get(String(ripple["kind"]), Color.WHITE)
		var at := screen_point(ripple["at"])
		for ring in range(RINGS):
			var phase := fposmod(t + float(ring) / float(RINGS), 1.0)
			colour.a = float(ripple["strength"]) * (1.0 - phase) * (1.0 - t * 0.5)
			_canvas.draw_arc(at, 6.0 + phase * REACH, 0.0, TAU, 32, colour, 2.0, true)
