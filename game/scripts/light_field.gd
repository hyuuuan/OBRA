class_name LightField
extends RefCounted
## HOW LIT A POINT IS -- the gameplay truth about the dark, kept apart from how it is drawn.
##
## Anything that gives light joins GROUP and answers `light_hole() -> Dictionary`. The darkness
## layer draws those same holes, and everything that cares whether a place is lit (a sigbin that
## only shows in the light, an enemy that will not cross a lantern) asks `light_at` -- so what the
## player sees and what the game counts can never disagree.
##
## A hole is either radial or a cone:
##   {"position": Vector2, "radius": float, "strength": float}                    radial
##   {"position": Vector2, "radius": float, "strength": float,
##    "direction": Vector2, "half_angle": float}                                  a cone (radians)
## `radius` is in world px. Inside SOFT_EDGE of the radius a source is at full strength, fading
## to nothing at the radius -- the same falloff the shader draws.

const GROUP := &"light_sources"
## The share of a light's radius that is fully lit; the rest is its soft edge.
const SOFT_EDGE := 0.6


## How lit `point` is, 0 (dark) to 1, from these holes over an `ambient` floor.
static func light_from(holes: Array, point: Vector2, ambient: float = 0.0) -> float:
	var lit := clampf(ambient, 0.0, 1.0)
	for hole_value: Variant in holes:
		var hole: Dictionary = hole_value
		lit = maxf(lit, contribution(hole, point))
		if lit >= 1.0:
			return 1.0
	return lit


## What one hole gives `point`.
static func contribution(hole: Dictionary, point: Vector2) -> float:
	var radius := float(hole.get("radius", 0.0))
	if radius <= 0.0:
		return 0.0
	var offset := point - (hole.get("position", Vector2.ZERO) as Vector2)
	var distance := offset.length()
	if distance >= radius:
		return 0.0
	var strength := clampf(float(hole.get("strength", 1.0)), 0.0, 1.0)
	var falloff := 1.0 - smoothstep(radius * SOFT_EDGE, radius, distance)
	if hole.has("direction"):
		var direction := (hole["direction"] as Vector2).normalized()
		var half := float(hole.get("half_angle", 0.5))
		if distance > 1.0:
			var off_axis := absf(direction.angle_to(offset))
			falloff *= 1.0 - smoothstep(half * 0.7, half, off_axis)
	return falloff * strength


## Every hole the scene's lights answer right now.
static func holes_in(tree: SceneTree) -> Array:
	var holes: Array = []
	for source in tree.get_nodes_in_group(GROUP):
		if source.has_method("light_hole") and source is CanvasItem \
				and (source as CanvasItem).is_visible_in_tree():
			var hole: Dictionary = source.call("light_hole")
			if not hole.is_empty():
				holes.append(hole)
	return holes


## How lit `point` is in this scene, over `ambient`.
static func light_at(tree: SceneTree, point: Vector2, ambient: float = 0.0) -> float:
	return light_from(holes_in(tree), point, ambient)
