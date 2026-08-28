class_name ConceptGate2D
extends Node2D
## An obstacle that opens only for a player who has acquired a required concept
## (an object/tool id such as "torch" or "ladder").
##
## The check reads the persistent player profile rather than any level-local state,
## which is what makes backtracking work: acquiring the concept in a later level
## retroactively opens every gate that needs it, in any level and any later session,
## with no extra bookkeeping.
##
## Level scenes connect to `passage_blocked` to surface `hint_text` and offer a return
## to the hub, and to `passage_allowed` to open the obstacle.

## The dialogue hook this gate's board re-reads. Whatever fires it must be played at least
## once, or the board stays inert -- see Signpost2D.reads and GameLevel._readable_sign.
@export var sign_hook: String = "L1_N1.cave"
## How close the player has to come before the gate answers.
@export var reach_size := Vector2(220.0, 200.0)

## How many of the player's bodies are standing in reach.
var _inside := 0

signal passage_allowed(concept_id: String)
signal passage_blocked(concept_id: String, hint: String)

## Object/tool id the player must own; must match an entity id in entities.json.
@export var required_concept_id: String = ""
## Player-facing hint shown when the gate is blocked. Falls back to a generated line.
@export var hint_text: String = ""
## When true the gate stays open once passed, even if the profile is later unavailable.
@export var stays_open: bool = true

var is_open: bool = false


func _ready() -> void:
	# An already-satisfied gate should present as open the moment the level loads,
	# so a returning player does not have to re-trigger it.
	if not required_concept_id.is_empty() and can_pass():
		is_open = true
	# A gate is a promise about what is behind it, and the cave has a memory in it.
	# AND IT CAN BE READ. Planted with no hook, this board could never be offered:
	# `GameLevel._readable_sign` skips any sign whose hook has not already played. So the one
	# marker standing at the one optional thing in Level 1 was scenery, and pressing the
	# interact key at it did nothing -- the same defect the chest in the straw room had.
	# The hook is fired by the level the first time the gate refuses or opens.
	Signpost2D.plant(self, Signpost2D.Mark.FIND, Vector2(-40.0, 0.0), sign_hook)
	_build_reach()


## ⚠ NOTHING EVER CALLED try_pass(). This gate was a Node2D with a concept id and no trigger
## of any kind, so `passage_blocked` and `passage_allowed` had never fired in the built game
## -- the level asked `can_pass()` once at load and that was the whole of it. If the player
## did not already own the concept when the level opened, the thing behind this gate could
## never be revealed, no matter what they drew afterwards. That is the whole of "I can't get
## the hidden flower even if I decided to get it".
##
## Walked into, like every other offer in this level. It re-asks each time, so drawing the
## concept and coming back opens it.
func _build_reach() -> void:
	var area := Area2D.new()
	area.name = "Reach"
	area.collision_layer = 0
	area.collision_mask = 1
	add_child(area)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = reach_size
	shape.shape = box
	shape.position = Vector2(0.0, -reach_size.y * 0.5)
	area.add_child(shape)
	area.body_entered.connect(_on_reach_entered)
	area.body_exited.connect(_on_reach_left)


func _on_reach_entered(body: Node) -> void:
	if not _is_the_player(body):
		return
	# COUNTED, because a drawn creature is many bodies and they arrive one at a time. Asking
	# on every one of them would refuse the player a dozen times in a dozen frames.
	_inside += 1
	if _inside == 1:
		try_pass()


func _on_reach_left(body: Node) -> void:
	if _is_the_player(body):
		_inside = maxi(0, _inside - 1)


func _is_the_player(body: Node) -> bool:
	var node := body as Node
	while node != null:
		if node.is_in_group(&"player_character") or node is ActiveRagdollMorph:
			return true
		node = node.get_parent()
	return false


## True when the player owns the required concept. An empty requirement is an open gate.
func can_pass() -> bool:
	if required_concept_id.is_empty():
		return true
	if is_open and stays_open:
		return true
	var profile := get_node_or_null(^"/root/PlayerProfile")
	if profile == null:
		return false
	return bool(profile.has_object(required_concept_id))


## Attempt passage. Emits the matching signal and reports the outcome.
func try_pass() -> Dictionary:
	if can_pass():
		if stays_open:
			is_open = true
		passage_allowed.emit(required_concept_id)
		return {"passed": true, "concept": required_concept_id, "hint": ""}
	var hint := effective_hint()
	passage_blocked.emit(required_concept_id, hint)
	return {"passed": false, "concept": required_concept_id, "hint": hint}


func effective_hint() -> String:
	if not hint_text.is_empty():
		return hint_text
	return "You need a %s to get past this." % required_concept_id.capitalize()
