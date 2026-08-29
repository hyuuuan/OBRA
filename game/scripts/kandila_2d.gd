class_name Kandila2D
extends Node2D
## The candle, on a table, in the one house on the plaza with a light on inside it.
##
## THIS IS WHAT PATH C IS FOR. The design's three routes to the kandila are: dance for the
## dancers, scare them off, or *"walk around the houses and find a door with lights inside,
## create a key that imitates the lock, get inside the house and find a candle"*. The first
## two hand it over at the moment the route commits. The third does not -- committing that
## route means the key worked, and the candle is still on a table in a room the player has
## not walked into yet.
##
## That difference is the whole reason the house has an inside at all. If the commit granted
## the kandila the way the other two do, the room behind the door would be a corridor with
## nothing in it, and the longest of the three routes would be the one with the least in it.
##
## TAKEN BY WALKING INTO IT, like the brass key in the heap and the canvas in the bale. No
## key press: the player has already made the choice that got them through the door.
##
## PLACEHOLDER ART. The design lists the kandila in three states -- unlit inventory icon,
## lit, placed on the altar -- under what does not exist. Drawn to `ART_PLACEHOLDERS.md`
## rules, at the size the real one has to be.

signal taken()

## Set false once it has been picked up this run, so a checkpoint restore inside the house
## does not put a second one on the table.
@export var present := true

## A candle is about twenty-five centimetres. At seventy-two pixels to the metre that is 18,
## which is far too small to find in a room -- so this is the CANDLE AND ITS STAND together,
## which is what the player is actually looking for and what the icon will show.
const SIZE := Vector2(26.0, 84.0)
## The table it stands on. Knee height on the apo, because that is what a table is.
const TABLE := Vector2(150.0, 62.0)
## How close counts as taking it.
const REACH := Vector2(120.0, 150.0)

const WAX := Color(0.949, 0.925, 0.831, 1.0)          # F2ECD4
const WAX_DARK := Color(0.796, 0.761, 0.647, 1.0)     # CBC2A5
const FLAME := Color(0.996, 0.847, 0.451, 1.0)        # FED873
const FLAME_CORE := Color(1.0, 0.976, 0.847, 1.0)     # FFF9D8
const GLOW := Color(0.988, 0.812, 0.451, 0.22)
const BRASS := Color(0.831, 0.667, 0.216, 1.0)        # D4AA37
const BRASS_DARK := Color(0.502, 0.376, 0.098, 1.0)   # 806019
const WOOD := Color(0.353, 0.243, 0.149, 1.0)         # 5A3E26
const WOOD_LIT := Color(0.478, 0.345, 0.216, 1.0)     # 7A5837
const WOOD_DARK := Color(0.212, 0.145, 0.086, 1.0)    # 362516

var _area: Area2D
## Drives the flame. A candle that does not move is a candle nobody looks at, and this one
## is the only lit thing in a dark room.
var _flicker := 0.0


func _ready() -> void:
	add_to_group(&"kandila")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_reach()
	set_process(present)
	queue_redraw()


func _process(delta: float) -> void:
	_flicker += delta
	queue_redraw()


func _build_reach() -> void:
	_area = Area2D.new()
	_area.name = "Reach"
	_area.position = Vector2(0.0, -REACH.y * 0.5)
	add_child(_area)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = REACH
	shape.shape = box
	_area.add_child(shape)
	_area.body_entered.connect(_on_body)
	# TAKE IT IF SOMEBODY IS ALREADY STANDING HERE when the trigger arms. `body_entered` is
	# a transition and there is no transition for a body that was already inside -- and the
	# player arrives in this room by a teleport, so where they land is decided by the room's
	# `entry_point()`. The day somebody moves that a few pixels this becomes unpickable and
	# the house quietly has nothing in it. Level 1's bale learned this the same way.
	_sweep_for_taker.call_deferred()


func _sweep_for_taker() -> void:
	if not present or _area == null:
		return
	await get_tree().physics_frame
	if not present or _area == null or not is_instance_valid(_area):
		return
	for body in _area.get_overlapping_bodies():
		if body.is_in_group(&"player_character"):
			_take()
			return


func _on_body(body: Node) -> void:
	if present and body.is_in_group(&"player_character"):
		_take()


func _take() -> void:
	present = false
	set_process(false)
	if _area != null:
		# DEFERRED, because this runs inside `body_entered` and Godot refuses to change
		# monitoring while a body is being reported in or out. Set directly it prints an
		# error, leaves monitoring on, and the only thing stopping a second pickup is the
		# `present` flag -- which is a guard doing two jobs and one of them silently.
		_area.set_deferred("monitoring", false)
	queue_redraw()
	taken.emit()


func _draw() -> void:
	# The table stays whether the candle is on it or not: an empty table is the room telling
	# a player who comes back that they already took what was standing on it.
	var top := Rect2(-TABLE.x * 0.5, -TABLE.y, TABLE.x, 12.0)
	draw_rect(top, WOOD_LIT)
	draw_rect(Rect2(top.position + Vector2(0.0, 12.0), Vector2(TABLE.x, 6.0)), WOOD_DARK)
	for side: float in [-1.0, 1.0]:
		draw_rect(Rect2(side * (TABLE.x * 0.5 - 18.0) - 6.0, -TABLE.y + 18.0,
			12.0, TABLE.y - 18.0), WOOD)
	if not present:
		return
	var foot := -TABLE.y
	# A brass stand, because a candle standing on its own end is a candle lying on the floor.
	draw_rect(Rect2(-18.0, foot - 10.0, 36.0, 10.0), BRASS_DARK)
	draw_rect(Rect2(-14.0, foot - 14.0, 28.0, 6.0), BRASS)
	# The candle itself, with the drip down one side that says wax rather than paint.
	var body := Rect2(-SIZE.x * 0.5, foot - 14.0 - SIZE.y, SIZE.x, SIZE.y)
	draw_rect(body, WAX)
	draw_rect(Rect2(body.position.x + SIZE.x - 7.0, body.position.y + 8.0, 7.0,
		SIZE.y - 8.0), WAX_DARK)
	# The flame, and the light it throws. Two frames of drift, which at this size is all a
	# flame needs to be alive.
	var lean := 2.0 * sin(_flicker * 7.0)
	var height := 15.0 + 3.0 * sin(_flicker * 11.0)
	var tip := Vector2(lean, body.position.y - height)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5.0, body.position.y), Vector2(5.0, body.position.y), tip]), FLAME)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2.0, body.position.y), Vector2(2.0, body.position.y),
		tip + Vector2(0.0, height * 0.42)]), FLAME_CORE)
	draw_circle(Vector2(0.0, body.position.y - 6.0), 62.0, GLOW)
