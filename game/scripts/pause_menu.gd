extends ModalOverlay
## The pause menu, and the last link in the cancel chain.
##
## It no longer reads the cancel key itself, and no longer has to know that the draw
## panel exists in order to defer to it -- UIRouter's chain expresses that precedence
## instead. What is left here is what a pause menu actually does.
##
## Settings and Controls open OVER this one rather than replacing it, which is what
## the derived pause state exists for: closing the screen on top must not unpause a
## game that is still behind this menu.

## Overlays this menu can open. Paths rather than hard node names so the same script
## works from any scene that instances them.
@export var settings_path: NodePath = NodePath("../SettingsOverlay")
@export var controls_path: NodePath = NodePath("../ControlsOverlay")
@export var confirm_path: NodePath = NodePath("../ConfirmOverlay")

@onready var resume_button: Button = $PauseRoot/Panel/VBox/ResumeButton
@onready var restart_button: Button = $PauseRoot/Panel/VBox/RestartButton
@onready var settings_button: Button = $PauseRoot/Panel/VBox/SettingsButton
@onready var controls_button: Button = $PauseRoot/Panel/VBox/ControlsButton
@onready var level_select_button: Button = $PauseRoot/Panel/VBox/LevelSelectButton
@onready var quit_button: Button = $PauseRoot/Panel/VBox/QuitButton


func _ready() -> void:
	_shrink_panel_to_content()
	super()
	resume_button.pressed.connect(close_pause)
	restart_button.pressed.connect(_restart_level)
	settings_button.pressed.connect(_open_overlay.bind(settings_path))
	controls_button.pressed.connect(_open_overlay.bind(controls_path))
	level_select_button.pressed.connect(_return_to_levels)
	quit_button.pressed.connect(_ask_quit)


## Last in the cancel chain, so it always answers: nothing more modal was up, and the
## key toggles the menu. Every overlay ahead of it has already declined.
func handle_cancel() -> bool:
	if is_open():
		close_pause()
	else:
		open_pause()
	return true


func open_pause() -> void:
	open()


func close_pause() -> void:
	close()


func _on_opened() -> void:
	resume_button.grab_focus()


func _open_overlay(path: NodePath) -> void:
	var overlay := get_node_or_null(path) as ModalOverlay
	if overlay != null:
		overlay.open()


func _restart_level() -> void:
	close()
	LevelManager.restart_level()


func _return_to_levels() -> void:
	close()
	LevelManager.return_to_house()


func _ask_quit() -> void:
	var confirm := get_node_or_null(confirm_path)
	if confirm == null:
		return
	if not confirm.is_connected(&"confirmed", _quit_to_desktop):
		confirm.connect(&"confirmed", _quit_to_desktop)
	confirm.call(&"ask", "QUIT TO DESKTOP?", "Progress on this level will be lost.", "QUIT")


func _quit_to_desktop() -> void:
	# The backend is a child process, not a node: quitting the tree does not take it
	# with us, and the one it leaves behind holds the port the next launch needs.
	get_tree().call_group(BackendSupervisor.GROUP, &"stop_backend")
	get_tree().quit()


## Size the panel to what is in it, instead of to the fixed 520x560 slab it was authored
## as -- which left a band of empty green under "Quit to Desktop".
##
## Done in CODE and not by editing game_level.tscn, deliberately. Round-tripping that
## scene through instantiate()/pack() is LOSSY: it dropped WorldItemRoot and GoalMarker,
## which are nodes added onto the instanced EnvironmentBaseplate, and an earlier attempt
## flattened all eight sub-scene instances into the file. The overlays under ui/ are
## standalone scenes with nothing instanced inside them and round-trip cleanly; this one
## does not, so it is never packed.
func _shrink_panel_to_content() -> void:
	var panel := get_node_or_null(^"PauseRoot/Panel") as PanelContainer
	if panel == null:
		return
	var vbox := panel.get_node_or_null(^"VBox") as VBoxContainer
	if vbox != null:
		vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
		vbox.add_theme_constant_override("separation", 12)
	panel.custom_minimum_size = Vector2(520.0, 0.0)
	# A frame for the container to work out how tall its children actually are; asking
	# before that returns the authored size and nothing changes.
	await get_tree().process_frame
	panel.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
