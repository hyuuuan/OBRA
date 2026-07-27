extends SceneTree
## Dependency-free headless regression suite:
## godot --headless --path game --script res://tests/run_tests.gd

const SpiderRigAnalyzer = preload("res://scripts/spider_rig_analyzer.gd")
const SpiderReferenceFixtures = preload("res://tests/spider_reference_fixtures.gd")

const THEME_PATH := "res://ui/obra_theme.tres"

var failures: Array[String] = []
var world: Node2D
var registry: EntityRegistry


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	world = Node2D.new()
	world.name = "TestWorld"
	root.add_child(world)
	_add_floor()
	registry = EntityRegistry.new()
	world.add_child(registry)
	registry.load_manifest()

	_test_manifest_roles()
	_test_theme_resource()
	_test_audio_buses()
	_test_ink_accounting()
	_test_inventory()
	_test_canvas_clipping()
	_test_game_level_contract()
	await _test_level_framework()
	await _test_banaue_environment()
	_test_camera_non_finite_guard()
	_test_target_contracts()
	await _test_ui_router_cancel_chain()
	await _test_overlay_pause_refcount()
	await _test_shared_overlays()
	await _test_level_completion_screen()
	await _test_placement_collision()
	_test_anatomy_inference()
	await _test_spider_stance_controller()
	await _test_active_ragdolls()
	await _test_archetype_coverage()
	await _test_idle_stability()
	await _test_pose_holding()
	await _test_wing_anatomy()
	await _test_fidelity_mode()
	await _test_fidelity_guard()
	await _test_every_class_animates()
	_test_skeleton_manifest()
	_test_skin_weights()
	_test_skinned_rest_identity()
	await _test_skinned_rig_renders_the_drawing()
	await _test_gait_reaches_the_ink()
	await _test_messy_fixtures()
	await _test_ink_integrity()
	await _test_grazing_stroke_not_split()
	await _test_limb_angle_discipline()
	await _test_stick_figure_anatomy()
	await _test_compound_fallback_recovery()
	await _test_physics_morphs()
	await _test_utilities()
	world.queue_free()
	registry = null
	world = null
	await process_frame
	await process_frame

	if failures.is_empty():
		print("OBRA_HEADLESS_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("OBRA_HEADLESS_TESTS_FAILED=%d" % failures.size())
		quit(1)


func _test_manifest_roles() -> void:
	var living := 0
	var shapes := 0
	var utilities := 0
	for entity_id in registry.get_entity_ids():
		var entry := registry.get_entity(entity_id)
		_expect(not entry.is_empty(), "manifest missing %s" % entity_id)
		match String(entry.get("runtime_role", "")):
			"active_ragdoll_morph": living += 1
			"physics_morph": shapes += 1
			"utility": utilities += 1
	_expect(living == 20, "expected 20 living morphs, got %d" % living)
	_expect(shapes == 3, "expected 3 physics morphs, got %d" % shapes)
	_expect(utilities == 27, "expected 27 utilities, got %d" % utilities)


## The reported bug, as a regression test: Escape while placing an object opened the
## pause menu instead of cancelling the placement.
##
## It was never a logic error in either script. Both read ui_cancel from
## _unhandled_input, Godot propagates that in reverse tree order, and PauseMenu is the
## last child of GameLevel while PlacementController is the sixth -- so the pause menu
## always won and placement_controller's cancel branch was unreachable code. The fix
## is an authored chain rather than an accident of node order, so what is asserted is
## the chain's decisions, driven directly and deterministically.
func _test_ui_router_cancel_chain() -> void:
	var level: Node = (load("res://game_level.tscn") as PackedScene).instantiate()
	world.add_child(level)
	await process_frame
	var router: Node = level.get_node_or_null("UIRouter")
	var pause: Node = level.get_node_or_null("PauseMenu")
	var placement: Node = level.get_node_or_null("PlacementController")
	var panel: Node = level.get_node_or_null("DrawPanel")
	_expect(router != null, "game_level has no UIRouter")
	_expect(pause != null and placement != null and panel != null, "cancel chain targets are missing")
	if router == null or pause == null or placement == null or panel == null:
		level.queue_free()
		await process_frame
		return

	# The chain must name the placement controller AHEAD of the pause menu. Order is
	# the entire fix, so it is asserted rather than assumed.
	var chain: Array = router.get("cancel_chain")
	var names: Array[String] = []
	for path in chain:
		names.append(String(path).get_file())
	_expect(
		names.find("PlacementController") >= 0 and names.find("PauseMenu") >= 0
			and names.find("PlacementController") < names.find("PauseMenu"),
		"cancel chain does not put placement ahead of pause: %s" % str(names)
	)

	# Nothing modal up: the key reaches the last link and opens the pause menu.
	_expect(not bool(pause.call("is_open")), "pause menu started open")
	_expect(bool(pause.call("handle_cancel")), "pause menu did not consume the key")
	_expect(bool(pause.call("is_open")), "pause menu did not open")
	pause.call("handle_cancel")
	_expect(not bool(pause.call("is_open")), "pause menu did not close again")

	# Nothing to cancel: every handler ahead of the pause menu declines, which is what
	# lets the key fall through instead of being swallowed by an idle overlay.
	_expect(not bool(placement.call("handle_cancel")), "idle placement consumed the cancel key")
	_expect(not bool(panel.call("handle_cancel")), "closed draw panel consumed the cancel key")

	# The draw panel consumes it while open, and its close must not leave the tree
	# paused behind it.
	panel.call("open_panel")
	_expect(bool(panel.call("is_open")), "draw panel did not open")
	_expect(bool(panel.call("handle_cancel")), "open draw panel did not consume the cancel key")
	_expect(not bool(panel.call("is_open")), "draw panel did not close on cancel")
	_expect(not paused, "closing the draw panel left the tree paused")

	level.queue_free()
	await process_frame


## The settings, controls and confirm screens, in both scenes that instance them.
##
## They are one definition used twice, so the failure to guard against is one copy
## drifting -- a button renamed in the scene, or an overlay wired into only one of
## the two places it is reachable from.
func _test_shared_overlays() -> void:
	for scene_path in ["res://game_level.tscn", "res://ui/main_menu.tscn"]:
		var instance: Node = (load(scene_path) as PackedScene).instantiate()
		world.add_child(instance)
		await process_frame
		var label: String = scene_path.get_file()
		for overlay_name in ["SettingsOverlay", "ControlsOverlay", "ConfirmOverlay"]:
			var overlay: Node = instance.get_node_or_null(overlay_name)
			_expect(overlay != null, "%s does not instance %s" % [label, overlay_name])
			if overlay == null:
				continue
			_expect(not bool(overlay.call("is_open")), "%s in %s started open" % [overlay_name, label])
			overlay.call("open")
			_expect(bool(overlay.call("is_open")), "%s in %s did not open" % [overlay_name, label])
			# Every shared overlay must be in the cancel chain of whichever scene it is
			# in, or it opens with no way back out except the mouse.
			_expect(bool(overlay.call("handle_cancel")), "%s in %s does not close on cancel" % [overlay_name, label])
			_expect(not bool(overlay.call("is_open")), "%s in %s stayed open after cancel" % [overlay_name, label])
		var router: Node = instance.get_node_or_null("UIRouter")
		_expect(router != null, "%s has no UIRouter" % label)
		if router != null:
			var chain_names: Array[String] = []
			for path in (router.get("cancel_chain") as Array):
				chain_names.append(String(path).get_file())
			for overlay_name in ["SettingsOverlay", "ControlsOverlay", "ConfirmOverlay"]:
				_expect(
					chain_names.has(overlay_name),
					"%s's cancel chain omits %s" % [label, overlay_name]
				)
		instance.queue_free()
		await process_frame
	paused = false

	# The controls screen derives its key glyphs from the live InputMap, so the only
	# thing that can rot is an action name in the JSON. A row naming an action that
	# does not exist is silently skipped, which would quietly empty the screen.
	var text := FileAccess.get_file_as_string("res://config/controls.json")
	var parsed: Variant = JSON.parse_string(text)
	_expect(parsed is Dictionary, "controls.json did not parse")
	if parsed is Dictionary:
		var rows: Array = (parsed as Dictionary).get("rows", [])
		_expect(rows.size() > 0, "controls.json lists no rows")
		for row_value: Variant in rows:
			var row: Dictionary = row_value
			var action := String(row.get("action", ""))
			_expect(
				InputMap.has_action(action),
				"controls.json names '%s', which is not in the InputMap" % action
			)
			var through := String(row.get("through", ""))
			if not through.is_empty():
				_expect(
					InputMap.has_action(through),
					"controls.json range ends at '%s', which is not in the InputMap" % through
				)


## Finishing a level must be readable, and reaching the ending must be possible.
##
## The completion overlay is driven with synthetic stats rather than by playing the
## level: this asserts the SCREEN, and deliberately writes nothing to the profile, so
## the suite never starts touching user://profile.json (which it does not today).
func _test_level_completion_screen() -> void:
	var level: Node = (load("res://game_level.tscn") as PackedScene).instantiate()
	world.add_child(level)
	await process_frame
	var complete: Node = level.get_node_or_null("LevelCompleteOverlay")
	var out_of_ink: Node = level.get_node_or_null("OutOfInkOverlay")
	_expect(complete != null, "game_level has no LevelCompleteOverlay")
	_expect(out_of_ink != null, "game_level has no OutOfInkOverlay")
	if complete == null or out_of_ink == null:
		level.queue_free()
		await process_frame
		return

	complete.call("present", {
		"level_title": "Banaue Rice Terraces",
		"ink_used": 7.5, "ink_capacity": 12.0,
		"classes_drawn": 3, "elapsed_seconds": 95.0,
	})
	_expect(bool(complete.call("is_open")), "the completion screen did not open")
	_expect(paused, "the completion screen did not pause the level behind it")

	# Every stat must reach the screen. Rendering the panel but leaving it blank is a
	# failure the "did it open" check alone would pass.
	var rendered: Array[String] = []
	for row in complete.get_node("Root/Panel/VBox/Stats").get_children():
		if row is HBoxContainer:
			rendered.append("%s %s" % [(row.get_child(0) as Label).text, (row.get_child(1) as Label).text])
	var joined := " | ".join(rendered)
	_expect(joined.contains("1:35"), "elapsed time is not rendered as m:ss (got '%s')" % joined)
	_expect(joined.contains("7.5"), "ink used is not rendered (got '%s')" % joined)
	_expect(joined.contains("3"), "classes drawn is not rendered (got '%s')" % joined)

	# It must NOT be dismissable: cancelling out would strand the player in a finished
	# level with nothing telling them what happens next.
	_expect(bool(complete.call("handle_cancel")), "the completion screen let the cancel key past it")
	_expect(bool(complete.call("is_open")), "the completion screen closed on cancel")

	level.queue_free()
	await process_frame
	paused = false

	# level_1 ends the run, so CONTINUE has an ending to reach and that ending exists.
	# Resolved through the tree like the rest of this suite: the autoloads are not
	# registered when a --script run compiles its own script.
	var manager := root.get_node_or_null("LevelManager")
	_expect(manager != null, "LevelManager autoload is unavailable")
	if manager != null:
		_expect(
			bool((manager.call("get_level", "level_1") as Dictionary).get("ends_run", false)),
			"level_1 does not end the run, so nothing reaches the ending screen"
		)
	_expect(ResourceLoader.exists("res://ui/ending_screen.tscn"), "the ending scene is missing")

	# The ending screen renders EndingResolver's payload rather than a blank verdict.
	var ending: Node = (load("res://ui/ending_screen.tscn") as PackedScene).instantiate()
	world.add_child(ending)
	await process_frame
	var ending_name := (ending.get_node("Panel/VBox/EndingName") as Label).text
	_expect(not ending_name.is_empty(), "the ending screen named no ending")
	_expect(
		ending.get_node("Panel/VBox/Rows").get_child_count() > 0,
		"the ending screen showed no reasons for its verdict"
	)
	ending.queue_free()
	await process_frame


## Pause is derived from whoever is open, not toggled by whoever closes.
##
## The bug this prevents: Settings opened over the pause menu, then closed, would set
## paused = false and drop the player back into a live level while still looking at
## the pause menu. Two overlays are enough to demonstrate it.
func _test_overlay_pause_refcount() -> void:
	var outer := ModalOverlay.new()
	var inner := ModalOverlay.new()
	world.add_child(outer)
	world.add_child(inner)
	await process_frame

	outer.open()
	_expect(paused, "an open overlay did not pause the tree")
	inner.open()
	_expect(paused, "a second overlay unpaused the tree")
	inner.close()
	_expect(paused, "closing the top overlay unpaused a game still behind one")
	outer.close()
	_expect(not paused, "closing the last overlay left the tree paused")

	# An overlay that does not want pause must not cause it.
	outer.pauses_game = false
	outer.open()
	_expect(not paused, "a non-pausing overlay paused the tree")
	outer.close()

	outer.queue_free()
	inner.queue_free()
	await process_frame
	paused = false


## Every name a scene asks the theme for must exist in it.
##
## This is the only thing that can catch a renamed type variation. A Control whose
## theme_type_variation names something the theme does not define does not warn and
## does not fail -- it silently falls back to the engine's default look, which is
## precisely the mismatch the theme was added to remove, reappearing invisibly.
func _test_theme_resource() -> void:
	var configured := String(ProjectSettings.get_setting("gui/theme/custom", ""))
	_expect(configured == THEME_PATH, "gui/theme/custom is '%s', not the project theme" % configured)
	var theme := load(THEME_PATH) as Theme
	_expect(theme != null, "the project theme failed to load")
	if theme == null:
		return
	for variation in ["PrimaryButton", "DialogButton", "LevelCard", "InventorySlot", "ScreenTitle", "ScreenSubtitle", "HudHint"]:
		_expect(
			theme.is_type_variation(variation, theme.get_type_variation_base(variation)),
			"theme has no type variation '%s'" % variation
		)
	# The base types the HUD and every new screen inherit from, which have no
	# overrides of their own and would otherwise render as raw engine defaults.
	_expect(theme.has_stylebox("normal", "Button"), "theme does not style a plain Button")
	_expect(theme.has_stylebox("disabled", "Button"), "theme does not style a disabled Button")
	_expect(theme.has_stylebox("panel", "PanelContainer"), "theme does not style a PanelContainer")
	_expect(theme.has_stylebox("fill", "ProgressBar"), "theme does not style the ink bar")
	_expect(theme.has_stylebox("grabber_area", "HSlider"), "theme does not style a volume slider")
	_expect(theme.has_color("font_color", "Label"), "theme does not colour a plain Label")
	# A font here WOULD reach the main menu, whose overrides are all colours and sizes.
	# The menu is deliberately left alone, so this must stay absent.
	_expect(not theme.has_font("font", "Label"), "theme defines a Label font, which would restyle the main menu")

	# Focus is drawn ON TOP of the state stylebox, not instead of it, so an opaque
	# focus box hides the button beneath. This is not hypothetical: the first version
	# of this theme did exactly that and covered the menu's bright PLAY button with a
	# flat dark panel, while every one of the menu's own overrides was still in force.
	# Overrides do not protect a state the scene does not override.
	for type_name in ["Button", "PrimaryButton", "LevelCard"]:
		if not theme.has_stylebox("focus", type_name):
			continue
		var box := theme.get_stylebox("focus", type_name)
		if box is StyleBoxFlat:
			_expect(
				(box as StyleBoxFlat).bg_color.a < 0.05,
				"%s's focus stylebox is opaque and will hide the button under it" % type_name
			)


## The audio layer exists before any sound does, so what is asserted is the part that
## can be wrong without anyone hearing it: the buses are laid out as intended, and the
## linear-to-dB conversion never produces a value AudioServer cannot hold.
func _test_audio_buses() -> void:
	var director := root.get_node_or_null("AudioDirector")
	_expect(director != null, "AudioDirector autoload is unavailable")
	if director == null:
		return
	for bus_name in ["Master", "Music", "SFX"]:
		_expect(AudioServer.get_bus_index(bus_name) >= 0, "no '%s' audio bus" % bus_name)
	for bus_name in ["Music", "SFX"]:
		var index := AudioServer.get_bus_index(bus_name)
		if index >= 0:
			_expect(
				String(AudioServer.get_bus_send(index)) == "Master",
				"'%s' does not send to Master, so the master slider cannot scale it" % bus_name
			)

	var sfx := AudioServer.get_bus_index("SFX")
	if sfx >= 0:
		director.call("set_bus_linear", "SFX", 1.0)
		_expect(absf(AudioServer.get_bus_volume_db(sfx)) < 0.01, "full volume is not 0 dB")
		_expect(not AudioServer.is_bus_mute(sfx), "full volume left the bus muted")
		director.call("set_bus_linear", "SFX", 0.5)
		_expect(
			absf(AudioServer.get_bus_volume_db(sfx) + 6.0206) < 0.05,
			"half volume is %.3f dB, not the expected -6.02" % AudioServer.get_bus_volume_db(sfx)
		)
		# Silence must MUTE rather than approach -inf: linear_to_db(0.0) is -inf, and
		# a non-finite dB written to the server is unrecoverable without a restart.
		director.call("set_bus_linear", "SFX", 0.0)
		_expect(AudioServer.is_bus_mute(sfx), "zero volume did not mute the bus")
		_expect(is_finite(AudioServer.get_bus_volume_db(sfx)), "zero volume wrote a non-finite dB")
		# Out of range is clamped, because this is reached from a save file too.
		director.call("set_bus_linear", "SFX", 4.0)
		_expect(absf(AudioServer.get_bus_volume_db(sfx)) < 0.01, "an over-range volume was not clamped")
		director.call("set_bus_linear", "SFX", 1.0)

	# An unresolved id is silence, not an error. This is the mechanism that lets every
	# call site be written before the sounds exist.
	director.call("play_sfx", &"ui_click")
	director.call("play_sfx", &"no_such_sound_id")
	director.call("play_music", &"menu")
	_expect(true, "playing unresolved sound ids must not raise")


func _test_ink_accounting() -> void:
	var sparse := [{"points": PackedVector2Array([Vector2.ZERO, Vector2(512.0, 0.0)])}]
	var dense_points := PackedVector2Array()
	for index in range(65):
		dense_points.append(Vector2(float(index) * 8.0, 0.0))
	var dense := [{"points": dense_points}]
	var sparse_cost := InkManager.static_cost_for_strokes(sparse)
	var dense_cost := InkManager.static_cost_for_strokes(dense)
	_expect(is_equal_approx(sparse_cost, dense_cost), "ink cost changes with sample density")
	var manager := InkManager.new()
	manager.begin_level(12.0)
	_expect(manager.reserve_attempt(2.0), "could not reserve valid ink")
	_expect(is_equal_approx(manager.remaining(), 10.0), "ink reservation not reflected")
	manager.release_attempt()
	_expect(is_equal_approx(manager.remaining(), 12.0), "released ink was not refunded")
	manager.reserve_attempt(3.0)
	manager.commit_attempt()
	_expect(is_equal_approx(manager.remaining(), 9.0), "committed ink was refunded")
	manager.reserve_attempt(1.0)
	var hidden_panel := DrawPanel.new()
	hidden_panel.ink_manager = manager
	hidden_panel.call("_on_stroke_cost_changed", 0.0)
	_expect(is_equal_approx(manager.reserved, 1.0), "hidden canvas clear erased a pending utility reservation")
	hidden_panel.free()
	manager.free()


func _test_inventory() -> void:
	var inventory := InventoryManager.new()
	inventory.capacity = 6
	world.add_child(inventory)
	inventory.begin_level()
	var ids: Array[int] = []
	for index in range(6):
		var item := DrawnItemData.new()
		item.entity_id = "key"
		ids.append(item.instance_id)
		_expect(inventory.add_item(item) == index, "inventory did not fill in slot order")
	_expect(inventory.is_full(), "six-slot inventory did not report full")
	_expect(inventory.add_item(DrawnItemData.new()) == -1, "inventory accepted a seventh item")
	var recovered := inventory.take_item(2)
	_expect(recovered != null and recovered.instance_id == ids[2], "inventory lost item identity")
	inventory.queue_free()


func _test_canvas_clipping() -> void:
	var canvas_script := load("res://scripts/drawing_canvas.gd")
	var canvas := Control.new()
	canvas.set_script(canvas_script)
	world.add_child(canvas)
	canvas.call("set_ink_budget", 0.1, Vector2(512.0, 512.0))
	canvas.call("_start_stroke", Vector2.ZERO)
	canvas.call("_append_point", Vector2(512.0, 0.0), true)
	var maximum := Vector2(512.0, 512.0).length() * 0.1
	_expect(float(canvas.call("get_drawn_length")) <= maximum + 0.01, "canvas exceeded exact ink limit")
	canvas.queue_free()


func _test_game_level_contract() -> void:
	var packed := load("res://game_level.tscn") as PackedScene
	_expect(packed != null, "game level scene did not load")
	if packed == null:
		return
	var level := packed.instantiate()
	for path in [
		"InkManager", "InventoryManager", "PlacementController",
		"EnvironmentBaseplate/GameplayPlane/EntityRoot",
		"EnvironmentBaseplate/GameplayPlane/WorldItemRoot",
		"CanvasLayer/InkBar", "CanvasLayer/InventoryHUD", "PauseMenu"
	]:
		_expect(level.get_node_or_null(path) != null, "game level missing %s" % path)
	level.free()


func _test_level_framework() -> void:
	var level_manager := root.get_node_or_null("LevelManager")
	_expect(level_manager != null, "LevelManager autoload is unavailable")
	if level_manager == null:
		return
	var levels: Array = level_manager.call("get_levels")
	_expect(levels.size() == 5, "level catalog must contain exactly five levels")
	var unlocked_count := 0
	for index in range(levels.size()):
		var entry: Dictionary = levels[index] as Dictionary
		_expect(int(entry.get("number", 0)) == index + 1, "level catalog order is not stable")
		if bool(entry.get("unlocked", false)):
			unlocked_count += 1
	_expect(unlocked_count == 1 and bool(level_manager.call("is_unlocked", "level_1")), "only Level 1 should be unlocked")
	_expect(not bool(level_manager.call("open_level", "level_2")), "locked Level 2 initiated a transition")
	_expect(not bool(level_manager.call("open_level", "missing")), "invalid level initiated a transition")

	# Playable and unlocked are different questions, and conflating them is the dead
	# card. Level 2 has no scene, so it is never playable however the profile's
	# progression feels about it -- including on a machine where level 1 was finished
	# in a real session, which is exactly when the old code enabled a card that then
	# did nothing.
	_expect(bool(level_manager.call("is_playable", "level_1")), "level_1 is not playable")
	for missing_id in ["level_2", "level_3", "level_4", "level_5"]:
		_expect(
			not bool(level_manager.call("is_playable", missing_id)),
			"%s reports playable with no scene behind it" % missing_id
		)
	_expect(not bool(level_manager.call("is_playable", "nonexistent")), "an unknown level reports playable")

	var menu_scene := load("res://ui/main_menu.tscn") as PackedScene
	_expect(menu_scene != null, "main menu scene did not load")
	if menu_scene == null:
		return
	var menu := menu_scene.instantiate()
	root.add_child(menu)
	await process_frame
	_expect(not bool(menu.call("is_selector_open")), "menu did not start in Play state")
	menu.call("_show_selector")
	await create_timer(0.7).timeout
	_expect(bool(menu.call("is_selector_open")), "Play did not expand into the level selector")
	var cards := menu.get_node("MenuLayer/MenuRoot/MorphPanel/Selector").get_children()
	var disabled_cards := 0
	for card in cards:
		if card is Button and (card as Button).disabled:
			disabled_cards += 1
	_expect(disabled_cards == 4, "selector does not expose exactly four locked cards")

	# The dead card, stated directly. Level 2's card must be disabled REGARDLESS of
	# what progression thinks, because no scene exists behind it -- and the previous
	# code disabled it only on is_unlocked, so finishing level 1 in a real session
	# enabled a card that then silently did nothing when clicked. Asserted without
	# touching the profile: this suite must never write user://profile.json.
	var level2 := menu.get_node_or_null("MenuLayer/MenuRoot/MorphPanel/Selector/Level2") as Button
	_expect(level2 != null, "the level 2 card is missing")
	if level2 != null:
		_expect(level2.disabled, "level 2's card is offered with no scene behind it")
		_expect(
			not bool(level_manager.call("open_level", "level_2")),
			"level 2 would start a transition to a scene that does not exist"
		)

	# Card text comes from the catalog, not from strings typed into the scene.
	var name_label := menu.get_node_or_null("MenuLayer/MenuRoot/MorphPanel/Selector/Level1/Name") as Label
	if name_label != null:
		var expected := String((level_manager.call("get_level", "level_1") as Dictionary).get("title", "")).to_upper()
		_expect(
			name_label.text == expected,
			"level 1's card reads '%s' but the catalog says '%s'" % [name_label.text, expected]
		)
	menu.call("_hide_selector")
	await create_timer(0.5).timeout
	_expect(not bool(menu.call("is_selector_open")), "selector did not collapse back into Play")
	menu.queue_free()
	await process_frame


func _test_banaue_environment() -> void:
	var environment_scene := load("res://levels/level_1/level_1_environment.tscn") as PackedScene
	_expect(environment_scene != null, "Banaue environment scene did not load")
	if environment_scene == null:
		return
	var environment := environment_scene.instantiate() as Node2D
	world.add_child(environment)
	await process_frame
	var bounds: Rect2 = environment.get("world_bounds")
	_expect(bounds.size == Vector2(3760.0, 1200.0), "Banaue world bounds changed unexpectedly")
	var spawn := environment.get_node("GameplayPlane/SpawnPoint") as Marker2D
	_expect(spawn.position == Vector2(260.0, 500.0), "Banaue spawn is not on the opening terrace")

	var terrace_count := 0
	for node in get_nodes_in_group("terrace_ground"):
		if environment.is_ancestor_of(node):
			terrace_count += 1
	_expect(terrace_count == 12, "Banaue terrain does not contain the expected terrace segments")
	var water_count := 0
	for node in get_nodes_in_group("water_medium"):
		if environment.is_ancestor_of(node):
			water_count += 1
	_expect(water_count == 2, "Banaue must contain exactly two physical paddies")

	var camera_delta := Vector2(100.0, 0.0)
	var far_layer := environment.get_node("FarMountainLayer") as DepthLayer2D
	var green_layer := environment.get_node("GreenMountainLayer") as DepthLayer2D
	var near_layer := environment.get_node("NearSceneryLayer") as DepthLayer2D
	for layer in [far_layer, green_layer, near_layer]:
		layer.set_camera_origin(Vector2.ZERO)
		layer.update_for_camera(camera_delta)
	var far_screen_motion := absf(camera_delta.x - far_layer.position.x)
	var green_screen_motion := absf(camera_delta.x - green_layer.position.x)
	var near_screen_motion := absf(camera_delta.x - near_layer.position.x)
	_expect(far_screen_motion < green_screen_motion and green_screen_motion < near_screen_motion, "Banaue parallax depth ordering is reversed")

	var probe := RigidBody2D.new()
	var lower_paddy := environment.get_node("GameplayPlane/WaterAreas/LowerPaddy") as WaterArea2D
	lower_paddy.call("_on_body_entered", probe)
	_expect(probe.has_meta("water_area") and int(probe.get_meta("water_overlap_count", 0)) == 1, "paddy did not apply water metadata")
	lower_paddy.call("_on_body_exited", probe)
	_expect(not probe.has_meta("water_area") and int(probe.get_meta("water_overlap_count", 0)) == 0, "paddy did not clear water metadata")
	probe.free()
	environment.queue_free()
	await process_frame


func _test_camera_non_finite_guard() -> void:
	var camera := WorldCameraController.new()
	var bad_target := Node2D.new()
	world.add_child(camera)
	world.add_child(bad_target)
	camera.set_target(bad_target)
	bad_target.global_position = Vector2(NAN, INF)
	var desired: Vector2 = camera.call("_clamped_target_position")
	_expect(is_finite(desired.x) and is_finite(desired.y), "camera accepted a non-finite physics target")
	camera.queue_free()
	bad_target.queue_free()


func _test_target_contracts() -> void:
	var axe_target: Node = load("res://scripts/destructible_2d.gd").new()
	axe_target.set("health", 50.0)
	world.add_child(axe_target)
	_expect(bool(axe_target.call("apply_tool_hit", "axe", 400.0, world)), "axe target rejected axe hit")
	_expect(bool(axe_target.get("is_destroyed")), "axe target did not apply impulse-scaled damage")
	axe_target.queue_free()

	var item := DrawnItemData.new()
	item.entity_id = "key"
	var lock: Node = load("res://scripts/lockable_2d.gd").new()
	lock.set("consume_key", true)
	world.add_child(lock)
	var result: Dictionary = lock.call("try_unlock", "drawn_key", item)
	_expect(bool(result.get("unlocked", false)), "lock rejected drawn key")
	_expect(bool(result.get("consumed", false)), "consuming lock omitted consumption result")
	lock.queue_free()

	var requirement := UtilityRequirement2D.new()
	requirement.required_utility = "flashlight"
	world.add_child(requirement)
	_expect(requirement.report_utility_used("flashlight", item), "utility requirement did not satisfy")
	_expect(not requirement.report_utility_used("flashlight", item), "utility requirement satisfied twice")
	requirement.queue_free()


func _test_placement_collision() -> void:
	var item := DrawnItemData.from_prediction("key", "Key", _blank_image(), _utility_fixture("key"), 0.4, registry.get_entity("key"))
	var utility := registry.instantiate_entity("key") as UtilityObject
	world.add_child(utility)
	utility.apply_item_data(item)
	utility.set_preview(true)
	var obstacle := StaticBody2D.new()
	obstacle.position = Vector2(760.0, 120.0)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(120.0, 120.0)
	collision.shape = shape
	obstacle.add_child(collision)
	world.add_child(obstacle)
	utility.global_position = obstacle.global_position
	var placement := PlacementController.new()
	world.add_child(placement)
	placement.set("_preview", utility)
	await physics_frame
	_expect(not bool(placement.call("_position_is_clear")), "placement accepted overlapping solid collision")
	utility.global_position = Vector2(1800.0, -500.0)
	await physics_frame
	_expect(bool(placement.call("_position_is_clear")), "placement rejected clear world position")
	placement.set("_preview", null)
	utility.queue_free()
	obstacle.queue_free()
	placement.queue_free()


func _test_active_ragdolls() -> void:
	for entity_id in _living_entity_ids():
		var instance := registry.instantiate_entity(entity_id) as Node2D
		_expect(instance != null, "could not instantiate %s" % entity_id)
		if instance == null:
			continue
		world.add_child(instance)
		instance.global_position = Vector2(300.0, 200.0)
		instance.call("apply_drawing", _blank_image(), _fixture_for(entity_id))
		var anchor := instance.call("get_physics_anchor") as ActiveRigBody2D
		_expect(anchor != null, "%s has no physics anchor" % entity_id)
		var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
		_expect(skin.get_rigid_bodies().size() <= 24, "%s exceeded body cap" % entity_id)
		_expect(skin.get_joint_count() <= 23, "%s exceeded joint cap" % entity_id)
		var rig_type := String(registry.get_entity(entity_id).get("rig_type", ""))
		if entity_id == "spider":
			_expect(skin.get_joint_count() >= 12, "spider legs regressed to single rigid segments")
		else:
			_expect(skin.get_joint_count() > 0, "%s did not articulate fixture strokes" % entity_id)
		var expected_roles := _expected_roles_for_rig(rig_type)
		if not expected_roles.is_empty():
			var role_found := false
			for role_name in expected_roles:
				role_found = role_found or role_name in skin.debug_segment_roles()
			_expect(role_found, "%s did not assign any expected role %s (got %s)" % [entity_id, str(expected_roles), str(skin.debug_segment_roles())])
		var motion_state: String = _gait_for_rig(rig_type)
		var motion_params := {"moving": true, "speed_ratio": 1.0, "direction": 1.0}
		# Keep the fixture in its species gait; the normal controller would read
		# zero headless input and replace this state with idle every frame.
		instance.set_physics_process(false)
		skin.set_motion_state(motion_state, motion_params)
		skin._physics_process(0.1)
		if skin.get_joint_count() > 0 and entity_id != "spider":
			var muscle_active := false
			for torque in skin.debug_drive_torques():
				muscle_active = muscle_active or absf(torque) > 0.01
			_expect(muscle_active, "%s gait did not drive bounded joint muscles" % entity_id)
		var stress_frames := 120
		var maximum_joint_error := 0.0
		var maximum_body_distance := 0.0
		for frame in range(stress_frames):
			skin.set_motion_state(motion_state, motion_params)
			if entity_id != "spider" and frame % 90 == 30 and anchor != null:
				anchor.apply_central_impulse(Vector2(55.0, -35.0) * anchor.mass)
			await physics_frame
			maximum_joint_error = maxf(maximum_joint_error, skin.debug_max_joint_error())
			maximum_body_distance = maxf(maximum_body_distance, skin.debug_max_body_distance())
		if anchor != null:
			_expect(is_finite(anchor.global_position.x) and is_finite(anchor.global_position.y), "%s physics became non-finite" % entity_id)
			_expect(anchor.linear_velocity.length() <= anchor.max_linear_speed + 1.0, "%s exceeded velocity safety bound" % entity_id)
			_expect(Rect2(-180.0, -700.0, 4120.0, 1560.0).has_point(anchor.global_position), "%s escaped the playable world" % entity_id)
			var camera_target := instance.call("get_camera_target") as Node2D
			_expect(camera_target != anchor, "%s camera still follows the raw rigidbody" % entity_id)
			_expect(camera_target != null and is_finite(camera_target.global_position.x) and is_finite(camera_target.global_position.y), "%s camera target became invalid" % entity_id)
		_expect(maximum_joint_error <= 22.5, "%s joint separated by %.2f px" % [entity_id, maximum_joint_error])
		_expect(maximum_body_distance <= maxf(125.0, skin.get_stroke_bounds().size.length() * 2.25), "%s rig scattered to %.2f px" % [entity_id, maximum_body_distance])
		_expect(skin.debug_recovery_count() <= 1, "%s needed repeated automatic recovery (%d)" % [entity_id, skin.debug_recovery_count()])
		for rig_body in skin.get_rigid_bodies():
			_expect(is_finite(rig_body.global_position.x) and is_finite(rig_body.global_position.y), "%s segment became non-finite" % entity_id)
		instance.queue_free()
		await process_frame


func _test_anatomy_inference() -> void:
	var reference_signature: Array[String] = []
	var reference_center := Vector2.ZERO
	var reference_bounds := Rect2()
	var reference_support_height := 0.0
	for fixture_value in SpiderReferenceFixtures.variants():
		var fixture: Dictionary = fixture_value
		var fixture_name := String(fixture.get("name", "unnamed"))
		var anatomy: Dictionary = SpiderRigAnalyzer.analyze(fixture.get("strokes", []))
		_expect(bool(anatomy.get("valid", false)), "spider analyzer rejected %s fixture: %s" % [fixture_name, anatomy.get("reason", "")])
		for field in ["torso_paths", "torso_bounds", "torso_center", "support_height", "legs"]:
			_expect(anatomy.has(field), "spider anatomy '%s' omitted %s" % [fixture_name, field])
		var torso_bounds: Rect2 = anatomy.get("torso_bounds", Rect2())
		var torso_center: Vector2 = anatomy.get("torso_center", Vector2.ZERO)
		var support_height := float(anatomy.get("support_height", 0.0))
		var has_open_torso_path := false
		for torso_path_value in anatomy.get("torso_paths", []):
			var torso_path: PackedVector2Array = torso_path_value
			if torso_path.size() >= 2 and torso_path[0].distance_to(torso_path[-1]) > 8.0:
				has_open_torso_path = true
		_expect(torso_bounds.size.x > torso_bounds.size.y * 1.5, "spider '%s' did not infer the open horizontal hub as torso" % fixture_name)
		_expect(has_open_torso_path, "spider '%s' did not preserve its open torso ink" % fixture_name)
		_expect(torso_bounds.grow(2.0).has_point(torso_center), "spider '%s' torso center lies outside its core" % fixture_name)
		_expect(support_height > 1.0, "spider '%s' has no sole-based support height" % fixture_name)

		var legs: Array = anatomy.get("legs", [])
		_expect(legs.size() == 6, "spider '%s' inferred %d legs instead of six" % [fixture_name, legs.size()])
		var side_counts := {-1: 0, 1: 0}
		var side_ranks := {-1: {}, 1: {}}
		var phase_by_leg: Dictionary = {}
		var support_candidates := 0
		var signature: Array[String] = []
		for leg_value in legs:
			var leg: Dictionary = leg_value
			for field in ["path", "root", "sole", "side", "side_rank", "phase_group", "support_candidate", "bend_index"]:
				_expect(leg.has(field), "spider '%s' leg omitted %s" % [fixture_name, field])
			var path: PackedVector2Array = leg.get("path", PackedVector2Array())
			var side := int(leg.get("side", 0))
			var side_rank := int(leg.get("side_rank", -1))
			var phase_group := int(leg.get("phase_group", -1))
			var bend_index := int(leg.get("bend_index", -1))
			_expect(side in [-1, 1], "spider '%s' emitted an invalid leg side" % fixture_name)
			_expect(phase_group in [0, 1], "spider '%s' emitted an invalid gait phase" % fixture_name)
			_expect(path.size() >= 3 and bend_index > 0 and bend_index < path.size() - 1, "spider '%s' leg has no usable drawn bend" % fixture_name)
			if side in [-1, 1]:
				side_counts[side] = int(side_counts[side]) + 1
				var ranks: Dictionary = side_ranks[side]
				ranks[side_rank] = true
				phase_by_leg["%d:%d" % [side, side_rank]] = phase_group
			if bool(leg.get("support_candidate", false)):
				support_candidates += 1
			signature.append("%d:%d:%d:%d" % [side, side_rank, phase_group, int(bool(leg.get("support_candidate", false)))])
		signature.sort()
		_expect(int(side_counts[-1]) == 3 and int(side_counts[1]) == 3, "spider '%s' did not infer three legs per side" % fixture_name)
		_expect((side_ranks[-1] as Dictionary).size() == 3 and (side_ranks[1] as Dictionary).size() == 3, "spider '%s' side ranks are not unique" % fixture_name)
		_expect(support_candidates == 4, "spider '%s' identified %d support candidates instead of four" % [fixture_name, support_candidates])
		for rank in range(3):
			_expect(int(phase_by_leg.get("-1:%d" % rank, -1)) != int(phase_by_leg.get("1:%d" % rank, -1)), "spider '%s' paired same-rank legs into one gait phase" % fixture_name)
		if phase_by_leg.size() == 6:
			_expect(int(phase_by_leg["-1:0"]) != int(phase_by_leg["-1:1"]) and int(phase_by_leg["-1:1"]) != int(phase_by_leg["-1:2"]), "spider '%s' left gait phases do not alternate" % fixture_name)
			_expect(int(phase_by_leg["1:0"]) != int(phase_by_leg["1:1"]) and int(phase_by_leg["1:1"]) != int(phase_by_leg["1:2"]), "spider '%s' right gait phases do not alternate" % fixture_name)
		if reference_signature.is_empty():
			reference_signature = signature
			reference_center = torso_center
			reference_bounds = torso_bounds
			reference_support_height = support_height
		else:
			_expect(signature == reference_signature, "spider anatomy changed with stroke ownership/order for '%s'" % fixture_name)
			_expect(torso_center.distance_to(reference_center) <= 5.0, "spider torso center changed for '%s'" % fixture_name)
			_expect(absf(torso_bounds.size.x - reference_bounds.size.x) <= 8.0 and absf(torso_bounds.size.y - reference_bounds.size.y) <= 8.0, "spider torso bounds changed for '%s'" % fixture_name)
			_expect(absf(support_height - reference_support_height) <= 8.0, "spider support height changed for '%s'" % fixture_name)
	for expected_leg_count in [4, 5, 7, 8]:
		var variable_anatomy := SpiderRigAnalyzer.analyze(SpiderReferenceFixtures.variable_leg_count(expected_leg_count))
		var variable_legs: Array = variable_anatomy.get("legs", [])
		_expect(bool(variable_anatomy.get("valid", false)), "spider analyzer rejected %d-leg topology: %s" % [expected_leg_count, variable_anatomy.get("reason", "")])
		_expect(variable_legs.size() == expected_leg_count, "spider analyzer inferred %d/%d variable legs" % [variable_legs.size(), expected_leg_count])
		var supported_phases := {0: false, 1: false}
		for leg_value in variable_legs:
			var leg := leg_value as Dictionary
			if bool(leg.get("support_candidate", false)):
				supported_phases[int(leg.get("phase_group", -1))] = true
		_expect(bool(supported_phases.get(0, false)) and bool(supported_phases.get(1, false)), "%d-leg spider cannot hand support across both gait phases" % expected_leg_count)
	var split_anatomy := SpiderRigAnalyzer.analyze(SpiderReferenceFixtures.split_leg_segments())
	_expect(bool(split_anatomy.get("valid", false)) and (split_anatomy.get("legs", []) as Array).size() == 6, "split-stroke spider legs lost topology")
	for leg_value in split_anatomy.get("legs", []):
		var leg := leg_value as Dictionary
		_expect((leg.get("ink_paths", []) as Array).size() >= 2, "split-stroke leg lost per-source ink ownership")
	var straight_anatomy := SpiderRigAnalyzer.analyze(SpiderReferenceFixtures.straight_leg_segments())
	var straight_legs: Array = straight_anatomy.get("legs", [])
	_expect(bool(straight_anatomy.get("valid", false)) and straight_legs.size() == 6, "straight two-point legs were rejected as spider anatomy")
	for leg_value in straight_legs:
		var leg := leg_value as Dictionary
		var path := PackedVector2Array(leg.get("path", PackedVector2Array()))
		var bend_index := int(leg.get("bend_index", -1))
		_expect(path.size() >= 3 and bend_index > 0 and bend_index < path.size() - 1, "straight leg received no midpoint articulation")
		if path.size() >= 3 and bend_index > 0 and bend_index < path.size() - 1:
			var arc_before := _test_path_length(path.slice(0, bend_index + 1))
			var arc_after := _test_path_length(path.slice(bend_index, path.size()))
			_expect(absf(arc_before - arc_after) <= 0.5, "straight leg articulation is not at its arc-length midpoint")
	var self_cross_anatomy := SpiderRigAnalyzer.analyze(SpiderReferenceFixtures.self_crossing_hub_leg())
	var self_cross_legs: Array = self_cross_anatomy.get("legs", [])
	_expect(bool(self_cross_anatomy.get("valid", false)) and self_cross_legs.size() == 6, "same-stroke hub intersection lost spider anatomy")
	var recovered_self_cross_leg := false
	for leg_value in self_cross_legs:
		var leg := leg_value as Dictionary
		var sole: Vector2 = leg.get("sole", Vector2.ZERO)
		if sole.distance_to(Vector2(154.0, 266.0)) <= 3.0:
			var root: Vector2 = leg.get("root", Vector2.ZERO)
			recovered_self_cross_leg = root.distance_to(Vector2(236.0, 256.0)) <= 8.0
			break
	_expect(recovered_self_cross_leg, "same-stroke self-intersection did not become the drawn leg root")

	var spider := registry.instantiate_entity("spider") as Node2D
	world.add_child(spider)
	spider.call("apply_drawing", _blank_image(), SpiderReferenceFixtures.separate_legs())
	var spider_skin := spider.get_node("DrawingSkin") as RuntimeRig2D
	var spider_total_mass := 0.0
	var terminal_collision_bodies := 0
	for rig_body in spider_skin.get_rigid_bodies():
		spider_total_mass += rig_body.mass
		if rig_body != spider_skin.get_primary_body():
			_expect(spider_skin.debug_primary_mass() > rig_body.mass, "spider leg outweighed its torso")
		if String(rig_body.name).ends_with("_1"):
			var has_terminal_collision := false
			for child in rig_body.get_children():
				if child is CollisionShape2D and (child as CollisionShape2D).shape != null:
					has_terminal_collision = true
					break
			_expect(has_terminal_collision, "%s has no physical distal-foot collision" % rig_body.name)
			if has_terminal_collision:
				terminal_collision_bodies += 1
	_expect(terminal_collision_bodies == 6, "spider did not build six colliding terminal feet")
	_expect(spider_skin.debug_primary_mass() >= spider_total_mass * 0.4, "spider torso owns less than 40%% of total rig mass")
	var initial_spider_body_count := spider_skin.get_rigid_bodies().size()
	var base_torso_mass := spider_skin.debug_primary_mass()
	var overdrawn_torso := SpiderReferenceFixtures.separate_legs()
	overdrawn_torso.append(_stroke(PackedVector2Array([
		Vector2(226.0, 247.0), Vector2(296.0, 247.0),
		Vector2(226.0, 252.0), Vector2(296.0, 252.0)
	])))
	spider.call("apply_drawing", _blank_image(), overdrawn_torso)
	_expect(spider_skin.debug_primary_mass() > base_torso_mass + 0.1, "spider torso mass ignored additional core ink")
	spider.call("apply_drawing", _blank_image(), SpiderReferenceFixtures.paired_through_body())
	_expect(spider_skin.get_rigid_bodies().size() == initial_spider_body_count, "rebuilding spider retained stale physics bodies")
	_expect(int(spider_skin.debug_spider_snapshot().get("leg_count", 0)) == 6, "rebuilding spider retained stale foot metadata")
	spider.free()
	var malformed_strokes := [_stroke(PackedVector2Array([Vector2(180.0, 250.0), Vector2(332.0, 260.0)]))]
	var malformed_anatomy: Dictionary = SpiderRigAnalyzer.analyze(malformed_strokes)
	_expect(not bool(malformed_anatomy.get("valid", true)), "spider analyzer fabricated anatomy from a lone stroke")
	var fallback_spider := registry.instantiate_entity("spider") as Node2D
	world.add_child(fallback_spider)
	fallback_spider.call("apply_drawing", _blank_image(), malformed_strokes)
	var fallback_skin := fallback_spider.get_node("DrawingSkin") as RuntimeRig2D
	_expect(fallback_skin.skin_mode() == "vector", "malformed spider discarded the player's vector ink")
	_expect(fallback_skin.get_rigid_bodies().size() == 1 and fallback_skin.get_joint_count() == 0, "malformed spider fabricated limbs instead of a safe compound body")
	fallback_spider.free()

	var torso := PackedVector2Array([
		Vector2(228, 160), Vector2(284, 160), Vector2(284, 330),
		Vector2(228, 330), Vector2(228, 160)
	])
	var human_strokes: Array = [
		_stroke(PackedVector2Array([Vector2(228, 215), Vector2(190, 245), Vector2(166, 286)])),
		_stroke(PackedVector2Array([Vector2(284, 215), Vector2(322, 245), Vector2(346, 286)])),
		_stroke(PackedVector2Array([Vector2(242, 328), Vector2(230, 382), Vector2(224, 438)])),
		_stroke(PackedVector2Array([Vector2(270, 328), Vector2(282, 382), Vector2(288, 438)])),
		_stroke(torso)
	]
	var human := registry.instantiate_entity("monkey") as Node2D
	world.add_child(human)
	human.call("apply_drawing", _blank_image(), human_strokes)
	var human_skin := human.get_node("DrawingSkin") as RuntimeRig2D
	var arms := 0
	var legs := 0
	for limb in human_skin.debug_limb_layout():
		if String(limb.get("role", "")) == "arm":
			arms += 1
		elif String(limb.get("role", "")) == "leg":
			legs += 1
	_expect(arms == 2 and legs == 2, "humanoid did not infer two shoulder arms and two hip legs")
	human.free()


func _test_spider_stance_controller() -> void:
	var wall := _add_spider_test_wall()
	var spider := registry.instantiate_entity("spider") as Node2D
	_expect(spider != null, "could not instantiate spider for stance regression")
	if spider == null:
		wall.queue_free()
		return
	world.add_child(spider)
	spider.global_position = Vector2(300.0, 360.0)
	spider.call("set_world_bounds", Rect2(0.0, -520.0, 1000.0, 1200.0))
	spider.call("apply_drawing", _blank_image(), SpiderReferenceFixtures.separate_legs())
	var skin := spider.get_node("DrawingSkin") as RuntimeRig2D
	var anchor := spider.call("get_physics_anchor") as ActiveRigBody2D
	_expect(anchor != null, "spider stance regression has no torso body")
	if anchor == null:
		spider.queue_free()
		wall.queue_free()
		await process_frame
		return
	_expect(not anchor.lock_rotation, "spider torso rotation is still locked")
	for rig_body in skin.get_rigid_bodies():
		_expect(is_equal_approx(rig_body.gravity_scale, 1.0), "spider segment is still using gravity cancellation")

	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")
	Input.action_release("jump")
	# Let the drawing fall onto its actual distal soles, then measure a full
	# 180-frame idle window after contacts and stance have had time to settle.
	for _settle_frame in range(120):
		await physics_frame
	var idle_start := anchor.global_position
	for _idle_frame in range(180):
		await physics_frame
	var idle_summary := skin.get_contact_summary()
	var idle_snapshot := skin.debug_spider_snapshot()
	_expect(bool(idle_snapshot.get("valid", false)), "runtime spider snapshot reports invalid anatomy")
	_expect(int(idle_snapshot.get("leg_count", 0)) == 6, "runtime spider did not preserve the six inferred legs")
	for field in ["torso_center", "torso_bounds", "support_height", "torso_clearance", "support_active", "stance_group", "gait_phase", "gait_targets", "torso_contact", "legs", "feet"]:
		_expect(idle_snapshot.has(field), "runtime spider snapshot omitted %s" % field)
	var feet_value: Variant = idle_summary.get("feet", [])
	_expect(feet_value is Array and (feet_value as Array).size() == 6, "contact summary did not expose six terminal feet")
	if feet_value is Array:
		for foot_value in feet_value as Array:
			var foot: Dictionary = foot_value
			for field in ["leg_index", "side", "side_rank", "phase_group", "support_candidate", "stance", "contact", "position", "plant_target", "gait_target", "target_angle", "normal", "drive_reaction"]:
				_expect(foot.has(field), "spider foot contact state omitted %s" % field)
	var idle_contact_sides := _spider_contact_sides(idle_summary)
	_expect(bool(idle_summary.get("grounded", false)), "spider torso settled without real foot grounding")
	_expect(bool(idle_summary.get("support_active", false)), "spider never activated foot-supported stance")
	_expect(not anchor.standing_hint, "spider stance still relies on the legacy torso standing hint")
	_expect(_contacting_spider_feet(idle_summary) >= 2, "spider settled with fewer than two contacting feet")
	_expect(bool(idle_contact_sides[-1]) and bool(idle_contact_sides[1]), "spider has no real foot contact on one side")
	_expect(not bool(idle_summary.get("torso_contact", true)), "spider is resting its torso on the floor")
	var support_height := float(idle_snapshot.get("support_height", 0.0))
	var torso_clearance := float(idle_snapshot.get("torso_clearance", 0.0))
	_expect(support_height > 1.0 and torso_clearance >= support_height * 0.6, "spider torso clearance %.1f is below 60%% of %.1f support height" % [torso_clearance, support_height])
	var idle_tilt := rad_to_deg(absf(wrapf(anchor.global_rotation, -PI, PI)))
	var idle_drift := anchor.global_position.distance_to(idle_start)
	_expect(idle_tilt < 20.0, "spider torso idled at %.1f degrees" % idle_tilt)
	_expect(idle_drift < 15.0, "spider drifted %.1f px during supported idle" % idle_drift)
	_expect(skin.debug_recovery_count() == 0, "spider needed automatic recovery while establishing stance")

	# A downward 60 px/s mass-scaled impulse must be absorbed by the stance and
	# return the torso to its supported height without invoking runaway recovery.
	var load_height := anchor.global_position.y
	anchor.apply_central_impulse(Vector2(0.0, 60.0) * anchor.mass)
	var load_contacts_restored := false
	for _load_frame in range(120):
		await physics_frame
		var load_summary := skin.get_contact_summary()
		if absf(anchor.global_position.y - load_height) <= 12.0 and _contacting_spider_feet(load_summary) >= 2:
			load_contacts_restored = true
	_expect(absf(anchor.global_position.y - load_height) <= 12.0, "spider torso did not recover its load-bearing height")
	_expect(load_contacts_restored, "spider did not restore real foot contacts within 120 frames of downward load")
	_expect(skin.debug_recovery_count() == 0, "downward load triggered spider runaway recovery")

	# Exercise the real PlayableEntity input path. Jump is explicitly released so
	# forward progress can only come from the grounded stance/gait controller.
	Input.action_release("jump")
	var walk_start := anchor.global_position
	var maximum_vertical_deviation := 0.0
	var maximum_tilt := 0.0
	var grounded_samples := 0
	var observed_stance_groups := {0: false, 1: false}
	var phase_transition_stage := {0: 0, 1: 0}
	var phase_target_excursion := {0: 0.0, 1: 0.0}
	var observed_leg_drive := false
	var drive_on_unplanted_foot := false
	var maximum_leg_drive := 0.0
	var maximum_drive_balance_error := 0.0
	Input.action_press("move_right")
	for _walk_frame in range(180):
		await physics_frame
		var walk_summary := skin.get_contact_summary()
		var walk_snapshot := skin.debug_spider_snapshot()
		var reported_stance_group := int(walk_snapshot.get("stance_group", -1))
		if reported_stance_group in [0, 1]:
			observed_stance_groups[reported_stance_group] = true
		if bool(walk_summary.get("grounded", false)):
			grounded_samples += 1
		maximum_vertical_deviation = maxf(maximum_vertical_deviation, absf(anchor.global_position.y - walk_start.y))
		maximum_tilt = maxf(maximum_tilt, rad_to_deg(absf(wrapf(anchor.global_rotation, -PI, PI))))
		var phase_has_stance := {0: false, 1: false}
		var phase_has_swing_target := {0: false, 1: false}
		var leg_drive_force := Vector2(walk_summary.get("leg_drive_force", Vector2.ZERO))
		var drive_reaction_sum := Vector2.ZERO
		maximum_leg_drive = maxf(maximum_leg_drive, leg_drive_force.length())
		for foot_value in (walk_summary.get("feet", []) as Array):
			var foot: Dictionary = foot_value
			var drive_reaction := Vector2(foot.get("drive_reaction", Vector2.ZERO))
			drive_reaction_sum += drive_reaction
			if drive_reaction.length_squared() > 1.0:
				observed_leg_drive = true
				drive_on_unplanted_foot = drive_on_unplanted_foot or not bool(foot.get("stance", false))
			var phase_group := int(foot.get("phase_group", -1))
			if phase_group not in [0, 1] or not bool(foot.get("support_candidate", false)):
				continue
			if bool(foot.get("stance", false)):
				phase_has_stance[phase_group] = true
			else:
				var gait_target: Vector2 = foot.get("gait_target", Vector2.ZERO)
				var plant_target: Vector2 = foot.get("plant_target", gait_target)
				var target_excursion := gait_target.distance_to(plant_target)
				phase_target_excursion[phase_group] = maxf(float(phase_target_excursion[phase_group]), target_excursion)
				if target_excursion >= 6.0:
					phase_has_swing_target[phase_group] = true
		maximum_drive_balance_error = maxf(maximum_drive_balance_error, (leg_drive_force + drive_reaction_sum).length())
		for phase_group in [0, 1]:
			var stage := int(phase_transition_stage[phase_group])
			if stage == 0 and bool(phase_has_stance[phase_group]):
				phase_transition_stage[phase_group] = 1
			elif stage == 1 and bool(phase_has_swing_target[phase_group]):
				phase_transition_stage[phase_group] = 2
			elif stage == 2 and bool(phase_has_stance[phase_group]):
				phase_transition_stage[phase_group] = 3
	Input.action_release("move_right")
	var forward_travel := anchor.global_position.x - walk_start.x
	_expect(forward_travel >= 90.0, "spider moved only %.1f px during 180 no-jump frames" % forward_travel)
	_expect(maximum_vertical_deviation < 35.0, "spider torso deviated %.1f px vertically while walking" % maximum_vertical_deviation)
	_expect(maximum_tilt < 35.0, "spider torso tilted %.1f degrees while walking" % maximum_tilt)
	_expect(grounded_samples >= 90, "spider had real foot contact for only %d/180 walk samples" % grounded_samples)
	_expect(observed_leg_drive and maximum_leg_drive > 1.0, "spider walked without stance-leg drive forces")
	_expect(not drive_on_unplanted_foot, "spider applied locomotion drive through an unplanted foot")
	_expect(maximum_drive_balance_error <= maxf(0.5, maximum_leg_drive * 0.001), "spider leg drive injected an unbalanced %.2f N torso force" % maximum_drive_balance_error)
	_expect(bool(observed_stance_groups[0]) and bool(observed_stance_groups[1]), "spider never handed stance between both gait groups")
	_expect(int(phase_transition_stage[0]) >= 3 and int(phase_transition_stage[1]) >= 3, "both gait groups did not complete stance-swing-stance transitions (%d, %d; targets %.1f, %.1f)" % [phase_transition_stage[0], phase_transition_stage[1], phase_target_excursion[0], phase_target_excursion[1]])
	_expect(skin.debug_max_joint_error() <= 22.5, "spider joint separated by %.2f px during walking" % skin.debug_max_joint_error())
	_expect(skin.debug_recovery_count() == 0, "spider locomotion invoked automatic recovery")

	# Jump must release active stance, travel upward, and reacquire support only
	# after real terminal feet land again.
	var jump_start_y := anchor.global_position.y
	var minimum_jump_y := jump_start_y
	var stance_released := false
	var became_airborne := false
	var stance_reacquired := false
	var airborne_leg_drive := false
	Input.action_press("jump")
	# Hold across one complete physics callback; SceneTree.physics_frame resumes
	# before node _physics_process callbacks in the same tick.
	await physics_frame
	await physics_frame
	Input.action_release("jump")
	for _jump_frame in range(240):
		var jump_summary := skin.get_contact_summary()
		minimum_jump_y = minf(minimum_jump_y, anchor.global_position.y)
		if not bool(jump_summary.get("support_active", false)):
			stance_released = true
		if not bool(jump_summary.get("grounded", false)):
			became_airborne = true
			airborne_leg_drive = airborne_leg_drive \
				or Vector2(jump_summary.get("leg_drive_force", Vector2.ZERO)).length_squared() > 1.0
		elif became_airborne and bool(jump_summary.get("support_active", false)) and _contacting_spider_feet(jump_summary) >= 2:
			stance_reacquired = true
		await physics_frame
	_expect(stance_released, "spider jump never released stance anchors")
	_expect(jump_start_y - minimum_jump_y >= 12.0, "spider jump produced no meaningful upward travel")
	_expect(stance_reacquired, "spider did not reacquire real foot support after landing")
	_expect(not airborne_leg_drive, "spider retained stance-leg propulsion while airborne")
	_expect(skin.debug_recovery_count() == 0, "spider jump/landing invoked automatic recovery")

	# Wall climbing remains a fallback transition and must consume aggregated rig
	# contact instead of relying on the torso alone.
	var wall_seen := false
	Input.action_press("move_right")
	for _wall_approach_frame in range(180):
		await physics_frame
		if bool(skin.get_contact_summary().get("wall_contact", false)):
			wall_seen = true
			break
	var climb_start_y := anchor.global_position.y
	var climb_min_y := climb_start_y
	Input.action_press("move_up")
	for _climb_frame in range(90):
		await physics_frame
		var climb_summary := skin.get_contact_summary()
		wall_seen = wall_seen or bool(climb_summary.get("wall_contact", false))
		climb_min_y = minf(climb_min_y, anchor.global_position.y)
	Input.action_release("move_up")
	Input.action_release("move_right")
	_expect(wall_seen, "spider never reported aggregated wall contact")
	_expect(climb_start_y - climb_min_y >= 6.0, "spider wall-climb fallback produced no upward travel")
	_expect(skin.debug_max_joint_error() <= 22.5 and skin.debug_recovery_count() == 0, "spider became unstable during wall-climb smoke test")

	spider.queue_free()
	wall.queue_free()
	await process_frame


## An uncontrolled, grounded creature must stay put. The active ragdoll must not pump
## energy through its limbs (via undamped gravity compensation) and wander/spin on its
## own when the player gives no input.
## A drawn creature standing on the ground must still LOOK like the thing the
## player drew. Two regressions are guarded here, both of which made creatures
## read as broken no matter how the gait was tuned:
##   1. Stand height was measured to the middle of the foot segment rather than to
##      the bottom of its collision shape, so the rig was parked with the lower
##      half of every leg inside the floor and the ground shoved the legs flat.
##   2. The pose muscles were too soft to hold a limb against the ground reaction
##      of the creature's own weight, so limbs splayed and stayed splayed.
func _test_pose_holding() -> void:
	# The floor added by _add_floor() spans y 400..440 at x 0..1000.
	var floor_top := 400.0
	for entity_id in ["horse", "pig", "crab", "monkey"]:
		var entry := registry.get_entity(entity_id)
		if entry.is_empty():
			continue
		var instance := registry.instantiate_entity(entity_id) as Node2D
		if instance == null:
			continue
		world.add_child(instance)
		instance.global_position = Vector2(500.0, 300.0)
		instance.call("set_world_bounds", Rect2(0.0, -520.0, 3760.0, 1200.0))
		instance.call("apply_drawing", _blank_image(), _quadruped_fixture())
		var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
		var primary := skin.get_primary_body()
		var rest_angles: Dictionary = {}
		for body in skin.get_rigid_bodies():
			if is_instance_valid(body) and body != primary:
				rest_angles[body.get_instance_id()] = body.rotation - primary.rotation
		for _settle in range(180):
			await physics_frame

		var deepest := 0.0
		var collapse := 0.0
		for body in skin.get_rigid_bodies():
			if not is_instance_valid(body) or body == primary:
				continue
			deepest = maxf(deepest, body.global_position.y - floor_top)
			if rest_angles.has(body.get_instance_id()):
				var rest: float = rest_angles[body.get_instance_id()]
				collapse = maxf(collapse, absf(wrapf(body.rotation - primary.rotation - rest, -PI, PI)))
		_expect(
			deepest < 26.0,
			"%s sank %.1f px of limb below the floor (feet buried, legs get shoved flat)" % [entity_id, deepest]
		)
		_expect(
			rad_to_deg(collapse) < 45.0,
			"%s limbs collapsed %.1f deg from the drawn pose" % [entity_id, rad_to_deg(collapse)]
		)
		instance.queue_free()
		await process_frame


## Players draw wings as closed loops either side of a thin body. Three separate
## rules used to conspire to wreck that drawing, and all three are guarded here:
##   1. Limb role came from the LAST point drawn, which for a loop returns to its
##      start -- so a wing reported no direction and was classified as a leg, and
##      the wing-flap gait never ran on it.
##   2. Torso choice only looked for limbs attaching above/below, so a wing loop's
##      closed+area bonus beat the body line, the wing became the torso and
##      swallowed the other wing.
##   3. A closed roundish stroke was welded to the torso as a head/eye blob, and
##      when it was not, it was split across bodies so the loop tore open mid-beat.
func _test_wing_anatomy() -> void:
	var instance := registry.instantiate_entity("butterfly") as Node2D
	_expect(instance != null, "could not instantiate butterfly")
	if instance == null:
		return
	world.add_child(instance)
	instance.global_position = Vector2(400.0, 200.0)
	instance.call("set_world_bounds", Rect2(0.0, -520.0, 3760.0, 1200.0))
	instance.call("apply_drawing", _blank_image(), _butterfly_fixture())
	var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
	var primary := skin.get_primary_body()
	var roles := skin.debug_segment_roles()
	_expect(roles.count("wing") >= 2, "butterfly wings were not rigged as wings (roles: %s)" % str(roles))
	# One body per wing plus the torso: a split wing loop tears open when it beats.
	_expect(
		skin.get_rigid_bodies().size() == 3,
		"butterfly built %d bodies; each wing loop must stay one intact piece" % skin.get_rigid_bodies().size()
	)
	var rest_angles: Dictionary = {}
	for body in skin.get_rigid_bodies():
		if is_instance_valid(body) and body != primary:
			rest_angles[body.get_instance_id()] = body.rotation - primary.rotation
	instance.set_physics_process(false)
	var collapse := 0.0
	for _frame in range(180):
		skin.set_motion_state("fly", {"moving": true, "speed_ratio": 1.0, "direction": 1.0})
		await physics_frame
		for body in skin.get_rigid_bodies():
			if not is_instance_valid(body) or body == primary or not rest_angles.has(body.get_instance_id()):
				continue
			var rest: float = rest_angles[body.get_instance_id()]
			collapse = maxf(collapse, absf(wrapf(body.rotation - primary.rotation - rest, -PI, PI)))
	_expect(
		rad_to_deg(collapse) < 70.0,
		"butterfly wings swung %.1f deg from the drawn pose; the silhouette stops reading as a butterfly" % rad_to_deg(collapse)
	)
	instance.queue_free()
	await process_frame


## Fidelity mode. A drawing made of several broad loop-shaped appendages cannot be
## articulated without ceasing to look like itself, so it is built as ONE rigid piece
## and animated as a whole body. Both halves of that bargain are asserted: the messy
## drawing must go rigid, and an ordinary thin-limbed drawing must NOT -- otherwise
## the rule would quietly swallow every creature and nothing would animate its limbs.
func _test_fidelity_mode() -> void:
	# A drawing made of several broad loop-shaped appendages -- the four-loop
	# butterfly that started this -- must ARTICULATE those appendages, not be
	# flattened into one rigid piece. Collapsing it was an earlier answer to the
	# loops scrambling; the ink now hinges on pivots at the joints it was drawn on,
	# so the shape holds by construction and flattening it only costs the wings.
	var messy := registry.instantiate_entity("butterfly") as Node2D
	if messy != null:
		world.add_child(messy)
		messy.global_position = Vector2(500.0, 200.0)
		messy.call("set_world_bounds", Rect2(0.0, -520.0, 3760.0, 1200.0))
		messy.call("apply_drawing", _blank_image(), _four_loop_fixture())
		var messy_skin := messy.get_node("DrawingSkin") as RuntimeRig2D
		_expect(messy_skin.skin_mode() == "vector", "four-loop drawing discarded the vector ink")
		_expect(messy_skin.debug_skin_active(), "four-loop drawing was not skinned to its class skeleton")
		# A butterfly is a flier whatever it looks like, so it HAS wing bones -- the
		# question a class-driven skeleton raises is whether they own any ink. Bones
		# that carry nothing beat invisibly, which is the failure this design invites
		# and the old geometric one could not have.
		var mass := messy_skin.debug_bone_ink_mass()
		var wing_mass := float(mass.get("wing_l", 0.0)) + float(mass.get("wing_r", 0.0))
		_expect(
			wing_mass > 0.15,
			"four-loop drawing's wing bones carry only %.0f%% of its ink" % (wing_mass * 100.0)
		)
		messy.set_physics_process(false)
		var travel: float = await _ink_travel(
			messy_skin, "fly", {"moving": true, "speed_ratio": 1.0, "direction": 1.0}, 150
		)
		_expect(travel > 2.0, "four-loop drawing's wings never beat (%.2f px of ink travel)" % travel)
		messy.queue_free()
		await process_frame

	var thin := registry.instantiate_entity("horse") as Node2D
	if thin != null:
		world.add_child(thin)
		thin.global_position = Vector2(500.0, 200.0)
		thin.call("set_world_bounds", Rect2(0.0, -520.0, 3760.0, 1200.0))
		thin.call("apply_drawing", _blank_image(), _quadruped_fixture())
		var thin_skin := thin.get_node("DrawingSkin") as RuntimeRig2D
		_expect(thin_skin.get_joint_count() > 0, "walker lost its articulation")
		thin.queue_free()
		await process_frame


func _test_fidelity_guard() -> void:
	for entity_id in ["frog", "spider", "horse"]:
		var entry := registry.get_entity(entity_id)
		if entry.is_empty():
			continue
		var instance := registry.instantiate_entity(entity_id) as Node2D
		if instance == null:
			continue
		world.add_child(instance)
		instance.global_position = Vector2(500.0, 250.0)
		instance.call("set_world_bounds", Rect2(0.0, -520.0, 3760.0, 1200.0))
		instance.call("apply_drawing", _blank_image(), _quadruped_fixture())
		var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
		var primary := skin.get_primary_body()
		_expect(primary != null, "%s has no primary body" % entity_id)
		if primary == null:
			instance.queue_free()
			continue
		# What "the drawing animates without coming apart" means once the ink is skinned
		# rather than hung off pivots. The old rig could tear a stroke or leave part of
		# it behind because strokes were cut between bodies; a skinned stroke is one
		# polyline for life, so the way it could still fail is by STRETCHING -- blended
		# bone transforms pulling a limb away from the body it joins.
		_expect(skin.debug_skin_active(), "%s is not skinned to its class skeleton" % entity_id)
		instance.set_physics_process(false)
		var motion := {"moving": true, "speed_ratio": 1.0, "direction": 1.0}
		# The bound is on the drawing COMING APART, not on the blend being perfect.
		# Linear blend skinning shears ink that straddles a weight gradient, and the
		# measured envelope across the roster is: swimmer/flier/spider 100-101%,
		# walker 113%, hopper/biped 131-135% -- worst where a limb rotates furthest
		# while a third of its ink still belongs to the body. It is bounded and it
		# recovers every cycle. A stroke actually tearing free grows without bound and
		# never comes back, which is what this still catches. Dual-quaternion skinning
		# in SkinBinding.deform is what would remove the residual.
		var stretch: float = await _ink_stretch(skin, "walk", motion, 200)
		_expect(
			stretch < 1.40,
			"%s limb ink stretched to %.0f%% of its drawn length" % [entity_id, stretch * 100.0]
		)
		# And it must stay a drawing of this creature: the gait is bounded by each
		# bone's authored limit, so no point can wander far from where it was drawn.
		var bounds := skin.get_stroke_bounds()
		var travel: float = await _ink_travel(skin, "walk", motion, 60)
		_expect(
			travel < bounds.size.length() * 0.5,
			"%s ink travelled %.1f px, over half its own diagonal" % [entity_id, travel]
		)
		instance.queue_free()
		await process_frame


## How far the rendered drawing actually moves over `frames` of the given motion: the
## largest distance any single ink point travels from where it started.
##
## Measured on the ink itself rather than on the nodes that carry it. A pivot node can
## rotate, and a bone can swing through its whole range, while the drawing on screen
## sits perfectly still -- if the thing that moved owned no ink, the player sees
## nothing. Only the rendered points can tell the difference.
func _ink_travel(skin: RuntimeRig2D, state: String, motion: Dictionary, frames: int) -> float:
	var first := skin.debug_skin_points()
	var travel := 0.0
	for _frame in range(frames):
		skin.set_motion_state(state, motion)
		await physics_frame
		var now := skin.debug_skin_points()
		for stroke_index in range(mini(first.size(), now.size())):
			var before: PackedVector2Array = first[stroke_index]
			var after: PackedVector2Array = now[stroke_index]
			for point_index in range(mini(before.size(), after.size())):
				travel = maxf(travel, before[point_index].distance_to(after[point_index]))
	return travel


## The worst ratio between a stroke's rendered length and its drawn length, over
## `frames` of motion. Skinning moves ink by blending bone transforms, so a little
## stretch across a joint is inherent; a drawing coming apart is not, and shows up
## here as a stroke growing without bound.
func _ink_stretch(skin: RuntimeRig2D, state: String, motion: Dictionary, frames: int) -> float:
	var rest: Array[float] = []
	for stroke_value in skin.get_vector_strokes():
		rest.append(_test_path_length((stroke_value as Dictionary)["points"]))
	var worst := 1.0
	for _frame in range(frames):
		skin.set_motion_state(state, motion)
		await physics_frame
		var now := skin.debug_skin_points()
		for stroke_index in range(mini(rest.size(), now.size())):
			if rest[stroke_index] <= 0.001:
				continue
			var ratio := _test_path_length(now[stroke_index]) / rest[stroke_index]
			worst = maxf(worst, maxf(ratio, 1.0 / maxf(0.001, ratio)))
	return worst


## Every Line2D the rig renders, wherever it was parented.
func _ink_lines(root_node: Node) -> Array:
	var found: Array = []
	for child in root_node.get_children():
		if child is Line2D:
			found.append(child)
		found.append_array(_ink_lines(child))
	return found


func _four_loop_fixture() -> Array:
	var strokes: Array = []
	for spec in [
		[200.0, 210.0, 62.0, 55.0], [312.0, 220.0, 62.0, 52.0],
		[212.0, 305.0, 52.0, 48.0], [300.0, 312.0, 48.0, 44.0]
	]:
		var loop := PackedVector2Array()
		for index in range(15):
			var t := TAU * float(index) / 14.0
			loop.append(Vector2(spec[0] + cos(t) * spec[2], spec[1] + sin(t) * spec[3]))
		strokes.append(_stroke(loop))
	strokes.append(_stroke(PackedVector2Array([
		Vector2(256, 160), Vector2(254, 220), Vector2(252, 280), Vector2(250, 350)
	])))
	return strokes


## A thin body line with a closed wing loop either side of it.
func _butterfly_fixture() -> Array:
	var bodyline := PackedVector2Array([Vector2(256, 200), Vector2(256, 250), Vector2(256, 300)])
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for index in range(13):
		var t := TAU * float(index) / 12.0
		left.append(Vector2(256.0 - 55.0 + cos(t) * 48.0, 240.0 + sin(t) * 40.0))
		right.append(Vector2(256.0 + 55.0 + cos(t) * 48.0, 240.0 + sin(t) * 40.0))
	return [_stroke(bodyline), _stroke(left), _stroke(right)]


## A skeleton is data, so it fails by typo: a misspelled bone name, a parent that does
## not exist, a pivot outside the drawing, or an amplitude_key naming a field no rig
## profile has. None of those raise an error at build time -- they surface as a creature
## that quietly will not move. Every one is caught here instead.
func _test_skeleton_manifest() -> void:
	var archetypes := SkeletonLibrary.archetype_names()
	for required in ["walker", "biped", "flier", "swimmer", "hopper", "none"]:
		_expect(required in archetypes, "skeletons.json has no '%s' archetype" % required)

	# Every field a skeleton names by string must exist in at least one rig profile,
	# otherwise the gait silently reads zero.
	var profile_fields: Dictionary = {}
	var dir := DirAccess.open("res://config/rigs")
	if dir != null:
		for file_name in dir.get_files():
			if not file_name.ends_with(".json"):
				continue
			var parsed: Variant = JSON.parse_string(
				FileAccess.get_file_as_string("res://config/rigs/" + file_name)
			)
			if parsed is Dictionary:
				for field: String in (parsed as Dictionary).keys():
					profile_fields[field] = true

	for entity_id in registry.get_entity_ids():
		var entry := registry.get_entity(entity_id)
		var rig_type := String(entry.get("rig_type", "none"))
		var skeleton := SkeletonLibrary.resolve(entity_id, rig_type)
		_expect(not skeleton.is_empty(), "%s (%s) resolved no skeleton" % [entity_id, rig_type])
		if skeleton.is_empty():
			continue
		for problem in SkeletonLibrary.validate(skeleton):
			_expect(false, "%s skeleton: %s" % [entity_id, problem])

		# A named profile key resolving to a value of the WRONG KIND is the failure this
		# design invites, and it does not raise: every key here exists and is a number.
		# The swimmers named wave_length as their gait frequency -- 44 to 82 PIXELS read
		# as hertz -- so they ran at more than a cycle per frame, aliased into noise, and
		# rendered motionless. The hopper named landing_squash as a continuous body
		# scale, so its legs shrank by a fifth on every hop. Both are in range for a
		# number and absurd for a frequency and a scale, which is what is checked.
		var profile_path := "res://config/rigs/%s.json" % entity_id
		var profile_for_rig: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(profile_path)
		) if FileAccess.file_exists(profile_path) else null
		if profile_for_rig is Dictionary:
			var placed := Skeleton2D_Rig.build(skeleton, Rect2(0.0, 0.0, 200.0, 200.0), profile_for_rig)
			# Nyquist: above 30 Hz a 60 fps sine is sampled less than twice per cycle and
			# stops being an animation. Real gaits here are 1.2 to 9.
			_expect(
				placed.frequency_hz > 0.05 and placed.frequency_hz <= 15.0,
				"%s (%s) resolves a gait frequency of %.1f Hz, which is not a gait" % [
					entity_id, rig_type, placed.frequency_hz
				]
			)
			var motion: Dictionary = skeleton.get("body_motion", {})
			# Calibrated to what renders correctly rather than to a round number. The
			# flier has a field built for this (flap_squash, 0.10-0.12); everyone else
			# borrows landing_squash, and 0.10-0.16 reads as squash-and-stretch on a
			# walker or a biped. The hopper's 0.22 was where it stopped reading as a
			# body pulse and started reading as the legs changing length.
			var squash := float(profile_for_rig.get(String(motion.get("squash_key", "")), motion.get("squash", 0.0)))
			_expect(
				absf(squash) <= 0.18,
				"%s squashes the whole creature by %.0f%% every cycle" % [entity_id, squash * 100.0]
			)
			var bob := float(profile_for_rig.get(String(motion.get("bob_key", "")), motion.get("bob_px", 0.0)))
			_expect(
				absf(bob) <= 24.0,
				"%s bobs %.0f px every cycle, which is a jump and not a bob" % [entity_id, bob]
			)
		for key in SkeletonLibrary.referenced_profile_keys(skeleton):
			_expect(
				profile_fields.has(key),
				"%s skeleton names profile field '%s', which no rig profile defines" % [entity_id, key]
			)
		# A creature whose gait drives nothing would render frozen.
		if rig_type != "none":
			var gaited := 0
			for bone_value in skeleton.get("bones", []):
				if not ((bone_value as Dictionary).get("gait", {}) as Dictionary).is_empty():
					gaited += 1
			_expect(gaited >= 1, "%s (%s) has no bone with a gait" % [entity_id, rig_type])


## Every ink point must be bound to something, with weights that sum to one. If a point
## can end up with no bone, it would stay behind while the rest of the drawing moved --
## a piece detaching, which is precisely what players kept reporting.
func _test_skin_weights() -> void:
	for case_value in _skin_cases():
		var case_data: Dictionary = case_value
		var label := String(case_data["label"])
		var binding := _bind_case(case_data)
		if binding == null:
			continue
		var report := binding.report()
		_expect(int(report["point_count"]) > 0, "'%s' bound no points" % label)
		_expect(
			int(report["unbound_points"]) == 0,
			"'%s' left %d ink points with no bone" % [label, int(report["unbound_points"])]
		)
		_expect(
			absf(float(report["min_weight_sum"]) - 1.0) < 1e-3,
			"'%s' weights sum to %.4f, not 1" % [label, float(report["min_weight_sum"])]
		)


## At rest the creature must BE the drawing. With every bone unrotated the skinning
## transforms cancel exactly, so this is an equality, not a tolerance -- and it is the
## property the whole approach rests on: whatever the gait later does, frame zero is
## always the player's own ink.
func _test_skinned_rest_identity() -> void:
	for case_value in _skin_cases():
		var case_data: Dictionary = case_value
		var label := String(case_data["label"])
		var binding := _bind_case(case_data)
		if binding == null:
			continue
		var skeleton := binding.skeleton()
		var angles := PackedFloat32Array()
		angles.resize(skeleton.bones.size())
		var posed := skeleton.pose(angles)
		var worst := 0.0
		for stroke_index in range(binding.stroke_count()):
			var rest := binding.rest_points(stroke_index)
			var deformed := binding.deform(stroke_index, posed)
			_expect(
				deformed.size() == rest.size(),
				"'%s' stroke %d changed point count" % [label, stroke_index]
			)
			for i in range(mini(rest.size(), deformed.size())):
				worst = maxf(worst, rest[i].distance_to(deformed[i]))
		_expect(worst < 0.01, "'%s' rest pose moved ink by %.4f px" % [label, worst])


## The same guarantee, but measured on the LIVE rig instead of the binding in
## isolation. Stage 1 proved the skinning transforms cancel at rest; this proves that
## nothing between them and the screen undoes it -- where the skin root is placed on
## the torso, how the Line2Ds are rebuilt from the strokes, what the gait does on its
## very first tick. The instant a creature exists it must be the player's drawing, to
## the pixel, or every claim made for the rig is about something the player never saw.
func _test_skinned_rig_renders_the_drawing() -> void:
	for entity_id in _living_entity_ids():
		var instance := registry.instantiate_entity(entity_id) as Node2D
		if instance == null:
			continue
		world.add_child(instance)
		instance.global_position = Vector2(420.0, 240.0)
		instance.call("apply_drawing", _blank_image(), _fixture_for(entity_id))
		var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
		if skin.debug_skin_active():
			var drawn := skin.get_vector_strokes()
			var rendered := skin.debug_skin_points()
			_expect(
				rendered.size() == drawn.size(),
				"%s renders %d strokes for %d drawn" % [entity_id, rendered.size(), drawn.size()]
			)
			# Compared in WORLD space, against where the entity holding the drawing
			# actually is. Comparing the ink to itself in its own local space would pass
			# no matter where that space had been put, which is most of what this is
			# here to check.
			var to_world := skin.debug_skin_transform()
			var drawn_to_world := instance.global_transform
			var worst := 0.0
			for index in range(mini(rendered.size(), drawn.size())):
				var source: PackedVector2Array = (drawn[index] as Dictionary)["points"]
				var shown: PackedVector2Array = rendered[index]
				_expect(
					shown.size() == source.size(),
					"%s stroke %d renders %d points for %d drawn" % [entity_id, index, shown.size(), source.size()]
				)
				for point_index in range(mini(source.size(), shown.size())):
					var here := to_world * shown[point_index]
					var expected := drawn_to_world * source[point_index]
					worst = maxf(worst, here.distance_to(expected))
			_expect(worst < 0.01, "%s renders its first frame %.4f px off the drawing" % [entity_id, worst])
			# And drawn ONCE. Every Line2D under the entity must be one the skin owns --
			# an ink line the builders left behind renders the drawing a second time,
			# frozen, underneath the one that animates. Two of them per stroke: the ink
			# and the halo beneath it.
			_expect(
				_ink_lines(instance).size() == rendered.size() * 2,
				"%s renders %d ink lines for %d strokes; the drawing is doubled" % [
					entity_id, _ink_lines(instance).size(), rendered.size()
				]
			)
		instance.queue_free()
		await process_frame


## The failure a class-driven skeleton invites, and a geometric one could not have:
## the skeleton is right for the CLASS, and wrong for THIS DRAWING. Every bone is
## placed, the gait drives them all correctly -- and they own none of the player's
## ink, so a fully rigged creature renders frozen. Nothing raises an error; the
## drawing simply never moves. So the ink is followed through to the bones that move.
func _test_gait_reaches_the_ink() -> void:
	var stranded: Array = []
	for entity_id in _living_entity_ids():
		var rig_type := String(registry.get_entity(entity_id).get("rig_type", ""))
		var instance := registry.instantiate_entity(entity_id) as Node2D
		if instance == null:
			continue
		world.add_child(instance)
		instance.global_position = Vector2(420.0, 240.0)
		instance.call("apply_drawing", _blank_image(), _fixture_for(entity_id))
		var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
		if skin.debug_skin_active():
			var state := _gait_for_rig(rig_type)
			var mass := skin.debug_bone_ink_mass()
			var carried := 0.0
			for bone_value in SkeletonLibrary.resolve(entity_id, rig_type).get("bones", []):
				var bone: Dictionary = bone_value
				var gait: Dictionary = bone.get("gait", {})
				if gait.is_empty():
					continue
				var states: Dictionary = gait.get("states", {})
				if states.is_empty() or float(states.get(state, 0.0)) > 0.0:
					carried += float(mass.get(String(bone.get("name", "")), 0.0))
			if carried < 0.10:
				stranded.append("%s(%s in %s, %.0f%%)" % [entity_id, rig_type, state, carried * 100.0])
		instance.queue_free()
		await process_frame
	_expect(stranded.is_empty(), "these classes move bones that carry no ink: %s" % str(stranded))


## Drawings spanning the shapes that broke the old rig: wings apart, wings meeting in
## the middle, a single continuous scribble, and an extreme aspect ratio.
func _skin_cases() -> Array:
	return [
		{"label": "butterfly wings apart", "rig": "flier", "profile": "butterfly",
		 "strokes": _butterfly_fixture()},
		{"label": "butterfly four loops", "rig": "flier", "profile": "butterfly",
		 "strokes": _four_loop_fixture()},
		{"label": "quadruped", "rig": "walker", "profile": "horse",
		 "strokes": _quadruped_fixture()},
		{"label": "single scribble", "rig": "walker", "profile": "horse",
		 "strokes": _scribble_fixture()},
		{"label": "extreme aspect", "rig": "swimmer", "profile": "fish",
		 "strokes": _wide_fixture()},
	]


func _bind_case(case_data: Dictionary) -> SkinBinding:
	var strokes: Array = case_data["strokes"]
	var skeleton_data := SkeletonLibrary.resolve(String(case_data["profile"]), String(case_data["rig"]))
	if skeleton_data.is_empty():
		_expect(false, "no skeleton for %s" % String(case_data["label"]))
		return null
	var profile: Dictionary = {}
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://config/rigs/%s.json" % String(case_data["profile"]))
	)
	if parsed is Dictionary:
		profile = parsed
	var bounds := _fixture_bounds(strokes)
	var skeleton := Skeleton2D_Rig.build(skeleton_data, bounds, profile)
	var binding := SkinBinding.new()
	binding.bind(strokes, skeleton)
	return binding


func _fixture_bounds(strokes: Array) -> Rect2:
	var bounds := Rect2()
	var started := false
	for stroke_value in strokes:
		for point: Vector2 in PackedVector2Array((stroke_value as Dictionary)["points"]):
			if not started:
				bounds = Rect2(point, Vector2.ZERO)
				started = true
			else:
				bounds = bounds.expand(point)
	return bounds


## One unbroken line that loops back on itself -- no separate limbs to find.
func _scribble_fixture() -> Array:
	var points := PackedVector2Array()
	for index in range(48):
		var t := TAU * float(index) / 24.0
		points.append(Vector2(256.0 + cos(t) * (60.0 + 18.0 * sin(t * 3.0)),
							  250.0 + sin(t) * (44.0 + 14.0 * cos(t * 2.0))))
	return [_stroke(points)]


## 10:1 aspect: the skeleton must stretch with the drawing, not smear onto a line.
func _wide_fixture() -> Array:
	var body := PackedVector2Array()
	for index in range(17):
		var angle := TAU * float(index) / 16.0
		body.append(Vector2(256.0 + cos(angle) * 200.0, 250.0 + sin(angle) * 20.0))
	return [_stroke(body)]


## This is a drawing game: EVERY playable class has to visibly animate, not just the
## handful that get looked at by hand. Each creature is rigged from a drawing shaped
## the way its archetype is normally drawn and driven through its own gait, and its
## limbs must actually swing. A creature that rigs no hinges, or hinges that never
## move, is a creature the player sees frozen.
func _test_every_class_animates() -> void:
	var silent: Array = []
	for entity_id in registry.get_entity_ids():
		var entry := registry.get_entity(entity_id)
		if String(entry.get("runtime_role", "")) != "active_ragdoll_morph":
			continue
		var rig_type := String(entry.get("rig_type", ""))
		var instance := registry.instantiate_entity(entity_id) as Node2D
		if instance == null:
			continue
		world.add_child(instance)
		instance.global_position = Vector2(500.0, 250.0)
		instance.call("set_world_bounds", Rect2(0.0, -520.0, 3760.0, 1200.0))
		instance.call("apply_drawing", _blank_image(), _archetype_fixture(entity_id, rig_type))
		var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
		instance.set_physics_process(false)
		if not skin.debug_skin_active():
			silent.append("%s(%s, not skinned)" % [entity_id, rig_type])
			instance.queue_free()
			await process_frame
			continue
		# Measured on the rendered ink, not on the bones. Every playable class has a
		# skeleton by construction now, so "does it have hinges" no longer distinguishes
		# anything -- what still can, and is the whole point, is whether the drawing the
		# player is looking at actually moves.
		var travel: float = await _ink_travel(skin, _gait_for_rig(rig_type), {
			"moving": true, "speed_ratio": 1.0, "direction": 1.0, "charge_ratio": 1.0
		}, 120)
		if travel < 2.0:
			silent.append("%s(%s, %.2f px)" % [entity_id, rig_type, travel])
		instance.queue_free()
		await process_frame
	_expect(silent.is_empty(), "these classes render frozen: %s" % str(silent))


## A drawing shaped the way each archetype is actually drawn: a finned body for a
## swimmer, a body with two wings for a flier, a body on four legs for a walker.
func _archetype_fixture(entity_id: String, rig_type: String) -> Array:
	if entity_id == "spider":
		return SpiderReferenceFixtures.separate_legs()
	if entity_id == "snake":
		var wave := PackedVector2Array()
		for index in range(18):
			wave.append(Vector2(120.0 + index * 17.0, 256.0 + sin(float(index) * 0.75) * 30.0))
		return [_stroke(wave)]
	if rig_type == "swimmer":
		return [
			_stroke(_oval(256.0, 250.0, 70.0, 38.0)),
			_stroke(PackedVector2Array([
				Vector2(186, 250), Vector2(140, 215), Vector2(126, 250), Vector2(140, 285)
			]))
		]
	if rig_type == "flier":
		return [
			_stroke(_oval(256.0, 250.0, 44.0, 30.0)),
			_stroke(PackedVector2Array([Vector2(232, 236), Vector2(190, 196), Vector2(150, 178)])),
			_stroke(PackedVector2Array([Vector2(280, 236), Vector2(322, 196), Vector2(362, 178)]))
		]
	return _quadruped_fixture()


func _oval(cx: float, cy: float, rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(17):
		var angle := TAU * float(index) / 16.0
		points.append(Vector2(cx + cos(angle) * rx, cy + sin(angle) * ry))
	return points


## A body with four legs hanging beneath it: what a player actually draws for a
## four-legged animal, as opposed to limbs radiating in every direction.
func _quadruped_fixture() -> Array:
	var body := PackedVector2Array()
	for index in range(17):
		var angle := TAU * float(index) / 16.0
		body.append(Vector2(256.0 + cos(angle) * 70.0, 240.0 + sin(angle) * 38.0))
	var strokes: Array = [_stroke(body)]
	for offset in [-46.0, -16.0, 16.0, 46.0]:
		var hip := Vector2(256.0 + offset, 274.0)
		strokes.append(_stroke(PackedVector2Array([
			hip, hip + Vector2(0.0, 34.0), hip + Vector2(0.0, 68.0)
		])))
	return strokes


func _test_idle_stability() -> void:
	for entity_id in ["spider", "horse", "monkey"]:
		var instance := registry.instantiate_entity(entity_id) as Node2D
		world.add_child(instance)
		instance.global_position = Vector2(400.0, 360.0)
		instance.call("set_world_bounds", Rect2(0.0, -520.0, 3760.0, 1200.0))
		instance.call("apply_drawing", _blank_image(), _fixture_for(entity_id))
		var anchor := instance.call("get_physics_anchor") as ActiveRigBody2D
		for _settle in range(90):
			await physics_frame
		var start := anchor.global_position
		var start_rotation := anchor.global_rotation
		for _hold in range(180):
			await physics_frame
		var drift := anchor.global_position.distance_to(start)
		var spin := rad_to_deg(absf(wrapf(anchor.global_rotation - start_rotation, -PI, PI)))
		_expect(drift < 40.0, "%s wandered %.1f px with zero input (self-propelling ragdoll)" % [entity_id, drift])
		_expect(spin < 45.0, "%s spun %.1f deg with zero input" % [entity_id, spin])
		instance.queue_free()
		await process_frame


## Messy real-world-style drawings (single scribbles, gapped limbs, multi-stroke bodies,
## jittery input, lone blobs) must still articulate, animate, and stay stable. Fixtures
## live in res://tests/fixtures/ and are also inspectable via res://tests/rig_probe.gd.
func _test_messy_fixtures() -> void:
	var dir := DirAccess.open("res://tests/fixtures")
	if dir == null:
		return
	var names := dir.get_files()
	names.sort()
	for file_name in names:
		if file_name.ends_with(".json"):
			await _check_messy_fixture("res://tests/fixtures/" + file_name)


func _check_messy_fixture(path: String) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		_expect(false, "fixture %s did not parse" % path)
		return
	var label := String(data.get("description", path.get_file()))
	var entity_id := String(data.get("entity_id", "horse"))
	var strokes := _messy_strokes(data.get("strokes", []))
	var states: Array = data.get("states", ["walk"])
	var primary_state := String(states[0]) if not states.is_empty() else "walk"
	var motion := {"moving": true, "speed_ratio": 1.0, "direction": 1.0, "charge_ratio": 1.0}

	var instance := registry.instantiate_entity(entity_id) as Node2D
	_expect(instance != null, "could not instantiate %s for fixture '%s'" % [entity_id, label])
	if instance == null:
		return
	world.add_child(instance)
	instance.global_position = Vector2(300.0, 200.0)
	if instance.has_method("set_world_bounds"):
		instance.call("set_world_bounds", Rect2(0.0, -520.0, 3760.0, 1200.0))
	instance.call("apply_drawing", _blank_image(), strokes)
	var skin := instance.get_node("DrawingSkin") as RuntimeRig2D

	_expect(skin.skin_mode() == "vector", "'%s' collapsed to bitmap" % label)
	# Whether the physics underneath articulated is now genuinely free: a drawing with
	# real limbs gets joints, one continuous shape stays a single body, and inventing
	# joints inside an unbroken line is what tore drawings apart. Neither outcome
	# decides what the player sees any more, so what is asserted is the thing that does
	# -- the drawing is bound to its class's skeleton, and it moves. (The old form of
	# this, "articulated OR animates as a whole body", could not fail once every skinned
	# rig reported the second: it was true by construction.)
	_expect(skin.debug_skin_active(), "'%s' is not skinned to its class skeleton" % label)
	_expect(skin.get_rigid_bodies().size() <= 24 and skin.get_joint_count() <= 23, "'%s' exceeded rig caps" % label)

	instance.set_physics_process(false)
	skin.set_motion_state(primary_state, motion)
	skin._physics_process(0.1)
	if entity_id == "spider":
		_expect(bool(skin.debug_spider_snapshot().get("valid", false)), "'%s' did not produce spider anatomy" % label)
	elif skin.debug_skin_active():
		# However the physics underneath was decomposed -- articulated or one rigid
		# piece -- the drawing itself must move, because that is the only part of this
		# the player can see.
		var travel: float = await _ink_travel(skin, primary_state, motion, 60)
		_expect(travel > 0.5, "'%s' never animated (%.2f px of ink travel)" % [label, travel])
		# Drawn once. These fixtures are where a LIMBLESS drawing lands, and a limbless
		# drawing has its ink moved under a whole-body pivot while the rig is built --
		# so if that copy is not cleared when the skin takes over, the player sees the
		# drawing twice: one frozen underneath, one animating over it. Two lines per
		# stroke is the ink and the halo beneath it.
		var lines := _ink_lines(instance).size()
		var expected := skin.debug_skin_points().size() * 2
		_expect(lines == expected, "'%s' renders %d ink lines, expected %d" % [label, lines, expected])
	else:
		var animated := false
		for torque in skin.debug_drive_torques():
			animated = animated or absf(torque) > 0.01
		_expect(animated, "'%s' did not animate in state %s" % [label, primary_state])

	var maximum_joint_error := 0.0
	for _frame in range(90):
		skin.set_motion_state(primary_state, motion)
		await physics_frame
		maximum_joint_error = maxf(maximum_joint_error, skin.debug_max_joint_error())
	_expect(maximum_joint_error <= 22.5, "'%s' rig unstable (%.2f px)" % [label, maximum_joint_error])
	_expect(skin.debug_recovery_count() <= 1, "'%s' needed repeated recovery" % label)

	instance.queue_free()
	await process_frame


func _messy_strokes(raw: Array) -> Array:
	var strokes: Array = []
	for stroke_value in raw:
		var stroke: Dictionary = stroke_value
		var points := PackedVector2Array()
		for pair in stroke.get("points", []):
			points.append(Vector2(float(pair[0]), float(pair[1])))
		strokes.append({"points": points, "width": float(stroke.get("width", 8.0)), "color": Color.BLACK})
	return strokes


## Everything the rig renders must be the player's ink: on-stroke (no fabricated
## chords slashing across the figure) and length-conserving (no ink silently
## dropped or duplicated). Checked for every living entity's clean fixture and
## every messy fixture — spider included, since its analyzer claims exact slices.
func _test_ink_integrity() -> void:
	var cases: Array = []
	for entity_id in _living_entity_ids():
		cases.append({"label": "clean %s" % entity_id, "entity_id": entity_id, "strokes": _fixture_for(entity_id)})
	var dir := DirAccess.open("res://tests/fixtures")
	if dir != null:
		var names := dir.get_files()
		names.sort()
		for file_name in names:
			if not file_name.ends_with(".json"):
				continue
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/" + file_name))
			if typeof(data) != TYPE_DICTIONARY:
				continue
			var fixture := data as Dictionary
			cases.append({
				"label": String(fixture.get("description", file_name)),
				"entity_id": String(fixture.get("entity_id", "horse")),
				"strokes": _messy_strokes(fixture.get("strokes", []))
			})
	for case_value in cases:
		var case_data := case_value as Dictionary
		var label := String(case_data["label"])
		var instance := registry.instantiate_entity(String(case_data["entity_id"])) as Node2D
		if instance == null:
			_expect(false, "ink integrity could not instantiate %s" % label)
			continue
		world.add_child(instance)
		instance.global_position = Vector2(300.0, 200.0)
		instance.call("apply_drawing", _blank_image(), case_data["strokes"])
		var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
		var strokes := skin.get_vector_strokes()
		var rendered := skin.debug_rendered_ink()
		_expect(not rendered.is_empty(), "'%s' rendered no ink" % label)
		_expect(skin.get_rigid_bodies().size() <= 24 and skin.get_joint_count() <= 23, "'%s' exceeded rig caps" % label)
		_expect(
			skin.get_joint_count() > 0 or skin.get_rigid_bodies().size() == 1,
			"'%s' degraded partially: %d jointless bodies" % [label, skin.get_rigid_bodies().size()]
		)
		var input_length := 0.0
		for stroke_value in strokes:
			input_length += _test_path_length((stroke_value as Dictionary)["points"])
		var core_length := 0.0
		var off_ink := 0
		for entry_value in rendered:
			var entry := entry_value as Dictionary
			var points: PackedVector2Array = entry["points"]
			if points.size() < 2:
				continue
			for index in range(points.size()):
				if not _point_is_on_ink(points[index], strokes):
					off_ink += 1
				if index > 0 and not _point_is_on_ink((points[index - 1] + points[index]) * 0.5, strokes):
					off_ink += 1
			var prefix := int(entry.get("overlap_prefix", 0))
			var suffix := int(entry.get("overlap_suffix", 0))
			var core := points.slice(prefix, points.size() - suffix)
			if core.size() >= 2:
				core_length += _test_path_length(core)
		_expect(off_ink == 0, "'%s' rendered %d points off the drawn ink" % [label, off_ink])
		if input_length > 0.0:
			var ratio := core_length / input_length
			_expect(
				ratio >= 0.92 and ratio <= 1.08,
				"'%s' rendered %.0f%% of the drawn ink length" % [label, ratio * 100.0]
			)
		instance.queue_free()
		await process_frame


func _point_is_on_ink(point: Vector2, strokes: Array) -> bool:
	for stroke_value in strokes:
		var points: PackedVector2Array = (stroke_value as Dictionary)["points"]
		for index in range(points.size() - 1):
			var nearest := Geometry2D.get_closest_point_to_segment(point, points[index], points[index + 1])
			if point.distance_to(nearest) <= 2.0:
				return true
	return false


## Joints must HOLD their gait poses, not just keep their pin anchors together.
## Before the continuous-angle muscles, limbs windmilled in full circles (pin
## error stayed at zero, so no other test saw it): birds could not flap and
## walkers flailed. A disciplined rig keeps every joint's integrated angle within
## its drawn limit plus bounded overshoot.
func _test_limb_angle_discipline() -> void:
	var cases := [
		{"entity_id": "horse", "state": "walk", "limit_deg": 250.0},
		{"entity_id": "bird", "state": "fly", "limit_deg": 250.0},
		{"entity_id": "monkey", "state": "walk", "limit_deg": 250.0},
		{"entity_id": "spider", "state": "walk", "limit_deg": 280.0}
	]
	for case_value in cases:
		var case_data := case_value as Dictionary
		var entity_id := String(case_data["entity_id"])
		var instance := registry.instantiate_entity(entity_id) as Node2D
		if instance == null:
			_expect(false, "angle discipline could not instantiate %s" % entity_id)
			continue
		world.add_child(instance)
		instance.global_position = Vector2(300.0, 200.0)
		instance.call("apply_drawing", _blank_image(), _fixture_for(entity_id))
		var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
		instance.set_physics_process(false)
		var params := {"moving": true, "speed_ratio": 1.0, "direction": 1.0}
		for _frame in range(120):
			skin.set_motion_state(String(case_data["state"]), params)
			await physics_frame
		var max_angle := rad_to_deg(skin.debug_max_tracked_angle())
		_expect(
			max_angle <= float(case_data["limit_deg"]),
			"%s joints windmilled to %.0f deg (limit %.0f)" % [entity_id, max_angle, float(case_data["limit_deg"])]
		)
		instance.queue_free()
		await process_frame


## A stick figure must rig as spine-torso with articulated arms and legs. Two
## regressions guarded here: the closed head circle out-scoring the spine as the
## torso (its stroke seam hid it from the hub test), and arms drawn as one stroke
## crossing the spine being welded rigid instead of split into two limbs.
func _test_stick_figure_anatomy() -> void:
	var instance := registry.instantiate_entity("monkey") as Node2D
	_expect(instance != null, "could not instantiate monkey for stick figure check")
	if instance == null:
		return
	world.add_child(instance)
	instance.global_position = Vector2(300.0, 200.0)
	instance.call("apply_drawing", _blank_image(), _stick_figure_fixture())
	var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
	_expect(skin.get_joint_count() >= 6, "stick figure articulated only %d joints" % skin.get_joint_count())
	var roles := skin.debug_segment_roles()
	_expect(roles.count("arm") >= 2, "stick figure arms did not split into limbs (roles: %s)" % str(roles))
	_expect(roles.count("leg") >= 2, "stick figure legs missing (roles: %s)" % str(roles))
	instance.queue_free()
	await process_frame


func _stick_figure_fixture() -> Array:
	var strokes: Array = []
	var head := PackedVector2Array()
	for index in range(19):
		var angle := TAU * float(index) / 18.0
		head.append(Vector2(256.0 + cos(angle) * 30.0, 150.0 + sin(angle) * 30.0))
	strokes.append(_stroke(head))
	strokes.append(_stroke(_dense_line(Vector2(256.0, 180.0), Vector2(256.0, 300.0))))
	strokes.append(_stroke(_dense_line(Vector2(180.0, 230.0), Vector2(332.0, 230.0))))
	strokes.append(_stroke(_dense_line(Vector2(256.0, 300.0), Vector2(208.0, 404.0))))
	strokes.append(_stroke(_dense_line(Vector2(256.0, 300.0), Vector2(304.0, 404.0))))
	return strokes


func _dense_line(from: Vector2, to: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := maxi(2, int(from.distance_to(to) / 6.0))
	for index in range(count + 1):
		points.append(from.lerp(to, float(index) / float(count)))
	return points


## A limb stroke whose midpoint merely grazes the torso must stay one limb; the
## old interior split cut it into two half-limbs that tore the drawing apart.
func _test_grazing_stroke_not_split() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/grazing_limb.json"))
	if typeof(data) != TYPE_DICTIONARY:
		_expect(false, "grazing_limb fixture did not parse")
		return
	var strokes := _messy_strokes((data as Dictionary).get("strokes", []))
	var instance := registry.instantiate_entity("horse") as Node2D
	_expect(instance != null, "could not instantiate horse for grazing check")
	if instance == null:
		return
	world.add_child(instance)
	instance.global_position = Vector2(300.0, 200.0)
	instance.call("apply_drawing", _blank_image(), strokes)
	var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
	# The grazing stroke is the fixture's last stroke; normalization keeps order.
	var normalized := skin.get_vector_strokes()
	var graze: Dictionary = normalized[normalized.size() - 1]
	var radius := clampf(skin.get_stroke_bounds().size.length() * 0.14, 12.0, 40.0)
	var paths: Array = skin._paths_attached_to_body(graze["points"], radius)
	_expect(paths.size() <= 1, "grazing stroke split into %d limb paths" % paths.size())
	instance.queue_free()
	await process_frame


func _test_utilities() -> void:
	for entity_id in ["axe", "ladder", "key", "umbrella", "flashlight", "sailboat"]:
		var item := DrawnItemData.from_prediction(entity_id, entity_id.capitalize(), _blank_image(), _utility_fixture(entity_id), 0.5, registry.get_entity(entity_id))
		var utility := registry.instantiate_entity(entity_id) as UtilityObject
		_expect(utility != null, "could not instantiate utility %s" % entity_id)
		if utility == null:
			continue
		world.add_child(utility)
		utility.global_position = Vector2(600.0, 180.0)
		utility.apply_item_data(item)
		_expect(not utility.controllable, "%s retained player controls" % entity_id)
		_expect(utility.utility_behavior == entity_id, "%s behavior metadata missing" % entity_id)
		_expect(utility.find_children("*", "CollisionShape2D", true, false).size() > 0, "%s has no vector collision" % entity_id)
		if entity_id == "axe":
			var target: Node2D = load("res://scripts/destructible_2d.gd").new()
			target.set("health", 50.0)
			target.global_position = utility.global_position
			world.add_child(target)
			_add_target_body(target)
			await physics_frame
			utility.use_utility(utility)
			_expect(bool(target.get("is_destroyed")), "axe utility did not invoke destructible contract")
			target.queue_free()
		if entity_id == "key":
			var target: Node2D = load("res://scripts/lockable_2d.gd").new()
			target.global_position = utility.global_position
			world.add_child(target)
			_add_target_body(target)
			await physics_frame
			utility.use_utility(utility)
			_expect(not bool(target.get("is_locked")), "key utility did not invoke lock contract")
			target.queue_free()
		if entity_id in ["umbrella", "flashlight"]:
			_expect(utility.use_utility(utility), "%s could not toggle" % entity_id)
			_expect(bool(utility.serialize_utility_state().get("active", false)), "%s state did not persist" % entity_id)
		if entity_id == "sailboat":
			utility.set_meta("water_overlap_count", 1)
			utility.sleeping = false
			for _water_frame in range(3):
				await physics_frame
			_expect(bool(utility.call("_is_in_water")), "sailboat did not detect water medium")
			_expect(utility.gravity_scale < 0.5, "sailboat did not switch to buoyancy physics")
		utility.queue_free()
		await process_frame


func _test_compound_fallback_recovery() -> void:
	var instance := registry.instantiate_entity("spider") as Node2D
	world.add_child(instance)
	instance.global_position = Vector2(320.0, 160.0)
	instance.call("set_world_bounds", Rect2(0.0, -520.0, 3760.0, 1200.0))
	instance.call("apply_drawing", _blank_image(), [])
	var anchor := instance.call("get_physics_anchor") as ActiveRigBody2D
	var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
	_expect(anchor != null and skin.get_joint_count() == 0, "bitmap fallback did not build one compound body")
	if anchor != null:
		anchor.global_position = Vector2(9000.0, 9000.0)
		for _frame in range(8):
			await physics_frame
		_expect(Rect2(0.0, -520.0, 3760.0, 1200.0).has_point(anchor.global_position), "compound fallback escaped without recovery")
	instance.queue_free()
	await process_frame


func _test_physics_morphs() -> void:
	for entity_id in ["circle", "square", "triangle"]:
		var instance := registry.instantiate_entity(entity_id) as PhysicsShapeObject
		_expect(instance != null, "could not instantiate physics morph %s" % entity_id)
		if instance == null:
			continue
		world.add_child(instance)
		instance.global_position = Vector2(450.0, 120.0)
		instance.apply_drawing(_blank_image(), [_stroke(_closed_body())])
		_expect(instance.controllable, "%s is no longer controllable" % entity_id)
		_expect(instance.get_physics_anchor() == instance, "%s physics anchor is incorrect" % entity_id)
		_expect(instance.find_children("*", "CollisionShape2D", true, false).size() > 0, "%s has no drawing collision" % entity_id)
		var state := instance.capture_morph_state()
		instance.apply_morph_state(state)
		await physics_frame
		_expect(is_finite(instance.global_position.x), "%s physics became non-finite" % entity_id)
		instance.queue_free()
		await process_frame


func _living_entity_ids() -> Array:
	var ids: Array = []
	for entity_id in registry.get_entity_ids():
		if String(registry.get_entity(entity_id).get("runtime_role", "")) == "active_ragdoll_morph":
			ids.append(entity_id)
	return ids


func _expected_roles_for_rig(rig_type: String) -> Array:
	match rig_type:
		"flier":
			return ["wing"]
		"swimmer":
			return ["tail", "fin", "chain"]
		"walker", "biped", "hopper":
			return ["leg"]
		_:
			return []


func _gait_for_rig(rig_type: String) -> String:
	match rig_type:
		"flier":
			return "fly"
		"swimmer":
			return "swim"
		"hopper":
			return "jump"
		_:
			return "walk"


## Per-archetype coverage: every enabled entity must spawn, rig, and step physics
## without erroring, keep its ink intact, stay in bounds, and not windmill. Results
## are grouped by rig_type archetype, matching the thesis's per-archetype plan.
func _test_archetype_coverage() -> void:
	var groups: Dictionary = {}
	var order: Array = []
	for entity_id in registry.get_entity_ids():
		var entry := registry.get_entity(entity_id)
		var rig_type := String(entry.get("rig_type", "none"))
		if not groups.has(rig_type):
			groups[rig_type] = {"pass": 0, "fail": 0}
			order.append(rig_type)
		var before := failures.size()
		await _cover_entity(entity_id, entry, rig_type)
		if failures.size() == before:
			groups[rig_type]["pass"] += 1
		else:
			groups[rig_type]["fail"] += 1
	order.sort()
	print("--- Per-archetype coverage summary (rig_type) ---")
	for rig_type in order:
		var g: Dictionary = groups[rig_type]
		print("  %-8s : %d passed, %d failed" % [rig_type, int(g["pass"]), int(g["fail"])])


func _cover_entity(entity_id: String, entry: Dictionary, rig_type: String) -> void:
	var is_creature := String(entry.get("runtime_role", "")) == "active_ragdoll_morph"
	var fixture: Array = _fixture_for(entity_id) if is_creature else _utility_fixture(entity_id)
	var instance := registry.instantiate_entity(entity_id) as Node2D
	_expect(instance != null, "coverage: could not instantiate %s" % entity_id)
	if instance == null:
		return
	world.add_child(instance)
	instance.global_position = Vector2(400.0, 200.0)
	if instance.has_method("set_world_bounds"):
		instance.call("set_world_bounds", Rect2(0.0, -520.0, 3760.0, 1200.0))
	instance.call("apply_drawing", _blank_image(), fixture)
	var anchor := instance.call("get_physics_anchor") as RigidBody2D
	var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
	_expect(anchor != null and skin != null, "coverage: %s missing anchor/skin" % entity_id)
	if anchor == null or skin == null:
		instance.queue_free()
		await process_frame
		return
	_expect(skin.get_rigid_bodies().size() <= 24 and skin.get_joint_count() <= 23, "coverage: %s exceeded rig caps" % entity_id)
	if skin.skin_mode() == "vector":
		_expect(bool(skin.call("_rig_ink_is_intact")), "coverage: %s violated the ink-integrity audit" % entity_id)
	if is_creature and entity_id != "spider":
		_expect(skin.get_joint_count() > 0 or skin.skin_mode() != "vector", "coverage: %s did not articulate" % entity_id)
	instance.set_physics_process(false)
	var motion := {"moving": true, "speed_ratio": 1.0, "direction": 1.0, "charge_ratio": 1.0}
	var gait := _gait_for_rig(rig_type)
	for _frame in range(90):
		if is_creature:
			skin.set_motion_state(gait, motion)
		await physics_frame
	for rig_body in skin.get_rigid_bodies():
		_expect(is_finite(rig_body.global_position.x) and is_finite(rig_body.global_position.y), "coverage: %s segment became non-finite" % entity_id)
	_expect(is_finite(anchor.global_position.x) and is_finite(anchor.global_position.y), "coverage: %s anchor became non-finite" % entity_id)
	_expect(Rect2(-180.0, -700.0, 4120.0, 1560.0).has_point(anchor.global_position), "coverage: %s escaped the playable world" % entity_id)
	if is_creature:
		var max_angle := rad_to_deg(skin.debug_max_tracked_angle())
		_expect(max_angle <= 360.0, "coverage: %s joints windmilled to %.0f deg" % [entity_id, max_angle])
	instance.queue_free()
	await process_frame


func _fixture_for(entity_id: String) -> Array:
	if entity_id == "snake":
		var wave := PackedVector2Array()
		for index in range(18):
			wave.append(Vector2(90.0 + index * 19.0, 256.0 + sin(float(index) * 0.75) * 28.0))
		return [_stroke(wave)]
	if entity_id == "spider":
		return SpiderReferenceFixtures.separate_legs()
	var strokes: Array = [_stroke(_closed_body())]
	var limb_count := 4
	if entity_id == "fish":
		limb_count = 2
	for index in range(limb_count):
		var angle := TAU * float(index) / float(limb_count)
		var start := Vector2(256.0, 256.0) + Vector2(cos(angle) * 58.0, sin(angle) * 38.0)
		var mid := start + Vector2(cos(angle) * 42.0, sin(angle) * 42.0)
		var tip := mid + Vector2(cos(angle) * 34.0, sin(angle) * 34.0)
		strokes.append(_stroke(PackedVector2Array([start, mid, tip])))
	return strokes


func _utility_fixture(entity_id: String) -> Array:
	if entity_id == "ladder":
		return [
			_stroke(PackedVector2Array([Vector2(210, 100), Vector2(210, 410)])),
			_stroke(PackedVector2Array([Vector2(302, 100), Vector2(302, 410)])),
			_stroke(PackedVector2Array([Vector2(210, 180), Vector2(302, 180)])),
			_stroke(PackedVector2Array([Vector2(210, 260), Vector2(302, 260)])),
			_stroke(PackedVector2Array([Vector2(210, 340), Vector2(302, 340)]))
		]
	return [_stroke(PackedVector2Array([Vector2(130, 256), Vector2(382, 256)]))]


func _closed_body() -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(17):
		var angle := TAU * float(index) / 16.0
		points.append(Vector2(256.0 + cos(angle) * 62.0, 256.0 + sin(angle) * 42.0))
	return points


func _stroke(points: PackedVector2Array) -> Dictionary:
	return {"points": points, "width": 8.0, "color": Color.BLACK}


func _test_path_length(points: PackedVector2Array) -> float:
	var length := 0.0
	for index in range(1, points.size()):
		length += points[index - 1].distance_to(points[index])
	return length


func _blank_image() -> Image:
	var image := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return image


func _add_floor() -> void:
	var floor := StaticBody2D.new()
	floor.position = Vector2(500.0, 420.0)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1000.0, 40.0)
	collision.shape = shape
	floor.add_child(collision)
	world.add_child(floor)


func _add_spider_test_wall() -> StaticBody2D:
	var wall := StaticBody2D.new()
	# Keep the wall reachable within the fixed smoke-test window now that grounded
	# translation comes from traction-limited stance legs instead of free torso thrust.
	wall.position = Vector2(500.0, 250.0)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(30.0, 300.0)
	collision.shape = shape
	wall.add_child(collision)
	world.add_child(wall)
	return wall


func _contacting_spider_feet(summary: Dictionary) -> int:
	var count := 0
	var feet_value: Variant = summary.get("feet", [])
	if feet_value is Array:
		for foot_value in feet_value as Array:
			if foot_value is Dictionary and bool((foot_value as Dictionary).get("contact", false)):
				count += 1
	return count


func _spider_contact_sides(summary: Dictionary) -> Dictionary:
	var result := {-1: false, 1: false}
	var feet_value: Variant = summary.get("feet", [])
	if feet_value is Array:
		for foot_value in feet_value as Array:
			if not (foot_value is Dictionary):
				continue
			var foot: Dictionary = foot_value
			if bool(foot.get("contact", false)):
				var side := int(foot.get("side", 0))
				if side in [-1, 1]:
					result[side] = true
	return result


func _add_target_body(parent: Node2D) -> void:
	var body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28.0, 28.0)
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
