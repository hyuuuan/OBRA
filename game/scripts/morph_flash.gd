class_name MorphFlash
extends Node2D
## The moment the wanderer becomes the drawing.
##
## Without it the swap is a single frame -- one body vanishes and another appears in
## its place -- which reads as a glitch rather than as the thing the whole game is
## about. This is a ring that expands from where the character stood while the new
## creature scales up inside it, so the change has a beat.
##
## Purely cosmetic and self-freeing. It is spawned into the world, never parented to
## either creature, so a rig that fails to build or a morph that is replaced again
## mid-flash cannot leave it stranded or take it down with them.

const DURATION := 0.42
const RING_RADIUS := 96.0
const INK := Color(0.55, 0.71, 0.18, 1.0)
const SPARK := Color(1.0, 0.94, 0.42, 1.0)
const SPARKS := 9

var _elapsed := 0.0


## Spawn a flash at `at` in `parent`'s space, and scale `arrival` up into it.
static func play(parent: Node, at: Vector2, arrival: Node2D = null) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var flash := MorphFlash.new()
	flash.global_position = at
	flash.z_index = 20
	parent.add_child(flash)
	if arrival != null and is_instance_valid(arrival):
		# The creature grows into the ring rather than appearing at full size. Scale
		# only -- position is left alone, because the rig underneath is already
		# simulating and moving it would fight the physics.
		var target := arrival.scale
		arrival.scale = target * 0.55
		var tween := arrival.create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(arrival, "scale", target, DURATION * 0.8)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(_elapsed / DURATION, 0.0, 1.0)
	# Fast out, slow settle: the ring should feel like a release, not a wipe.
	var eased := 1.0 - pow(1.0 - t, 3.0)
	var radius := RING_RADIUS * eased
	var fade := 1.0 - t

	var ring := INK
	ring.a = fade * 0.9
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, ring, 5.0 * fade + 1.0, true)

	var inner := SPARK
	inner.a = fade * 0.5
	draw_arc(Vector2.ZERO, radius * 0.6, 0.0, TAU, 32, inner, 3.0 * fade + 1.0, true)

	# A few marks thrown outward, so the ring reads as ink being scattered rather than
	# as a UI circle.
	var spark := SPARK
	spark.a = fade
	for index in range(SPARKS):
		var angle := TAU * float(index) / float(SPARKS) + eased * 0.8
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(direction * radius * 0.82, direction * (radius * 1.04), spark, 3.0 * fade + 1.0, true)
