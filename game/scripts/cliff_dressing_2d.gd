class_name CliffDressing2D
extends Node2D
## Mayon's construction, worn by Levels 1-4 in their own ground: tools/build_cliff_kits.py cuts
## each level's strip from that level's delivered tileset (Payyo's mossy river-stone terrace wall
## under its own thick grass, ...), and this draws it the way MayonTerrain2D draws Mayon's cliffs.
##
## Draws only: each platform gets the strip from `lip` above its top -- a thick lip she stands in,
## stone under it darkening as it goes down -- and the ground carries on below in darker repeats
## of the stone instead of a flat fill, each broken layer shadowing the one under it. Collision
## stays with each level's own bodies, which hand their rectangles over (`dress()`, or by group).
##
## An open end rounds from the lip into a shaded wall, with grass spilling a little way down
## the side and a plant on the corner. A step down to lower ground shadows the foot of the wall.
##
## ⚠ NOT Mayon's enlarged end caps. Enlarged, a tileset painted one pixel to a pixel blurs; and a
## cap of stones laid over the wall's own stones met them nowhere and read as a chewed edge.
##
## Where it differs from Mayon it is because Mayon never needed it: an end is open when the
## ground beside it is LOWER on either side (Mayon only ever climbs to the right), and ground
## that keeps its own top -- a paddy's mud -- still closes or lowers an end beside it.

## The level's kit: face.png, edge.png, plant_N.png and kit.json, which says where the walk line,
## the lip's band and the stone are in face.png, so the scene restates none of it.
@export_dir var kit := ""
const ShelfArt = preload("res://scripts/moonlit_shelf_art.gd")
const EdgeArt = preload("res://scripts/terrain_edge_art.gd")
## The level's ground bodies, by group. Each answers `dressed_ground()` -- world rects this
## draws for it, standing its own art down -- and may answer `undressed_ground()`: ground that
## keeps its own top but whose face this draws, and which closes or lowers an end beside it.
@export var ground_group: StringName = &""
## Only the group's bodies of this kind (`ground_kind()`) are drawn here; the rest only close the
## ends beside them, through `ground_rects()`, which changes nothing about them. Dilim's mud and
## its rocks are two dressings over one group. Empty: every body in the group.
@export var kind := ""
## The light on the ground. A night level grades its whole kit by it.
@export var tint := Color.WHITE

## MayonTerrain2D's numbers: the same construction, so the same depth.
const DEPTH_TINTS := [Color(0.62, 0.6, 0.62), Color(0.42, 0.4, 0.44), Color(0.28, 0.26, 0.3)]
const DEPTH_STEP := 150.0
## A platform this thin or thinner is a loose shelf of rock, not a wall.
const LEDGE_MAX := 40.0
## An open side, turning away from the light: this wide, this dark at the edge.
const SIDE_SHADE := 22.0
const SIDE_DARK := 0.5
const OUTLINE := Color(0.06, 0.05, 0.03, 0.85)
## At the foot of a wall, on the lower step: the wall's shadow, this far out.
const CONTACT := 30.0
const CONTACT_DARK := 0.45
## Plants along a lip: never nearer an end than this, and this far apart give or take.
const PLANT_MARGIN := 70.0
const PLANT_GAP := Vector2(190.0, 430.0)

## From kit.json; the defaults are only what an empty kit draws with.
var lip := 14.0
var band := 35.0
var skip := 59.0
var overhang := 6.0
var deep := Color(0.11, 0.09, 0.04)
var corner_plant := 0
## Large native-size kits can space their plants without changing the other levels.
var plant_gap := PLANT_GAP
var plant_margin := PLANT_MARGIN
var vine_offset := 0.0

var _face: Texture2D
var _edge: Texture2D
var _shelf: Texture2D
var _plants: Array[Texture2D] = []
var _vines: Array[Texture2D] = []
var _ground: Array[Rect2] = []
var _ledges: Array[Rect2] = []
var _others: Array[Rect2] = []
## Ground another dressing draws: it closes or lowers an end here and is not drawn.
var _neighbours: Array[Rect2] = []
## Every open end, as {rect, side (-1 left, 1 right), rise (0 at a free end)}.
var _ends: Array[Dictionary] = []
var _corners: Dictionary = {}
var _caps: Node2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	modulate = tint
	if kit != "":
		_load_kit()
	_caps = Node2D.new()
	_caps.name = "CliffCaps"
	# Over every strip, as Mayon's joins are, and graded with them.
	_caps.z_index = 1
	_caps.use_parent_material = true
	_caps.draw.connect(_draw_caps)
	add_child(_caps)
	if ground_group != &"":
		# Deferred: every body in the level has to have built itself first.
		call_deferred("_collect")


func _load_kit() -> void:
	_face = load(kit.path_join("face.png")) as Texture2D
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(kit.path_join("kit.json")))
	if not data is Dictionary:
		push_error("CliffDressing2D: %s has no readable kit.json" % kit)
		return
	# Quiet block kits already carry their moss in the strip; they need no extra spill.
	if bool(data.get("edge", true)):
		_edge = load(kit.path_join("edge.png")) as Texture2D
	var shelf_path := String(data.get("shelf", ""))
	if not shelf_path.is_empty():
		_shelf = load(kit.path_join(shelf_path)) as Texture2D
	lip = float(data.get("lip", lip))
	band = float(data.get("band", band))
	var spacing: Array = data.get("plant_gap", [PLANT_GAP.x, PLANT_GAP.y])
	plant_gap = Vector2(float(spacing[0]), float(spacing[1]))
	plant_margin = float(data.get("plant_margin", PLANT_MARGIN))
	vine_offset = float(data.get("vine_offset", band - 10.0))
	skip = float(data.get("skip", skip))
	overhang = float(data.get("overhang", overhang))
	deep = Color.html(String(data.get("deep", deep.to_html(false))))
	corner_plant = int(data.get("corner_plant", corner_plant))
	for index in range(int(data.get("plants", 0))):
		_plants.append(load(kit.path_join("plant_%d.png" % index)) as Texture2D)
	for index in range(int(data.get("vines", 0))):
		_vines.append(load(kit.path_join("vine_%d.png" % index)) as Texture2D)


## Hand over the ground, in this node's space. Thin pieces are drawn as loose shelves.
func dress(ground: Array[Rect2], others: Array[Rect2] = [], neighbours: Array[Rect2] = []) -> void:
	_ground.clear()
	_ledges.clear()
	for rect in ground:
		if rect.size.y <= LEDGE_MAX:
			_ledges.append(rect)
		else:
			_ground.append(rect)
	_others = others.duplicate()
	_neighbours = neighbours.duplicate()
	_ends = exposed_ends()
	_corners.clear()
	for end in _ends:
		var rect: Rect2 = end.rect
		var rise: float = end.rise
		var limit := minf(rise, EdgeArt.RADIUS) if rise > 0.0 else EdgeArt.RADIUS
		var corners: Vector2 = _corners.get(rect, Vector2.ZERO)
		corners[int(end.side > 0)] = EdgeArt.radius(rect, limit)
		_corners[rect] = corners
	queue_redraw()
	if _caps != null:
		_caps.queue_redraw()


## Which ends are open. Ground as high or higher beside an end closes it; lower ground leaves a
## riser (its height is the end's `rise`); nothing beside it leaves a free end (rise 0).
func exposed_ends() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var meets: Array[Rect2] = _ground + _others + _neighbours
	for rect in _ground:
		for side in [-1, 1]:
			var lower := EdgeArt.neighbour_top(rect, side, meets)
			if lower > rect.position.y + 0.5:
				out.append({"rect": rect, "side": side,
					"rise": lower - rect.position.y if lower < INF else 0.0})
	return out


## Where plants stand along one lip, as world-anchored local x positions: the same every run and
## the same however the ground is split into bodies.
func plant_spots(rect: Rect2) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	if _plants.size() < 2:
		return spots
	var origin := global_position.x
	var x := rect.position.x + plant_margin
	x += _hash(x + origin) * plant_gap.x * 0.5
	while x < rect.end.x - plant_margin:
		var which := 1 + int(_hash(x + origin + 17.0) * float(_plants.size() - 1)) % (_plants.size() - 1)
		spots.append(Vector2(roundf(x), float(which)))
		x += lerpf(plant_gap.x, plant_gap.y, _hash(x + origin + 31.0))
	return spots


func _hash(value: float) -> float:
	return fposmod(sin(value * 12.9898) * 43758.5453, 1.0)


func _collect() -> void:
	var environment := _environment()
	var ground: Array[Rect2] = []
	var others: Array[Rect2] = []
	var neighbours: Array[Rect2] = []
	for body in get_tree().get_nodes_in_group(ground_group):
		if environment != null and not environment.is_ancestor_of(body):
			continue
		if kind != "" and body.has_method("ground_kind") and String(body.call("ground_kind")) != kind:
			# ⚠ ground_rects(), never dressed_ground(): that would stand the other kind's art down.
			for rect: Rect2 in body.call("ground_rects"):
				neighbours.append(_local(rect))
			continue
		if body.has_method("dressed_ground"):
			for rect: Rect2 in body.call("dressed_ground"):
				ground.append(_local(rect))
		if body.has_method("undressed_ground"):
			for rect: Rect2 in body.call("undressed_ground"):
				others.append(_local(rect))
	dress(ground, others, neighbours)


## The environment this belongs to, so a second level loaded alongside (a test) is not dressed.
func _environment() -> Node:
	var node := get_parent()
	while node != null and not node is EnvironmentBaseplate:
		node = node.get_parent()
	return node


func _local(rect: Rect2) -> Rect2:
	return Rect2(to_local(rect.position), rect.size)


func _draw() -> void:
	if _face == null:
		return
	for rect in _ground:
		_draw_wall(rect, rect.position.y - lip, true, _corners.get(rect, Vector2.ZERO))
	# Mud keeps its own silt band; under it, the same stone as the banks either side.
	for rect in _others:
		_draw_wall(rect, rect.position.y, false)
	for rect in _ledges:
		_draw_loose_rock(rect)
	for end: Dictionary in _ends:
		_draw_open_side(end.rect, int(end.side), float(end.rise))


## Deep fill, the darker repeats from deepest to nearest, then the strip itself over them.
func _draw_wall(rect: Rect2, top: float, with_strip: bool, corners := Vector2.ZERO) -> void:
	var face := Rect2(rect.position.x, top, rect.size.x, rect.end.y - top)
	var slices := EdgeArt.rows(face, corners)
	for slice in slices:
		var fill := slice.intersection(rect)
		if fill.has_area():
			draw_rect(fill, deep)
	for layer in range(DEPTH_TINTS.size(), 0, -1):
		var y := top + layer * DEPTH_STEP
		if y < rect.end.y:
			# Shifted along, so the shadowed stone does not repeat the face above it.
			_draw_tiles(rect, y, skip, minf(_face.get_height() - skip, rect.end.y - y),
				DEPTH_TINTS[layer - 1], layer * 0.37 * _face.get_width())
	if with_strip:
		for slice in slices:
			var source_y := slice.position.y - top
			_draw_tiles(slice, slice.position.y, source_y,
				minf(slice.size.y, _face.get_height() - source_y), Color.WHITE, 0.0)
	else:
		_draw_tiles(rect, top, skip, minf(rect.end.y - top, _face.get_height() - skip),
			DEPTH_TINTS[0], 0.0)


## One band of tiles across a platform, in world phase.
func _draw_tiles(rect: Rect2, y: float, source_y: float, height: float, colour: Color,
		shift: float) -> void:
	if height <= 0.0:
		return
	for piece in tiles_across(rect, float(_face.get_width()), shift):
		draw_texture_rect_region(_face, Rect2(piece.x, y, piece.z, height),
			Rect2(piece.y, source_y, piece.z, height), colour)


## The tile pieces across one platform, clipped to it, as (local x, texture x, width). Tile phase
## belongs to the world, so adjacent platforms do not restart a tile.
func tiles_across(rect: Rect2, width: float, shift: float) -> Array[Vector3]:
	var pieces: Array[Vector3] = []
	var origin := global_position.x + shift
	var from := rect.position.x + origin
	var to := rect.end.x + origin
	var k := floori(from / width)
	while k * width < to:
		var start := k * width
		var left := maxf(from, start)
		var right := minf(to, start + width)
		if right > left:
			pieces.append(Vector3(left - origin, left - start, right - left))
		k += 1
	return pieces


## Normalised UVs for points in this node's space: world-anchored across, `top` at row 0.
func strip_uv(points: PackedVector2Array, top: float) -> PackedVector2Array:
	var uv := PackedVector2Array()
	var size := _face.get_size()
	for point in points:
		uv.append(Vector2((point.x + global_position.x) / size.x, (point.y - top) / size.y))
	return uv


## A shelf of stone: the strip cut to a broken underside. It starts `lip` above the walk line,
## as a wall's strip does, and reaches down far enough to show stone under its grass.
func _draw_loose_rock(rect: Rect2) -> void:
	if uses_floating_shelf(rect):
		ShelfArt.draw_on(self, _shelf, rect)
		return
	var width := rect.size.x
	var under := band + 12.0
	var outline := EdgeArt.top_edge(width, EdgeArt.radius(rect, 15.0))
	var right_shoulder := outline.size() - 1
	outline.append_array(PackedVector2Array([
		Vector2(width - 6, under), Vector2(width - 30, under + 16), Vector2(width * .56, under + 24),
		Vector2(width * .36, under + 17), Vector2(18, under + 12), Vector2(4, under)]))
	var points := PackedVector2Array()
	for point in outline:
		points.append(rect.position - Vector2(0, lip) + point)
	draw_polygon(points, PackedColorArray([Color.WHITE]), strip_uv(points, rect.position.y - lip),
		_face)
	draw_polyline(points.slice(right_shoulder) + PackedVector2Array([points[0]]), OUTLINE, 1.0)


## Grounded landmark rocks keep their depth; unsupported ledges share the raised path artwork.
func uses_floating_shelf(rect: Rect2) -> bool:
	if _shelf == null:
		return false
	for base: Rect2 in _ground + _others + _neighbours:
		var overlaps := rect.position.x < base.end.x and rect.end.x > base.position.x
		if overlaps and rect.end.y >= base.position.y - 0.5 and rect.end.y <= base.end.y:
			return false
	return true


## One open end: the side shading away from the light, its outline, and -- at a step down -- the
## wall's shadow on the lower step.
func _draw_open_side(rect: Rect2, side: int, rise: float) -> void:
	var edge := rect.position.x if side < 0 else rect.end.x
	var from := rect.position.y - lip + band
	var to := rect.position.y + (rise if rise > 0.0 else rect.size.y)
	var inner := edge - side * SIDE_SHADE
	var dark := Color(0.0, 0.0, 0.0, SIDE_DARK)
	var clear := Color(0.0, 0.0, 0.0, 0.0)
	if to > from:
		draw_polygon(PackedVector2Array([Vector2(edge, from), Vector2(inner, from), Vector2(inner, to),
			Vector2(edge, to)]), PackedColorArray([dark, clear, clear, dark]))
		draw_rect(Rect2(edge - (2.0 if side > 0 else 0.0), from, 2.0, to - from), OUTLINE)
	if rise > 0.0:
		var lower := rect.position.y + rise
		var out := edge + side * CONTACT
		var shade := Color(0.0, 0.0, 0.0, CONTACT_DARK)
		draw_polygon(PackedVector2Array([Vector2(edge, lower - lip), Vector2(out, lower - lip),
			Vector2(out, lower + 48.0), Vector2(edge, lower + 48.0)]),
			PackedColorArray([shade, clear, clear, shade]))


func _draw_caps() -> void:
	if _face == null:
		return
	for rect in _ground:
		for spot in plant_spots(rect):
			_draw_plant(int(spot.y), Vector2(spot.x, rect.position.y), 1)
			if not _vines.is_empty():
				# Short face growth, inset from the ends: never a hanging path up a riser.
				var which := int(_hash(spot.x + 83.0) * _vines.size()) % _vines.size()
				var vine := _vines[which]
				if rect.size.y >= band + vine.get_height():
					_caps.draw_texture(vine, Vector2(spot.x - floorf(vine.get_width() * 0.5),
						rect.position.y - lip + vine_offset))
	if _edge != null:
		for end: Dictionary in _ends:
			var rect: Rect2 = end.rect
			var side := int(end.side)
			var edge := rect.position.x if side < 0 else rect.end.x
			_caps.draw_set_transform(Vector2(edge + side * overhang, rect.position.y - lip + band - 6.0),
				0.0, Vector2(float(-side), 1.0))
			_caps.draw_texture(_edge, Vector2.ZERO)
			_caps.draw_set_transform(Vector2.ZERO)
			# The corner plant, rooted just inside the edge and leaning out over it.
			if corner_plant < _plants.size():
				_draw_plant(corner_plant, Vector2(edge - side * 12.0, rect.position.y), -side)


## A plant rooted on the walk line at `at` (its base centre), mirrored when `facing` is -1.
func _draw_plant(index: int, at: Vector2, facing: int) -> void:
	var plant := _plants[index]
	var size := plant.get_size()
	_caps.draw_set_transform(Vector2(at.x, at.y + 3.0), 0.0, Vector2(float(facing), 1.0))
	_caps.draw_texture(plant, Vector2(-floorf(size.x * 0.5), -size.y))
	_caps.draw_set_transform(Vector2.ZERO)
