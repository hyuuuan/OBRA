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
	Signpost2D.plant(self, Signpost2D.Mark.MEMORY)


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
