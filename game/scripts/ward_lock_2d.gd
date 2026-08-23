class_name WardLock2D
extends Node2D
## The padlock on Lola's baul, and Node 3's Pragmatist route.
##
## CLASSIFICATION IS NOT THE PUZZLE. The recogniser only gets the player through the door:
## once it accepts `key` at threshold, this measures THEIR OWN STROKES against the ward
## slot -- how many bits they drew, how deep, and how long the blade is against its width.
## A key that is recognisably a key but the wrong shape turns partway and stops.
##
## This is a geometric test on the vector data, NOT a CNN function, and the distinction
## matters beyond the code: the model recognises a CLASS, it has no opinion about whether
## a particular key fits a particular lock. Nothing in any chapter should describe the
## model as recognising a *specific* key. It is also the level's clearest demonstration of
## the thesis's own claim that the player's strokes ARE the entity -- the drawing is not a
## token standing in for a key, it is the key, and its shape is load-bearing.
##
## NOBODY FAILS PERMANENTLY. Each attempt draws more of the ward on the canvas as a guide,
## and the third opens the lock whatever was drawn. A tutorial level cannot have a dead end
## behind a shape the player cannot picture.

signal turned(result: Dictionary)
signal opened()

## What the slot wants. Ratios rather than sizes, because the player draws at whatever
## scale they like and a key is the right shape or it is not.
@export var required_bits: int = 3
## How far the teeth stand off the blade, as a fraction of blade length.
@export var required_bit_depth := 0.13
## How long the blade is against how thick, which is what separates a key from a comb.
@export var required_aspect := 7.0

## Widened on each attempt: the second try is judged more kindly than the first.
@export var tolerances: Array[float] = [0.35, 0.6]
@export var max_attempts: int = 3

var _attempts := 0
var _open := false


func is_open() -> bool:
	return _open


func attempts_made() -> int:
	return _attempts


## Offer a drawn key to the lock. Returns
## { opens, attempt, reason, measured, revealed, forced }.
func try_key(strokes: Array) -> Dictionary:
	if _open:
		return {"opens": true, "attempt": _attempts, "reason": "already open",
			"measured": {}, "revealed": 1.0, "forced": false}

	_attempts += 1
	var measured := measure(strokes)
	var index: int = mini(_attempts - 1, tolerances.size() - 1)
	var tolerance: float = tolerances[index]
	var reason := _mismatch(measured, tolerance)

	# The third turn opens it whatever was drawn. Three tries at a shape nobody described
	# is enough, and being locked out of the level by a padlock is not a lesson.
	var forced := reason != "" and _attempts >= max_attempts
	var opens := reason == "" or forced

	var result := {
		"opens": opens,
		"attempt": _attempts,
		"reason": "" if opens and not forced else reason,
		"measured": measured,
		# How much of the ward is now drawn on the canvas. Each failure shows more of the
		# shape, so the guide is earned rather than given.
		"revealed": clampf(float(_attempts) / float(max_attempts), 0.0, 1.0),
		"forced": forced,
	}
	turned.emit(result)
	if opens:
		_open = true
		opened.emit()
	return result


## Which property is wrong, or "" if the key fits. Bits first: a wrong tooth count is the
## thing a player can actually see and change.
func _mismatch(measured: Dictionary, tolerance: float) -> String:
	var bits := int(measured.get("bits", 0))
	if absi(bits - required_bits) > (1 if tolerance > 0.4 else 0):
		return "bits"
	var depth := float(measured.get("bit_depth", 0.0))
	if absf(depth - required_bit_depth) > required_bit_depth * tolerance:
		return "depth"
	var aspect := float(measured.get("aspect", 0.0))
	if absf(aspect - required_aspect) > required_aspect * tolerance:
		return "aspect"
	return ""


## Measure a drawn key: how many teeth, how deep, how long against thick.
##
## The blade is taken as the longer side of the drawing's bounding box, and the teeth as
## excursions away from it. Crude next to a real shape descriptor, and deliberately so --
## it has to agree with what a person thinks they drew, and a person counts teeth.
static func measure(strokes: Array) -> Dictionary:
	var points: Array[Vector2] = []
	for stroke_value: Variant in strokes:
		var stroke: Dictionary = stroke_value
		for point_value: Variant in stroke.get("points", PackedVector2Array()):
			points.append(point_value)
	if points.size() < 4:
		return {"bits": 0, "bit_depth": 0.0, "aspect": 0.0, "blade": 0.0}

	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	var horizontal := bounds.size.x >= bounds.size.y
	var blade: float = bounds.size.x if horizontal else bounds.size.y
	var thickness: float = bounds.size.y if horizontal else bounds.size.x
	if blade <= 0.001:
		return {"bits": 0, "bit_depth": 0.0, "aspect": 0.0, "blade": 0.0}

	# WHERE THE BLADE IS, and this is the part that has to be right. Taking the spine as
	# the bounding box's centre reads a key as ONE tooth: the teeth are all on one side, so
	# the centre line sits halfway up them and every slice measures as an excursion. The
	# blade is where the ink actually is, so the spine is the MEDIAN of the across
	# coordinates -- most of what a person draws is shaft.
	var across_all: Array[float] = []
	for point in points:
		across_all.append(point.y if horizontal else point.x)
	across_all.sort()
	var spine: float = across_all[across_all.size() / 2]

	# Walk the blade in slices and record how far the ink strays from the spine in each.
	const SLICES := 28
	var profile: Array[float] = []
	profile.resize(SLICES)
	profile.fill(0.0)
	for point in points:
		var along: float = (point.x - bounds.position.x) if horizontal \
			else (point.y - bounds.position.y)
		var across: float = absf((point.y if horizontal else point.x) - spine)
		var slice: int = clampi(int(along / blade * float(SLICES)), 0, SLICES - 1)
		profile[slice] = maxf(profile[slice], across)

	var deepest := 0.0
	for value in profile:
		deepest = maxf(deepest, value)

	# Relative to the deepest excursion rather than to the drawing's thickness: a tooth is
	# a tooth because it stands out from the shaft, not because it is a particular size.
	var threshold := deepest * 0.45
	var bits := 0
	var inside := false
	for value in profile:
		if value > threshold and not inside:
			inside = true
			bits += 1
		elif value <= threshold:
			inside = false

	return {
		"bits": bits,
		"bit_depth": deepest / blade,
		"aspect": blade / maxf(1.0, thickness),
		"blade": blade,
	}
