class_name InkDrain
extends Node
## Dagat's replacement for the transformation clock, to the Level 3 design: "transformation
## no longer expires on a timer -- it ends when the player reverts, or when ink runs out".
##
## ⚠ THIS IS A LEVEL 3 SYSTEM AND IT MUST NOT REACH PAYYO OR PIYESTA. The new brush is found
## on Dagat's shore and the design says it governs the rules "from here to the end of the
## game" -- so a player replaying the first two levels keeps the ten-second clock and must not
## suddenly be draining. The node only charges when a level calls `charge()`, and Level 3 only
## calls it once the brush is picked up. Nothing in `LevelBase` reaches this.
##
## MODEL ONLY -- no view, no world, no `_process`. The level owns the frame and decides when a
## morph counts as held, exactly as `DanceMinigame` owns the rules and `DanceOverlay` owns the
## screen. That is what lets a probe drive a whole crossing headless without a scene.
##
## THE RATE VARIES BY CLASS, from the design: "a fish costs less to hold than a shark". The
## table is the whole tuning surface and is deliberately not a constant -- the design is
## explicit that drain rate, starting capacity and refill size "are numbers, not decisions,
## they come out of playtesting".

## Ink per second while a form is held, keyed by entity id. A class with no entry drains at
## DEFAULT_RATE, so a form can never be free by being forgotten.
@export var rates: Dictionary = {}
## What an unlisted class costs per second.
@export var default_rate: float = 0.20
## Below this fraction of the budget the meter pulses and Lolo says something. The design puts
## it at twenty per cent; `MorphLife.warning_ratio` is the same idea at 0.25 and is left alone.
@export var warning_ratio: float = 0.20

signal low_ink(remaining: float, capacity: float)
signal ink_emptied

var _ink: InkManager = null
var _form_id := ""
var _warned := false


## The level hands over the ledger once. Kept as a reference rather than a parent lookup so a
## probe can bind a bare InkManager with no scene around it.
func bind(ink: InkManager) -> void:
	_ink = ink


## A form is now being held. Clears the low-ink warning, so a second transformation warns
## again -- the same reasoning as MorphLife.begin starting a NEW life rather than resuming one.
func begin(form_id: String) -> void:
	_form_id = form_id
	_warned = false


## No form is held. Charging stops until the next `begin`.
func clear() -> void:
	_form_id = ""
	_warned = false


func is_draining() -> bool:
	return not _form_id.is_empty()


func form_id() -> String:
	return _form_id


func rate_for(entity_id: String) -> float:
	return maxf(0.0, float(rates.get(entity_id, default_rate)))


func current_rate() -> float:
	if _form_id.is_empty():
		return 0.0
	return rate_for(_form_id)


## Charge one frame of holding the current form. Returns false once the ink is gone, which is
## the level's cue to run the zero case: revert, carry the apo up, lose the crossing, never
## die. Safe to call every frame with no form held -- it simply does nothing.
func charge(delta: float) -> bool:
	if _ink == null or _form_id.is_empty() or delta <= 0.0:
		return true
	var alive := _ink.drain(current_rate() * delta)
	if not alive:
		# ⚠ ONCE. InkManager latches its own exhaustion for the same reason, but this signal
		# is the one the level acts on and a revert triggered sixty times a second would fight
		# itself. Clearing the form here is what stops the second charge.
		clear()
		ink_emptied.emit()
		return false
	if not _warned and _ink.remaining_ratio() <= warning_ratio:
		_warned = true
		low_ink.emit(_ink.remaining(), _ink.capacity)
	return true


## Has the low-ink warning already been spent on this form? Read by the level so the HUD pulse
## and Lolo's line stay in step with each other.
func has_warned() -> bool:
	return _warned
