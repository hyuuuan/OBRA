class_name Wakwak2D
extends FlyingEnemy2D
## The wakwak: a great bird of the night, flying with the manananggal in the finale's second wave
## (Kent's design: "W2 + manananggal and wakwak (fliers)"). It is a FlyingEnemy2D as it stands --
## closes to above her, hangs through its windup, dives along the line it chose -- and this draws it.
##
## PLACEHOLDER BODY until there is art (ART_PLACEHOLDERS): lighter than the dark round it, so it reads
## in her light as the manananggal and the bungisngis do -- dun wings spread wide, a hooked beak, and
## its eye. The base's dark box was the one thing in the night that could not be seen in a lantern.

const WING := Color(0.40, 0.34, 0.32)
const WING_EDGE := Color(0.28, 0.23, 0.22)
const BODY := Color(0.50, 0.43, 0.38)
const BEAK := Color(0.78, 0.70, 0.52)
const EYE_RED := Color(1.0, 0.42, 0.2)

var _clock := 0.0


func _init() -> void:
	kind = "wakwak"


func _physics_process(delta: float) -> void:
	_clock += delta
	super(delta)
	queue_redraw()


func _draw() -> void:
	if art != null and art.has_art():
		return
	# Wings spread wide and beating; held back while it dives.
	var flap := sin(_clock * 7.0) * 10.0 if state != State.ATTACK else -6.0
	for side: float in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(side * 6.0, -4.0),
			Vector2(side * 34.0, -16.0 + flap), Vector2(side * 46.0, -4.0 + flap * 0.6),
			Vector2(side * 26.0, 6.0 + flap * 0.3)]), WING)
		draw_line(Vector2(side * 34.0, -16.0 + flap), Vector2(side * 46.0, -4.0 + flap * 0.6), WING_EDGE, 2.0)
	draw_circle(Vector2.ZERO, 10.0, BODY)
	var head := Vector2(_facing * 10.0, -8.0)
	draw_circle(head, 6.5, BODY)
	draw_colored_polygon(PackedVector2Array([head + Vector2(_facing * 5.0, -2.0),
		head + Vector2(_facing * 13.0, 1.0), head + Vector2(_facing * 7.0, 5.0)]), BEAK)
	draw_circle(head + Vector2(_facing * 2.0, -2.0), 1.8, EYE_RED)
