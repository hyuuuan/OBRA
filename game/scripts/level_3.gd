extends "res://scripts/level_base.gd"
## LEVEL 3 -- DAGAT. The sea, and the rule that replaces the clock.
##
## Extended BY PATH rather than by `class_name LevelBase`, for the reason game_level.gd and
## level_2.gd are: a `--script` run does not register class names and the probes are exactly
## that.
##
## What this level adds to the machine that neither of the first two needed:
##
##   * NO MORPH CLOCK. `_morph_has_a_life()` answers false once the new brush is found, so
##     MorphLife.begin is never called and a form is held for as long as the ink lasts. The
##     MorphCard's gauge is re-captioned INK and fed from here.
##   * A ZERO CASE THAT IS NOT A LOSS SCREEN. `_on_ink_emptied()` takes the out-of-ink
##     overlay off the table and does the design's own thing instead: revert, carry the apo
##     up to the surface, lose the crossing, never die.
##   * NO DROWNING RESCUE. `_rescues_a_swimming_apo()` answers false. The base fishes an
##     un-morphed apo out of deep water after 1.1 s, which is right when water is a gate and
##     is a rescue loop when the level IS the sea.
##   * A SECOND DIALOGUE NODE. Piyesta committed two of its three beats implicitly, through
##     the drawing. Dagat cannot: the bakunawa's Pragmatist resolution is not a drawing at
##     all, so it has to be offered out loud, and a level with two spoken forks needs two
##     volumes and a `_dialogue_node_obstacle_id()` that answers for whichever one is live.
##
## ⚠ THE DRAIN IS THE LEVEL'S, NOT THE BRUSH'S. `has_new_brush()` is a profile flag and it
## survives into Levels 4 and 5 -- but it is consulted HERE, by this level, and Payyo and
## Piyesta never ask. A player who finds the brush and then replays a memory gets that
## memory's rules back, which is the whole reason the hook is a level virtual.

const RestrictionsClass = preload("res://scripts/level_restrictions.gd")

## Where the waterline sits, read off the mark rather than typed twice. Everything below it
## is the sea: the aquatic rule is armed there and nowhere else, because the shore and a
## boat's deck are air.
var _waterline_y := INF

var _marks: Node2D
var _sea: WaterArea2D
var _restrictions: LevelRestrictions
var _drain: InkDrain

## The second spoken fork. See the header.
var _bakunawa_node: DialogueNode2D
## Which beat the choice overlay is currently answering for. Set when a node is approached,
## because `_dialogue_node_obstacle_id()` is asked at both the presenting and the committing
## and has to give the same answer to each.
var _live_node_obstacle := "L3_N1"

## Latches, so a lesson and a line are each spent once per run rather than once per frame.
var _said_underwater := false
var _brush_taken := false


# --- What the machine asks -------------------------------------------------------------

func level_config_path() -> String:
	return "res://config/level_03.json"


func dialogue_path() -> String:
	return "res://config/dialogue_l3.json"


func _dialogue_node_obstacle_id() -> String:
	return _live_node_obstacle


func _resolve_level_nodes() -> void:
	var plane := ^"EnvironmentBaseplate/GameplayPlane"
	dialogue_node = get_node_or_null(
		plane.get_concatenated_names() + "/DialogueNode") as DialogueNode2D
	_bakunawa_node = get_node_or_null(
		plane.get_concatenated_names() + "/BakunawaNode") as DialogueNode2D
	_sea = get_node_or_null(plane.get_concatenated_names() + "/Sea") as WaterArea2D
	_marks = get_node_or_null(plane.get_concatenated_names() + "/Marks") as Node2D
	var waterline := _mark("WaterlineMark")
	if waterline != null:
		_waterline_y = waterline.global_position.y


func _mark(mark_name: String) -> Node2D:
	return _marks.get_node_or_null(NodePath(mark_name)) as Node2D if _marks != null else null


func _build_level_furniture() -> void:
	_restrictions = RestrictionsClass.new()
	_restrictions.name = "LevelRestrictions"
	add_child(_restrictions)
	for problem: Variant in _restrictions.load_from(director.level_data(), _roster_ids()):
		# LOUD AT STARTUP, never quiet at runtime. A swimmer list that resolves to nothing
		# does not fail open the way a ban list does -- it drowns every creature drawn here.
		push_error("Level3: %s" % problem)
	_restrictions.floundered.connect(_on_floundered)

	# ⚠ NOT set_refusal_filter. Piyesta hands the director its ban list so the hint ladder
	# stops offering what the level will refuse; here there is nothing to refuse. A land
	# creature is a legal answer that turns out to be a bad one, and the tag layer should go
	# on offering it -- the level says no with the world, not at the canvas.

	_drain = get_node_or_null(^"InkDrain") as InkDrain
	if _drain != null:
		_drain.bind(ink_manager)
		var economy: Dictionary = director.level_data().get("ink_economy", {})
		_drain.default_rate = float(economy.get("default_rate_per_second", _drain.default_rate))
		_drain.warning_ratio = float(economy.get("warning_ratio", _drain.warning_ratio))
		_drain.rates = economy.get("rates", {})
		_drain.low_ink.connect(_on_low_ink)
		_drain.ink_emptied.connect(_on_drain_emptied)

	_plant_the_brush()


func _roster_ids() -> PackedStringArray:
	var out := PackedStringArray()
	if registry == null:
		return out
	for id: Variant in registry.get_entity_ids():
		out.append(String(id))
	return out


## THE NEW BRUSH, glinting in the wet sand. A pickup rather than an obstacle: a sub-beat
## resolves a tag, and picking something up is not a drawing.
##
## ⚠ CODE-DRAWN, AND THAT IS THE CONTRACT, NOT THE ART. Nothing on Dagat's asset list exists
## yet, so this is a shape with the right size, the right place and the right behaviour,
## the way Payyo's props were before they were painted. ART_PLACEHOLDERS.md is where its
## contract goes: the design asks for something that reads as a different tool from
## magicbrush.png at a glance, in silhouette and colour.
func _plant_the_brush() -> void:
	if PlayerProfile.has_new_brush():
		_brush_taken = true
		return
	var mark := _mark("BrushMark")
	if mark == null:
		return
	var pickup := Area2D.new()
	pickup.name = "NewBrush"
	pickup.collision_layer = 0
	pickup.collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 44.0
	shape.shape = circle
	pickup.add_child(shape)
	var art := Polygon2D.new()
	art.polygon = PackedVector2Array([
		Vector2(-26, 10), Vector2(14, -14), Vector2(22, -4), Vector2(-18, 20)])
	art.color = Color(0.94, 0.86, 0.58, 1.0)
	pickup.add_child(art)
	pickup.global_position = mark.global_position
	pickup.z_index = 8
	mark.get_parent().add_child(pickup)
	pickup.body_entered.connect(_on_brush_touched.bind(pickup))


func _on_brush_touched(body: Node, pickup: Area2D) -> void:
	if _brush_taken or not body.is_in_group(&"player_character"):
		return
	_brush_taken = true
	PlayerProfile.record_new_brush()
	if tutorial != null:
		tutorial.note("new_brush_taken")
	# ⚠ THE CAPTION CHANGES HERE AND NOT AT THE NEXT MORPH. From this moment the gauge is
	# measuring ink, and a card still captioned LIFE over a bar fed by the drain is the exact
	# confusion the shore beat exists to prevent.
	if morph_card != null:
		morph_card.set_meter_caption("INK")
	_say_why("Take it, apo. Hers is spent — this one was waiting for you.")
	pickup.queue_free()


## The second fork, wired beside the first. `super()` still owns the overlay and the memory
## screen; this only adds the volume Piyesta had no equivalent of.
func _wire_dialogue_node() -> void:
	super()
	if _bakunawa_node == null:
		return
	_bakunawa_node.approached.connect(_on_bakunawa_approached)
	_bakunawa_node.route_chosen.connect(_on_route_chosen)


# --- The three rules this level changes -------------------------------------------------

## FALSE ONCE THE BRUSH IS FOUND, and true before it. The shore is played under the old rule
## on purpose: the design wants the replacement taught before the fork, and a player who has
## not picked the brush up yet has not been told anything about ink.
func _morph_has_a_life() -> bool:
	return not PlayerProfile.has_new_brush()


## The ink ran out. The design's own words, and none of them is a loss: "the transformation
## reverts and the apo is carried up to the surface or to the nearest air pocket, losing
## progress on the crossing but never dying."
func _on_ink_emptied() -> bool:
	if not PlayerProfile.has_new_brush():
		return false
	return true


func _rescues_a_swimming_apo() -> bool:
	# The apo still cannot swim. What is different here is the consequence: being in the
	# water without a body is the ink-zero case, handled below, rather than a teleport.
	return false


# --- Per frame --------------------------------------------------------------------------

func _level_physics(anchor_position: Vector2) -> void:
	var delta := get_physics_process_delta_time()
	var underwater := anchor_position.y > _waterline_y

	if underwater and not _said_underwater:
		_said_underwater = true
		if tutorial != null:
			tutorial.note("underwater")

	# ⚠ THE DRAIN ONLY RUNS WHILE A FORM IS HELD, and `_current_form_id` is the only thing
	# that knows. Charging on "the player is not a Wanderer" would keep charging through the
	# frame a rig fails to build, which is the one frame the player has no body at all.
	if _drain == null or not PlayerProfile.has_new_brush():
		return
	if _current_form_id.is_empty():
		if _drain.is_draining():
			_drain.clear()
	else:
		if _drain.form_id() != _current_form_id:
			_drain.begin(_current_form_id)
			if tutorial != null:
				tutorial.note("ink_draining")
		_drain.charge(delta)
		if morph_card != null:
			morph_card.set_meter_caption("INK")
			morph_card.set_drain(ink_manager.remaining(), ink_manager.capacity)
		# The medium rule, asked once per frame the way the ceiling is. It owns its own
		# clock, so a creature that leaves the water gets its whole beat back next time.
		_restrictions.check_medium(_current_form_id, underwater, delta)


# --- What happens when a rule bites -----------------------------------------------------

## A land creature has floundered for its beat. Revert through the SAME door Q uses -- never
## a second copy of it, which is a second chance to strand the player in a body that is gone.
func _on_floundered(_entity_id: String, note: String) -> void:
	_say_why(note)
	_revert_to_base_form()
	_carry_to_the_surface()


func _on_low_ink(_remaining: float, _capacity: float) -> void:
	if tutorial != null:
		tutorial.note("ink_low")
	_say_why("It is nearly gone, apo.")


## THE ZERO CASE. Revert, carry up, lose the crossing, never die. There is no death state
## anywhere in this game and none is being added here.
func _on_drain_emptied() -> void:
	if tutorial != null:
		tutorial.note("ink_emptied")
	_say_why("Out. Up you come — you lost the crossing, nothing else.")
	_revert_to_base_form()
	_carry_to_the_surface()


## ⚠ THROUGH apply_morph_state, NOT global_position. Whatever the player is, its bodies may
## be top_level, and writing the node's position moves the node and leaves the physics where
## it was. The same trap run_water_audit.gd documents.
func _carry_to_the_surface() -> void:
	if player == null or not is_instance_valid(player):
		return
	if not player.has_method("apply_morph_state"):
		return
	var anchor := player.call("get_physics_anchor") as Node2D
	var here: Vector2 = anchor.global_position if anchor != null else player.global_position
	# Straight up to the nearest air, keeping the x: the crossing is lost, not the progress
	# along it, and dragging the player back to the shore as well would make running out of
	# ink the harshest thing in a game with no fail state.
	var surface := Vector2(here.x, _waterline_y - 40.0)
	player.call("apply_morph_state", {"position": surface, "linear_velocity": Vector2.ZERO})


# --- The two forks -----------------------------------------------------------------------

func _on_bakunawa_approached() -> void:
	# The base's handler reads `dialogue_node` and `_dialogue_node_obstacle_id()`, so both
	# have to point at this fork before it runs.
	_live_node_obstacle = "L3_N2"
	dialogue_node = _bakunawa_node
	_on_dialogue_node_approached()


func _on_route_solved(obstacle_id: String, route: String) -> bool:
	if obstacle_id == "L3_N1" and route == "artist":
		# The boat is FOUND, not drawn. Nothing to spawn and nothing to judge.
		script_lines.set_flag("heard_how_he_died")
		return false
	if obstacle_id == "L3_N1" and route == "pragmatist":
		script_lines.set_flag("heard_about_lola")
		return false
	if obstacle_id == "L3_N2":
		_close_the_encounter(route)
		return false
	return false


## One place that writes what the encounter was, so the flag, the profile and the flower
## cannot disagree with each other.
func _close_the_encounter(route: String) -> void:
	match route:
		"artist":
			PlayerProfile.record_bakunawa("LIT")
			script_lines.set_flag("l3_bakunawa_lit")
			_award_the_flower()
		"pragmatist":
			PlayerProfile.record_bakunawa("EVADED")
			script_lines.set_flag("l3_bakunawa_evaded")
		"protector":
			PlayerProfile.record_bakunawa("FOUGHT")
			script_lines.set_flag("l3_bakunawa_fought")


## ⚠ THE ID HERE MUST BE IN PlayerProfile.FLOWER_IDS OR THE FLOWER COUNTS FOR NOTHING. The
## level file's `hidden_flowers[].id` is documentation; this string is the fact.
func _award_the_flower() -> void:
	PlayerProfile.record_collectible("L3_HF")
	script_lines.set_flag("has_flower_3")


# --- What the player should be doing now --------------------------------------------------

## DERIVED, NEVER SET -- an objective written at the moment something happened is wrong after
## every checkpoint restore.
func _current_objective() -> Dictionary:
	if director == null:
		return {}
	if not PlayerProfile.has_new_brush():
		return {"key": "brush", "target": _mark_position("BrushMark")}
	if not director.is_solved("L3_B0_SHORE"):
		return {"key": "practice", "obstacle": "L3_B0_SHORE",
			"target": _mark_position("WaterlineMark")}
	if not director.is_solved("L3_N1"):
		return {"key": "cross", "obstacle": "L3_N1", "target": _mark_position("CoralMark")}
	if not director.is_solved("L3_N2"):
		return {"key": "bakunawa", "obstacle": "L3_N2",
			"target": _mark_position("BakunawaMark")}
	return {"key": "island", "target": _mark_position("IslandMark")}


func _mark_position(mark_name: String) -> Variant:
	var mark := _mark(mark_name)
	return mark.global_position if mark != null else null


# --- What a checkpoint has to carry -------------------------------------------------------

## The brush and the encounter's outcome are on the PROFILE and are permanent, so they are
## not here. What is here is the run's own shape: which fork was taken, and the latches that
## stop a lesson being spent twice.
func _level_run_state() -> Dictionary:
	return {
		"live_node": _live_node_obstacle,
		"said_underwater": _said_underwater,
		"brush_taken": _brush_taken,
	}


func _restore_level_run_state(state: Dictionary) -> void:
	_live_node_obstacle = String(state.get("live_node", "L3_N1"))
	_said_underwater = bool(state.get("said_underwater", false))
	_brush_taken = bool(state.get("brush_taken", false))
	# A restore is a new body or none at all, so the drain starts again rather than resuming
	# a form that is no longer standing.
	if _drain != null:
		_drain.clear()
