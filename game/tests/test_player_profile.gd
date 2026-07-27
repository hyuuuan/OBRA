extends SceneTree
## Headless test for the persistent player profile (scripts/player_profile.gd).
## Run: godot --headless --path game --script res://tests/test_player_profile.gd
##
## Covers the guarantees the thesis makes about the profile: a save/reload round
## trip through disk, an atomic write that leaves no temp file, and treating an
## unreadable or schema-incompatible profile as a fresh one rather than a crash.

const PROFILE_PATH := "user://profile.json"
const TMP_PATH := "user://profile.json.tmp"
## Bumped in lockstep with PlayerProfile.SCHEMA_VERSION. It is written here as a
## separate literal on purpose: a bump fails this suite loudly until someone has
## confirmed the migration carries the old profile forward rather than wiping it.
const EXPECTED_SCHEMA := 3

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
	_test_settings_persistence(profile)
	_test_ending_screen_payload(profile)
	_test_schema_migration(profile)

	# --- Corrupt profile -> fresh, not fatal -------------------------------
	var corrupt := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	corrupt.store_string("{ this is not valid json ]]")
	corrupt.close()
	profile.call("load_profile")
	_expect((profile.call("get_snapshot")["classes_drawn_accepted"] as Array).is_empty(), "corrupt profile was not reset")
	_expect(int(profile.call("get_snapshot")["schema_version"]) == EXPECTED_SCHEMA, "fresh profile has wrong schema version")

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


## Settings survive a round trip through disk, and cannot be corrupted by whatever
## a caller passes in — the settings screen is not the only thing that can reach
## set_setting, and a hand-edited profile reaches it too.
func _test_settings_persistence(profile) -> void:
	profile.call("set_setting", "master_volume", 0.42)
	profile.call("set_setting", "music_volume", 0.0)
	profile.call("set_setting", "sfx_volume", 0.9)
	profile.call("set_setting", "fullscreen", true)
	profile.call("save_profile")
	profile.call("load_profile")
	_expect(
		is_equal_approx(float(profile.call("get_setting", "master_volume")), 0.42),
		"master_volume did not survive a save/load round trip"
	)
	_expect(
		is_equal_approx(float(profile.call("get_setting", "music_volume")), 0.0),
		"a zero volume did not survive the round trip"
	)
	_expect(bool(profile.call("get_setting", "fullscreen")), "fullscreen did not survive the round trip")

	# Out of range clamps rather than being rejected, so a hand-edited profile cannot
	# deafen anyone or invert a slider.
	profile.call("set_setting", "sfx_volume", 1.7)
	_expect(
		is_equal_approx(float(profile.call("get_setting", "sfx_volume")), 1.0),
		"an out-of-range volume was not clamped"
	)
	profile.call("set_setting", "sfx_volume", -3.0)
	_expect(
		is_equal_approx(float(profile.call("get_setting", "sfx_volume")), 0.0),
		"a negative volume was not clamped"
	)

	# An unknown key is refused outright. Every key stored here is a key some future
	# migration has to keep understanding, so a typo must not be able to create one.
	profile.call("set_setting", "volume", 0.5)
	_expect(
		not (profile.call("get_settings") as Dictionary).has("volume"),
		"an unknown setting key was written into the profile"
	)

	# The signal carries the STORED value, not the requested one — a listener that
	# applies it must see what was actually kept.
	var seen: Array = []
	var handler := func(key: String, value: Variant) -> void: seen.append([key, value])
	profile.connect("settings_changed", handler)
	profile.call("set_setting", "master_volume", 4.0)
	profile.disconnect("settings_changed", handler)
	_expect(seen.size() == 1, "settings_changed did not fire exactly once")
	if seen.size() == 1:
		_expect(String(seen[0][0]) == "master_volume", "settings_changed reported the wrong key")
		_expect(is_equal_approx(float(seen[0][1]), 1.0), "settings_changed reported the unclamped value")

	# Restore defaults so later assertions in this suite start from a known state.
	profile.call("set_setting", "master_volume", 1.0)
	profile.call("set_setting", "music_volume", 0.8)
	profile.call("set_setting", "sfx_volume", 1.0)
	profile.call("set_setting", "fullscreen", false)


## explain() is the ending screen's entire data contract and had no caller and no
## coverage — only resolve() was tested. Every key the screen reads is asserted here
## so a rename cannot reach the screen as a blank field.
func _test_ending_screen_payload(profile) -> void:
	var payload: Dictionary = EndingResolver.explain(profile)
	for key in ["ending", "title", "route_counts", "class_diversity", "roster_size", "redraw_rate", "collectibles"]:
		_expect(payload.has(key), "explain() is missing '%s', which the ending screen reads" % key)
	_expect(not String(payload.get("title", "")).is_empty(), "explain() returned an empty ending title")
	_expect(payload.get("route_counts") is Dictionary, "explain() route_counts is not a dictionary")
	_expect(int(payload.get("roster_size", 0)) > 0, "explain() reported an empty roster")

	# A null profile is the pre-first-launch case, and must still name an ending
	# rather than crash the screen that displays it.
	var fallback: Dictionary = EndingResolver.explain(null)
	_expect(not String(fallback.get("title", "")).is_empty(), "explain(null) produced no ending title")


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
	_expect(int(snapshot["schema_version"]) == EXPECTED_SCHEMA, "migrated profile was not stamped forward")
	_expect(snapshot["acquired_objects"] is Array, "v1 migration did not add acquired_objects")
	_expect(snapshot["route_counts"] is Dictionary, "v1 migration did not add route_counts")
	_expect(int(profile.call("route_count", "artist")) == 0, "migrated route tally is not zeroed")
	_expect(not bool(profile.call("has_object", "torch")), "migrated profile invented an acquisition")

	# v2 -> v3. A v2 profile predates settings entirely, so the defaults must appear
	# without the progress beside them being disturbed.
	var v2 := {
		"schema_version": 2,
		"classes_drawn_accepted": ["frog", "bird"],
		"levels_completed": ["level_1"],
		"levels_unlocked": ["level_2"],
		"acquired_objects": ["axe"],
		"routes": {"level_1": "artist"},
		"route_counts": {"artist": 2, "pragmatist": 0, "protector": 0},
		"collectibles": [],
		"counts": {"submissions": 9, "declines": 2},
	}
	var v2_file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	v2_file.store_string(JSON.stringify(v2))
	v2_file.close()
	profile.call("load_profile")
	snapshot = profile.call("get_snapshot")
	_expect(int(snapshot["schema_version"]) == EXPECTED_SCHEMA, "v2 profile was not stamped to v3")
	_expect(bool(profile.call("has_object", "axe")), "v2 migration lost acquired objects")
	_expect(int(profile.call("route_count", "artist")) == 2, "v2 migration lost the route tally")
	_expect(int((snapshot["counts"] as Dictionary)["submissions"]) == 9, "v2 migration lost counts")
	_expect(snapshot["settings"] is Dictionary, "v2 migration did not add settings")
	_expect(
		is_equal_approx(float(profile.call("get_setting", "master_volume")), 1.0),
		"v2 migration did not default master_volume"
	)

	# A profile carrying only SOME settings is the case that needs the merge: the
	# incoming block replaces the default wholesale, so every key it omits must be
	# put back or the settings screen reads a null.
	var partial := v2.duplicate(true)
	partial["schema_version"] = 3
	partial["settings"] = {"music_volume": 0.25}
	var partial_file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	partial_file.store_string(JSON.stringify(partial))
	partial_file.close()
	profile.call("load_profile")
	_expect(
		is_equal_approx(float(profile.call("get_setting", "music_volume")), 0.25),
		"a partial settings block lost the value it did carry"
	)
	for key in ["master_volume", "sfx_volume", "fullscreen"]:
		_expect(
			profile.call("get_setting", key) != null,
			"a partial settings block left '%s' unresolved" % key
		)


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
