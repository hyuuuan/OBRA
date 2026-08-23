extends ModalOverlay
## A memory of Lola, unlocked by the Empathy route (Game Design, Level 1, Choice 1:
## "Unlocks a memory cutscene showing Lola painting this exact bridge").
##
## Deliberately text and light rather than an animated sequence: the memory is the
## reward for the longer route, and it has to EXIST for that route to mean anything,
## but what it eventually looks like is art direction that does not exist yet. The
## contract -- present(title, lines) and a signal when it is done -- is what a
## finished cutscene would answer too.

signal dismissed()

@onready var _title: Label = $Root/Center/Panel/VBox/Title
@onready var _body: Label = $Root/Center/Panel/VBox/Body
@onready var _continue: Button = $Root/Center/Panel/VBox/ContinueButton


func _ready() -> void:
	super()
	closes_on_cancel = false
	_continue.pressed.connect(_on_continue)


func present(title: String, lines: PackedStringArray) -> void:
	_title.text = title.to_upper()
	_body.text = "\n\n".join(lines)
	open()


func _on_continue() -> void:
	close()
	dismissed.emit()
