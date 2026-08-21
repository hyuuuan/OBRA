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
signal settings_changed(key: String, value: Variant)

const PROFILE_PATH := "user://profile.json"
const ENTITIES_PATH := "res://config/entities.json"
const SCHEMA_VERSION := 4
const DEFAULT_ROSTER_SIZE := 50
## Older schemas that can be migrated forward instead of being discarded.
## v3 -> v4 added unlocked_tags; _merge_defaults supplies it, so a v3 profile keeps
## every level, route and object it had and simply starts with no tags unlocked.
const MIGRATABLE_SCHEMAS := [1, 2, 3]
const ROUTES := ["artist", "pragmatist", "protector"]

## Every setting the player can change, with its default. Nothing outside this list
## is storable: a typo must not quietly grow the save, because each key written here
## is a key every future migration has to keep understanding.
##
## Volumes are LINEAR 0..1 -- what a slider shows. The audio layer converts to dB,
## because dB is a display-hostile scale to persist and linear_to_db(0.0) is -inf.
const SETTING_DEFAULTS := {
	"master_volume": 1.0,
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"fullscreen": false,
}

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
		"unlocked_tags": [],             # ability tags the player has been taught, across levels
		"classes_drawn_accepted": [],    # distinct classes drawn and accepted at least once
		"acquired_objects": [],          # object/tool ids owned across levels and sessions
		"levels_completed": [],
		"levels_unlocked": [],
		"routes": {},                    # level_id -> most recent route taken
		"route_counts": {"artist": 0, "pragmatist": 0, "protector": 0},
		"collectibles": [],
		"counts": {"submissions": 0, "declines": 0},
		"settings": _default_settings(),
	}


func _default_settings() -> Dictionary:
	return SETTING_DEFAULTS.duplicate(true)


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
	var version := int(incoming.get("schema_version", -1))
	if version != SCHEMA_VERSION and version not in MIGRATABLE_SCHEMAS:
		push_warning("Player profile schema mismatch; starting a new profile")
		return
	# Older-but-known schemas keep their progress: missing fields fall back to the
	# defaults and the profile is stamped forward on the next save.
	_data = _merge_defaults(incoming)
	_data["schema_version"] = SCHEMA_VERSION


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


## Record an object/tool the player has acquired. Ownership is global and permanent:
## a concept acquired in a later level retroactively opens every gate that needs it.
func record_object_acquired(entity_id: String) -> void:
	if entity_id.is_empty():
		return
	var owned: Array = _data["acquired_objects"]
	if not owned.has(entity_id):
		owned.append(entity_id)
		_commit()


## The backtracking gate's "can pass?" query.
func has_object(entity_id: String) -> bool:
	return (_data["acquired_objects"] as Array).has(entity_id)


## Design-language alias for has_object().
func is_concept_unlocked(concept_id: String) -> bool:
	return has_object(concept_id)


func acquired_objects() -> Array:
	return (_data["acquired_objects"] as Array).duplicate()


## Record the narrative route chosen at a dialogue node. Both the per-level choice
## and a cumulative tally are kept: the tally drives ending selection and must not be
## overwritten when a level is replayed.
func record_route(level_id: String, route: String) -> void:
	if level_id.is_empty() or route not in ROUTES:
		return
	(_data["routes"] as Dictionary)[level_id] = route
	var counts: Dictionary = _data["route_counts"]
	counts[route] = int(counts.get(route, 0)) + 1
	_commit()


func route_counts() -> Dictionary:
	return (_data["route_counts"] as Dictionary).duplicate()


func route_count(route: String) -> int:
	return int((_data["route_counts"] as Dictionary).get(route, 0))


## Ability tags the player has been taught. These accumulate ACROSS levels and never
## fall: the Ability Book is a record of what has been learned, and a tag taught in
## Payyo is still known in Pista. Obstacles resolve their solutions from tags, so this
## is also what decides whether a drawing spawns with its ability or spawns inert.
## The distinct classes the player has drawn and had accepted. The Ability Book shows
## the player their OWN qualifying drawings for an obstacle, which is a different thing
## from the classes that would qualify -- the book is a record of what they have done.
func get_drawn_classes() -> Array:
	return (_data["classes_drawn_accepted"] as Array).duplicate()


func record_tag_unlocked(tag: String) -> void:
	if tag.is_empty():
		return
	var tags: Array = _data["unlocked_tags"]
	if not tags.has(tag):
		tags.append(tag)
		_commit()


func is_tag_unlocked(tag: String) -> bool:
	return (_data["unlocked_tags"] as Array).has(tag)


func unlocked_tags() -> Array:
	return (_data["unlocked_tags"] as Array).duplicate()


func record_collectible(collectible_id: String) -> void:
	if collectible_id.is_empty():
		return
	var found: Array = _data["collectibles"]
	if not found.has(collectible_id):
		found.append(collectible_id)
		_commit()


func is_collectible_found(collectible_id: String) -> bool:
	return (_data["collectibles"] as Array).has(collectible_id)


func collectible_count() -> int:
	return (_data["collectibles"] as Array).size()


# --- Settings ----------------------------------------------------------------

## Read-only copy of every setting, with each key guaranteed present.
func get_settings() -> Dictionary:
	return (_data["settings"] as Dictionary).duplicate(true)


func get_setting(key: String) -> Variant:
	return (_data["settings"] as Dictionary).get(key, SETTING_DEFAULTS.get(key))


## Store one setting and persist immediately.
##
## This writes the WHOLE profile, atomically, on every call. A slider dragged across
## its track emits value_changed once per pixel, so a settings screen must apply the
## change live through AudioDirector and call this only when the drag ends and when
## it closes. Applying and persisting are separate for exactly that reason.
##
## An unchanged value is dropped before the write, so a slider returned to where it
## started costs nothing.
func set_setting(key: String, value: Variant) -> void:
	if not SETTING_DEFAULTS.has(key):
		push_warning("Unknown player setting '%s' ignored" % key)
		return
	var stored: Variant = _coerce_setting(key, value)
	var settings: Dictionary = _data["settings"]
	if settings.get(key) == stored:
		return
	settings[key] = stored
	_commit()
	settings_changed.emit(key, stored)


## Force a stored value into the shape its default declares. A hand-edited profile
## carrying "master_volume": 7 must not be able to deafen anyone, and a JSON round
## trip turns every number into a float whether it was written as one or not.
func _coerce_setting(key: String, value: Variant) -> Variant:
	if typeof(SETTING_DEFAULTS[key]) == TYPE_BOOL:
		return bool(value)
	return clampf(float(value), 0.0, 1.0)


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
	if not (base["route_counts"] is Dictionary):
		base["route_counts"] = {"artist": 0, "pragmatist": 0, "protector": 0}
	else:
		for route in ROUTES:  # a partial tally from an older save must still resolve
			var counts: Dictionary = base["route_counts"]
			counts[route] = int(counts.get(route, 0))
	for key in ["acquired_objects", "collectibles", "classes_drawn_accepted", "levels_completed", "levels_unlocked", "unlocked_tags"]:
		if not (base[key] is Array):
			base[key] = []
	# A v2 profile has no settings block at all and simply keeps the defaults above.
	# The case that needs work is a PARTIAL one -- written before a setting existed,
	# or hand-edited -- because the loop over incoming keys replaced the whole
	# dictionary wholesale and every key it omitted would be gone. The settings screen
	# reads all of them unconditionally, so each has to resolve.
	if not (base["settings"] is Dictionary):
		base["settings"] = _default_settings()
	else:
		var settings: Dictionary = base["settings"]
		for key: Variant in SETTING_DEFAULTS.keys():
			settings[key] = _coerce_setting(String(key), settings.get(key, SETTING_DEFAULTS[key]))
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
