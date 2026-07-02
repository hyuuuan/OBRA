extends Node2D

@onready var registry: EntityRegistry = $EntityRegistry
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var status_label: Label = $CanvasLayer/StatusLabel

var player: Node = null


func _ready() -> void:
	registry.load_manifest()
	var entity_id := GameState.pending_entity
	if entity_id.is_empty():
		entity_id = "frog"

	player = registry.instantiate_entity(entity_id)
	if player == null:
		status_label.text = "Spawn failed"
		return

	add_child(player)
	player.global_position = spawn_point.global_position
	if GameState.pending_drawing != null and player.has_method("apply_drawing"):
		player.apply_drawing(GameState.pending_drawing, GameState.pending_strokes)

	var label := GameState.pending_display_name
	status_label.text = label if not label.is_empty() else entity_id.capitalize()


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("redraw"):
		GameState.clear_pending()
		get_tree().change_scene_to_file("res://draw_screen.tscn")

