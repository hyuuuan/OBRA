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
