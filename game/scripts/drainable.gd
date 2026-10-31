class_name Drainable
extends Node
## Mayon's ash takes the world: white, then blank. Hang this under anything that can be taken --
## a prop, a stretch of ground, a backdrop band -- and drain it.
##
## It gives its target the drain shader (drain.gdshader) and makes every CanvasItem under the
## target use it, so a prop built of several sprites goes white as one. At blank the target's
## collision goes with it: a bridge that has gone blank is not there to stand on.
##
## ⚠ NOTHING IS FREED. A freed node cannot come back on a checkpoint restore (LevelBase re-homes
## props, it does not rebuild them), so a blanked thing keeps its node and `restore()` brings it
## back, collision and all. The level carries which things were taken in its run state.
##
## The drain is a tween on this node, so it holds while the tree is paused -- a line of dialogue
## does not let the ash keep working behind it.

signal blanked
signal restored

const SHADER := preload("res://shaders/drain.gdshader")
## At or past this, it is blank.
const BLANK := 0.999

## What drains: the parent, unless set.
@export var target_path: NodePath = ^".."

## What it drains toward. Mayon's paper unless a level gives its own (LevelBase._fade_paper).
var paper := Color(0.957, 0.937, 0.894)
## How much of the whitening it takes, and where it starts to go (drain.gdshader). Mayon's: all of
## it, from flat paper.
var wash := 1.0
var vanish_from := 0.85
## Whether it draws in its painted colours (drain.gdshader `texture_in_colour`): true for an old
## way in another level. Mayon's ash leaves it off, the look its tuning was made against.
var painted_colours := false
## Whether it shows itself in a level's dark WHILE IT GOES, the way her drawings are seen
## (PhysicsShapeObject.dark_reveal): an old way in Dilim's woods has to be seen to be seen going.
## Only while it goes -- before, the woods stay as dark as Kent made them, and a reveal standing
## open round the bungisngis's ravine showed the giant from half a screen off. Seen, never light:
## DarknessLayer.REVEAL_GROUP, which LightField does not count, so it shows no sigbin.
var reveals_in_dark := false
## How much of the drain it takes to come up out of the dark, before it dissolves with the rest.
const REVEAL_RISE := 0.15

## How far the ash has taken it: 0 painted, 0.5 white, 0.85 flat paper, 1 blank.
var drain: float = 0.0:
	set = set_drain

var _target: CanvasItem
var _material: ShaderMaterial
var _tween: Tween
var _blank := false
## Every body taken at blank, with its layer and mask to give back.
var _taken: Array[Dictionary] = []


func _ready() -> void:
	_target = get_node_or_null(target_path) as CanvasItem
	if _target == null:
		push_warning("Drainable: nothing to drain at %s" % target_path)
		return
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("paper", paper)
	_material.set_shader_parameter("wash", wash)
	_material.set_shader_parameter("vanish_from", vanish_from)
	_material.set_shader_parameter("texture_in_colour", painted_colours)
	_target.material = _material
	for item in _target.find_children("*", "CanvasItem", true, false):
		(item as CanvasItem).use_parent_material = true
	set_drain(drain)


func set_drain(value: float) -> void:
	drain = clampf(value, 0.0, 1.0)
	if _material != null:
		_material.set_shader_parameter("drain", drain)
	if drain >= BLANK and not _blank:
		_go_blank()
	elif drain < BLANK and _blank:
		_come_back()


## Drain to `value` over `seconds`. 0 seconds is at once.
func drain_to(value: float, seconds: float) -> Tween:
	_stop()
	if seconds <= 0.0:
		set_drain(value)
		return null
	_tween = create_tween()
	_tween.tween_property(self, "drain", clampf(value, 0.0, 1.0), seconds)
	return _tween


## Painted again, at once: for a checkpoint restore.
func restore() -> void:
	_stop()
	set_drain(0.0)


func is_blank() -> bool:
	return _blank


func target() -> CanvasItem:
	return _target


func dark_reveal() -> Dictionary:
	if not reveals_in_dark or _target == null or _blank or drain <= 0.0:
		return {}
	var box := _extent()
	if box.size == Vector2.ZERO:
		return {}
	var reach := maxf(box.size.x, box.size.y) * 0.5 * PhysicsShapeObject.DARK_REVEAL_FULL \
		/ LightField.SOFT_EDGE + PhysicsShapeObject.DARK_REVEAL_MARGIN
	return {"position": box.get_center(), "radius": reach,
		"strength": PhysicsShapeObject.DARK_REVEAL_STRENGTH * minf(1.0, drain / REVEAL_RISE)
			* (1.0 - drain)}


## Everything drawn in it, in the world.
func _extent() -> Rect2:
	var sprites: Array[Node] = _target.find_children("*", "Sprite2D", true, false)
	if _target is Sprite2D:
		sprites.append(_target)
	var box := Rect2()
	for node in sprites:
		var sprite := node as Sprite2D
		var rect := sprite.get_global_transform() * sprite.get_rect()
		box = rect if box.size == Vector2.ZERO else box.merge(rect)
	return box


func _stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _go_blank() -> void:
	_blank = true
	_taken.clear()
	for body in _bodies():
		_taken.append({"body": body, "layer": body.collision_layer, "mask": body.collision_mask})
		body.collision_layer = 0
		body.collision_mask = 0
	blanked.emit()


func _come_back() -> void:
	_blank = false
	for entry in _taken:
		var body := entry["body"] as CollisionObject2D
		if is_instance_valid(body):
			body.collision_layer = int(entry["layer"])
			body.collision_mask = int(entry["mask"])
	_taken.clear()
	restored.emit()


func _bodies() -> Array[CollisionObject2D]:
	var found: Array[CollisionObject2D] = []
	if _target is CollisionObject2D:
		found.append(_target as CollisionObject2D)
	for node in _target.find_children("*", "CollisionObject2D", true, false):
		found.append(node as CollisionObject2D)
	return found
