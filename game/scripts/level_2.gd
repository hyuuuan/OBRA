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

var restrictions: LevelRestrictions
var ledger: ScrapLedger
var assembly: ScrapAssembly
var dance: DanceMinigame

## Where the bandaritas hang in the plaza, read off the scene rather than typed twice.
var _bunting_y := -INF


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
	var line := get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/Marks/BuntingLine") as Node2D
	if line != null:
		_bunting_y = line.global_position.y


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


func _roster_ids() -> PackedStringArray:
	var out := PackedStringArray()
	if registry == null:
		return out
	for id: Variant in registry.get_entity_ids():
		out.append(String(id))
	return out


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
