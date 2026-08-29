extends Node2D
## Lolo's body: the delivered ghost art, driven by what lolo.gd is doing.
##
## This file used to draw him from primitives -- a nineteen-unit yellow ball with a leaf
## and two dots -- and the note on it said that replacing him with real art meant replacing
## this one file. That is what this is. Nothing outside it changed shape: the node is still
## `Figure`, it is still told which way he is facing, and lolo.gd still owns where he is
## and what he says rather than how he looks.
##
## THE FRAMES COME OUT OF `tools/build_art.py`, off the same kind of presentation page the
## apo's did and through the same cutter. Read its header for how the keying works and what
## the panel chrome on Lolo's page cost before it did.
##
## HE STILL HAS NO GAIT, which is the one thing about him that the art did not change. The
## sheet's walk and run cycles are a ghost DRIFTING -- he has a tail where the apo has legs,
## and the cycle undulates it rather than stepping -- so nothing here has to line up with
## ground contact, and the follow behaviour lolo.gd implements is unaffected.

## Frame size and the row every pose is aligned on, both fixed by the generator.
const CELL := Vector2(80.0, 104.0)
const GROUND_ROW := 103.0

## How far above that row his origin sits.
##
## THE APO IS ANCHORED ON THE FEET because a controller stands them on the ground. Lolo is
## anchored on the MIDDLE OF HIS BODY, because nothing about him touches the floor: his
## position is a point in the air that lolo.gd works out from the player's shoulder, and
## the drawing hangs around it. Anchored on the tail tip like a walker, `follow_offset`
## would have meant something different than it did the day it was tuned, and he would sit
## a whole body too high.
const HOVER := 43.0

## THE SHEET IS DRAWN FACING LEFT, where the apo's is drawn facing right. Nothing deep --
## the two pages were made months apart -- but it is the sort of thing that is invisible in
## code and reads on screen as a companion moonwalking after you.
const SHEET_FACING := -1.0

const IDLE := preload("res://assets/characters/lolo/lolo_idle.png")
const WALK := preload("res://assets/characters/lolo/lolo_walk.png")
const RUN := preload("res://assets/characters/lolo/lolo_run.png")
const WAVE := preload("res://assets/characters/lolo/lolo_wave.png")
const CHEER := preload("res://assets/characters/lolo/lolo_cheer.png")
const TURNAROUND := preload("res://assets/characters/lolo/lolo_turnaround.png")

## What each pose draws. `cycle` means the drift phase picks the frame; anything else holds
## the one frame named by `frame`.
##
## `float` and `hurry` are the sheet's walk and run under the names that describe what they
## actually show, because a companion who never touches the ground has no walk and calling
## it one is how someone ends up trying to sync it to a footfall.
## A pose is either a CYCLE driven by the drift phase, a ONE-SHOT driven by its own clock,
## or a single held frame.
##
## `once` plays through at `fps` and holds the last frame; `reverse` plays the same sheet
## backwards, which is what turning back to the drift is. Both read `pose_time`, which Lolo
## advances and resets -- the figure still owns no clock of its own, for the reason on
## refresh(): it must not animate on while the tree is paused behind an overlay.
const POSES := {
	&"float": {"texture": WALK, "count": 6, "cycle": true, "frame": 0},
	&"hurry": {"texture": RUN, "count": 6, "cycle": true, "frame": 0},
	&"still": {"texture": IDLE, "count": 1, "cycle": false, "frame": 0},
	&"wave": {"texture": WAVE, "count": 1, "cycle": false, "frame": 0},
	&"cheer": {"texture": CHEER, "count": 1, "cycle": false, "frame": 0},
	# THE TURNAROUND IS FIVE FRAMES AND FOUR OF THEM HAD NEVER BEEN DRAWN. The sheet is
	# 400x104 -- five cells -- and `face` held frame 0 forever, so the one piece of
	# character animation the artist delivered for this companion showed as a still. He
	# turns now: to the player when he starts speaking, and back to the drift when he is
	# done.
	# THE SHEET RUNS FRONT TO BACK: cell 0 is head-on with a face, cell 4 is the back of his
	# head. Verified by photographing all five, which is also how it was caught that the two
	# poses below had their directions swapped -- `face` was turning him AWAY to speak.
	# Turning TO the player is therefore the sheet played BACKWARDS, ending on cell 0 and
	# holding it for the rest of the line.
	&"face": {"texture": TURNAROUND, "count": 5, "cycle": false, "frame": 0,
		"once": true, "fps": 14.0, "reverse": true},
	&"turn_back": {"texture": TURNAROUND, "count": 5, "cycle": false, "frame": 0,
		"once": true, "fps": 16.0},
}

## Which pose to draw. Set by Lolo; an unknown name falls back to the drift rather than
## leaving him frozen mid-gesture forever.
@export var pose: StringName = &"float"
## Phase of the drift, in whole cycles.
@export var stride: float = 0.0
## -1 or 1. Lolo turns to face the way he is going, like the player does.
@export var facing: float = 1.0:
	set(value):
		facing = value
		if _sprite != null:
			_sprite.scale.x = SHEET_FACING * signf(value) if value != 0.0 else SHEET_FACING
## Advanced by lolo.gd. The drift cycle carries most of his motion now, but a hover that is
## only ever the six frames repeating reads as a loop; a slow rise and fall under it is what
## stops the eye finding the seam.
@export var bob: float = 0.0
## Seconds spent in the current pose, advanced and reset by lolo.gd. Only the one-shot
## poses read it; a cycle is still driven by `stride` so it stays locked to the ground he
## is covering rather than to a second, unrelated clock.
@export var pose_time: float = 0.0
## Set while he is talking. Kept because lolo.gd sets it and because a companion who is
## saying something should not look identical to one who is not -- he lifts and breathes
## wider while a line of his is up.
@export var talking: bool = false

var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Body"
	# Nearest, like every other texture in the level. The art is pixel art and a linear
	# filter turns the outlines into smears at exactly the size the player looks at them.
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Anchored on his middle rather than on the bottom of the cell -- see HOVER -- and
	# offset left by half a cell, which also means a mirrored scale.x turns him about his
	# own axis instead of swinging him sideways.
	_sprite.centered = false
	_sprite.offset = Vector2(-CELL.x * 0.5, -(GROUND_ROW - HOVER))
	_sprite.scale.x = SHEET_FACING * (signf(facing) if facing != 0.0 else 1.0)
	add_child(_sprite)
	refresh()


## How long a one-shot pose takes to play out, so a caller can hold a state for exactly as
## long as the animation it started. Zero for a cycle or a single frame.
static func pose_duration(which: StringName) -> float:
	var entry: Dictionary = POSES.get(which, {})
	if not bool(entry.get("once", false)):
		return 0.0
	return float(int(entry["count"])) / maxf(1.0, float(entry.get("fps", 12.0)))


## Draw whatever `pose`, `stride` and `bob` currently say. Called from lolo.gd's `_process`
## rather than run off one here, so the figure cannot drift on while the tree is paused
## behind an overlay.
func refresh() -> void:
	if _sprite == null:
		return
	var entry: Dictionary = POSES.get(pose, POSES[&"float"])
	var texture: Texture2D = entry["texture"]
	var count: int = int(entry["count"])
	if _sprite.texture != texture:
		_sprite.texture = texture
		_sprite.hframes = count
	var frame := int(entry["frame"])
	if bool(entry.get("once", false)):
		var fps := float(entry.get("fps", 12.0))
		# Clamped rather than wrapped: a one-shot that looped would have him turning to the
		# player over and over for as long as the line is up.
		var step := clampi(int(floor(pose_time * fps)), 0, count - 1)
		frame = (count - 1 - step) if bool(entry.get("reverse", false)) else step
	elif bool(entry["cycle"]):
		# posmod, not %, because the phase is a float that can go negative on a rewind and
		# a negative frame index leaves the sprite showing nothing at all.
		frame = posmod(int(floor(stride * float(count))), count)
	_sprite.frame = frame
	# Whole pixels. He is drawn at 1:1 against a pixel-art level, and a sprite sitting on a
	# half pixel is the one thing on screen that shimmers as it moves.
	_sprite.position.y = roundf(sin(TAU * bob) * (5.0 if talking else 3.0))
