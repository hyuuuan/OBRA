class_name RuinedBridge2D
extends Node2D
## What is left of the hanging bridge Lola painted (Game Design, Level 1): two anchor
## posts and the frayed rope still tied to them. Scenery with no collision -- the point
## of it is that it does NOT hold anyone up.
##
## It reads left-to-right as a sentence: a post, rope going out, rope stopping in
## mid-air. That is the question the dialogue node then asks out loud.
##
## The posts, the ropes and the two planks still hanging off them were drawn in code until
## the art for them arrived. Same picture, drawn by somebody who can draw.

const ART := preload("res://assets/Level1/props/broken_bridge.png")

## Which row of the art the posts stand ON. Measured, not guessed: the left post's lowest
## opaque row is 31 of 40, and everything under it -- the frayed rope, the plank still
## swinging from the far post -- is what hangs over the edge into the gorge. Anchoring on
## the bottom of the picture instead would stand the bridge on its own dangling rope.
const BASE_ROW := 32

## Distance between the two anchor posts, which is the width of the gorge the level drops
## this into. It chooses the scale rather than stretching the art to fit: the nearest whole
## multiple keeps every pixel square, and a bridge whose far post lands a few pixels past
## the lip reads better than one resampled to land exactly on it.
@export var span: float = 560.0

var _art: Sprite2D


func _ready() -> void:
	_art = Sprite2D.new()
	_art.name = "Art"
	_art.texture = ART
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Anchored on the near post's base, which is this node's origin and the point the level
	# positions. Centred, half the bridge would hang back over ground already crossed.
	_art.centered = false
	add_child(_art)
	_lay_out()


func _lay_out() -> void:
	var width := ART.get_width()
	if _art == null or width == 0:
		return
	var factor := maxf(1.0, roundf(span / float(width)))
	_art.scale = Vector2(factor, factor)
	_art.offset = Vector2(0.0, -float(BASE_ROW))
