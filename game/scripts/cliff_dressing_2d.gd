class_name CliffDressing2D
extends Node2D
## Mayon's construction, worn by Levels 1-4 in their own ground: tools/build_cliff_kits.py cuts
## each level's strip and end cap from that level's delivered tileset (Payyo's mossy river-stone
## terrace wall, ...), and this draws them the way MayonTerrain2D draws Mayon's cliffs.
##
## Draws only, as MayonTerrain2D does: each platform gets the broad strip from `lip` above
## its top, the mountain carrying on below in darker repeats of the rock instead of a flat fill,
## tiles overlapping so their tapered ends never open a seam, and a painted cap on every open end,
## enlarged uniformly to cover a riser. Collision stays with each level's own bodies, which hand
## their rectangles over (`dress()`, or by group).
##
## Where it differs from Mayon it is because Mayon never needed it: an end is capped when the
## ground beside it is LOWER on either side (Mayon only ever climbs to the right), and ground
## that keeps its own top -- a paddy's mud -- still closes or lowers an end beside it.

## The level's kit: face.png (a strip, its top `lip` px above the walk line) and edge.png.
@export_dir var kit := ""
## The level's ground bodies, by group. Each answers `dressed_ground()` -- world rects this
## draws for it, standing its own art down -- and may answer `undressed_ground()`: ground that
## keeps its own top but whose face this draws, and which closes or lowers an end beside it.
@export var ground_group: StringName = &""
## How far the strip's top is drawn above the collision top. Mayon's meadow strip: 20.
@export var lip := 20.0
## Under the strip, before the repeats: what the rock is in the dark.
@export var deep := Color(0.19, 0.15, 0.12)
## The light on the ground. A night level grades its whole kit by it.
@export var tint := Color.WHITE

## How far neighbouring tiles overlap. Mayon's strips are standalone chunks with tapered ends
## and need 160 (MayonTerrain2D's TILE_OVERLAP); a kit built to tile seamlessly needs none.
@export var tile_overlap := 160.0
## Where the darker repeats start in the strip, so they carry rock and not the lip again.
@export var depth_skip := 40.0

## MayonTerrain2D's numbers: the same construction, so the same depth.
const DEPTH_TINTS := [Color(0.62, 0.6, 0.62), Color(0.42, 0.4, 0.44), Color(0.28, 0.26, 0.3)]
const DEPTH_STEP := 150.0
## The cap stands this far out past the edge, as Mayon's does.
const CAP_OUT := 10.0
## A platform this thin or thinner is a loose shelf of rock, not a wall.
const LEDGE_MAX := 40.0

var _face: Texture2D
var _edge: Texture2D
var _ground: Array[Rect2] = []
var _ledges: Array[Rect2] = []
var _others: Array[Rect2] = []
## Every open end, as {rect, side (-1 left, 1 right), rise (0 at a free end)}.
var _ends: Array[Dictionary] = []
var _caps: Node2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	modulate = tint
	if kit != "":
		_face = load(kit.path_join("face.png")) as Texture2D
		_edge = load(kit.path_join("edge.png")) as Texture2D
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


## Hand over the ground, in this node's space. Thin pieces are drawn as loose shelves.
func dress(ground: Array[Rect2], others: Array[Rect2] = []) -> void:
	_ground.clear()
	_ledges.clear()
	for rect in ground:
		if rect.size.y <= LEDGE_MAX:
			_ledges.append(rect)
		else:
			_ground.append(rect)
	_others = others.duplicate()
	_ends = exposed_ends()
	queue_redraw()
	if _caps != null:
		_caps.queue_redraw()


## Which ends are open. Ground as high or higher beside an end closes it; lower ground leaves a
## riser (its height is the cap's `rise`); nothing beside it leaves a free end (rise 0).
func exposed_ends() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var meets: Array[Rect2] = _ground + _others
	for rect in _ground:
		for side in [-1, 1]:
			var edge := rect.position.x if side < 0 else rect.end.x
			var lower := INF
			var closed := false
			for other in meets:
				if other == rect:
					continue
				var touching := is_equal_approx(other.end.x, edge) if side < 0 \
					else is_equal_approx(other.position.x, edge)
				if not touching or other.end.y <= rect.position.y:
					continue
				if other.position.y <= rect.position.y + 0.5:
					closed = true
				else:
					lower = minf(lower, other.position.y)
			if not closed:
				out.append({"rect": rect, "side": side,
					"rise": lower - rect.position.y if lower < INF else 0.0})
	return out


func _collect() -> void:
	var environment := _environment()
	var ground: Array[Rect2] = []
	var others: Array[Rect2] = []
	for body in get_tree().get_nodes_in_group(ground_group):
		if environment != null and not environment.is_ancestor_of(body):
			continue
		if body.has_method("dressed_ground"):
			for rect: Rect2 in body.call("dressed_ground"):
				ground.append(_local(rect))
		if body.has_method("undressed_ground"):
			for rect: Rect2 in body.call("undressed_ground"):
				others.append(_local(rect))
	dress(ground, others)


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
		_draw_wall(rect, rect.position.y - lip, true)
	# Mud keeps its own silt band; under it, the same rock as the banks either side.
	for rect in _others:
		_draw_wall(rect, rect.position.y, false)
	for rect in _ledges:
		_draw_loose_rock(rect)


## Deep fill, the darker repeats from deepest to nearest, then the strip itself over them.
func _draw_wall(rect: Rect2, top: float, with_strip: bool) -> void:
	draw_rect(rect, deep)
	for band in range(DEPTH_TINTS.size(), 0, -1):
		var y := top + band * DEPTH_STEP
		if y < rect.end.y:
			# Shifted along, so the shadowed rock does not repeat the face above it.
			_draw_tiles(rect, y, depth_skip, minf(_face.get_height() - depth_skip, rect.end.y - y),
				DEPTH_TINTS[band - 1], band * 0.37 * _face.get_width())
	if with_strip:
		_draw_tiles(rect, top, 0.0, minf(rect.end.y - top, _face.get_height()), Color.WHITE, 0.0)
	else:
		_draw_tiles(rect, top, depth_skip, minf(rect.end.y - top, _face.get_height() - depth_skip),
			DEPTH_TINTS[0], 0.0)


## One band of overlapping tiles across a platform; later tiles are drawn over earlier ones.
func _draw_tiles(rect: Rect2, y: float, source_y: float, height: float, colour: Color,
		shift: float) -> void:
	if height <= 0.0:
		return
	for piece in tiles_across(rect, float(_face.get_width()), shift):
		draw_texture_rect_region(_face, Rect2(piece.x, y, piece.z, height),
			Rect2(piece.y, source_y, piece.z, height), colour)


## The tile pieces across one platform, clipped to it, as (local x, texture x, width). Tile phase
## belongs to the world, so adjacent platforms do not restart a tile. MayonTerrain2D's own.
func tiles_across(rect: Rect2, width: float, shift: float) -> Array[Vector3]:
	var pieces: Array[Vector3] = []
	var period := width - tile_overlap
	var origin := global_position.x + shift
	var from := rect.position.x + origin
	var to := rect.end.x + origin
	var k := ceili((from - width) / period)
	while k * period < to:
		var start := k * period
		var left := maxf(from, start)
		var right := minf(to, start + width)
		if right > left:
			pieces.append(Vector3(left - origin, left - start, right - left))
		k += 1
	return pieces


## A shelf of rock: the strip cut to a broken underside, as Mayon's loose rocks are. It starts
## `lip` above the walk line, as a wall's strip does: from the walk line, a kit whose top rows
## are the air its blades stand in drew Payyo's ledges as slivers of grass.
func _draw_loose_rock(rect: Rect2) -> void:
	var width := rect.size.x
	var outline := PackedVector2Array([Vector2(0, -lip), Vector2(width, -lip), Vector2(width, 0),
		Vector2(width - 12, 24), Vector2(width - 42, 39), Vector2(width * .56, 49),
		Vector2(width * .36, 40), Vector2(26, 35), Vector2(8, 23), Vector2(0, 0)])
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	var size := _face.get_size()
	var phase := fposmod(rect.position.x + global_position.x, size.x)
	for point in outline:
		points.append(rect.position + point)
		uv.append(Vector2((phase + point.x) / size.x, (point.y + lip) / size.y))
	draw_polygon(points, PackedColorArray([Color.WHITE]), uv, _face)


func _draw_caps() -> void:
	if _edge == null:
		return
	for end: Dictionary in _ends:
		_draw_cap(end.rect, int(end.side), float(end.rise))


## Natural size on an ordinary end; a uniform enlargement covers a tall riser. Neither axis is
## stretched alone and the top keeps its registration with the strip's lip. Mayon's own rule.
func _draw_cap(rect: Rect2, side: int, rise: float) -> void:
	var fit := maxf(1.0, (rise + 100.0) / _edge.get_height())
	var size := _edge.get_size() * fit
	var edge := rect.position.x if side < 0 else rect.end.x
	_caps.draw_set_transform(Vector2(edge + side * CAP_OUT, rect.position.y - lip), 0.0,
		Vector2(float(-side), 1.0))
	_caps.draw_texture_rect(_edge, Rect2(Vector2.ZERO, size), false)
	_caps.draw_set_transform(Vector2.ZERO)
