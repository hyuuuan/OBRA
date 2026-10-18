class_name HeldLantern2D
extends Node2D
## The lantern she carries through the dark. Where the level counts it as her health, its light IS
## the health: each stage the flame drops, the circle she can see in shrinks (Kent, 2026-10-16).
##
## It follows whoever the player is, held at the side away from her weapon hand, and answers
## LightField like every other light -- so the dark is cut by it and a sigbin can ask how lit she is.

## The light's radius by lantern stage, world px: full, dim, low, guttering.
const RADII := {4: 380.0, 3: 290.0, 2: 200.0, 1: 130.0}
## Guttering, the light will not hold still: this far either way, this many times a second.
const GUTTER_FLICKER := 14.0
const GUTTER_HZ := 6.0
## Dragged down by something close to it (the tik-tik): the light is this much smaller while it is.
const DRAGGED_SHARE := 0.18
## Where it hangs: behind her leading hand and a little below her middle.
const HANG := Vector2(-12.0, 6.0)

const FRAME := Color(0.11, 0.08, 0.05)
const GLASS := Color(1.0, 0.8, 0.42)
const FLAME := Color(1.0, 0.95, 0.75)

var player: Node2D = null
## Where the stage comes from; without one it burns full.
var health: PlayerHealth = null

var _clock := 0.0
var _dragged := 0.0


func _ready() -> void:
	add_to_group(LightField.GROUP)
	z_index = 4


func _physics_process(delta: float) -> void:
	_clock += delta
	_dragged = maxf(0.0, _dragged - delta)
	follow()
	queue_redraw()


func follow() -> void:
	if player == null or not is_instance_valid(player):
		return
	var facing := 1.0
	if player.get(&"_facing") != null:
		facing = float(player.get(&"_facing"))
	global_position = PlayerHurtbox2D.middle_of(player) + Vector2(HANG.x * facing, HANG.y)


func stage() -> int:
	return health.stage if health != null else PlayerHealth.FULL


## The light's radius this frame.
func radius() -> float:
	var reach := float(RADII.get(stage(), RADII[PlayerHealth.FULL]))
	if stage() <= PlayerHealth.GUTTERING:
		reach += sin(_clock * TAU * GUTTER_HZ) * GUTTER_FLICKER
	if _dragged > 0.0:
		reach *= 1.0 - DRAGGED_SHARE
	return reach


## Something close is pulling the light down: for `seconds`, it is DRAGGED_SHARE smaller.
func drag_down(seconds: float) -> void:
	_dragged = maxf(_dragged, seconds)


func is_dragged() -> bool:
	return _dragged > 0.0


func light_hole() -> Dictionary:
	return {"position": global_position, "radius": radius(), "strength": 1.0}


func _draw() -> void:
	# A small iron lantern: a handle, a frame, warm glass, and a flame that shrinks with the stage.
	draw_arc(Vector2(0.0, -6.0), 3.0, PI, TAU, 8, FRAME, 1.5)
	draw_rect(Rect2(-4.0, -5.0, 8.0, 10.0), FRAME)
	var glow := GLASS
	glow.a = 0.55 + 0.1 * stage()
	draw_rect(Rect2(-3.0, -4.0, 6.0, 8.0), glow)
	draw_circle(Vector2(0.0, 1.0), 0.6 + 0.45 * stage(), FLAME)
