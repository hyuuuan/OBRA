class_name FloatingTread2D
extends RigidBody2D
## The stair tread that floated off into the paddy, and sub-beat 0.2's whole lesson:
## the things in this world have weight, and weight is something you can use.
##
## LOOSE, IT IS NOT A STEP. It is a plank riding on water -- light, free to rotate, and
## buoyant enough that anything landing on one end tips it and slides off. That is not a
## punishment, it is the observation the beat is built on: the player tries to use it,
## feels it roll out from under them, and now has a reason to want it held down.
##
## HELD DOWN BY SOMETHING THAT ROLLS, it becomes one. A circle or a wheel resting on it is
## mass the water cannot lift; it levels out, settles, and freezes into a solid platform.
##
## The tag is what is checked, never the class. Roll resolves to whatever tags.json says it
## resolves to, so adding a class to Roll makes it work here with nothing changed -- the
## same rule every obstacle in the level follows.

signal settled(by_class: String)
signal unsettled()

## What has to be resting on it. Not a class list: AbilityTags resolves this.
@export var required_tag: String = "roll"
## How still it has to be before it counts as having come to rest. The weight decides
## where that is -- see _physics_process for why there is no target height here.
@export var rest_speed: float = 6.0
## And how level. A tread that froze crooked is a ramp nobody asked for.
@export var rest_tilt: float = 0.06
## A body counts as resting ON it only if its centre is at least this far above the
## tread's own. Otherwise a prop drifting alongside in the water would hold it down.
@export var contact_margin: float = 6.0

var _settled := false
var _settling_class := ""
var _tags: Node


func _ready() -> void:
	add_to_group(&"floating_treads")
	_tags = get_node_or_null(^"/root/AbilityTags")
	# Contact reporting is what tells us anything is on top at all. Without it
	# get_colliding_bodies() is always empty and the tread can never be weighted.
	contact_monitor = true
	max_contacts_reported = 8


func is_settled() -> bool:
	return _settled


func settling_class() -> String:
	return _settling_class


func _physics_process(delta: float) -> void:
	var weight := _weighting_class()
	if weight.is_empty():
		if _settled:
			_release()
		return
	if _settled:
		return
	_settling_class = weight

	# NO TARGET HEIGHT, AND NOTHING DRIVEN BY HAND. The first version moved the body toward
	# a settled_y picked by eye and lost twice over: the number was 580 while the tread
	# actually comes to rest at 622, and writing global_position on an ACTIVE RigidBody2D
	# fights the physics server, which overwrites it the same frame. It never converged.
	#
	# The weight already does the work -- a circle on it drops it 55px on its own -- so
	# this only has to notice when the sinking has finished. Where it stops is wherever
	# the water and the load agree, which is the honest answer and needs no tuning.
	if absf(linear_velocity.y) <= rest_speed and absf(rotation) <= rest_tilt:
		_settle()


## The class of whatever is resting on top and carries the required tag, or "".
func _weighting_class() -> String:
	for body in get_colliding_bodies():
		# From ABOVE only. Something floating against its edge is not weighing it down.
		if body.global_position.y >= global_position.y - contact_margin:
			continue
		var class_id := _class_of(body)
		if class_id.is_empty():
			continue
		if _tags != null and bool(_tags.call("class_has_tag", class_id, required_tag)):
			return class_id
	return ""


## What a colliding body IS, as far as the roster is concerned. Placed props carry their
## own item data; anything else is scenery or the player and has no class.
func _class_of(body: Node) -> String:
	var prop := body as PhysicsShapeObject
	if prop == null or prop.item_data == null:
		return ""
	return String(prop.item_data.entity_id)


func _settle() -> void:
	_settled = true
	rotation = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	lock_rotation = true
	# Frozen rather than merely heavy: the water skips frozen bodies, so this is also what
	# stops the buoyancy lifting it straight back up the moment it is standable.
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	freeze = true
	settled.emit(_settling_class)


func _release() -> void:
	_settled = false
	_settling_class = ""
	freeze = false
	lock_rotation = false
	unsettled.emit()
