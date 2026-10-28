extends "res://scripts/level_base.gd"
## LEVEL 5 -- MAYON. The last painting, coming apart while the apo stands in it.
##
## Extended BY PATH rather than by `class_name LevelBase`, for the reason every level is: a
## `--script` run does not register class names and the probes are exactly that.
##
## What this level is, in the machine's terms (LEVEL_5.md has the design and why):
##
##   * NO COMBAT, NO HEALTH. The antagonist is the clock and the ink.
##   * THE INK IS THE STORY. Six units, every drawing costs one, a creature form drains it, and
##     nothing on the mountain gives any back. The gauge never steps aside. Two units nobody sees
##     keep the climb's two gates always payable (`_may_use_hidden_ink`): a player locked out of
##     the climax by over-spending would be a disaster.
##   * ONE CONTINUOUS ASCENT. The checkpoints are written without a word.
##   * IT ENDS WITH ITS OWN SCENE. The summit and the frame's return are the ending (Kent,
##     2026-10-25); until they are built, finishing takes her home.
##
## This is the shell: the climb and its gates. The fragments, Lolo's thread, the summit and the
## frame come with their PRs.


func level_config_path() -> String:
	return "res://config/level_05.json"


func dialogue_path() -> String:
	return "res://config/dialogue_l5.json"


## How far under the mountain's lowest ground a fall goes before she is put back.
const FALL_BELOW := 1000.0
## The gates the climb cannot be finished without: the hidden reserve pays for them.
const GATES := ["L5_SPAN", "L5_CLIMB"]


## Every drawing costs a unit, not only the first of its kind: there is no clearing here to give
## any back, and what she spends is the story.
func _every_drawing_costs_ink() -> bool:
	return true


## Only a gate may draw on the reserve, and only while she stands in it.
func _may_use_hidden_ink(_entity_id: String) -> bool:
	return director != null and String(director.current_obstacle()) in GATES


func _saves_silently() -> bool:
	return true


func _ink_always_visible() -> bool:
	return true


## A climb as tall as it is wide: the camera centres on her rather than pinning the ground.
func _camera_follows_height() -> bool:
	return true


func _ends_with_its_own_scene() -> bool:
	return true


## The summit and the frame's return are the ending (PR 08, 09). Until then, home.
func _play_own_ending() -> void:
	LevelManager.return_to_house()


func _checkpoint_place(checkpoint_id: String) -> String:
	match checkpoint_id:
		"CP1":
			return "the mid slope"
		"CP2":
			return "below the summit"
	return super(checkpoint_id)


## The ink economy's own numbers: the drain while a form is held, and the reserve nobody sees.
func _build_level_furniture() -> void:
	super()
	var economy: Dictionary = director.level_data().get("ink_economy", {})
	ink_manager.hidden_reserve = float(economy.get("hidden_reserve", 0.0))
	_arm_the_drain()


func _level_physics(anchor_position: Vector2) -> void:
	if anchor_position.y > _lowest_ground() + FALL_BELOW:
		var words := _line("FELL")
		_return_to_safety(words, words)
		return
	_hold_the_drain(get_physics_process_delta_time())


func _on_ink_emptied() -> bool:
	_speak(script_lines.fire("INK.empty"))
	return true


## The banner: the gate she stands at, while it is open; the climb everywhere else.
func _current_objective() -> Dictionary:
	if director == null:
		return {}
	match String(director.current_obstacle()):
		"L5_SPAN":
			return {"key": "span"} if not director.is_solved("L5_SPAN") else {"key": "slope"}
		"L5_CLIMB":
			return {"key": "climb"} if not director.is_solved("L5_CLIMB") else {"key": "slope"}
	if player != null and is_instance_valid(player) and player.global_position.x < 1400.0:
		return {"key": "foot"}
	return {"key": "slope"}


func _lowest_ground() -> float:
	return 600.0


## A line's own words, for the rescue's hint (it takes text, not a line).
func _line(hook: String) -> String:
	var lines := script_lines.fire(hook)
	return String((lines[0] as Dictionary).get("text", "")) if not lines.is_empty() else ""


# --- A drawn body costs ink while it is held ------------------------------------------------

## As in Dilim: a creature's body is paid for in ink -- level_05.json's creature_drain_per_second
## -- for as long as she holds it, and there is no ten-second clock. At none she is herself again.
var _drain: InkDrain


func _morph_has_a_life() -> bool:
	return false


func _arm_the_drain() -> void:
	_drain = get_node_or_null(^"InkDrain") as InkDrain
	if _drain == null:
		return
	_drain.bind(ink_manager)
	var economy: Dictionary = director.level_data().get("ink_economy", {})
	_drain.default_rate = float(economy.get("creature_drain_per_second", _drain.default_rate))
	_drain.ink_emptied.connect(_revert_to_base_form)


func _hold_the_drain(delta: float) -> void:
	if _drain == null:
		return
	if _current_form_id.is_empty():
		if _drain.is_draining():
			_drain.clear()
		return
	if _drain.form_id() != _current_form_id:
		_drain.begin(_current_form_id)
	_drain.charge(delta)
	if morph_card != null:
		morph_card.set_meter_caption("INK")
		morph_card.set_drain(ink_manager.remaining(), ink_manager.capacity)
