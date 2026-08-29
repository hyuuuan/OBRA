extends "res://scripts/level_base.gd"
## LEVEL 2 -- PIYESTA. The plaza, and the rules it arms over the whole of itself.
##
## Extended BY PATH rather than by `class_name LevelBase`, for the reason game_level.gd is:
## a `--script` run does not register class names and a dozen runners are exactly that.
##
## What this level adds to the machine that Payyo did not need:
##   * TWO RESTRICTIONS, armed for the level's whole length. See level_restrictions.gd for
##     why one refuses and the other punishes.
##   * A LEDGER, because the seven pieces of the painting are recovered across two screens
##     and the count that survives the first is a NUMBER, not a flag.
##   * A CEILING THAT IS A PLACE. It is set per scene from the bandaritas' own Y, so the
##     boundary is the art rather than a HUD element, and it lifts when the line is cut.

const RestrictionsClass = preload("res://scripts/level_restrictions.gd")
const LedgerClass = preload("res://scripts/scrap_ledger.gd")
const AssemblyClass = preload("res://scripts/scrap_assembly.gd")
const DanceClass = preload("res://scripts/dance_minigame.gd")

## The canvas Level 1's Protector route creases. Read from the profile, drawn on the
## assembled picture, and changing nothing else -- see LEVEL_1.md, where the fact that this
## now costs nothing mechanical is recorded as a debt rather than as a design.
const CREASED_CANVAS := "canvas_2_pista"
## The dance is scored on timing, not on shape, so it never reaches the recogniser. A var
## rather than a const because GDScript will not fold a PackedFloat32Array into one -- and
## the track wants to be authored against the music anyway.
var dance_track := PackedFloat32Array([1.0, 2.0, 3.0, 4.0, 5.0, 6.0])

## THE DOORS THAT GO SOMEWHERE, and the two that do not. The design asks for the lit house
## to sit "past two or three dark doors so the search reads as a search", so the dark pair
## are content rather than decoration -- they are what makes finding the lit one a find.
const DOOR_CHURCH := "church"
const DOOR_LIT_HOUSE := "lit_house"
const DOOR_DARK_A := "dark_a"
const DOOR_DARK_B := "dark_b"

var restrictions: LevelRestrictions
var ledger: ScrapLedger
var assembly: ScrapAssembly
var dance: DanceMinigame

## Where the bandaritas hang in the plaza, read off the scene rather than typed twice.
var _bunting_y := -INF

var church: PiyestaRoom2D
var house: PiyestaRoom2D
var alley_1: PiyestaRoom2D
var alley_2: PiyestaRoom2D
var _marks: Node2D
## door_id -> the door, and door_id -> the inside it opens onto. Two dictionaries rather
## than one because the dark pair have a door and no room, which is the point of them.
var _doors: Dictionary = {}
var _door_rooms: Dictionary = {}
## Where the player was standing when they went in, by room name. REMEMBERED ON THE WAY IN
## rather than worked out on the way out, which is the shape Level 1 arrived at after the
## straw room put people back inside the mouth they had just walked out of.
var _step_back: Dictionary = {}
var _at_door: PiyestaDoor2D = null
## Whether the kandila is in hand. LEVEL RUN STATE, not the profile: `has_object` is
## permanent by design, so recording it there would open every later run of Piyesta with the
## candle already found and the whole of Problem 1 already answered. Level 1 made exactly
## this mistake with the canvas in the bale.
var _has_kandila := false


# --- What this level answers ---------------------------------------------------------

func level_config_path() -> String:
	return "res://config/level_02.json"


func dialogue_path() -> String:
	return "res://config/dialogue_l2.json"


func _dialogue_node_obstacle_id() -> String:
	return "L2_N1"


func _resolve_level_nodes() -> void:
	dialogue_node = get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/DialogueNode") as DialogueNode2D
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
	restrictions.ceiling_crossed.connect(_on_ceiling_crossed)
	# The plaza's own line. Each later scene sets its own; a scene with no bandaritas
	# leaves it at -INF and the rule stands down there.
	restrictions.set_ceiling(_bunting_y + 20.0 if _bunting_y != -INF else -INF)

	ledger = LedgerClass.new()
	ledger.name = "ScrapLedger"
	add_child(ledger)
	ledger.reset()

	assembly = AssemblyClass.new()
	assembly.name = "ScrapAssembly"
	add_child(assembly)
	assembly.set_creased(PlayerProfile.is_canvas_damaged(CREASED_CANVAS))

	dance = DanceClass.new()
	dance.name = "DanceMinigame"
	add_child(dance)
	dance.set_track(dance_track)
	dance.finished.connect(_on_dance_finished)

	_build_the_doors()
	_wire_the_rooms()
	_put_the_kandila_in_the_house()


func _roster_ids() -> PackedStringArray:
	var out := PackedStringArray()
	if registry == null:
		return out
	for id: Variant in registry.get_entity_ids():
		out.append(String(id))
	return out


# --- The plaza's doors, and the insides behind two of them ---------------------------

## FOUR DOORS ON THE PLAZA. Two open onto rooms and two open onto nothing, and they are
## drawn identically apart from the light under the lit one -- which is the design's own
## instruction and the reason Path C reads as a search rather than as a walk to the only
## interactive thing on screen.
##
## Built here rather than authored into the scene because they stand ON the marks, and the
## marks are what the scene probe measures against the plaza floor. Two sources for one
## position is one of them going stale.
func _build_the_doors() -> void:
	var plan: Array[Dictionary] = [
		{"id": DOOR_DARK_A, "mark": "DarkHouseA", "lit": false, "room": null,
			"shut": "Shuttered. Nobody is home -- they are all out at the fiesta."},
		{"id": DOOR_DARK_B, "mark": "DarkHouseB", "lit": false, "room": null,
			"shut": "Dark inside. Not this one."},
		{"id": DOOR_LIT_HOUSE, "mark": "LitHouse", "lit": true, "room": house,
			"shut": "There is a light on in there, and the door does not give.",
			"open": "The door is open."},
		{"id": DOOR_CHURCH, "mark": "ChurchDoor", "lit": false, "room": church,
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
	return restrictions != null and restrictions.refuses(entity_id)


func _on_submission_refused(_entity_id: String, note: String) -> void:
	# The hint bar, not the story box: this is the game talking about its own rule while
	# the player is standing at a canvas, and it must not stop the world to do it.
	if hint_bar != null:
		hint_bar.show_hint(note, Lolo.SPEAKER)


# --- The ceiling: a violation, and POSITION ONLY -------------------------------------

func _level_physics(anchor_position: Vector2) -> void:
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
	_speak(script_lines.fire("L2_START.ward.fail1"))
	Telemetry.record_event("restriction_violation", {
		"level_id": LevelManager.current_level_id,
		"rule": "flight_ceiling", "class": entity_id, "over_by": height_over,
	})


# --- What the level does when a beat is answered -------------------------------------

func _on_route_solved(obstacle_id: String, route: String) -> bool:
	match [obstacle_id, route]:
		["L2_N1", "artist"], ["L2_N1", "protector"]:
			# The dancers hand it over -- either for the performance or on their way out of
			# the plaza. Both routes end with the candle in hand and the church open.
			_hold_the_kandila()
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
		["L2_N2", "artist"]:
			# One offering brings all five down. Splitting it per bird would turn a lore
			# beat into a chore.
			for index in range(ScrapLedger.IN_ALLEY_1):
				ledger.recover("alley1_%d" % index)
			ledger.defer(0)
		["L2_N2", "pragmatist"]:
			# All five go on ahead. Deferred, not lost -- Alley 2 spawns exactly this many.
			ledger.defer(ScrapLedger.IN_ALLEY_1)
		["L2_N3", "protector"]:
			# The one action in this level that permanently changes the town, and the
			# reason the cut is a trade: it buys the sky for the rest of the level.
			script_lines.set_flag("bandaritas_cut")
			if restrictions != null:
				restrictions.lift()
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
	return {"scraps": ledger.serialize()} if ledger != null else {}


func _restore_level_run_state(state: Dictionary) -> void:
	if ledger != null and state.has("scraps"):
		ledger.restore(state["scraps"])
