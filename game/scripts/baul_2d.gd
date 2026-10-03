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
## Opened: something that can UNLOCK or CUT was used on it. See GameLevel._open_the_chest.
signal opened()

const AtlasTile = preload("res://scripts/atlas_tile.gd")
const TEXTURE_MAP := preload("res://assets/Level1/texturemap.png")
## The atlas has no chest, so this is the plank door out of the hut-accent row: boards, a
## rail top and bottom, and a round fitting on the face. At chest size that reads as a
## banded lowland trunk, which is what it is meant to be. It was a rectangle of mud wall.
const PLANKS := Rect2(910, 1001, 44, 61)

@export var chest_size := Vector2(74.0, 52.0)
@export var start_hidden := true

var _found := false
var _opened := false
var _art: Node2D


func _ready() -> void:
	add_to_group(&"baul")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build()
	visible = not start_hidden
	# What is inside is Lola's, so the sign says memory rather than talk.
	#
	# AND IT CAN BE READ. It was planted with no hook, and `GameLevel._readable_sign` skips
	# any board whose hook has not already played -- so this one could never be offered, ever.
	# The one object in the straw room the player is meant to walk up to and think about was
	# a picture of a chest with a picture of a sign next to it, and pressing the interact key
	# at either did nothing. `L1_N2.solved` is the line that closes the beat ("Locked. Of
	# course.") and is fired by `_uncover_the_baul` at the moment this chest appears, so the
	# board is readable from the instant there is a chest to read it about.
	Signpost2D.plant(self, Signpost2D.Mark.MEMORY, Vector2(-34.0, 0.0), "L1_N2.solved")


func is_found() -> bool:
	return _found


func is_opened() -> bool:
	return _opened


## THE PADLOCK COMES OFF AND THE LID GOES BACK. Kent's friend: "the box in level 1 is not
## openable". It never was: the level found it, said "Locked. Of course.", and Lolo later said
## it "was made to be opened" -- and nothing in the game opened it. It was where the painting
## used to be, before the painting moved into Ang Bale. Opened now by something that can
## UNLOCK or CUT, and what is inside is hers: a page from her sketchbook.
func open() -> void:
	if _opened:
		return
	_opened = true
	var half := chest_size * 0.5
	var lock := _art.get_node_or_null(^"Padlock") as Node2D
	if lock != null:
		var fall := create_tween()
		fall.set_parallel(true)
		fall.tween_property(lock, "position:y", chest_size.y * 0.7, 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall.tween_property(lock, "modulate:a", 0.0, 0.35)
	# The dark inside, the lid thrown back behind it, and the corner of a page.
	var inside := Polygon2D.new()
	inside.name = "Inside"
	inside.polygon = PackedVector2Array([
		Vector2(-half.x + 4.0, -chest_size.y), Vector2(half.x - 4.0, -chest_size.y),
		Vector2(half.x - 6.0, -chest_size.y + 7.0), Vector2(-half.x + 6.0, -chest_size.y + 7.0),
	])
	inside.color = Color(0.13, 0.08, 0.05)
	_art.add_child(inside)
	var lid := Polygon2D.new()
	lid.name = "Lid"
	lid.polygon = PackedVector2Array([
		Vector2(-half.x, -chest_size.y), Vector2(half.x, -chest_size.y),
		Vector2(half.x - 4.0, -chest_size.y - 16.0), Vector2(-half.x + 4.0, -chest_size.y - 16.0),
	])
	lid.color = Color(0.42, 0.27, 0.15)
	_art.add_child(lid)
	_art.move_child(lid, 0)
	var page := Polygon2D.new()
	page.name = "Page"
	page.polygon = PackedVector2Array([
		Vector2(-10.0, -chest_size.y + 2.0), Vector2(12.0, -chest_size.y + 1.0),
		Vector2(10.0, -chest_size.y - 9.0), Vector2(-8.0, -chest_size.y - 7.0),
	])
	page.color = Color(0.95, 0.91, 0.8)
	_art.add_child(page)
	var rise := create_tween()
	rise.tween_property(lid, "modulate:a", 1.0, 0.25).from(0.0)
	opened.emit()


## Turn up out of the straw. Idempotent: three combing passes all end at the same chest.
func reveal() -> void:
	if _found:
		return
	_found = true
	visible = true
	# Rises out of the pile rather than appearing, so the moment reads as uncovering
	# something rather than as the level spawning it.
	# Rises TO its resting place, from below it. Tweening away from the rest position
	# left the chest hanging ten pixels off the terrace for the rest of the level, which
	# is what the old version did -- there was nothing to bring it back down.
	var resting := position.y
	position.y = resting + 10.0
	var lift := create_tween()
	lift.set_parallel(true)
	lift.tween_property(self, "position:y", resting, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lift.tween_property(self, "modulate:a", 1.0, 0.3).from(0.0)
	found.emit()


func _build() -> void:
	_art = Node2D.new()
	_art.name = "Chest"
	add_child(_art)

	var half := chest_size * 0.5
	var body := Sprite2D.new()
	body.name = "Body"
	body.texture = AtlasTile.cut(TEXTURE_MAP, PLANKS)
	# Bottom-centre anchored like every prop: `position` is where it meets the ground.
	body.position = Vector2(0.0, -half.y)
	body.scale = chest_size / PLANKS.size
	_art.add_child(body)

	# The padlock. Node 3's whole Pragmatist route is about this shape.
	var lock := Polygon2D.new()
	lock.name = "Padlock"
	# On the lid line, small. The plank face already carries a fitting of its own, and a
	# tan slab across the middle of it read as a sticker rather than as a padlock.
	lock.polygon = PackedVector2Array([
		Vector2(-5.0, -chest_size.y * 0.72), Vector2(-5.0, -chest_size.y * 0.86),
		Vector2(5.0, -chest_size.y * 0.86), Vector2(5.0, -chest_size.y * 0.72),
	])
	lock.color = Color(0.86, 0.8, 0.36)
	_art.add_child(lock)
