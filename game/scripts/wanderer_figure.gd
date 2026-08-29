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
const UNDERWATER_SHADER := preload("res://shaders/underwater_character.gdshader")

## What each pose draws. `cycle` means the stride phase picks the frame; anything else
## holds the one frame named by `frame`.
##
## `climb` borrows the BACK view out of the turnaround, which is the one place in a
## side-on game where a front-and-back sheet earns its keep: someone going up a ladder is
## facing away from you, and the walk cycle seen from the side reads as walking on air.
const POSES := {
	&"idle": {"texture": IDLE, "count": 1, "cycle": false, "frame": 0},
	# THE WALK IS BUILT, NOT CUT. The delivered walk sheet is six near-identical striding
	# poses -- the gap between the feet stays between 53 and 56 pixels across all of them, so
	# the legs never pass each other, and the leg mass either side of the body axis is the
	# same in every one. For a while this pose drew the RUN sheet instead, on the grounds
	# that a hurrying child beats a gliding one; that sheet turns out to plant the same foot
	# at the same place in all six of its frames, so what it actually looked like was a boy
	# hopping.
	#
	# tools/build_art.py now makes a real cycle out of the one stride the sheet does have,
	# by moving the legs below the knee and leaving every pixel above it alone. Contact,
	# closing, pass, and the same three with the feet exchanged. The feet alternate: the
	# planted foot at the pass is at x=47 in one half of the cycle and x=31 in the other.
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
var _underwater_material: ShaderMaterial
var _underwater_strength := 0.0


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
	_underwater_material = ShaderMaterial.new()
	_underwater_material.shader = UNDERWATER_SHADER
	_sprite.material = _underwater_material
	refresh()


## Change the light on the art below the real world waterline. The sprite keeps the
## material while dry with a zero strength so entering water never swaps rendering state
## halfway through a frame.
func set_underwater_appearance(
	active: bool,
	surface_y: float,
	bottom_y: float,
	shallow: Color,
	deep: Color,
	highlight: Color
) -> void:
	if _underwater_material == null:
		return
	_underwater_strength = 1.0 if active else 0.0
	_underwater_material.set_shader_parameter(&"effect_strength", _underwater_strength)
	_underwater_material.set_shader_parameter(&"surface_y", surface_y)
	_underwater_material.set_shader_parameter(&"bottom_y", bottom_y)
	_underwater_material.set_shader_parameter(&"shallow_water", shallow)
	_underwater_material.set_shader_parameter(&"deep_water", deep)
	_underwater_material.set_shader_parameter(&"caustic_light", highlight)


func debug_underwater_strength() -> float:
	return _underwater_strength


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
	_sprite.position.y = _bob(bool(entry["cycle"]))


## The rise and fall of a body over its own legs.
##
## NEITHER SHEET HAS ONE. The head sits within a pixel of the same row in all six frames of
## both cycles, and a figure that travels without rising and falling is the definition of a
## glide -- it is the single thing most responsible for the character reading as though he
## were on rails rather than on feet.
##
## TWICE THE STRIDE FREQUENCY, because there are two footfalls in a stride and the body
## comes up over each of them. The same reason gait_driver.gd runs its bob at double the
## limb rate for the drawn creatures, and it is why a bob at the stride rate reads as a limp.
##
## Two pixels for the walk, and rounded to whole ones. It has to be small there: a walk
## always has a foot down, so lifting the whole figure lifts that foot off the floor with
## it, and past about two pixels that is what the eye notices instead of the gait.
##
## FIVE FOR THE RUN, because a run is the gait that LEAVES THE GROUND. Both feet are off it
## for part of every stride, which is the thing that separates running from walking quickly
## and the thing the delivered run sheet has none of -- its head sits within a pixel of the
## same row in all six frames. At two pixels the run was a walk played fast; at five the
## boy bounds.
const BOB_PIXELS := {
	&"walk": 2.0,
	&"run": 5.0,
}


func _bob(cycling: bool) -> float:
	if not cycling:
		return 0.0
	return -roundf(absf(sin(TAU * stride)) * float(BOB_PIXELS.get(pose, 2.0)))
