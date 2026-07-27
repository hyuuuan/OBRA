extends ModalOverlay
## The pause menu, and the last link in the cancel chain.
##
## It no longer reads the cancel key itself, and no longer has to know that the draw
## panel exists in order to defer to it -- UIRouter's chain expresses that precedence
## instead. What is left here is what a pause menu actually does.

@onready var resume_button: Button = $PauseRoot/Panel/VBox/ResumeButton
@onready var level_select_button: Button = $PauseRoot/Panel/VBox/LevelSelectButton


func _ready() -> void:
	super()
	resume_button.pressed.connect(close_pause)
	level_select_button.pressed.connect(_return_to_levels)


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


func _return_to_levels() -> void:
	close()
	LevelManager.return_to_selector()
