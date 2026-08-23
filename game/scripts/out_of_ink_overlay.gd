extends ModalOverlay
## Shown when the ink budget runs out.
##
## ADVISORY, NOT A LOSS STATE. Running out of ink does not end the run: the morph
## already spawned is still under the player's control and the goal may still be
## reachable on foot. Turning this into a game over would be inventing a rule the
## game does not have, so the screen tells the player where they stand and offers a
## restart -- it does not impose one.
##
## Which is also why it closes on cancel. Dismissing it and carrying on is a
## legitimate choice.

signal restart_pressed
signal level_select_pressed

@onready var _resume_button: Button = $Root/Center/Panel/VBox/Buttons/ResumeButton
@onready var _restart_button: Button = $Root/Center/Panel/VBox/Buttons/RestartButton
@onready var _level_select_button: Button = $Root/Center/Panel/VBox/Buttons/LevelSelectButton


func _ready() -> void:
	super()
	_resume_button.pressed.connect(close)
	_restart_button.pressed.connect(_on_restart)
	_level_select_button.pressed.connect(_on_level_select)


func _on_opened() -> void:
	# The forgiving option takes focus, because this screen is a warning rather than
	# a verdict and the common answer is to keep playing.
	_resume_button.grab_focus()


func _on_restart() -> void:
	close()
	restart_pressed.emit()


func _on_level_select() -> void:
	close()
	level_select_pressed.emit()
