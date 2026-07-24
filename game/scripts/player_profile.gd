extends Node
## Persistent player profile — the file-based save store the thesis describes.
##
## Thesis §4.5.2: "The system uses no database. ... Player progress is persisted
## locally through a player profile that records ... unlocked classes, completed
## levels, and routes taken", written as "a single profile file to the host's user
## data directory in which progression and accumulated telemetry are stored between
## sessions."
##
## One JSON document at user://profile.json, written atomically (temp file then
## rename) so a crash mid-write cannot corrupt the live profile. An unreadable or
## schema-incompatible profile is treated as a new profile, never a fatal error
## (thesis §3.2.8: a profile may be "absent on first launch, truncated by a power"
## loss ... "as a new profile rather than as a fatal error").

signal profile_changed

const PROFILE_PATH := "user://profile.json"
const ENTITIES_PATH := "res://config/entities.json"
const SCHEMA_VERSION := 1
const DEFAULT_ROSTER_SIZE := 50

var _data: Dictionary = {}
var _roster_ids: Dictionary = {}  # entity_id -> true, the recognised class roster
var _roster_size: int = DEFAULT_ROSTER_SIZE


func _ready() -> void:
	_load_roster()
	load_profile()


func _default_profile() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"unlocked_classes": [],          # classes the player has been taught (future gate)
		"classes_drawn_accepted": [],    # distinct classes drawn and accepted at least once
		"levels_completed": [],
		"levels_unlocked": [],
		"routes": {},                    # level_id -> route taken (populated by branching, future)
		"collectibles": [],
		"counts": {"submissions": 0, "declines": 0},
	}


## Reload the profile from disk, falling back to a fresh profile on any problem.
func load_profile() -> void:
	_data = _default_profile()
	if not FileAccess.file_exists(PROFILE_PATH):
		return
	var text := FileAccess.get_file_as_string(PROFILE_PATH)
	if text.is_empty():
		return
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("Player profile unreadable; starting a new profile")
		return
	var incoming := parsed as Dictionary
	if int(incoming.get("schema_version", -1)) != SCHEMA_VERSION:
		push_warning("Player profile schema mismatch; starting a new profile")
		return
	_data = _merge_defaults(incoming)


## Persist the profile atomically. Returns true on success.
func save_profile() -> bool:
	return _atomic_write(PROFILE_PATH, JSON.stringify(_data, "  "))


# --- Progression -------------------------------------------------------------

## Record that a class was drawn and accepted by the recogniser. Feeds class
## diversity (thesis §3.2.8: "distinct classes ... drawn and had accepted at least
## once ... out of fifty ... rises monotonically and never falls").
func record_class_drawn(entity_id: String) -> void:
	if entity_id.is_empty():
		return
	var accepted: Array = _data["classes_drawn_accepted"]
	if not accepted.has(entity_id):
		accepted.append(entity_id)
		_commit()


## Count one submission and, if it was declined by the recogniser, one decline.
## Backs the redraw rate (thesis §3.2.8).
func note_submission(accepted: bool) -> void:
	var counts: Dictionary = _data["counts"]
	counts["submissions"] = int(counts.get("submissions", 0)) + 1
	if not accepted:
		counts["declines"] = int(counts.get("declines", 0)) + 1
	_commit()


## Mark a level complete and unlock the next one so progression survives sessions.
func mark_level_completed(level_id: String) -> void:
	if level_id.is_empty():
		return
	var changed := false
	var completed: Array = _data["levels_completed"]
	if not completed.has(level_id):
		completed.append(level_id)
		changed = true
	var next_id := _next_level_id(level_id)
	if not next_id.is_empty():
		var unlocked: Array = _data["levels_unlocked"]
		if not unlocked.has(next_id):
			unlocked.append(next_id)
			changed = true
	if changed:
		_commit()


func is_level_unlocked(level_id: String) -> bool:
	return (_data["levels_unlocked"] as Array).has(level_id)


func is_level_completed(level_id: String) -> bool:
	return (_data["levels_completed"] as Array).has(level_id)


## Record the narrative route chosen for a level (schema-ready; the branching
## system that produces routes is out of scope, so this stays empty until then).
func record_route(level_id: String, route: String) -> void:
	if level_id.is_empty():
		return
	(_data["routes"] as Dictionary)[level_id] = route
	_commit()


func record_collectible(collectible_id: String) -> void:
	if collectible_id.is_empty():
		return
	var found: Array = _data["collectibles"]
	if not found.has(collectible_id):
		found.append(collectible_id)
		_commit()


# --- Derived quantities ------------------------------------------------------

## Number of distinct roster classes drawn and accepted at least once.
func class_diversity() -> int:
	var n := 0
	for entity_id: Variant in _data["classes_drawn_accepted"]:
		if _roster_ids.is_empty() or _roster_ids.has(entity_id):
			n += 1
	return n


func roster_size() -> int:
	return _roster_size


## Proportion of submitted drawings the recogniser declined.
func redraw_rate() -> float:
	var counts: Dictionary = _data["counts"]
	var submissions := int(counts.get("submissions", 0))
	if submissions <= 0:
		return 0.0
	return float(counts.get("declines", 0)) / float(submissions)


## Read-only copy of the raw profile (for telemetry folding and tests).
func get_snapshot() -> Dictionary:
	return _data.duplicate(true)


# --- Internals ---------------------------------------------------------------

func _commit() -> void:
	save_profile()
	profile_changed.emit()


func _merge_defaults(incoming: Dictionary) -> Dictionary:
	var base := _default_profile()
	for key: Variant in incoming.keys():
		base[key] = incoming[key]
	if not (base["counts"] is Dictionary):
		base["counts"] = {"submissions": 0, "declines": 0}
	return base


func _next_level_id(level_id: String) -> String:
	var separator := level_id.rfind("_")
	if separator < 0:
		return ""
	var number_part := level_id.substr(separator + 1)
	if not number_part.is_valid_int():
		return ""
	return level_id.substr(0, separator + 1) + str(number_part.to_int() + 1)


func _atomic_write(path: String, text: String) -> bool:
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open %s for writing (err %d)" % [tmp_path, FileAccess.get_open_error()])
		return false
	file.store_string(text)
	file.close()  # flush before rename so the swap is of a complete file
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		push_error("Could not open profile directory: %s" % path.get_base_dir())
		return false
	var tmp_name := tmp_path.get_file()
	var final_name := path.get_file()
	var err := dir.rename(tmp_name, final_name)
	if err != OK:
		# Some platforms refuse to overwrite on rename; drop the stale file and retry.
		dir.remove(final_name)
		err = dir.rename(tmp_name, final_name)
	if err != OK:
		push_error("Could not finalise profile write (err %d)" % err)
		return false
	return true


func _load_roster() -> void:
	_roster_ids.clear()
	_roster_size = DEFAULT_ROSTER_SIZE
	var text := FileAccess.get_file_as_string(ENTITIES_PATH)
	if text.is_empty():
		return
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary) or not (parsed as Dictionary).has("entities"):
		return
	for entry: Variant in (parsed as Dictionary)["entities"]:
		if entry is Dictionary and bool((entry as Dictionary).get("enabled", true)):
			var entity_id := String((entry as Dictionary).get("id", ""))
			if not entity_id.is_empty():
				_roster_ids[entity_id] = true
	if _roster_ids.size() > 0:
		_roster_size = _roster_ids.size()
