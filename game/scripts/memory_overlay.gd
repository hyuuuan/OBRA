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
	# The memory is literally a painting of Lola's -- the Empathy route shows her painting
	# this exact bridge -- so of everything in the game this is the one that most has to
	# arrive in a frame.
	UIFrame.wrap($Root/Center/Panel as PanelContainer)


## The running dialogue line is cleared before this opens. Both are story, both are framed,
## and one behind the other reads as two people talking over each other.
func _on_opened() -> void:
	get_tree().call_group(DialogueBox.GROUP, &"hide_line")
	_continue.pressed.connect(_on_continue)


func present(title: String, lines: PackedStringArray) -> void:
	_title.text = title.to_upper()
	_body.text = "\n\n".join(lines)
	open()


func _on_continue() -> void:
	close()
	dismissed.emit()
