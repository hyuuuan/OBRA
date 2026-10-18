class_name Telegraph2D
extends Node2D
## The amber glint an enemy shows before it strikes: what makes every blow one she could see coming.
##
## A four-point star that grows from nothing to full over the windup and brightens at the end,
## drawn in code so it needs no art and reads the same on every creature, in the dark included.
## Amber because the game already uses amber for "about to happen" (the tiyanak's cry, the HUD's
## pending state) and never for anything harmless.

const COLOR := Color(1.0, 0.741, 0.239)
const CORE := Color(1.0, 0.95, 0.8)
## Its size at the end of the windup, in px from the centre to a point.
const REACH := 11.0

var _length := 0.0
var _elapsed := 0.0


func _ready() -> void:
	visible = false
	z_index = 5
	set_physics_process(false)


func show_for(seconds: float) -> void:
	_length = maxf(seconds, 0.01)
	_elapsed = 0.0
	visible = true
	set_physics_process(true)
	queue_redraw()


func stop() -> void:
	visible = false
	set_physics_process(false)


## How far through the windup it is, 0 to 1; 0 when not showing.
func progress() -> float:
	return clampf(_elapsed / _length, 0.0, 1.0) if visible else 0.0


func _physics_process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	var t := progress()
	var reach := REACH * (0.35 + 0.65 * t)
	var thin := reach * 0.28
	var glow := COLOR
	glow.a = 0.55 + 0.45 * t
	for axis: Vector2 in [Vector2.RIGHT, Vector2.DOWN]:
		var side := Vector2(-axis.y, axis.x) * thin
		draw_colored_polygon(PackedVector2Array([axis * reach, side, -axis * reach, -side]), glow)
	draw_circle(Vector2.ZERO, thin * (0.8 + 0.6 * t), CORE)
