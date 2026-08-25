class_name FloatingTread2D
extends RigidBody2D
## Two of the stair treads, floated off into the paddy -- and sub-beat 0.1's whole lesson:
## the things in this world have weight, and weight is something you can use.
##
## IT IS THE WAY ACROSS THE WATER, which is the thing to understand before changing
## anything here. The paddy is three hundred pixels wide and nothing the beat accepts is
## eighty pixels across, let alone three hundred, so there is no drawing that spans it.
## What there is, is this: a loose plank you cannot stand on, and a way to make it stand
## still. Held down by something that rolls it locks level and becomes a deck with a
## sixty-two pixel hop at each end.
##
## LOOSE, IT IS NOT A STEP, and the player does not merely find that out -- they pass
## straight through it. Letting them stand on a plank they have not paid for halves the
## crossing for free, which is X3 in GATES.md; making the layer say so and leaving the mask
## alone is X14, and is why they shoved it the length of the paddy instead.
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
## How far BELOW the deck the weight's top is set once the plank has locked.
##
## THE WEIGHT BEDS INTO THE STONE, and this is a gameplay number, not a look. A drawn
## primitive is 80px and the deck is 176px of a 300px paddy, so a ball that size left
## standing on it is the crossing rather than something on the crossing. Both ways of
## leaving it up were measured and both fail. At its full eighty the player jumps the near
## gap, sails over a deck that is only eight pixels below the bank, lands on the ball at its
## apex, rolls off the far side with a full run's speed and eighty pixels of fall, and
## clears the whole far half of the deck to splash down twenty-one pixels short of the bank.
## Cut down to a cap of twenty-four they walk into it and stop, because a CharacterBody2D
## does not step up.
##
## Set flush, the deck is a deck. Four pixels under it, so the stone is unambiguously the
## surface being stood on and the physics has nothing to catch on. What is left to see of
## the drawing is the rest of it hanging under the plank in the water, which is where a
## thing holding a plank down belongs.
@export var load_bed_depth: float = 4.0
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
## list. A settled tread is frozen STATIC, and a static body reports no contacts of its own
## -- so re-deriving the load from get_colliding_bodies() after settling would come back
## empty on the very next frame and unfreeze the step out from under whoever was standing on
## it. Settling freezes the weight where it is bedded, so the only way it stops being there
## is the player taking it back, which is R8 and is what this is watching for.
func _still_loaded() -> bool:
	return _settling_body != null and is_instance_valid(_settling_body)


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
	global_position.y = surface_y - deck_clearance + _half_extent().y
	# AND THE WEIGHT BEDS INTO IT. It cannot simply be carried up with the plank: a weight
	# rides it down while it is sinking, so by the time the dwell is up the two can be sixty
	# pixels under, and a plank that lifts out from under its own load lands inside it and
	# the solver throws the pair apart. Nor can it be left sitting on top -- see
	# load_bed_depth for why an 80px ball on a 176px deck is the crossing, not a step on it.
	#
	# So it is set into the stone, flush with the deck, and frozen there. That is what
	# "settled" means for the pair of them: the weight is wedged, the plank cannot rise, and
	# the deck is something to walk on. Taking the weight back releases both.
	var load_body := _settling_body as RigidBody2D
	if load_body != null and is_instance_valid(load_body):
		var deck := global_position.y - _half_extent().y
		load_body.global_position.y = deck + load_bed_depth + _half_of(load_body).y
		load_body.linear_velocity = Vector2.ZERO
		load_body.angular_velocity = 0.0
		load_body.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		load_body.freeze = true


func _release() -> void:
	_settled = false
	_settling_class = ""
	_loaded_for = 0.0
	collision_layer &= ~1
	freeze = false
	lock_rotation = false
	# VALID FIRST, CAST SECOND. This runs when the weight has STOPPED being there, and the
	# ordinary way for that to happen is the player picking it up, which frees it -- and
	# `freed as RigidBody2D` is an error in Godot 4, not a null. It only ever printed to the
	# log, so every suite stayed green and only the bot walking the whole level found it.
	if is_instance_valid(_settling_body):
		var load_body := _settling_body as RigidBody2D
		if load_body != null:
			load_body.freeze = false
	_settling_body = null
	# Loose again, so the player passes through it again.
	_raise_exceptions()
	unsettled.emit()


## Half the plank, from its own collision rather than from a number typed here -- the shape
## is authored in the level and the deck height is measured off it.
func _half_extent() -> Vector2:
	var half := _half_of(self)
	return half if half != Vector2.ZERO else Vector2(88.0, 10.0)


## Half a body's own collision box.
func _half_of(body: Node) -> Vector2:
	var prop := body as PhysicsShapeObject
	if prop != null:
		return prop.world_extent().size * 0.5
	for child in body.get_children():
		var collision := child as CollisionShape2D
		if collision != null and collision.shape != null and collision.shape.has_method("get_rect"):
			return Rect2(collision.shape.call("get_rect")).size * 0.5
	return Vector2.ZERO
