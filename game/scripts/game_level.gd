extends Node2D

@onready var registry: EntityRegistry = $EntityRegistry
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var status_label: Label = $CanvasLayer/StatusLabel
@onready var draw_panel: CanvasLayer = $DrawPanel

var player: Node = null


func _ready() -> void:
	registry.load_manifest()
	draw_panel.drawing_ready.connect(_on_drawing_ready)
	# Draw-first: nothing spawns until the panel recognizes a drawing.
	status_label.text = "Draw something!"


func _on_drawing_ready(
	entity: String,
	display_name: String,
	drawing: Image,
	_response: Dictionary,
	strokes: Array
) -> void:
	_spawn_or_replace(entity, display_name, drawing, strokes)


func _spawn_or_replace(
	entity_id: String,
	display_name: String,
	drawing: Image,
	strokes: Array
) -> void:
	if entity_id.is_empty():
		entity_id = "frog"

	var new_player := registry.instantiate_entity(entity_id)
	if new_player == null:
		status_label.text = "Spawn failed"
		return

	# Only remove the old creature once the new one is ready to take its place.
	if player != null:
		player.queue_free()
	player = new_player

	add_child(player)
	player.global_position = spawn_point.global_position
	if drawing != null and player.has_method("apply_drawing"):
		player.apply_drawing(drawing, strokes)

	var label := display_name if not display_name.is_empty() else entity_id.capitalize()
	# Diagnostic: show whether the rig built from strokes (vector) with limbs, or
	# fell back to a flat bitmap. Also prints the received stroke count.
	var skin := player.get_node_or_null("DrawingSkin")
	if skin != null and skin.has_method("rig_summary"):
		label += " [%s | %d strokes]" % [skin.rig_summary(), strokes.size()]
	status_label.text = label
