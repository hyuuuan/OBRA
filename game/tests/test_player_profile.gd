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

	# --- Acquired objects, routes, collectibles ----------------------------
	_expect(not bool(profile.call("has_object", "torch")), "has_object true before acquisition")
	profile.call("record_object_acquired", "torch")
	_expect(bool(profile.call("has_object", "torch")), "has_object false after acquisition")
	_expect(bool(profile.call("is_concept_unlocked", "torch")), "is_concept_unlocked alias disagrees with has_object")
	profile.call("record_object_acquired", "torch")  # idempotent
	_expect((profile.call("acquired_objects") as Array).size() == 1, "duplicate acquisition was stored twice")

	profile.call("record_route", "level_1", "artist")
	profile.call("record_route", "level_2", "artist")
	profile.call("record_route", "level_3", "protector")
	profile.call("record_route", "level_4", "not_a_route")  # rejected
	_expect(int(profile.call("route_count", "artist")) == 2, "artist route tally wrong")
	_expect(int(profile.call("route_count", "protector")) == 1, "protector route tally wrong")
	_expect(int(profile.call("route_count", "pragmatist")) == 0, "unrecorded route is non-zero")

	profile.call("record_collectible", "flower_1")
	profile.call("record_collectible", "flower_1")  # idempotent
	_expect(bool(profile.call("is_collectible_found", "flower_1")), "collectible not found after recording")
	_expect(not bool(profile.call("is_collectible_found", "flower_2")), "unrecorded collectible reported found")
	_expect(int(profile.call("collectible_count")) == 1, "collectible count wrong")

	# Survives a save/load round trip.
	profile.call("load_profile")
	_expect(bool(profile.call("has_object", "torch")), "acquired object did not persist")
	_expect(int(profile.call("route_count", "artist")) == 2, "route tally did not persist")
	_expect(int(profile.call("collectible_count")) == 1, "collectible did not persist")

	# Replaying a level adds to the tally rather than overwriting it (FR-12.5).
	profile.call("record_route", "level_1", "artist")
	_expect(int(profile.call("route_count", "artist")) == 3, "replayed route overwrote the tally")

	_test_ending_resolver()
	_test_schema_migration(profile)

	# --- Corrupt profile -> fresh, not fatal -------------------------------
	var corrupt := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	corrupt.store_string("{ this is not valid json ]]")
	corrupt.close()
	profile.call("load_profile")
	_expect((profile.call("get_snapshot")["classes_drawn_accepted"] as Array).is_empty(), "corrupt profile was not reset")
	_expect(int(profile.call("get_snapshot")["schema_version"]) == 2, "fresh profile has wrong schema version")

	# --- Schema mismatch -> fresh, not fatal -------------------------------
	var wrong := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	wrong.store_string(JSON.stringify({"schema_version": 999, "classes_drawn_accepted": ["x"]}))
	wrong.close()
	profile.call("load_profile")
	_expect((profile.call("get_snapshot")["classes_drawn_accepted"] as Array).is_empty(), "schema-mismatched profile was not reset")

	registry.queue_free()
	_clean_files()  # do not leave test state for a real run
	_finish()


## The resolver must return exactly one ending for any profile, with a fixed
## precedence when several conditions hold at once.
func _test_ending_resolver() -> void:
	var valid := [
		EndingResolver.ENDING_A, EndingResolver.ENDING_B,
		EndingResolver.ENDING_C, EndingResolver.ENDING_D
	]
	# artist, pragmatist, protector, diversity, redraw, flowers -> expected
	var cases := [
		[3, 0, 0, 30, 0.1, 5, EndingResolver.ENDING_A],   # every A condition holds
		[3, 0, 0, 30, 0.1, 4, EndingResolver.ENDING_D],   # a missing flower drops out of A
		[3, 0, 0, 20, 0.1, 5, EndingResolver.ENDING_D],   # too little diversity for A
		[0, 3, 0, 5, 0.1, 0, EndingResolver.ENDING_B],    # rushed and narrow
		[0, 3, 0, 30, 0.1, 0, EndingResolver.ENDING_D],   # rushed route but broad vocabulary
		[0, 0, 3, 12, 0.1, 0, EndingResolver.ENDING_C],   # protector commitment
		[0, 0, 0, 12, 0.9, 0, EndingResolver.ENDING_D],   # telemetry-only perseverance
		[0, 0, 0, 0, 0.0, 0, EndingResolver.ENDING_D],    # empty profile still resolves
		[3, 0, 3, 30, 0.1, 5, EndingResolver.ENDING_A],   # A outranks C
		[0, 3, 3, 5, 0.1, 0, EndingResolver.ENDING_B],    # B outranks C
	]
	for case_value in cases:
		var c: Array = case_value
		var got := EndingResolver.resolve_values(c[0], c[1], c[2], c[3], c[4], c[5])
		_expect(got in valid, "resolver returned an unknown ending: %s" % got)
		_expect(got == c[6], "resolver gave %s, expected %s for %s" % [got, c[6], str(c.slice(0, 6))])
	_expect(EndingResolver.resolve(null) in valid, "resolver did not handle a null profile")
	_expect(not EndingResolver.title_for(EndingResolver.ENDING_A).is_empty(), "ending A has no title")


## A profile written by the previous schema keeps its progress instead of being wiped.
func _test_schema_migration(profile) -> void:
	var legacy := {
		"schema_version": 1,
		"classes_drawn_accepted": ["frog"],
		"levels_completed": ["level_1"],
		"levels_unlocked": ["level_2"],
		"collectibles": [],
		"counts": {"submissions": 4, "declines": 1},
	}
	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	profile.call("load_profile")
	var snapshot: Dictionary = profile.call("get_snapshot")
	_expect((snapshot["levels_completed"] as Array).has("level_1"), "v1 migration lost level progress")
	_expect(int((snapshot["counts"] as Dictionary)["submissions"]) == 4, "v1 migration lost counts")
	_expect(int(snapshot["schema_version"]) == 2, "migrated profile was not stamped to v2")
	_expect(snapshot["acquired_objects"] is Array, "v1 migration did not add acquired_objects")
	_expect(snapshot["route_counts"] is Dictionary, "v1 migration did not add route_counts")
	_expect(int(profile.call("route_count", "artist")) == 0, "migrated route tally is not zeroed")
	_expect(not bool(profile.call("has_object", "torch")), "migrated profile invented an acquisition")


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
