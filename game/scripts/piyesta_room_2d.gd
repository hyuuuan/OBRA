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
## AN OPENING IS ARMED BY BEING LEFT, NOT BY A TIMER.
##
## The player arrives in a room by teleport, and `entry_point()` lands them a body's width
## from the way back -- so on the frame they appear they are already standing in it, and an
## opening that answered would step them straight back out of the room they just walked
## into. The first cut of this was a half-second grace, which is wrong in both directions:
## too short and the way back fires anyway, and too long is worse -- a player put down IN an
## opening generates no `body_entered` when the grace expires, because `body_entered` is a
## TRANSITION and there is no transition for a body that was already inside. That is how the
## first alley could be walked into and never walked out of.
##
## Waiting to be left has neither failure. It cannot fire on arrival, and it cannot be
## outrun by a fast machine or missed on a slow one.
var _exit_armed := true
var _onward_armed := true


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
func _process(_delta: float) -> void:
	if not _exit_armed and not _somebody_in(_exit_area):
		_exit_armed = true
	if not _onward_armed and not _somebody_in(_onward_area):
		_onward_armed = true
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


## Stop the openings answering until the player has stepped clear of them. Called on the way
## in, for the reason `BaleInterior2D.disarm_the_way_out` exists: the entry point is INSIDE
## the room but within a body's width of the doorway.
func disarm_the_way_out() -> void:
	_exit_armed = false
	_onward_armed = false


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


func _somebody_in(area: Area2D) -> bool:
	if area == null or not is_instance_valid(area):
		return false
	for body in area.get_overlapping_bodies():
		if body.is_in_group(&"player_character"):
			return true
	return false


func _on_exit_body(body: Node) -> void:
	if not _exit_armed or not body.is_in_group(&"player_character"):
		return
	exit_reached.emit()


func _on_onward_body(body: Node) -> void:
	if not _onward_armed or not body.is_in_group(&"player_character"):
		return
	if not onward_open:
		# REFUSED, AND SAID SO. A press -- or in this case a walk -- that does nothing and
		# explains nothing is one the player concludes is broken.
		if not onward_note.is_empty():
			noticed.emit(onward_note)
		return
	onward_reached.emit()


# --- What it looks like -------------------------------------------------------------------

## BUILT FROM THE ARTIST'S OWN TILESET, not drawn by hand.
##
## The first version of this was `draw_rect` -- flat bands of one colour with a few lines on
## them -- and beside the delivered plaza it read as a grey box. `TextureMap_Piyesta.png`
## ships three nine-slice wall sets, a stone plaza floor, stucco, roof, plank, thatch and a
## shelf of props, and every one of these rooms is made of them. They are the same material
## as the plaza because they are the same pixels.
##
## WHICH SET EACH ROOM IS MADE OF:
##   church -- the pale `church` stone, because it is the same building the plaza faces
##   house  -- `plank` walls over a `moss` stone base, which is how a town house is built
##   alley  -- `moss`, the mossy stone of the plaza's own retaining wall, in shade
func _draw() -> void:
	_draw_void()
	_draw_wall()
	_draw_floor()
	_draw_props()
	_draw_opening(exit_rect(), true)
	_draw_opening(onward_rect(), onward_open)


## The material this room is made of, and the tint the shade puts on it.
func _wall_set() -> String:
	match kind:
		Kind.CHURCH:
			return "church"
		Kind.HOUSE:
			return "moss"
		_:
			return "moss"


## ⚠ AN ALLEY IS IN SHADE AND A CHURCH IS NOT. The design asks the alleys for "dark, narrow,
## behind the plaza" and asks the church for window light, and the tileset is one daylight
## set -- the dark-palette variant it also asks for does not exist. Tinting is not a
## substitute for that variant, but it is honest about which way the light goes and it is
## what stops four rooms made of the same tiles reading as one room.
func _shade() -> Color:
	match kind:
		Kind.CHURCH:
			return Color(0.86, 0.82, 0.78, 1.0)
		Kind.HOUSE:
			return Color(0.78, 0.70, 0.60, 1.0)
		_:
			return Color(0.46, 0.52, 0.60, 1.0)


## What the room is seen against, and only just bigger than the room: a ground that reaches a
## screen past the walls is a ground painted over the level.
func _draw_void() -> void:
	var span := _span()
	draw_rect(Rect2(-span, -wall_height - 260.0,
		span * 2.0, wall_height + floor_depth + 460.0), VOID)


func _draw_wall() -> void:
	var span := _span()
	var set_name := _wall_set()
	var shade := _shade()
	# An alley is open to the sky, so the strip above its wall is daylight rather than more
	# room. It is the only bright thing in there and it is where the birds circle.
	if kind == Kind.ALLEY:
		draw_rect(Rect2(-span, -wall_height - 260.0, span * 2.0, 260.0), ALLEY_SKY)
		draw_rect(Rect2(-span, -wall_height - 70.0, span * 2.0, 70.0), ALLEY_SKY_LOW)
	_draw_courses(Rect2(-span, -wall_height, span * 2.0, wall_height), set_name, shade)
	# A HOUSE IS PLANK OVER A STONE BASE. One material floor to ceiling is a wall; two with
	# the join at waist height is a building somebody made.
	if kind == Kind.HOUSE:
		var base := wall_height * 0.34
		PiyestaTiles.fill(self, Rect2(-span, -wall_height, span * 2.0, wall_height - base),
			"plank", shade)
		PiyestaTiles.run(self, Vector2(-span, -base - 10.0), span * 2.0, "moss_top", shade)
	# The capped top edge -- the whole reason the set has nine tiles and not one.
	var cap := PiyestaTiles.size_of("%s_top" % set_name)
	PiyestaTiles.run(self, Vector2(-span, -wall_height - cap.y * 0.5),
		span * 2.0, "%s_top" % set_name, shade)
	# A pilaster at each end the player can walk to, so the room has a length the eye reads
	# rather than running on forever.
	for side: float in [-1.0, 1.0]:
		var at := side * room_length * 0.5
		PiyestaTiles.fill(self, Rect2(at - 22.0, -wall_height, 44.0, wall_height),
			"%s_left" % set_name, shade)
	if kind != Kind.ALLEY:
		# ⚠ A ROOFED ROOM HAS TO SHOW ITS ROOF. The wall simply stopped at a capping course
		# with the void above it, so both insides read as open-topped pits. The church gets
		# beams under terracotta, the house thatch, which is how each is built outside.
		var eaves := -wall_height - 6.0
		PiyestaTiles.run(self, Vector2(-span, eaves - 52.0), span * 2.0,
			"roof" if kind == Kind.CHURCH else "thatch", shade)
		for index in range(int(span * 2.0 / 190.0) + 1):
			PiyestaTiles.fill(self, Rect2(-span + float(index) * 190.0, eaves - 8.0,
				22.0, 26.0), "post", Color(shade.r * 0.7, shade.g * 0.66, shade.b * 0.6, 1.0))
	if kind == Kind.CHURCH:
		# The high window the nave is lit by, and the light it throws down. Out of reach on
		# purpose: nothing in this room is climbed and the shape should say so.
		var window := Rect2(room_length * 0.22, -wall_height + 54.0, 96.0, 116.0)
		PiyestaTiles.fill(self, window, "stucco_window", Color(1.0, 0.98, 0.92, 1.0))
		draw_colored_polygon(PackedVector2Array([
			window.position + Vector2(0.0, window.size.y),
			window.position + Vector2(window.size.x, window.size.y),
			Vector2(window.position.x - 40.0, 0.0),
			Vector2(window.position.x - 250.0, 0.0)]), WINDOW_LIGHT)


## ⚠ ONE TILE REPEATED IS A GRID, and a grid is what the eye finds first. The set has no
## second fill, so the variation comes from the tint: each course is nudged a few percent
## either side of the shade, and every third block a little further. It is the difference
## between a wall and graph paper, and it costs nothing.
func _draw_courses(rect: Rect2, set_name: String, shade: Color) -> void:
	var tile := PiyestaTiles.size_of("%s_fill" % set_name)
	if tile.y <= 0.0:
		draw_rect(rect, VOID)
		return
	var course := 0
	var y := rect.position.y
	while y < rect.position.y + rect.size.y:
		var height := minf(tile.y, rect.position.y + rect.size.y - y)
		var x := rect.position.x
		var block := 0
		while x < rect.position.x + rect.size.x:
			var width := minf(tile.x, rect.position.x + rect.size.x - x)
			var lift := 1.0 + 0.05 * float((course * 3 + block * 5) % 5 - 2)
			PiyestaTiles.fill(self, Rect2(x, y, width, height), "%s_fill" % set_name,
				Color(shade.r * lift, shade.g * lift, shade.b * lift, 1.0))
			x += tile.x
			block += 1
		y += tile.y
		course += 1


## The stone plaza floor, which is what these rooms are floored with too -- one town, one
## paving. Four blocks in the set, alternated so it does not read as a grid.
func _draw_floor() -> void:
	var span := _span()
	var shade := _shade()
	var names := ["floor_a", "floor_b", "floor_c", "floor_d"]
	var tile := PiyestaTiles.size_of("floor_a")
	if tile.x <= 0.0:
		draw_rect(Rect2(-span, 0.0, span * 2.0, floor_depth), FLOOR_DARK)
		return
	var index := 0
	var x := -span
	while x < span:
		var width := minf(tile.x, span - x)
		# DARKER THAN THE WALL, always. The church's walls and its paving are cut from the
		# same rock, so at the same value the room had no floor line at all -- the apo
		# appeared to be standing in front of a quarry face.
		PiyestaTiles.fill(self, Rect2(x, 0.0, width, floor_depth),
			names[index % names.size()],
			Color(shade.r * 0.72, shade.g * 0.70, shade.b * 0.68, 1.0))
		x += tile.x
		index += 1
	# The wall's own bottom course where it meets the floor, and the shadow it casts. Without
	# them the two planes are one plane.
	PiyestaTiles.run(self, Vector2(-span, -PiyestaTiles.size_of("%s_bottom" % _wall_set()).y
		+ 6.0), span * 2.0, "%s_bottom" % _wall_set(), shade)
	draw_rect(Rect2(-span, 0.0, span * 2.0, 9.0), Color(0.0, 0.0, 0.0, 0.45))


## What is standing in the room. Not decoration -- an empty box of the right material still
## reads as a box, and these are what give it a scale and somewhere for the eye to rest.
func _draw_props() -> void:
	var half := room_length * 0.5
	var shade := _shade()
	match kind:
		Kind.CHURCH:
			# Lanterns down the nave, and the balustrade that separates it from the chancel.
			for index in range(3):
				var x := -half + room_length * (0.30 + 0.22 * float(index))
				PiyestaTiles.hang(self, "lantern_hanging",
					Vector2(x, -wall_height + 24.0), 0.62, shade)
			PiyestaTiles.run(self, Vector2(-half + 90.0, -66.0),
				room_length * 0.22, "balustrade", shade)
			PiyestaTiles.stand(self, "plants", Vector2(-half + 70.0, 0.0), 0.42, shade)
		Kind.HOUSE:
			PiyestaTiles.hang(self, "lantern_hanging",
				Vector2(-half + 120.0, -wall_height + 20.0), 0.52, shade)
			PiyestaTiles.stand(self, "jar_a", Vector2(half - 90.0, 0.0), 0.72, shade)
			PiyestaTiles.stand(self, "plants", Vector2(half - 160.0, 0.0), 0.38, shade)
		_:
			# An alley is where a town keeps what it does not want seen: jars against the
			# wall, weeds at the foot of it, and one lamp somebody hung and left.
			PiyestaTiles.stand(self, "jar_a", Vector2(-half + 130.0, 0.0), 0.78, shade)
			PiyestaTiles.stand(self, "jar_b", Vector2(-half + 186.0, 0.0), 0.70, shade)
			PiyestaTiles.stand(self, "jar_b", Vector2(half - 150.0, 0.0), 0.66, shade)
			PiyestaTiles.stand(self, "plants", Vector2(-half + 300.0, 0.0), 0.34, shade)
			PiyestaTiles.stand(self, "plants", Vector2(half - 260.0, 0.0), 0.30, shade)
			PiyestaTiles.hang(self, "lantern_hanging",
				Vector2(0.0, -wall_height * 0.62), 0.54, shade)


## AN OPENING, AND IT HAS TO READ AS A HOLE THROUGH A WALL.
##
## The first version filled the rect with a flat cream and called it daylight, which put a
## blank slab of card in the middle of every room -- the single most obviously wrong thing
## left in these interiors. What makes a rectangle read as an opening is not its colour, it
## is the DEPTH around it: a jamb standing proud of the wall, an arch built over the head, a
## reveal in shadow down one side, and light that falls off as it goes back.
func _draw_opening(rect: Rect2, open: bool) -> void:
	var set_name := _wall_set()
	var shade := _shade()
	var jamb := 15.0
	var rise := 22.0
	# The surround, and the arch over it. Drawn from the wall's own left-edge tile so the
	# jamb is the same rock as everything around it.
	PiyestaTiles.fill(self, Rect2(rect.position.x - jamb, rect.position.y - rise,
		jamb, rect.size.y + rise), "%s_left" % set_name, shade)
	PiyestaTiles.fill(self, Rect2(rect.position.x + rect.size.x, rect.position.y - rise,
		jamb, rect.size.y + rise), "%s_right" % set_name, shade)
	PiyestaTiles.run(self, Vector2(rect.position.x - jamb, rect.position.y - rise - 10.0),
		rect.size.x + jamb * 2.0, "%s_top" % set_name, shade)
	# The reveal: dark, and darker at the top where the head is.
	draw_rect(rect, Color(0.055, 0.047, 0.043, 1.0))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 16.0)), Color(0.02, 0.02, 0.02, 1.0))
	if not open:
		# Boarded across, and visibly boarded rather than merely dark -- a way onward the
		# player has not earned should look shut.
		for board in range(4):
			var y := rect.position.y + 16.0 + float(board) * 34.0
			PiyestaTiles.fill(self, Rect2(rect.position.x - 5.0, y,
				rect.size.x + 10.0, 18.0), "plank_h", shade)
		draw_rect(Rect2(rect.position.x - 5.0, rect.position.y + 16.0,
			rect.size.x + 10.0, 4.0), Color(0.0, 0.0, 0.0, 0.35))
		return
	# WHAT IS THROUGH IT IS OUTSIDE, not a colour. A doorway seen from a dark room shows a
	# small bright picture -- sky over ground, with a horizon -- inset behind the reveal so
	# the wall has a thickness. The first version drew seven stacked full-height rects with
	# rising alpha, which is a solid cream card with extra steps.
	var inner := rect.grow(-9.0)
	inner.position.y += 6.0
	inner.size.y -= 6.0
	var horizon := inner.position.y + inner.size.y * 0.62
	# Sky, brightest just above the horizon the way a hot afternoon is.
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, horizon - inner.position.y)),
		Color(0.60, 0.80, 0.94, 1.0))
	draw_rect(Rect2(inner.position.x, horizon - 26.0, inner.size.x, 26.0),
		Color(0.82, 0.90, 0.95, 1.0))
	# And the ground out there, in the plaza's own paving.
	PiyestaTiles.fill(self, Rect2(inner.position.x, horizon, inner.size.x,
		inner.position.y + inner.size.y - horizon), "floor_b",
		Color(1.05, 1.02, 0.96, 1.0))
	# The reveal's own shadow down the head and the left jamb: the wall has depth, and this
	# is the only thing that says so.
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, 9.0)), Color(0.0, 0.0, 0.0, 0.5))
	draw_rect(Rect2(inner.position, Vector2(8.0, inner.size.y)), Color(0.0, 0.0, 0.0, 0.32))
	# The threshold, and the light it throws onto the floor just inside.
	PiyestaTiles.run(self, Vector2(rect.position.x - jamb, -12.0),
		rect.size.x + jamb * 2.0, "step_block", shade)
	draw_rect(Rect2(rect.position.x - 18.0, -8.0, rect.size.x + 36.0, 12.0),
		Color(DAYLIGHT.r, DAYLIGHT.g, DAYLIGHT.b, 0.42))
