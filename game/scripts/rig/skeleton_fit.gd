class_name SkeletonFit
extends RefCounted
## Fits a class's skeleton to the drawing actually made: the class says WHAT parts a creature
## has, the ink says WHERE they are.
##
## Kent, 2026-10-24: "if i draw a bird, sometimes it does not recognize the wing to flap... its
## not just birds, some creatures as well when they are drawn differently." Until now every
## bone sat at fixed fractions of the drawing's bounding box, authored for ONE way of drawing
## each archetype: a bird seen from the front, every animal facing right, four legs under every
## walker. People draw birds and bees from the side, fish and horses facing left as often as
## right, pigs and monkeys as just a face -- and then the "wings" flapped a bird's head and tail
## while its wing sat still, and a left-facing horse wagged its head as its tail (measured by
## tests/run_rig_fit_probe.gd: 20 of 21 such drawings wrong).
##
## So the drawing is read, not assumed:
##   1. The BODY is the closed stroke around the middle of the drawing (the largest one, so a
##      turtle's shell and not its pattern). Thin protrusions of that outline -- a beak, a tail
##      drawn in the same stroke -- are trimmed off by a morphological opening. A drawing with
##      no closed body (a seagull "M", a stick figure) gets a small disc at its middle instead.
##   2. Each other STROKE's ink outside the body is a PART (players draw a limb as a stroke; a
##      stroke that leaves the body twice, like a U for two legs, is two parts): where it joins
##      the body (its attach point), which way it runs, how far it reaches (its tip).
##   3. Each way of drawing the class (the archetype's views: a bird from the front or the side)
##      is tried as drawn and mirrored, the parts are matched to the bones that may move them
##      by direction and position, and the reading that explains the drawing best wins. Extra
##      parts of a repeatable kind (an ant's six legs, an octopus's arms) get bones of their own;
##      bones the drawing has no part for are dropped, so nothing that is not a limb swings.
##   4. A matched bone pivots where its part joins the body and reaches to its tip, and only
##      that part's ink follows it (SkinBinding reads the regions) -- body ink cannot be thrown.
##
## Bones that are not matched to parts (a fish's spine, the root) keep their authored places,
## mirrored with the reading, and are weighted as before.

const GRID := 72
const PAD := 3
## A stroke counts as closed if its ends are this close, as a share of its own size.
const CLOSED_GAP := 0.3
## No closed body near the middle: a disc this share of the longest side stands in for it.
const STICK_CORE := 0.12
## A closed stroke this near the middle (share of the longest side) can still be the body.
const BODY_REACH := 0.18
## The opening that trims thin protrusions off the body, as a share of its thickest point.
const OPEN_SHARE := 0.4
## Parts smaller than this are specks (eyes, dots), not parts.
const MIN_LENGTH := 0.05
const MIN_MASS := 0.004
## Matching. Directions and reach are compared in the drawing's own proportions.
const MAX_TURN_DEG := 75.0
const TURN_SCALE_DEG := 55.0
const REACH_SCALE := 0.35
const MAX_REACH := 0.65
## A "thin" bone (leg, tail, tentacle) refuses a part fatter than this, width over length.
## Only a closed stroke or a piece of the body's own outline can be fat: an open stroke is a line.
const THIN := 0.32

const INTERIOR_PENALTY := 0.45
const UNEXPLAINED := 1.2
## A match is refused when it costs this many times more than leaving the part and the bone
## unmatched -- a bird's legs are not two more tails, a butterfly's antennae not two more wings.
const WORSE_THAN_NONE := 2.5
## In a symmetric view (a bird from the front), a left/right pair matched to parts unlike each
## other pays this much per unit of difference: a side-on bird's head and tail are not wings.
const ASYMMETRY := 1.5
const DEFAULT_EXPECT := 0.2


## What each fitted bone owns, for SkinBinding: a label grid over the drawing.
class Regions extends RefCounted:
	var origin := Vector2.ZERO
	var cell := 1.0
	var width := 0
	var height := 0
	var labels := PackedInt32Array()     ## slot per cell, -1 for none
	var names: Array[String] = []        ## bone name per slot

	func slot_at(point: Vector2) -> int:
		var x := int(floor((point.x - origin.x) / cell))
		var y := int(floor((point.y - origin.y) / cell))
		if x < 0 or y < 0 or x >= width or y >= height:
			return -1
		return labels[y * width + x]


class Part extends RefCounted:
	var cells := PackedInt32Array()
	var stroke := -1
	var attach := Vector2.ZERO   ## rig space
	var tip := Vector2.ZERO
	var length := 0.0            ## rig px
	var mass := 0.0              ## share of all the ink
	var width_ratio := 0.0
	var interior := false
	var joined := false                  ## touches the body (else it hangs off another part)
	var polygon := PackedVector2Array()  ## the stroke, when the part is a whole closed stroke


var _bounds: Rect2
var _longest := 1.0
var _cell := 1.0
var _origin := Vector2.ZERO
var _w := 0
var _h := 0
var _ink_cells := 0
var _stroke_cells: Array = []        ## PackedInt32Array of ink cells, per stroke
var _core: BitMap
var _core_grown: BitMap
var _core_middle := Vector2.ZERO
var _core_box := Rect2()             ## rig space; where a bone's "attach" [u, v] is measured
var _body_stroke := -1
var _protrusions: Array = []         ## cell lists trimmed off the body's own outline
var _parts: Array[Part] = []
var _inner: Array[Part] = []
var _readings: Array[String] = []


## `skeleton` from SkeletonLibrary.resolve; `strokes` in rig space ({points, width}); `bounds`
## the drawing's bounds as Skeleton2D_Rig will see them. Returns {skeleton, regions, view,
## mirrored, facing, parts, debug}; with nothing to read, the skeleton comes back as authored.
## facing is which way the drawing looks: 1 right, -1 left (a reading that had to be mirrored),
## 0 for a drawing seen from the front or above, which looks no way at all.
static func fit(skeleton: Dictionary, strokes: Array, bounds: Rect2) -> Dictionary:
	var fitter := SkeletonFit.new()
	return fitter._fit(skeleton, strokes, bounds)


func _fit(skeleton: Dictionary, strokes: Array, bounds: Rect2) -> Dictionary:
	var unchanged := {"skeleton": skeleton, "regions": null, "view": "", "mirrored": false, "facing": 0, "parts": 0, "debug": {}}
	if strokes.is_empty() or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return unchanged
	_bounds = Rect2(bounds.position, bounds.size.max(Vector2(4.0, 4.0)))
	_longest = maxf(_bounds.size.x, _bounds.size.y)
	_cell = _longest / float(GRID)
	_origin = _bounds.position - Vector2.ONE * _cell * PAD
	_w = int(ceil(_bounds.size.x / _cell)) + PAD * 2
	_h = int(ceil(_bounds.size.y / _cell)) + PAD * 2
	_raster(strokes)
	_find_body(strokes)
	_find_parts(strokes)

	var best := {}
	_readings.clear()
	for view_value in _views_of(skeleton):
		var view: Dictionary = view_value
		for mirrored in ([false] if bool(view.get("symmetric", false)) else [false, true]):
			var reading := _read(view, mirrored)
			_readings.append("%s%s %.2f %s" % [view.get("name", ""), " mirrored" if mirrored else "", float(reading["cost"]), reading.get("why", "")])
			if best.is_empty() or float(reading["cost"]) < float(best["cost"]) - 0.0001:
				best = reading
	if best.is_empty():
		return unchanged
	var fitted := skeleton.duplicate()
	fitted.erase("views")
	for field: String in (best["view"] as Dictionary).keys():
		if field not in ["name", "bones", "symmetric", "comment"]:
			fitted[field] = (best["view"] as Dictionary)[field]
	fitted["bones"] = best["bones"]
	fitted["view"] = String((best["view"] as Dictionary).get("name", ""))
	fitted["mirrored"] = bool(best["mirrored"])
	fitted["symmetric"] = bool((best["view"] as Dictionary).get("symmetric", false))
	return {
		"skeleton": fitted,
		"regions": best["regions"],
		"view": fitted["view"],
		"mirrored": best["mirrored"],
		"facing": 0 if fitted["symmetric"] else (-1 if bool(best["mirrored"]) else 1),
		"parts": _parts.size(),
		"debug": _debug(best),
	}


# --- reading the ink ----------------------------------------------------------

func _raster(strokes: Array) -> void:
	var all := PackedByteArray()
	all.resize(_w * _h)
	for stroke_value in strokes:
		var stroke: Dictionary = stroke_value
		var points := PackedVector2Array(stroke.get("points", PackedVector2Array()))
		var radius := maxf(0.6, float(stroke.get("width", 2.0)) * 0.5 / _cell)
		var marks := PackedByteArray()
		marks.resize(_w * _h)
		var cells := PackedInt32Array()
		_stamp_line(marks, cells, points, radius)
		_stroke_cells.append(cells)
		for i in cells:
			all[i] = 1
	_ink_cells = maxi(1, all.count(1))


## Marks every cell within `radius` cells of the polyline, appending newly marked ones to `cells`.
func _stamp_line(marks: PackedByteArray, cells: PackedInt32Array, points: PackedVector2Array, radius: float) -> void:
	if points.is_empty():
		return
	if points.size() == 1:
		_stamp(marks, cells, _to_grid(points[0]), radius)
		return
	for i in range(points.size() - 1):
		var a := _to_grid(points[i])
		var b := _to_grid(points[i + 1])
		var steps := maxi(1, int(ceil(a.distance_to(b) * 2.0)))
		for k in range(steps + 1):
			_stamp(marks, cells, a.lerp(b, float(k) / float(steps)), radius)


func _stamp(marks: PackedByteArray, cells: PackedInt32Array, at: Vector2, radius: float) -> void:
	var reach := int(ceil(radius))
	var cx := int(floor(at.x))
	var cy := int(floor(at.y))
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if dx * dx + dy * dy > radius * radius + 0.5:
				continue
			var x := cx + dx
			var y := cy + dy
			if x < 0 or y < 0 or x >= _w or y >= _h:
				continue
			var i := y * _w + x
			if marks[i] == 0:
				marks[i] = 1
				cells.append(i)


func _find_body(strokes: Array) -> void:
	var middle := _bounds.get_center()
	var best_area := 0.0
	var nearest := INF
	var nearest_index := -1
	for index in range(strokes.size()):
		var points := PackedVector2Array((strokes[index] as Dictionary).get("points", PackedVector2Array()))
		if not _is_closed(points):
			continue
		var area := absf(_polygon_area(points))
		if Geometry2D.is_point_in_polygon(middle, points):
			if area > best_area:
				best_area = area
				_body_stroke = index
			continue
		var distance := _distance_to_polyline(middle, points)
		if distance < nearest:
			nearest = distance
			nearest_index = index
	if _body_stroke < 0 and nearest_index >= 0 and nearest <= BODY_REACH * _longest:
		_body_stroke = nearest_index

	_core = BitMap.new()
	_core.create(Vector2i(_w, _h))
	if _body_stroke >= 0:
		var body := _filled_stroke(PackedVector2Array((strokes[_body_stroke] as Dictionary).get("points")),
			_stroke_cells[_body_stroke])
		_core = _opened(body)
		for y in range(_h):
			for x in range(_w):
				if body.get_bit(x, y) and not _core.get_bit(x, y):
					body.set_bit(x, y, true)
				else:
					body.set_bit(x, y, false)
		_protrusions = _components(body, true)
	else:
		var centre := _nearest_ink_cell(_to_grid(middle))
		var marks := PackedByteArray()
		marks.resize(_w * _h)
		var cells := PackedInt32Array()
		_stamp(marks, cells, centre, STICK_CORE * GRID)
		for i in cells:
			_core.set_bit(i % _w, i / _w, true)
	_core_middle = _centre_of(_core)
	var low := Vector2(INF, INF)
	var high := -low
	for y in range(_h):
		for x in range(_w):
			if _core.get_bit(x, y):
				low = low.min(Vector2(x, y))
				high = high.max(Vector2(x + 1, y + 1))
	_core_box = Rect2(_to_rig(low), (high - low) * _cell) if low.x < INF else Rect2(_bounds.get_center(), Vector2.ONE)
	_core_grown = _copy(_core)
	_core_grown.grow_mask(1, Rect2i(0, 0, _w, _h))


## A closed stroke's ink and everything it encloses.
func _filled_stroke(points: PackedVector2Array, cells: PackedInt32Array) -> BitMap:
	var wall := PackedByteArray()
	wall.resize(_w * _h)
	for i in cells:
		wall[i] = 1
	# Close the gap between its ends so it holds water.
	var closing := PackedInt32Array()
	_stamp_line(wall, closing, PackedVector2Array([points[points.size() - 1], points[0]]), 1.0)
	var outside := PackedByteArray()
	outside.resize(_w * _h)
	var queue := PackedInt32Array()
	for x in range(_w):
		for y in [0, _h - 1]:
			_flood_seed(wall, outside, queue, y * _w + x)
	for y in range(_h):
		for x in [0, _w - 1]:
			_flood_seed(wall, outside, queue, y * _w + x)
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		var x := i % _w
		if x > 0:
			_flood_seed(wall, outside, queue, i - 1)
		if x < _w - 1:
			_flood_seed(wall, outside, queue, i + 1)
		if i >= _w:
			_flood_seed(wall, outside, queue, i - _w)
		if i < _w * (_h - 1):
			_flood_seed(wall, outside, queue, i + _w)
	var inside := BitMap.new()
	inside.create(Vector2i(_w, _h))
	for i in range(_w * _h):
		if outside[i] == 0:
			inside.set_bit(i % _w, i / _w, true)
	return inside


func _flood_seed(wall: PackedByteArray, outside: PackedByteArray, queue: PackedInt32Array, i: int) -> void:
	if outside[i] != 0 or wall[i] != 0:
		return
	outside[i] = 1
	queue.append(i)


## Trims thin protrusions (a beak, a tail drawn in the body's own stroke) off a body by an
## opening, keeping the piece around the middle.
func _opened(body: BitMap) -> BitMap:
	var thickest := _thickness(body)
	if thickest < 3:
		return body
	var radius := maxi(1, int(floor(thickest * OPEN_SHARE)))
	var opened := _copy(body)
	opened.grow_mask(-radius, Rect2i(0, 0, _w, _h))
	opened.grow_mask(radius, Rect2i(0, 0, _w, _h))
	for y in range(_h):
		for x in range(_w):
			if opened.get_bit(x, y) and not body.get_bit(x, y):
				opened.set_bit(x, y, false)
	var pieces := _components(opened, false)
	if pieces.size() <= 1:
		return opened if not pieces.is_empty() else body
	var middle := _to_grid(_bounds.get_center())
	var keep: PackedInt32Array = pieces[0]
	var closest := INF
	for piece_value in pieces:
		var piece: PackedInt32Array = piece_value
		for i in piece:
			var d := Vector2(i % _w, i / _w).distance_squared_to(middle)
			if d < closest:
				closest = d
				keep = piece
	var out := BitMap.new()
	out.create(Vector2i(_w, _h))
	for i in keep:
		out.set_bit(i % _w, i / _w, true)
	return out


## The half-thickness of the thickest place, in cells: how many erosions it survives.
func _thickness(map: BitMap) -> int:
	var probe := _copy(map)
	var steps := 0
	while probe.get_true_bit_count() > 0 and steps < GRID:
		probe.grow_mask(-1, Rect2i(0, 0, _w, _h))
		steps += 1
	return maxi(0, steps - 1)


func _find_parts(strokes: Array) -> void:
	for piece_value in _protrusions:
		var part := _part_from(piece_value, _body_stroke, PackedVector2Array())
		if part != null:
			_parts.append(part)
	var deep := _copy(_core)
	deep.grow_mask(-1, Rect2i(0, 0, _w, _h))
	var specks: Array[int] = []
	for index in range(strokes.size()):
		if index == _body_stroke:
			continue
		var points := PackedVector2Array((strokes[index] as Dictionary).get("points", PackedVector2Array()))
		var cells: PackedInt32Array = _stroke_cells[index]
		var outside := PackedInt32Array()
		var inside := PackedInt32Array()
		for i in cells:
			var x := i % _w
			var y := i / _w
			if not _core_grown.get_bit(x, y):
				outside.append(i)
			elif deep.get_bit(x, y):
				inside.append(i)
		var made := false
		var pieces := _components_of(outside)
		for piece_value in pieces:
			var piece: PackedInt32Array = piece_value
			# A whole closed stroke (a wing loop, a head) is as fat as the area it encloses.
			var whole := pieces.size() == 1 and piece.size() >= cells.size() * 0.5 and _is_closed(points)
			var part := _part_from(piece, index, points if whole else PackedVector2Array())
			if part != null:
				_parts.append(part)
				made = true
		# Ink drawn INSIDE the body by another stroke -- a wing drawn on a bird's side. Only
		# bones that allow it ever take one of these.
		if inside.size() >= cells.size() * 0.6 and float(inside.size()) / float(_ink_cells) >= MIN_MASS * 0.5:
			var inner := Part.new()
			inner.cells = inside
			inner.stroke = index
			inner.interior = true
			inner.mass = float(inside.size()) / float(_ink_cells)
			inner.attach = _to_rig(_centre_of_cells(inside))
			inner.tip = inner.attach
			_inner.append(inner)
			made = true
		if not made:
			specks.append(index)
	_merge_hangers()
	# A speck inside a part (an eye in a head, a pattern on a wing) moves with that part.
	for index in specks:
		var cells: PackedInt32Array = _stroke_cells[index]
		if cells.is_empty():
			continue
		var at := _to_rig(_centre_of_cells(cells))
		for part in _parts:
			if not part.polygon.is_empty() and Geometry2D.is_point_in_polygon(at, part.polygon):
				part.cells.append_array(cells)
				break


## A part that does not touch the body but touches another part (a beak on a head, a trunk, an
## antenna) is part of that one: it moves with it, and is not matched to a bone of its own.
func _merge_hangers() -> void:
	for _pass in range(3):
		var label := {}
		for index in range(_parts.size()):
			for i in _parts[index].cells:
				label[i] = index
		var merged := false
		for index in range(_parts.size() - 1, -1, -1):
			var part := _parts[index]
			if part.joined:
				continue
			var host := -1
			for i in part.cells:
				var x := i % _w
				var y := i / _w
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var j := (y + dy) * _w + (x + dx)
						if label.has(j) and int(label[j]) != index:
							host = int(label[j])
							break
					if host >= 0:
						break
				if host >= 0:
					break
			if host < 0:
				continue
			_parts[host].cells.append_array(part.cells)
			_parts[host].mass += part.mass
			_parts.remove_at(index)
			merged = true
			break
		if not merged:
			return


func _part_from(cells: PackedInt32Array, stroke: int, polygon: PackedVector2Array) -> Part:
	var mass := float(cells.size()) / float(_ink_cells)
	if mass < MIN_MASS:
		return null
	var part := Part.new()
	part.cells = cells
	part.stroke = stroke
	part.mass = mass
	part.polygon = polygon
	var joined := Vector2.ZERO
	var joins := 0
	var nearest := INF
	var nearest_cell := Vector2.ZERO
	for i in cells:
		var x := i % _w
		var y := i / _w
		var touches := false
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + offset.x
			var ny: int = y + offset.y
			if nx >= 0 and ny >= 0 and nx < _w and ny < _h and _core_grown.get_bit(nx, ny):
				touches = true
				break
		if touches:
			joined += Vector2(x + 0.5, y + 0.5)
			joins += 1
		var d := Vector2(x, y).distance_squared_to(_core_middle)
		if d < nearest:
			nearest = d
			nearest_cell = Vector2(x + 0.5, y + 0.5)
	part.joined = joins > 0
	var attach_cell := joined / float(joins) if joins > 0 else nearest_cell
	# It runs from where it joins toward its middle -- not to its farthest corner, which on a
	# fan-shaped part (a fish's tail) points off to one side.
	var heading := _centre_of_cells(cells) - attach_cell
	var tip_cell := _farthest(cells, attach_cell) if heading.length() < 0.5 \
		else _farthest_along(cells, attach_cell, heading.normalized())
	part.attach = _to_rig(attach_cell)
	part.tip = _to_rig(tip_cell)
	part.length = part.attach.distance_to(part.tip)
	if part.length < MIN_LENGTH * _longest:
		return null
	if not polygon.is_empty():
		part.width_ratio = absf(_polygon_area(polygon)) / (part.length * part.length)
	elif stroke == _body_stroke:
		part.width_ratio = float(cells.size()) * _cell * _cell / (part.length * part.length)
	return part


# --- matching the parts to a view's bones -------------------------------------

func _views_of(skeleton: Dictionary) -> Array:
	var views: Array = [{
		"name": String(skeleton.get("view", "default")),
		"bones": skeleton.get("bones", []),
		"symmetric": bool(skeleton.get("symmetric", false)),
	}]
	for view_value in skeleton.get("views", []):
		views.append(view_value)
	return views


func _read(view: Dictionary, mirrored: bool) -> Dictionary:
	var bones: Array = []
	for bone_value in view.get("bones", []):
		bones.append(_mirrored_bone(bone_value as Dictionary, mirrored))
	var fit_bones: Array[int] = []
	for index in range(bones.size()):
		if String((bones[index] as Dictionary).get("fit", "")) in ["appendage", "anchor"]:
			fit_bones.append(index)

	# Every allowed pairing, cheapest first; each bone and each part used once.
	var pairs: Array = []
	var candidates: Array[Part] = []
	candidates.append_array(_parts)
	candidates.append_array(_inner)
	for b in fit_bones:
		for p in range(candidates.size()):
			var priced := _price(bones[b], candidates[p])
			if not priced.is_empty():
				pairs.append([float(priced["cost"]), b, p, priced])
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	# What each part would cost as one more of a repeated kind (another leg), so a one-off bone
	# (a tail) does not take a part that is plainly a leg.
	var as_repeat: Dictionary = {}
	for pair in pairs:
		if bool((bones[int(pair[1])] as Dictionary).get("repeat", false)) and not as_repeat.has(pair[2]):
			as_repeat[pair[2]] = float(pair[0])
	var bone_part: Dictionary = {}
	var part_bone: Dictionary = {}
	var cost := 0.0
	for pair in pairs:
		if bone_part.has(pair[1]) or part_bone.has(pair[2]):
			continue
		if not bool((bones[int(pair[1])] as Dictionary).get("repeat", false)) \
				and float(as_repeat.get(pair[2], INF)) < float(pair[0]):
			continue
		# A match far worse than leaving both alone is no match.
		if float(pair[0]) > WORSE_THAN_NONE * (_unexplained(candidates[int(pair[2])]) \
				+ float((bones[int(pair[1])] as Dictionary).get("expect", DEFAULT_EXPECT))):
			continue
		bone_part[pair[1]] = pair
		part_bone[pair[2]] = pair[1]
		cost += float(pair[0])

	# A part left over of a kind the creature repeats gets a bone of its own.
	var clones: Array = []
	for p in range(_parts.size()):
		if part_bone.has(p):
			continue
		var cheapest: Array = []
		for pair in pairs:
			if int(pair[2]) != p or not bool((bones[int(pair[1])] as Dictionary).get("repeat", false)):
				continue
			cheapest = pair
			break
		if cheapest.is_empty() or float(cheapest[0]) > WORSE_THAN_NONE * _unexplained(_parts[p]):
			cost += _unexplained(_parts[p])
			continue
		part_bone[p] = cheapest[1]
		clones.append(cheapest)
		cost += float(cheapest[0])
	if bool(view.get("symmetric", false)):
		cost += _asymmetry(bones, bone_part, candidates)
	var why: Array[String] = []
	for b in fit_bones:
		if not bone_part.has(b):
			cost += float((bones[b] as Dictionary).get("expect", DEFAULT_EXPECT))
			why.append("%s:none" % (bones[b] as Dictionary).get("name"))
		else:
			why.append("%s:s%d %.2f" % [(bones[b] as Dictionary).get("name"), candidates[int((bone_part[b] as Array)[2])].stroke, float((bone_part[b] as Array)[0])])
	for p in range(_parts.size()):
		if not part_bone.has(p):
			why.append("s%d:unexplained" % _parts[p].stroke)

	return {
		"cost": cost,
		"why": " ".join(why),
		"view": view,
		"mirrored": mirrored,
		"bones": _placed(bones, fit_bones, bone_part, clones),
		"regions": _regions(bones, bone_part, clones, candidates),
	}


## How unlike each other the parts are that a view's left/right pairs took (same role,
## opposite sides): their size and their reach, weighed by ASYMMETRY.
func _asymmetry(bones: Array, bone_part: Dictionary, candidates: Array[Part]) -> float:
	var total := 0.0
	for a in bone_part:
		var left: Dictionary = bones[int(a)]
		if float(left.get("side", 0.0)) >= 0.0:
			continue
		for b in bone_part:
			var right: Dictionary = bones[int(b)]
			if String(right.get("role", "")) != String(left.get("role", "")) \
					or float(right.get("side", 0.0)) <= 0.0 or int(right.get("index", 0)) != int(left.get("index", 0)) + 1 \
					and int(right.get("index", 0)) != int(left.get("index", 0)):
				continue
			var one := candidates[int((bone_part[a] as Array)[2])]
			var two := candidates[int((bone_part[b] as Array)[2])]
			total += ASYMMETRY * (absf(one.mass - two.mass) / maxf(0.0001, one.mass + two.mass) \
				+ absf(one.length - two.length) / maxf(0.0001, one.length + two.length))
			break
	return total


## What a reading pays for a part it gives no bone: more for a bigger part.
func _unexplained(part: Part) -> float:
	return 0.0 if part.interior else UNEXPLAINED * (part.mass * 3.0 + part.length / _longest)


## The cost of `part` moving with `bone`, or {} if the bone may not take it.
func _price(bone: Dictionary, part: Part) -> Dictionary:
	var pivot := _at(bone.get("pivot", [0.5, 0.5]))
	var tip := _at(bone.get("tip", [0.5, 0.9]))
	# Where on the BODY it should join -- measured on the body's own box, which the limbs
	# themselves cannot stretch the way they stretch the drawing's.
	var expected := _on_body(bone["attach"]) if bone.has("attach") else pivot
	if part.interior:
		if not bool(bone.get("interior", false)):
			return {}
		var attach_cell := _nearest_of(part.cells, _to_grid(expected))
		var attach := _to_rig(attach_cell)
		var far := _to_rig(_farthest(part.cells, attach_cell))
		var reach := attach.distance_to(expected) / _longest
		if reach > MAX_REACH or attach.distance_to(far) < MIN_LENGTH * _longest * 0.5:
			return {}
		return {"cost": pow(reach / REACH_SCALE, 2.0) + INTERIOR_PENALTY, "attach": attach, "tip": far}
	if String(bone.get("shape", "")) == "thin" and part.width_ratio > THIN:
		return {}
	var drawn := part.tip - part.attach
	var authored := tip - pivot
	if drawn.length() < 0.0001 or authored.length() < 0.0001:
		return {}
	var turn := rad_to_deg(absf(angle_difference(drawn.angle(), authored.angle())))
	if turn > float(bone.get("max_turn", MAX_TURN_DEG)):
		return {}
	var reach := part.attach.distance_to(expected) / _longest
	if reach > MAX_REACH:
		return {}
	return {"cost": pow(turn / float(bone.get("turn_scale", TURN_SCALE_DEG)), 2.0) + pow(reach / REACH_SCALE, 2.0),
		"attach": part.attach, "tip": part.tip}


## The view's bones placed on this drawing: matched bones on their parts, unmatched limb bones
## dropped, repeat clones added beside their source.
func _placed(bones: Array, fit_bones: Array[int], bone_part: Dictionary, clones: Array) -> Array:
	var out: Array = []
	var dropped: Dictionary = {}
	for index in range(bones.size()):
		var bone: Dictionary = (bones[index] as Dictionary).duplicate(true)
		if index in fit_bones and String(bone.get("fit", "")) == "appendage":
			if not bone_part.has(index):
				dropped[String(bone.get("name", ""))] = String(bone.get("parent", ""))
				continue
			var priced: Dictionary = (bone_part[index] as Array)[3]
			bone["pivot_at"] = priced["attach"]
			bone["tip_at"] = priced["tip"]
		out.append(bone)
	var made: Dictionary = {}
	for pair in clones:
		var source: Dictionary = bones[int(pair[1])]
		if String(source.get("fit", "")) != "appendage":
			continue
		var name := String(source.get("name", ""))
		var count := int(made.get(name, 0)) + 1
		made[name] = count
		var clone := source.duplicate(true)
		var priced: Dictionary = pair[3]
		clone["name"] = "%s_%d" % [name, count]
		clone["pivot_at"] = priced["attach"]
		clone["tip_at"] = priced["tip"]
		clone["index"] = int(source.get("index", 0)) + count * 10
		if float(source.get("side", 0.0)) != 0.0:
			clone["side"] = signf((priced["attach"] as Vector2).x - _bounds.get_center().x)
		var gait: Dictionary = clone.get("gait", {})
		if not gait.is_empty():
			gait["phase"] = fposmod(float(gait.get("phase", 0.0)) + float(source.get("repeat_phase", 0.5)) * count, 1.0)
		out.append(clone)
	# A dropped bone's children hang from its parent instead.
	for bone_value in out:
		var bone: Dictionary = bone_value
		var parent := String(bone.get("parent", ""))
		while dropped.has(parent):
			parent = String(dropped[parent])
		bone["parent"] = parent
	return out


func _regions(bones: Array, bone_part: Dictionary, clones: Array, candidates: Array[Part]) -> Regions:
	var regions := Regions.new()
	regions.origin = _origin
	regions.cell = _cell
	regions.width = _w
	regions.height = _h
	regions.labels.resize(_w * _h)
	regions.labels.fill(-1)
	var owned: Array = []
	for index in bone_part:
		var bone: Dictionary = bones[int(index)]
		if String(bone.get("fit", "")) == "appendage":
			owned.append([String(bone.get("name", "")), candidates[int((bone_part[index] as Array)[2])]])
	var made: Dictionary = {}
	for pair in clones:
		var source: Dictionary = bones[int(pair[1])]
		if String(source.get("fit", "")) != "appendage":
			continue
		var name := String(source.get("name", ""))
		var count := int(made.get(name, 0)) + 1
		made[name] = count
		owned.append(["%s_%d" % [name, count], candidates[int(pair[2])]])
	for entry in owned:
		var slot := regions.names.size()
		regions.names.append(String(entry[0]))
		for i in (entry[1] as Part).cells:
			regions.labels[i] = slot
	return regions


func _mirrored_bone(bone: Dictionary, mirrored: bool) -> Dictionary:
	if not mirrored:
		return bone
	var out := bone.duplicate(true)
	for field in ["pivot", "tip"]:
		var point: Array = out.get(field, [0.5, 0.5])
		if point.size() == 2:
			out[field] = [1.0 - float(point[0]), float(point[1])]
	if out.has("side"):
		out["side"] = -float(out["side"])
	var joins: Array = out.get("attach", [])
	if joins.size() == 2:
		out["attach"] = [1.0 - float(joins[0]), float(joins[1])]
	var capture: Dictionary = out.get("capture", {})
	if capture.has("u"):
		var band: Array = capture["u"]
		if band.size() == 2:
			capture["u"] = [1.0 - float(band[1]), 1.0 - float(band[0])]
	return out


## What the fit saw and chose, for tests and diagnostics.
func _debug(best: Dictionary) -> Dictionary:
	var parts: Array = []
	for part in _parts + _inner:
		parts.append({
			"stroke": part.stroke, "attach": _norm(part.attach), "tip": _norm(part.tip), "mass": part.mass,
			"width": part.width_ratio, "length": part.length / _longest, "interior": part.interior,
		})
	var placed: Array = []
	for bone_value in best.get("bones", []):
		var bone: Dictionary = bone_value
		if bone.has("pivot_at"):
			placed.append("%s %s->%s" % [bone["name"], _norm(bone["pivot_at"]).snappedf(0.01),
				_norm(bone["tip_at"]).snappedf(0.01)])
	return {"body_stroke": _body_stroke, "core_cells": _core.get_true_bit_count(),
		"cost": best.get("cost", 0.0), "parts": parts, "placed": placed, "readings": _readings}


# --- small helpers --------------------------------------------------------------

func _is_closed(points: PackedVector2Array) -> bool:
	if points.size() < 3:
		return false
	var box := Rect2(points[0], Vector2.ZERO)
	for point in points:
		box = box.expand(point)
	return points[0].distance_to(points[points.size() - 1]) <= maxf(CLOSED_GAP * box.size.length(), 3.0 * _cell)


func _components(map: BitMap, eight: bool) -> Array:
	var cells := PackedInt32Array()
	for y in range(_h):
		for x in range(_w):
			if map.get_bit(x, y):
				cells.append(y * _w + x)
	return _components_of(cells, eight)


## Connected pieces of a set of cells.
func _components_of(cells: PackedInt32Array, eight: bool = true) -> Array:
	var member := {}
	for i in cells:
		member[i] = true
	var seen := {}
	var out: Array = []
	for start in cells:
		if seen.has(start):
			continue
		var piece := PackedInt32Array([start])
		seen[start] = true
		var head := 0
		while head < piece.size():
			var i := piece[head]
			head += 1
			var x := i % _w
			var y := i / _w
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if (dx == 0 and dy == 0) or (not eight and dx != 0 and dy != 0):
						continue
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= _w or ny >= _h:
						continue
					var j := ny * _w + nx
					if member.has(j) and not seen.has(j):
						seen[j] = true
						piece.append(j)
		out.append(piece)
	return out


func _copy(map: BitMap) -> BitMap:
	var out := BitMap.new()
	out.create(Vector2i(_w, _h))
	for y in range(_h):
		for x in range(_w):
			if map.get_bit(x, y):
				out.set_bit(x, y, true)
	return out


func _to_grid(point: Vector2) -> Vector2:
	return (point - _origin) / _cell


func _to_rig(cell: Vector2) -> Vector2:
	return _origin + cell * _cell


func _norm(point: Vector2) -> Vector2:
	return (point - _bounds.position) / _bounds.size


## An authored [u, v] fraction, in rig space on this drawing.
func _at(value: Variant) -> Vector2:
	var pair: Array = value
	var uv := Vector2(float(pair[0]), float(pair[1])) if pair.size() == 2 else Vector2(0.5, 0.5)
	return _bounds.position + uv * _bounds.size


## A [u, v] fraction of the body's own box, in rig space.
func _on_body(value: Variant) -> Vector2:
	var pair: Array = value
	var uv := Vector2(float(pair[0]), float(pair[1])) if pair.size() == 2 else Vector2(0.5, 0.5)
	return _core_box.position + uv * _core_box.size


func _farthest(cells: PackedInt32Array, from: Vector2) -> Vector2:
	var best := from
	var reach := -1.0
	for i in cells:
		var at := Vector2(i % _w + 0.5, i / _w + 0.5)
		var d := at.distance_squared_to(from)
		if d > reach:
			reach = d
			best = at
	return best


func _farthest_along(cells: PackedInt32Array, from: Vector2, heading: Vector2) -> Vector2:
	var best := from
	var reach := -INF
	for i in cells:
		var at := Vector2(i % _w + 0.5, i / _w + 0.5)
		var d := (at - from).dot(heading)
		if d > reach:
			reach = d
			best = at
	return best


func _nearest_of(cells: PackedInt32Array, to: Vector2) -> Vector2:
	var best := to
	var reach := INF
	for i in cells:
		var at := Vector2(i % _w + 0.5, i / _w + 0.5)
		var d := at.distance_squared_to(to)
		if d < reach:
			reach = d
			best = at
	return best


func _nearest_ink_cell(to: Vector2) -> Vector2:
	var best := to
	var reach := INF
	for cells_value in _stroke_cells:
		for i in cells_value as PackedInt32Array:
			var at := Vector2(i % _w + 0.5, i / _w + 0.5)
			var d := at.distance_squared_to(to)
			if d < reach:
				reach = d
				best = at
	return best


func _centre_of(map: BitMap) -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	for y in range(_h):
		for x in range(_w):
			if map.get_bit(x, y):
				sum += Vector2(x + 0.5, y + 0.5)
				count += 1
	return sum / float(count) if count > 0 else _to_grid(_bounds.get_center())


func _centre_of_cells(cells: PackedInt32Array) -> Vector2:
	var sum := Vector2.ZERO
	for i in cells:
		sum += Vector2(i % _w + 0.5, i / _w + 0.5)
	return sum / float(maxi(1, cells.size()))


func _polygon_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		area += a.x * b.y - b.x * a.y
	return area * 0.5


func _distance_to_polyline(point: Vector2, points: PackedVector2Array) -> float:
	var best := INF
	for i in range(points.size() - 1):
		var nearest := Geometry2D.get_closest_point_to_segment(point, points[i], points[i + 1])
		best = minf(best, point.distance_to(nearest))
	return best
