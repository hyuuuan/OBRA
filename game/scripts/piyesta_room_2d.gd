class_name PiyestaRoom2D
extends Node2D
## The four insides of Piyesta: the church, the lit house, and the two alleys.
##
## ONE SCRIPT AND NOT FOUR, and that is the decision worth defending. Level 1 has two
## interiors and they are two scripts, because a straw heap and a bamboo house are two
## different arguments about material. These four are not: they are the same box seen in
## three dressings, and every one of them owes the level the identical six answers --
## `bounds`, `camera_rect`, `entry_point`, `eye_level`, `how_far_in`, `exit_rect`. Four
## copies of `bounds()` is four chances for one of them to drift a wall away from its own
## collision, and the failure that causes is a player standing in a room the camera says
## they have left.
##
## PLACEHOLDER ART, DELIBERATELY. The design asks for a church interior set, both alley
## layer sets, and a dark-palette variant of TextureMap_Piyesta, and none of the four
## exists -- `Level 2 Pista Design Refined.pdf` lists all of them under "Environments and
## backgrounds". So these rooms are drawn in code the way Payyo's props were before the art
## arrived, to `ART_PLACEHOLDERS.md` rules: real size, real collision, and nothing implying
## an affordance it does not have. When the sets land, this script becomes a sprite driver
## and the numbers below are the brief.
##
## THE RULER IS THE APO, as it is in the straw room. He is 96 pixels tall and a child of
## about a metre thirty, so A METRE IS SEVENTY-TWO PIXELS, and every dimension here carries
## the measurement it came from.
##
## THEY ARE PARKED IN THE SKY above the plaza, thousands of units off, and the player is
## carried into them by the same teleport Level 1 uses for the heap and the house: it is the
## same body in the same level, so ink, the bag, the drawing panel and every checkpoint come
## with them.
##
## ⚠ NOT DRAWN WHILE NOBODY IS IN IT. A room paints a solid ground behind itself so the sky
## it is standing in never shows through the wall, and that ground has to reach well past the
## walls because the camera leads the player. Left switched on, it paints the plaza. This is
## the bug that put black over half of Payyo's valley and it is one line -- see `_process`.

## The apo has walked into the opening they came in by.
signal exit_reached()
## The apo has walked into the opening that leads on to the next room.
signal onward_reached()
## Something in here worth a sentence, and the sentence going away again. Hint channel: no
## key press, no pause, cleared on the way out. Same contract Level 1's interiors have.
signal noticed(text: String)
signal notice_left()

## Which dressing. The shell is identical; this picks the palette, the material and whether
## there is a roof over it or open sky.
enum Kind { CHURCH, HOUSE, ALLEY }

@export var kind: Kind = Kind.ALLEY
## How long the room is, floor centre at this node's origin.
@export var room_length := 900.0
## Floor to ceiling, or floor to the top of the wall where the sky starts.
@export var wall_height := 420.0
## How far the floor runs toward the viewer before the frame ends. A metre thirty.
@export var floor_depth := 100.0
## How far in the camera sits. A small room wants 2 and fills the frame at it; a nave wants
## less, because coming in that close to a six-metre nave shows a wall and nothing else.
@export var room_zoom := 1.8
## Whether the way onward is open yet. A room at the end of a chain sets this false and the
## level arms it when the beat that opens it is answered -- so an alley the player has not
## earned is a room with one door, not a door that lies about where it goes.
@export var onward_open := false
## Drawn beside the onward opening while it is shut, so a closed way out is a thing the
## player can see rather than a wall they bounce off.
@export var onward_note: String = ""

## A doorway in a town wall: one metre by two and a bit.
const DOOR := Vector2(76.0, 150.0)
## How far past the walkable end each opening sits, so walking out of one does not count as
## walking straight back into it.
const DOOR_INSET := 30.0
## The apo's jump apex (`wanderer.gd`), the number every reachable thing in this project is
## measured against. Nothing in a room's shell may sit above floor + this without something
## to stand on, or the room is a Climb gate nobody wrote down.
const JUMP_RISE := 94.3

## --- CHURCH. Lime-washed stone in the daylight from a high window, and candle warmth at
## the altar end. Cool where the light is not.
const STONE_DEEP := Color(0.180, 0.184, 0.204, 1.0)   # 2E2F34
const STONE_DARK := Color(0.286, 0.290, 0.306, 1.0)   # 494A4E
const STONE := Color(0.435, 0.435, 0.427, 1.0)        # 6F6F6D
const STONE_LIT := Color(0.588, 0.576, 0.541, 1.0)    # 96938A
const STONE_PALE := Color(0.749, 0.729, 0.671, 1.0)   # BFBAAB
## The courses cycle through these so neighbouring blocks differ without the wall
## turning into noise. Typed, because an untyped literal indexed inline gives GDScript
## nothing to infer from and the whole script fails to parse -- which loads the scene with
## no script on the room and is silent everywhere except the ground check.
const STONE_TONES: Array[Color] = [STONE, STONE_LIT, STONE_DARK, STONE]
## The window light landing on the floor. Warm, because it is afternoon outside.
const WINDOW_LIGHT := Color(0.965, 0.902, 0.702, 0.28)
const CANDLE_GLOW := Color(0.980, 0.788, 0.400, 0.20)

## --- HOUSE. Plank and bamboo, one room, one candle. Warmer and much smaller than the
## church, and lit from inside rather than through anything.
const PLANK_DEEP := Color(0.161, 0.106, 0.063, 1.0)   # 291B10
const PLANK_DARK := Color(0.290, 0.196, 0.114, 1.0)   # 4A321D
const PLANK := Color(0.435, 0.310, 0.184, 1.0)        # 6F4F2F
const PLANK_LIT := Color(0.573, 0.427, 0.259, 1.0)    # 926D42
const PLANK_PALE := Color(0.702, 0.561, 0.373, 1.0)   # B38F5F

const PLANK_TONES: Array[Color] = [PLANK, PLANK_LIT, PLANK_DARK, PLANK, PLANK_PALE]

## --- ALLEY. Plaster over rubble, in shade, with the fiesta going on somewhere the player
## can hear and not see. The design word is "dark, narrow, behind the plaza".
const PLASTER_DEEP := Color(0.114, 0.129, 0.145, 1.0) # 1D2125
const PLASTER_DARK := Color(0.184, 0.204, 0.216, 1.0) # 2F3437
const PLASTER := Color(0.294, 0.310, 0.310, 1.0)      # 4B4F4F
const PLASTER_LIT := Color(0.400, 0.408, 0.396, 1.0)  # 666865
const PLASTER_PALE := Color(0.518, 0.510, 0.478, 1.0) # 84827A
## The strip of sky over an alley. This is the only bright thing in the room and it is where
## the birds circle, so it is generous.
const ALLEY_SKY := Color(0.545, 0.729, 0.851, 1.0)    # 8BBADA
const ALLEY_SKY_LOW := Color(0.729, 0.808, 0.831, 1.0)# BACED4

const PLASTER_TONES: Array[Color] = [PLASTER, PLASTER_LIT, PLASTER_DARK, PLASTER]

## The ground everything is drawn against, so the plaza never shows through a wall.
const VOID := Color(0.043, 0.047, 0.055, 1.0)         # 0B0C0E
## Trodden earth and worn flags. A floor somebody has walked on for a season is not one
## flat colour, which is the note the straw room's floor is written on.
const FLOOR_DEEP := Color(0.145, 0.129, 0.110, 1.0)   # 25211C
const FLOOR_DARK := Color(0.220, 0.196, 0.161, 1.0)   # 383229
const FLOOR_MID := Color(0.310, 0.278, 0.227, 1.0)    # 4F473A
const FLOOR_LIT := Color(0.404, 0.365, 0.302, 1.0)    # 675D4D
const FLOOR_TONES: Array[Color] = [FLOOR_MID, FLOOR_LIT, FLOOR_DARK, FLOOR_MID, FLOOR_DEEP]

## Daylight in an opening. Washed out, because the eye in here is used to the dark.
const DAYLIGHT := Color(0.965, 0.925, 0.804, 1.0)     # F6ECCD
const DAYLIGHT_DIM := Color(0.812, 0.757, 0.612, 1.0) # CFC19C
## A shut way onward: boarded, and visibly boarded rather than merely absent.
const BOARD := Color(0.310, 0.239, 0.157, 1.0)        # 4F3D28

var _shell_built := false
var _exit_area: Area2D
var _onward_area: Area2D
## Seconds before an opening counts as "leave" again, so arriving inside one does not step
## the player straight back out of the room they have just walked into.
var _exit_grace := 0.0
var _onward_grace := 0.0


func _ready() -> void:
	add_to_group(&"interiors")
	# Level 2's own group. The base's `_room_holding_player` asks `interiors`; the level asks
	# this one when it wants a room BY NAME rather than whichever one holds the player.
	add_to_group(&"piyesta_rooms")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -10
	_build_shell()
	_build_openings()
	# See the class comment: a room drawn while nobody is inside it is a room painted over
	# the level.
	visible = false
	set_process(true)


## Whether the apo is standing in here, asked of their position rather than set by a
## doorway -- a checkpoint restore, a fall, a morph or an expiry can all move them in or out
## without going through one, and every one of those left Payyo's rooms drawn over the
## valley until `_room_holding_player` was written the same way.
func _process(delta: float) -> void:
	_exit_grace = maxf(0.0, _exit_grace - delta)
	_onward_grace = maxf(0.0, _onward_grace - delta)
	var here := false
	for node in get_tree().get_nodes_in_group(&"player_character"):
		var body := node as Node2D
		if body != null and bounds().grow(90.0).has_point(body.global_position):
			here = true
			break
	if here == visible:
		return
	visible = here


# --- The contract every interior answers ----------------------------------------------

## The box the room OCCUPIES, floor centre at this node's origin. This is the right answer
## to "is the player in here" and the wrong one to "where may the camera look" -- see
## `camera_rect`.
func bounds() -> Rect2:
	return Rect2(global_position - Vector2(room_length * 0.5, wall_height),
		Vector2(room_length, wall_height + floor_depth))


## THE BOX THE CAMERA MAY NOT LOOK OUT OF, and it is wider than `bounds()` on purpose: the
## room is DRAWN past its own walls (see `_span`) so the camera can lead the player to the
## end of it without the plaza appearing behind the masonry.
func camera_rect() -> Rect2:
	var span := _span()
	return Rect2(global_position - Vector2(span, wall_height),
		Vector2(span * 2.0, wall_height + floor_depth))


func how_far_in() -> float:
	return room_zoom


## Where the camera sits to look at this room: halfway up it, so a screenful shows the whole
## height and neither the ceiling nor the floor slides off as the player walks.
func eye_level() -> float:
	return global_position.y - (wall_height - floor_depth) * 0.5


## Where the apo appears on the way IN -- just inside the way they came, so the first thing
## in front of them is the room and the first thing behind them is how to leave.
func entry_point() -> Vector2:
	return global_position + Vector2(-room_length * 0.5 + DOOR.x * 1.6, 0.0)


## Where the apo appears when they come BACK from the room ahead: at the far end, beside the
## opening they returned through. Walking back into a room and landing at its front door
## would silently undo the walk that got them to the far end of it.
func return_point() -> Vector2:
	return global_position + Vector2(room_length * 0.5 - DOOR.x * 1.6, 0.0)


## The opening they came in by, in this room's own space.
func exit_rect() -> Rect2:
	return Rect2(Vector2(-room_length * 0.5 + DOOR_INSET, -DOOR.y), DOOR)


## The opening that leads on, at the far end. A room with nowhere to go still HAS one --
## it is simply never armed -- because a rect that exists is a rect the audit can measure.
func onward_rect() -> Rect2:
	return Rect2(Vector2(room_length * 0.5 - DOOR_INSET - DOOR.x, -DOOR.y), DOOR)


## How far past the walkable walls the room is painted. The camera sees roughly 400 units
## either side at this zoom and the player can walk right up to the end wall, so a room drawn
## only as far as it is walkable puts its own edge on screen with the plaza behind it. Safe
## to be generous: none of it is drawn while the player is somewhere else.
func _span() -> float:
	return room_length * 0.5 + 480.0


## Open the way onward, and say so. Called by the level when the beat that earns it commits.
func open_onward() -> void:
	if onward_open:
		return
	onward_open = true
	queue_redraw()


## Stop the openings answering for a moment. Called on the way in, for the reason
## `BaleInterior2D.disarm_the_way_out` exists: the entry point is INSIDE the room but within
## a body's width of the doorway, and an `Area2D` sweeps on the frame it arms.
func disarm_the_way_out() -> void:
	_exit_grace = 0.5
	_onward_grace = 0.5


# --- The shell ------------------------------------------------------------------------

## SOMETHING TO STAND ON, AND WALLS AT BOTH ENDS. The room is parked in the sky, so it
## brings its own floor; without one the apo drops out of the bottom and the level fishes
## them back to a checkpoint on the plaza, which is a very confusing way to leave a room.
## The end walls matter for the same reason in the other axis.
func _build_shell() -> void:
	if _shell_built:
		return
	_shell_built = true
	_add_body("Floor", Vector2(0.0, floor_depth * 0.5),
		Vector2(room_length + 240.0, floor_depth))
	# Walls stand from the floor to well above the ceiling: a player who morphs into
	# something that climbs must not be able to leave over the top of the room.
	for side: float in [-1.0, 1.0]:
		_add_body("Wall%s" % ("L" if side < 0.0 else "R"),
			Vector2(side * (room_length * 0.5 + 40.0), -wall_height * 0.5),
			Vector2(80.0, wall_height * 3.0))
	# A lid, for the two roofed rooms only. An alley is open to the sky by design -- that is
	# where the birds circle and where the bandaritas are strung, and a ceiling over it would
	# make the flight rule a roof instead of a line.
	if kind != Kind.ALLEY:
		_add_body("Ceiling", Vector2(0.0, -wall_height - 40.0),
			Vector2(room_length + 240.0, 80.0))


func _add_body(body_name: String, at: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = body_name
	body.position = at
	add_child(body)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)


func _build_openings() -> void:
	_exit_area = _add_opening("WayBack", exit_rect(), _on_exit_body)
	_onward_area = _add_opening("WayOnward", onward_rect(), _on_onward_body)


func _add_opening(opening_name: String, rect: Rect2, handler: Callable) -> Area2D:
	var area := Area2D.new()
	area.name = opening_name
	area.position = rect.position + rect.size * 0.5
	area.monitoring = true
	add_child(area)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	area.add_child(shape)
	area.body_entered.connect(handler)
	return area


func _on_exit_body(body: Node) -> void:
	if _exit_grace > 0.0 or not body.is_in_group(&"player_character"):
		return
	exit_reached.emit()


func _on_onward_body(body: Node) -> void:
	if _onward_grace > 0.0 or not body.is_in_group(&"player_character"):
		return
	if not onward_open:
		# REFUSED, AND SAID SO. A press -- or in this case a walk -- that does nothing and
		# explains nothing is one the player concludes is broken.
		if not onward_note.is_empty():
			noticed.emit(onward_note)
		return
	onward_reached.emit()


# --- What it looks like -----------------------------------------------------------------

func _draw() -> void:
	_draw_void()
	_draw_wall()
	_draw_floor()
	_draw_opening(exit_rect(), true)
	_draw_opening(onward_rect(), onward_open)


## What the room is seen against, and only just bigger than the room: a ground that reaches
## a screen past the walls is a ground painted over the level.
func _draw_void() -> void:
	var span := _span()
	draw_rect(Rect2(-span, -wall_height - 260.0,
		span * 2.0, wall_height + floor_depth + 460.0), VOID)


func _draw_wall() -> void:
	match kind:
		Kind.CHURCH:
			_draw_masonry()
		Kind.HOUSE:
			_draw_planks()
		_:
			_draw_plaster()


## Coursed lime-washed stone, and a tall window at the altar end throwing warm light down
## the nave. The courses are what make a wall read as built rather than as a colour.
func _draw_masonry() -> void:
	var span := _span()
	draw_rect(Rect2(-span, -wall_height, span * 2.0, wall_height), STONE_DARK)
	var course := 46.0                      # 64cm, a worked block
	var row := 0
	var y := -wall_height
	while y < 0.0:
		# Offset every other course so the joints break, which is the whole of why a wall
		# looks like masonry and not like tiles.
		var offset := 0.0 if row % 2 == 0 else 62.0
		var x := -span + offset
		while x < span:
			var tone: Color = STONE_TONES[(row * 7 + int(x / 124.0)) % STONE_TONES.size()]
			draw_rect(Rect2(x + 2.0, y + 2.0, 120.0, course - 4.0), tone)
			x += 124.0
		draw_rect(Rect2(-span, y, span * 2.0, 2.0), STONE_DEEP)
		y += course
		row += 1
	# The high window, and the light off it. Sill at 2.6m so it is plainly out of reach --
	# nothing in this room is climbed and the shape should say so.
	var window := Rect2(room_length * 0.22, -wall_height + 40.0, 96.0, 190.0)
	draw_rect(window.grow(8.0), STONE_DEEP)
	draw_rect(window, DAYLIGHT_DIM)
	draw_rect(Rect2(window.position + Vector2(0.0, 6.0), Vector2(window.size.x, 60.0)),
		DAYLIGHT)
	# The pool it throws on the floor, cast toward the middle of the nave.
	draw_colored_polygon(PackedVector2Array([
		window.position + Vector2(0.0, window.size.y),
		window.position + Vector2(window.size.x, window.size.y),
		Vector2(window.position.x - 40.0, 0.0),
		Vector2(window.position.x - 250.0, 0.0)]), WINDOW_LIGHT)
	# Warmth at the altar end, so the far end of the nave is somewhere to walk toward.
	draw_rect(Rect2(room_length * 0.5 - 300.0, -wall_height, 300.0, wall_height),
		CANDLE_GLOW)
	for side: float in [-1.0, 1.0]:
		_draw_pilaster(side * room_length * 0.5, STONE_PALE, STONE_DEEP)


## Sawn plank over a bamboo frame, in one small room. The house is somebody's, so it is warm
## and close and the boards run vertically like a wall that was built by hand.
func _draw_planks() -> void:
	var span := _span()
	draw_rect(Rect2(-span, -wall_height, span * 2.0, wall_height), PLANK_DARK)
	var x := -span
	var index := 0
	while x < span:
		var width := 26.0 + float((index * 13) % 3) * 6.0
		var tone: Color = PLANK_TONES[index % PLANK_TONES.size()]
		draw_rect(Rect2(x, -wall_height, width - 3.0, wall_height), tone)
		draw_rect(Rect2(x + width - 3.0, -wall_height, 3.0, wall_height), PLANK_DEEP)
		x += width
		index += 1
	# Two rails, which is what stops a run of vertical boards reading as a fence.
	for height: float in [0.30, 0.72]:
		draw_rect(Rect2(-span, -wall_height * height - 9.0, span * 2.0, 18.0), PLANK_LIT)
		draw_rect(Rect2(-span, -wall_height * height + 9.0, span * 2.0, 4.0), PLANK_DEEP)
	for side: float in [-1.0, 1.0]:
		_draw_pilaster(side * room_length * 0.5, PLANK_PALE, PLANK_DEEP)


## Plaster over rubble, in shade, open to a strip of sky. The alley is the only room in the
## level with weather in it, and the sky is where everything the player wants has gone.
func _draw_plaster() -> void:
	var span := _span()
	# The sky above the wall. Drawn first and tall, because the birds circle up into it and
	# the bandaritas are strung across it.
	draw_rect(Rect2(-span, -wall_height - 260.0, span * 2.0, 260.0), ALLEY_SKY)
	draw_rect(Rect2(-span, -wall_height - 60.0, span * 2.0, 60.0), ALLEY_SKY_LOW)
	draw_rect(Rect2(-span, -wall_height, span * 2.0, wall_height), PLASTER_DARK)
	# Patchy render: plaster that has been repaired more than once, in slabs rather than
	# strokes, so the wall has areas rather than noise.
	var index := 0
	var y := -wall_height
	while y < 0.0:
		var x := -span + float((index * 53) % 90)
		while x < span:
			var width := 90.0 + float((index * 37) % 5) * 26.0
			var tone: Color = PLASTER_TONES[
				(index * 3 + int(x / 90.0)) % PLASTER_TONES.size()]
			draw_rect(Rect2(x, y, width - 5.0, 68.0), tone)
			x += width
			index += 1
		y += 72.0
		index += 1
	# Damp running down from the top of the wall, which is what makes a shaded alley read as
	# a shaded alley rather than as a grey room.
	for streak in range(int(room_length / 130.0) + 4):
		var sx := -span + float(streak) * 130.0 + float((streak * 29) % 40)
		draw_rect(Rect2(sx, -wall_height, 16.0, wall_height * (0.35 + 0.1 * float(streak % 4))),
			PLASTER_DEEP)
	# A capping course at the top, so the wall ends against the sky rather than stopping.
	draw_rect(Rect2(-span, -wall_height - 12.0, span * 2.0, 16.0), PLASTER_PALE)
	for side: float in [-1.0, 1.0]:
		_draw_pilaster(side * room_length * 0.5, PLASTER_PALE, PLASTER_DEEP)


## A corner at each end the player can walk to, so the room has a length the eye can read
## rather than running on forever.
func _draw_pilaster(at_x: float, lit: Color, dark: Color) -> void:
	draw_rect(Rect2(at_x - 16.0, -wall_height, 32.0, wall_height), dark)
	draw_rect(Rect2(at_x - 12.0, -wall_height, 8.0, wall_height), lit)


## Laid in courses, like the boards in the hub's house: a floor somebody has walked on for a
## season is not one flat colour.
func _draw_floor() -> void:
	var span := _span()
	draw_rect(Rect2(-span, 0.0, span * 2.0, floor_depth), FLOOR_DARK)
	var x := -span
	var index := 0
	while x < span:
		var width := 54.0 + float((index * 17) % 4) * 12.0
		var tone: Color = FLOOR_TONES[index % FLOOR_TONES.size()]
		draw_rect(Rect2(x, 2.0, width - 4.0, floor_depth - 4.0), tone)
		x += width
		index += 1
	# The shadow where the wall meets the floor. Without it the two planes are one plane.
	draw_rect(Rect2(-span, 0.0, span * 2.0, 8.0), FLOOR_DEEP)


## An opening, and what is on the other side of it. An open one shows daylight; a shut one
## shows boards, because a way onward the player has not earned should look shut rather than
## look like wall.
func _draw_opening(rect: Rect2, open: bool) -> void:
	draw_rect(rect.grow(10.0), VOID)
	if open:
		draw_rect(rect, DAYLIGHT_DIM)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.42)), DAYLIGHT)
		# The light it spills onto the floor just inside.
		draw_rect(Rect2(rect.position.x - 14.0, -6.0, rect.size.x + 28.0, 10.0),
			DAYLIGHT_DIM)
		return
	draw_rect(rect, VOID)
	# Boarded across, on the diagonal, which is how a shut thing is shut.
	for board in range(4):
		var y := rect.position.y + 18.0 + float(board) * 34.0
		draw_rect(Rect2(rect.position.x - 6.0, y, rect.size.x + 12.0, 16.0), BOARD)
