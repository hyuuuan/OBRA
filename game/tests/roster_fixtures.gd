class_name RosterFixtures
extends RefCounted
## Drawings shaped the way each archetype is actually drawn, shared by the regression
## suite and the roster sweep so both measure the same thing.
##
## Radial limbs -- a body with spokes coming off it in every direction -- are not how
## anyone draws an animal, and a rig tuned against them is tuned against nothing. A
## walker gets a body on four legs beneath it, a flier a body with a wing either side,
## a biped arms at the shoulders and legs at the hips.

const SpiderReferenceFixtures = preload("res://tests/spider_reference_fixtures.gd")


static func for_rig(rig_type: String, entity_id: String = "") -> Array:
	if entity_id == "spider":
		return SpiderReferenceFixtures.separate_legs()
	if entity_id == "snake":
		var wave := PackedVector2Array()
		for index in range(18):
			wave.append(Vector2(120.0 + index * 17.0, 256.0 + sin(float(index) * 0.75) * 30.0))
		return [stroke(wave)]
	match rig_type:
		"flier":
			return flier()
		"swimmer":
			return swimmer()
		"biped":
			return biped()
		"hopper":
			return legged(2, 240.0)
		"walker":
			return legged(4, 240.0)
	return [stroke(oval(256.0, 250.0, 60.0, 42.0))]


## The state each archetype is most characteristically animated in.
static func gait_for(rig_type: String) -> String:
	match rig_type:
		"flier":
			return "fly"
		"swimmer":
			return "swim"
		"hopper":
			return "jump"
	return "walk"


static func flier() -> Array:
	return [
		stroke(oval(256.0, 250.0, 44.0, 30.0)),
		stroke(PackedVector2Array([Vector2(232, 236), Vector2(190, 196), Vector2(150, 178)])),
		stroke(PackedVector2Array([Vector2(280, 236), Vector2(322, 196), Vector2(362, 178)]))
	]


static func swimmer() -> Array:
	return [
		stroke(oval(256.0, 250.0, 70.0, 38.0)),
		stroke(PackedVector2Array([
			Vector2(186, 250), Vector2(140, 215), Vector2(126, 250), Vector2(140, 285)
		]))
	]


## A body with four legs hanging beneath it (or two, for a hopper).
static func legged(count: int, centre_y: float) -> Array:
	var strokes: Array = [stroke(oval(256.0, centre_y, 70.0, 38.0))]
	var offsets := [-46.0, -16.0, 16.0, 46.0] if count == 4 else [-40.0, 40.0]
	for offset in offsets:
		var hip := Vector2(256.0 + offset, centre_y + 34.0)
		strokes.append(stroke(PackedVector2Array([hip, hip + Vector2(0.0, 34.0), hip + Vector2(0.0, 68.0)])))
	return strokes


## A torso with arms at the shoulders and legs at the hips -- the shape the biped
## skeleton is authored for.
static func biped() -> Array:
	var strokes: Array = [stroke(oval(256.0, 224.0, 40.0, 52.0))]
	for side in [-1.0, 1.0]:
		var shoulder := Vector2(256.0 + side * 34.0, 206.0)
		strokes.append(stroke(PackedVector2Array([
			shoulder, shoulder + Vector2(side * 26.0, 30.0), shoulder + Vector2(side * 40.0, 62.0)
		])))
	for side in [-1.0, 1.0]:
		var hip := Vector2(256.0 + side * 18.0, 272.0)
		strokes.append(stroke(PackedVector2Array([
			hip, hip + Vector2(side * 6.0, 36.0), hip + Vector2(side * 10.0, 74.0)
		])))
	return strokes


## The same biped with no arms drawn. The case that exposed the arm bones capturing
## leg ink: nothing in the drawing belongs to an arm, so if the arm bones still win
## the legs they drag them in the opposite phase and the legs shear.
static func biped_legs_only() -> Array:
	var strokes: Array = [stroke(oval(256.0, 224.0, 40.0, 52.0))]
	for side in [-1.0, 1.0]:
		var hip := Vector2(256.0 + side * 18.0, 272.0)
		strokes.append(stroke(PackedVector2Array([
			hip, hip + Vector2(side * 6.0, 36.0), hip + Vector2(side * 10.0, 74.0)
		])))
	return strokes


static func oval(cx: float, cy: float, rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(17):
		var angle := TAU * float(index) / 16.0
		points.append(Vector2(cx + cos(angle) * rx, cy + sin(angle) * ry))
	return points


static func stroke(points: PackedVector2Array) -> Dictionary:
	return {"points": points, "width": 8.0, "color": Color.BLACK}
