class_name Bale2D
extends Node2D
## The Ifugao house, and Node 3's puzzle. The architecture IS the obstacle: every route
## answers a real feature of the building rather than a lock the designer invented.
##
##   four posts, each with a HALIPAN     a rat guard -- a disc the width of a dinner plate
##                                       that a rat cannot get past and neither can a
##                                       climber. This is why "climb the post" is not an
##                                       answer, and it is a real thing, not a fiction
##   no windows, one door above head     the door is the only opening and it is shut
##   the ladder is taken in at night     which is the lock. There is nothing else
##   thatch slope and an eave gap        the way in, if you can get onto the roof
##
## So the Artist route goes up the thatch and in under the eaves into the attic granary --
## the way you would actually get into a bale that had been closed up.
##
## The posts and the floor are solid. The halipan are solid too, and that is the point:
## they are what a straight climb runs into.

signal attic_entered()

const AtlasTile = preload("res://scripts/atlas_tile.gd")
const TEXTURE_MAP := preload("res://assets/Level1/texturemap.png")
## Real hut pieces, from the atlas's own "hut accent" row -- a thatch panel with its ridge
## pole, a bamboo-slat wall, a plank door, and a post-and-beam frame. Until now this house
## was assembled out of terrace tiles: a triangle of rice for a roof and mud for the posts,
## which is why it read as a covered pavilion rather than as somewhere shut for the night.
## The solid middle of the thatch panel. The panel itself is a trapezoid with transparent
## corners, so tiling the whole thing across a roof printed the gaps too and the slope came
## out as three small roofs instead of one.
const THATCH := Rect2(734, 1012, 70, 44)
const THATCH_RIDGE := Rect2(732, 1002, 74, 14)
const WALL_PANEL := Rect2(966, 1001, 69, 61)
const DOOR := Rect2(910, 1001, 44, 61)
const POST := Rect2(1045, 1000, 70, 62)
const WOOD := Rect2(217, 248, 146, 96)

## The storey between the deck and the roof. It has no windows and one door, which is the
## premise all three of Node 3's routes rest on: the way in is the eave gap, or the hasp,
## or nothing.
@export var wall_height := 60.0

@export var floor_size := Vector2(240.0, 22.0)
@export var post_height := 96.0
@export var halipan_size := Vector2(46.0, 12.0)
@export var roof_height := 92.0

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


func attic_was_entered() -> bool:
	return _entered


## Where the eave gap is, in world space. The Artist route's target: over the roof and in
## under the edge, not through the door.
func eave_gap() -> Vector2:
	return global_position + Vector2(floor_size.x * 0.42, -_roof_base() - roof_height * 0.45)


## Top of the walls, measured from the ground: posts, deck, then the storey itself.
func _roof_base() -> float:
	return post_height + floor_size.y + wall_height


func _build_posts() -> void:
	var span := floor_size.x * 0.5 - 18.0
	for index in range(4):
		var x: float = lerpf(-span, span, float(index) / 3.0)
		var post := StaticBody2D.new()
		post.name = "Post%d" % (index + 1)
		post.position = Vector2(x, 0.0)
		add_child(post)
		var collision := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(16.0, post_height)
		collision.shape = box
		collision.position = Vector2(0.0, -post_height * 0.5)
		post.add_child(collision)
		var art := Polygon2D.new()
		art.polygon = PackedVector2Array([
			Vector2(-8.0, 0.0), Vector2(-8.0, -post_height),
			Vector2(8.0, -post_height), Vector2(8.0, 0.0),
		])
		AtlasTile.fill(art, TEXTURE_MAP, WOOD)
		art.color = Color(0.74, 0.6, 0.42)
		post.add_child(art)

		# The halipan. Solid, and wider than the post, so a climb up the post meets a
		# ceiling -- which is exactly what the thing is for.
		var guard := StaticBody2D.new()
		guard.name = "Halipan%d" % (index + 1)
		guard.position = Vector2(x, -post_height * 0.72)
		add_child(guard)
		var guard_collision := CollisionShape2D.new()
		var guard_box := RectangleShape2D.new()
		guard_box.size = halipan_size
		guard_collision.shape = guard_box
		guard.add_child(guard_collision)
		var guard_art := Polygon2D.new()
		var half := halipan_size * 0.5
		guard_art.polygon = PackedVector2Array([
			Vector2(-half.x, half.y), Vector2(-half.x * 0.7, -half.y),
			Vector2(half.x * 0.7, -half.y), Vector2(half.x, half.y),
		])
		guard_art.color = Color(0.55, 0.45, 0.33)
		guard.add_child(guard_art)


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
	var art := Polygon2D.new()
	var half := floor_size * 0.5
	art.polygon = PackedVector2Array([
		Vector2(-half.x, 0.0), Vector2(-half.x, -floor_size.y),
		Vector2(half.x, -floor_size.y), Vector2(half.x, 0.0),
	])
	AtlasTile.fill(art, TEXTURE_MAP, WOOD)
	art.color = Color(0.62, 0.5, 0.36)
	deck.add_child(art)


## The house itself: a closed box of bamboo slats with one door, standing on the deck.
##
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
	box.size = Vector2(floor_size.x * 0.86, wall_height)
	collision.shape = box
	collision.position = Vector2(0.0, -wall_height * 0.5)
	body.add_child(collision)

	var half := floor_size.x * 0.43
	var slats := TextureRect.new()
	slats.name = "Slats"
	slats.position = Vector2(-half, -wall_height)
	slats.size = Vector2(half * 2.0, wall_height)
	slats.texture = AtlasTile.cut(TEXTURE_MAP, WALL_PANEL)
	slats.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	slats.stretch_mode = TextureRect.STRETCH_TILE
	slats.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(slats)

	# One door, and it is above head height because the ladder is taken in at night. That
	# is the lock: there is nothing else.
	var door := Sprite2D.new()
	door.name = "Door"
	door.texture = AtlasTile.cut(TEXTURE_MAP, DOOR)
	door.position = Vector2(half * 0.52, -wall_height * 0.5)
	door.scale = Vector2.ONE * (wall_height / DOOR.size.y)
	body.add_child(door)


## The pyramidal thatch. Solid on its slope, which is what makes going over it a climb
## rather than a walk.
func _build_roof() -> void:
	var roof := StaticBody2D.new()
	roof.name = "ThatchSlope"
	roof.position = Vector2(0.0, -_roof_base())
	add_child(roof)
	var half := floor_size.x * 0.58
	var points := PackedVector2Array([
		Vector2(-half, 0.0), Vector2(0.0, -roof_height), Vector2(half, 0.0),
	])
	var collision := CollisionPolygon2D.new()
	collision.polygon = points
	roof.add_child(collision)
	var art := Polygon2D.new()
	art.polygon = points
	AtlasTile.fill(art, TEXTURE_MAP, THATCH)
	art.color = Color(0.86, 0.78, 0.6)
	roof.add_child(art)

	# The ridge pole, which is what makes a triangle read as a roof.
	var ridge := Sprite2D.new()
	ridge.name = "Ridge"
	ridge.texture = AtlasTile.cut(TEXTURE_MAP, THATCH_RIDGE)
	ridge.position = Vector2(0.0, -roof_height + 6.0)
	ridge.scale = Vector2(half * 0.5 / (THATCH_RIDGE.size.x * 0.5), 1.0)
	roof.add_child(ridge)


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
