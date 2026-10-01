extends Node2D
## THE NEXT PAINTING, glittering in the island's sand -- the thing the crossing is for.
##
## The design: "when done with the bakunawa, you arrive on another island and see something
## glittering in the sand. its the next painting." It was a burst of sparkles over bare sand.
## It is one of Lola's canvases now, in the same gilt the paintings in her house hang in --
## drawn by Painting2D's own moulding, so it is recognisably one of that set -- stood upright
## with its foot buried in a heap of this island's sand, and catching the light as it goes.
##
## ⚠ TAKEN, NOT ONLY SEEN. It was scenery -- the level ended on the island's arrival and this
## was looked at and left in the sand. Kent: "the acquiring of the painting ... should have the
## acquired pop up since its an acquired". So it is picked up the way Payyo's canvas is: walked
## onto, it lifts out of the sand and fades with the same gold flourish, and `taken` tells the
## level, which shows the card and then lets Lolo say goodbye. The level ARMS it once the apo
## is ashore; before that nothing can take it.
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

## The apo has taken it. Fired once, the moment they reach it -- the lift is still playing.
signal taken

var _clock := 0.0
var _reach: Area2D
var _armed := false
var _taken := false
## How far it has risen out of the sand while it is being taken. It fades through
## `self_modulate`, so the heap of sand it stood in stays where it was.
var _lift := 0.0
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
	# What the apo walks into to take it: the frame's width, from the sand up a body's height.
	var reach := Area2D.new()
	reach.name = "Reach"
	reach.collision_layer = 0
	reach.collision_mask = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(picture_rect().size.x + moulding * 2.0, 110.0)
	shape.shape = box
	shape.position = Vector2(0.0, -55.0)
	reach.add_child(shape)
	add_child(reach)
	reach.body_entered.connect(_on_body)
	_reach = reach


## From here on, walking into it takes it -- and standing in it already, as a player set down
## beside it can be, counts as having walked into it.
func arm() -> void:
	_armed = true
	_take_if_standing_in_it.call_deferred()


func _take_if_standing_in_it() -> void:
	if _reach == null or _taken:
		return
	for body in _reach.get_overlapping_bodies():
		if _is_the_player(body):
			take()
			return


func is_taken() -> bool:
	return _taken


func _on_body(body: Node) -> void:
	if not _armed or _taken or not _is_the_player(body):
		return
	take()


## Out of the sand: it lifts, the gold throws its flourish, and it fades -- Payyo's canvas, as
## taken in the bale. `taken` fires at once rather than at the end, so nothing downstream waits
## on an animation to know the apo has it.
func take() -> void:
	if _taken:
		return
	_taken = true
	PickupFlourish2D.burst(self, picture_rect().get_center())
	var lift := create_tween()
	lift.set_parallel(true)
	lift.tween_property(self, "_lift", 46.0, 0.6).set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
	lift.tween_property(self, "self_modulate:a", 0.0, 0.5).set_delay(0.15)
	taken.emit()


## The rig's segments are what enter an area, and `player_character` is on the body's root.
func _is_the_player(body: Node) -> bool:
	var node := body
	while node != null:
		if node.is_in_group(&"player_character") or node is ActiveRagdollMorph:
			return true
		node = node.get_parent()
	return false


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
	picture.position.y -= _lift
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
