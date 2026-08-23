class_name CheckpointManager
extends Node
## Level-scoped checkpoints: what the player gets back when they die.
##
## THE RULE THAT DECIDES WHERE THESE GO: a checkpoint is written the instant a route is
## committed, immediately after the dialogue choice. That does two jobs with one write.
## It puts a checkpoint in front of every morph on that route, which is REQ-4.9-1 -- a
## player who becomes a fish above a gorge must not lose the last ten minutes to it. And
## it stops a death replaying the choice, which matters more than it sounds: being asked
## "what kind of person are you" twice in ninety seconds turns the level's one real
## question into a menu.
##
## IN MEMORY, NOT ON DISK, and deliberately. A checkpoint answers "restart from here"
## inside one sitting. Progress that must outlive the session -- the route tally, the
## level unlock, the tags learned -- goes to PlayerProfile instead, which is a different
## question with a different lifetime. Mixing them would make a mid-level death rewind
## things that are not the level's to rewind.
##
## The manager holds snapshots and nothing else. It does not know what ink is, or what a
## placed object is; the level builds the dictionary and reads it back. That is what
## keeps this testable without a world, and what stops it growing a dependency on every
## system it has to preserve.

signal checkpoint_written(checkpoint_id: String)
signal checkpoint_restored(checkpoint_id: String)

## Every snapshot taken this level, oldest first. Kept rather than overwritten so the
## telemetry can report how many times each was used, and so a later "return to the last
## node" affordance has somewhere to read from.
var _snapshots: Array[Dictionary] = []
var _restore_counts: Dictionary = {}


func clear() -> void:
	_snapshots.clear()
	_restore_counts.clear()


func has_checkpoint() -> bool:
	return not _snapshots.is_empty()


func count() -> int:
	return _snapshots.size()


func latest_id() -> String:
	return "" if _snapshots.is_empty() else String(_snapshots[-1].get("id", ""))


func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for snapshot in _snapshots:
		out.append(String(snapshot.get("id", "")))
	return out


func restore_count(checkpoint_id: String) -> int:
	return int(_restore_counts.get(checkpoint_id, 0))


## Take a snapshot. `state` is the level's business: position, ink, toolbelt, placed
## entities, obstacle state. Duplicated deep on the way in so a later mutation of the
## live world cannot reach backwards and edit the past -- the bug this prevents is a
## checkpoint that silently becomes a copy of the present.
func write(checkpoint_id: String, state: Dictionary) -> void:
	if checkpoint_id.is_empty():
		push_warning("CheckpointManager: refusing to write a checkpoint with no id")
		return
	# Re-committing the same checkpoint replaces it rather than stacking. Re-entering a
	# trigger area is not progress, and a stack of identical snapshots would make
	# restore_count meaningless.
	for index in range(_snapshots.size()):
		if String(_snapshots[index].get("id", "")) == checkpoint_id:
			_snapshots[index] = _snapshot(checkpoint_id, state)
			checkpoint_written.emit(checkpoint_id)
			return
	_snapshots.append(_snapshot(checkpoint_id, state))
	checkpoint_written.emit(checkpoint_id)


func _snapshot(checkpoint_id: String, state: Dictionary) -> Dictionary:
	return {
		"id": checkpoint_id,
		"written_msec": Time.get_ticks_msec(),
		"state": state.duplicate(true),
	}


## The most recent snapshot's state, deep-copied so the caller may consume it destructively
## without damaging the checkpoint it will need again on the next death. Empty when nothing
## has been written -- the caller decides whether that means "restart the level".
func restore() -> Dictionary:
	if _snapshots.is_empty():
		return {}
	var snapshot := _snapshots[-1]
	var checkpoint_id := String(snapshot.get("id", ""))
	_restore_counts[checkpoint_id] = int(_restore_counts.get(checkpoint_id, 0)) + 1
	checkpoint_restored.emit(checkpoint_id)
	return (snapshot["state"] as Dictionary).duplicate(true)


## Look without consuming, and without counting a restore. For tests and for the HUD
## indicator, which wants to name the checkpoint without pretending to use it.
func peek(checkpoint_id: String = "") -> Dictionary:
	if _snapshots.is_empty():
		return {}
	if checkpoint_id.is_empty():
		return (_snapshots[-1]["state"] as Dictionary).duplicate(true)
	for snapshot in _snapshots:
		if String(snapshot.get("id", "")) == checkpoint_id:
			return (snapshot["state"] as Dictionary).duplicate(true)
	return {}


## Total restores this level, for the telemetry line the spec asks for.
func total_restores() -> int:
	var total := 0
	for value: Variant in _restore_counts.values():
		total += int(value)
	return total
