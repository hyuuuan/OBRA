extends SceneTree
## Every popup in the game, one screenshot each. Needs a real viewport:
##   godot --path game --script res://tests/run_visual_popups.gd
## Frames land in /tmp/obra_pop_*.png
##
## They were each pinned to a hand-picked rect far larger than their content, so the text
## sat marooned in an empty slab. That is not visible from any headless assertion -- the
## labels say the right words at the right size either way.

const PROFILE_PATH := "user://profile.json"

var level: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://game_level.tscn") as PackedScene
	level = scene.instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	await _wait(1.2)

	var d = level.get("director")
	var player := level.get("player") as Node2D
	player.global_position = Vector2(700.0, 440.0)
	await _wait(0.6)
	await _capture("00_lolo_short")

	# A long line, to prove the bubble grows rather than cramming.
	level.get("lolo").say("Four hundred. Maybe less. They built this while the Spanish were burning the lowlands. This was not left behind, apo. This is an answer.")
	await _wait(0.6)
	await _capture("01_lolo_long")

	level.call("_on_dialogue_node_approached")
	await _wait(0.8)
	await _capture("02_dialogue_choice")
	level.get_node("DialogueChoiceOverlay").call("close")
	await _wait(0.5)

	level.get_node("MemoryOverlay").call("present", "A memory", [
		"She is younger here, and the light is the same gold it is now.",
		"Lola is painting this crossing — the ropes first, then the planks, one at a time.",
		"She looks up from the canvas, straight out of it, and smiles.",
	])
	await _wait(0.8)
	await _capture("03_memory")
	level.get_node("MemoryOverlay").call("close")
	await _wait(0.5)

	level.get_node("OutOfInkOverlay").call("open")
	await _wait(0.8)
	await _capture("04_out_of_ink")
	level.get_node("OutOfInkOverlay").call("close")
	await _wait(0.5)

	level.get_node("LevelCompleteOverlay").call("present", level.call("run_stats"))
	await _wait(0.8)
	await _capture("05_level_complete")
	level.get_node("LevelCompleteOverlay").call("close")
	await _wait(0.5)

	level.get_node("PauseMenu").call("open")
	await _wait(0.8)
	await _capture("06_pause")

	# The two the pause menu opens. Pressed as real buttons -- an earlier version called a
	# handler by name behind a has_method() guard, and when the name was wrong the guard
	# silently did nothing and the screenshot was just the pause menu again.
	var pause := level.get_node("PauseMenu")
	pause.get("settings_button").emit_signal("pressed")
	await _wait(1.0)
	await _capture("07_settings")
	var settings := level.get_node_or_null("SettingsOverlay")
	if settings != null:
		settings.call("close")
	await _wait(0.6)
	pause.get("controls_button").emit_signal("pressed")
	await _wait(1.0)
	await _capture("08_controls")

	var controls := level.get_node_or_null("ControlsOverlay")
	if controls != null:
		controls.call("close")
	pause.call("close")
	await _wait(0.6)

	# THE BAG. Filled first, because an empty inventory screen is a picture of six frames
	# and says nothing about whether the thing works.
	var bag := level.get("inventory_manager") as InventoryManager
	var registry := level.get_node("EntityRegistry") as EntityRegistry
	for id in ["axe", "ladder", "key"]:
		var entry := registry.get_entity(id)
		var item := DrawnItemData.from_prediction(id, String(entry.get("display_name", id)),
			_scribble(), [], 1.0, entry)
		bag.add_item(item)
	# ⚠ AND PUT THE PROFILE BACK. The bag screen reads PlayerProfile, so a picture of it worth
	# looking at needs one with things in it -- and PlayerProfile is a real file at
	# user://profile.json that survives between runs. A screenshot fixture that grants the
	# brush and marks seven classes drawn would quietly hand the player progress they had not
	# earned, in a save nothing tells them was touched. Same trap LEVEL_1.md logs as #4:
	# measure deltas, never write, against anything persistent.
	var saved := FileAccess.get_file_as_string(PROFILE_PATH)
	var profile = level.get_node_or_null(^"/root/PlayerProfile")
	if profile != null:
		profile.call("record_brush_acquired")
		profile.call("record_collectible", "L1_bale_key")
		for id in ["axe", "ladder", "key", "circle", "square", "frog", "spider"]:
			profile.call("record_class_drawn", id)
	level.call("_toggle_inventory_screen")
	await _wait(1.0)
	await _capture("09_inventory")
	# And with something chosen, because the detail pane and the USE button are half of what
	# this screen is for and an empty one is a picture of frames.
	level.get_node("InventoryScreen").call("_choose_bag", 0)
	await _wait(0.4)
	await _capture("09b_inventory_chosen")
	level.get_node("InventoryScreen").call("close")
	await _wait(0.5)

	# THE ACQUISITION CARD, caught at full size rather than mid-fade.
	level.call("announce_acquisition", "The Brass Key",
		"Too small for the chest. It belongs to a door you have only seen painted.",
		UIIcons.key())
	await _wait(0.6)
	await _capture("10_acquired")
	await _wait(2.0)

	_restore_profile(saved)
	print("OBRA_VISUAL_POPUPS_DONE")
	quit(0)


## The save exactly as it was before this fixture ran. An empty string means there was no
## profile to begin with, in which case the one this made is deleted rather than left behind.
func _restore_profile(saved: String) -> void:
	if saved.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
		return
	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("could not put the profile back; it now carries this fixture's writes")
		return
	file.store_string(saved)
	file.close()
	var profile := root.get_node_or_null(^"/root/PlayerProfile")
	if profile != null:
		profile.call("load_profile")


## A drawing to put in a slot: a few strokes on white paper, which is what the drawing panel
## actually hands the bag.
func _scribble() -> Image:
	var image := Image.create_empty(400, 400, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	for step in range(200):
		var t := float(step) / 199.0
		var x := int(90.0 + t * 220.0)
		var y := int(300.0 - sin(t * PI) * 190.0)
		for dx in range(-5, 6):
			for dy in range(-5, 6):
				var px := clampi(x + dx, 0, 399)
				var py := clampi(y + dy, 0, 399)
				image.set_pixel(px, py, Color.BLACK)
	return image

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/obra_pop_%s.png" % label)

func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout
