class_name WhipLash2D
extends Node2D
## The buntot pagi's lash, seen: an arc of its reach in front of her, there and gone.
##
## PLACEHOLDER until there is art (ART_PLACEHOLDERS): a pale curve, fading.

const SECONDS := 0.18
const LASH := Color(0.86, 0.80, 0.68)

var reach := 130.0
var facing := 1.0
var arc_degrees := 160.0

var _left := SECONDS


func _ready() -> void:
	z_index = 7


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var middle := 0.0 if facing > 0.0 else PI
	var half := deg_to_rad(arc_degrees * 0.5)
	draw_arc(Vector2.ZERO, reach, middle - half, middle + half, 18, Color(LASH, _left / SECONDS), 3.0)
