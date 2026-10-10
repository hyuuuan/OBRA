extends Node2D
## The apo's body: the delivered character art, driven by what the controller is doing.
##
## This file used to draw a stick figure out of arcs and lines, and the note on it said
## that replacing it with real art meant replacing this one file. That is what this is.
## Nothing outside it changed shape: the node is still `Figure`, it is still scaled by
## `scale.x` to face, and it is still told a stride phase every physics frame.
##
## The walk/run atlas replaces the old procedural leg patches. Its source sheets and
## preparation notes live in assets/characters/apo/source/. Other poses still come from
## tools/build_art.py. Each atlas frame has a measured anchor so differing sheet spacing
## never makes the body lurch sideways; flight frames keep their clearance above ground.

## Frame size and the row the feet stand on, both fixed by the generator.
const CELL := Vector2(80.0, 106.0)
const FOOT_ROW := 105.0

const IDLE := preload("res://assets/characters/apo/apo_idle.png")
const LOCOMOTION := preload("res://assets/characters/apo/apo_locomotion.png")
## One scale for both rows: the walk is 96px tall and the run crouches naturally.
const LOCOMOTION_SCALE := 0.28
const ATLAS_COLUMNS := [0, 362, 724, 1086, 1447, 1809, 2171]
const WALK_ANCHORS := [216.0, 211.5, 192.0, 192.5, 168.0, 153.5]
const RUN_ANCHORS := [223.0, 198.5, 193.5, 195.5, 198.5, 206.0]
const WALK_GROUND := [377.0, 374.0, 374.0, 377.0, 377.0, 374.0]
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
	&"walk": {"texture": LOCOMOTION, "count": 6, "cycle": true, "frame": 0},
	&"run": {"texture": LOCOMOTION, "count": 6, "cycle": true, "frame": 0},
	&"air": {"texture": JUMP, "count": 1, "cycle": false, "frame": 0},
	&"look_up": {"texture": LOOK_UP, "count": 1, "cycle": false, "frame": 0},
	&"look_down": {"texture": LOOK_DOWN, "count": 1, "cycle": false, "frame": 0},
	&"wave": {"texture": WAVE, "count": 1, "cycle": false, "frame": 0},
	&"cheer": {"texture": CHEER, "count": 1, "cycle": false, "frame": 0},
	&"climb": {"texture": TURNAROUND, "count": 5, "cycle": false, "frame": 4},
	# THE WATER HAS ITS OWN TWO. There is no swimming drawing on the sheet, so `swim` lays the
	# run cycle flat -- the reaching arm and the alternating legs read as a stroke and a kick --
	# and `tread` is the arms-out jump frame, upright: keeping afloat, or failing to.
	&"swim": {"texture": LOCOMOTION, "count": 6, "cycle": true, "frame": 0},
	&"tread": {"texture": JUMP, "count": 1, "cycle": false, "frame": 0},
}
## Laid flat to swim: head first, the body's length centred over the feet's point, and its line
## a little above it -- the apo floats with her feet just under the surface, so this puts the
## swimmer ON the waterline rather than standing on it.
const SWIM_OFFSET := Vector2(-43.0, -22.0)
## How far a swimmer's head dips or lifts with the stroke's direction, steering fully down or up.
const SWIM_MAX_TILT := 0.5
## The run cycle leans into its stride, so laid flat it swam head-down; this takes the lean out.
const SWIM_LEAN := 0.3

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
## Swimming only: -1 rising .. 1 diving. The head leads the way the stroke is going.
@export var tilt: float = 0.0
## Treading water only: how far the figure is drawn down from the feet's point, so the surface
## is at her chest rather than her ankles. Set by Wanderer; 0 anywhere she can stand.
@export var water_sink: float = 0.0

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
	var frame := int(entry["frame"])
	if bool(entry["cycle"]):
		# posmod, not %, because the phase is a float that can go negative on a rewind and
		# a negative frame index leaves the sprite showing nothing at all.
		frame = posmod(int(floor(stride * float(count))), count)
	# Clear the previous strip's frame before changing its divisions (climb has five).
	_sprite.frame = 0
	_sprite.hframes = 1
	_sprite.texture = texture
	_sprite.region_enabled = bool(entry["cycle"])
	_sprite.position = Vector2.ZERO
	_sprite.rotation = 0.0
	if pose == &"swim":
		# A quarter turn clockwise puts the head forward; the parent's mirror then carries it
		# to whichever side she faces, and a tilt the same sign as the dive dips the head.
		_sprite.rotation = PI * 0.5 - SWIM_LEAN + clampf(tilt, -1.0, 1.0) * SWIM_MAX_TILT
		_sprite.position = SWIM_OFFSET
	elif pose == &"tread":
		_sprite.position = Vector2(0.0, water_sink)
	if bool(entry["cycle"]):
		var running := pose == &"run" or pose == &"swim"
		var top := 382.0 if running else 0.0
		var height := 342.0 if running else 382.0
		_sprite.region_rect = Rect2(float(ATLAS_COLUMNS[frame]), top,
			float(ATLAS_COLUMNS[frame + 1] - ATLAS_COLUMNS[frame]), height)
		_sprite.region_filter_clip_enabled = true
		_sprite.scale = Vector2.ONE * LOCOMOTION_SCALE
		var anchor: float = RUN_ANCHORS[frame] if running else WALK_ANCHORS[frame]
		# Run contact baseline is 707 in the sheet. Do not ground the lifted flight feet.
		var ground: float = 325.0 if running else WALK_GROUND[frame]
		_sprite.offset = Vector2(-anchor, -ground)
	else:
		_sprite.scale = Vector2.ONE
		_sprite.offset = Vector2(-CELL.x * 0.5, -FOOT_ROW)
		_sprite.hframes = count
		_sprite.frame = frame
