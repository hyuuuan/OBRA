extends Node2D
## The start of the game: Lolo and Lola's house, with the five paintings on the wall.
##
## WHAT THIS REPLACES. Choosing a level was a grid of cards on the main menu. It is a room
## now -- you walk in as the apo, walk along the wall, and the level you pick is the picture
## you stand in front of. The cards said the same five things; standing in the house says
## why they are the same five things, which is that Lola painted all of them.
##
## Only Payyo can be walked into. The other four hang exactly as they are, lit and named,
## with a plate that says they are not painted yet -- see Painting2D for why that is better
## than hiding them or greying them out.
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
	{"id": "level_2", "plate": "PISTA"},
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
var _carried: Control
## What the prompt is currently saying. NONE until the first target comes into reach.
enum Wear { NONE, TAKE, VIEW, REFUSE }
## The card that says a thing is yours now. See AcquiredOverlay.
var _acquired: AcquiredOverlay
var _wearing: Wear = Wear.NONE


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
	_player.global_position = Vector2(SPAWN_X, _room.call("ground_y"))
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
	_camera.zoom = Vector2(ZOOM, ZOOM)
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
	painting.connect(&"chosen", _on_painting_chosen)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HubHud"
	add_child(layer)

	var title := Label.new()
	title.name = "Title"
	title.text = "THE HOUSE"
	title.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	title.add_theme_color_override(&"font_color", UISkin.GILT_LIT)
	# ADDED FIRST, PLACED SECOND. A font-size override does not reach a Control until it is
	# in the tree, so anything positioned or sized before add_child is laid out against the
	# theme's 30pt rather than the 20 it draws at. See Painting2D._build_plate, where this
	# same ordering put every picture's name to the right of its picture.
	layer.add_child(title)
	title.position = Vector2(40.0, 32.0)

	_status = Label.new()
	_status.name = "Status"
	_status.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	_status.add_theme_color_override(&"font_color", UISkin.MUTED)
	layer.add_child(_status)
	_status.position = Vector2(40.0, 62.0)
	_write_status()

	_build_carried(layer)

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
	_carried = HBoxContainer.new()
	_carried.name = "Carried"
	_carried.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_carried as HBoxContainer).add_theme_constant_override(&"separation", 12)
	layer.add_child(_carried)

	var caption := Label.new()
	caption.name = "Caption"
	caption.text = "BRUSH"
	caption.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	caption.add_theme_color_override(&"font_color", UISkin.GILT_LIT)
	caption.add_theme_constant_override(&"outline_size", 4)
	caption.add_theme_color_override(&"font_outline_color", UISkin.INK)
	_carried.add_child(caption)

	var art := TextureRect.new()
	art.name = "Brush"
	art.texture = AtlasTexture.new()
	(art.texture as AtlasTexture).atlas = BrushSheet
	(art.texture as AtlasTexture).region = Rect2(
		InkBrush.SHEET_ORIGIN, Vector2(InkBrush.ART) * InkBrush.ART_PIXEL)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.custom_minimum_size = InkBrush.size_at(3)
	_carried.add_child(art)

	# Sized before it is placed. A container does not know how wide it is until its children
	# have been measured, and a right-hand edge computed against a zero width parks the whole
	# row off the screen.
	_carried.reset_size()
	_carried.position = Vector2(
		get_viewport_rect().size.x - _carried.size.x - 40.0, 30.0)
	_carried.visible = _has_brush()


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_camera.global_position = _eye_on(_player.global_position.x)
	_near = _nearest_target()
	_prompt.visible = _near != null
	if _near == null:
		return
	var on_stand := _near == _stand
	_wear(Wear.TAKE if on_stand else (Wear.VIEW if _has_brush() else Wear.REFUSE))
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
	var half := get_viewport_rect().size.x / (2.0 * ZOOM)
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
	var candidates: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group(&"paintings"):
		candidates.append(node as Node2D)
	if _stand != null and is_instance_valid(_stand) and bool(_stand.call("holds_brush")):
		candidates.append(_stand)

	var best: Node2D = null
	var best_distance := INF
	for target in candidates:
		if target == null or not bool(target.call("within_reach", origin)):
			continue
		var distance: float = target.call("distance_to_point", origin)
		if distance < best_distance:
			best_distance = distance
			best = target
	return best


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"interact") or _near == null:
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
	if not bool(manager.call("is_playable", level_id)):
		# Named, not scolded. The plate already says it is unfinished; this is the answer to
		# having pressed the key anyway.
		_status.text = "Lola has not painted that one yet."
		return
	manager.call("open_level", level_id)


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
