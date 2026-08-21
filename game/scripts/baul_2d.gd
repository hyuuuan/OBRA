class_name Baul2D
extends Node2D
## Lola's chest: small, banded, padlocked, and hidden in the straw until somebody finds it.
##
## It is the reward for Node 2 and the problem for Node 3, which is why it is one object
## that outlives the obstacle that produced it. Finding it is not opening it -- "Locked. Of
## course." is the line that closes the beat.
##
## DECLARED LIBERTY, and Lolo says so aloud in the level: an Ifugao house had no locks. This
## one is hers, carried up from the lowlands, and the padlock came with it. That is recorded
## in the build spec's creative-liberties table rather than smuggled past.

signal found()

const AtlasTile = preload("res://scripts/atlas_tile.gd")
const TEXTURE_MAP := preload("res://assets/Level1/texturemap.png")
## Dark banded wood. The stone regions read as too grey next to straw, so this borrows the
## mud wall, which is the warmest brown in the atlas.
const WOOD := Rect2(217, 228, 146, 129)

@export var chest_size := Vector2(74.0, 52.0)
@export var start_hidden := true

var _found := false
var _art: Node2D


func _ready() -> void:
	add_to_group(&"baul")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build()
	visible = not start_hidden


func is_found() -> bool:
	return _found


## Turn up out of the straw. Idempotent: three combing passes all end at the same chest.
func reveal() -> void:
	if _found:
		return
	_found = true
	visible = true
	# Rises out of the pile rather than appearing, so the moment reads as uncovering
	# something rather than as the level spawning it.
	var lift := create_tween()
	lift.set_parallel(true)
	lift.tween_property(self, "position:y", position.y - 10.0, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lift.tween_property(self, "modulate:a", 1.0, 0.3).from(0.0)
	found.emit()


func _build() -> void:
	_art = Node2D.new()
	_art.name = "Chest"
	add_child(_art)

	var body := Polygon2D.new()
	body.name = "Body"
	var half := chest_size * 0.5
	body.polygon = PackedVector2Array([
		Vector2(-half.x, 0.0), Vector2(-half.x, -chest_size.y),
		Vector2(half.x, -chest_size.y), Vector2(half.x, 0.0),
	])
	body.texture = _atlas(WOOD)
	body.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	body.color = Color(0.86, 0.72, 0.52)
	_art.add_child(body)

	# The bands, which are what make a box read as a chest at this size.
	for offset in [-chest_size.x * 0.26, chest_size.x * 0.26]:
		var band := Polygon2D.new()
		band.polygon = PackedVector2Array([
			Vector2(offset - 4.0, 1.0), Vector2(offset - 4.0, -chest_size.y - 1.0),
			Vector2(offset + 4.0, -chest_size.y - 1.0), Vector2(offset + 4.0, 1.0),
		])
		band.color = Color(0.32, 0.26, 0.19)
		_art.add_child(band)

	# The padlock. Node 3's whole Pragmatist route is about this shape.
	var lock := Polygon2D.new()
	lock.name = "Padlock"
	lock.polygon = PackedVector2Array([
		Vector2(-7.0, -chest_size.y * 0.42), Vector2(-7.0, -chest_size.y * 0.62),
		Vector2(7.0, -chest_size.y * 0.62), Vector2(7.0, -chest_size.y * 0.42),
	])
	lock.color = Color(0.78, 0.72, 0.34)
	_art.add_child(lock)


## A Polygon2D cannot be filled from an AtlasTexture: it samples the whole atlas page
## rather than the region, and the prop draws the wrong art or none at all. See
## atlas_tile.gd, which cuts the region out into a texture that tiles honestly.
func _atlas(region: Rect2) -> ImageTexture:
	return AtlasTile.cut(TEXTURE_MAP, region)
