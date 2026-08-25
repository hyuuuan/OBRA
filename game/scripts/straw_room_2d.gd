class_name StrawRoom2D
extends Node2D
## What is inside the heap: one of Lola's canvases, a key on the floor, and the ants that
## were living in there before anybody came looking.
##
## IT IS THE ONLY INTERIOR IN LEVEL 1, and the reason to have gone in. The chest is beside
## it and stays shut -- that is Node 3's problem and the line that closes Node 2 is "Locked.
## Of course." -- so what the room actually pays out is the canvas and the key, and neither
## of them opens the chest. Finding a key that does not fit the lock it is lying next to is
## the point rather than an oversight.
##
## THE CANVAS IS THE NEXT PLACE. Every level in this game is somewhere Lola painted, and the
## hub is a wall of those paintings; one of them propped in the straw with her chest says
## where this is all going without a word of exposition, and it is the same image the player
## will later stand in front of in the house. It is loaded from the hub's own folder for
## exactly that reason -- two copies of that picture would be two pictures.
##
## Everything here is hidden until the apo is standing in the heap, because it is inside it.

signal key_taken()

## The heap this is the inside of. The room shows itself when the apo walks in and hides
## when she walks out, so it does not have to know anything else about her.
@export var pile_path: NodePath = NodePath("../StrawPileB")
## What the canvas is a painting of. A level id, so the picture and the place cannot drift
## apart: it is read out of the hub's paintings, which is where the same image already lives.
@export var canvas_level_id: String = "level_2"
@export var canvas_size := Vector2(96.0, 54.0)
## Where the canvas leans, the key lies, and the ants are, in the heap's own space -- the
## heap's origin is the middle of its base, so these are measured off the floor it stands on.
@export var canvas_at := Vector2(6.0, -128.0)
## DEEPER IN THAN THE MOUTH. The apo comes in at the middle of the opening and the key area
## is walked into, so a key lying by the door is a key taken before she has looked at
## anything -- the room's whole beat is over on the frame she enters. It sits by the chest,
## which is a few steps further in.
@export var key_at := Vector2(42.0, -10.0)
## What the profile records when the key is taken.
@export var collectible_id: String = "L1_straw_key"

## The gilt of the hub's picture frames, because this canvas is one of the same set.
const FRAME := Color(0.647, 0.447, 0.137, 1.0)      # A57223
const FRAME_LIT := Color(0.859, 0.655, 0.212, 1.0)  # DBA736
const FRAME_EDGE := Color(0.361, 0.212, 0.055, 1.0) # 5C360E
## Brass, dulled. A key that has been in a straw heap is not a bright one.
const BRASS := Color(0.831, 0.667, 0.216, 1.0)      # D4AA37
const BRASS_LIT := Color(0.949, 0.851, 0.427, 1.0)  # F2D96D
const BRASS_DARK := Color(0.502, 0.376, 0.098, 1.0) # 806019
const ANT := Color(0.180, 0.106, 0.075, 1.0)        # 2E1B13

var _taken := false
var _pile: Node2D
var _art: Texture2D
var _key_area: Area2D


func _ready() -> void:
	add_to_group(&"straw_rooms")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var path := "res://assets/hub/paintings/%s.png" % canvas_level_id
	if ResourceLoader.exists(path):
		_art = load(path)
	_pile = get_node_or_null(pile_path) as Node2D
	if _pile != null:
		global_position = _pile.global_position
		_pile.connect(&"entered", _on_pile_entered)
		_pile.connect(&"left", _on_pile_left)
	_build_key_area()
	visible = false


func key_is_taken() -> bool:
	return _taken


## DEFERRED, EVERY TIME. All three of these run inside a body_entered/body_exited handler --
## the pile's mouth area emits `entered` from one, and the key's own pickup is one -- and
## Godot refuses to switch an area's monitoring while it is in the middle of delivering a
## signal from it. It is an error printed to the log and nothing else, which is why every
## visual run of this looked fine and the headless bot walking the level found it.
func _on_pile_entered() -> void:
	visible = true
	if _key_area != null:
		_key_area.set_deferred(&"monitoring", not _taken)
	queue_redraw()


func _on_pile_left() -> void:
	visible = false
	if _key_area != null:
		_key_area.set_deferred(&"monitoring", false)


## WALKED ONTO, not pressed at. E reaches only placed drawings -- that is what the group is
## and what the reach is measured against -- and giving this its own key would mean a second
## meaning for the same button in the one room where the player has just learned the first.
## The level already picks things up by being walked into: that is what a checkpoint is.
func _build_key_area() -> void:
	_key_area = Area2D.new()
	_key_area.name = "Key"
	_key_area.collision_layer = 0
	_key_area.collision_mask = 1
	_key_area.monitoring = false
	_key_area.position = key_at
	add_child(_key_area)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(46.0, 40.0)
	shape.shape = box
	shape.position = Vector2(0.0, -8.0)
	_key_area.add_child(shape)
	_key_area.body_entered.connect(_on_key_body)


func _on_key_body(body: Node) -> void:
	if _taken:
		return
	var node := body as Node
	while node != null:
		if node.is_in_group(&"player_character") or node is ActiveRagdollMorph:
			_taken = true
			_key_area.monitoring = false
			var profile := get_node_or_null(^"/root/PlayerProfile")
			if profile != null:
				profile.call("record_collectible", collectible_id)
			queue_redraw()
			key_taken.emit()
			return
		node = node.get_parent()


func _draw() -> void:
	_draw_canvas()
	if not _taken:
		_draw_key(key_at)
	_draw_ants()


## One of Lola's, leaning on the inside of the heap. Framed like the ones in the house,
## because it is one of the ones in the house.
func _draw_canvas() -> void:
	var half := canvas_size * 0.5
	var picture := Rect2(canvas_at - half, canvas_size)
	# The straw behind it darkened, so the canvas is against something rather than floating.
	draw_rect(picture.grow(9.0), Color(0.086, 0.055, 0.024, 0.85))
	if _art != null:
		draw_texture_rect(_art, picture, false)
	else:
		draw_rect(picture, FRAME_EDGE)
	# A stepped moulding: light on the top and left, shadow on the bottom and right, the
	# same way round as every other frame in this game.
	for band in range(3):
		var rect := picture.grow(float(band) + 1.0)
		var thickness := 1.0
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, thickness)), FRAME_LIT)
		draw_rect(Rect2(rect.position, Vector2(thickness, rect.size.y)), FRAME)
		draw_rect(Rect2(rect.position.x, rect.end.y - thickness, rect.size.x, thickness),
			FRAME_EDGE)
		draw_rect(Rect2(rect.end.x - thickness, rect.position.y, thickness, rect.size.y),
			FRAME_EDGE)
	draw_rect(picture.grow(4.0), FRAME_EDGE, false, 1.0)


## A key, lying flat: a bow, a shank, and two teeth. Small -- it is a thing on a floor, not
## an icon, and the player finds it by walking over it rather than by spotting it.
func _draw_key(at: Vector2) -> void:
	# The shadow under it first, or it reads as painted on the earth.
	draw_rect(Rect2(at + Vector2(-15.0, -3.0), Vector2(32.0, 4.0)), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(at + Vector2(-14.0, -11.0), Vector2(11.0, 11.0)), BRASS)
	draw_rect(Rect2(at + Vector2(-11.0, -8.0), Vector2(5.0, 5.0)), Color(0.086, 0.055, 0.024))
	draw_rect(Rect2(at + Vector2(-14.0, -11.0), Vector2(11.0, 2.0)), BRASS_LIT)
	draw_rect(Rect2(at + Vector2(-3.0, -8.0), Vector2(19.0, 4.0)), BRASS)
	draw_rect(Rect2(at + Vector2(-3.0, -8.0), Vector2(19.0, 1.0)), BRASS_LIT)
	draw_rect(Rect2(at + Vector2(10.0, -4.0), Vector2(3.0, 4.0)), BRASS_DARK)
	draw_rect(Rect2(at + Vector2(14.0, -4.0), Vector2(2.0, 3.0)), BRASS_DARK)


## The tenants. Scenery, and deliberately nothing else: they carry no collision, nothing
## reads their position, and drawing one does not make one appear. A heap of straw left on
## a terrace for a season has ants in it, and that is the whole of the reason they are here.
func _draw_ants() -> void:
	for at: Vector2 in [Vector2(-58.0, -5.0), Vector2(-34.0, -3.0), Vector2(62.0, -7.0)]:
		draw_rect(Rect2(at + Vector2(-4.0, -2.0), Vector2(3.0, 3.0)), ANT)
		draw_rect(Rect2(at + Vector2(-1.0, -3.0), Vector2(3.0, 4.0)), ANT)
		draw_rect(Rect2(at + Vector2(2.0, -2.0), Vector2(2.0, 3.0)), ANT)
		for leg in range(3):
			var x := at.x - 3.0 + float(leg) * 3.0
			draw_rect(Rect2(Vector2(x, at.y + 1.0), Vector2(1.0, 2.0)), ANT)
