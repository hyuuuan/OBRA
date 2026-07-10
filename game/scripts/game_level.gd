extends Node2D

@export var debug_timing_logs: bool = false

@onready var registry: EntityRegistry = $EntityRegistry
@onready var environment: Node = $EnvironmentBaseplate
@onready var spawn_point: Marker2D = $EnvironmentBaseplate/GameplayPlane/SpawnPoint
@onready var entity_root: Node2D = $EnvironmentBaseplate/GameplayPlane/EntityRoot
@onready var backend_supervisor: Node = $BackendSupervisor
@onready var status_label: Label = $CanvasLayer/StatusLabel
@onready var draw_button: Button = $CanvasLayer/DrawButton
@onready var draw_panel = $DrawPanel

var player: Node2D = null


func _ready() -> void:
	registry.load_manifest()
	draw_panel.set("debug_timing_logs", debug_timing_logs)
	draw_button.pressed.connect(_on_draw_button_pressed)
	draw_panel.drawing_ready.connect(_on_drawing_ready)
	draw_panel.panel_closed.connect(_on_draw_panel_closed)
	backend_supervisor.set("debug_logs", debug_timing_logs)
	backend_supervisor.connect("backend_ready", Callable(self, "_on_backend_ready"))
	backend_supervisor.connect("backend_starting", Callable(self, "_on_backend_starting"))
	backend_supervisor.connect("backend_failed", Callable(self, "_on_backend_failed"))
	environment.call("set_target", spawn_point)
	draw_button.disabled = true
	status_label.text = "Checking backend..."
	backend_supervisor.call("ensure_backend")


func _on_draw_button_pressed() -> void:
	draw_panel.open_panel()


func _on_backend_ready() -> void:
	draw_button.disabled = false
	status_label.text = "Ready"


func _on_backend_starting(message: String) -> void:
	draw_button.disabled = true
	status_label.text = message


func _on_backend_failed(message: String) -> void:
	draw_button.disabled = true
	status_label.text = message


func _on_draw_panel_closed() -> void:
	draw_button.grab_focus()


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
	var spawn_started := Time.get_ticks_usec()
	if entity_id.is_empty():
		entity_id = "frog"

	var instantiate_started := Time.get_ticks_usec()
	var new_player := registry.instantiate_entity(entity_id) as Node2D
	if new_player == null:
		status_label.text = "Spawn failed"
		return
	var instantiated_usec := Time.get_ticks_usec()

	# Only remove the old creature once the new one is ready to take its place.
	if player != null:
		player.queue_free()
	player = new_player

	entity_root.add_child(player)
	player.global_position = spawn_point.global_position
	environment.call("set_target", player)
	var skin := player.get_node_or_null("DrawingSkin")
	if skin != null:
		skin.set("debug_timing_logs", debug_timing_logs)
	if drawing != null and player.has_method("apply_drawing"):
		player.apply_drawing(drawing, strokes)
	var applied_usec := Time.get_ticks_usec()

	var label := display_name if not display_name.is_empty() else entity_id.capitalize()
	# Diagnostic: show whether the rig built from strokes (vector) with limbs, or
	# fell back to a flat bitmap. Also prints the received stroke count.
	if skin != null and skin.has_method("rig_summary"):
		label += " [%s | %d strokes]" % [skin.rig_summary(), strokes.size()]
	status_label.text = label
	if debug_timing_logs:
		print(
			"GameLevel spawn %s instantiate %.2f ms apply %.2f ms total %.2f ms" % [
				entity_id,
				float(instantiated_usec - instantiate_started) / 1000.0,
				float(applied_usec - instantiated_usec) / 1000.0,
				float(Time.get_ticks_usec() - spawn_started) / 1000.0
			]
		)
