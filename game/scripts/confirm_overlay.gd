extends ModalOverlay
## A yes/no gate for anything the player cannot undo. Currently one caller -- quit to
## desktop -- but it is a screen rather than an inline dialog so restart, and anything
## later that discards progress, do not each grow their own.
##
## The confirm signal fires and the overlay closes; the caller decides what happens.
## Nothing destructive lives in here.

signal confirmed

@onready var _title: Label = $Root/Panel/VBox/Title
@onready var _body: Label = $Root/Panel/VBox/Body
@onready var _confirm_button: Button = $Root/Panel/VBox/Buttons/ConfirmButton
@onready var _cancel_button: Button = $Root/Panel/VBox/Buttons/CancelButton


func _ready() -> void:
	super()
	_confirm_button.pressed.connect(_on_confirmed)
	_cancel_button.pressed.connect(close)


## Pose a question. `confirm_text` names the destructive action rather than saying
## "OK", so the button the player is about to press states what it does.
func ask(title: String, body: String, confirm_text: String = "CONFIRM") -> void:
	_title.text = title
	_body.text = body
	_confirm_button.text = confirm_text
	open()


func _on_opened() -> void:
	# Focus lands on CANCEL, not confirm: the safe choice is the one a stray Enter
	# should take.
	_cancel_button.grab_focus()


func _on_confirmed() -> void:
	close()
	confirmed.emit()
