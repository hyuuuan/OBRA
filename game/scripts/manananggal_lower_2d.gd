class_name ManananggalLower2D
extends Enemy2D
## The manananggal's lower half, left standing where she parted: in a dark hollow, waiting for the
## rest of her (Kent's design: "find the lower half to kill it (sprinkle with salt)").
##
## It never moves and it is not hurt by a weapon -- a blow passes through it (`apply_tool_hit` is
## nothing). Salt is what ends it: a throw that lands on it salts it at once (`salted`), and she
## cannot come back to it. Light on it is the level's to measure (LightField, her own lantern not
## counted): held there long enough, she cannot rejoin in the light. It is an Enemy2D so the satchel's
## salt, which looks for exactly those, finds it.

signal salted

const CRUMBLE_SECONDS := 1.4

## PLACEHOLDER BODY until there is art (ART_PLACEHOLDERS): hips and legs, a wrap round them.
const SKIN := Color(0.62, 0.56, 0.62)
const WRAP := Color(0.32, 0.20, 0.24)
const SALT_SMOKE := Color(0.9, 0.9, 0.92)

var _salted := false
var _smoke := 0.0


func _init() -> void:
	kind = "manananggal_lower"
	hunts_by_smell = false


## It does not hunt, move or strike. Only its art and the smoke of the salt go on.
func _physics_process(delta: float) -> void:
	art.advance(delta)
	if _smoke > 0.0:
		_smoke -= delta
		queue_redraw()


## A weapon's blow passes through it.
func apply_tool_hit(_tool: String, _impulse: float, _actor: Node2D) -> bool:
	return false


## Salt on it, however much: it is done.
func apply_burn(_ticks: int, _seconds: float) -> void:
	if _salted or state == State.DEAD:
		return
	_salted = true
	_smoke = CRUMBLE_SECONDS
	salted.emit()
	_die()


func is_salted() -> bool:
	return _salted


func reset_for_restore() -> void:
	_salted = false
	_smoke = 0.0
	super()


func _draw() -> void:
	var half := body_size * 0.5
	draw_rect(Rect2(Vector2(-12.0, -half.y + 16.0), Vector2(10.0, body_size.y - 16.0)), SKIN)
	draw_rect(Rect2(Vector2(2.0, -half.y + 16.0), Vector2(10.0, body_size.y - 16.0)), SKIN)
	draw_rect(Rect2(Vector2(-half.x, -half.y), Vector2(body_size.x, 22.0)), WRAP)
	if _smoke > 0.0:
		for puff in range(4):
			var rise := (1.0 - _smoke / CRUMBLE_SECONDS) * 30.0
			draw_circle(Vector2(-10.0 + puff * 7.0, -half.y - rise - puff * 4.0), 5.0,
				Color(SALT_SMOKE, _smoke / CRUMBLE_SECONDS))
