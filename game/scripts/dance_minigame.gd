class_name DanceMinigame
extends Node
## Piyesta's one screen that is not free drawing.
##
## The dancers will hand over the kandila if the apo dances for them. A cue appears, the
## player draws the shape, and **the timing of the completed stroke is what is scored** --
## not what the shape was. The recogniser is not involved, so this costs no ink: it is a
## performance, not a summoning, and charging for it would make the flower cost something
## the other two routes at this node do not.
##
## THE LEVEL IS UNLOSEABLE AND THAT IS THE DESIGN. Clear it inside two attempts and the
## dancers give the kandila AND the flower. Fail both and they give the kandila anyway and
## withhold the flower. The kandila is never withheld, so this node can never dead-end the
## run -- only the flower is ever at stake.
##
## AND THE LOSS IS SILENT. The flower is the level's one collectible and it feeds the
## ending resolver; a secret ending that announces its own requirements is not secret, so
## nothing on screen says what was missed. Three routes lose it -- scaring the dancers,
## going in through the window, or failing this twice -- and none of them is told.
##
## Between the two attempts Lolo TEASES rather than instructs. Same register as the
## restriction dialogue: he is enjoying this.

signal cue_judged(index: int, verdict: String, offset: float)
signal attempt_finished(cleared: bool, attempts_used: int)
signal finished(cleared: bool, flower_earned: bool)

## Two, from the design. Not three: a third would make the flower a matter of persistence
## rather than of getting it, and persistence is already what the redraw rate measures.
const MAX_ATTEMPTS := 2
## How many of the cues have to land for the attempt to count as cleared.
const CUES_TO_CLEAR := 4

## The window either side of the beat, in seconds. Generous on purpose: this is one screen
## in a drawing game, played once, by someone who has never seen it before -- the failure
## it must not have is a player who cannot tell whether they were early or unlucky.
const PERFECT_WINDOW := 0.18
const HIT_WINDOW := 0.34

var _beats: PackedFloat32Array = PackedFloat32Array()
var _judged: Array[String] = []
var _attempts := 0
var _cleared := false
var _finished := false


## The cue track. Times are seconds from the start of the attempt, and they are DATA so the
## bar can be authored to the music rather than hardcoded to a metronome.
func set_track(beats: PackedFloat32Array) -> void:
	_beats = beats


func track() -> PackedFloat32Array:
	return _beats


func begin_attempt() -> int:
	if _finished:
		return _attempts
	_attempts += 1
	_judged.clear()
	for _beat in _beats:
		_judged.append("")
	return _attempts


func attempts_used() -> int:
	return _attempts


func attempts_left() -> int:
	return maxi(0, MAX_ATTEMPTS - _attempts)


## Score one completed stroke against the cue it was aimed at. `at_seconds` is when the
## stroke FINISHED, because that is the moment the player commits to it -- scoring the
## moment it started would reward a stroke begun early and dragged onto the beat.
func judge(index: int, at_seconds: float) -> String:
	if index < 0 or index >= _beats.size():
		return "miss"
	var offset := at_seconds - _beats[index]
	var verdict := "miss"
	if absf(offset) <= PERFECT_WINDOW:
		verdict = "perfect"
	elif absf(offset) <= HIT_WINDOW:
		verdict = "early" if offset < 0.0 else "late"
	if index < _judged.size():
		_judged[index] = verdict
	cue_judged.emit(index, verdict, offset)
	return verdict


## Early and late still COUNT. They are named differently so the bar can show the player
## which way they were off -- that is the whole teaching -- but a game that only accepts
## perfect is a game with one difficulty and it is "no".
func landed() -> int:
	var count := 0
	for verdict in _judged:
		if verdict == "perfect" or verdict == "early" or verdict == "late":
			count += 1
	return count


func perfect_count() -> int:
	var count := 0
	for verdict in _judged:
		if verdict == "perfect":
			count += 1
	return count


## Close the attempt. Returns whether the run is over -- either because they cleared it or
## because they have used both goes.
func end_attempt() -> bool:
	var cleared := landed() >= CUES_TO_CLEAR
	if cleared:
		_cleared = true
	attempt_finished.emit(cleared, _attempts)
	if cleared or _attempts >= MAX_ATTEMPTS:
		_finished = true
		finished.emit(_cleared, flower_earned())
		return true
	return false


func is_finished() -> bool:
	return _finished


func cleared() -> bool:
	return _cleared


## The flower is the only thing at stake.
func flower_earned() -> bool:
	return _cleared


## THE KANDILA IS NEVER WITHHELD. This is what makes the level unloseable, and it is a
## function rather than a constant so that it is answerable -- and obviously true -- at the
## call site that hands the item over.
func kandila_earned() -> bool:
	return _finished
