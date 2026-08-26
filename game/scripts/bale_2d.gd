class_name Bale2D
extends Node2D
## The Ifugao house, and Node 3's puzzle. The architecture IS the obstacle: every route
## answers a real feature of the building rather than a lock the designer invented.
##
##   posts, each with a HALIPAN          a rat guard -- a disc the width of a dinner plate
##                                       that a rat cannot get past and neither can a
##                                       climber. This is why "climb the post" is not an
##                                       answer, and it is a real thing, not a fiction
##   one door, above head height         the door is the only opening and it is shut
##   thatch slope and an eave gap        the way in, if you can get onto the roof
##
## So the Artist route goes up the thatch and in under the eaves into the attic granary --
## the way you would actually get into a bale that had been closed up.
##
## The posts and the floor are solid. The halipan are solid too, and that is the point:
## they are what a straight climb runs into.
##
## IT IS THE ARTIST'S HUT NOW. This was assembled out of the level atlas, then hand-drawn in
## `_draw()`, and it is neither any more: `assets/Level1/hut.png` is the real thing. What is
## left here is the part a picture cannot do, which is COLLISION MEASURED OFF THAT PICTURE
## rather than guessed beside it -- every number in the block below was read out of the art's
## own alpha, so what the player climbs is exactly what they can see.
##
## THE ART IS NOT SYMMETRICAL and the collision does not pretend it is. It is drawn a little
## from the left, so the roof reaches 212px past the ridge on one side and 168 on the other,
## and the ridge itself sits 12px left of the middle. A symmetric triangle over it would put
## solid ground where there is sky on one side and sky where there is thatch on the other,
## which is precisely the bug that makes a climbable roof feel broken. The roof body is a
## CollisionPolygon2D, so carrying the asymmetry costs nothing.

signal attic_entered()

const ART: Texture2D = preload("res://assets/Level1/hut.png")

## The picture, and where this node's origin sits in it: the middle of the HOUSE BODY (not
## of the image, which the roof overhangs unevenly) at ground level.
const ART_SIZE := Vector2(354.0, 333.0)
const ART_ORIGIN := Vector2(182.0, 333.0)

## Every band below is measured up from the ground in world pixels, straight off the art,
## which is drawn at THREE WORLD PIXELS to one of the artist's -- the largest whole multiple
## that leaves the Overlook both a shelf in front of the house for a ladder to stand in and
## ground behind it. At four the hut came out 472 wide and the terrace is 600.
## The storey between the deck and the roof has no windows and one door, which is the
## premise all three of Node 3's routes rest on.
@export var wall_height := 45.0
## The deck the house stands on: how wide it is, and how deep its beam is.
## Measured to the OUTER FACES OF THE POSTS, not to the art's full apron: the level's
## "is there room for a ladder in front of the house" check reads this, and the apron reaches
## out past the last post to carry the drawn ladder.
@export var floor_size := Vector2(243.0, 22.0)
## Ground to the underside of the deck.
@export var post_height := 77.0
@export var halipan_size := Vector2(42.0, 9.0)
## Eaves to ridge.
@export var roof_height := 189.0

## Where the three posts stand, measured from the art. Three, not four: the picture has
## three and a ladder, and collision that disagrees with the picture is collision the player
## walks into thin air to find.
const POST_X: Array[float] = [-105.0, -34.0, 42.0]
const POST_WIDTH := 33.0
## How far up the post the guard sits. Near the TOP in this art -- the collars are tucked
## right under the deck rather than halfway down the trunk.
const HALIPAN_Y := -69.0

## The eaves, left and right of this node, and where the ridge actually is.
const EAVE_LEFT := -160.0
const EAVE_RIGHT := 126.0
const RIDGE_X := -9.0
## How far the walls reach either side. Symmetric, unlike everything above it.
const WALL_HALF := 126.0

var _attic: Area2D
var _entered := false


func _ready() -> void:
	add_to_group(&"bale")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_posts()
	_build_floor()
	_build_walls()
	_build_roof()
	_build_attic()
	queue_redraw()


func attic_was_entered() -> bool:
	return _entered


## Where the eave gap is, in world space. The Artist route's target: over the roof and in
## under the edge, not through the door.
func eave_gap() -> Vector2:
	return global_position + Vector2(EAVE_RIGHT * 0.8, -_roof_base() - roof_height * 0.45)


## Top of the walls, measured from the ground: posts, deck, then the storey itself.
func _roof_base() -> float:
	return post_height + floor_size.y + wall_height


## The picture, drawn once, behind every body below it.
func _draw() -> void:
	draw_texture_rect(ART, Rect2(-ART_ORIGIN, ART_SIZE), false)


# Unchanged from the tiled version: same bodies, same sizes, same places. See the class note.

func _build_posts() -> void:
	for index in range(POST_X.size()):
		var x: float = POST_X[index]
		var post := StaticBody2D.new()
		post.name = "Post%d" % (index + 1)
		post.position = Vector2(x, 0.0)
		add_child(post)
		var collision := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(POST_WIDTH, post_height)
		collision.shape = box
		collision.position = Vector2(0.0, -post_height * 0.5)
		post.add_child(collision)

		# The halipan. Solid, and wider than the post, so a climb up the post meets a
		# ceiling -- which is exactly what the thing is for.
		var guard := StaticBody2D.new()
		guard.name = "Halipan%d" % (index + 1)
		guard.position = Vector2(x, HALIPAN_Y)
		add_child(guard)
		var guard_collision := CollisionShape2D.new()
		var guard_box := RectangleShape2D.new()
		guard_box.size = halipan_size
		guard_collision.shape = guard_box
		guard.add_child(guard_collision)


func _build_floor() -> void:
	var deck := StaticBody2D.new()
	deck.name = "Deck"
	deck.position = Vector2(0.0, -post_height)
	add_child(deck)
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = floor_size
	collision.shape = box
	collision.position = Vector2(0.0, -floor_size.y * 0.5)
	deck.add_child(collision)


## Solid, because it is a building. The way in is over the thatch and under the eaves --
## that is the Artist route, and it only means anything if walking in at deck level is not
## an option.
func _build_walls() -> void:
	var body := StaticBody2D.new()
	body.name = "Walls"
	body.position = Vector2(0.0, -post_height - floor_size.y)
	add_child(body)
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(WALL_HALF * 2.0, wall_height)
	collision.shape = box
	collision.position = Vector2(0.0, -wall_height * 0.5)
	body.add_child(collision)


## The pyramidal thatch. Solid on its slope, which is what makes going over it a climb
## rather than a walk.
func _build_roof() -> void:
	var roof := StaticBody2D.new()
	roof.name = "ThatchSlope"
	roof.position = Vector2(0.0, -_roof_base())
	add_child(roof)
	# The art's own triangle, ridge off-centre and one eave longer than the other.
	var collision := CollisionPolygon2D.new()
	collision.polygon = PackedVector2Array([
		Vector2(EAVE_LEFT, 0.0), Vector2(RIDGE_X, -roof_height), Vector2(EAVE_RIGHT, 0.0),
	])
	roof.add_child(collision)


## The granary under the roof. Reached through the eave gap, never through the door.
func _build_attic() -> void:
	_attic = Area2D.new()
	_attic.name = "AtticVolume"
	_attic.collision_layer = 0
	_attic.collision_mask = 1
	_attic.position = Vector2(0.0, -_roof_base() - roof_height * 0.4)
	add_child(_attic)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(floor_size.x * 0.7, roof_height * 0.6)
	shape.shape = box
	_attic.add_child(shape)
	_attic.body_entered.connect(_on_attic_entered)


func _on_attic_entered(body: Node) -> void:
	if _entered:
		return
	var node := body as Node
	while node != null:
		if node.is_in_group(&"player_character"):
			_entered = true
			attic_entered.emit()
			return
		node = node.get_parent()
