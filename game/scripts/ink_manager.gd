class_name InkManager
extends Node
## Level-scoped ink accounting, to thesis FR-7: "a limited ink budget of six units".
##
## ⚠ ONE UNIT IS ONE THING, NOT ONE CANVAS DIAGONAL OF LINE. It used to be length --
## `drawn_length / canvas_diagonal` -- so a drawing cost whatever it happened to cost and
## the budget was twelve diagonals of stroke. That prices NEATNESS, and it is not the
## economy the manuscript specifies or the one the levels are balanced against: a tool
## costs one unit on its first successful recognition and is then free forever, a placeable
## costs one unit on every placement, a creature transformation is free, and a declined
## drawing costs nothing. Six of those, per level.
##
## The length cap did not disappear, it stopped being the budget: `DrawingCanvas` still
## limits how much line fits on one page, which is a statement about the page.

signal ink_changed(remaining: float, capacity: float, reserved: float)
signal ink_exhausted

## Thesis FR-7. Six, everywhere, for every level -- §4.5.4 is explicit that it "is
## unchanged throughout, so the same resource covers a widening demand".
const BUDGET := 6.0
## What any one chargeable thing costs. There is no other price.
const UNIT := 1.0

@export var capacity: float = BUDGET
## The canvas one ink unit is measured against. Follows the viewport: a unit is a canvas
## diagonal of stroke, so shrinking the surface without moving this would quietly make every
## drawing cost more ink than the budget was tuned for.
@export var canvas_size: Vector2 = Vector2(400.0, 400.0)

var committed: float = 0.0
var reserved: float = 0.0


func begin_level(new_capacity: float = BUDGET) -> void:
	capacity = maxf(0.0, new_capacity)
	committed = 0.0
	reserved = 0.0
	_emit_changed()


func remaining() -> float:
	return maxf(0.0, capacity - committed - reserved)


func total_uncommitted_available() -> float:
	return maxf(0.0, capacity - committed)


func remaining_ratio() -> float:
	if capacity <= 0.0:
		return 0.0
	return clampf((capacity - committed - reserved) / capacity, 0.0, 1.0)


func reserve_attempt(cost: float) -> bool:
	var requested := maxf(0.0, cost)
	if requested > total_uncommitted_available() + 0.0001:
		return false
	reserved = requested
	_emit_changed()
	# NOT exhausted. Reserved ink is provisional -- the stroke is on the canvas and
	# clearing it hands every unit straight back -- so announcing it here threw the
	# out-of-ink screen over the player's own drawing, mid-stroke, the moment a sketch
	# grew to the size of the budget. Exhaustion is something that happens when ink is
	# SPENT, which is commit_attempt below.
	return true


## Charge one unit outright, for the events that are priced rather than drawn: a placeable
## being set down again, which the player pays for every time. Returns false when there is
## nothing left, so the caller can refuse the action instead of quietly running a deficit.
func spend_unit() -> bool:
	if total_uncommitted_available() < UNIT - 0.0001:
		return false
	committed = minf(capacity, committed + UNIT)
	_emit_changed()
	if total_uncommitted_available() <= 0.0001:
		ink_exhausted.emit()
	return true


func commit_attempt() -> float:
	var amount := reserved
	committed = minf(capacity, committed + amount)
	reserved = 0.0
	_emit_changed()
	if total_uncommitted_available() <= 0.0001:
		ink_exhausted.emit()
	return amount


func release_attempt() -> float:
	var amount := reserved
	reserved = 0.0
	_emit_changed()
	return amount


func add_ink(amount: float) -> void:
	committed = maxf(0.0, committed - maxf(0.0, amount))
	_emit_changed()


func cost_for_strokes(strokes: Array) -> float:
	return static_cost_for_strokes(strokes, canvas_size)


static func static_cost_for_strokes(
	strokes: Array,
	for_canvas_size: Vector2 = Vector2(512.0, 512.0)
) -> float:
	var diagonal := maxf(1.0, for_canvas_size.length())
	var length := 0.0
	for value in strokes:
		if not (value is Dictionary):
			continue
		var points_value: Variant = (value as Dictionary).get("points")
		if not (points_value is PackedVector2Array):
			continue
		var points: PackedVector2Array = points_value
		for index in range(points.size() - 1):
			length += points[index].distance_to(points[index + 1])
	return length / diagonal


func _emit_changed() -> void:
	ink_changed.emit(remaining(), capacity, reserved)

