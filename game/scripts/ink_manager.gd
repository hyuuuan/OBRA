class_name InkManager
extends Node
## Level-scoped ink accounting. One unit is one canvas diagonal of geometric
## polyline length, independent of how densely pointer events sampled it.

signal ink_changed(remaining: float, capacity: float, reserved: float)
signal ink_exhausted

@export var capacity: float = 12.0
@export var canvas_size: Vector2 = Vector2(512.0, 512.0)

var committed: float = 0.0
var reserved: float = 0.0


func begin_level(new_capacity: float = 12.0) -> void:
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
	if remaining() <= 0.0001:
		ink_exhausted.emit()
	return true


func commit_attempt() -> float:
	var amount := reserved
	committed = minf(capacity, committed + amount)
	reserved = 0.0
	_emit_changed()
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

