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
