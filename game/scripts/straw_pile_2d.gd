class_name StrawPile2D
extends Node2D
## A heap of cut cogon and rice straw, and the thing Node 2's three routes disagree about.
##
## CUT STRAW, NOT HARVESTED GRAIN, and that is a build constraint rather than a detail.
## Scattering someone's *tinawon* harvest across a terrace is not a neutral image to stage,
## and the Protector route below does exactly that -- straw keeps the picture and removes
## the problem. See the build spec's cultural guardrails.
##
## IT IS DELIVERED ART NOW. Two goes at drawing straw in code came and went -- the first
## fanned thin diagonal lines out of a crown and read as scratches, the second built it from
## axis-aligned columns and read as a shaded dome with scratches on it. Kent drew the heap;
## `tools/build_art.py` keys it off its white page and cuts it down to the size it stands at.
##
## ONE PICTURE, FOUR STATES. The heap he drew has a way in, and the other two on the terrace
## do not -- so the cutter also produces a mouthless copy, by mirroring the straw from the
## far side of the heap over the doorway. Which of the two a pile draws is the whole of how
## a tunnelled heap differs from a combed one.
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
## The apo is standing in the mouth of a heap that has one, or has stepped back off it.
##
## IT IS NOT "SHE HAS GONE IN". The mouth sits on the path east -- Terrace5 is how you get
## to Node 3 -- so a heap that swallows anybody who walks past it is a hole in the floor of
## the level, and run_nodraw found exactly that: the bot's run east stopped dead at the
## doorway. Going in is a deliberate press; this only says the offer is there.
signal at_mouth(standing: bool)

enum State { INTACT, COMBED, TUNNELLED, SCATTERED }

const HEAP := preload("res://assets/Level1/props/haybale.png")
const HEAP_SOLID := preload("res://assets/Level1/props/haybale_solid.png")

## How big the heap stands. The art is 208 x 144, so a heap at that size draws it pixel for
## pixel; the two smaller ones on the terrace are exactly HALF, which keeps their pixels
## square. Anything in between resamples the straw and the stalks go soft.
@export var pile_size := Vector2(208.0, 144.0)
## Straw catches the light unevenly; a row of identical mounds reads as wallpaper.
@export var tint := Color(1.0, 1.0, 1.0, 1.0)
## Faces the other way, so the two small heaps are not one sprite printed twice.
@export var flipped := false
## THIS ONE HAS A WAY IN, and it is the only place in Level 1 with an inside. Standing in
## the mouth offers it; pressing down takes it. What is through it is a room somewhere else
## entirely, so the mouth only has to be enterable, not stood up in.
@export var entrance := false

## Where the doorway sits in the delivered art, as a fraction of the heap. Measured off the
## source rather than eyeballed: the mouth is x 292-570 of a picture that crops to x 22-1004,
## and y 414-748 of one that crops to y 71-748.
const MOUTH_LEFT := 0.2747
const MOUTH_RIGHT := 0.5575
const MOUTH_TOP := 0.506

## The golds, darkest to lightest, sampled off Kent's heap so the scattered straw and the
## walls of the room inside it are the same straw as the picture.
const EDGE := Color(0.369, 0.227, 0.071, 1.0)   # 5E3A12  the shadow between clumps
const DARK := Color(0.588, 0.376, 0.118, 1.0)   # 96601E
const MID := Color(0.788, 0.541, 0.169, 1.0)    # C98A2B
const BODY := Color(0.929, 0.710, 0.227, 1.0)   # EDB53A
const LIT := Color(1.000, 0.843, 0.369, 1.0)    # FFD75E
const HI := Color(1.000, 0.941, 0.659, 1.0)     # FFF0A8  the catch on a stalk facing up

var _state: int = State.INTACT
var _inside := false
## Mirrored copies, built the first time one is asked for.
##
## NEITHER OF THE TWO OBVIOUS WAYS WORKS. draw_texture_rect's fifth argument is `transpose`,
## which swaps the axes rather than mirroring -- pass `true` and the heap is drawn on its
## side inside its own box. A Rect2 with a negative width, which is how the docs say to
## flip, draws nothing at all in 4.7.
static var _mirrors: Dictionary = {}


func _ready() -> void:
	add_to_group(&"straw_piles")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if entrance:
		_build_mouth_area()
	queue_redraw()


func state() -> int:
	return _state


func is_disturbed() -> bool:
	return _state != State.INTACT


func is_inside() -> bool:
	return _inside


## Where the way in is, in the heap's own space. Read off the art, so moving the doorway is
## a matter of redrawing the heap rather than of retuning a number here.
func mouth_rect() -> Rect2:
	var settle := _settle()
	var wide := pile_size.x * settle.x
	var high := pile_size.y * settle.y
	var left := wide * (MOUTH_LEFT - 0.5)
	var right := wide * (MOUTH_RIGHT - 0.5)
	if flipped:
		var swap := left
		left = -right
		right = -swap
	return Rect2(Vector2(left, -high * (1.0 - MOUTH_TOP)),
		Vector2(right - left, high * (1.0 - MOUTH_TOP)))


## Patient. The pile settles a little and stays standing.
func comb() -> void:
	if _state != State.INTACT:
		return
	_state = State.COMBED
	queue_redraw()
	searched.emit("comb")


## In underneath. One hole, and the top of the pile keeps its shape.
func tunnel() -> void:
	if _state != State.INTACT:
		return
	_state = State.TUNNELLED
	queue_redraw()
	searched.emit("tunnel")


## Gone, and it does not come back. The one route with a cost you can see.
func scatter() -> void:
	if _state == State.SCATTERED:
		return
	_state = State.SCATTERED
	queue_redraw()
	searched.emit("scatter")


## Put it back the way it was found.
##
## Nothing in the level calls this -- a checkpoint restore leaves the straw where the route
## left it, which is right, since a route commit is written to a checkpoint and is not meant
## to be undone. It exists because the prop photographer has to take four pictures of one
## heap, and comb() and tunnel() both refuse to run on a pile that is not intact: it was
## calling them in order on the same three piles, so the frame labelled "tunnelled" was a
## picture of a COMBED pile for as long as the node existed.
func restore_intact() -> void:
	_state = State.INTACT
	queue_redraw()


## The volume that notices the apo standing in the mouth. It is an Area2D and nothing else:
## the heap has no collision, deliberately, so walking up to it is walking up to it.
func _build_mouth_area() -> void:
	var area := Area2D.new()
	area.name = "Mouth"
	area.collision_layer = 0
	area.collision_mask = 1
	add_child(area)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	var mouth := mouth_rect()
	# THE PROMPT IS WIDER THAN THE DOORWAY, AND ON PURPOSE.
	#
	# `mouth_rect` is where the hole is in the ART and must stay that -- the audit measures
	# it and the entry offer is drawn from it. But it is 59 x 71 world pixels, and outside
	# that box nothing anywhere on screen said the heap had an inside. A player walking the
	# terrace east to Node 3 passed within a stride of the only door in Level 1 and was told
	# about it for about a fifth of a second, if they happened to walk through the exact
	# pixels of the opening.
	#
	# Going in is still a PRESS, so a generous notice zone cannot swallow anyone -- that was
	# the constraint that made this a keypress in the first place. It reaches the whole width
	# of the heap and up to the eaves: stand anywhere in front of the haystack and the game
	# tells you there is a way under it.
	var settle := _settle()
	# The lower two thirds only. Full height would put the notice zone across the ROOF of the
	# heap, and "there is a way in under the straw" is not a thing to be told while standing
	# on top of it.
	var reach := Vector2(pile_size.x * settle.x + 48.0, pile_size.y * settle.y * 0.66)
	box.size = reach
	shape.shape = box
	shape.position = Vector2(mouth.get_center().x * 0.35, -reach.y * 0.5)
	area.add_child(shape)
	area.body_entered.connect(_on_mouth_body.bind(true, area))
	area.body_exited.connect(_on_mouth_body.bind(false, area))


func _on_mouth_body(body: Node, coming_in: bool, area: Area2D) -> void:
	if not _is_the_player(body):
		return
	if _inside == coming_in:
		return
	# A DRAWN CREATURE IS MANY BODIES AND THEY LEAVE ONE AT A TIME. The apo is one capsule,
	# so a bare transition was right for as long as she was the only thing that could stand
	# here; a rig's first foot out of the mouth would otherwise take the prompt down while
	# the rest of it is still standing in the doorway. Same rule LevelObstacle2D follows.
	if not coming_in and area != null:
		for other in area.get_overlapping_bodies():
			if other != body and _is_the_player(other):
				return
	_inside = coming_in
	at_mouth.emit(coming_in)


func _is_the_player(body: Node) -> bool:
	var node := body as Node
	while node != null:
		if node.is_in_group(&"player_character") or node is ActiveRagdollMorph:
			return true
		node = node.get_parent()
	return false


## How wide and how tall the heap stands in each state. Combed is spread and pulled DOWN;
## tunnelled keeps its height, because the hole is underneath it.
##
## COMBED USED TO BE AN 8% SIZE CHANGE ON THE SAME PICTURE, which is the whole of what the
## Artist route left behind: a player who went through the heap by hand and a player who
## never touched it were looking at the same haystack. A route that costs patience has to
## leave a mark you can see from where you are standing, so it is spread wide and low now --
## a different silhouette, not a different scale -- and _draw_combing rakes it.
func _settle() -> Vector2:
	match _state:
		State.COMBED:
			return Vector2(1.14, 0.70)
		State.TUNNELLED:
			return Vector2(0.99, 0.97)
		_:
			return Vector2.ONE


func _draw() -> void:
	if _state == State.SCATTERED:
		_draw_scattered()
		return
	var settle := _settle()
	var wide := pile_size.x * settle.x
	var high := pile_size.y * settle.y
	_draw_ground_shadow(wide * 0.5)
	# WHICH PICTURE, AND IT IS THE WHOLE STATE MACHINE. A heap you can go into has a
	# doorway; a heap somebody tunnelled under has a hole; anything else is solid straw.
	var art := HEAP if entrance or _state == State.TUNNELLED else HEAP_SOLID
	var box := Rect2(Vector2(-wide * 0.5, -high), Vector2(wide, high))
	draw_texture_rect(_mirror(art) if flipped else art, box, false, tint)
	if _state == State.COMBED:
		_draw_combing(wide, high)


## The marks a rake leaves. Furrows across the face of the heap and a fringe of loose stalks
## pulled out at the foot -- enough to say somebody went through this by hand, drawn rather
## than cut because there is no picture of a combed heap and the delivered silhouette is
## still doing the work underneath.
func _draw_combing(wide: float, high: float) -> void:
	var rng := _rng()
	# THE DOORWAY IS NOT RAKED OVER. On the entrance heap the mouth is the only way into the
	# one room in Level 1, and combing already squashes it to seven tenths of its height --
	# furrows drawn across it as well would close the last thing saying it is there.
	var mouth := mouth_rect() if entrance else Rect2()
	for index in range(11):
		var t := (float(index) + 0.5) / 11.0
		var x := lerpf(-wide * 0.42, wide * 0.42, t)
		if entrance and x > mouth.position.x - 6.0 and x < mouth.end.x + 6.0:
			continue
		var top := -high * rng.randf_range(0.58, 0.86)
		var run := Vector2(rng.randf_range(-5.0, 5.0), high * rng.randf_range(0.34, 0.52))
		draw_line(Vector2(x, top), Vector2(x, top) + run, EDGE * tint, 2.0, false)
		draw_line(Vector2(x + 2.0, top), Vector2(x + 2.0, top) + run, LIT * tint, 1.0, false)
	for index in range(26):
		var at := Vector2(rng.randf_range(-wide * 0.62, wide * 0.62), rng.randf_range(-7.0, 0.0))
		var run := Vector2(rng.randf_range(-15.0, 15.0), rng.randf_range(-5.0, 1.0))
		draw_line(at, at + run, _ramp(rng.randf_range(0.4, 1.0)) * tint, 2.0, false)


## What stops it floating. Everything in the house that stands on the floor has one of
## these and the heaps did not.
func _mirror(art: Texture2D) -> Texture2D:
	if not _mirrors.has(art):
		var image := art.get_image()
		image.flip_x()
		_mirrors[art] = ImageTexture.create_from_image(image)
	return _mirrors[art]


func _draw_ground_shadow(half: float) -> void:
	draw_rect(Rect2(-half - 4.0, -3.0, half * 2.0 + 8.0, 5.0), Color(0.0, 0.0, 0.0, 0.30))
	draw_rect(Rect2(-half - 9.0, -1.0, half * 2.0 + 18.0, 3.0), Color(0.0, 0.0, 0.0, 0.16))


## What is left after the wind: loose handfuls across the terrace, which is the whole point
## of the Protector cost being visible rather than described. Drawn rather than cut, because
## there is no picture of a heap that has been pulled apart -- and a heap is a silhouette
## while scattered straw is a scatter, so nothing about the delivered art would survive it.
func _draw_scattered() -> void:
	var rng := _rng()
	for index in range(150):
		var across := rng.randf_range(-1.0, 1.0)
		var at := Vector2(across * pile_size.x * 1.25,
			rng.randf_range(-11.0, 1.0) * (1.0 - absf(across) * 0.6))
		var run := Vector2(rng.randf_range(-24.0, 24.0), rng.randf_range(-8.0, 2.0))
		draw_line(at, at + run, _ramp(rng.randf_range(0.3, 1.0)) * tint,
			3.0 if rng.randf() < 0.2 else 2.0, false)


## Seeded from where the pile stands, so the same heap scatters the same way every frame and
## after a restored checkpoint.
func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(position.x) * 7919.0 + absf(position.y) * 104729.0) | 1
	return rng


func _ramp(lit: float) -> Color:
	var ramp: Array[Color] = [EDGE, DARK, MID, BODY, LIT, HI]
	return ramp[int(round(clampf(lit, 0.0, 1.0) * float(ramp.size() - 1)))]
