class_name ScrapLedger
extends Node
## The seven pieces of the Dagat painting -- the NEXT level's, which is how Piyesta hands the
## player on -- and the one promise the design makes about them:
## **none can be permanently lost.**
##
## Five are carried by the flock in Alley 1 and two by the flock in Alley 2. Every way through
## an alley ends with all of that alley's pieces on its floor -- fed, cut down or knocked down,
## nothing flies off with one -- and the way on out of an alley does not open until the player
## has picked up every piece lying there. So nothing is carried from one screen to the next and
## there is nothing to defer: the ledger is a set of which pieces are in hand.
##
## ⚠ IT USED TO CARRY A DEBT. The first flock was on a timer and whatever it did not reach flew
## on to Alley 2, so the ledger kept a count of escapees and Alley 2 spawned that many tangled
## birds. Kent: nothing escapes, no timer -- so the debt, and the whole second road the scraps
## could travel by, is gone rather than kept at zero.
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


func reset() -> void:
	_held.clear()


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


## THE INVARIANT, asked directly so a test can assert it rather than infer it: everything
## not yet in hand is still reachable somewhere -- in a beak, or lying on a floor. This is
## false only if a route lost a scrap, which is the one thing the design forbids.
func all_still_reachable(reachable_now: int) -> bool:
	return _held.size() + reachable_now >= TOTAL


func is_complete() -> bool:
	return _held.size() >= TOTAL


# --- Checkpoint state ----------------------------------------------------------------

func serialize() -> Dictionary:
	var ids := _held.keys()
	ids.sort()
	return {"held": ids}


func restore(state: Dictionary) -> void:
	_held.clear()
	for value: Variant in state.get("held", []):
		_held[String(value)] = true
