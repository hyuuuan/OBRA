extends RefCounted
## WHETHER A MARK IS STANDING ON THE BOTTOM OF THE SEA -- the one question the checkpoint and
## the signpost both ask before deciding what they look like.
##
## Both were made for dry land: a stone lantern with a fire in it, and a pale wooden board on a
## post. Dagat puts the level's last checkpoints and three of its boards on the seabed, where a
## burning lantern is not a thing at all and a wooden signpost is a land object dropped into the
## sea. Under the water they take the sea's forms instead -- see CheckpointLantern2D.Form and
## Signpost2D._sea.
##
## ⚠ TWO CONDITIONS, AND THE FIRST IS THE LEVEL'S. Payyo's paddy is a WaterArea2D too, and a
## board standing in a rice paddy is not standing on a seabed. So a level opts in by meta on an
## ancestor -- `under_the_sea` on the environment scene's root, the way `checkpoint_stone`
## re-skins the lanterns -- and only then does being below a water surface change anything.

const META := &"under_the_sea"
## How far under the surface a point has to be before it counts as below it. A mark planted on
## the surface itself -- a board on the beach at the waterline -- is standing on the shore.
const BELOW := 8.0


## Whether this level has asked for sea forms at all.
static func level_wants_it(node: Node) -> bool:
	var walk := node
	while walk != null:
		if walk.has_meta(META):
			return bool(walk.get_meta(META))
		walk = walk.get_parent()
	return false


## The body of water that holds `point` below its surface, or null. Read off WaterArea2D's own
## box: its position is the middle of it, and surface_y() is its top.
static func water_holding(node: Node, point: Vector2) -> Node2D:
	if node == null or not node.is_inside_tree():
		return null
	for water_value in node.get_tree().get_nodes_in_group(&"water_medium"):
		var water := water_value as Node2D
		if water == null or not water.has_method("surface_y"):
			continue
		var size: Vector2 = water.get("surface_size")
		var top := float(water.call("surface_y"))
		var bottom := water.global_position.y + size.y * 0.5
		var half := size.x * 0.5
		if point.x < water.global_position.x - half or point.x > water.global_position.x + half:
			continue
		if point.y > top + BELOW and point.y <= bottom:
			return water
	return null


## Both conditions, for a mark standing where it is.
static func holds(node: Node2D) -> bool:
	return level_wants_it(node) and water_holding(node, node.global_position) != null


## How far down this water goes below `point`, or INF when there is no water there. A mark on
## a seabed has to look further for its footing than one on a terrace does: the checkpoint's
## own trigger is in the middle of the column, and the bottom is five hundred pixels below it.
static func depth_below(node: Node, point: Vector2) -> float:
	var water := water_holding(node, point)
	if water == null:
		return INF
	var size: Vector2 = water.get("surface_size")
	return water.global_position.y + size.y * 0.5 - point.y
