extends SceneTree
## Headless test for the persistent player profile (scripts/player_profile.gd).
## Run: godot --headless --path game --script res://tests/test_player_profile.gd
##
## Covers the guarantees the thesis makes about the profile: a save/reload round
## trip through disk, an atomic write that leaves no temp file, and treating an
## unreadable or schema-incompatible profile as a fresh one rather than a crash.

const PROFILE_PATH := "user://profile.json"
const TMP_PATH := "user://profile.json.tmp"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile := root.get_node_or_null("PlayerProfile")
	_expect(profile != null, "PlayerProfile autoload is unavailable")
	if profile == null:
		_finish()
		return

	_clean_files()
	profile.call("load_profile")  # start from a known-empty profile

	# Use a real roster id so class diversity has a valid member to count.
	var registry := EntityRegistry.new()
	root.add_child(registry)
	registry.load_manifest()
	var ids := registry.get_entity_ids()
	_expect(ids.size() >= 1, "entity roster is empty")
	var real_id := String(ids[0]) if ids.size() >= 1 else "frog"

	# --- Round-trip through disk -------------------------------------------
	profile.call("record_class_drawn", real_id)
	profile.call("record_class_drawn", "__not_a_real_class__")
	profile.call("note_submission", true)
	profile.call("note_submission", false)
	profile.call("mark_level_completed", "level_1")
	_expect(bool(profile.call("save_profile")), "save_profile reported failure")
	_expect(FileAccess.file_exists(PROFILE_PATH), "profile.json was not written")
	_expect(not FileAccess.file_exists(TMP_PATH), "atomic temp file was left behind")

	profile.call("load_profile")  # re-read from disk
	var snapshot: Dictionary = profile.call("get_snapshot")
	_expect((snapshot["classes_drawn_accepted"] as Array).has(real_id), "drawn class did not persist")
	_expect((snapshot["levels_completed"] as Array).has("level_1"), "level completion did not persist")
	_expect(bool(profile.call("is_level_unlocked", "level_2")), "completing level_1 did not unlock level_2")
	_expect(int((snapshot["counts"] as Dictionary)["submissions"]) == 2, "submission count did not persist")
	_expect(int((snapshot["counts"] as Dictionary)["declines"]) == 1, "decline count did not persist")
	_expect(int(profile.call("class_diversity")) == 1, "class diversity counted a non-roster id (got %d)" % int(profile.call("class_diversity")))
	_expect(int(profile.call("roster_size")) >= 1, "roster size was not derived")
	_expect(absf(float(profile.call("redraw_rate")) - 0.5) < 0.001, "redraw rate wrong: %f" % float(profile.call("redraw_rate")))

	# --- Corrupt profile -> fresh, not fatal -------------------------------
	var corrupt := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	corrupt.store_string("{ this is not valid json ]]")
	corrupt.close()
	profile.call("load_profile")
	_expect((profile.call("get_snapshot")["classes_drawn_accepted"] as Array).is_empty(), "corrupt profile was not reset")
	_expect(int(profile.call("get_snapshot")["schema_version"]) == 1, "fresh profile has wrong schema version")

	# --- Schema mismatch -> fresh, not fatal -------------------------------
	var wrong := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	wrong.store_string(JSON.stringify({"schema_version": 999, "classes_drawn_accepted": ["x"]}))
	wrong.close()
	profile.call("load_profile")
	_expect((profile.call("get_snapshot")["classes_drawn_accepted"] as Array).is_empty(), "schema-mismatched profile was not reset")

	registry.queue_free()
	_clean_files()  # do not leave test state for a real run
	_finish()


func _clean_files() -> void:
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(PROFILE_PATH)
	if FileAccess.file_exists(TMP_PATH):
		DirAccess.remove_absolute(TMP_PATH)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("OBRA_PROFILE_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("OBRA_PROFILE_TESTS_FAILED=%d" % failures.size())
		quit(1)
