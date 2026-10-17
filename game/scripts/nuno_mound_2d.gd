class_name NunoMound2D
extends StaticBody2D
## A punso on the path: the nuno's mound (Kent's design, "Nuno sa punso").
##
## Solid, and too steep at the sides to walk up, so the only way past it is over -- and the only
## way over it that does not touch it is a jump that clears it. Standing on any of it is standing
## on the nuno's crown, and that curses her (the level's to do: crown_touched).
##
## What it keeps is the crossing: whether she stopped and asked first (`ask()`, the level's E),
## and whether she touched it on the way. Getting from its west side to its east side says which
## (crossed). Going back west starts a new crossing.
##
## No hurtbox, on purpose: it is not a thing to fight, and no weapon finds it. Its crown is found
## through her hurtbox, so it is the same for the apo and for anything she has become.

signal crown_touched
signal crossed(clean: bool, asked: bool)

## The dome, base to crown, in px: a little wider than she can step and as tall as a step is not.
const WIDTH := 150.0
const HEIGHT := 34.0
## Her hurtbox's feet are this far under its bottom edge (PlayerHurtbox2D: 44 to the middle, 72 tall).
const HURTBOX_ABOVE_FEET := 8.0
## The crown's band: standing anywhere on the dome puts her hurtbox in it, a jump that clears the
## dome never does -- not even taking off right at its foot.
const CROWN_HALF_WIDTH := 40.0
const CROWN_TOP := -(HEIGHT + 1.0 + HURTBOX_ABOVE_FEET)
const CROWN_BOTTOM := -20.0
## How far past its foot, either side, counts as off it.
const CLEAR_OF := 10.0
const SOIL := Color(0.36, 0.27, 0.19)
const SOIL_LIGHT := Color(0.48, 0.37, 0.25)
const OFFERING := Color(0.93, 0.86, 0.66)
const COIN := Color(0.96, 0.78, 0.3)

var asked := false
var _touched := false
var _west := false
var crown: Area2D


func _ready() -> void:
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0
	var dome := CollisionPolygon2D.new()
	dome.polygon = _dome_points()
	add_child(dome)
	crown = Area2D.new()
	crown.name = "Crown"
	crown.collision_layer = 0
	crown.collision_mask = PhysicsLayers.PLAYER_HURTBOX
	crown.monitorable = false
	var band := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(CROWN_HALF_WIDTH * 2.0, CROWN_BOTTOM - CROWN_TOP)
	band.shape = box
	band.position = Vector2(0.0, (CROWN_TOP + CROWN_BOTTOM) * 0.5)
	crown.add_child(band)
	add_child(crown)
	crown.area_entered.connect(_on_crown_entered)
	queue_redraw()


func _physics_process(_delta: float) -> void:
	var hurtbox := _her_hurtbox()
	if hurtbox == null:
		return
	var x := to_local(hurtbox.middle()).x
	if x < -WIDTH * 0.5 - CLEAR_OF:
		if not _west:
			_west = true
			_touched = false
	elif x > WIDTH * 0.5 + CLEAR_OF and _west:
		_west = false
		crossed.emit(not _touched, asked)


## She stopped and asked to pass. Said once; it holds until she has crossed.
func ask() -> void:
	asked = true


func touched_this_crossing() -> bool:
	return _touched


## Back to before she came: the checkpoint the level restored is from then.
func reset_for_restore() -> void:
	asked = false
	_touched = false
	_west = false


func _on_crown_entered(area: Area2D) -> void:
	if area is PlayerHurtbox2D:
		_touched = true
		crown_touched.emit()


func _her_hurtbox() -> PlayerHurtbox2D:
	for node in get_tree().get_nodes_in_group(PlayerHurtbox2D.GROUP):
		var hurtbox := node as PlayerHurtbox2D
		if hurtbox != null and hurtbox.is_inside_tree():
			return hurtbox
	return null


static func _dome_points() -> PackedVector2Array:
	var half := WIDTH * 0.5
	return PackedVector2Array([Vector2(-half, 0.0), Vector2(-half * 0.8, -HEIGHT * 0.53),
		Vector2(-half * 0.47, -HEIGHT * 0.88), Vector2(0.0, -HEIGHT),
		Vector2(half * 0.47, -HEIGHT * 0.88), Vector2(half * 0.8, -HEIGHT * 0.53), Vector2(half, 0.0)])


## PLACEHOLDER until it has art: the mound in two earths, and what has been left for the nuno at
## its western foot -- a bowl, two candle stubs, coins -- so a careful player sees it is tended.
func _draw() -> void:
	draw_colored_polygon(_dome_points(), SOIL)
	var cap := PackedVector2Array()
	for point in _dome_points():
		if point.y < -HEIGHT * 0.5:
			cap.append(point)
	cap.append(Vector2(WIDTH * 0.24, -HEIGHT * 0.5))
	cap.append(Vector2(-WIDTH * 0.24, -HEIGHT * 0.5))
	draw_colored_polygon(cap, SOIL_LIGHT)
	var foot := -WIDTH * 0.5 - 18.0
	draw_arc(Vector2(foot, -4.0), 9.0, 0.0, PI, 10, OFFERING, 3.0)
	draw_rect(Rect2(foot - 22.0, -14.0, 5.0, 14.0), OFFERING)
	draw_rect(Rect2(foot + 14.0, -11.0, 5.0, 11.0), OFFERING)
	for coin in [Vector2(foot - 8.0, -2.0), Vector2(foot + 4.0, -1.5), Vector2(foot - 1.0, -3.0)]:
		draw_circle(coin, 2.5, COIN)
