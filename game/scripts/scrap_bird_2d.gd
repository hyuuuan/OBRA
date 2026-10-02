class_name ScrapBird2D
extends Node2D
## One of the flock in Piyesta's alleys, each carrying one piece of the painting.
##
## THE DESIGN'S PROMISE IS PER-BIRD, NOT PASS/FAIL, so each bird is INDIVIDUALLY ADDRESSABLE
## and owns exactly one scrap. The five do not need to look different; they need to be five
## things, not a number.
##
## ⚠ THEY FLY, THEY DO NOT HANG. They used to circle a 120 x 46 ellipse around a point just
## under the bunting, which from the floor read as five birds stuck to the line. Kent: "the birds
## are just perched to the banderitas instead of flying around". They wander the alley's air now,
## each on its own course, and every so often go back to their nests in the bunting for a few
## seconds before taking off again -- which is also what makes cutting the line a way to get
## what they are holding.
##
## THREE WAYS DOWN, and a bird that has taken one answers none of the others -- the routes are
## alternatives, and a bird that could be fed AND downed would drop its scrap twice:
##   * calmed    -- it flies down to what was put out, eats, and leaves the scrap beside it.
##   * struck    -- a throw hits it; it tumbles to the floor, lets go, and flies off dazed.
##   * scattered -- its nest comes down with the line; it bolts, and the scrap flutters down.
##
## THE SCRAP ENDS UP ON THE FLOOR EVERY TIME, and from there it is the level's: `scrap_dropped`
## says where it lies, the level puts the piece there for the player to walk over and pick up,
## and this bird stops drawing it. The bird never decides whether a piece is collected.

## The scrap is lying on the floor, and `at` (global) is the point on the floor under it. From
## here it is the level's to lay out.
signal scrap_dropped(scrap_id: String, at: Vector2)

enum State { FLYING, PERCHED, DESCENDING, CALMED, FALLING, DOWNED, FLEEING, GONE }

## Which piece of the painting this one has. Set by the alley when it spawns the flock.
@export var scrap_id: String = ""
## Where it may fly, in the parent's (the alley's) own space: x across the alley, y above its
## floor. The floor is y = 0 in an alley.
@export var airspace := Rect2(-380.0, -270.0, 760.0, 150.0)
## How fast it flies, and how hard it can turn toward where it is going.
@export var cruise_speed := 120.0
@export var steer := 260.0
## How long it stays up between visits to the nest, and how long it sits there, in seconds.
@export var flight_seconds := Vector2(6.0, 11.0)
@export var perch_seconds := Vector2(2.5, 4.5)
## Where a piece it lets go of may come to rest, across the parent's x: the floor between the
## alley's two doorways. ⚠ NEVER IN A DOORWAY -- walking in to pick a piece up out of one walks
## the apo out of the alley, and the piece is still lying there when they come back.
@export var drop_span := Vector2(-INF, INF)

## Where its nest is: a Callable returning the GLOBAL point on the bunting it lands on. The line
## sways, so this is asked every frame while the bird is on it. Empty for a bird with no nest.
var nest := Callable()
## Where the floor is, in the parent's space. An alley's floor is 0.
var floor_y := 0.0

## Hit by a thrown stone at this distance from its middle. A bird is small and a stone is
## smaller; this is generous because the player is aiming at something moving.
const HIT_RADIUS := 30.0
const GRAVITY := 900.0
## How fast it comes down to food, and how fast it gets out when its nest falls.
const DESCEND_SPEED := 150.0
const FLEE_SPEED := 260.0
## How long a struck bird sits stunned on the floor before it shakes it off and goes. Struck,
## never killed: a bird lying still for the rest of the level reads as one that died.
const DAZED_SECONDS := 1.4
## How long a leaving bird takes to fade out.
const LEAVING_SECONDS := 1.2
## Where the piece lies beside a bird on the floor: far enough in front of it that the bird is
## still seen eating, or lying stunned, rather than hidden behind what it dropped.
const BESIDE := 32.0
## Where a piece's picture is anchored above the floor it lies on: `draw_scrap` hangs the card
## eighteen pixels below its anchor, so at sixteen up its lower edge just meets the floor.
const PIECE_LIFT := 16.0

## ⚠ PIXEL ART, NOT POLYGONS. Kent: the birds are "so weird ... not detailed enough for a 8bit
## game". They were three smooth polygons and a circle drawn here, which at the alley's zoom are
## antialiased brown arrowheads beside an apo painted pixel by pixel. They are maya now -- the
## tree sparrow of every plaza -- drawn at the apo's own density by tools/build_birds.py: a sheet
## of frames on one origin (MANIFEST says which cell is which, and where each frame's bill is),
## and the piece of painting they carry, a torn bit of canvas with the Dagat sea on it.
const SHEET := preload("res://assets/Level2/birds/maya.png")
const SCRAP_ART := preload("res://assets/Level2/birds/scrap.png")
const MANIFEST := "res://assets/Level2/birds/maya.json"
## The four beats of a wingbeat: up, level, down, level.
const STROKE := ["fly_up", "fly_mid", "fly_down", "fly_mid"]
## Where the piece hangs from the bill: by its top corner, ahead of the bill and below it. Hung
## from its middle, the card covered the bird's whole face -- the part that makes it a maya.
const HELD_BELOW_BILL := Vector2(9.0, 6.0)

## The sheet's layout, read once for every bird.
static var _cells := {}
static var _cell := Vector2.ZERO
static var _origin := Vector2.ZERO

var _state: int = State.FLYING
## Whether the scrap is still in its beak. False from the moment it has let go of it.
var _holding := true
var _velocity := Vector2.ZERO
var _target := Vector2.ZERO
var _clock := 0.0
var _until := 0.0
var _flap := 0.0
var _facing := 1.0
var _spin := 0.0
## Where it is flying down to, while it is (parent space).
var _landing := Vector2.ZERO
## Where the food it was fed is, across the parent's x, so it lands facing it and sets its piece
## down behind itself -- not under the thing it came down to eat. NAN when it was not fed.
var _food_x := NAN
## A scrap let go of in the air, fluttering down on its own (parent space). INF when none.
var _loose_scrap := Vector2.INF
var _loose_fall := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"scrap_birds")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_read_the_sheet()
	# Each its own course: seeded off its id, so a flock is the same flock every run and a test
	# can reason about it, and no two of them move together.
	_rng.seed = hash(scrap_id) + 1
	_flap = _rng.randf() * TAU
	_until = _rng.randf_range(flight_seconds.x * 0.3, flight_seconds.y)
	_pick_a_heading()
	queue_redraw()


func state() -> int:
	return _state


## Taken one of the three ways down. An answered bird answers nothing else.
func is_answered() -> bool:
	return _state in [State.DESCENDING, State.CALMED, State.FALLING, State.DOWNED,
		State.FLEEING, State.GONE]


## Up and about, and so something a throw can hit.
func is_airborne() -> bool:
	return _state == State.FLYING or _state == State.PERCHED


func is_perched() -> bool:
	return _state == State.PERCHED


## Whether the scrap is still in its beak.
func is_holding() -> bool:
	return _holding


## Whether a thrown thing at `point` (global) has hit it.
func hit_test(point: Vector2, radius: float = 0.0) -> bool:
	return is_airborne() and global_position.distance_to(point) <= HIT_RADIUS + radius


func _physics_process(delta: float) -> void:
	_clock += delta
	match _state:
		State.FLYING:
			_fly(delta)
		State.PERCHED:
			_sit(delta)
		State.DESCENDING:
			_descend(delta)
		State.CALMED:
			_flap += delta * 5.0
		State.FALLING:
			_fall(delta)
		State.DOWNED:
			_daze(delta)
		State.FLEEING:
			_flee(delta)
	if _loose_scrap != Vector2.INF:
		_drop_the_loose_scrap(delta)
	queue_redraw()


# --- Flying about ----------------------------------------------------------------------

func _fly(delta: float) -> void:
	_flap += delta * 11.0
	if _clock >= _until and nest.is_valid():
		# Home for a while. The nest is where the scraps live; cutting it down is a route.
		_target = _nest_here()
		if position.distance_to(_target) < 10.0:
			_state = State.PERCHED
			_clock = 0.0
			_until = _rng.randf_range(perch_seconds.x, perch_seconds.y)
			_velocity = Vector2.ZERO
			return
	elif position.distance_to(_target) < 32.0:
		_pick_a_heading()
	var wanted := (_target - position).normalized() * cruise_speed
	_velocity = _velocity.move_toward(wanted, steer * delta)
	position += _velocity * delta
	# Never out of its air: a gust of steering must not carry it through a wall or the floor.
	# The top is its nest's height when it is going home, which is above the air it wanders.
	position = Vector2(clampf(position.x, airspace.position.x, airspace.end.x),
		clampf(position.y, minf(airspace.position.y, _nest_here().y), airspace.end.y))
	if absf(_velocity.x) > 4.0:
		_facing = signf(_velocity.x)


func _pick_a_heading() -> void:
	_target = Vector2(_rng.randf_range(airspace.position.x, airspace.end.x),
		_rng.randf_range(airspace.position.y, airspace.end.y))


## Where its nest is now, in the parent's space -- or where it is, for a bird with none.
func _nest_here() -> Vector2:
	if not nest.is_valid():
		return position
	var at: Variant = nest.call()
	if not (at is Vector2):
		return position
	var parent := get_parent() as Node2D
	return parent.to_local(at as Vector2) if parent != null else at as Vector2


func _sit(delta: float) -> void:
	# Held to the string, which sways, so the bird rides it rather than hanging in the air
	# beside it.
	position = _nest_here()
	_flap += delta * 2.0
	if _clock >= _until:
		_state = State.FLYING
		_clock = 0.0
		_until = _rng.randf_range(flight_seconds.x, flight_seconds.y)
		_pick_a_heading()
		# Off the string downward and out, the way a bird drops off a wire.
		_velocity = Vector2(_rng.randf_range(-60.0, 60.0), 70.0)


# --- Fed ---------------------------------------------------------------------------------

## Fed. It flies down to `landing` (global) beside `food` (global) -- what was put out -- turns
## to it, and sets its piece down behind itself. With no landing, it settles straight down from
## where it is.
func calm(landing: Vector2 = Vector2.INF, food: Vector2 = Vector2.INF) -> bool:
	if is_answered():
		return false
	var parent := get_parent() as Node2D
	var local := parent.to_local(landing) if landing.is_finite() and parent != null \
		else position
	_landing = Vector2(local.x, floor_y - 6.0)
	_food_x = (parent.to_local(food) if parent != null else food).x if food.is_finite() else NAN
	_state = State.DESCENDING
	_clock = 0.0
	return true


func _descend(delta: float) -> void:
	_flap += delta * 13.0
	var to_go := _landing - position
	if to_go.length() <= DESCEND_SPEED * delta:
		position = _landing
		_velocity = Vector2.ZERO
		_state = State.CALMED
		if is_nan(_food_x):
			_let_go(_facing)
			return
		# ⚠ FACING THE FOOD, WITH THE PIECE BEHIND IT. A piece set down in front of a bird
		# eating was set down on the food -- and the food is solid, so a piece under the bread
		# could only be reached by climbing onto the bread. Found by the play bot.
		_facing = 1.0 if _food_x >= position.x else -1.0
		_let_go(-_facing)
		return
	_velocity = to_go.normalized() * DESCEND_SPEED
	position += _velocity * delta
	if absf(_velocity.x) > 4.0:
		_facing = signf(_velocity.x)


## Down on the floor with the scrap still in its beak: set it down on one side of itself, 1 for
## the way it is facing and -1 for behind it.
func _let_go(side: float) -> void:
	if not _holding:
		return
	_holding = false
	var parent := get_parent() as Node2D
	var local := Vector2(clampf(position.x + BESIDE * side, drop_span.x, drop_span.y), floor_y)
	scrap_dropped.emit(scrap_id, parent.to_global(local) if parent != null else local)


# --- Struck --------------------------------------------------------------------------------

## Hit. It tumbles to the floor, and the scrap is where it lands rather than on the bird.
func strike_down() -> bool:
	if not is_airborne():
		return false
	_state = State.FALLING
	_velocity = Vector2(_velocity.x * 0.3, -80.0)
	_spin = 0.0
	return true


func _fall(delta: float) -> void:
	_velocity.y += GRAVITY * delta
	position += _velocity * delta
	_spin += delta * 9.0
	# Not through a wall on the way down either.
	position.x = clampf(position.x, airspace.position.x, airspace.end.x)
	if position.y >= floor_y - 6.0:
		position.y = floor_y - 6.0
		_spin = 0.0
		_velocity = Vector2.ZERO
		_state = State.DOWNED
		_clock = 0.0
		_let_go(_facing)


func _daze(_delta: float) -> void:
	if _clock < DAZED_SECONDS:
		return
	# It shakes it off and goes: up and away, over whichever wall is nearer.
	_state = State.FLEEING
	_clock = 0.0
	_facing = 1.0 if position.x >= 0.0 else -1.0
	_velocity = Vector2(_facing * FLEE_SPEED * 0.6, -FLEE_SPEED)


# --- Scattered -----------------------------------------------------------------------------

## Its nest has come down. It bolts up and out of the alley, and the scrap it was holding
## flutters down to the floor on its own -- nothing is lost, it is only let go of.
func startle() -> bool:
	if not is_airborne():
		return false
	_state = State.FLEEING
	_clock = 0.0
	_facing = 1.0 if position.x >= 0.0 else -1.0
	_velocity = Vector2(_facing * FLEE_SPEED, -FLEE_SPEED * 0.6)
	if _holding:
		_holding = false
		_loose_scrap = position + Vector2(19.0 * _facing, 15.0)
		_loose_fall = 0.0
	return true


func _flee(delta: float) -> void:
	_flap += delta * 16.0
	position += _velocity * delta
	modulate.a = clampf(1.0 - _clock / LEAVING_SECONDS, 0.0, 1.0)
	if _clock >= LEAVING_SECONDS:
		_state = State.GONE


func _drop_the_loose_scrap(delta: float) -> void:
	_loose_fall += GRAVITY * 0.35 * delta
	_loose_scrap.y += _loose_fall * delta
	# A card flutters rather than falls straight -- and drifts in off a doorway on the way down,
	# so it does not land in one and then jump out of it.
	_loose_scrap.x += sin(_clock * 7.0) * 30.0 * delta
	_loose_scrap.x = move_toward(_loose_scrap.x,
		clampf(_loose_scrap.x, drop_span.x, drop_span.y), 90.0 * delta)
	if _loose_scrap.y < floor_y - PIECE_LIFT:
		return
	var local := Vector2(clampf(_loose_scrap.x, drop_span.x, drop_span.y), floor_y)
	_loose_scrap = Vector2.INF
	var parent := get_parent() as Node2D
	scrap_dropped.emit(scrap_id, parent.to_global(local) if parent != null else local)


## Put back to where a restore says it was: still up with its piece, or long gone with it
## handed over. Neither replays how it got there.
func restore_to(done: bool) -> void:
	_loose_scrap = Vector2.INF
	_food_x = NAN
	_spin = 0.0
	_clock = 0.0
	_velocity = Vector2.ZERO
	if done:
		_holding = false
		_state = State.GONE
		modulate.a = 0.0
		return
	_holding = true
	modulate.a = 1.0
	_state = State.FLYING
	_until = _rng.randf_range(flight_seconds.x * 0.3, flight_seconds.y)
	_pick_a_heading()
	position = Vector2(clampf(position.x, airspace.position.x, airspace.end.x),
		clampf(position.y, airspace.position.y, airspace.end.y))


# --- Drawing ---------------------------------------------------------------------------------

## ⚠ THESE HAD NO `_draw` AT ALL once, and nothing anywhere said so: five birds carrying five
## pieces, orbiting on a real physics process, invisible, with every headless check green.
func _draw() -> void:
	if _loose_scrap != Vector2.INF:
		draw_scrap(self, _loose_scrap - position)
	if _state == State.GONE:
		return
	var frame_name := _frame_now()
	# On the floor it does not tumble; in the air a struck bird spins as it falls.
	var spin := 0.0 if _state in [State.CALMED, State.DOWNED] else _spin
	draw_set_transform(Vector2.ZERO, spin, Vector2(_facing, 1.0))
	var cell: Dictionary = _cells.get(frame_name, {})
	if not cell.is_empty():
		draw_texture_rect_region(SHEET, Rect2(-_origin, _cell),
			Rect2(Vector2(float(cell["index"]) * _cell.x, 0.0), _cell))
		# ⚠ CARRIED, NOT WORN: hanging from the bill, in front of the bird.
		if _holding:
			draw_scrap(self, (cell["beak"] as Vector2) + HELD_BELOW_BILL)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Which frame it is showing: the stroke of its wings in the air, folded on the string with a
## blink now and then, and on the floor pecking where it was fed or flat where it was hit.
func _frame_now() -> String:
	match _state:
		State.PERCHED:
			return "blink" if fposmod(_flap, 7.0) < 0.3 else "perch"
		State.CALMED:
			return "peck" if sin(_flap) > 0.2 else "stand"
		State.DOWNED:
			return "dazed"
	return STROKE[int(fposmod(_flap, TAU) / TAU * float(STROKE.size())) % STROKE.size()]


static func _read_the_sheet() -> void:
	if not _cells.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not (parsed is Dictionary):
		push_warning("ScrapBird2D: no sheet manifest at %s" % MANIFEST)
		return
	var sheet := parsed as Dictionary
	_cell = Vector2(float(sheet["cell"][0]), float(sheet["cell"][1]))
	_origin = Vector2(float(sheet["origin"][0]), float(sheet["origin"][1]))
	for frame_name: String in (sheet["frames"] as Dictionary):
		var entry: Dictionary = sheet["frames"][frame_name]
		_cells[frame_name] = {"index": int(entry["index"]),
			"beak": Vector2(float(entry["beak"][0]), float(entry["beak"][1]))}


## A piece of the painting, drawn onto `canvas` at `at`: the card's top edge six above `at` and
## its foot eighteen below, as it always was -- the level lays its pieces on the floor by that.
## Static so the level's piece on the floor is the same picture the bird carried -- two drawings
## of one thing drift apart.
static func draw_scrap(canvas: CanvasItem, at: Vector2) -> void:
	canvas.draw_texture(SCRAP_ART, at + Vector2(-10.0, -6.0))
