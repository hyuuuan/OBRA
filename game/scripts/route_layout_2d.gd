class_name RouteLayout2D
extends Node2D
## The physical difference between the three answers (Game Design §3): choosing a route
## opens its part of the level and permanently removes the others for this playthrough.
##
## Removal is real -- the losing branches are freed, not hidden -- because a hidden
## StaticBody2D still collides, and a player who picked the gorge would walk into an
## invisible dead tree. Until a choice is made every branch is inactive, so the chasm
## reads as impassable, which is what makes the question worth asking.

## Child node names, one per route. Anything not named here is shared scenery and is
## left alone.
@export var artist_branch: NodePath = NodePath("Artist")
@export var pragmatist_branch: NodePath = NodePath("Pragmatist")
@export var protector_branch: NodePath = NodePath("Protector")

var _chosen := ""


func _ready() -> void:
	for path in [artist_branch, pragmatist_branch, protector_branch]:
		_set_branch_active(get_node_or_null(path), false)


func chosen_route() -> String:
	return _chosen


func apply_route(route: String) -> void:
	if not _chosen.is_empty():
		return
	_chosen = route
	var keep := _branch_for(route)
	for path in [artist_branch, pragmatist_branch, protector_branch]:
		var branch := get_node_or_null(path)
		if branch == null:
			continue
		if branch == keep:
			_set_branch_active(branch, true)
		else:
			branch.queue_free()


func _branch_for(route: String) -> Node:
	match route:
		"artist":
			return get_node_or_null(artist_branch)
		"pragmatist":
			return get_node_or_null(pragmatist_branch)
		"protector":
			return get_node_or_null(protector_branch)
	return null


## Inactive means invisible AND intangible. Visibility alone would leave the collision
## in the world, which is the difference between a branch that is off and one that is
## merely unpainted.
func _set_branch_active(branch: Node, active: bool) -> void:
	if branch == null:
		return
	if branch is CanvasItem:
		(branch as CanvasItem).visible = active
	branch.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	for node in branch.find_children("*", "CollisionObject2D", true, false):
		var body := node as CollisionObject2D
		body.set_deferred(&"collision_layer", 1 if active else 0)
		body.set_deferred(&"collision_mask", 1 if active else 0)
	var self_body := branch as CollisionObject2D
	if self_body != null:
		self_body.set_deferred(&"collision_layer", 1 if active else 0)
		self_body.set_deferred(&"collision_mask", 1 if active else 0)
