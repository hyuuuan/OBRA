class_name AboDust2D
extends Node2D
## A handful of abo thrown into the air where she stands: it blinds what it touches for a moment
## and shows what hides in shadow.
##
## Kent's design: "Thrown in a cloud. Reveals anything hiding in shadow and blinds what it touches
## for a moment. The counter to the creatures the darkness protects." Everything within `radius`
## when it is thrown is blinded (Enemy2D.stun) for `stun_seconds`; anything in the REVEALS group
## there is asked to show itself (`reveal(seconds)`) for `reveal_seconds` -- the creatures that
## hide in the dark answer that as they come. The dust hangs, thins and is gone.

const REVEALS := &"hides_in_shadow"
const HANG_SECONDS := 1.6
const DUST := Color(0.62, 0.6, 0.63)

@export var radius := 160.0
@export var stun_seconds := 1.5
@export var reveal_seconds := 6.0

var _left := HANG_SECONDS
var _blinded: Array[Enemy2D] = []


func _ready() -> void:
	z_index = 7
	for node in get_tree().get_nodes_in_group(Enemy2D.FOES):
		var foe := node as Enemy2D
		if foe != null and not foe.is_dead() and foe.global_position.distance_to(global_position) <= radius:
			foe.stun(stun_seconds)
			_blinded.append(foe)
	for node in get_tree().get_nodes_in_group(REVEALS):
		var hidden := node as Node2D
		if hidden != null and hidden.has_method("reveal") \
				and hidden.global_position.distance_to(global_position) <= radius:
			hidden.call("reveal", reveal_seconds)


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	queue_redraw()


## What it blinded when it was thrown.
func blinded() -> Array[Enemy2D]:
	return _blinded


## PLACEHOLDER until it has art: grey dust spreading and thinning.
func _draw() -> void:
	var spread := 1.0 - _left / HANG_SECONDS
	var alpha := 0.45 * (1.0 - spread)
	for index in range(14):
		var angle := TAU * float(index) / 14.0
		var at := Vector2(cos(angle), sin(angle) * 0.5) * radius * (0.3 + 0.7 * spread) * (0.6 + 0.4 * float(index % 3) / 2.0)
		draw_circle(at + Vector2(0.0, -40.0), 10.0 + 8.0 * spread, Color(DUST, alpha))
