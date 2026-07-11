extends CanvasLayer

@export var draw_panel_path: NodePath = NodePath("../DrawPanel")

@onready var draw_panel: CanvasLayer = get_node_or_null(draw_panel_path) as CanvasLayer
@onready var resume_button: Button = $PauseRoot/Panel/VBox/ResumeButton
@onready var level_select_button: Button = $PauseRoot/Panel/VBox/LevelSelectButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(close_pause)
	level_select_button.pressed.connect(_return_to_levels)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or LevelManager.is_transitioning():
		return
	if draw_panel != null and draw_panel.visible:
		return
	get_viewport().set_input_as_handled()
	if visible:
		close_pause()
	else:
		open_pause()


func open_pause() -> void:
	visible = true
	get_tree().paused = true
	resume_button.grab_focus()


func close_pause() -> void:
	visible = false
	get_tree().paused = false


func _return_to_levels() -> void:
	visible = false
	get_tree().paused = false
	LevelManager.return_to_selector()
