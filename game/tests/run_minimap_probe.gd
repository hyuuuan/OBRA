extends SceneTree
## All five real levels: minimap layout, exploration, interiors, morphs and camera isolation.
## Run without --headless to also verify pixels and save /tmp/obra_minimap_level_*.png.

const FIXTURES = preload("res://tests/roster_fixtures.gd")
const LEVELS := ["res://game_level.tscn", "res://level_2.tscn", "res://level_3.tscn",
	"res://level_4.tscn", "res://level_5.tscn"]
var failures := 0
var _aborting := false


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["OK" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _run() -> void:
	create_timer(90.0, true).timeout.connect(func() -> void: quit(2))
	await process_frame
	var profile := root.get_node("PlayerProfile")
	profile.set("_data", profile.call("_default_profile"))
	profile.call("record_brush_acquired")
	for index in range(LEVELS.size()):
		await _audit(LEVELS[index], index + 1)
		if _aborting:
			return
	await _notice()
	print("OBRA_MINIMAP_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(0 if failures == 0 else 1)


func _audit(path: String, number: int) -> void:
	root.get_node("LevelManager").set("current_level_id", "level_%d" % number)
	var level := (load(path) as PackedScene).instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await create_timer(0.7, true).timeout
	level.get("dialogue_box").call("hide_line")
	level.call("_on_backend_ready")
	var map := level.get("minimap") as LevelMinimap
	var brush := level.get("hud_panel") as HudPanel
	_check(map != null, "level %d has a minimap" % number)
	if map == null:
		level.queue_free()
		await process_frame
		return
	map.refresh()
	await process_frame
	var rect := map.get_global_rect()
	var view := root.get_visible_rect()
	_check(is_equal_approx(rect.size.x, rect.size.y) and rect.size.x >= 200.0
		and absf(rect.position.x - 24.0) < 1.0 and absf(rect.position.y - 20.0) < 1.0,
		"level %d: square at the top left" % number)
	var ink := brush.get_global_rect()
	_check(ink.position.y >= rect.end.y + 10.0 and absf(ink.position.x - rect.position.x) < 1.0
		and is_equal_approx(ink.size.x, rect.size.x) and view.encloses(ink),
		"level %d: brush matches map width, aligned below and on screen" % number)
	_check(not brush.is_ancestor_of(level.get("status_label"))
		and String(level.get("status_label").text).is_empty(),
		"level %d: no description on the brush or idle ready text" % number)
	var anchor: Vector2 = level.call("_player_anchor_position")
	_check(map.world_rect().get_center().distance_to(anchor) < 2.0 and map.is_explored(anchor)
		and not map.is_explored(anchor + Vector2(2000.0, 0.0)),
		"level %d: follows player and hides unexplored terrain" % number)
	var camera := level.call("_world_camera") as Camera2D
	var transform := root.canvas_transform
	var zoom := camera.zoom
	map.refresh()
	_check(root.canvas_transform == transform and camera.zoom == zoom
		and root.get_camera_2d() == camera, "level %d: map leaves gameplay camera alone" % number)
	if number == 1:
		await _travel_and_morph(level, map, anchor)
	if DisplayServer.get_name() != "headless":
		var until := Time.get_ticks_msec() + 6000
		while Time.get_ticks_msec() < until and level.get("cinematic").call("is_playing"):
			await create_timer(0.1, true).timeout
		var acquired: Object = level.get("acquired_overlay")
		for _card in range(8):
			if not acquired.call("is_busy"):
				break
			acquired.call("_dismiss")
			await create_timer(0.4, true).timeout
		level.get("tutorial_spotlight").call("close")
		level.get("dialogue_box").call("hide_line")
		level.get("status_label").text = ""
		await create_timer(0.3, true).timeout
		# Dismissing a pickup can release an opening performance that was waiting behind it.
		until = Time.get_ticks_msec() + 12000
		while Time.get_ticks_msec() < until and (level.get("cinematic").call("is_playing")
				or map.modulate.a <= 0.9):
			await create_timer(0.1, true).timeout
		var ready := not bool(acquired.call("is_busy")) and map.is_visible_in_tree() and map.modulate.a > 0.9
		_check(ready,
			"level %d: visual fixture shows the map without a blocking card" % number)
		if not ready:
			_aborting = true
			quit(1)
			return
		await RenderingServer.frame_post_draw
		var pixels := (map.get_node("MapView") as SubViewport).get_texture().get_image()
		var colours: Dictionary = {}
		for y in range(0, pixels.get_height(), 4):
			for x in range(0, pixels.get_width(), 4):
				colours[pixels.get_pixel(x, y).to_rgba32()] = true
		_check(colours.size() > 12, "level %d: map renders actual world pixels" % number)
		root.get_texture().get_image().save_png("/tmp/obra_minimap_level_%d.png" % number)
	level.queue_free()
	await process_frame
	await process_frame


func _travel_and_morph(level: Node2D, map: LevelMinimap, origin: Vector2) -> void:
	var player := level.get("player") as Node2D
	player.global_position += Vector2(2100.0, -100.0)
	map.refresh()
	_check(map.is_explored(origin) and map.is_explored(player.global_position)
		and map.world_rect().get_center().distance_to(player.global_position) < 2.0,
		"travelling reveals new terrain and remembers the old area")
	# The heap exercises room framing without taking the painting that ends Payyo.
	var room := get_first_node_in_group(&"straw_rooms") as Node2D
	_check(room != null, "interior fixture exists")
	if room == null:
		return
	player.global_position = Vector2(room.call("entry_point"))
	level.call("_refresh_room_framing", true)
	map.refresh()
	_check(map.world_rect().get_center().distance_to(player.global_position) < 2.0
		and map.world_rect().size.x < LevelMinimap.WORLD_SPAN,
		"entering a room moves and scales the minimap")
	var image := Image.create(400, 400, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var made := bool(level.call("_spawn_or_replace", "frog", "Frog", image,
		FIXTURES.for_rig("hopper")))
	_check(made, "morph fixture builds")
	await create_timer(0.15, true).timeout
	map.refresh()
	var anchor: Vector2 = level.call("_player_anchor_position")
	_check(made and map.world_rect().get_center().distance_to(anchor) < 2.0,
		"minimap follows the active morph's physics anchor")
	var card := level.get("morph_card") as Control
	_check(card.is_visible_in_tree() and card.get_global_rect().position.x > map.get_global_rect().end.x,
		"morph card stays clear of the minimap")
	level.call("_revert_to_base_form")
	player = level.get("player") as Node2D
	player.global_position = origin
	level.call("_refresh_room_framing", true)
	map.refresh()
	_check(map.is_explored(origin) and map.world_rect().size.x == LevelMinimap.WORLD_SPAN,
		"returning outside restores map scale and exploration")


func _notice() -> void:
	# An isolated notice: live levels can write checkpoints or placement feedback over it.
	var label := Label.new()
	root.add_child(label)
	var notice := HudNotice.new()
	root.add_child(notice)
	notice.adopt(label)
	label.text = "Inventory full"
	await process_frame
	await process_frame
	_check(notice.visible, "action errors still appear outside the brush")
	await create_timer(HudNotice.HOLD_SECONDS + 0.2, true).timeout
	_check(not notice.visible and label.text.is_empty(), "feedback clears after its brief display")
	label.text = "Inventory full"
	await process_frame
	await process_frame
	_check(notice.visible, "the same error can be shown again")
	notice.queue_free()
	await process_frame
