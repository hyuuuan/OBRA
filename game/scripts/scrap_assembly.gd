class_name ScrapAssembly
extends Node
## Scene 3: seven pieces into seven slots, and then Piyesta is whole.
##
## KEEP IT LIGHT. The design is explicit that this is a light interaction and not a puzzle
## with a fail state at the end of the level -- the player has already answered three nodes
## and crossed two alleys, and a jigsaw here would make the reward into one more obstacle.
## So: drag with a snap, no timer, no wrong answers, and the only thing that can happen is
## that it finishes.
##
## The pieces are cut from Level2_CompletedLook along IRREGULAR TEAR LINES rather than a
## grid, which is why a slot is matched by ID and not by geometry -- torn edges do not tile,
## and a nearest-corner test on seven ragged shapes is a worse experience than a snap.
##
## THE CREASE IS DRAWN ON TOP AND CHANGES NOTHING ELSE. If the player cut Lola's canvas open
## in Level 1 the fold runs through the finished picture. It does not change the piece count,
## the paths, or the ending -- see LEVEL_1.md, where that is recorded as a debt rather than
## as a design.

signal piece_placed(scrap_id: String, placed: int, total: int)
signal assembled(creased: bool)

const SLOTS := 7
## How close a dragged piece has to be dropped before it takes its slot. Generous, because
## the alternative to a generous snap is a player fighting a picture they have earned.
const SNAP_RADIUS := 96.0

var _slots: Dictionary = {}       # scrap_id -> slot position
var _filled: Dictionary = {}      # scrap_id -> true
var _creased := false


## The seven slots, as scrap_id -> where that piece belongs.
func set_slots(slots: Dictionary) -> void:
	_slots = slots.duplicate()
	_filled.clear()


func slot_count() -> int:
	return _slots.size()


func placed() -> int:
	return _filled.size()


func remaining() -> int:
	return _slots.size() - _filled.size()


func is_complete() -> bool:
	return not _slots.is_empty() and _filled.size() >= _slots.size()


## Whether the finished picture carries Level 1's fold. Read from the profile by the level
## and handed in, so this node stays testable without one.
func set_creased(creased: bool) -> void:
	_creased = creased


func is_creased() -> bool:
	return _creased


## Where a piece belongs, or a very large distance if this is not one of the seven.
func distance_to_slot(scrap_id: String, from: Vector2) -> float:
	if not _slots.has(scrap_id):
		return INF
	return from.distance_to(_slots[scrap_id] as Vector2)


func would_snap(scrap_id: String, from: Vector2) -> bool:
	return distance_to_slot(scrap_id, from) <= SNAP_RADIUS


## Drop a piece. Returns whether it took its slot.
##
## Idempotent like the ledger's recover(), and for the same reason: a piece released twice
## -- a double click, a drag that ends on the frame the screen opens -- must not count as
## two of seven.
func drop(scrap_id: String, at: Vector2) -> bool:
	if not _slots.has(scrap_id) or _filled.has(scrap_id):
		return false
	if not would_snap(scrap_id, at):
		return false
	_filled[scrap_id] = true
	piece_placed.emit(scrap_id, _filled.size(), _slots.size())
	if is_complete():
		assembled.emit(_creased)
	return true


## Put it where it goes without asking. THE LEVEL MUST NOT BE ABLE TO END HALF-ASSEMBLED:
## if anything ever needs to finish this on the player's behalf -- an accessibility option,
## a skip, a restored checkpoint that arrives with all seven already held -- it goes through
## here rather than through a second copy of the completion rule.
func place_now(scrap_id: String) -> bool:
	if not _slots.has(scrap_id) or _filled.has(scrap_id):
		return false
	return drop(scrap_id, _slots[scrap_id] as Vector2)


func place_all() -> int:
	var count := 0
	for scrap_id: Variant in _slots.keys():
		if place_now(String(scrap_id)):
			count += 1
	return count
