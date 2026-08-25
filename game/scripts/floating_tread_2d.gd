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
## How long the weight has to stay on before the plank counts as having steadied.
##
## SHORT ON PURPOSE, and it is a tuning number with a measured reason. It only has to tell
## a weight sitting on the plank from one rolling over it -- but every frame it waits is a
## frame the plank spends sinking under the load, and the further it sinks the further it
## has to lift when it locks. At a third of a second it went fifty pixels under, came back
## up through the weight that put it there, and the two threw each other apart: the plank
## tumbled off across the paddy and the beat could not be solved at all. At an eighth it
## barely dips, and it has held every time since.
@export var settle_dwell: float = 0.12
## How far the settled deck stands clear of the water's surface.
##
## IT HAS TO BE CLEAR OF IT AT ALL, and that is the whole reason this number exists.
## wanderer.gd tests `elif is_in_water():` BEFORE `elif is_on_floor():`, so anything
## standing inside the water rectangle gets the wading branch and the 55px kick that goes
## with it -- a player who stepped onto a deck at or below the waterline could never step
## off again, and would be fished out by the drowning rescue while standing on a solid
## floor. Eight pixels is enough to be outside the rectangle and little enough to read as
## a loaded plank riding low.
@export var deck_clearance: float = 8.0
## A body counts as resting ON it only if its centre is at least this far above the
## tread's own. Otherwise a prop drifting alongside in the water would hold it down.
@export var contact_margin: float = 6.0

var _settled := false
var _settling_class := ""
## The body that settled it, kept by reference rather than re-found each frame -- see
## _still_loaded for why a frozen tread cannot answer the question from its contacts.
var _settling_body: Node2D = null
var _loaded_for := 0.0
var _tags: Node
## Who the player is, and every physics body they are made of while this plank is loose.
## The player is kept as well as their bodies, because the exceptions come off when the
## tread settles and have to go back on if the weight is ever taken away again.
var _player: Node2D = null
var _excepted: Array[PhysicsBody2D] = []


func _ready() -> void:
	add_to_group(&"floating_treads")
	_tags = get_node_or_null(^"/root/AbilityTags")
	# Contact reporting is what tells us anything is on top at all. Without it
	# get_colliding_bodies() is always empty and the tread can never be weighted.
	contact_monitor = true
	max_contacts_reported = 8


## THE PLAYER PASSES THROUGH A LOOSE PLANK, and setting the layer was never enough to say
## so. This body is on its own collision layer precisely so the player cannot use it as a
## free stepping stone -- but Godot pairs two bodies when EITHER side matches
## (`layer & other.mask || other.layer & mask`), and the mask here was still the default 1,
## which is the layer the player is on. So the pair existed after all: the apo walked
## through the plank exactly as intended and shoved it across the paddy on the way, because
## a kinematic body against a 0.6-mass rigid one wins every contact. That is the "the
## floating dirt just flies when I go in the water" report, and it looked like buoyancy.
##
## The mask cannot simply drop layer 1: the terrain, the placed drawings and the player are
## all on it, and a tread that ignores layer 1 also ignores the circle that is supposed to
## weigh it down. So the exception is against the player specifically, and it is lifted the
## moment the tread settles -- a settled tread is a step, and a step you fall through is
## worse than no step at all.
func except_player(body: Node2D) -> void:
	_player = body
	_drop_exceptions()
	if _settled:
		return
	_raise_exceptions()


func _raise_exceptions() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	for physics_body in _physics_bodies_of(_player):
		add_collision_exception_with(physics_body)
		_excepted.append(physics_body)


func _drop_exceptions() -> void:
	for physics_body in _excepted:
		if is_instance_valid(physics_body):
			remove_collision_exception_with(physics_body)
	_excepted.clear()


## Whatever the player is made of. A wanderer is one CharacterBody2D; a drawn creature is a
## rig of a dozen ActiveRigBody2D under its skin, and a swimmer has to pass through this
## just as the apo does. Walking the subtree answers both without either class having to
## grow a method for it.
func _physics_bodies_of(root: Node) -> Array[PhysicsBody2D]:
	var found: Array[PhysicsBody2D] = []
	var body := root as PhysicsBody2D
	if body != null:
		found.append(body)
	for child in root.get_children():
		found.append_array(_physics_bodies_of(child))
	return found


func is_settled() -> bool:
	return _settled


func settling_class() -> String:
	return _settling_class


func _physics_process(delta: float) -> void:
	if _settled:
		if not _still_loaded():
			_release()
		return
	var weight := _weighting_body()
	if weight == null:
		_loaded_for = 0.0
		return
	_settling_body = weight
	_settling_class = _class_of(weight)
	# SETTLED BY THE LOAD, NOT BY GOING STILL, and this is the change that made the beat
	# solvable. It used to wait for the sinking to stop, which meant waiting for a circle to
	# drag the plank the whole hundred pixels to the paddy floor -- a deck at y 640 under a
	# surface at 560, where standing on it is standing in the water and the player is fished
	# out by the drowning rescue a second later. What the lesson is actually about is that a
	# loose plank TIPS and a weighted one lies flat, so the weight being there is the whole
	# of the condition, and a short dwell is only there to tell a circle sitting on it from
	# a circle rolling over it.
	_loaded_for += delta
	if _loaded_for >= settle_dwell:
		_settle()


## The body resting on top that carries the required tag, or null.
func _weighting_body() -> Node2D:
	for body in get_colliding_bodies():
		if not _is_resting_on(body):
			continue
		var class_id := _class_of(body)
		if class_id.is_empty():
			continue
		if _tags != null and bool(_tags.call("class_has_tag", class_id, required_tag)):
			return body
	return null


## From ABOVE, and over the deck. Something floating against the plank's edge is not
## weighing it down.
func _is_resting_on(body: Node2D) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	if body.global_position.y >= global_position.y - contact_margin:
		return false
	# OVER THE DECK, not merely touching. The two horizontal extents have to overlap, or a
	# prop floating against the plank's end counts as sitting on it -- and after the plank
	# freezes, so does one that has rolled off and drifted away.
	var reach := _half_extent().x + contact_margin
	var prop := body as PhysicsShapeObject
	if prop != null:
		reach += prop.world_extent().size.x * 0.5
	return absf(body.global_position.x - global_position.x) <= reach


## WHETHER THE WEIGHT IS STILL THERE, asked of the body itself rather than of the contact
## list. A settled tread is frozen STATIC, and a static body reports no contacts of its
## own -- so re-deriving the load from get_colliding_bodies() after settling would come
## back empty on the very next frame and unfreeze the step out from under whoever was
## standing on it. What settled it is remembered instead, and the only question left is
## whether it is still sitting there.
func _still_loaded() -> bool:
	return _is_resting_on(_settling_body)


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
	_ride_the_waterline()
	# A SETTLED TREAD IS A STEP, so the player stops passing through it. The exceptions come
	# off and it joins layer 1 alongside its own -- keeping layer 4 as well, so anything
	# that was looking for a floating tread still finds one.
	_drop_exceptions()
	collision_layer |= 1
	settled.emit(_settling_class)


## Level with the water, deck dry. The plank floats where the water and its own weight
## agree; loaded, it lies flat and rides at the surface, and THAT is the height the beat
## needs -- see deck_clearance for what happens to a player standing below the waterline.
##
## The surface comes from the water itself, through the meta WaterArea2D already writes on
## every body inside it, so moving the paddy moves the deck and there is no second copy of
## the number. Writing global_position here is not the thing the note above forbids: that
## is about driving a LIVE rigid body, which the server overwrites the same frame. This one
## is frozen static by the line above, which is exactly the kind of body you place by hand.
func _ride_the_waterline() -> void:
	var water := get_meta("water_area", null) as Node2D
	if water == null:
		return
	var surface: Vector2 = water.get("surface_size")
	var surface_y: float = water.global_position.y - surface.y * 0.5
	# The DECK is what has to clear the water, so the plank's middle sits half a plank below
	# the line the deck wants to be on.
	var lift := surface_y - deck_clearance + _half_extent().y - global_position.y
	global_position.y += lift
	# AND THE LOAD COMES UP WITH IT. A weight rides the plank down while it is sinking, so
	# by the time the dwell is up the two can be sixty pixels under -- and a plank that
	# lifts out from under its own load lands inside it, whereupon the solver throws the
	# pair apart and the plank tumbles off across the paddy. Which is the exact thing this
	# beat exists to stop doing. It is one body and we are already holding it.
	var load_body := _settling_body as RigidBody2D
	if load_body != null and is_instance_valid(load_body):
		load_body.global_position.y += lift
		load_body.linear_velocity = Vector2.ZERO
		load_body.angular_velocity = 0.0


func _release() -> void:
	_settled = false
	_settling_class = ""
	_settling_body = null
	_loaded_for = 0.0
	collision_layer &= ~1
	freeze = false
	lock_rotation = false
	# Loose again, so the player passes through it again.
	_raise_exceptions()
	unsettled.emit()


## Half the plank, from its own collision rather than from a number typed here -- the shape
## is authored in the level and the deck height is measured off it.
func _half_extent() -> Vector2:
	for child in get_children():
		var collision := child as CollisionShape2D
		if collision != null and collision.shape != null and collision.shape.has_method("get_rect"):
			var rect: Rect2 = collision.shape.call("get_rect")
			return rect.size * 0.5
	return Vector2(44.0, 10.0)
