class_name LevelDirector
extends Node
## The level's brain: which obstacle the player is at, what it will accept, how much help
## they have been given, and what gets written down about it.
##
## It owns no scene nodes and draws nothing. Obstacles report entry to it, the draw panel
## reports submissions to it, and it answers one question -- "does this drawing solve what
## is in front of you?" -- from level_01.json rather than from anything authored in the
## scene. That is what keeps an obstacle's difficulty a data edit.
##
## THE HINT LADDER IS THE PART THAT NEEDS EXPLAINING. Four tiers, and only the last one
## changes what the game will accept:
##
##   T0  on approach          flavour. No tag named
##   T1  canvas opens, or 30s the required tags, by name. Never a class
##   T2  2 failures, or 90s   the Ability Book, required tags lit, and the player's OWN
##                            qualifying drawings -- still not a class they do not have
##   T3  4 failures, or 3min  the accept-set widens to the union of all three routes
##
## T3 is what replaces per-obstacle fallback authoring: one rule, no special cases, and a
## stuck Protector at Node 2 can solve with a rake. **The tally still records the choice
## made at the dialogue, not the solution used**, so route identity survives being helped
## -- and the attempt is flagged assisted so Chapter 5 can exclude it from unassisted
## statistics rather than quietly inflating them.

signal obstacle_entered(obstacle_id: String)
signal obstacle_exited(obstacle_id: String)
signal route_committed(obstacle_id: String, route: String)
signal obstacle_solved(obstacle_id: String, route: String, label: String, attempts: int, hint_tier: int)
signal hint_tier_changed(obstacle_id: String, tier: int)
signal tag_unlocked(tag: String)
signal requirements_changed(obstacle_id: String, required_tags: Array)

const LEVEL_PATH := "res://config/level_01.json"

## Seconds of standing at an obstacle before the next tier opens on its own, and the
## number of failed attempts that opens it early. Either trigger is enough: a player who
## is trying and failing and one who is stuck staring both want help, and only one of
## them is generating attempts.
const TIER_IDLE_SECONDS := [0.0, 30.0, 90.0, 180.0]
const TIER_ATTEMPTS := [0, 0, 2, 4]
const MAX_TIER := 3

var _level: Dictionary = {}
var _obstacles: Dictionary = {}      # id -> Dictionary
var _order: Array[String] = []

var _current := ""
var _committed: Dictionary = {}      # obstacle id -> route name
var _stage: Dictionary = {}          # obstacle id -> int, for multi-step routes
var _solved: Dictionary = {}         # obstacle id -> true
var _attempts: Dictionary = {}       # obstacle id -> int
var _tier: Dictionary = {}           # obstacle id -> int
var _dwell: Dictionary = {}          # obstacle id -> seconds at this obstacle
var _assisted: Dictionary = {}       # obstacle id -> true when solved at T3
var _declines := 0

var _tags: Node
var _profile: Node
var _telemetry: Node


func _ready() -> void:
	# By path, not by name: see ability_tags.gd for why every autoload reference in this
	# project looks like this.
	_tags = get_node_or_null(^"/root/AbilityTags")
	_profile = get_node_or_null(^"/root/PlayerProfile")
	_telemetry = get_node_or_null(^"/root/Telemetry")


func load_level(path: String = LEVEL_PATH) -> bool:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("LevelDirector: %s is missing or empty" % path)
		return false
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("LevelDirector: %s is not a JSON object" % path)
		return false
	_level = parsed as Dictionary
	_obstacles.clear()
	_order.clear()
	for obstacle_value: Variant in _level.get("obstacles", []):
		var obstacle: Dictionary = obstacle_value
		var id := String(obstacle.get("id", ""))
		if id.is_empty():
			continue
		_obstacles[id] = obstacle
		_order.append(id)
	return true


## The raw level document, for the few callers that need something the director does not
## model -- the declared checkpoint list, so a walk-in checkpoint can be validated against
## it rather than trusted.
func level_data() -> Dictionary:
	return _level.duplicate(true)


func level_id() -> String:
	return String(_level.get("level_id", ""))


func display_name() -> String:
	return String(_level.get("display_name", ""))


func obstacle_ids() -> Array[String]:
	return _order.duplicate()


func obstacle(id: String) -> Dictionary:
	return (_obstacles.get(id, {}) as Dictionary).duplicate(true)


func current_obstacle() -> String:
	return _current


func is_solved(id: String) -> bool:
	return _solved.has(id)


func committed_route(id: String) -> String:
	return String(_committed.get(id, ""))


func attempts(id: String) -> int:
	return int(_attempts.get(id, 0))


func was_assisted(id: String) -> bool:
	return _assisted.has(id)


# --- Presence ----------------------------------------------------------------

func enter_obstacle(id: String) -> void:
	if not _obstacles.has(id) or _current == id:
		return
	_current = id
	if not _tier.has(id):
		_tier[id] = 0
		_dwell[id] = 0.0
	obstacle_entered.emit(id)
	_emit_requirements()


func exit_obstacle(id: String) -> void:
	if _current != id:
		return
	_current = ""
	obstacle_exited.emit(id)


func _process(delta: float) -> void:
	# Dwell only accrues at an unsolved obstacle. A player standing at a solved one is
	# looking at the view, not stuck, and escalating at them would be the game nagging.
	if _current.is_empty() or _solved.has(_current):
		return
	_dwell[_current] = float(_dwell.get(_current, 0.0)) + delta
	_reconsider_tier(_current)


# --- Hints -------------------------------------------------------------------

func hint_tier(id: String = "") -> int:
	var key := _current if id.is_empty() else id
	return int(_tier.get(key, 0))


func _reconsider_tier(id: String) -> void:
	var current := int(_tier.get(id, 0))
	var dwell := float(_dwell.get(id, 0.0))
	var failed := int(_attempts.get(id, 0))
	var wanted := current
	for tier in range(current + 1, MAX_TIER + 1):
		var by_time: bool = dwell >= TIER_IDLE_SECONDS[tier]
		var by_failure: bool = TIER_ATTEMPTS[tier] > 0 and failed >= TIER_ATTEMPTS[tier]
		if by_time or by_failure:
			wanted = tier
	if wanted != current:
		_tier[id] = wanted
		hint_tier_changed.emit(id, wanted)
		_emit_requirements()


## The canvas opening is itself a request for help -- the player has decided to draw
## something and does not yet know what. T1 is the floor from that moment.
func note_canvas_opened() -> void:
	if _current.is_empty() or _solved.has(_current):
		return
	if int(_tier.get(_current, 0)) < 1:
		_tier[_current] = 1
		hint_tier_changed.emit(_current, 1)
		_emit_requirements()


# --- Requirements ------------------------------------------------------------

## What the obstacle in front of the player needs, right now: after a route commit it is
## that route's stage; before one it is every route's tags, because the player has not
## chosen yet and the strip must not pre-empt the choice.
func requirement_spec(id: String = "") -> Dictionary:
	var key := _current if id.is_empty() else id
	if not _obstacles.has(key):
		return {}
	var obstacle: Dictionary = _obstacles[key]
	var route := String(_committed.get(key, ""))

	if not route.is_empty():
		var routes: Dictionary = obstacle.get("routes", {})
		var spec: Dictionary = routes.get(route, {})
		var stage := int(_stage.get(key, 0))
		if stage > 0 and spec.has("then"):
			return spec["then"]
		return spec

	# Beat 0 has no routes; it has sub-beats taken in order.
	var subs: Array = obstacle.get("sub_beats", [])
	if not subs.is_empty():
		var index: int = mini(int(_stage.get(key, 0)), subs.size() - 1)
		return subs[index]

	# A dialogue node before its choice: show every route's requirement.
	return _union_spec(obstacle)


## The id of the stage currently being attempted. Beat 0's sub-beats have their own ids
## ("sub1", "sub2") and their own dialogue; a route's stages do not, and answer "".
func stage_id(id: String = "") -> String:
	var key := _current if id.is_empty() else id
	if not _obstacles.has(key):
		return ""
	if not String(_committed.get(key, "")).is_empty():
		return ""
	var subs: Array = (_obstacles[key] as Dictionary).get("sub_beats", [])
	if subs.is_empty():
		return ""
	var index: int = mini(int(_stage.get(key, 0)), subs.size() - 1)
	return String((subs[index] as Dictionary).get("id", ""))


func _union_spec(obstacle: Dictionary) -> Dictionary:
	var union: Array = []
	for route_value: Variant in (obstacle.get("routes", {}) as Dictionary).values():
		for tag_value: Variant in (route_value as Dictionary).get("required_tags", []):
			if not union.has(tag_value):
				union.append(tag_value)
	return {"required_tags": union, "match": "any", "exclude": []}


func required_tags(id: String = "") -> Array:
	return (requirement_spec(id).get("required_tags", []) as Array).duplicate()


## The classes that would be accepted right now. At T3 this widens to every route's tags
## -- the one place a hint changes the rules rather than the wording.
func accept_set(id: String = "") -> PackedStringArray:
	var key := _current if id.is_empty() else id
	if _tags == null or not _obstacles.has(key):
		return PackedStringArray()
	var spec := requirement_spec(key)
	if hint_tier(key) >= MAX_TIER:
		spec = _union_spec(_obstacles[key])
		# A union that lands empty means the obstacle has no routes (Beat 0); fall back
		# to its own requirement rather than accepting nothing, which would make the most
		# generous tier the harshest.
		if (spec.get("required_tags", []) as Array).is_empty():
			spec = requirement_spec(key)
	return _tags.call("resolve",
		spec.get("required_tags", []),
		String(spec.get("match", "all")),
		spec.get("exclude", [])) as PackedStringArray


func _emit_requirements() -> void:
	if not _current.is_empty():
		requirements_changed.emit(_current, required_tags(_current))


# --- Routes and tags ---------------------------------------------------------

## Teach a tag. Ordering is a design rule with teeth: a node teaches all three of its
## routes' tags in the dialogue BEFORE presenting the choice, because a player cannot
## choose a route whose verb they do not know.
func unlock_tag(tag: String) -> void:
	if _tags == null or bool(_tags.call("is_unlocked", tag)):
		return
	_tags.call("unlock", tag)
	tag_unlocked.emit(tag)
	if _telemetry != null:
		_telemetry.call("record_event", "tag_unlocked", {"level_id": level_id(), "tag": tag})


func teach_before_choice(id: String) -> void:
	for tag_value: Variant in (obstacle(id).get("teaches_before_choice", []) as Array):
		unlock_tag(String(tag_value))


## The player has answered the node. This is the moment a checkpoint is written -- see
## checkpoint_manager.gd for why here and not at the solve.
func commit_route(id: String, route: String) -> void:
	if not _obstacles.has(id) or _committed.has(id):
		return
	var routes: Dictionary = (_obstacles[id] as Dictionary).get("routes", {})
	if not routes.has(route):
		push_warning("LevelDirector: %s has no route '%s'" % [id, route])
		return
	_committed[id] = route
	_stage[id] = 0
	if _profile != null:
		_profile.call("record_route", level_id(), route)
	route_committed.emit(id, route)
	_emit_requirements()
	if _telemetry != null:
		_telemetry.call("record_event", "route_committed", {
			"level_id": level_id(), "obstacle_id": id, "route": route,
		})


# --- Submissions -------------------------------------------------------------

## Judge a recognised drawing against whatever is in front of the player.
##
## Returns { solves, obstacle_id, route, required_tags, tag_match, stage_advanced,
##           obstacle_complete, assisted, attempts, hint_tier }.
##
## `tag_match` is the first-intent metric and is deliberately NOT the same as `solves`:
## it records whether the class the player reached for carried the required tag, before
## T3's widening is applied. A drawing that only passes because the player was helped is
## a solve and is not a match, and collapsing the two would let assistance inflate the
## headline number.
func note_submission(entity_id: String) -> Dictionary:
	var id := _current
	var verdict := {
		"solves": false, "obstacle_id": id, "route": String(_committed.get(id, "")),
		"required_tags": required_tags(id), "tag_match": false,
		"stage_advanced": false, "obstacle_complete": false,
		"assisted": false, "attempts": attempts(id), "hint_tier": hint_tier(id),
		"stage_id": stage_id(id),
	}
	if id.is_empty() or _solved.has(id) or _tags == null:
		return verdict

	var strict := _strict_accept_set(id)
	var effective := accept_set(id)
	verdict["tag_match"] = strict.has(entity_id)
	verdict["solves"] = effective.has(entity_id)
	verdict["assisted"] = verdict["solves"] and not verdict["tag_match"]

	if not verdict["solves"]:
		_attempts[id] = attempts(id) + 1
		verdict["attempts"] = _attempts[id]
		_reconsider_tier(id)
		verdict["hint_tier"] = hint_tier(id)
		_record_attempt(entity_id, verdict)
		return verdict

	# Solved this stage. A route with a `then`, or a beat with more sub-beats, advances
	# instead of completing -- Node 1's Artist route spans the gorge and then still has
	# to climb the far abutment.
	if _has_next_stage(id):
		_stage[id] = int(_stage.get(id, 0)) + 1
		verdict["stage_advanced"] = true
		_emit_requirements()
	else:
		_solved[id] = true
		verdict["obstacle_complete"] = true
		if verdict["assisted"]:
			_assisted[id] = true
		obstacle_solved.emit(id, verdict["route"], entity_id, attempts(id), hint_tier(id))
	_record_attempt(entity_id, verdict)
	return verdict


## What the obstacle would accept with no help at all. Kept separate from accept_set()
## precisely so T3 cannot reach it.
func _strict_accept_set(id: String) -> PackedStringArray:
	var spec := requirement_spec(id)
	return _tags.call("resolve",
		spec.get("required_tags", []),
		String(spec.get("match", "all")),
		spec.get("exclude", [])) as PackedStringArray


func _has_next_stage(id: String) -> bool:
	var obstacle: Dictionary = _obstacles.get(id, {})
	var stage := int(_stage.get(id, 0))
	var route := String(_committed.get(id, ""))
	if not route.is_empty():
		var spec: Dictionary = (obstacle.get("routes", {}) as Dictionary).get(route, {})
		return stage == 0 and spec.has("then")
	var subs: Array = obstacle.get("sub_beats", [])
	return stage + 1 < subs.size()


func _record_attempt(entity_id: String, verdict: Dictionary) -> void:
	if _telemetry == null:
		return
	_telemetry.call("record_event", "obstacle_attempt", {
		"level_id": level_id(),
		"obstacle_id": verdict["obstacle_id"],
		"route": verdict["route"],
		"required_tags": verdict["required_tags"],
		"accepted_label": entity_id,
		"tag_match": verdict["tag_match"],
		"solves": verdict["solves"],
		"assisted": verdict["assisted"],
		"attempts": verdict["attempts"],
		"hint_tier": verdict["hint_tier"],
	})


## A declined recognition is not an attempt at the obstacle -- the recogniser never got
## far enough to have an opinion about the tag -- but the level still wants to know, and
## the refusal beat fires on the first one anywhere.
func note_decline(reason: String) -> int:
	_declines += 1
	if not _current.is_empty() and not _solved.has(_current):
		_reconsider_tier(_current)
	if _telemetry != null:
		_telemetry.call("record_event", "recognition_declined_at_obstacle", {
			"level_id": level_id(), "obstacle_id": _current,
			"reason": reason, "decline_index": _declines,
		})
	return _declines


func decline_count() -> int:
	return _declines


# --- Snapshot ----------------------------------------------------------------

## Obstacle state for a checkpoint. Deliberately not the whole director: dwell and hint
## tier are NOT restored, because a player who has been helped has been helped, and
## resetting them would re-hide a hint they have already read.
func obstacle_state() -> Dictionary:
	return {
		"committed": _committed.duplicate(true),
		"stage": _stage.duplicate(true),
		"solved": _solved.duplicate(true),
		"assisted": _assisted.duplicate(true),
		"attempts": _attempts.duplicate(true),
	}


func restore_obstacle_state(state: Dictionary) -> void:
	_committed = (state.get("committed", {}) as Dictionary).duplicate(true)
	_stage = (state.get("stage", {}) as Dictionary).duplicate(true)
	_solved = (state.get("solved", {}) as Dictionary).duplicate(true)
	_assisted = (state.get("assisted", {}) as Dictionary).duplicate(true)
	_attempts = (state.get("attempts", {}) as Dictionary).duplicate(true)
	_emit_requirements()
