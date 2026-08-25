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


func _ready() -> void:
	_room = HubRoomScript.new()
	_room.name = "Room"
	add_child(_room)

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
	title.position = Vector2(40.0, 32.0)
	layer.add_child(title)

	_status = Label.new()
	_status.name = "Status"
	_status.text = "Walk to a painting and press E"
	_status.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	_status.add_theme_color_override(&"font_color", UISkin.MUTED)
	_status.position = Vector2(40.0, 62.0)
	layer.add_child(_status)

	# The prompt follows the painting rather than the player: it is a label on the picture,
	# and one pinned over the apo's head covers the thing they are looking at.
	_prompt = Label.new()
	_prompt.name = "Prompt"
	_prompt.text = "E   VIEW"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	_prompt.add_theme_color_override(&"font_color", UISkin.LIME)
	_prompt.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_prompt.add_theme_constant_override(&"shadow_offset_x", 2)
	_prompt.add_theme_constant_override(&"shadow_offset_y", 2)
	_prompt.size = Vector2(240.0, 30.0)
	_prompt.visible = false
	layer.add_child(_prompt)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_camera.global_position = _eye_on(_player.global_position.x)
	_near = _nearest_painting()
	_prompt.visible = _near != null
	if _near == null:
		return
	# Placed under the plate, in screen space, so it reads with the picture it belongs to.
	var canvas := get_viewport().get_canvas_transform()
	var at := canvas * (_near.global_position + Vector2(0.0, 66.0))
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
func _nearest_painting() -> Node2D:
	var origin := _player.global_position
	var best: Node2D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(&"paintings"):
		var painting := node as Node2D
		if painting == null or not bool(painting.call("within_reach", origin)):
			continue
		var distance: float = painting.call("distance_to_point", origin)
		if distance < best_distance:
			best_distance = distance
			best = painting
	return best


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"interact") or _near == null:
		return
	get_viewport().set_input_as_handled()
	_near.call("choose")


func _on_painting_chosen(level_id: String) -> void:
	var manager := get_node_or_null(^"/root/LevelManager")
	if manager == null:
		return
	if not bool(manager.call("is_playable", level_id)):
		# Named, not scolded. The plate already says it is unfinished; this is the answer to
		# having pressed the key anyway.
		_status.text = "Lola has not painted that one yet."
		return
	manager.call("open_level", level_id)
