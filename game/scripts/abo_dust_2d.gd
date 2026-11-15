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
##
## ⚠ WHAT FLIES IN WHILE IT HANGS IS SHOWN TOO (Kent, 2026-11-06). Asked only at the throw, ash thrown
## the moment the lamp leaned, at 220 px, reached nothing: the cloud only reached 160, and the tik-tik
## flew through it unseen a second later. So the plain instruction was wrong by half a second. The
## hanging cloud goes on looking, and "when the lamp leans, throw" is always in time.

## It hung and went without touching anything: the level's to say so, once she can no longer be
## caught out by something flying in.
signal reached_nothing

const REVEALS := &"hides_in_shadow"
const HANG_SECONDS := 1.6
const DUST := Color(0.62, 0.6, 0.63)

@export var radius := 160.0
@export var stun_seconds := 1.5
@export var reveal_seconds := 6.0

var _left := HANG_SECONDS
var _blinded: Array[Enemy2D] = []
## What it has shown, by instance id: each is shown once, however long it stays in the cloud.
var _shown: Dictionary = {}


func _ready() -> void:
	z_index = 7
	for node in get_tree().get_nodes_in_group(Enemy2D.FOES):
		var foe := node as Enemy2D
		if foe != null and not foe.is_dead() and foe.global_position.distance_to(global_position) <= radius:
			foe.stun(stun_seconds)
			_blinded.append(foe)
	_show_what_is_in_it()


func _process(delta: float) -> void:
	_left -= delta
	_show_what_is_in_it()
	if _left <= 0.0:
		if _blinded.is_empty() and _shown.is_empty():
			reached_nothing.emit()
		queue_free()
		return
	queue_redraw()


func _show_what_is_in_it() -> void:
	for node in get_tree().get_nodes_in_group(REVEALS):
		var hidden := node as Node2D
		if hidden != null and hidden.has_method("reveal") and not _shown.has(hidden.get_instance_id()) \
				and hidden.global_position.distance_to(global_position) <= radius:
			_shown[hidden.get_instance_id()] = true
			hidden.call("reveal", reveal_seconds)


## How many it has shown, thrown or since.
func shown_count() -> int:
	return _shown.size()


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
