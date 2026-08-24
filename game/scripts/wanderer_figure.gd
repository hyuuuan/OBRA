extends Node2D
## The apo's body: the delivered character art, driven by what the controller is doing.
##
## This file used to draw a stick figure out of arcs and lines, and the note on it said
## that replacing it with real art meant replacing this one file. That is what this is.
## Nothing outside it changed shape: the node is still `Figure`, it is still scaled by
## `scale.x` to face, and it is still told a stride phase every physics frame.
##
## THE FRAMES COME OUT OF `tools/build_art.py`, not out of a folder somebody sliced by
## hand. The delivered sheet is a presentation page -- panels, labels, a palette, a flat
## dark background and no alpha anywhere -- so every pose has to be found, keyed and
## aligned before it is a sprite. That script does it and can be re-run when the sheet is
## redelivered; read its header for how the keying and the anchoring work.
##
## EVERY STRIP SHARES ONE CELL SIZE AND ONE ANCHOR. That is the whole reason the poses can
## be swapped by changing a texture: the feet sit on the same row and the head sits on the
## same column in all twenty-three of them, so switching from walking to standing still
## moves nothing. If a future strip is built to a different cell, this breaks silently and
## looks like the character twitching.

## Frame size and the row the feet stand on, both fixed by the generator.
const CELL := Vector2(80.0, 106.0)
const FOOT_ROW := 105.0

const IDLE := preload("res://assets/characters/apo/apo_idle.png")
const WALK := preload("res://assets/characters/apo/apo_walk.png")
const RUN := preload("res://assets/characters/apo/apo_run.png")
const JUMP := preload("res://assets/characters/apo/apo_jump.png")
const LOOK_UP := preload("res://assets/characters/apo/apo_look_up.png")
const LOOK_DOWN := preload("res://assets/characters/apo/apo_look_down.png")
const WAVE := preload("res://assets/characters/apo/apo_wave.png")
const CHEER := preload("res://assets/characters/apo/apo_cheer.png")
const TURNAROUND := preload("res://assets/characters/apo/apo_turnaround.png")

## What each pose draws. `cycle` means the stride phase picks the frame; anything else
## holds the one frame named by `frame`.
##
## `climb` borrows the BACK view out of the turnaround, which is the one place in a
## side-on game where a front-and-back sheet earns its keep: someone going up a ladder is
## facing away from you, and the walk cycle seen from the side reads as walking on air.
const POSES := {
	&"idle": {"texture": IDLE, "count": 1, "cycle": false, "frame": 0},
	&"walk": {"texture": WALK, "count": 6, "cycle": true, "frame": 0},
	&"run": {"texture": RUN, "count": 6, "cycle": true, "frame": 0},
	&"air": {"texture": JUMP, "count": 1, "cycle": false, "frame": 0},
	&"look_up": {"texture": LOOK_UP, "count": 1, "cycle": false, "frame": 0},
	&"look_down": {"texture": LOOK_DOWN, "count": 1, "cycle": false, "frame": 0},
	&"wave": {"texture": WAVE, "count": 1, "cycle": false, "frame": 0},
	&"cheer": {"texture": CHEER, "count": 1, "cycle": false, "frame": 0},
	&"climb": {"texture": TURNAROUND, "count": 5, "cycle": false, "frame": 4},
}

## Which pose to draw. Set by Wanderer every physics frame; an unknown name falls back to
## idle rather than leaving the character mid-stride forever.
@export var pose: StringName = &"idle"
## Phase of the walk, in whole cycles. The controller advances it with actual speed.
@export var stride: float = 0.0
## What the player is holding. Recorded because `set_carried` is part of the player-swap
## contract and something may want to ask later -- it is deliberately NOT drawn. The
## equipped utility is reparented to the wanderer's grip anchor and so is already on
## screen in the character's hand; the stand-in silhouette this file used to draw beside
## it was a second copy of the same axe.
@export var carrying: String = ""

var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Body"
	# Nearest, like every other texture in the level. The art is pixel art and a linear
	# filter turns the outlines into smears at exactly the size the player looks at them.
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Anchored on the FEET, not on the middle. The node's origin is the point the
	# controller puts on the ground, so the sprite is offset up by its own foot row and
	# left by half a cell -- which also means scale.x = -1 mirrors about the body's axis
	# instead of swinging it sideways.
	_sprite.centered = false
	_sprite.offset = Vector2(-CELL.x * 0.5, -FOOT_ROW)
	add_child(_sprite)
	refresh()


## Draw whatever `pose` and `stride` currently say. Called by Wanderer rather than run off
## _process so the figure cannot advance while the tree is paused behind an overlay.
func refresh() -> void:
	if _sprite == null:
		return
	var entry: Dictionary = POSES.get(pose, POSES[&"idle"])
	var texture: Texture2D = entry["texture"]
	var count: int = int(entry["count"])
	if _sprite.texture != texture:
		_sprite.texture = texture
		_sprite.hframes = count
	var frame := int(entry["frame"])
	if bool(entry["cycle"]):
		# posmod, not %, because the phase is a float that can go negative on a rewind and
		# a negative frame index leaves the sprite showing nothing at all.
		frame = posmod(int(floor(stride * float(count))), count)
	_sprite.frame = frame
