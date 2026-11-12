class_name FanBlades
extends RefCounted
## Which of the strokes of a drawn fan are its blades, and the hub they turn about.
##
## Kent: "when i draw a fan ... it should like spin if its possible." It is the player's own
## strokes that spin, so this only ever CHOOSES strokes -- whole ones, turned rigidly about a
## point (RuntimeRig2D.turn_strokes). It never cuts, joins or redraws one, which is what keeps
## ink integrity a non-question here: every polyline on screen is still exactly a stroke.
##
## Two shapes are read as a rotor, and anything else is not:
##   * A CAGE -- a large, round, closed stroke -- with strokes wholly inside it. The desk fan
##     most people draw: the cage, blades inside, a pole and a base. The blades turn, the cage,
##     pole and base stand still.
##   * Blades RADIATING ALL ROUND a point with no cage -- a pinwheel, a propeller from the front.
##     All round matters: a folding hand fan is ribs radiating from a point too, but over less
##     than half a turn, and spinning it would be a hand fan doing something no hand fan does.
## Neither: `find` returns {} and the fan flutters whole instead (UtilityObject).
##
## Measured in the strokes' own space, and on strokes that are fractions of one drawing, so
## every threshold is a fraction of a size the drawing gives -- never pixels of a screen.

## A cage is at least this share of the drawing's larger side.
const CAGE_MIN_SHARE := 0.3
## Closed: its ends this close, as a share of its own larger side. Drawn circles overlap or fall
## short of themselves; a quarter of the width is still a circle, a C is not.
const CAGE_CLOSURE := 0.25
## Round: the narrower side at least this share of the wider.
const CAGE_ASPECT := 0.6
## A ring rather than a filled scribble: points this close to one radius, on average.
const CAGE_RING_SPREAD := 0.25
## Inside the cage: every point within this many radii of its middle (a blade tip poking past
## the wire is still a blade).
const INSIDE := 1.15
## A blade reaches this close to the hub, in radii; a hub cap is no wider than this.
const REACHES_HUB := 0.45
## Radiating: a stroke's nearest point within this share of the drawing's larger side of the hub.
const RADIATE_TOLERANCE := 0.12
## Radiating blades go all round: no gap between neighbouring blades wider than this.
const LARGEST_GAP := 2.6
const MIN_RADIATING := 3


## {"hub": Vector2, "blades": PackedInt32Array, "radius": float} in the strokes' space, or {}.
## `strokes` is the skin's vector stroke list (each {points, ...}).
static func find(strokes: Array) -> Dictionary:
	var paths: Array[PackedVector2Array] = []
	for stroke_value in strokes:
		paths.append(PackedVector2Array((stroke_value as Dictionary).get("points", PackedVector2Array())))
	var whole := _bounds_of_all(paths)
	var side := maxf(whole.size.x, whole.size.y)
	if paths.size() < 2 or side <= 0.0:
		return {}
	var rotor := _caged(paths, side)
	if rotor.is_empty():
		rotor = _radiating(paths, side)
	return rotor


static func _caged(paths: Array[PackedVector2Array], side: float) -> Dictionary:
	var cage := -1
	var cage_area := 0.0
	for index in range(paths.size()):
		var points := paths[index]
		if points.size() < 6:
			continue
		var box := _bounds(points)
		var wide := maxf(box.size.x, box.size.y)
		var narrow := minf(box.size.x, box.size.y)
		if wide < side * CAGE_MIN_SHARE or narrow < wide * CAGE_ASPECT:
			continue
		if points[0].distance_to(points[points.size() - 1]) > wide * CAGE_CLOSURE:
			continue
		if not _is_ring(points, box):
			continue
		if box.get_area() > cage_area:
			cage = index
			cage_area = box.get_area()
	if cage < 0:
		return {}
	var cage_box := _bounds(paths[cage])
	var middle := cage_box.get_center()
	var radius := (cage_box.size.x + cage_box.size.y) * 0.25
	var blades := PackedInt32Array()
	var reaches_in := false
	for index in range(paths.size()):
		if index == cage or paths[index].is_empty():
			continue
		var inside := true
		for point in paths[index]:
			if point.distance_to(middle) > radius * INSIDE:
				inside = false
				break
		if not inside:
			continue
		blades.append(index)
		reaches_in = reaches_in or _nearest(paths[index], middle).distance_to(middle) <= radius * REACHES_HUB
	# Something inside that comes in toward the middle. A cage with only a rim's worth of
	# decoration inside it has nothing that would read as turning.
	if blades.is_empty() or not reaches_in:
		return {}
	return {"hub": _hub(paths, blades, middle, radius), "blades": blades, "radius": radius}


## Where the blades actually meet, which is rarely the exact middle of a hand-drawn cage: the
## middle of a small hub cap if there is one, otherwise where the blades' inner ends average out.
## Turning about the cage's middle instead would swing the blades' meeting point round in a
## small circle -- a wobble, on top of the spin.
static func _hub(paths: Array[PackedVector2Array], blades: PackedInt32Array, middle: Vector2,
		radius: float) -> Vector2:
	for index in blades:
		var points := paths[index]
		var box := _bounds(points)
		var closed := points.size() >= 4 \
			and points[0].distance_to(points[points.size() - 1]) <= maxf(box.size.x, box.size.y) * CAGE_CLOSURE
		if closed and maxf(box.size.x, box.size.y) <= radius * REACHES_HUB \
				and box.get_center().distance_to(middle) <= radius * REACHES_HUB:
			return box.get_center()
	var sum := Vector2.ZERO
	var count := 0
	for index in blades:
		var near := _nearest(paths[index], middle)
		if near.distance_to(middle) <= radius * REACHES_HUB:
			sum += near
			count += 1
	return sum / float(count) if count > 0 else middle


static func _radiating(paths: Array[PackedVector2Array], side: float) -> Dictionary:
	var tolerance := side * RADIATE_TOLERANCE
	var centre := _bounds_of_all(paths).get_center()
	# Candidate hubs: every stroke's ends. A blade drawn out from the middle starts or ends there.
	var best := Vector2.INF
	var best_count := 0
	for path in paths:
		if path.is_empty():
			continue
		for candidate in [path[0], path[path.size() - 1]]:
			var count := 0
			for other in paths:
				if not other.is_empty() and _nearest(other, candidate).distance_to(candidate) <= tolerance:
					count += 1
			if count > best_count or (count == best_count and best != Vector2.INF
					and candidate.distance_to(centre) < best.distance_to(centre)):
				best = candidate
				best_count = count
	if best_count < MIN_RADIATING:
		return {}
	var touching := PackedInt32Array()
	for index in range(paths.size()):
		if not paths[index].is_empty() and _nearest(paths[index], best).distance_to(best) <= tolerance:
			touching.append(index)
	# A stroke that runs from the hub to something else -- a pole down to a base -- holds the
	# rotor up; it does not turn with it.
	var blades := PackedInt32Array()
	for index in touching:
		var far := _farthest(paths[index], best)
		var connects := false
		for other in range(paths.size()):
			if other == index or touching.has(other) or paths[other].is_empty():
				continue
			if _nearest(paths[other], far).distance_to(far) <= tolerance:
				connects = true
				break
		if not connects:
			blades.append(index)
	if blades.size() < MIN_RADIATING or _largest_gap(paths, blades, best) > LARGEST_GAP:
		return {}
	var radius := 0.0
	for index in blades:
		radius = maxf(radius, _farthest(paths[index], best).distance_to(best))
	return {"hub": best, "blades": blades, "radius": radius}


## The widest angle between neighbouring blades, seen from the hub: small when they go all round.
static func _largest_gap(paths: Array[PackedVector2Array], blades: PackedInt32Array, hub: Vector2) -> float:
	var angles: Array[float] = []
	for index in blades:
		angles.append((_farthest(paths[index], hub) - hub).angle())
	angles.sort()
	var widest := 0.0
	for index in range(angles.size()):
		var next := angles[(index + 1) % angles.size()] + (TAU if index == angles.size() - 1 else 0.0)
		widest = maxf(widest, next - angles[index])
	return widest


static func _is_ring(points: PackedVector2Array, box: Rect2) -> bool:
	var middle := box.get_center()
	var radius := (box.size.x + box.size.y) * 0.25
	if radius <= 0.0:
		return false
	var spread := 0.0
	for point in points:
		spread += absf(point.distance_to(middle) - radius)
	return spread / float(points.size()) / radius <= CAGE_RING_SPREAD


## The point on the polyline nearest `to` -- along its segments, not only at its points: a pole
## drawn as one long segment touches the base it stands on in the middle of the base's line.
static func _nearest(points: PackedVector2Array, to: Vector2) -> Vector2:
	var best := points[0]
	for index in range(1, points.size()):
		var on := Geometry2D.get_closest_point_to_segment(to, points[index - 1], points[index])
		if on.distance_squared_to(to) < best.distance_squared_to(to):
			best = on
	return best


static func _farthest(points: PackedVector2Array, from: Vector2) -> Vector2:
	var best := points[0]
	for point in points:
		if point.distance_squared_to(from) > best.distance_squared_to(from):
			best = point
	return best


static func _bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var box := Rect2(points[0], Vector2.ZERO)
	for point in points:
		box = box.expand(point)
	return box


static func _bounds_of_all(paths: Array[PackedVector2Array]) -> Rect2:
	var box := Rect2()
	var started := false
	for path in paths:
		if path.is_empty():
			continue
		box = box.merge(_bounds(path)) if started else _bounds(path)
		started = true
	return box
