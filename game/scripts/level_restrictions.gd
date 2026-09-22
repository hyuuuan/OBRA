class_name LevelRestrictions
extends Node
## The rules a level arms for its whole length, and the first time this project has
## restricted what the player may draw. Piyesta arms two; Dagat arms a third.
##
## Everything before this level ADDED to what a drawing could do. Level 2 takes things away,
## and that is a different kind of promise: a refusal the player cannot predict reads as the
## recogniser failing, and a punishment for a drawing the game accepted reads as a bug. So
## the rules are deliberately NOT all the same kind of thing:
##
##   * **A banned class is REFUSED AT SUBMISSION.** It costs no ink, the player is told why,
##     and nothing moves. It is a boundary.
##   * **The flight ceiling is a VIOLATION.** The drawing was legal, the player made it and
##     then went somewhere they were told not to, and they are put back. It is a
##     consequence.
##   * **Drowning is also a CONSEQUENCE, and deliberately not a ban.** Dagat's design is
##     explicit that a land creature spawned underwater "should not be silently refused --
##     let it flounder for a beat, have Lolo react, then revert it. The refusal is funnier
##     and clearer than a blocked draw." So a horse in the sea is drawn, spawned, paid for
##     and then cannot cope, which is a fact about horses rather than a rule about drawing.
##
## Level 2's design routes its two to the checkpoint handler. Its UI list asks for
## feedback saying WHY a drawing was refused, and its own note says to check the size rule
## first so the more specific message wins -- which only makes sense if the size rule
## answers before anybody is airborne. Sending the player back to a checkpoint for a
## drawing they were never allowed to make is a punishment for the game's own rule.
##
## EVERY LIST IS EXPLICIT AND VALIDATED. The design is emphatic: never infer size or flight
## from a label at runtime. A rule that names a class the roster does not have bans nothing
## and says nothing, which is the one failure mode a restriction cannot have.

## A class the player may not become here, and why, so the message is specific.
signal submission_refused(entity_id: String, note: String)
## A legal drawing that went somewhere it was told not to.
signal ceiling_crossed(entity_id: String, height_over: float)
## A legal drawing that cannot cope with the medium it is in, after its flounder.
signal floundered(entity_id: String, note: String)

const BANNED_KEY := "banned_playable_classes"
const CEILING_KEY := "flight_ceiling"
const AQUATIC_KEY := "aquatic_only"

var _banned: Dictionary = {}          # entity_id -> true
var _capped: Dictionary = {}          # entity_id -> true
var _banned_fiction := ""
var _ceiling_y: float = -INF          # world Y of the line; -INF means "no line here"
var _lifted := false
var _lift_flag := ""

## ⚠ THE AQUATIC RULE LISTS WHAT WORKS, NOT WHAT DOES NOT. The other two name the classes
## they act on; this one would have to name forty-three. Naming the seven that swim also
## makes the rule readable as the sentence the design writes it as -- "underwater, only
## aquatic classes work as playable actors" -- and makes the audit's job the right way round:
## a swimmer list that resolves to nothing means EVERYTHING flounders.
var _swimmers: Dictionary = {}        # entity_id -> true
var _aquatic_armed := false
var _flounder_fiction := ""
var _flounder_seconds := 1.2
var _floundering_id := ""
var _floundering_for := 0.0


## Read the rules out of the level file and check every class against the manifest.
## Returns the problems rather than pushing them, so the caller decides whether a bad
## rule is a warning or a refusal to start -- and so this is testable without a level.
func load_from(level: Dictionary, roster_ids: PackedStringArray) -> Array:
	_banned.clear()
	_capped.clear()
	_swimmers.clear()
	_aquatic_armed = false
	_lifted = false
	_ceiling_y = -INF
	_floundering_id = ""
	_floundering_for = 0.0
	var problems: Array = []
	var rules: Dictionary = level.get("restrictions", {})

	var ban: Dictionary = rules.get(BANNED_KEY, {})
	_banned_fiction = String(ban.get("fiction", ""))
	for value: Variant in ban.get("classes", []):
		var id := String(value)
		if not roster_ids.has(id):
			problems.append("%s bans '%s', which is not in the roster" % [BANNED_KEY, id])
			continue
		_banned[id] = true

	var cap: Dictionary = rules.get(CEILING_KEY, {})
	_lift_flag = String(cap.get("lifted_by_flag", ""))
	for value: Variant in cap.get("classes", []):
		var id := String(value)
		if not roster_ids.has(id):
			problems.append("%s caps '%s', which is not in the roster" % [CEILING_KEY, id])
			continue
		_capped[id] = true

	var sea: Dictionary = rules.get(AQUATIC_KEY, {})
	_aquatic_armed = not sea.is_empty()
	_flounder_fiction = String(sea.get("fiction", ""))
	if sea.has("flounder_seconds"):
		_flounder_seconds = maxf(0.0, float(sea.get("flounder_seconds", 1.2)))
	for value: Variant in sea.get("swimmers", []):
		var id := String(value)
		if not roster_ids.has(id):
			problems.append("%s names '%s', which is not in the roster" % [AQUATIC_KEY, id])
			continue
		_swimmers[id] = true

	# A rule that names nothing is not a rule. Silence here is the exact failure the
	# design says must fail loudly at startup rather than quietly at runtime.
	if not rules.is_empty():
		if _banned.is_empty() and not (ban.get("classes", []) as Array).is_empty():
			problems.append("%s resolved to no classes at all" % BANNED_KEY)
		if _capped.is_empty() and not (cap.get("classes", []) as Array).is_empty():
			problems.append("%s resolved to no classes at all" % CEILING_KEY)
		# Worse than silence: an armed aquatic rule with no swimmers reverts every creature
		# the player draws, which is a level that cannot be finished rather than one that
		# says nothing.
		if _aquatic_armed and _swimmers.is_empty():
			problems.append("%s resolved to no swimmers at all" % AQUATIC_KEY)
	return problems


func is_armed() -> bool:
	return not _banned.is_empty() or not _capped.is_empty() or _aquatic_armed


func banned_classes() -> PackedStringArray:
	var out := PackedStringArray(_banned.keys())
	out.sort()
	return out


func capped_classes() -> PackedStringArray:
	var out := PackedStringArray(_capped.keys())
	out.sort()
	return out


# --- The size rule, answered first ---------------------------------------------------

func is_banned(entity_id: String) -> bool:
	return _banned.has(entity_id)


## Why it was refused, in the fiction rather than in the rule. "Too small" is a property of
## the drawing; "they will not be looking down" is a property of the plaza, and only one of
## those tells the player what to do instead.
func refusal_note(entity_id: String) -> String:
	if not is_banned(entity_id):
		return ""
	if _banned_fiction.is_empty():
		return "Not that one, apo. Not today."
	return "Not that one, apo — %s. Draw something the crowd will see." % _banned_fiction


## The one call the level's `_extra_refusals` hook needs. Emits so the level can say it
## without this node knowing what a hint bar is.
func refuses(entity_id: String) -> bool:
	if not is_banned(entity_id):
		return false
	submission_refused.emit(entity_id, refusal_note(entity_id))
	return true


# --- The ceiling, which is a place rather than a class -------------------------------

## Where the bandaritas are strung in the scene the player is standing in. PER SCENE, not
## one number for the level: the design's whole argument is that the boundary is the art,
## so it lives wherever the art put it. A scene with no line calls this with -INF and the
## rule stands down there.
func set_ceiling(world_y: float) -> void:
	_ceiling_y = world_y


func ceiling() -> float:
	return _ceiling_y


## Cutting the line lifts the cap for the rest of the level. This is what turns the cut into
## a trade rather than a free choice: climbing preserves the town, cutting buys the sky.
func lift() -> void:
	_lifted = true


func is_lifted() -> bool:
	return _lifted


func lift_flag() -> String:
	return _lift_flag


func caps(entity_id: String) -> bool:
	return _capped.has(entity_id) and not _lifted


## ⚠ Y GROWS DOWNWARD. Being ABOVE the line means a SMALLER y than the line's, and writing
## this comparison the intuitive way round is a ceiling that triggers everywhere except
## where it should. Stated rather than assumed, because the inverse of this exact mistake
## shipped in a test earlier in this level's work.
func crossed(entity_id: String, world_y: float) -> bool:
	if not caps(entity_id) or _ceiling_y == -INF:
		return false
	return world_y < _ceiling_y


## How far over the line, for the message and the telemetry. Zero when it is not a crossing.
func height_over(entity_id: String, world_y: float) -> float:
	if not crossed(entity_id, world_y):
		return 0.0
	return _ceiling_y - world_y


## The whole per-frame question, so the level asks once and this owns the answer.
func check_height(entity_id: String, world_y: float) -> bool:
	if not crossed(entity_id, world_y):
		return false
	ceiling_crossed.emit(entity_id, height_over(entity_id, world_y))
	return true


# --- The medium, which is a property of the body rather than of the place --------------

func aquatic_rule_armed() -> bool:
	return _aquatic_armed


func swimmer_classes() -> PackedStringArray:
	var out := PackedStringArray(_swimmers.keys())
	out.sort()
	return out


func swims(entity_id: String) -> bool:
	return _swimmers.has(entity_id)


## Would this class flounder if it were in the water? A question about the class only -- the
## water is the caller's to know, the same way the ceiling's height is.
func flounders(entity_id: String) -> bool:
	return _aquatic_armed and not entity_id.is_empty() and not _swimmers.has(entity_id)


func flounder_seconds() -> float:
	return _flounder_seconds


## Why it is going under, in the fiction rather than in the rule -- the same reasoning as
## refusal_note. "Wrong required_medium" is a property of the manifest; "it cannot breathe
## down here" is a property of the sea, and only one of those is something Lolo would say.
func flounder_note(entity_id: String) -> String:
	if not flounders(entity_id):
		return ""
	if _flounder_fiction.is_empty():
		return "Not down here, apo. It cannot breathe."
	return "Not down here, apo — %s." % _flounder_fiction


## The whole per-frame question, mirroring check_height: the level says what it is and where
## it is, and this owns the clock. Returns true on the ONE frame the flounder is over, which
## is the level"s cue to revert. Leaving the water, or becoming something else, puts the
## beat back -- a creature that was rescued half-drowned should get its whole beat next time.
func check_medium(entity_id: String, in_water: bool, delta: float) -> bool:
	if not in_water or not flounders(entity_id):
		_floundering_id = ""
		_floundering_for = 0.0
		return false
	if entity_id != _floundering_id:
		_floundering_id = entity_id
		_floundering_for = 0.0
	_floundering_for += maxf(0.0, delta)
	if _floundering_for < _flounder_seconds:
		return false
	_floundering_id = ""
	_floundering_for = 0.0
	floundered.emit(entity_id, flounder_note(entity_id))
	return true


## How far into its flounder the current body is, 0-1, for a level that wants to show it.
func flounder_ratio() -> float:
	if _floundering_id.is_empty() or _flounder_seconds <= 0.0:
		return 0.0
	return clampf(_floundering_for / _flounder_seconds, 0.0, 1.0)
