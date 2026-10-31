extends Node2D
## The start of the game: Lolo and Lola's house, with the five paintings on the wall.
##
## WHAT THIS REPLACES. Choosing a level was a grid of cards on the main menu. It is a room
## now -- you walk in as the apo, walk along the wall, and the level you pick is the picture
## you stand in front of. The cards said the same five things; standing in the house says
## why they are the same five things, which is that Lola painted all of them.
##
## Painting availability follows the level catalog and progression flag, including DevMode.
##
## The room builds itself here rather than being authored as a scene tree, because every
## number in it is derived from one thing: how far apart five paintings want to be. The
## bays in the wall, the wainscot panels and the width of the room all follow from that, so
## a scene file would be five copies of an arithmetic that belongs in one place.

const HubRoomScript = preload("res://scripts/hub_room.gd")
const PaintingScript = preload("res://scripts/painting_2d.gd")
const BrushStandScript = preload("res://scripts/brush_stand_2d.gd")
const BrushSheet: Texture2D = preload("res://assets/hud/brush_full.png")
const WandererScene = preload("res://creatures/wanderer.tscn")

## The five, in the order they hang. The title comes out of the catalog; this only says
## which painting goes where and what the plate reads.
const WALL: Array[Dictionary] = [
	{"id": "level_1", "plate": "PAYYO"},
	{"id": "level_2", "plate": "PIYESTA"},
	{"id": "level_3", "plate": "DAGAT"},
	{"id": "level_4", "plate": "DILIM"},
	{"id": "level_5", "plate": "MAYON"},
]

## Where the apo comes in: in front of the first painting rather than at the end of the
## wall, so the first thing on screen is a picture and not an empty corner.
const SPAWN_X := 300.0
## Where the brush stands: past the last doorway, in the end bay HubRoom leaves for it.
##
## FAR ENOUGH RIGHT TO BE A WALK, close enough that the camera can still very nearly centre
## on it -- _eye_on stops the view at room_width less half a screen, which is 1700 here, so
## a stand any deeper into the bay would be looked at from the corner of the frame. At 1800
## it sits where the fifth painting sits: a hundred past the clamp, with the end wall
## filling the frame behind it.
const BRUSH_STAND_X := 1800.0
## How far in the camera sits.
##
## TWO IS WHAT MAKES THE ROOM A ROOM. The house is built to the apo at seventy-two pixels
## to the metre, so one screen at this zoom is eleven metres of wall by six and a quarter
## of air -- which is a room you are standing in rather than a hall seen from the far end.
## He comes out a fifth of the screen tall, where at 1.25 he was an eighth of it.
##
## It is also the number the ROOM IS DRAWN TO FILL. Any less and the ceiling runs out before
## the top of the frame does and the view opens onto grey nothing, which is what the top
## of every screenshot of this room used to show. run_hub_audit asserts it, because it
## costs nothing there and it is invisible everywhere else.
const ZOOM := 2.0
## Where the eye rests: between the pictures and the floor, not on the apo's head. It is the
## middle of the drawn room, so what runs off the top and what runs off the bottom are the
## same nine pixels rather than all of the slack going one way.
const EYE_Y := 234.0

var _room: Node2D
var _player: Node2D
var _camera: Camera2D
var _prompt: Label
var _status: Label
var _near: Node2D
var _stand: Node2D
var _paintings: Array[Node2D] = []
var _carried: Control
## What the prompt is currently saying. NONE until the first target comes into reach.
enum Wear { NONE, TAKE, VIEW, REFUSE, LOCKED, UNFINISHED }
## The card that says a thing is yours now. See AcquiredOverlay.
var _acquired: AcquiredOverlay
var _wearing: Wear = Wear.NONE
## Where the camera looks instead of at the apo, while the house is showing her something.
var _look_at := NAN
var _revealing := false
var _last_hall_x := SPAWN_X


func _ready() -> void:
	_room = HubRoomScript.new()
	_room.name = "Room"
	add_child(_room)

	# The house says "this is yours now" the same way a level does. One overlay, built here
	# because the hub is its own scene and does not go through GameLevel.
	_acquired = AcquiredOverlay.new()
	_acquired.name = "AcquiredOverlay"
	add_child(_acquired)

	# THE DRAWN FLOOR IS A PICTURE OF A FLOOR. HubRoom paints the boards; nothing in it
	# collides, so without this the apo walks in and falls straight through the house.
	var ground := StaticBody2D.new()
	ground.name = "Ground"
	var ground_shape := CollisionShape2D.new()
	var slab := RectangleShape2D.new()
	slab.size = Vector2(float(_room.get("room_width")) + 400.0, 200.0)
	ground_shape.shape = slab
	ground_shape.position = Vector2(float(_room.get("room_width")) * 0.5,
		float(_room.call("ground_y")) + 100.0)
	ground.add_child(ground_shape)
	add_child(ground)

	for index in range(WALL.size()):
		_hang(index, WALL[index])

	# THE ONE THING IN THIS HOUSE THAT IS NOT A PICTURE. It goes in before the apo so it is
	# already standing there on the first frame, the same as the paintings are.
	_stand = BrushStandScript.new()
	_stand.name = "BrushStand"
	_stand.position = Vector2(BRUSH_STAND_X, _room.call("ground_y"))
	add_child(_stand)
	_stand.connect(&"taken", _on_brush_taken)

	_player = WandererScene.instantiate()
	_player.name = "Apo"
	add_child(_player)
	var profile := get_node_or_null(^"/root/PlayerProfile")
	var manager := get_node_or_null(^"/root/LevelManager")
	var fallback_x := SPAWN_X
	if manager != null:
		var returning := painting_for_level(String(manager.get("returning_level_id")))
		if returning != null:
			fallback_x = returning.position.x
	_last_hall_x = float(profile.call("hall_position_x", fallback_x)) if profile != null else fallback_x
	_last_hall_x = clampf(_last_hall_x, 40.0, float(_room.get("room_width")) - 40.0)
	_player.global_position = Vector2(_last_hall_x, _room.call("ground_y"))
	for painting in _paintings:
		painting.call("set_player_aligned", bool(painting.call("within_reach", _player.position)), false)
	# Kept indoors. The wanderer clamps itself to whatever bounds it is given, which is the
	# only thing stopping a walk off the end of the wall into nothing.
	if _player.has_method("set_world_bounds"):
		_player.call("set_world_bounds", Rect2(
			40.0, -400.0, float(_room.get("room_width")) - 80.0, 1200.0))

	_camera = Camera2D.new()
	_camera.name = "Camera"
	# CLOSER THAN THE LEVELS, because a room is closer than a valley. The levels get away
	# with a wide view because there is terrain and sky doing the work; here the subject is
	# a person and five pictures, so the camera comes in until the room fills the frame.
	# Fitted to the screen as the levels' cameras are: a taller screen sees the same room, as
	# tall as it was painted, rather than the floor below it. See WorldCameraController.
	_camera.zoom = Vector2.ONE * ZOOM * WorldCameraController.screen_fit(get_viewport())
	get_viewport().size_changed.connect(func() -> void:
		_camera.zoom = Vector2.ONE * ZOOM * WorldCameraController.screen_fit(get_viewport()))
	# Vertically pinned. The room is one storey and the floor never moves, so a camera that
	# follows the apo up and down would sway the whole wall every time they jumped.
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 6.0
	add_child(_camera)
	_camera.make_current()
	# STANDING WHERE IT BELONGS BEFORE THE FIRST FRAME. Smoothing starts a camera wherever
	# the node happens to be, which is the origin, and it then slides into place over about
	# half a second -- so the game opened on the corner of the ceiling and a band of grey
	# void down the left of the screen, and slid off it. That is the first thing a player
	# ever sees of this house.
	_camera.global_position = _eye_on(_player.global_position.x)
	_camera.reset_smoothing()

	_build_hud()
	set_process(true)
	var opened := String(manager.call("take_pending_reveal")) \
		if manager != null and manager.has_method("take_pending_reveal") else ""
	if not opened.is_empty():
		_revealing = true
		_player.set_physics_process(false)
		_open_in_front_of_her.call_deferred(opened)


func _exit_tree() -> void:
	remember_position()


func remember_position() -> void:
	if is_instance_valid(_player):
		_last_hall_x = _player.position.x
	var profile := get_node_or_null(^"/root/PlayerProfile")
	if profile != null:
		profile.call("remember_hall_position", _last_hall_x)


func painting_for_level(level_id: String) -> Node2D:
	for painting in _paintings:
		if String(painting.get("level_id")) == level_id:
			return painting
	return null


## A LEVEL JUST FINISHED HAS OPENED THE NEXT PAINTING, AND THE HOUSE OPENS IT IN FRONT OF HER.
## Kent: "after obtaining the painting, it should return to the house like the lobby and there
## should be an animation wherein the level gets unlocked". The camera goes to the frame, the
## padlock comes off and the picture comes up into its colours (Painting2D.reveal), and the
## line under the title says where to go. The apo waits while it plays.
func _open_in_front_of_her(level_id: String) -> void:
	var painting: Node2D = null
	for node in _paintings:
		if String(node.get("level_id")) == level_id:
			painting = node as Node2D
	if painting == null:
		return
	_revealing = true
	painting.call("show_locked")
	_player.set_physics_process(false)
	var manager := get_node_or_null(^"/root/LevelManager")
	if manager != null and bool(manager.call("is_transitioning")):
		await manager.transition_finished
	# Home first -- she is seen to arrive -- and then the eye goes over to the picture.
	await get_tree().create_timer(0.7).timeout
	_look_at = painting.global_position.x
	await get_tree().create_timer(0.9).timeout
	await painting.call("reveal")
	await get_tree().create_timer(0.7).timeout
	_look_at = NAN
	_revealing = false
	_player.set_physics_process(true)
	var title := String(manager.call("get_level", level_id).get("title", "")) if manager != null else ""
	_status.text = "%s is open. Walk to it and press E." % title if not title.is_empty() \
		else "A new painting is open."


## Whether the house is in the middle of opening a painting.
func is_revealing() -> bool:
	return _revealing


## One painting, hung and wired.
func _hang(index: int, entry: Dictionary) -> void:
	var painting := PaintingScript.new()
	painting.name = "Painting%d" % (index + 1)
	painting.set("level_id", String(entry["id"]))
	painting.set("plate_text", String(entry["plate"]))
	var art_path := "res://assets/hub/paintings/%s.png" % String(entry["id"])
	if ResourceLoader.exists(art_path):
		painting.set("art", load(art_path))
	painting.position = _room.call("painting_anchor", index)
	add_child(painting)
	_paintings.append(painting)
	painting.connect(&"chosen", _on_painting_chosen)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HubHud"
	layer.layer = 5
	add_child(layer)

	var title := Label.new()
	title.name = "Title"
	title.text = "THE HOUSE"
	title.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	title.add_theme_color_override(&"font_color", UISkin.GILT_LIT)
	# ⚠ ON A PLATE, NOT ON THE CEILING. The title and the status line were bare text laid over
	# the pressed-tin frieze along the top of the hall, a busy repeating pattern in the same
	# olive as the letters, so "Lola's brush is at the end of the hall. Take it first." -- the
	# one instruction the house gives -- was the hardest thing on screen to read. They sit on
	# the same chip the level HUD uses now, sized to what they say.
	var plate := PanelContainer.new()
	plate.name = "Plate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override(&"panel", UISkin.chip(14.0, 8.0))
	layer.add_child(plate)
	plate.position = Vector2(24.0, 20.0)
	var lines := VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override(&"separation", 2)
	plate.add_child(lines)
	lines.add_child(title)

	_status = Label.new()
	_status.name = "Status"
	_status.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	_status.add_theme_color_override(&"font_color", UISkin.CREAM_TEXT)
	lines.add_child(_status)
	_write_status()

	_build_carried(layer)
	_build_menu_button(layer)

	# The prompt follows the painting rather than the player: it is a label on the picture,
	# and one pinned over the apo's head covers the thing they are looking at.
	_prompt = Label.new()
	_prompt.name = "Prompt"
	_prompt.text = "E   VIEW"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	_prompt.add_theme_color_override(&"font_color", UISkin.GOLD)
	_prompt.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_prompt.add_theme_constant_override(&"shadow_offset_x", 2)
	_prompt.add_theme_constant_override(&"shadow_offset_y", 2)
	_prompt.visible = false
	layer.add_child(_prompt)
	# Wide enough for the longest of the three things it says. It is centred on the target
	# by its own width, so a string that outgrows this would be centred on the wrong number.
	_prompt.size = Vector2(320.0, 30.0)


## The brush, carried, top right -- shown the moment it is taken and there from the first
## frame on every visit afterwards.
##
## NOT IN A BOX, the same as the level HUD is not. It was a bordered chip, which put the
## brush in a little square while the thing it is a picture of stands two metres away
## unboxed on its plinth, and while the gauge it becomes in Payyo has no frame either. The
## word carries an ink outline instead, because unlike the title and the status line on the
## left this corner sits over the pressed-tin ceiling rather than over dark panelling.
func _build_carried(layer: CanvasLayer) -> void:
	# ⚠ ON A PLATE TOO. The note above says unboxed, and it was right about the brush and wrong
	# about the word: BRUSH in olive over the pressed-tin frieze could not be read. The plate is
	# the level HUD's own chip, so the carried brush looks like the ink gauge it becomes.
	_carried = PanelContainer.new()
	_carried.name = "Carried"
	_carried.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_carried as PanelContainer).add_theme_stylebox_override(&"panel", UISkin.chip(14.0, 6.0))
	layer.add_child(_carried)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 12)
	_carried.add_child(row)

	var caption := Label.new()
	caption.name = "Caption"
	caption.text = "BRUSH"
	caption.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	caption.add_theme_color_override(&"font_color", UISkin.GILT_LIT)
	caption.add_theme_constant_override(&"outline_size", 4)
	caption.add_theme_color_override(&"font_outline_color", UISkin.INK)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)

	var art := TextureRect.new()
	art.name = "Brush"
	art.texture = AtlasTexture.new()
	(art.texture as AtlasTexture).atlas = BrushSheet
	(art.texture as AtlasTexture).region = Rect2(
		InkBrush.SHEET_ORIGIN, Vector2(InkBrush.ART) * InkBrush.ART_PIXEL)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.custom_minimum_size = InkBrush.size_at(3)
	row.add_child(art)

	# Sized before it is placed. A container does not know how wide it is until its children
	# have been measured, and a right-hand edge computed against a zero width parks the whole
	# row off the screen.
	_carried.reset_size()
	_carried.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	# Keep its right margin on resize and leave the DEV MODE indicator a clear row above it.
	_carried.position = Vector2(
		get_viewport_rect().size.x - _carried.size.x - 24.0, 56.0)
	_carried.visible = _has_brush()


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_camera.global_position = _eye_on(_look_at if is_finite(_look_at) else _player.global_position.x)
	_last_hall_x = _player.position.x
	var manager := get_node_or_null(^"/root/LevelManager")
	var transitioning := manager != null and bool(manager.call("is_transitioning"))
	if transitioning:
		# Leave the current controls intact for their separate screen-space fade.
		return
	var previous_near := _near
	_near = null if is_revealing() else _nearest_target()
	if _near != previous_near and _near in _paintings:
		get_node(^"/root/LevelManager").call("prepare_level", String(_near.get("level_id")))
	for painting in _paintings:
		painting.call("set_player_aligned", painting == _near)
	_prompt.visible = _near != null
	if _near == null:
		return
	var on_stand := _near == _stand
	if on_stand:
		_wear(Wear.TAKE)
	elif not _has_brush():
		_wear(Wear.REFUSE)
	elif not bool(_near.call("is_playable")):
		_wear(Wear.UNFINISHED)
	elif bool(_near.call("is_locked")):
		_wear(Wear.LOCKED)
	else:
		_wear(Wear.VIEW)
	# Placed in screen space so it reads with the thing it belongs to: under the plate on a
	# picture, and ABOVE the case, clear of the dome -- the plate is on the floor at its
	# foot and the brush is inside the glass between the two.
	var canvas := get_viewport().get_canvas_transform()
	var offset := Vector2(0.0, -186.0) if on_stand else Vector2(0.0, 66.0)
	var at := canvas * (_near.global_position + offset)
	_prompt.position = at - Vector2(_prompt.size.x * 0.5, 0.0)


## Where the camera sits to look at somebody standing at `x`.
##
## Held inside the room by hand rather than with the camera's own limits, which are in
## screen pixels and so do not know about the zoom -- with limits set to the room width the
## view slid past the end of the wall at anything other than 1:1.
func _eye_on(x: float) -> Vector2:
	var half := get_viewport_rect().size.x / (2.0 * _camera.zoom.x)
	var span := float(_room.get("room_width"))
	return Vector2(clampf(x, half, maxf(half, span - half)), EYE_Y)


## The one the apo is standing closest to, if they are close enough to any.
##
## The stand answers on the same terms a picture does -- same reach, same measurement along
## the wall -- so it joins the same sweep rather than getting a second nearest-thing check
## of its own. It drops out of the list the moment the brush is off it, because an empty
## stand is scenery and a prompt on it would offer to hand over something that is gone.
func _nearest_target() -> Node2D:
	var origin := _player.global_position
	var best: Node2D = null
	var best_distance := INF
	# The wall is static: avoid a group lookup and two temporary arrays on every frame.
	for target in _paintings:
		if target == null or not bool(target.call("within_reach", origin)):
			continue
		var distance: float = target.call("distance_to_point", origin)
		if distance < best_distance:
			best_distance = distance
			best = target
	if _stand != null and bool(_stand.call("holds_brush")) \
			and bool(_stand.call("within_reach", origin)) \
			and float(_stand.call("distance_to_point", origin)) < best_distance:
		best = _stand
	return best


## THE WAY OUT OF THE HOUSE THAT IS NOT A PAINTING. The house replaced the title screen's
## level grid, and the grid had a way back to the title; the house had none, so the only way
## to reach NEW GAME, the settings or Quit from here was to walk into a level and pause.
## Bottom left, out of the way of the plate and the brush, and Escape does the same.
func _build_menu_button(layer: CanvasLayer) -> void:
	var button := Button.new()
	button.name = "MainMenuButton"
	button.text = "ESC  MAIN MENU"
	button.theme_type_variation = &"DialogButton"
	button.focus_mode = Control.FOCUS_NONE
	button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	button.offset_left = 24.0
	button.offset_top = -72.0
	button.offset_right = 284.0
	button.offset_bottom = -24.0
	button.pressed.connect(_to_main_menu)
	layer.add_child(button)


func _to_main_menu() -> void:
	remember_position()
	var manager := get_node_or_null(^"/root/LevelManager")
	if manager != null:
		manager.call("open_main_menu")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_to_main_menu()
		return
	if not event.is_action_pressed(&"interact") or event.is_echo() or is_revealing() or _near == null:
		return
	get_viewport().set_input_as_handled()
	if _near == _stand:
		_stand.call("take")
		return
	_near.call("choose")


func _on_painting_chosen(level_id: String) -> void:
	var manager := get_node_or_null(^"/root/LevelManager")
	if manager == null:
		return
	# THE BRUSH COMES FIRST, before the question of whether this particular picture is
	# finished. LevelManager refuses the same way and is the real gate -- this is here so
	# the refusal has WORDS on it and points down the hall, instead of a key press that
	# does nothing.
	if not _has_brush():
		_status.text = "Not without her brush. It is at the end of the hall."
		return
	if not bool(manager.call("is_unlocked", level_id)):
		# The painting is built, so `is_playable` alone cannot explain this refusal. Without
		# this line E was accepted, LevelManager correctly rejected the locked level, and the
		# house said nothing at all -- indistinguishable from a broken interaction key.
		_status.text = "That place is still out of reach. Finish the earlier painting first."
		return
	if not bool(manager.call("is_playable", level_id)):
		# Named, not scolded. The plate already says it is unfinished; this is the answer to
		# having pressed the key anyway.
		_status.text = "Lola has not painted that one yet."
		return
	for painting in _paintings:
		if String(painting.get("level_id")) == level_id:
			remember_position()
			manager.call("open_level", level_id, painting)
			return


## WHAT THE KEY WILL DO, not a generic verb. Standing at a painting without the brush is
## the one case where the prompt refuses rather than promises: the plate says what the
## picture is and this says why pressing E will not open it, which is the only place a
## player who walked straight past the case finds out.
##
## Written only when it CHANGES. This is called from _process, and a theme override is not
## a field assignment -- setting one fires a notification that walks the control and its
## children, so the three-line version of this repainted the label sixty times a second to
## say the same word.
func _wear(state: Wear) -> void:
	if state == _wearing:
		return
	_wearing = state
	match state:
		Wear.TAKE:
			_prompt.text = "E   TAKE"
			_prompt.add_theme_color_override(&"font_color", UISkin.GILT_HI)
		Wear.VIEW:
			_prompt.text = "E   VIEW"
			_prompt.add_theme_color_override(&"font_color", UISkin.GOLD)
		Wear.REFUSE:
			_prompt.text = "NEEDS LOLA'S BRUSH"
			_prompt.add_theme_color_override(&"font_color", UISkin.MUTED)
		Wear.LOCKED:
			_prompt.text = "LOCKED"
			_prompt.add_theme_color_override(&"font_color", UISkin.MUTED)
		Wear.UNFINISHED:
			_prompt.text = "NOT YET PAINTED"
			_prompt.add_theme_color_override(&"font_color", UISkin.MUTED)


func _has_brush() -> bool:
	var profile := get_node_or_null(^"/root/PlayerProfile")
	return profile != null and bool(profile.call("has_brush"))


## Taken off the stand. Everything that was refusing now stops refusing, and the house says
## so once rather than leaving the player to walk back and discover it.
func _on_brush_taken() -> void:
	_status.text = "Her brush is yours. Now choose a painting."
	_show_carried()
	# THE FIRST THING THE PLAYER EVER ACQUIRES, and it was the one acquisition with no card.
	# Every pickup in a level plays AcquiredOverlay; the brush is taken in the HUB, which is a
	# different scene with its own tree, so it had quietly been left out -- and this is the
	# object the whole game runs through. Without it, taking the brush is a sprite dissolving
	# and a line of small text under the title.
	if _acquired != null and is_instance_valid(_acquired):
		_acquired.present("Lola's Brush",
			"Everything you can do in a level runs through it.",
			load("res://assets/hud/brush_full.png") as Texture2D)
	# The prompt says something different now. Nothing in this room lets the apo stand at a
	# painting and the case at once, but the cached wear would outlive the change if one
	# ever did, and a stale refusal on an open painting is the worst of the three states.
	_wearing = Wear.NONE


## The line under the title. It is the room's only standing instruction, so it says the
## thing the player cannot do anything without: on a first visit, where the brush is.
func _write_status() -> void:
	_status.text = "Walk to a painting and press E" if _has_brush() \
		else "Lola's brush is at the end of the hall. Take it first."


## The brush, carried. A corner of the screen that says the apo has it -- the same artwork
## the level HUD drains, shown here full, because the point of this room is that you leave
## it holding something you did not walk in with.
func _show_carried() -> void:
	if _carried == null or not is_instance_valid(_carried):
		return
	_carried.visible = true
