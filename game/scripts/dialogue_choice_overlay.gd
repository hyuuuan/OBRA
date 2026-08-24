extends ModalOverlay
## Lolo pauses time to ask (Game Design §3). The three answers are not flavour: each
## one physically alters the level and locks the other two away for this playthrough,
## so this screen is a decision point and not something to dismiss -- hence
## closes_on_cancel = false, the same reasoning as the level-complete screen.
##
## A view. It shows the lines it is handed and reports which route was picked; what a
## route then does to the level is RouteLayout2D's business.

signal route_picked(route: String)

## Route ids in PlayerProfile.ROUTES order, one per button.
const ROUTES := ["artist", "pragmatist", "protector"]

@onready var _speaker: Label = $Root/Center/Panel/VBox/Speaker
@onready var _context: Label = $Root/Center/Panel/VBox/Context
@onready var _buttons: VBoxContainer = $Root/Center/Panel/VBox/Choices


func _ready() -> void:
	super()
	closes_on_cancel = false
	# A decision is the most story-laden thing in the level -- the answer physically
	# rearranges it -- so it is framed like the rest of the story rather than presented as
	# a settings dialog with three long buttons in it.
	UIFrame.wrap($Root/Center/Panel as PanelContainer)


## The running dialogue line is cleared before this opens. Both are story, both are framed,
## and one behind the other reads as two people talking over each other.
func _on_opened() -> void:
	get_tree().call_group(DialogueBox.GROUP, &"hide_line")


## `choices` is one line per route, in ROUTES order. Anything missing is skipped
## rather than rendered blank, so a level may offer two answers instead of three.
func present(speaker: String, context: String, choices: Dictionary) -> void:
	_speaker.text = speaker.to_upper()
	_context.text = context
	for child in _buttons.get_children():
		child.queue_free()
	for route in ROUTES:
		var line := String(choices.get(route, ""))
		if line.is_empty():
			continue
		var button := Button.new()
		button.text = line
		button.custom_minimum_size = Vector2(0, 68)
		button.theme_type_variation = &"DialogButton"
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_route_pressed.bind(route))
		_buttons.add_child(button)
	open()
	await get_tree().process_frame
	if _buttons.get_child_count() > 0:
		(_buttons.get_child(0) as Button).grab_focus()


func _on_route_pressed(route: String) -> void:
	# Closed before the route is announced, so the world is running again by the time
	# the level starts rearranging itself and the player sees it happen.
	close()
	route_picked.emit(route)
