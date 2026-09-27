extends Node2D
## THE NEXT PAINTING, glittering in the island's sand -- the thing the crossing is for.
##
## The design: "when done with the bakunawa, you arrive on another island and see something
## glittering in the sand. its the next painting." It was a burst of sparkles over bare sand.
## It is one of Lola's canvases now, in the same gilt the paintings in her house hang in --
## drawn by Painting2D's own moulding, so it is recognisably one of that set -- stood upright
## with its foot buried in a heap of this island's sand, and catching the light as it goes.
##
## ⚠ SCENERY, NOT A DOOR. It is not an Area2D and nothing reads it: the level ends on the
## island's arrival, not on touching this, and the next level is chosen from the house. What
## it has to say is only "that is where she went next".
##
## Anchored at its FOOT: `position` is where the frame meets the sand, and the picture is built
## upward from there, the way every prop in this project stands.

const PaintingClass = preload("res://scripts/painting_2d.gd")
const MOUND := preload("res://assets/Level3/authored/sand_mound.png")

## The picture in the frame. The level hands it the next level's own painting.
@export var art: Texture2D
## A hand's breadth of gold, as in the house.
@export var moulding := 8.0
## How much of the frame the heap of sand in front of it hides, in pixels.
@export var buried := 22.0

var _clock := 0.0
## Where on the gilt the light catches, as fractions round the frame, each with its own phase.
const GLINTS := [Vector2(0.18, 0.0), Vector2(1.0, 0.34), Vector2(0.62, 0.0), Vector2(0.0, 0.55)]


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mound := Sprite2D.new()
	mound.name = "Sand"
	mound.texture = MOUND
	mound.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mound.centered = false
	# In front of the frame's foot, its crest at the buried line and its base on the sand.
	mound.position = Vector2(-MOUND.get_width() * 0.5, 6.0 - MOUND.get_height())
	mound.z_index = 1
	add_child(mound)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func picture_rect() -> Rect2:
	var size := art.get_size() if art != null else Vector2(128.0, 72.0)
	# The frame's outer bottom sits just under the sand line; the heap in front covers the
	# lowest `buried` pixels of it.
	var bottom := 4.0
	return Rect2(Vector2(-size.x * 0.5, bottom - moulding - size.y), size)


func _draw() -> void:
	var picture := picture_rect()
	if art != null:
		draw_texture_rect(art, picture, false)
	PaintingClass.draw_gilt(self, picture, moulding)
	# THE GLITTER, which is how it is seen from out on the water: a few points of light on the
	# gold, each coming and going on its own clock, never all at once.
	var outer := picture.grow(moulding)
	for index in range(GLINTS.size()):
		var at: Vector2 = GLINTS[index]
		var point := outer.position + Vector2(outer.size.x * at.x, outer.size.y * at.y)
		var strength := pow(maxf(0.0, sin(_clock * 1.7 + float(index) * 1.9)), 6.0)
		if strength < 0.05:
			continue
		var light := Color(1.0, 0.97, 0.82, strength)
		var arm := 3.0 + 4.0 * strength
		draw_rect(Rect2(point - Vector2(arm, 1.0), Vector2(arm * 2.0, 2.0)), light)
		draw_rect(Rect2(point - Vector2(1.0, arm), Vector2(2.0, arm * 2.0)), light)
