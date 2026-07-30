extends Node
## In-game telemetry — the automatic, anonymous, local behavioural log the thesis
## describes (§4.2 In-game telemetry; §4.7 "Optional end-to-end timing logs on both
## the game and the recognition backend"). Nothing leaves the host and no
## identifying information is collected.
##
## Each play session appends a structured event stream to
## user://telemetry/session_<UTC>.jsonl (one JSON object per line). The cumulative
## derived counts the game reasons about between sessions (class diversity, redraw
## rate) live in the persistent PlayerProfile instead — see player_profile.gd.

const TELEMETRY_DIR := "user://telemetry"

var _file: FileAccess = null
var _session_path: String = ""
var _session_active := false
var _current_level := ""
var _level_start_msec := 0


func _ready() -> void:
	_begin_session()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		end_session()


# --- Public API --------------------------------------------------------------

## Open a level record. Closes any still-open level as "abandoned" first so the
## completion-rate telemetry stays consistent.
func begin_level(level_id: String) -> void:
	if not _current_level.is_empty() and _level_start_msec > 0:
		end_level(_current_level, "abandoned")
	_current_level = level_id
	_level_start_msec = Time.get_ticks_msec()
	record_event("level_start", {"level_id": level_id})


func end_level(level_id: String, outcome: String) -> void:
	var seconds := 0.0
	if _level_start_msec > 0:
		seconds = float(Time.get_ticks_msec() - _level_start_msec) / 1000.0
	record_event("level_end", {
		"level_id": level_id,
		"outcome": outcome,
		"time_on_level_s": seconds,
	})
	_current_level = ""
	_level_start_msec = 0


## Record one recognition outcome. `fields` carries the per-submission record the
## thesis wants for live recognition performance: outcome (accept|decline), entity,
## source_label, confidence, margin, runner_up, latency_ms, and (when the intended
## class is known) intended_class. A decline is the redraw signal.
func record_recognition(fields: Dictionary) -> void:
	record_event("recognition", fields)


## Append an arbitrary typed event to the session log.
func record_event(type: String, fields: Dictionary) -> void:
	if not _session_active or _file == null:
		return
	var event := {
		"type": type,
		"ts": Time.get_unix_time_from_system(),
		"iso": Time.get_datetime_string_from_system(true),
	}
	for key: Variant in fields.keys():
		event[key] = fields[key]
	_file.store_line(JSON.stringify(event))
	_file.flush()  # flush per event so a crash cannot lose the stream


func end_session() -> void:
	if not _session_active:
		return
	if not _current_level.is_empty():
		end_level(_current_level, "abandoned")
	record_event("session_end", _profile_summary())
	if _file != null:
		_file.flush()
		_file.close()
		_file = null
	_session_active = false


# --- Internals ---------------------------------------------------------------

func _begin_session() -> void:
	if not _ensure_dir(TELEMETRY_DIR):
		push_warning("Telemetry disabled: could not create %s" % TELEMETRY_DIR)
		return
	var stamp := Time.get_datetime_string_from_system(true).replace(":", "-")
	_session_path = "%s/session_%s_%04x.jsonl" % [TELEMETRY_DIR, stamp, randi() % 65536]
	_file = FileAccess.open(_session_path, FileAccess.WRITE)
	if _file == null:
		push_warning("Telemetry disabled: could not open %s (err %d)" % [_session_path, FileAccess.get_open_error()])
		return
	_session_active = true
	record_event("session_start", {})


func _profile_summary() -> Dictionary:
	var profile := get_node_or_null(^"/root/PlayerProfile")
	if profile == null:
		return {}
	return {
		"class_diversity": profile.class_diversity(),
		"roster_size": profile.roster_size(),
		"redraw_rate": profile.redraw_rate(),
	}


func _ensure_dir(path: String) -> bool:
	if DirAccess.dir_exists_absolute(path):
		return true
	return DirAccess.make_dir_recursive_absolute(path) == OK
