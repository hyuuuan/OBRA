extends RefCounted
## Six-leg, open-hub spider fixtures based on the project's drawing reference.
## Every variant describes the same ink topology with different stroke ownership
## and direction so anatomy inference cannot depend on stroke order.


static func separate_legs() -> Array:
	var strokes: Array = _hub_strokes()
	for path in _leg_paths():
		strokes.append(_stroke(path))
	return strokes


static func paired_through_body() -> Array:
	var legs := _leg_paths()
	var strokes: Array = _hub_strokes()
	# Pair matching side ranks into continuous strokes crossing the open hub.
	for rank in range(3):
		var left: PackedVector2Array = legs[rank]
		var right: PackedVector2Array = legs[rank + 3]
		strokes.append(_stroke(PackedVector2Array([
			left[2], left[1], left[0],
			Vector2(256.0, 256.0),
			right[0], right[1], right[2]
		])))
	return strokes


static func reversed_shuffled() -> Array:
	var source := separate_legs()
	var order := [6, 2, 4, 0, 7, 3, 1, 5]
	var strokes: Array = []
	for source_index in order:
		var original: PackedVector2Array = source[source_index].get("points", PackedVector2Array())
		var reversed := PackedVector2Array()
		for point_index in range(original.size() - 1, -1, -1):
			reversed.append(original[point_index])
		strokes.append(_stroke(reversed))
	return strokes


static func split_leg_segments() -> Array:
	var strokes := _hub_strokes()
	for path in _leg_paths():
		strokes.append(_stroke(PackedVector2Array([path[0], path[1]])))
		strokes.append(_stroke(PackedVector2Array([path[1], path[2]])))
	return strokes


static func straight_leg_segments() -> Array:
	var strokes := _hub_strokes()
	var straight_legs: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(236.0, 252.0), Vector2(160.0, 205.0)]),
		PackedVector2Array([Vector2(229.0, 256.0), Vector2(155.0, 286.0)]),
		PackedVector2Array([Vector2(239.0, 261.0), Vector2(181.0, 331.0)]),
		PackedVector2Array([Vector2(278.0, 251.0), Vector2(351.0, 204.0)]),
		PackedVector2Array([Vector2(286.0, 256.0), Vector2(359.0, 288.0)]),
		PackedVector2Array([Vector2(277.0, 261.0), Vector2(335.0, 333.0)])
	]
	for path in straight_legs:
		strokes.append(_stroke(path))
	return strokes


static func self_crossing_hub_leg() -> Array:
	var legs := _leg_paths()
	# The first leg reconnects to an earlier section of its own stroke. Its actual
	# root is recoverable only if non-adjacent same-path intersections are welded;
	# broad same-path proximity welding would incorrectly shortcut the whole leg.
	var strokes: Array = [_stroke(PackedVector2Array([
		Vector2(222.0, 256.0), Vector2(298.0, 256.0), Vector2(310.0, 238.0),
		Vector2(236.0, 256.0), legs[0][1], legs[0][2]
	]))]
	for leg_index in range(1, legs.size()):
		strokes.append(_stroke(legs[leg_index]))
	return strokes


static func variants() -> Array:
	return [
		{"name": "separate", "strokes": separate_legs()},
		{"name": "paired_through_body", "strokes": paired_through_body()},
		{"name": "reversed_shuffled", "strokes": reversed_shuffled()}
	]


static func variable_leg_count(count: int) -> Array:
	var base := _leg_paths()
	var selected: Array[PackedVector2Array] = []
	match clampi(count, 4, 8):
		4:
			selected = [base[1], base[2], base[4], base[5]]
		5:
			selected = [base[0], base[1], base[2], base[4], base[5]]
		6:
			selected = base
		7:
			selected = [_extra_left_leg(), base[0], base[1], base[2], base[3], base[4], base[5]]
		8:
			selected = [_extra_left_leg(), base[0], base[1], base[2], _extra_right_leg(), base[3], base[4], base[5]]
	var strokes := _hub_strokes()
	for path in selected:
		strokes.append(_stroke(path))
	return strokes


static func _hub_strokes() -> Array:
	return [
		_stroke(PackedVector2Array([
			Vector2(222.0, 254.0), Vector2(238.0, 260.0),
			Vector2(256.0, 256.0), Vector2(278.0, 259.0), Vector2(298.0, 251.0)
		])),
		_stroke(PackedVector2Array([
			Vector2(236.0, 249.0), Vector2(252.0, 262.0),
			Vector2(270.0, 261.0), Vector2(284.0, 250.0)
		]))
	]


static func _leg_paths() -> Array:
	return [
		# Left side, ranked from upper to lower root/sole geometry.
		PackedVector2Array([Vector2(236.0, 252.0), Vector2(196.0, 225.0), Vector2(154.0, 266.0)]),
		PackedVector2Array([Vector2(229.0, 256.0), Vector2(184.0, 263.0), Vector2(159.0, 311.0)]),
		PackedVector2Array([Vector2(239.0, 261.0), Vector2(199.0, 286.0), Vector2(181.0, 331.0)]),
		# Right side mirrors the anatomy without requiring pixel-perfect symmetry.
		PackedVector2Array([Vector2(278.0, 251.0), Vector2(318.0, 221.0), Vector2(351.0, 257.0)]),
		PackedVector2Array([Vector2(286.0, 256.0), Vector2(331.0, 263.0), Vector2(351.0, 313.0)]),
		PackedVector2Array([Vector2(277.0, 261.0), Vector2(318.0, 287.0), Vector2(335.0, 333.0)])
	]


static func _extra_left_leg() -> PackedVector2Array:
	return PackedVector2Array([Vector2(242.0, 250.0), Vector2(210.0, 211.0), Vector2(170.0, 220.0)])


static func _extra_right_leg() -> PackedVector2Array:
	return PackedVector2Array([Vector2(273.0, 249.0), Vector2(305.0, 208.0), Vector2(344.0, 217.0)])


static func _stroke(points: PackedVector2Array) -> Dictionary:
	return {"points": points, "width": 8.0, "color": Color.BLACK}
