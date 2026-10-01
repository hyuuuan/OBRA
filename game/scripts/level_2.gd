extends "res://scripts/level_base.gd"
## LEVEL 2 -- PIYESTA. The plaza, and the rules it arms over the whole of itself.
##
## Extended BY PATH rather than by `class_name LevelBase`, for the reason game_level.gd is:
## a `--script` run does not register class names and a dozen runners are exactly that.
##
## What this level adds to the machine that Payyo did not need:
##   * TWO RESTRICTIONS, armed for the level's whole length. See level_restrictions.gd for
##     why one refuses and the other punishes.
##   * A LEDGER, because the seven pieces of the painting are recovered across two screens.
##   * A CEILING THAT IS A PLACE. It is set per scene from the bandaritas' own Y, so the
##     boundary is the art rather than a HUD element, and it lifts when the line is cut.
##   * TWO ALLEYS THAT ARE ONE PROBLEM TWICE: a flock carrying pieces of the painting, nesting
##     in the bunting, and the same three ways to get them back -- see `_Alley`.

## WHERE THE ALLEYS' BUNTING HANGS, above the floor, and it is a measured number. Both alleys,
## because both are now the same problem: the flock nests in the line and the cut route climbs
## to it.
##
## The window is narrow and both walls of it are real. A player standing on a drawn primitive
## reaches 80 + 96 + 94.3 = 270 at the top of a jump (R4 and R1), so a line at or under that
## is not a Climb gate at all -- it is a hop. Standing on drawn stairs, which `climb`
## resolves to and which the design names outright, reaches 176 + 96 + 94.3 = 366; a ladder
## climbed reaches 340. So the line has to sit above 270 and below 340, and 320 is the
## middle of that with about fifty pixels of margin each way.
##
## ⚠ MOVING THIS BREAKS THE CUT ROUTE IN ONE DIRECTION OR THE OTHER, silently. Lower and the
## strings can be jumped at; higher and half of `climb`'s own answers cannot reach them.
## `run_level2_scene_probe` measures both walls, in both alleys.
##
## Alley 1's line used to sit at 380 with nothing on it: a flight cap and no more. A cap at 380
## was out of reach on purpose, and the strings the flock nests in cannot be.
const ALLEY_LINE := 320.0
## Where the flock flies, above an alley's floor: from a little over the apo's head to a little
## under the strings. Every bit of it is inside a throw -- see StoneThrow2D.reach.
const FLOCK_LOW := 120.0
const FLOCK_HIGH := 270.0
## How close the cutting edge has to be to the strings. From the floor, even jumping, the apo's
## hand is 150 short of them; from the top of drawn stairs it is 70.
const CUT_REACH := 110.0
## Walking this close to a piece of the painting on the floor picks it up -- and a piece comes
## to rest at least this far clear of anything solid the player set down, so there is somewhere
## to stand within reach of it.
const PIECE_REACH := 40.0
const PIECE_STANDOFF := 24.0
## How far inside an alley's doorways anything the player has to walk to comes to rest. See
## _between_the_doors.
const DOOR_CLEARANCE := 20.0
## How far clear of the offering's edge the nearest fed bird lands, how far apart the rest of
## the flock settles beside it, and how close they will crowd to keep to the apo's side of it.
## See _feed_the_flock.
const FEED_CLEARANCE := 40.0
const FEED_SPACING := 56.0
const FEED_CROWDED := 32.0

const RestrictionsClass = preload("res://scripts/level_restrictions.gd")
const LedgerClass = preload("res://scripts/scrap_ledger.gd")
const AssemblyClass = preload("res://scripts/scrap_assembly.gd")
const AssemblyOverlayClass = preload("res://scripts/assembly_overlay.gd")
const DanceClass = preload("res://scripts/dance_minigame.gd")
const DanceOverlayClass = preload("res://scripts/dance_overlay.gd")

## The canvas Level 1's Protector route creases. Read from the profile, drawn on the
## assembled picture, and changing nothing else -- see LEVEL_1.md, where the fact that this
## now costs nothing mechanical is recorded as a debt rather than as a design.
const CREASED_CANVAS := "canvas_2_pista"
## The dance is scored on timing, not on shape, so it never reaches the recogniser. A var
## rather than a const because GDScript will not fold a PackedFloat32Array into one -- and
## the track wants to be authored against the music anyway.
var dance_track := PackedFloat32Array([1.0, 2.0, 3.0, 4.0, 5.0, 6.0])

## The two entrances that go somewhere: the lit house and the church.
const DOOR_CHURCH := "church"
const DOOR_LIT_HOUSE := "lit_house"

var restrictions: LevelRestrictions
var ledger: ScrapLedger
var assembly: ScrapAssembly
## Scene 3's table. The model is the rule; this is where the pieces are put back.
var assembly_screen: AssemblyOverlay
var dance: DanceMinigame
## The screen the dance is played on. The model scores; this is what the player touches.
var dance_screen: DanceOverlay

## Where the bandaritas hang in the plaza, read off the scene rather than typed twice.
var _bunting_y := -INF
## How many times the flight ceiling has been crossed this run, so Lolo escalates rather
## than repeating himself. See _on_ceiling_crossed.
var _ceiling_crossings := 0

var church: PiyestaRoom2D
var house: PiyestaRoom2D
var alley_1: PiyestaRoom2D
var alley_2: PiyestaRoom2D
var _marks: Node2D
## door_id -> the door, and door_id -> the inside it opens onto.
var _doors: Dictionary = {}
var _door_rooms: Dictionary = {}
## Where the player was standing when they went in, by room name. REMEMBERED ON THE WAY IN
## rather than worked out on the way out, which is the shape Level 1 arrived at after the
## straw room put people back inside the mouth they had just walked out of.
var _step_back: Dictionary = {}
var _at_door: PiyestaDoor2D = null
## The scare warning currently on the hint bar, so walking away can take that and only that.
var _warning := ""
## Scene 2's furniture, built inside the church room.
var chancel: ChurchInterior2D
var _at_rack := false
## The bunting in each scene that has any, by room name. The ceiling is read off these.
var _lines: Dictionary = {}
## Which room the ceiling is currently set for, so it is changed when the answer changes
## rather than every frame. Same shape as `_refresh_room_framing`.
var _ceiling_for := "?"
var dancers: DancerGroup2D
## The two alleys, by the obstacle each one is: "L2_N2" and "L2_N3".
var _alleys: Dictionary = {}
## THREE FORKS NOW, and the base knows one. The plaza's is the scene's DialogueNode; each alley
## has its own. `dialogue_node` is pointed at whichever was approached last, and this says which
## beat it is answering for -- `_dialogue_node_obstacle_id()` is asked both when the choice is
## presented and when it is committed, and it must give the same answer to each.
var _live_node_obstacle := "L2_N1"
var _plaza_node: DialogueNode2D
## Where the last thing set down in an alley was put, for the flock to come down to, and how
## far it reaches either side of that. INF and 0 when the answer was a tool used in the hand.
var _feed_at := Vector2.INF
var _feed_half_width := 0.0
## Whether the kandila is in hand. LEVEL RUN STATE, not the profile: `has_object` is
## permanent by design, so recording it there would open every later run of Piyesta with the
## candle already found and the whole of Problem 1 already answered. Level 1 made exactly
## this mistake with the canvas in the bale.
var _has_kandila := false
## The candle on the table in the lit house, for pointing at.
var _kandila_prop: Kandila2D


# --- What this level answers ---------------------------------------------------------

func level_config_path() -> String:
	return "res://config/level_02.json"


func dialogue_path() -> String:
	return "res://config/dialogue_l2.json"


func _dialogue_node_obstacle_id() -> String:
	return _live_node_obstacle


func _resolve_level_nodes() -> void:
	dialogue_node = get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/DialogueNode") as DialogueNode2D
	_plaza_node = dialogue_node
	_marks = get_node_or_null(^"EnvironmentBaseplate/GameplayPlane/Marks") as Node2D
	var line := _mark("BuntingLine")
	if line != null:
		_bunting_y = line.global_position.y
	var rooms := ^"EnvironmentBaseplate/GameplayPlane/Rooms"
	church = get_node_or_null(rooms.get_concatenated_names() + "/ChurchInterior") as PiyestaRoom2D
	house = get_node_or_null(rooms.get_concatenated_names() + "/HouseInterior") as PiyestaRoom2D
	alley_1 = get_node_or_null(rooms.get_concatenated_names() + "/Alley1") as PiyestaRoom2D
	alley_2 = get_node_or_null(rooms.get_concatenated_names() + "/Alley2") as PiyestaRoom2D


func _mark(mark_name: String) -> Node2D:
	return _marks.get_node_or_null(NodePath(mark_name)) as Node2D if _marks != null else null


func _build_level_furniture() -> void:
	restrictions = RestrictionsClass.new()
	restrictions.name = "LevelRestrictions"
	add_child(restrictions)
	var problems: Array = restrictions.load_from(
		director.level_data(), _roster_ids())
	for problem: Variant in problems:
		# LOUD AT STARTUP, never quiet at runtime: a rule that bans nothing is worse than
		# no rule, because the level goes on claiming to have one.
		push_error("Level2: %s" % problem)
	restrictions.submission_refused.connect(_on_submission_refused)
	# ⚠ AND THE DIRECTOR IS TOLD, so the level stops OFFERING what it will refuse. `climb`
	# resolves spider, spider is banned here, and `clue_class` prefers a class the player has
	# already drawn -- so a player arriving from Payyo, where a spider is how you climb, gets
	# a third clue naming the one animal this plaza will not take.
	if director != null:
		director.set_refusal_filter(restrictions.refuses)
	restrictions.ceiling_crossed.connect(_on_ceiling_crossed)
	# The plaza's own line. Each later scene sets its own; a scene with no bandaritas
	# leaves it at -INF and the rule stands down there.
	restrictions.set_ceiling(_bunting_y + 20.0 if _bunting_y != -INF else -INF)

	ledger = LedgerClass.new()
	ledger.name = "ScrapLedger"
	add_child(ledger)
	ledger.reset()
	# THE OBJECTIVE READOUT, and Piyesta had none. The corner said "GOAL 300 m" and counted
	# down to a marker parked past the east wall of Alley 2 -- inherited, because level_2.tscn
	# is a text copy of game_level.tscn -- which is not how this level ends and not anywhere
	# the player is meant to walk. The marker is gone; what the corner counts now is the only
	# number that means anything here, which is how much of her painting is in hand.
	# ⚠ unbind(3), NOT unbind(1). `scrap_recovered` carries (scrap_id, held, total) and
	# `_show_the_count` takes none, so the callable has to drop all three. With one dropped it
	# still expected two, and a signal-argument mismatch in GDScript is a RUNTIME error at
	# emit -- so the readout printed 0 / 7 on the frame the level opened and never moved
	# again, while the ledger climbed to seven behind it. Nothing failed; a line went to
	# stderr and the corner lied for the whole level.
	ledger.scrap_recovered.connect(_show_the_count.unbind(3))
	_show_the_count()

	assembly = AssemblyClass.new()
	assembly.name = "ScrapAssembly"
	add_child(assembly)
	# ⚠ THE CREASE IS ON THE PLAZA, NOT ON THE TABLE. Payyo's Protector route creased the
	# canvas it cut out of Lola's chest -- canvas_2_pista, THIS plaza -- and the design's own
	# first wording is "a visible crease on the painting's background". It sat on the table
	# while the table assembled the plaza; the table assembles the sea now (see build_scraps),
	# which is a different canvas and was never folded. So the fold runs through the plaza the
	# player is walking in, and the table's picture is whole.
	var creased := PlayerProfile.is_canvas_damaged(CREASED_CANVAS)
	if creased:
		_crease_the_plaza()
	# ⚠ AND THE SCRIPT HAS TO KNOW TOO. The crease was on the PROFILE and nothing set the flag,
	# so Lolo's line about it waited on a flag nothing in this level ever set, and could not
	# fire for anybody. That line is the entire payoff of Payyo's Protector route, the one
	# LEVEL_1.md carries as a debt because it "costs nothing mechanical". It costs this.
	if creased and script_lines != null:
		script_lines.set_flag("canvas_2_creased")
	assembly_screen = AssemblyOverlayClass.new()
	assembly_screen.name = "AssemblyOverlay"
	add_child(assembly_screen)
	assembly_screen.bind(assembly)
	assembly_screen.assembly_done.connect(_on_assembly_done)

	dance = DanceClass.new()
	dance.name = "DanceMinigame"
	add_child(dance)
	dance.set_track(dance_track)
	dance.finished.connect(_on_dance_finished)
	_build_the_dance_screen()

	_build_the_doors()
	_wire_the_rooms()
	_put_the_kandila_in_the_house()
	_furnish_the_church()
	_bring_out_the_dancers()
	_build_the_alleys()


## Where the fold runs, in world x at the top of the painting, and how far it has wandered by
## the bottom: between the palm arch and the church, where the plaza is walked through, and a
## little off vertical, because a fold somebody made in a hurry is not a plumb line.
const CREASE_X := 1110.0
const CREASE_LEAN := 46.0


## The fold, drawn ON the painted plaza from the top of the painting to its ground line.
##
## ⚠ OVER THE PAINTED FRONTS, UNDER THE PEOPLE. The first cut was a child of the backdrop, and
## the church and the lit house are their own plates standing in front of it -- so the fold ran
## down the sky and stopped at the first roof, and read as a wire. The fronts are part of the
## same painting, so the fold goes over them (it is added after them at their z) and under
## anybody alive standing in the plaza. The backdrop is placed so world x is plate x (see
## _build_the_doors), which is what makes CREASE_X a place.
func _crease_the_plaza() -> void:
	var backdrop := get_node_or_null(^"EnvironmentBaseplate/PlazaBackdrop") as Sprite2D
	var plane := get_node_or_null(^"EnvironmentBaseplate/GameplayPlane") as Node2D
	if backdrop == null or backdrop.texture == null or plane == null:
		return
	var height := float(backdrop.texture.get_height())
	var top_y := backdrop.global_position.y - (height * 0.5 if backdrop.centered else 0.0)
	var fold := _CanvasFold.new()
	fold.name = "Crease"
	fold.z_index = -1
	fold.top = Vector2(CREASE_X, top_y)
	fold.bottom = Vector2(CREASE_X + CREASE_LEAN, top_y + height)
	plane.add_child(fold)


## Where Level 1's Protector route cut the canvas open. Paper, not ink: a crease is a soft
## shadow falling away on one side of the fold, a dark crease line, a narrow lit ridge beside it
## and a faint lift of light on the far side.
class _CanvasFold extends Node2D:
	const SHADE := Color(0.086, 0.075, 0.059, 0.11)
	const DARK := Color(0.086, 0.075, 0.059, 0.66)
	const LIT := Color(1.0, 0.976, 0.902, 0.58)
	const LIFT := Color(1.0, 0.976, 0.902, 0.08)
	var top := Vector2.ZERO
	var bottom := Vector2.ZERO

	func _draw() -> void:
		draw_line(top + Vector2(-15.0, 0.0), bottom + Vector2(-15.0, 0.0), SHADE, 26.0)
		# The crease itself: crisp, because a fold is a line and a soft one reads as a sunbeam.
		draw_line(top, bottom, DARK, 3.0)
		draw_line(top + Vector2(3.0, 0.0), bottom + Vector2(3.0, 0.0), LIT, 3.0)
		draw_line(top + Vector2(12.0, 0.0), bottom + Vector2(12.0, 0.0), LIFT, 14.0)


func _roster_ids() -> PackedStringArray:
	var out := PackedStringArray()
	if registry == null:
		return out
	for id: Variant in registry.get_entity_ids():
		out.append(String(id))
	return out


# --- The plaza's doors, and the insides behind two of them ---------------------------

## TWO DOORS ON THE PLAZA. Both open onto rooms once their route has made them available.
##
## Built here rather than authored into the scene because they stand ON the marks, and the
## marks are what the scene probe measures against the plaza floor. Two sources for one
## position is one of them going stale.
func _build_the_doors() -> void:
	# ⚠ `tone` IS SAMPLED OFF THE PAINTING, at each door's own x. The plaza backdrop is placed
	# so that world x is plate x, so these are medians of the plate under each mark, taken over
	# the door's own height. See `PiyestaDoor2D.wall_tone`.
	var plan: Array[Dictionary] = [
		{"id": DOOR_LIT_HOUSE, "mark": "LitHouse", "lit": true, "room": house,
			"hut": true,
			"tone": Color(0.749, 0.557, 0.380), # BF8E61, the sunlit house front
			"shut": "There is a light on in there, and it will not open.",
			"open": "It is open now."},
		{"id": DOOR_CHURCH, "mark": "ChurchDoor", "lit": false, "room": church,
			"tone": Color(0.624, 0.427, 0.188), # 9F6D30
			"shut": "The church. Lolo will not go in without a candle.",
			"open": "The church."},
	]
	for entry in plan:
		var mark := _mark(String(entry["mark"]))
		if mark == null:
			push_error("Level2: no mark for door %s" % entry["id"])
			continue
		var door := PiyestaDoor2D.new()
		door.name = "Door_%s" % entry["id"]
		door.door_id = String(entry["id"])
		door.lit = bool(entry["lit"])
		door.style = PiyestaDoor2D.Style.CHURCH if entry["id"] == DOOR_CHURCH \
			else PiyestaDoor2D.Style.HOUSE
		door.use_hut_art = bool(entry.get("hut", false))
		# The supplied plates are buildings behind the people and portable props in the street.
		# Keeping them one layer back lets figures cross their fronts instead of being cut out.
		door.z_index = -1 if door.use_hut_art or door.style == PiyestaDoor2D.Style.CHURCH else 0
		door.wall_tone = Color(entry["tone"])
		door.shut_note = String(entry["shut"])
		door.open_note = "%s  —  press %s" % [
			entry.get("open", ""), ControlsKeys.keys_for("interact")]
		door.global_position = mark.global_position
		mark.add_child(door)
		door.global_position = mark.global_position
		door.at_door.connect(_on_at_door.bind(door))
		_doors[door.door_id] = door
		if entry["room"] != null:
			_door_rooms[door.door_id] = entry["room"]


## Both signals off every room, in one place. A room that is entered and never wired is a
## room with no way out, and the failure only shows up once somebody is standing in it.
func _wire_the_rooms() -> void:
	for room: PiyestaRoom2D in [church, house, alley_1, alley_2]:
		if room == null:
			continue
		room.exit_reached.connect(_leave_room.bind(room))
		room.onward_reached.connect(_go_onward.bind(room))
		room.noticed.connect(_on_room_notice)
		room.notice_left.connect(_on_room_notice_left)


## The candle Path C is for. It is IN THE ROOM rather than granted on the route commit,
## because committing that route means the key worked and nothing more -- see kandila_2d.gd.
func _put_the_kandila_in_the_house() -> void:
	if house == null:
		return
	var candle := Kandila2D.new()
	candle.name = "Kandila"
	house.add_child(candle)
	# At the far end, so the room is walked rather than glanced into. The apo lands beside
	# the door and the table is the other thing in the room.
	candle.position = Vector2(house.room_length * 0.3, 0.0)
	candle.taken.connect(_on_kandila_taken)
	_kandila_prop = candle


## Scene 2. The nave gets its furniture from the room it is in, so the pews cannot outgrow
## the church and the rack cannot end up outside it.
func _furnish_the_church() -> void:
	if church == null:
		return
	chancel = ChurchInterior2D.new()
	chancel.name = "Chancel"
	chancel.nave_length = church.room_length
	chancel.nave_height = church.wall_height
	church.add_child(chancel)
	chancel.at_rack.connect(_on_at_rack)
	chancel.kandila_placed.connect(_on_kandila_placed)
	chancel.priest_arrived.connect(_on_priest_arrived)


## THE SCREEN, AND THE ONE THING THAT OPENS IT.
##
## The dance is answered on COMMIT rather than on solve, and that is the whole reason this
## needed its own wiring. Every other route in the game is solved by a drawing the recogniser
## accepted, so `_on_route_solved` is where a level acts. This route has no `required_tags`
## at all -- it declares `answered_by: dance_minigame` -- so nothing was ever going to solve
## it, and committing it closed the other two and left the player standing there.
func _build_the_dance_screen() -> void:
	dance_screen = DanceOverlayClass.new()
	dance_screen.name = "DanceOverlay"
	add_child(dance_screen)
	dance_screen.bind(dance)
	dance_screen.run_finished.connect(_on_dance_screen_finished)
	dance_screen.attempt_lost.connect(_on_dance_attempt_lost)
	if director != null:
		director.route_committed.connect(_on_route_committed_here)


func _on_route_committed_here(obstacle_id: String, route: String) -> void:
	if obstacle_id != "L2_N1" or route != "artist" or dance_screen == null:
		return
	# FIRST THE DANCERS, THEN THE PUZZLE. Restart their authored three-frame phrase and wait
	# on the animation's own clock. A detached timer could expire while the world was paused,
	# opening a rhythm lane over a dance the player never got to see.
	if dancers != null and not dancers.are_gone():
		dancers.begin_puzzle_lead_in()
		await dancers.puzzle_lead_in_finished
	else:
		# Defensive only: route exclusivity means the Artist choice cannot normally coexist
		# with a scattered troupe, but a probe or restored developer state must not deadlock.
		await get_tree().create_timer(DancerGroup2D.PUZZLE_LEAD_IN, false, false, true).timeout
	if dance_screen != null and is_instance_valid(dance_screen):
		dance_screen.present()


## THE PERFORMANCE IS OVER, whichever way it went.
##
## `solve_with_item` rather than a submission, and the director already has that door: it
## records no attempt, no tag match and no hint tier, "because neither happened". A dance is
## not a drawing, and pushing it through `note_submission` would put a class nobody drew into
## this level's per-class statistics -- which is exactly the reporting rule the thesis is
## built on. The item is the dance itself.
func _on_dance_screen_finished(_cleared: bool, _flower: bool) -> void:
	# The flower and the telemetry were already recorded by `_on_dance_finished`, off the
	# model's own signal, so nothing about the outcome is decided twice.
	if director != null and not director.is_solved("L2_N1"):
		director.solve_with_item("L2_N1", "dance")


## Between the two goes. The design asks for Lolo to TEASE rather than instruct -- same
## register as the restriction dialogue, he is enjoying this -- so the line is authored in
## dialogue_l2.json and not written on the screen.
func _on_dance_attempt_lost(_attempts_used: int) -> void:
	_speak(script_lines.fire("L2_N1.artist.retry"))


## The dancers, on their mark. They are the plaza's whole reason for being full, and the one
## thing in this level the player can take away from it permanently.
func _bring_out_the_dancers() -> void:
	var mark := _mark("DancersMark")
	if mark == null:
		push_error("Level2: no DancersMark to stand the dancers on")
		return
	dancers = DancerGroup2D.new()
	dancers.name = "Dancers"
	mark.add_child(dancers)
	dancers.noticed.connect(_on_dancers_noticed)
	dancers.notice_left.connect(_on_dancers_notice_left)
	dancers.scattered.connect(_on_dancers_scattered)


## The irreversibility, said while the player can still walk away. The design asks for the
## signal to arrive BEFORE the commit, and this fires off the dancers' own approach volume
## rather than off the choice screen -- so it is said about the people it is about, while the
## player is looking at them.
func _on_dancers_noticed(_text: String) -> void:
	var lines := script_lines.fire("L2_N1.protector.warn")
	# Remember which of them is the HINT, because that is the one that lands on the bar and
	# the one walking away should take back down. The rest is a story beat and dismisses
	# itself.
	_warning = ""
	for line_value: Variant in lines:
		var line: Dictionary = line_value
		if script_lines.kind_of(line) == "hint":
			_warning = script_lines.display_text(line)
	_speak(lines)


## ⚠ THE GROUP HAS ALWAYS EMITTED THIS AND NOTHING HAS EVER LISTENED. The warning is about
## standing near them -- "if you do this they will not come back" -- so a player who thought
## better of it and walked away was still being told the price of a thing they were no longer
## about to do. Cleared only if the bar is still saying it, because one channel carries
## several voices and taking down somebody else's message is worse than leaving this one up.
func _on_dancers_notice_left() -> void:
	if hint_bar == null or _warning.is_empty():
		return
	if hint_bar.current_text() == _warning:
		hint_bar.clear()
	_warning = ""


## They are gone. Nothing in the level is harder for it -- the cost is entirely that Lolo
## brought the player here to see this and it is not here any more.
func _on_dancers_scattered() -> void:
	script_lines.set_flag("dancers_gone")
	_speak(script_lines.fire("L2_N1.protector.solved"))


# --- The alleys: a flock each, and three ways to get the pieces back ------------------

## ONE ALLEY, and everything in it that Problem 2 or Problem 3 is about. Both alleys are built
## from this because they are one problem twice -- Kent asked for the same three choices "in
## the two areas where the player needs to collect the parts of the painting": feed the flock
## down, climb to the strings and cut the nests down, or throw at them.
class _Alley extends RefCounted:
	## The obstacle this alley is, and the room it is in.
	var obstacle_id := ""
	var room: PiyestaRoom2D
	## The bunting: the flight cap, where the flock nests, and what the cut route brings down.
	var line: BandaritaLine2D
	var birds: Array[ScrapBird2D] = []
	var thrower: StoneThrow2D
	## The choice, asked out loud at the way in.
	var fork: DialogueNode2D
	## The pieces this alley's flock carries, one per bird.
	var scraps := PackedStringArray()
	## The checkpoint the route commit writes, written again once every piece is in hand.
	var checkpoint_id := ""
	## Lolo's line once the climb half of the cut route is done.
	var climbed_hook := ""
	## Pieces lying on the floor waiting to be walked over, by scrap id.
	var pieces: Dictionary = {}
	## Every piece that has come down, picked up or not.
	var dropped: Dictionary = {}
	## The drawn tools thrown here, spent once the flock is down.
	var thrown_with: Dictionary = {}

	func has_everything(held: ScrapLedger) -> bool:
		for scrap_id in scraps:
			if not held.has(scrap_id):
				return false
		return true

	## Every bird has taken one of the three ways down.
	func flock_is_down() -> bool:
		for bird in birds:
			if not bird.is_answered():
				return false
		return true


## A piece of the painting lying on an alley's floor, waiting to be walked over. Drawn with the
## bird's own picture of it, lifting a little off the setts every second or so, because a thing
## worth walking over has to be found by a player scanning a dark floor.
class _FloorPiece extends Node2D:
	var scrap_id := ""
	## Where it is sliding to, out from under something solid it came down on (global x).
	var slide_to := NAN
	var _clock := 0.0

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		z_index = 1

	func _process(delta: float) -> void:
		_clock += delta
		if not is_nan(slide_to):
			global_position.x = move_toward(global_position.x, slide_to, 260.0 * delta)
		queue_redraw()

	func _draw() -> void:
		var lift := maxf(0.0, sin(_clock * 3.0)) * 3.0
		ScrapBird2D.draw_scrap(self, Vector2(0.0, -ScrapBird2D.PIECE_LIFT - lift))


## BOTH ALLEYS, built the same way: the bunting, the flock nesting in it, the throw, and the
## fork at the way in. The pieces are named here, and `tools/build_scraps.py` writes the same
## names into the table's manifest -- `run_assembly_probe` holds the two together.
func _build_the_alleys() -> void:
	var plan: Array = [
		[alley_1, "L2_N2", "alley1", ScrapLedger.IN_ALLEY_1, "L2_N2.pragmatist.climbed"],
		[alley_2, "L2_N3", "alley2", ScrapLedger.IN_ALLEY_2, "L2_N3.pragmatist.climbed"],
	]
	for entry: Array in plan:
		var room := entry[0] as PiyestaRoom2D
		if room == null:
			continue
		var alley := _Alley.new()
		alley.obstacle_id = String(entry[1])
		alley.room = room
		alley.climbed_hook = String(entry[4])
		if director != null:
			alley.checkpoint_id = String(
				director.obstacle(alley.obstacle_id).get("checkpoint_on_commit", ""))
		for index in range(int(entry[3])):
			alley.scraps.append("%s_%d" % [entry[2], index])
		_string_the_bunting(alley)
		_release_the_flock(alley)
		_ready_the_throw(alley)
		_plant_the_fork(alley)
		_alleys[alley.obstacle_id] = alley


## THE BUNTING. Each line owns its own Y and the flight rule reads the ceiling off it, which is
## what makes the boundary the art rather than a number. A nest for every bird.
func _string_the_bunting(alley: _Alley) -> void:
	var line := BandaritaLine2D.new()
	line.name = "Bandaritas"
	line.span = alley.room.room_length - 120.0
	line.nest_count = alley.scraps.size()
	line.position = Vector2(0.0, -ALLEY_LINE)
	alley.room.add_child(line)
	alley.line = line
	_lines[alley.room.name] = line


## One bird per piece, individually addressable: the design's outcome is per bird, which is
## only true if there are birds rather than a number. They start spread through the alley's air
## and find their own way home to the strings.
func _release_the_flock(alley: _Alley) -> void:
	var half := alley.room.room_length * 0.5 - 70.0
	var count := alley.scraps.size()
	for index in range(count):
		var bird := ScrapBird2D.new()
		bird.name = "Bird%d" % index
		bird.scrap_id = alley.scraps[index]
		bird.airspace = Rect2(-half, -FLOCK_HIGH, half * 2.0, FLOCK_HIGH - FLOCK_LOW)
		bird.drop_span = _between_the_doors(alley.room)
		bird.nest = alley.line.nest_point.bind(index)
		bird.position = Vector2(lerpf(-half, half, (float(index) + 0.5) / float(count)),
			-lerpf(FLOCK_LOW, FLOCK_HIGH, 0.35 + 0.3 * float(index % 2)))
		alley.room.add_child(bird)
		bird.scrap_dropped.connect(_on_scrap_dropped.bind(alley.obstacle_id))
		alley.birds.append(bird)


## What the Protector route throws with. It is told every frame what is in the player's hand
## (see _tend_the_alleys) and owns the stone, the arc and whatever is in the air.
func _ready_the_throw(alley: _Alley) -> void:
	var thrower := StoneThrow2D.new()
	thrower.name = "Throw"
	alley.room.add_child(thrower)
	var half := alley.room.room_length * 0.5
	thrower.floor_y = alley.room.global_position.y
	thrower.walls = Vector2(alley.room.global_position.x - half,
		alley.room.global_position.x + half)
	var clear := _between_the_doors(alley.room)
	thrower.rest_span = Vector2(alley.room.global_position.x + clear.x,
		alley.room.global_position.x + clear.y)
	thrower.hand = _throwing_hand
	var flock := alley.birds
	thrower.targets = func() -> Array: return flock
	alley.thrower = thrower


## THE CHOICE, ASKED AT THE WAY IN. The apo is put down inside this when they walk into the
## alley, so the three ways are offered as soon as Lolo has seen the flock -- before there is
## anything to draw at, which is what keeps a drawing from being judged against no route.
func _plant_the_fork(alley: _Alley) -> void:
	var fork := DialogueNode2D.new()
	fork.name = "Fork"
	fork.level_id = "level_2"
	fork.trigger_size = Vector2(160.0, 360.0)
	fork.position = Vector2(alley.room.entry_point().x - alley.room.global_position.x + 30.0, 0.0)
	alley.room.add_child(fork)
	alley.fork = fork


## THREE FORKS. `super()` still owns the overlay, the memory screen and the plaza's
## `route_chosen`; this re-routes the plaza's approach so it says which beat is being asked,
## and wires the two in the alleys the same way.
func _wire_dialogue_node() -> void:
	super()
	if _plaza_node != null \
			and _plaza_node.approached.is_connected(_on_dialogue_node_approached):
		_plaza_node.approached.disconnect(_on_dialogue_node_approached)
		_plaza_node.approached.connect(_on_fork_approached.bind(_plaza_node, "L2_N1"))
	for alley: _Alley in _alleys.values():
		alley.fork.approached.connect(_on_fork_approached.bind(alley.fork, alley.obstacle_id))
		alley.fork.route_chosen.connect(_on_route_chosen)


## A FORK IS APPROACHED. The base's handler reads `dialogue_node` and
## `_dialogue_node_obstacle_id()`, so both are pointed at this one before it runs.
func _on_fork_approached(fork: DialogueNode2D, obstacle_id: String) -> void:
	if director == null or not director.committed_route(obstacle_id).is_empty():
		return
	_live_node_obstacle = obstacle_id
	dialogue_node = fork
	if _alleys.has(obstacle_id):
		# THE FLOCK IS SEEN BEFORE ITS ANSWERS ARE OFFERED. The fork and the alley's own volume
		# are entered on the frame the apo is put down in the alley, in whichever order the
		# physics server reports them. So the beat is entered here -- which is what teaches its
		# four verbs -- and Lolo's arrival is said first, and the choice waits for him.
		director.enter_obstacle(obstacle_id)
		_speak_on_arrival("%s.enter" % obstacle_id)
	# The choice after the conversation that sets it up, never over it.
	if dialogue_box != null and dialogue_box.is_open():
		if not dialogue_box.conversation_finished.is_connected(_on_dialogue_node_approached):
			dialogue_box.conversation_finished.connect(_on_dialogue_node_approached,
				CONNECT_ONE_SHOT)
		return
	_on_dialogue_node_approached()


## Asked again, for an alley whose choice somehow has not been made. See _extra_refusals.
func _ask_at(alley: _Alley) -> void:
	if alley.fork == null or alley.fork.is_answered():
		return
	if dialogue_overlay != null and bool(dialogue_overlay.call("is_open")):
		return
	_on_fork_approached(alley.fork, alley.obstacle_id)


## THE FLOOR BETWEEN AN ALLEY'S TWO DOORWAYS, in the room's own x. Everything the player has to
## walk over -- a piece of the painting, the stone they threw -- comes to rest inside this.
##
## ⚠ FOUND BY PLAYING IT. Fed beside something set down near the way in, the flock landed by the
## wall and left two pieces lying in the doorway. Walking in to pick them up walked the apo back
## out into the church, and the pieces were still in the doorway when they came back.
func _between_the_doors(room: PiyestaRoom2D) -> Vector2:
	return Vector2(room.exit_rect().end.x + DOOR_CLEARANCE,
		room.onward_rect().position.x - DOOR_CLEARANCE)


## The alley holding the player, or null out on the plaza or in another room.
func _alley_holding_player() -> _Alley:
	return _alley_in(_room_holding_player())


func _alley_in(room: Node2D) -> _Alley:
	if room == null:
		return null
	for alley: _Alley in _alleys.values():
		if alley.room == room:
			return alley
	return null


## The alley whose beat the director is judging against, or null.
func _alley_at_beat() -> _Alley:
	if director == null:
		return null
	return _alleys.get(director.current_obstacle()) as _Alley


## Whether this alley's flock is being thrown at: the throwing route chosen, and a bird still up.
func _throwing_at(alley: _Alley) -> bool:
	return alley != null and director != null \
		and director.committed_route(alley.obstacle_id) == "protector" \
		and not director.is_solved(alley.obstacle_id) and not alley.flock_is_down()


## Halfway up the cut route: the climb is done and the strings are the next thing.
func _cutting_at(alley: _Alley) -> bool:
	return alley != null and director != null \
		and director.committed_route(alley.obstacle_id) == "pragmatist" \
		and director.stage(alley.obstacle_id) > 0 and not director.is_solved(alley.obstacle_id)


## The drawn tool in the player's hand, if it is one that is thrown from it.
func _held_throwable() -> UtilityObject:
	if _equipped_utility == null or not is_instance_valid(_equipped_utility) \
			or _equipped_utility.item_data == null:
		return null
	var kind := int(StoneThrow2D.THROWN.get(_equipped_utility.item_data.entity_id,
		StoneThrow2D.Kind.NONE))
	if kind == StoneThrow2D.Kind.BOOMERANG or kind == StoneThrow2D.Kind.CANNON:
		return _equipped_utility
	return null


func _has_a_throwable_in_the_bag() -> bool:
	for value: Variant in inventory_manager.items():
		var item := value as DrawnItemData
		if item == null:
			continue
		var kind := int(StoneThrow2D.THROWN.get(item.entity_id, StoneThrow2D.Kind.NONE))
		if kind == StoneThrow2D.Kind.BOOMERANG or kind == StoneThrow2D.Kind.CANNON:
			return true
	return false


## Where a throw leaves from: the tool itself when one is held, and otherwise the apo's own
## hand -- the grip a tool would be in, on the side they are facing.
func _throwing_hand() -> Vector2:
	if player == null or not is_instance_valid(player):
		return Vector2.INF
	var tool := _held_throwable()
	if tool != null:
		return tool.global_position
	var facing := float(player.call("facing_direction")) \
		if player.has_method("facing_direction") else 1.0
	return _player_anchor_position() + Vector2(14.0 * facing, -StoneThrow2D.HAND_HEIGHT)


## Whether the held boomerang was hidden for being in the air, so it is shown again only if this
## is what hid it.
var _hid_the_throwable := false


## THE ALLEYS, EVERY FRAME: what is in the hand to throw, and the pieces lying within reach.
func _tend_the_alleys() -> void:
	var here := _alley_holding_player()
	var tool := _held_throwable()
	var hide_it := false
	for alley: _Alley in _alleys.values():
		var kind := StoneThrow2D.Kind.NONE
		if alley == here and _throwing_at(alley):
			if tool != null:
				kind = int(StoneThrow2D.THROWN[tool.item_data.entity_id])
				# The boomerang in the hand IS the one in the air, so it is not in the hand
				# while it flies.
				hide_it = kind == StoneThrow2D.Kind.BOOMERANG \
					and alley.thrower.in_flight(StoneThrow2D.Kind.BOOMERANG)
			elif alley.thrower.has_stone():
				kind = StoneThrow2D.Kind.STONE
		alley.thrower.hold(kind)
	if tool != null and hide_it:
		tool.visible = false
		_hid_the_throwable = true
	elif tool != null and _hid_the_throwable:
		tool.visible = true
		_hid_the_throwable = false
	if here != null:
		_pick_up_the_pieces(here)
		_say_what_is_in_the_way(here)


## Which alleys have already said that a drawing is in the way, so it is said once.
var _said_in_the_way: Dictionary = {}


## A DRAWING STANDING IN THE WAY ON, said once, when the apo reaches it. A ladder stood in the
## middle of an alley to cut the strings is solid until it is climbed, and the way on is past
## it. Climbing over it works, and E takes it back -- and nothing said either. Found by the play
## bot, stopped at the foot of the ladder with the way on open behind it.
func _say_what_is_in_the_way(alley: _Alley) -> void:
	if not alley.room.onward_open or _said_in_the_way.has(alley.obstacle_id):
		return
	var near := _nearest_interactable_utility()
	if near == null:
		return
	var me := _player_anchor_position().x
	var way_on := alley.room.global_position.x + alley.room.onward_rect().get_center().x
	var extent := near.world_extent()
	if extent.end.x <= minf(me, way_on) or extent.position.x >= maxf(me, way_on):
		return
	_said_in_the_way[alley.obstacle_id] = true
	var climbable := near is UtilityObject and (near as UtilityObject).can_be_climbed()
	_say_why("Your %s is in the way -- %spress %s to take it back." % [
		_drawing_display_name(near).to_lower(), "climb over it, or " if climbable else "",
		ControlsKeys.key_cap_for("interact")])


## Walking over a piece picks it up. The corner counts it, and once every piece in the alley is
## in hand the way on opens.
func _pick_up_the_pieces(alley: _Alley) -> void:
	if ledger == null:
		return
	var at := _player_anchor_position()
	for scrap_id: String in alley.pieces.keys():
		var piece := alley.pieces[scrap_id] as Node2D
		if piece == null or not is_instance_valid(piece):
			alley.pieces.erase(scrap_id)
			continue
		if absf(piece.global_position.x - at.x) > PIECE_REACH \
				or absf(piece.global_position.y - at.y) > 110.0:
			continue
		alley.pieces.erase(scrap_id)
		piece.queue_free()
		ledger.recover(scrap_id)
	if not alley.room.onward_open and alley.has_everything(ledger):
		_the_alley_is_done(alley)


## Every piece from here is in hand. The way on opens, and the checkpoint is written again, so
## nothing a restore does can put a piece back in a beak.
func _the_alley_is_done(alley: _Alley) -> void:
	alley.thrower.clear()
	alley.room.open_onward()
	if not alley.checkpoint_id.is_empty():
		_write_checkpoint(alley.checkpoint_id)
	_say_why("That is all of her from here. The way on is open.")


## A piece is on the floor. It is laid out where it fell for the player to walk over, and on the
## Protector route the last one coming down is what answers the beat.
func _on_scrap_dropped(scrap_id: String, at: Vector2, obstacle_id: String) -> void:
	var alley := _alleys.get(obstacle_id) as _Alley
	if alley == null:
		return
	alley.dropped[scrap_id] = true
	if ledger != null and not ledger.has(scrap_id) and not alley.pieces.has(scrap_id):
		var piece := _FloorPiece.new()
		piece.name = "Piece_%s" % scrap_id
		piece.scrap_id = scrap_id
		alley.room.add_child(piece)
		var clear := _between_the_doors(alley.room)
		var x := clampf(at.x, alley.room.global_position.x + clear.x,
			alley.room.global_position.x + clear.y)
		piece.global_position = Vector2(x, alley.room.global_position.y)
		piece.slide_to = _clear_of_drawings(alley, x)
		alley.pieces[scrap_id] = piece
	if director != null and director.committed_route(obstacle_id) == "protector" \
			and not director.is_solved(obstacle_id) \
			and alley.dropped.size() >= alley.scraps.size():
		director.solve_with_item(obstacle_id, "thrown")


## THE NEAREST FLOOR TO `x` THAT NOTHING SOLID STANDS ON, in this alley -- so a piece that comes
## down at the foot of the ladder the strings were cut from slides out from under it.
##
## ⚠ FOUND BY THE PLAY BOT. A drawing set down is solid until it is climbed, and a piece that
## landed under the ladder lay 40.4px from the nearest place the apo could stand, with the reach
## 40. A player could take the ladder back with E; nobody should have to. Clear by enough to
## stand beside the thing and reach it.
func _clear_of_drawings(alley: _Alley, x: float) -> float:
	var clear := _between_the_doors(alley.room)
	var left := alley.room.global_position.x + clear.x
	var right := alley.room.global_position.x + clear.y
	var floor_y := alley.room.global_position.y
	var standing: Array[Rect2] = []
	for child in world_item_root.get_children():
		var drawn := child as PhysicsShapeObject
		if drawn == null or drawn.is_preview:
			continue
		var extent := drawn.world_extent()
		# On this alley's floor: both alleys share their x, and the other one is not in the way.
		if extent.end.y < floor_y - 40.0 or extent.position.y > floor_y + 10.0:
			continue
		standing.append(Rect2(extent.position.x - PIECE_STANDOFF, 0.0,
			extent.size.x + PIECE_STANDOFF * 2.0, 1.0))
	var blocked := func(at: float) -> bool:
		for box: Rect2 in standing:
			if at > box.position.x and at < box.end.x:
				return true
		return false
	if not bool(blocked.call(x)):
		return x
	# Outward a step at a time, both ways, and the nearer clear floor wins.
	for step in range(1, 120):
		for side: float in [-1.0, 1.0]:
			var at := x + side * float(step) * 6.0
			if at >= left and at <= right and not bool(blocked.call(at)):
				return at
	return x


## THE ARTIST ROUTE. Every bird comes down to what was put out -- or, for something used in the
## hand, to where the apo is standing -- and lands beside it on the APO'S side, facing it, with
## its piece set down behind it: between the food and the player.
##
## ⚠ BESIDE IT, NOT ON IT, AND NOT PAST IT. Both found by the play bot. The flock used to land
## spread across the offering's own x, so one bird came down on the bread and left its piece
## under it; and spread to both sides, pieces lay beyond the bread from the apo -- and what was
## set down is solid, 84px of it against a 94px jump. So the slots start clear of the thing's
## own width, fill the apo's side first, and use the far side only if the near one runs out of
## floor. None is in a doorway.
func _feed_the_flock(alley: _Alley) -> void:
	if alley == null:
		return
	var landing := _feed_at
	var reach := _feed_half_width
	_feed_at = Vector2.INF
	if not landing.is_finite() or not Rect2(alley.room.bounds()).grow(60.0).has_point(landing):
		landing = _player_anchor_position()
		reach = 0.0
	var clear := _between_the_doors(alley.room)
	var left := alley.room.global_position.x + clear.x
	var right := alley.room.global_position.x + clear.y
	var near := signf(_player_anchor_position().x - landing.x)
	if near == 0.0:
		near = 1.0
	var count := alley.birds.size()
	var first := reach + FEED_CLEARANCE
	# The near row closes up before anybody is sent round the far side: down to FEED_CROWDED
	# apart, which is birds shoulder to shoulder.
	var near_floor := (landing.x - left) if near < 0.0 else (right - landing.x)
	var near_spacing := FEED_SPACING
	if count > 1:
		near_spacing = clampf((near_floor - first) / float(count - 1), FEED_CROWDED, FEED_SPACING)
	var slots: Array[float] = []
	for side: float in [near, -near]:
		var spacing := near_spacing if side == near else FEED_SPACING
		var rank := 0
		while slots.size() < count:
			var x := landing.x + side * (first + float(rank) * spacing)
			if x < left - 0.5 or x > right + 0.5:
				break
			slots.append(clampf(x, left, right))
			rank += 1
	for index in range(count):
		# More birds than the floor has room for, somehow: the rest come down at the edge.
		var x: float = slots[index] if index < slots.size() else clampf(landing.x, left, right)
		alley.birds[index].calm(Vector2(x, alley.room.global_position.y),
			Vector2(landing.x, alley.room.global_position.y))


## THE PRAGMATIST ROUTE, answered: the strings come down, the nests with them, and every bird
## bolts and lets go of what it was carrying. The alley's sky opens with it.
func _cut_the_bunting(alley: _Alley) -> void:
	if alley == null:
		return
	script_lines.set_flag("bandaritas_cut")
	alley.line.cut_it_down()
	for bird in alley.birds:
		bird.startle()
	# The cap has to be recomputed rather than waited for: the player is standing in the room
	# whose line has just come down.
	_ceiling_for = "?"


## THE PROTECTOR ROUTE, answered by the last piece coming down. The throw is put away, and any
## drawn tool that did the throwing is spent -- one use, and the use was this flock.
func _the_flock_is_down(alley: _Alley) -> void:
	if alley == null:
		return
	alley.thrower.clear()
	for tool_id: String in alley.thrown_with.keys():
		if _slot_holding(tool_id) >= 0:
			spend_tool(tool_id)
	alley.thrown_with.clear()
	# The status line was still saying "Stone in hand" over a stone that no longer exists.
	status_label.text = "Every one of them is down"


## A ROUND SHAPE DRAWN WHERE A FLOCK IS BEING THROWN AT IS A STONE, and it goes into the hand
## rather than the bag. Priced like the placeable it is -- a unit, the moment it is set down --
## because putting it in the hand is setting it down.
func _take_up_a_stone(alley: _Alley, entity_id: String, strokes: Array) -> void:
	ink_manager.release_attempt()
	var thrower := alley.thrower
	if thrower.has_stone():
		# Free: one stone is all the route needs, and a second would only be two to keep track of.
		_say_why("One stone is enough -- %s" % ("it is in your hand."
			if thrower.stone_in_hand() else "pick it up where it landed."))
		return
	if not ink_manager.spend_unit():
		status_label.text = "A stone costs a unit of ink, and there is none left"
		return
	_classes_this_run[entity_id] = true
	PlayerProfile.record_object_acquired(entity_id)
	if tutorial != null:
		tutorial.note("drawing_accepted")
	# The first half of the route is drawing something to throw, and this is it.
	if director.stage(alley.obstacle_id) == 0:
		_judge_submission(entity_id, strokes)
	thrower.give_stone()
	status_label.text = "Stone in hand"


## Let go of whatever is in hand, along the arc. A drawn tool's first throw is also its answer
## to the route's first half -- a tool is answered by using it, and here the use is a throw.
func _throw_in(alley: _Alley) -> bool:
	_tend_the_alleys()
	var thrower := alley.thrower
	if not thrower.ready_to_throw():
		return false
	var tool := _held_throwable()
	if tool != null and director.stage(alley.obstacle_id) == 0:
		_judge_submission(tool.item_data.entity_id, tool.item_data.strokes)
	if not thrower.throw():
		return false
	if tool != null:
		alley.thrown_with[tool.item_data.entity_id] = true
	return true


func _over_the_flock(alley: _Alley) -> Vector2:
	return alley.room.global_position + Vector2(0.0, -(FLOCK_LOW + FLOCK_HIGH) * 0.5)


func _nearest_piece(alley: _Alley) -> Vector2:
	var best := Vector2.INF
	var from := _player_anchor_position()
	for value: Variant in alley.pieces.values():
		var piece := value as Node2D
		if piece == null or not is_instance_valid(piece):
			continue
		if not best.is_finite() or piece.global_position.distance_to(from) < best.distance_to(from):
			best = piece.global_position
	return best


## An alley put back to a checkpoint: every bird whose piece is in hand long gone, every other one
## up again with its piece, nothing lying on the floor, the strings as they were, and the throw
## holding only what it held then. A checkpoint is written at the choice and once everything is
## in hand, so those are the only two states a restore ever lands on.
func _put_the_alley_back(alley: _Alley, saved: Dictionary) -> void:
	for value: Variant in alley.pieces.values():
		var piece := value as Node
		if piece != null and is_instance_valid(piece):
			piece.queue_free()
	alley.pieces.clear()
	alley.dropped.clear()
	for bird in alley.birds:
		var done := ledger != null and ledger.has(bird.scrap_id)
		bird.restore_to(done)
		if done:
			alley.dropped[bird.scrap_id] = true
	if bool(saved.get("cut", false)):
		alley.line.set_already_cut()
	else:
		alley.line.put_back_up()
	alley.thrower.clear()
	if bool(saved.get("stone", false)):
		alley.thrower.give_stone()
	alley.thrown_with.clear()
	_ceiling_for = "?"


func _on_at_rack(standing: bool) -> void:
	_at_rack = standing
	if hint_bar == null:
		return
	if not standing or chancel == null or chancel.kandila_on_rack:
		hint_bar.clear()
		return
	if not _has_kandila:
		hint_bar.show_hint("The rack. You have nothing to put on it.", Lolo.SPEAKER)
		return
	hint_bar.show_hint("Put the kandila on the rack  —  press %s"
		% ControlsKeys.keys_for("interact"), Lolo.SPEAKER)


## THE ONE ACTION IN SCENE 2, and the pace drops from here. The design is explicit that
## nothing in this room is a puzzle: the candle goes on the rack, the priest walks over and
## says where Lola went, and the far door opens.
##
## ⚠ LOLO'S PART IN HERE IS THE CANDLE AND NOTHING ELSE. He used to pray aloud, then say where
## she went all over again after the priest had -- "Two narrow ways. Of course." Kent: "the
## priest should be the one saying the dialogue ... The lolo dialogue here is just the lighting
## of candle." So he says one thing about the light and holds still beside it.
func _on_kandila_placed() -> void:
	_has_kandila = false
	script_lines.set_flag("kandila_placed")
	if hint_bar != null:
		hint_bar.clear()
	_speak(script_lines.fire("SCENE_2.lit"))
	# HE STOPS FOLLOWING and stays by the light. There is no praying pose in the delivered
	# sheet -- the design lists it as missing -- and `cheer` is arms-up celebration, which
	# would read as encouragement. Standing still beside it is the beat.
	if lolo != null and is_instance_valid(lolo) and chancel != null:
		lolo.global_position = chancel.rack_point() + Vector2(-70.0, -20.0)
	# The priest sets off once Lolo has been heard, and a moment after -- not over the top of
	# him, and not on a clock that could run out while the line was still being read.
	if dialogue_box != null and dialogue_box.is_open():
		await dialogue_box.conversation_finished
	await get_tree().create_timer(1.0, false).timeout
	if chancel != null and is_instance_valid(chancel):
		chancel.send_the_priest(_where_the_apo_is)


## Where the priest is walking to, asked every frame he walks: the apo, whatever body it is in.
func _where_the_apo_is() -> Vector2:
	if player == null or not is_instance_valid(player):
		return Vector2.INF
	return player.global_position


## He has walked over. He names the alleys -- the design calls his line "the only signpost
## for the second half of the level" -- and that is what opens the way out.
func _on_priest_arrived() -> void:
	_speak(script_lines.fire("SCENE_2.priest"))
	# CP2 is this moment. Written here rather than by a volume at the far door, because the
	# scene is finished by being watched rather than by being walked through -- a player who
	# heard the priest and then died in the first alley must not have to sit through him again.
	_write_checkpoint("CP2")
	if lolo != null and is_instance_valid(lolo):
		lolo.follow(player)
	if church != null:
		church.open_onward()


## The priest is the one person here who is neither Lolo nor the apo. See LevelBase._speak.
func _speaker_display(speaker_id: String) -> String:
	if speaker_id == "priest":
		return "Padre"
	return super._speaker_display(speaker_id)


## And while he talks, the camera is on him.
func _speaker_subject(speaker_id: String) -> Node2D:
	if speaker_id == "priest" and chancel != null and is_instance_valid(chancel):
		return chancel.priest_figure()
	return super._speaker_subject(speaker_id)


func _on_at_door(standing: bool, door: PiyestaDoor2D) -> void:
	_at_door = door if standing else null
	if hint_bar == null:
		return
	if not standing:
		# Only if the bar is still saying what this door put there -- one channel carries
		# several voices, and clearing unconditionally takes somebody else's message with it.
		if hint_bar.current_text() == door.prompt():
			hint_bar.clear()
		return
	hint_bar.show_hint(door.prompt(), Lolo.SPEAKER)


## E at an open door. Tried between a placed drawing and a signpost, which is where the base
## offers this hook.
func _interact_with_level() -> bool:
	if _at_rack and _has_kandila and chancel != null and not chancel.kandila_on_rack:
		return chancel.place_the_kandila()
	if _at_door == null or not _at_door.open:
		return false
	var room := _door_rooms.get(_at_door.door_id) as PiyestaRoom2D
	if room == null:
		return false
	_enter_room(room, _at_door.step_out_point())
	return true


## Into an inside, by the same teleport Level 1 uses for the heap and the house: it is the
## same body in the same level, so ink, the bag, the drawing panel and every checkpoint come
## with it.
func _enter_room(room: PiyestaRoom2D, came_from: Vector2) -> void:
	if player == null or not is_instance_valid(player):
		return
	# IDEMPOTENT. More than one thing can ask for a room -- a door, a beat, a restore -- and
	# a second call while the player is already inside would overwrite the outside spot with
	# a spot IN THE ROOM. The way out would then put them back into the room they had just
	# left, which is a trap that only shows up on the way out.
	if _room_holding_player() == room:
		return
	_step_back[room.name] = came_from
	room.disarm_the_way_out()
	_step_through(room.entry_point())
	if room == church and chancel != null and not chancel.kandila_on_rack:
		_speak(script_lines.fire("SCENE_2.enter"))


## Back out the way they came in.
func _leave_room(room: PiyestaRoom2D) -> void:
	var back: Vector2 = _step_back.get(room.name, Vector2.ZERO)
	if back == Vector2.ZERO:
		return
	_step_through(back)


## On to the next room in the chain. The far door of one inside is the near door of the
## next, so the player is put down at the room ahead's entry and their way back out of it
## is the room they just left.
func _go_onward(room: PiyestaRoom2D) -> void:
	# THE END OF THE SECOND ALLEY IS THE END OF THE LEVEL. Scene 3 is a modal overlay rather
	# than a room -- there is nothing to walk around in it -- so the chain stops being a
	# chain of places here and becomes a table with seven pieces on it.
	if room == alley_2:
		_open_scene_3()
		return
	var next := _next_after(room)
	if next == null:
		return
	next.disarm_the_way_out()
	_step_back[next.name] = room.return_point()
	_step_through(next.entry_point())


func _next_after(room: PiyestaRoom2D) -> PiyestaRoom2D:
	if room == church:
		return alley_1
	if room == alley_1:
		return alley_2
	return null


## Scene 3. The design is explicit that this cannot be failed, and the way that is honoured
## is simpler than it reads: THE TABLE ALWAYS LAYS OUT ALL SEVEN. `AssemblyOverlay.present`
## sets the slots from its own pieces, not from the ledger, so a player who arrives holding
## fewer than seven still has a whole painting to put back and still gets an ending.
##
## ⚠ THE LEDGER IS THEREFORE A COUNT, NOT A GATE, and the warning below is the only place
## the difference shows. This note used to say the missing pieces were handed over through
## `ScrapAssembly.place_now` "so the completion rule is not written twice" -- nothing has
## ever called it outside the tests, because nothing needs to.
func _open_scene_3() -> void:
	if assembly_screen == null or assembly_screen.is_open():
		return
	if ledger != null and not ledger.is_complete():
		push_warning("Level2: Scene 3 opened holding %d of %d scraps" % [
			ledger.held(), ledger.total()])
	# ⚠ HIM FIRST, THEN THE TABLE. `speak` appends to a queue and the table is a MODAL, so
	# presenting first puts the box behind a screen the player has to finish before they can
	# read what it said. Same ordering rule the straw heap already carries.
	_speak(script_lines.fire("EXIT_MARKER.enter"))
	assembly_screen.present()


## The painting is whole. THIS is what ends Piyesta -- not a marker somebody has to walk to.
##
## Level 1 learned that the hard way: its goal marker sat out on the Overlook, so finishing
## Payyo meant solving the hardest node in the level, taking the painting, and then walking
## to a spot that looked like every other spot on the terrace. Players did the first part and
## stood there. The last thing you do should be the thing that ends it.
func _on_assembly_done(_creased: bool) -> void:
	# ⚠ FOUR AUTHORED LINES FOR THIS MOMENT AND NOTHING FIRED ANY OF THEM. `dialogue_l2.json`
	# has carried EXIT_MARKER.enter, two EXIT_MARKER.assembled lines and the closing
	# EXIT_MARKER since the file was written -- the level's whole ending, in Lolo's voice,
	# including the one line that pays off Payyo's Protector route ("The fold runs right
	# through it. That was us."). The level went straight from the table to a completion
	# screen and said none of it.
	#
	# The crease line carries its own `condition`, so a player who never cut the hasp gets
	# two lines and one who did gets three; `fire` is what applies that, which is why these
	# go through the script rather than being written here.
	_speak(script_lines.fire("EXIT_MARKER.assembled"))
	_speak(script_lines.fire("EXIT_MARKER"))
	_complete_level()


## The candle, off the table in the lit house. Path C's reward, and the last thing that has
## to happen before the church will let anybody in.
func _on_kandila_taken() -> void:
	_hold_the_kandila()
	announce_acquisition("Kandila",
		"A candle off a stranger's table. Lolo will want it lit somewhere.")
	_speak(script_lines.fire("L2_N1.pragmatist.solved"))


## One door for the candle arriving, whichever route brought it. The church opens off this
## and nothing else, so the three routes cannot disagree about when it opens.
func _hold_the_kandila() -> void:
	if _has_kandila:
		return
	_has_kandila = true
	script_lines.set_flag("has_kandila")
	var door := _doors.get(DOOR_CHURCH) as PiyestaDoor2D
	if door != null:
		door.set_open(true)


# --- The size rule: a refusal, which costs nothing -----------------------------------

func _extra_refusals(entity_id: String, _strokes: Array) -> bool:
	if restrictions != null and restrictions.refuses(entity_id):
		return true
	# ⚠ NOTHING IS JUDGED AT AN ALLEY BEFORE ITS CHOICE. Before a route is committed the
	# director judges against every route's tags at once and ignores each route's exclusions,
	# so a blade -- `cut` for one route, excluded from `strike` by another -- would answer the
	# beat by no route at all, and a beat solved by no route has no flock to bring down: the way
	# on would never open. The choice is asked at the way in, so this is only ever reached by
	# something getting past it -- and then it asks again rather than refusing forever.
	var alley := _alley_at_beat()
	if alley != null and director.committed_route(alley.obstacle_id).is_empty():
		_say_why("Tell Lolo how you will do it first.")
		_ask_at(alley)
		return true
	return false


func _on_submission_refused(_entity_id: String, note: String) -> void:
	# The hint bar, not the story box: this is the game talking about its own rule while
	# the player is standing at a canvas, and it must not stop the world to do it.
	if hint_bar != null:
		hint_bar.show_hint(note, Lolo.SPEAKER)


# --- The alleys' answers, where they are not the base's --------------------------------

## THE SECOND HALF OF THE THROWING ROUTE IS NOT A DRAWING. It is answered by the last piece
## coming down, and nothing drawn may answer it -- T3's widening included, which would otherwise
## take any drawing at all as every bird knocked down and end the beat with the flock still up.
##
## And halfway up the cut route, Lolo says what the second drawing is for.
func _judge_submission(entity_id: String, strokes: Array = []) -> void:
	var alley := _alley_at_beat()
	if alley == null:
		super(entity_id, strokes)
		return
	var route := director.committed_route(alley.obstacle_id)
	if route == "protector" and director.stage(alley.obstacle_id) > 0:
		return
	var before := director.stage(alley.obstacle_id)
	super(entity_id, strokes)
	if route == "pragmatist" and before == 0 and director.stage(alley.obstacle_id) > 0:
		_speak(script_lines.fire(alley.climbed_hook))


## A round shape drawn where a flock is being thrown at goes into the hand as a stone. Anything
## else is drawn the way it is everywhere.
func _on_drawing_ready(
	entity_id: String,
	display_name: String,
	drawing: Image,
	response: Dictionary,
	strokes: Array,
	ink_cost: float
) -> void:
	var alley := _alley_holding_player()
	if _throwing_at(alley) and int(StoneThrow2D.THROWN.get(entity_id, StoneThrow2D.Kind.NONE)) \
			== StoneThrow2D.Kind.STONE:
		_take_up_a_stone(alley, entity_id, strokes)
		return
	super(entity_id, display_name, drawing, response, strokes, ink_cost)


## Where a drawing was set down, kept for the flock while it is judged -- the judging is what
## feeds them, and they come down to the thing that was put out, not to the player.
func _on_placement_confirmed(
	item: DrawnItemData,
	placed: PhysicsShapeObject,
	source_slot: int
) -> void:
	if placed != null and is_instance_valid(placed):
		var extent := placed.world_extent()
		_feed_at = extent.get_center() if extent.size != Vector2.ZERO else placed.global_position
		_feed_half_width = extent.size.x * 0.5
	super(item, placed, source_slot)
	_feed_at = Vector2.INF
	_feed_half_width = 0.0


## At a flock being thrown at, the drawn things that are thrown answer it -- at either half of
## the route, since the second half is more of the same -- and nothing else does: the blades the
## route excludes swing, and must not be offered as a throw.
func _tool_answers_here(entity_id: String) -> bool:
	var alley := _alley_at_beat()
	if alley != null and director.committed_route(alley.obstacle_id) == "protector" \
			and not director.is_solved(alley.obstacle_id):
		var kind := int(StoneThrow2D.THROWN.get(entity_id, StoneThrow2D.Kind.NONE))
		return kind == StoneThrow2D.Kind.BOOMERANG or kind == StoneThrow2D.Kind.CANNON
	return super(entity_id)


## F IN AN ALLEY. Whatever is held to throw is thrown along the arc -- a boomerang's own use is a
## throw straight ahead at nothing -- and a cutting edge only cuts the strings it can reach.
func _use_equipped_utility() -> void:
	var alley := _alley_holding_player()
	if _throwing_at(alley):
		_tend_the_alleys()
		if alley.thrower.kind != StoneThrow2D.Kind.NONE:
			if not _throw_in(alley) and alley.thrower.kind == StoneThrow2D.Kind.STONE \
					and alley.thrower.stone_on_the_floor():
				_say_why("Your stone is where it landed -- walk over it to pick it up.")
			return
	if _cutting_at(alley) and _equipped_utility != null and is_instance_valid(_equipped_utility) \
			and _equipped_utility.item_data != null \
			and _tool_answers_here(_equipped_utility.item_data.entity_id) \
			and alley.line.reach_distance(_equipped_utility.global_position) > CUT_REACH:
		_say_why("Up to the strings first -- they are out of reach from down here.")
		return
	super()


## A CLICK THROWS, in an alley being thrown at: the arc follows the pointer, and letting go where
## you are pointing is the gesture it invites. F throws too, through `_use_equipped_utility`.
func _handle_level_input(event: InputEvent) -> bool:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return false
	if placement_controller.is_placing():
		return false
	var alley := _alley_holding_player()
	if not _throwing_at(alley):
		return false
	_tend_the_alleys()
	if not alley.thrower.ready_to_throw():
		return false
	alley.thrower.aim_at(get_viewport().get_canvas_transform().affine_inverse() * click.position)
	return _throw_in(alley)


# --- The ceiling: a violation, and POSITION ONLY -------------------------------------

func _level_physics(anchor_position: Vector2) -> void:
	_tend_the_alleys()
	_refresh_the_ceiling()
	if restrictions == null or player == null or not is_instance_valid(player):
		return
	if _current_form_id.is_empty():
		return
	restrictions.check_height(_current_form_id, anchor_position.y)


## ⚠ NOT `_return_to_safety`, and the difference is the whole rule. That door runs a full
## `_restore_checkpoint`, which rolls ink back to the snapshot and re-stages every placed
## drawing -- so a player who solved something and then drifted too high would lose the
## solve. The design says inventory, ink, scraps and flags are KEPT and only position
## resets, so this reads the checkpoint WITHOUT consuming it (peek does not count a
## restore) and moves the body, and nothing else.
func _on_ceiling_crossed(entity_id: String, height_over: float) -> void:
	var landing := spawn_point.global_position
	if checkpoints != null and checkpoints.has_checkpoint():
		var state: Dictionary = checkpoints.peek()
		landing = Vector2(state.get("position", landing))
	if player.has_method("apply_morph_state"):
		player.call("apply_morph_state", {"position": landing, "linear_velocity": Vector2.ZERO})
	else:
		player.global_position = landing
	# ⚠ IT ESCALATES, AND THE SECOND LINE HAD NO CALL SITE. `fail1` is "Hoy! I told you.
	# Under the strings"; `fail2` is "Naku. Come here. You are going to get yourself stepped
	# on." Firing the first every time means a player who keeps crossing hears the same
	# sentence forever, which reads as the game not noticing rather than as a warning.
	_ceiling_crossings += 1
	_speak(script_lines.fire("L2_START.ward.fail%d" % mini(_ceiling_crossings, 2)))
	Telemetry.record_event("restriction_violation", {
		"level_id": LevelManager.current_level_id,
		"rule": "flight_ceiling", "class": entity_id, "over_by": height_over,
	})


## THE CEILING IS PER SCENE, NOT ONE NUMBER. Whatever Y the bandaritas are strung at in the
## room the player is standing in, the cap sits just under it -- so the boundary is always
## something visible and always in the same place as the thing that draws it.
##
## Asked every frame and acted on only when the answer changes, which is the shape
## `_refresh_room_framing` already uses: a checkpoint restore, a fall or an expiry can move
## the player between scenes without going through a doorway, and every one of those would
## otherwise leave the cap set for the room they used to be in.
func _refresh_the_ceiling() -> void:
	if restrictions == null:
		return
	var room := _room_holding_player()
	var where: String = String(room.name) if room != null else "plaza"
	if where == _ceiling_for:
		return
	_ceiling_for = where
	var line: BandaritaLine2D = _lines.get(where)
	if line != null and line.still_a_ceiling():
		restrictions.set_ceiling(line.ceiling_y())
		return
	# ⚠ THE PLAZA'S BUNTING IS PAINTED INTO THE PLATE, so its cap is read off the mark that
	# records where the painted line hangs rather than off a node. Stringing an authored line
	# over it would put two runs of bandaritas across one plaza -- the same doubling this
	# level keeps having to be talked out of.
	if where == "plaza" and _bunting_y != -INF:
		restrictions.set_ceiling(_bunting_y + 20.0)
		return
	restrictions.set_ceiling(-INF)


# --- What the level does when a beat is answered -------------------------------------

func _on_route_solved(obstacle_id: String, route: String) -> bool:
	match [obstacle_id, route]:
		["L2_N1", "artist"]:
			# Reached from `_on_dance_screen_finished` whichever way the dance went. THE
			# KANDILA IS NEVER WITHHELD -- that is what makes this level unloseable, and only
			# the flower was ever at stake. The flower is recorded separately, off the model's
			# own `finished`, so a player who failed both goes still walks away with a candle
			# and is never told what they missed.
			_hold_the_kandila()
			# ⚠ AND THE RIGHT LINE FOR WHAT ACTUALLY HAPPENED. The generic `.solved` line is
			# "they still gave her the flower", which is a lie to a player who failed twice --
			# and `.failed` was authored for exactly that case and had never fired. Returning
			# true is what stops the base speaking the other one over the top of it.
			if dance != null and not dance.cleared():
				_speak(script_lines.fire("L2_N1.artist.failed"))
				return true
		["L2_N1", "protector"]:
			# One way, and they do not come back. The quiet line waits until they have
			# actually gone rather than firing over the top of them leaving.
			_hold_the_kandila()
			if dancers != null:
				dancers.scatter()
			return true
		["L2_N1", "pragmatist"]:
			# ⚠ THIS ONE DOES NOT GRANT THE KANDILA, and that is the difference between it
			# and the other two. Committing this route means the drawn key imitated the lock;
			# the candle is still on a table inside. `Kandila2D.taken` is what closes the
			# beat, and the spoken line goes with it rather than firing here.
			var door := _doors.get(DOOR_LIT_HOUSE) as PiyestaDoor2D
			if door != null:
				door.set_open(true)
			# TRUE, so the generic "L2_N1.pragmatist.solved" does NOT fire here. That line
			# is "take it and leave something on the sill", which is about the candle -- and
			# the candle is inside. It fires when the candle is taken. The commit already had
			# its own line ("someone is home, I will let myself in"), which is the door.
			return true
		["L2_N2", "artist"], ["L2_N3", "artist"]:
			# One offering brings the whole flock down. Driven through the BIRDS rather than
			# straight into the ledger, so what the player sees and what the count says cannot
			# disagree -- and the pieces are on the floor to be picked up, not handed over.
			_feed_the_flock(_alleys.get(obstacle_id) as _Alley)
		["L2_N2", "pragmatist"], ["L2_N3", "pragmatist"]:
			_cut_the_bunting(_alleys.get(obstacle_id) as _Alley)
		["L2_N2", "protector"], ["L2_N3", "protector"]:
			_the_flock_is_down(_alleys.get(obstacle_id) as _Alley)
	# FALSE for every alley route, so the generic `.solved` line fires. The way on is NOT opened
	# here: it opens when every piece is in hand, which is later -- see _pick_up_the_pieces.
	return false


func _on_dance_finished(cleared: bool, flower_earned: bool) -> void:
	# THE KANDILA IS NEVER WITHHELD, so this node can never dead-end the run. Only the
	# flower is at stake, and losing it is SILENT -- a secret ending that announces its
	# requirements is not secret.
	if flower_earned:
		PlayerProfile.record_collectible("L2_HF")
		script_lines.set_flag("has_flower")
	Telemetry.record_event("dance_minigame", {
		"level_id": LevelManager.current_level_id,
		"cleared": cleared, "attempts": dance.attempts_used(),
	})


# --- What a checkpoint carries that the machine does not know about -------------------

func _level_run_state() -> Dictionary:
	var out: Dictionary = {
		"kandila": _has_kandila,
		"dancers_gone": dancers != null and dancers.are_gone(),
		"kandila_on_rack": chancel != null and chancel.kandila_on_rack,
		# Where the chain has got to. Without it a restore behind a room the player had
		# already opened would board the door up again and strand them in an alley.
		"onward": {
			"church": church != null and church.onward_open,
			"alley_1": alley_1 != null and alley_1.onward_open,
			"alley_2": alley_2 != null and alley_2.onward_open,
		},
		# Which fork the choice screen is answering for. See _live_node_obstacle.
		"live_node": _live_node_obstacle,
	}
	if ledger != null:
		out["scraps"] = ledger.serialize()
	# What each alley has done that the birds and the ledger do not already say: whether its
	# strings are down, and whether a stone has been drawn there.
	var alleys: Dictionary = {}
	for alley: _Alley in _alleys.values():
		alleys[alley.obstacle_id] = {
			"cut": alley.line.is_cut(),
			"stone": alley.thrower.has_stone(),
		}
	out["alleys"] = alleys
	return out


func _restore_level_run_state(state: Dictionary) -> void:
	if ledger != null and state.has("scraps"):
		ledger.restore(state["scraps"])
	# AFTER the ledger, because the birds are put back by it: a bird whose piece is in hand is
	# gone, and every other one is up again with its piece.
	var alleys: Dictionary = state.get("alleys", {})
	for alley: _Alley in _alleys.values():
		_put_the_alley_back(alley, alleys.get(alley.obstacle_id, {}))
	_live_node_obstacle = String(state.get("live_node", _live_node_obstacle))
	var live := _alleys.get(_live_node_obstacle) as _Alley
	dialogue_node = live.fork if live != null else _plaza_node
	if dancers != null and bool(state.get("dancers_gone", false)):
		# Set, not replayed: a restore after they left must not run them off the plaza a
		# second time, which would look like the level happening again.
		dancers.set_already_gone()
	if bool(state.get("kandila", false)):
		_hold_the_kandila()
	if chancel != null and bool(state.get("kandila_on_rack", false)):
		chancel.kandila_on_rack = true
		chancel.queue_redraw()
	var onward: Dictionary = state.get("onward", {})
	if church != null and bool(onward.get("church", false)):
		church.open_onward()
	if alley_1 != null and bool(onward.get("alley_1", false)):
		alley_1.open_onward()
	if alley_2 != null and bool(onward.get("alley_2", false)):
		alley_2.open_onward()


## How much of the Dagat painting is recovered, in the corner where Payyo counts metres.
##
## Written on every change rather than every frame: `_physics_process` owns that label for a
## level that has a marker, and this level has none, so nothing overwrites it in between.
func _show_the_count() -> void:
	if goal_label == null or ledger == null:
		return
	goal_label.text = "SCRAPS  %d / %d" % [ledger.held(), ledger.total()]


## THE LEVEL OPENS ITS MOUTH. `_greet` in the base reads `_script_lines`, which is the legacy
## dialogue.json Payyo still carries and this level has none of -- so Piyesta spawned the
## player into a plaza and said nothing at all.
##
## ⚠ AND `L2_START.teach` IS THE TWO RULES. It is the only place the player is told that
## the bandaritas are a ceiling and that small animals are refused, and nothing fired it. So
## the first time either rule bit, it bit unannounced: a drawing refused for a reason nobody
## had given, or a flier snapped back to a checkpoint while Lolo says "Hoy! I told you.
## Under the strings." He had not told them. That line has been in the file the whole time.
##
## ONE CALL, BOTH HOOKS, and the split between them is already authored: `.enter` is lore and
## takes the framed box, `.teach` is marked `kind: hint` and takes the bar. `_speak` routes
## by kind and posts the advice UNDER the conversation, where it waits out the box and then
## plays -- so the rules are the thing standing on screen when the player takes their first
## step, which is exactly when they need them.
func _greet() -> void:
	if script_lines == null:
		return
	var opening: Array = script_lines.fire("L2_START.enter")
	opening.append_array(script_lines.fire("L2_START.teach"))
	_speak(opening)


# --- What the player should be doing ---------------------------------------------------

## PIYESTA IN ORDER: a light for the church, the candle on the rack, the flock in the first
## alley, the bunting in the second, the table. Each step points at the thing it is about when
## the player is where that thing is, and at the way there when they are not -- because the
## commonest way to be lost in this level is standing in the right room's neighbour.
func _current_objective() -> Dictionary:
	if director == null:
		return {}
	if assembly_screen != null and assembly_screen.is_open():
		return {"key": "table"}
	var room := _room_holding_player()
	var placed := chancel != null and chancel.kandila_on_rack

	# PROBLEM 1 -- a light to leave.
	if not _has_kandila and not placed:
		if not director.is_solved("L2_N1"):
			match director.committed_route("L2_N1"):
				"artist":
					return {"key": "dance", "target": _over_the_dancers()}
				"pragmatist":
					return _from(room, {"key": "unlock", "obstacle": "L2_N1",
						"target": _over_door(DOOR_LIT_HOUSE)})
				"protector":
					return _from(room, {"key": "startle", "obstacle": "L2_N1",
						"target": _over_the_dancers()})
			var node_at := _plaza_node.global_position + Vector2(0.0, -110.0) \
				if _plaza_node != null else _over_the_dancers()
			return _from(room, {"key": "light", "target": node_at})
		# The key worked and the candle is still on the table inside.
		if room == house:
			return {"key": "take_light", "target": _kandila_prop.global_position
				+ Vector2(0.0, -70.0) if _kandila_prop != null else Vector2.INF}
		return _from(room, {"key": "fetch_light", "target": _over_door(DOOR_LIT_HOUSE)})

	# SCENE 2 -- the rack, and the priest.
	if not placed:
		if room == church:
			return {"key": "rack", "target": chancel.rack_point() + Vector2(0.0, -110.0)}
		return _from(room, {"key": "to_church", "target": _over_door(DOOR_CHURCH)})
	if church != null and not church.onward_open:
		return {"key": "priest"}

	# PROBLEMS 2 AND 3, and the rooms between.
	var alley := _alley_in(room)
	if alley != null:
		return _alley_objective(alley)
	if room == church:
		return {"key": "to_alleys", "target": _onward_of(church)}
	return _from(room, {"key": "back_to_church", "target": _over_door(DOOR_CHURCH)})


## AN ALLEY, STEP BY STEP. The same words in both, because they are the same problem: choose,
## do the route's one or two things, pick the pieces up, go on. Each step points at what it is
## about -- the flock, the strings, the stone where it landed, the nearest piece -- and the aim
## points at nothing, because the birds are the target and they are on screen.
func _alley_objective(alley: _Alley) -> Dictionary:
	var ob := alley.obstacle_id
	if alley.room.onward_open:
		return {"key": "alley_on" if alley.room == alley_1 else "alley_end",
			"target": _onward_of(alley.room)}
	# Everything is coming down, or down: the pieces are the thing now.
	if director.is_solved(ob) or alley.flock_is_down():
		var piece := _nearest_piece(alley)
		return {"key": "flock_collect",
			"target": piece + Vector2(0.0, -60.0) if piece.is_finite() else Vector2.INF}
	match director.committed_route(ob):
		"artist":
			return {"key": "flock_feed", "obstacle": ob, "target": _over_the_flock(alley)}
		"pragmatist":
			if director.stage(ob) == 0:
				return {"key": "flock_climb", "obstacle": ob,
					"target": alley.line.middle() + Vector2(0.0, ALLEY_LINE * 0.5)}
			return {"key": "flock_cut", "obstacle": ob, "target": alley.line.middle()}
		"protector":
			return _throw_objective(alley)
	return {"key": "flock", "obstacle": ob, "target": _over_the_flock(alley)}


## The throwing route, which has the most states: something to draw, something in the bag,
## a stone on the floor, or something in hand.
func _throw_objective(alley: _Alley) -> Dictionary:
	var thrower := alley.thrower
	if _held_throwable() == null and thrower.stone_on_the_floor():
		return {"key": "flock_fetch", "target": thrower.resting_stone() + Vector2(0.0, -60.0)}
	if thrower.kind != StoneThrow2D.Kind.NONE:
		return {"key": "flock_aim"}
	if _has_a_throwable_in_the_bag():
		return {"key": "flock_hold", "target": _over_the_flock(alley)}
	return {"key": "flock_stone", "obstacle": alley.obstacle_id,
		"target": _over_the_flock(alley)}


## A plaza objective asked while the player is inside somewhere: the same words, pointed at
## the way out of the room they are in.
func _from(room: Node2D, goal: Dictionary) -> Dictionary:
	var inside := room as PiyestaRoom2D
	if inside == null:
		return goal
	goal["target"] = inside.global_position + inside.exit_rect().get_center()
	return goal


func _over_door(door_id: String) -> Vector2:
	var door := _doors.get(door_id) as PiyestaDoor2D
	if door == null:
		return Vector2.INF
	var height := PiyestaDoor2D.PORTAL.y + 90.0 if door.style == PiyestaDoor2D.Style.CHURCH \
		else PiyestaDoor2D.FACADE.y + 10.0
	return door.global_position + Vector2(0.0, -height)


func _over_the_dancers() -> Vector2:
	var mark := _mark("DancersMark")
	return mark.global_position + Vector2(260.0, -170.0) if mark != null else Vector2.INF


func _onward_of(room: PiyestaRoom2D) -> Vector2:
	return room.global_position + room.onward_rect().get_center() + Vector2(0.0, -70.0)
