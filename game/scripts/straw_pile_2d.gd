class_name StrawPile2D
extends Node2D
## A heap of cut cogon and rice straw, and the thing Node 2's three routes disagree about.
##
## CUT STRAW, NOT HARVESTED GRAIN, and that is a build constraint rather than a detail.
## Scattering someone's *tinawon* harvest across a terrace is not a neutral image to stage,
## and the Protector route below does exactly that -- straw keeps the picture and removes
## the problem. See the build spec's cultural guardrails.
##
## Three ways to search it, and the pile remembers which:
##   comb    patient, section by section. The pile is left standing
##   tunnel  in underneath and out again. One hole, otherwise undisturbed
##   scatter fastest, and it does not go back. Lolo does not stop the player, and he
##           mentions it at the marker stone on the way out
##
## No collision. A shoulder-high pile of straw is something you push through, not something
## you climb, and a solid one would be a wall across the only route out of the level.

signal searched(how: String)

enum State { INTACT, COMBED, TUNNELLED, SCATTERED }

const AtlasTile = preload("res://scripts/atlas_tile.gd")
const TEXTURE_MAP := preload("res://assets/Level1/texturemap.png")
## Real thatch, cut from the middle of the atlas's hut panel. This was the straw band off
## the top of a rice tile, which is standing crop rather than cut straw -- the heaps read
## as a piece of the field they were lying in.
const STRAW := Rect2(734, 1012, 70, 44)

@export var pile_size := Vector2(150.0, 96.0)
## Straw catches the light unevenly; a row of identical mounds reads as wallpaper.
@export var tint := Color(1.0, 0.97, 0.86, 1.0)

var _state: int = State.INTACT
var _mound: Polygon2D
var _scatter: Node2D


func _ready() -> void:
	add_to_group(&"straw_piles")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build()


func state() -> int:
	return _state


func is_disturbed() -> bool:
	return _state != State.INTACT


## Patient. The pile settles a little and stays standing.
func comb() -> void:
	if _state != State.INTACT:
		return
	_state = State.COMBED
	_reshape(0.82, 0.9)
	searched.emit("comb")


## In underneath. One hole, and the top of the pile keeps its shape.
func tunnel() -> void:
	if _state != State.INTACT:
		return
	_state = State.TUNNELLED
	_reshape(0.94, 0.78)
	searched.emit("tunnel")


## Gone, and it does not come back. The one route with a cost you can see.
func scatter() -> void:
	if _state == State.SCATTERED:
		return
	_state = State.SCATTERED
	if _mound != null:
		_mound.visible = false
	_build_scatter()
	searched.emit("scatter")


func _build() -> void:
	_mound = Polygon2D.new()
	_mound.name = "Mound"
	_mound.polygon = _mound_shape(1.0, 1.0)
	AtlasTile.fill(_mound, TEXTURE_MAP, STRAW)
	_mound.color = tint
	add_child(_mound)


## A heap, not a box: wider at the base, rounded over, and slightly lopsided so three of
## them side by side do not read as one repeated sprite.
func _mound_shape(width_scale: float, height_scale: float) -> PackedVector2Array:
	var half := pile_size.x * 0.5 * width_scale
	var high := pile_size.y * height_scale
	return PackedVector2Array([
		Vector2(-half, 0.0),
		Vector2(-half * 0.86, -high * 0.42),
		Vector2(-half * 0.44, -high * 0.86),
		Vector2(0.0, -high),
		Vector2(half * 0.5, -high * 0.82),
		Vector2(half * 0.88, -high * 0.36),
		Vector2(half, 0.0),
	])


## The fill is re-anchored with the shape. A Polygon2D pins its texture to its vertices,
## so a heap that settles by nine pixels slides the straw off the top of itself.
func _reshape(width_scale: float, height_scale: float) -> void:
	if _mound != null:
		_mound.polygon = _mound_shape(width_scale, height_scale)
		_mound.uv = AtlasTile.anchor_uv(_mound.polygon)


## What is left after the wind: loose handfuls across the terrace, which is the whole
## point of the Protector cost being visible rather than described.
func _build_scatter() -> void:
	if _scatter != null:
		return
	_scatter = Node2D.new()
	_scatter.name = "Scattered"
	add_child(_scatter)
	var rng := RandomNumberGenerator.new()
	# Seeded from where the pile stands, so a restored checkpoint scatters it the same way
	# rather than reshuffling every time the player dies.
	rng.seed = int(abs(position.x) * 7.0 + abs(position.y) * 13.0)
	for index in range(9):
		var tuft := Polygon2D.new()
		var w: float = rng.randf_range(16.0, 30.0)
		var h: float = rng.randf_range(5.0, 11.0)
		tuft.polygon = PackedVector2Array([
			Vector2(-w * 0.5, 0.0), Vector2(-w * 0.3, -h),
			Vector2(w * 0.3, -h * 0.7), Vector2(w * 0.5, 0.0),
		])
		AtlasTile.fill(tuft, TEXTURE_MAP, STRAW)
		tuft.color = tint
		tuft.position = Vector2(
			rng.randf_range(-pile_size.x * 1.4, pile_size.x * 1.4),
			rng.randf_range(-6.0, 2.0))
		tuft.rotation = rng.randf_range(-0.5, 0.5)
		_scatter.add_child(tuft)
