extends "res://scripts/level_base.gd"
## LEVEL 4 -- DILIM. The dark forest on Mt. Makiling, crossed alone.
##
## Extended BY PATH rather than by `class_name LevelBase`, for the reason every level is: a
## `--script` run does not register class names and the probes are exactly that.
##
## What this level is, in the machine's terms (LEVEL_4.md has the design and why):
##
##   * NO COMPANION. Lolo stopped at the water, so `_has_companion()` is false and every note the
##     level says -- the rescues, the tool notes -- is in the apo's own voice. The opening still
##     plays: it is hers now (dialogue_l4.json).
##   * A LEVEL THAT FIGHTS, built from hooks LevelBase keeps off everywhere else: the lantern as
##     her health, the dark, weapons that wear out, every drawing costing ink. Each is switched on
##     below by itself, so a probe can name the one it is about.
##   * ROUTES ARE CHOSEN BY WHAT SHE DOES. There is no dialogue node and no choice popup: the
##     drawing, or the deed, is the answer, and the level gives the ending one point -- its
##     majority route (`"tally": "majority"` in level_04.json).


func level_config_path() -> String:
	return "res://config/level_04.json"


func dialogue_path() -> String:
	return "res://config/dialogue_l4.json"


## Past what Lolo remembers: she goes on alone.
func _has_companion() -> bool:
	return false


func _companion_speaker() -> String:
	return APO_SPEAKER


## The lantern is her health (Kent): four stages, a hit takes one, a hit at the last puts her back
## where the lantern was last lit.
func _has_player_health() -> bool:
	return true


## Every weapon or light drawn costs a unit of ink, not only the first of its kind (Kent): a sword
## that wears out and is drawn again is paid for again, and the clearings are where ink comes back.
func _every_drawing_costs_ink() -> bool:
	return true


## How many times the lantern has gone out this run, so the RESPAWN pool turns over.
var _knockouts := 0


## Back where the lantern was last lit, in Lola's words rather than a failure message (Kent's
## design: "the apo's dialogue on respawn be lola's voice"). One line of the RESPAWN pool per
## knockout, in turn, so the second time is not the first time again.
func _knockout_words() -> String:
	var pool: Array = script_lines.peek("RESPAWN") if script_lines != null else []
	if pool.is_empty():
		return super()
	var line: Dictionary = pool[_knockouts % pool.size()]
	_knockouts += 1
	return script_lines.display_text(line)


## How fast the dark settles to a new zone's, per second: a change of about a tenth takes about a
## second, so walking into the deep woods is felt rather than switched.
const DARKNESS_EASE := 0.1

## [start x, darkness] for each of level_04.json's `lighting_states`, west to east. A zone starts
## at the west edge of its `from` beat's volume and runs until the next one starts; before the
## first, the first holds.
var _dark_zones: Array = []


## THE WOODS ARE DARK, AND DARKER FURTHER IN. Read off the level file rather than typed here: the
## edge of the woods 0.80, the deep woods 0.94, the far side 0.88, the last clearing 0.92. The
## level opens at the dark of wherever she starts.
func _darkness() -> float:
	return _darkness_at(spawn_point.global_position.x)


func _darkness_at(x: float) -> float:
	if _dark_zones.is_empty():
		_dark_zones = _read_dark_zones()
	if _dark_zones.is_empty():
		return 0.0
	var dark := float((_dark_zones[0] as Array)[1])
	for zone: Array in _dark_zones:
		if x >= float(zone[0]):
			dark = float(zone[1])
	return dark


func _read_dark_zones() -> Array:
	var west_edges: Dictionary = {}
	for node in get_tree().get_nodes_in_group(&"level_obstacles"):
		var volume := node as LevelObstacle2D
		if volume != null:
			west_edges[volume.obstacle_id] = volume.global_position.x - volume.trigger_size.x * 0.5
	var zones: Array = []
	for state_value: Variant in director.level_data().get("lighting_states", []):
		var state: Dictionary = state_value
		var from := String(state.get("from", ""))
		if west_edges.has(from) and state.has("darkness"):
			zones.append([float(west_edges[from]), float(state["darkness"])])
	zones.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return zones


func _level_physics(anchor_position: Vector2) -> void:
	if darkness_layer != null:
		darkness_layer.darkness = move_toward(darkness_layer.darkness,
			_darkness_at(anchor_position.x), DARKNESS_EASE * get_physics_process_delta_time())
