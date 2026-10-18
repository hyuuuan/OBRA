class_name PlayerHealth
extends Node
## The lantern is her health: four stages, FULL down to GUTTERING. Kent (2026-10-16): a hit
## knocks the flame down a stage; a hit while it is guttering puts it out, and she is back at the
## last checkpoint.
##
## Only the count lives here. What a stage looks like (the light's radius, the HUD chip) and what
## being snuffed does (the knockout) belong to whoever listens, so this holds no level and no node
## but the one it flickers.
##
## The grace after a hit is counted in physics frames, not wall time: a line of dialogue pauses
## the tree, and a grace that ran on behind it would be spent before she could move.

signal stage_changed(stage: int)
signal hit_taken(stage: int)
## A hit landed while guttering. The stage is left at GUTTERING; the listener restores her.
signal snuffed

const FULL := 4
const DIM := 3
const LOW := 2
const GUTTERING := 1
## How often the body blinks during the grace, in full on-off cycles a second.
const FLICKER_HZ := 12.0
## How faint the blink goes. Never gone: she has to stay findable in the dark.
const FLICKER_ALPHA := 0.35

## Grace after a hit, and the longer one after a knockout, so she is not hit again on arrival.
@export var invulnerable_seconds := 1.0
@export var respawn_invulnerable_seconds := 2.0
## What blinks during the grace: the player's body. The level points it at whoever is the player.
var flicker_target: CanvasItem = null

var stage := FULL
var _grace_left := 0.0
var _grace_clock := 0.0


func _ready() -> void:
	# Paused with the world, so the grace and the blink stop behind a line of dialogue.
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _physics_process(delta: float) -> void:
	if _grace_left <= 0.0:
		return
	_grace_left = maxf(0.0, _grace_left - delta)
	_grace_clock += delta
	_show_flicker()


## A blow. Returns whether it landed: during the grace it does not.
func take_hit() -> bool:
	if is_invulnerable():
		return false
	if stage <= GUTTERING:
		snuffed.emit()
		return true
	_set_stage(stage - 1)
	_start_grace(invulnerable_seconds)
	hit_taken.emit(stage)
	return true


## Oil in the lantern: up by `stages`, never past FULL.
func refill(stages: int = FULL) -> void:
	_set_stage(mini(FULL, stage + maxi(0, stages)))


## Something that is not a blow takes the flame down a stage -- the nuno's curse -- but never
## below `floor_stage`, and never out. No grace and no hit: nothing struck her, and nothing should
## flicker or count as the first hit to the lantern.
func dim(floor_stage: int = LOW) -> void:
	_set_stage(maxi(stage - 1, mini(stage, maxi(GUTTERING, floor_stage))))


## Back to a full flame after a knockout, with the longer grace.
func reset_full() -> void:
	_set_stage(FULL)
	_start_grace(respawn_invulnerable_seconds)


func is_invulnerable() -> bool:
	return _grace_left > 0.0


func set_flicker_target(target: CanvasItem) -> void:
	_clear_flicker()
	flicker_target = target
	_show_flicker()


func _set_stage(next: int) -> void:
	next = clampi(next, GUTTERING, FULL)
	if next == stage:
		return
	stage = next
	stage_changed.emit(stage)


func _start_grace(seconds: float) -> void:
	_grace_left = seconds
	_grace_clock = 0.0
	_show_flicker()


func _show_flicker() -> void:
	if flicker_target == null or not is_instance_valid(flicker_target):
		return
	var faint := is_invulnerable() and fposmod(_grace_clock * FLICKER_HZ, 1.0) >= 0.5
	flicker_target.modulate.a = FLICKER_ALPHA if faint else 1.0


func _clear_flicker() -> void:
	if flicker_target != null and is_instance_valid(flicker_target):
		flicker_target.modulate.a = 1.0
