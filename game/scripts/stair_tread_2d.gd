class_name StairTread2D
extends StaticBody2D
## One stone step of Ang Hagdan, drawn from the Level 1 atlas so it reads as cut stone
## rather than as an invisible collider.
##
## Follows TerraceSegment2D's conventions on purpose -- same atlas, same regions, same
## TOP-LEFT anchoring -- because a tread that anchors differently from the terrain it sits
## against is a step whose height you have to compute twice. That is not hypothetical: the
## first version of these treads was centre-anchored, every riser came out half a tread
## shorter than intended, and all three became jumpable. Beat 0 stopped being a puzzle and
## the geometry that was supposed to illustrate the lesson was what defeated it.
##
## A tread is scenery with a surface. It has no behaviour, and deliberately no ability to
## be moved, drawn on, or destroyed -- the ones that are gone are gone, and the gap they
## left is the whole point of the beat.

const TEXTURE_MAP := preload("res://assets/Level1/texturemap.png")
## Same atlas regions TerraceSegment2D uses for its stone faces.
const STONE_TOP := Rect2(828, 343, 84, 86)
const STONE_WALL := Rect2(217, 401, 146, 125)

## Top-left anchored, like every terrace. `position` is the tread's upper-left corner and
## `tread_size.y` is how far its stone face drops below the surface you stand on.
@export var tread_size := Vector2(84.0, 26.0)
## How much of the tread is the walking surface before the riser starts.
@export var cap_height := 14.0

## A tread that is GONE: the snapped-off stub of one, drawn and not solid.
##
## Three of these carry the whole read of the beat. Two intact stones on their own look
## like two rocks; two stones with three broken stubs below them look like a stair someone
## has to repair, which is the sentence Lolo is saying out loud at the same moment.
@export var is_broken := false


func _ready() -> void:
	add_to_group(&"stair_treads")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Drawn over the retaining wall behind it. Cut stone against rubble is already a
	# different texture, but at this scale the silhouette is what separates them, and a
	# tread half-buried behind the wall it is set into has no silhouette at all.
	z_index = 3
	if is_broken:
		# No collision and no ground group: standing on the treads that are missing is
		# exactly what the beat is about.
		_build_stub()
		return
	# NOT terrace_ground. That group means "terrace segment" -- it is what the Banaue
	# environment test counts to check the level still has its sixteen terraces -- and a
	# step is not a terrace. Joining it made the count 18 and failed a test about
	# something else entirely.
	_build_collision()
	_build_visuals()


## The walking surface, in world space. What a reachability check should ask for rather
## than reading `position` and re-deriving the offset at every call site.
func surface_y() -> float:
	return global_position.y


func _build_collision() -> void:
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.position = tread_size * 0.5
	var rectangle := RectangleShape2D.new()
	rectangle.size = tread_size
	collision.shape = rectangle
	add_child(collision)


func _build_visuals() -> void:
	# The riser first and behind, so the cap's edge sits over it.
	var wall := TextureRect.new()
	wall.name = "Riser"
	wall.position = Vector2(0.0, cap_height)
	wall.size = Vector2(tread_size.x, maxf(1.0, tread_size.y - cap_height))
	wall.texture = _atlas(STONE_WALL)
	wall.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	wall.stretch_mode = TextureRect.STRETCH_TILE
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wall.show_behind_parent = true
	add_child(wall)

	var cap := TextureRect.new()
	cap.name = "Cap"
	cap.position = Vector2.ZERO
	cap.size = Vector2(tread_size.x, cap_height)
	cap.texture = _atlas(STONE_TOP)
	cap.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	cap.stretch_mode = TextureRect.STRETCH_TILE
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cap)


## What is left of a tread that broke: a short stub against the wall, darker, sitting where
## the stone used to spring from. Deliberately not a neat half-tread -- a clean rectangle
## reads as a small step and invites a jump.
func _build_stub() -> void:
	var stub := TextureRect.new()
	stub.name = "Stub"
	stub.position = Vector2.ZERO
	stub.size = Vector2(maxf(12.0, tread_size.x * 0.34), tread_size.y * 0.8)
	stub.texture = _atlas(STONE_WALL)
	stub.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	stub.stretch_mode = TextureRect.STRETCH_TILE
	stub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sunk into shadow, so it reads as a scar rather than as a ledge.
	stub.modulate = Color(0.46, 0.44, 0.40, 1.0)
	add_child(stub)


func _atlas(region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = TEXTURE_MAP
	atlas.region = region
	return atlas
