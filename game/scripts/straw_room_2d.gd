class_name StrawRoom2D
extends Node2D
## Inside the heap, and it is a great deal bigger in here than the hole suggested.
##
## IT IS A PLACE, NOT A CUTAWAY. The first version drew the inside of the heap where the
## heap stands, at the heap's own size, with the terrace still visible round the edges --
## which is honest, and reads as a close-up of a haystack rather than as going somewhere.
## This one is a room fifteen hundred units across, sitting in the empty sky above the
## level, reachable only by ducking into an opening you could not stand up in. A little hole
## and a big room is the whole feeling being bought here, and it does not survive the two
## being the same size.
##
## It costs a teleport and a fade and nothing else. The apo is the same body in the same
## level, so checkpoints, ink, the bag and the drawing panel all carry in with her, and the
## way back out is an opening in the wall with daylight behind it.
##
## WHAT IS IN IT. One of Lola's canvases -- the hub's own painting of the next place, at 2x,
## which is why it is loaded from the hub's folder rather than copied. Her baul, still
## locked; that lock is Node 3's problem and the line closing Node 2 is "Locked. Of course."
## A brass key on the floor, which does NOT open the chest beside it and is not meant to.
## And the ants that were living in here before anybody came looking.

signal key_taken()
## The apo has walked into the opening that leads back out to the terrace.
signal exit_reached()

## How big the room is: floor centre at this node's origin, walls going up and out. Wider
## and taller than a screenful at the level's zoom (1280 x 720), so the edges of it are
## never in shot and the sky it is standing in is never visible behind it.
@export var room_size := Vector2(1700.0, 900.0)
## What the canvas is a painting of. A level id, so the picture and the place cannot drift
## apart: it is read out of the hub's paintings, which is where the same image already lives.
@export var canvas_level_id: String = "level_2"
## Drawn at a whole multiple of its own pixels, or a pixel picture stops having pixels. The
## hub covers are 128 x 72, so this is exactly 2x.
@export var canvas_scale: int = 2
@export var canvas_at := Vector2(110.0, -430.0)
@export var key_at := Vector2(150.0, -14.0)
## What the profile records when the key is taken.
@export var collectible_id: String = "L1_straw_key"

## The straw, matching StrawPile2D's palette exactly -- it is the same straw seen from the
## inside, and two sets of golds for one material is two materials.
const EDGE := StrawPile2D.EDGE
const DARK := StrawPile2D.DARK
const MID := StrawPile2D.MID
const BODY := StrawPile2D.BODY
const LIT := StrawPile2D.LIT
const HI := StrawPile2D.HI
## The dark of the far side of the room, and what the walls are seen against.
const DEEP := Color(0.110, 0.063, 0.024, 1.0)         # 1C1006
const DEEPER := Color(0.063, 0.035, 0.016, 1.0)       # 100904
## The floor: trodden earth, because a heap that has been crawled into has a worn floor.
const EARTH := Color(0.235, 0.157, 0.098, 1.0)        # 3C2819
const EARTH_LIT := Color(0.337, 0.239, 0.153, 1.0)    # 563D27
const EARTH_DARK := Color(0.149, 0.098, 0.063, 1.0)   # 261910
const PEBBLE := Color(0.443, 0.404, 0.353, 1.0)       # 71675A
## Daylight in the opening back out. Warm and washed out, because it is the terrace out
## there and the eye in here is used to the dark.
const DAYLIGHT := Color(0.980, 0.941, 0.792, 1.0)     # FAF0CA
const DAYLIGHT_DIM := Color(0.847, 0.784, 0.588, 1.0) # D8C896
## The gilt of the hub's picture frames, because this canvas is one of the same set.
const FRAME := Color(0.647, 0.447, 0.137, 1.0)        # A57223
const FRAME_LIT := Color(0.859, 0.655, 0.212, 1.0)    # DBA736
const FRAME_EDGE := Color(0.361, 0.212, 0.055, 1.0)   # 5C360E
## Brass, dulled. A key that has been in a straw heap is not a bright one.
const BRASS := Color(0.831, 0.667, 0.216, 1.0)        # D4AA37
const BRASS_LIT := Color(0.949, 0.851, 0.427, 1.0)    # F2D96D
const BRASS_DARK := Color(0.502, 0.376, 0.098, 1.0)   # 806019
## Kent's interior, cut to a tileable strip by tools/build_art.py, and where the dirt
## starts in it. The level lines that line up with its own floor.
const INTERIOR := preload("res://assets/Level1/props/haybale_interior.png")
const INTERIOR_FLOOR := 1096.0

## The wall, mirrored, built once.
##
## NEITHER OF THE TWO OBVIOUS WAYS WORKS. draw_texture_rect's fifth argument is `transpose`,
## which swaps the axes rather than mirroring -- pass `true` and a 400x1660 wall is drawn
## sideways into a 400-wide box and disappears. A Rect2 with a negative width, which is how
## the docs say to flip, draws nothing at all in 4.7. So the flip is baked into a second
## texture at load and the tiling just picks one of the two.
var _flipped: Texture2D

var _taken := false
var _art: Texture2D
var _key_area: Area2D
var _exit_area: Area2D


func _ready() -> void:
	add_to_group(&"straw_rooms")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var path := "res://assets/hub/paintings/%s.png" % canvas_level_id
	if ResourceLoader.exists(path):
		_art = load(path)
	var mirror := INTERIOR.get_image()
	mirror.flip_x()
	_flipped = ImageTexture.create_from_image(mirror)
	_build_floor()
	_build_key_area()
	_build_exit_area()
	_build_ants()
	queue_redraw()


## They walk about on their own, so they get their own node: the walls of this room are a
## couple of thousand units of tiled art and repainting all of it every frame to move six
## legs would be the smallest thing on screen costing the most.
func _build_ants() -> void:
	var ants := StrawAnts2D.new()
	ants.name = "Ants"
	ants.patrol = Vector2(-room_size.x * 0.34, room_size.x * 0.34)
	ants.position = Vector2(0.0, 26.0)
	ants.z_index = 1
	add_child(ants)


func key_is_taken() -> bool:
	return _taken


## Where the apo appears when she ducks in: just inside the way out, so the first thing she
## can see is how to leave, and the room is in front of her rather than behind.
func entry_point() -> Vector2:
	return global_position + Vector2(-room_size.x * 0.5 + 230.0, 0.0)


## The opening back out to the terrace, in the room's own space.
func exit_rect() -> Rect2:
	var size := Vector2(150.0, 230.0)
	return Rect2(Vector2(-room_size.x * 0.5 + 46.0, -size.y), size)


## SOMETHING TO STAND ON. The room is in the sky above the level, so it brings its own floor;
## without it the apo drops out of the bottom of it and the level fishes her back to a
## checkpoint on the terrace, which is a very confusing way to leave a room.
func _build_floor() -> void:
	var body := StaticBody2D.new()
	body.name = "Floor"
	add_child(body)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(room_size.x, 120.0)
	shape.shape = box
	shape.position = Vector2(0.0, 60.0)
	body.add_child(shape)
	# And a wall at each end, so she cannot walk out of the sides of the room into the sky
	# it is standing in.
	for side: float in [-1.0, 1.0]:
		var wall := StaticBody2D.new()
		wall.name = "Wall%s" % ("L" if side < 0.0 else "R")
		add_child(wall)
		var wall_shape := CollisionShape2D.new()
		var wall_box := RectangleShape2D.new()
		wall_box.size = Vector2(60.0, room_size.y)
		wall_shape.shape = wall_box
		wall_shape.position = Vector2(side * (room_size.x * 0.5 + 10.0), -room_size.y * 0.5)
		wall.add_child(wall_shape)


## WALKED ONTO, not pressed at. E reaches only placed drawings -- that is what the group is
## and what its 96px is measured against -- and a second meaning for that button, in the one
## room where the player has just learned the first, is one meaning too many. The level
## already picks things up by being walked into: that is what a checkpoint is.
func _build_key_area() -> void:
	_key_area = Area2D.new()
	_key_area.name = "Key"
	_key_area.collision_layer = 0
	_key_area.collision_mask = 1
	_key_area.position = key_at
	add_child(_key_area)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(90.0, 96.0)
	shape.shape = box
	shape.position = Vector2(0.0, -34.0)
	_key_area.add_child(shape)
	_key_area.body_entered.connect(_on_key_body)


func _build_exit_area() -> void:
	_exit_area = Area2D.new()
	_exit_area.name = "WayOut"
	_exit_area.collision_layer = 0
	_exit_area.collision_mask = 1
	add_child(_exit_area)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	var opening := exit_rect()
	box.size = Vector2(70.0, opening.size.y)
	shape.shape = box
	shape.position = opening.get_center()
	_exit_area.add_child(shape)
	_exit_area.body_entered.connect(_on_exit_body)


func _is_the_player(body: Node) -> bool:
	var node := body as Node
	while node != null:
		if node.is_in_group(&"player_character") or node is ActiveRagdollMorph:
			return true
		node = node.get_parent()
	return false


func _on_key_body(body: Node) -> void:
	if _taken or not _is_the_player(body):
		return
	_taken = true
	# DEFERRED. Godot refuses to switch an area's monitoring while it is in the middle of
	# delivering a signal from it, and this is that signal.
	_key_area.set_deferred(&"monitoring", false)
	var profile := get_node_or_null(^"/root/PlayerProfile")
	if profile != null:
		profile.call("record_collectible", collectible_id)
	queue_redraw()
	key_taken.emit()


func _on_exit_body(body: Node) -> void:
	if _is_the_player(body):
		exit_reached.emit()


func _draw() -> void:
	_draw_dark()
	_draw_walls()
	_draw_way_out()
	_draw_canvas()
	if not _taken:
		_draw_key(key_at)


## Behind everything, for the sliver the tiles do not reach.
func _draw_dark() -> void:
	var half := room_size * 0.5
	draw_rect(Rect2(-half.x - 1200.0, -room_size.y - 1200.0,
		room_size.x + 2400.0, room_size.y + 2400.0), DEEPER)


## KENT'S INTERIOR, TILED. Two goes at drawing the inside of a heap in code came and went;
## this is the picture he drew, cut by tools/build_art.py into a strip that is wall and
## floor and nothing else -- the chest and the canvas painted into the middle of his version
## are real nodes in this level, and the baul outlives this room.
##
## The strip carries its own floor line, so the level lines the two up rather than either
## end guessing: everything above INTERIOR_FLOOR is wall, everything below is dirt, and y=0
## in this node is the ground the apo stands on.
func _draw_walls() -> void:
	# MIRRORED EVERY OTHER TILE. The strip's left and right edges are different straw, so
	# butting copies of it put a hard vertical seam every four hundred units across the
	# room -- the one thing a wall of hanging stalks must not have. Flipping alternate
	# copies makes each join a reflection of itself, which cannot show.
	var span := room_size.x * 0.5 + 900.0
	var width := float(INTERIOR.get_width())
	var first := floorf(-span / width)
	var index := first
	while index * width < span:
		var mirrored := int(absf(index)) % 2 == 1
		draw_texture_rect(_flipped if mirrored else INTERIOR,
			Rect2(Vector2(index * width, -INTERIOR_FLOOR),
				Vector2(width, float(INTERIOR.get_height()))), false)
		index += 1.0


## The way back out: the terrace's daylight through a hole worn in the wall. It is the only
## bright thing in the room, which is what makes it read as the way out without a label --
## and the delivered interior has no doorway in it, so this is drawn over the top.
func _draw_way_out() -> void:
	var rng := _rng(41)
	var opening := exit_rect()
	var centre := Vector2(opening.get_center().x, 0.0)
	var wide := opening.size.x * 0.5
	var tall := opening.size.y
	var steps := 26
	var arch := PackedVector2Array()
	for index in range(steps + 1):
		var phi := PI * float(index) / float(steps)
		arch.append(centre + Vector2(-wide * cos(phi) * rng.randf_range(0.9, 1.1),
			-tall * sin(phi) * rng.randf_range(0.92, 1.06)))
	draw_colored_polygon(arch, DAYLIGHT_DIM)
	var inner := PackedVector2Array()
	for index in range(steps + 1):
		var phi := PI * float(index) / float(steps)
		inner.append(centre + Vector2(-wide * 0.74 * cos(phi), -tall * 0.78 * sin(phi)))
	draw_colored_polygon(inner, DAYLIGHT)
	# Straw hanging across it, so it is a hole worn in a heap and not a doorway.
	for index in range(int(wide * 0.9)):
		var x := roundf(centre.x + rng.randf_range(-wide, wide))
		var top := -tall * rng.randf_range(0.1, 0.96)
		draw_rect(Rect2(x, top, 1.0, rng.randf_range(12.0, 70.0)),
			_ramp(rng.randf_range(0.04, 0.4)))
	# And the light it throws on the floor in front of it.
	var spill := 0
	while spill < 130:
		var fade := float(spill) / 130.0
		draw_rect(Rect2(centre.x - wide - float(spill) * 0.7, float(spill) * 0.14,
			wide * 2.0 + float(spill) * 2.0, 4.0),
			Color(0.98, 0.94, 0.79, 0.12 * (1.0 - fade)))
		spill += 4


## One of Lola's, propped against the straw. Framed like the ones in the house, because it
## is one of the ones in the house.
func _draw_canvas() -> void:
	if _art == null:
		return
	var size := _art.get_size() * float(canvas_scale)
	var picture := Rect2(canvas_at - size * 0.5, size)
	draw_rect(picture.grow(24.0), Color(0.0, 0.0, 0.0, 0.55))
	draw_texture_rect(_art, picture, false)
	# A stepped moulding: light on the top and left, shadow on the bottom and right, the same
	# way round as every other frame in this game.
	for band in range(6):
		var rect := picture.grow(float(band) + 1.0)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), FRAME_LIT)
		draw_rect(Rect2(rect.position, Vector2(1.0, rect.size.y)), FRAME)
		draw_rect(Rect2(rect.position.x, rect.end.y - 1.0, rect.size.x, 1.0), FRAME_EDGE)
		draw_rect(Rect2(rect.end.x - 1.0, rect.position.y, 1.0, rect.size.y), FRAME_EDGE)
	draw_rect(picture.grow(7.0), FRAME_EDGE, false, 2.0)


## A key, lying flat: a bow, a shank and two teeth. Bigger than it would be on the terrace,
## because everything in here is.
func _draw_key(at: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(-30.0, -5.0), Vector2(64.0, 7.0)), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(at + Vector2(-28.0, -22.0), Vector2(22.0, 22.0)), BRASS)
	draw_rect(Rect2(at + Vector2(-22.0, -16.0), Vector2(10.0, 10.0)), DEEPER)
	draw_rect(Rect2(at + Vector2(-28.0, -22.0), Vector2(22.0, 3.0)), BRASS_LIT)
	draw_rect(Rect2(at + Vector2(-6.0, -16.0), Vector2(38.0, 8.0)), BRASS)
	draw_rect(Rect2(at + Vector2(-6.0, -16.0), Vector2(38.0, 2.0)), BRASS_LIT)
	draw_rect(Rect2(at + Vector2(20.0, -8.0), Vector2(6.0, 8.0)), BRASS_DARK)
	draw_rect(Rect2(at + Vector2(28.0, -8.0), Vector2(4.0, 6.0)), BRASS_DARK)


## Seeded, so the room is the same room every time it is walked into.
func _rng(salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(position.x) * 7919.0 + absf(position.y) * 104729.0) + salt
	return rng


func _ramp(lit: float) -> Color:
	var ramp: Array[Color] = [EDGE, DARK, MID, BODY, LIT, HI]
	return ramp[int(round(clampf(lit, 0.0, 1.0) * float(ramp.size() - 1)))]
