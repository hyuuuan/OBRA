class_name ScrapLedger
extends Node
## The seven pieces of the Pista painting, and the one promise the design makes about them:
## **none can be permanently lost.**
##
## That promise is the whole reason this is a ledger rather than a counter. Five scraps are
## carried by the flock in Alley 1 and two are up in the bandaritas in Alley 2, and every
## route through Alley 1 ends with a DIFFERENT number of them still airborne: feeding brings
## all five down, chasing sends all five on ahead, and knocking them down leaves however many
## the timer did not reach. A player who downs three of five must walk into Alley 2 and find
## exactly two waiting -- not five, not zero, and not a fail screen.
##
## So the count that survives Alley 1 is a NUMBER, not a flag, and Alley 2 spawns from it.
## `BIRDS_IN_ALLEY2` in the design; `deferred()` here.
##
## RIDES THE CHECKPOINT. Scraps are level-scoped run state like the pickups, not profile
## state like a route tally: dying in Alley 2 must not undo Alley 1, and finishing the level
## twice must not hand out fourteen scraps.

signal scrap_recovered(scrap_id: String, held: int, total: int)
signal all_recovered()

## Seven is the design's number and it is load-bearing in two directions: enough that the
## assembly in Scene 3 reads as a real reconstruction, few enough that it stays a light
## interaction rather than a jigsaw.
const TOTAL := 7
const IN_ALLEY_1 := 5
const IN_ALLEY_2 := 2

var _held: Dictionary = {}        # scrap_id -> true
var _deferred := 0                # carried on to the next screen rather than lost


func reset() -> void:
	_held.clear()
	_deferred = 0


func total() -> int:
	return TOTAL


func held() -> int:
	return _held.size()


func has(scrap_id: String) -> bool:
	return _held.has(scrap_id)


func remaining() -> int:
	return TOTAL - _held.size()


## Idempotent on purpose: a trigger swept twice, or a scrap picked up on the frame a
## checkpoint restores, must not count twice. The bug this prevents is a player finishing
## with eight of seven.
func recover(scrap_id: String) -> bool:
	if scrap_id.is_empty() or _held.has(scrap_id):
		return false
	_held[scrap_id] = true
	scrap_recovered.emit(scrap_id, _held.size(), TOTAL)
	if _held.size() >= TOTAL:
		all_recovered.emit()
	return true


func recover_many(scrap_ids: Array) -> int:
	var count := 0
	for value: Variant in scrap_ids:
		if recover(String(value)):
			count += 1
	return count


# --- What Alley 1 hands to Alley 2 ---------------------------------------------------

## However many of the flock got away, to be found tangled in the bandaritas next screen.
## Never negative and never more than the five that were there.
func defer(count: int) -> void:
	_deferred = clampi(count, 0, IN_ALLEY_1)


func deferred() -> int:
	return _deferred


## Taking the deferred ones back, once Alley 2 has spawned them and the player has freed
## them. Clears the debt so a checkpoint restore cannot spawn them a second time.
func claim_deferred() -> int:
	var claimed := _deferred
	_deferred = 0
	return claimed


## THE INVARIANT, asked directly so a test can assert it rather than infer it: everything
## not yet in hand is still reachable somewhere. This is false only if a route dropped a
## scrap on the floor, which is the one thing the design forbids.
func all_still_reachable(reachable_now: int) -> bool:
	return _held.size() + reachable_now + _deferred >= TOTAL


func is_complete() -> bool:
	return _held.size() >= TOTAL


# --- Checkpoint state ----------------------------------------------------------------

func serialize() -> Dictionary:
	var ids := _held.keys()
	ids.sort()
	return {"held": ids, "deferred": _deferred}


func restore(state: Dictionary) -> void:
	_held.clear()
	for value: Variant in state.get("held", []):
		_held[String(value)] = true
	_deferred = clampi(int(state.get("deferred", 0)), 0, IN_ALLEY_1)
