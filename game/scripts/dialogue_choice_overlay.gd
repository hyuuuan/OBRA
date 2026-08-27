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
##
## `notes` IS THE POINT OF THIS SCREEN NOW, and it is the fix for the worst thing in the
## level. The three buttons are Lolo's own words -- "Let us put it back", "There is another
## way", "I will make a way" -- and none of them says what the route will then ASK the
## player for. The requirement was taught seconds earlier as three lines on the hint bar,
## which the choice interrupts, so in practice the player heard one of the three, picked a
## sentence that named nothing, and was then told by the requirement strip that the level
## wanted something they had never been told about. Choosing a path and being instructed in
## a different one is exactly what it looked like from outside.
##
## So each button carries the requirement of the route it commits to, worded by
## `RequirementStrip.phrase` -- the same function the strip itself uses, reading the same
## level data. The button and the instruction cannot disagree, because they are one string.
func present(speaker: String, context: String, choices: Dictionary,
		notes: Dictionary = {}) -> void:
	_speaker.text = speaker.to_upper()
	_context.text = context
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	for route in ROUTES:
		var line := String(choices.get(route, ""))
		if line.is_empty():
			continue
		var note := String(notes.get(route, ""))
		var button := Button.new()
		# Tall enough for the sentence AND the two lines of requirement under it. At 104 the
		# gloss ran out through the bottom border of its own button.
		button.custom_minimum_size = Vector2(0, 68 if note.is_empty() else 140)
		button.theme_type_variation = &"DialogButton"
		button.pressed.connect(_on_route_pressed.bind(route))
		_buttons.add_child(button)
		# A Button is not a container, so the two lines are laid into it by hand: added
		# AFTER the button is in the tree, because a Control measured outside it does not
		# report the size it will have -- the trap HUD_SKIN.md keeps a note about.
		var column := VBoxContainer.new()
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		column.offset_left = 14.0
		column.offset_right = -14.0
		column.offset_top = 8.0
		column.offset_bottom = -8.0
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override(&"separation", 2)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(column)
		column.add_child(_line_label(line, false))
		# The requirement arrives as "NEEDS SPAN" and its gloss on two lines. Split, so the
		# ability can be gold and the description under it quieter -- one label would have to
		# pick a single weight for both, and the ability is the part the player has to carry
		# with them to the obstacle.
		for index in range(note.split("\n").size()):
			column.add_child(_line_label(note.split("\n")[index], true, index > 0))
	open()
	await get_tree().process_frame
	if _buttons.get_child_count() > 0:
		(_buttons.get_child(0) as Button).grab_focus()


## One line inside a button. The requirement is set in the interface's own gold and a size
## down from the sentence: it is what the choice COSTS, which is a different kind of thing
## from what Lolo says out loud, and it must not compete with it.
func _line_label(text: String, is_note: bool, is_gloss: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_note:
		label.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
		label.add_theme_color_override(&"font_color",
			UISkin.WOOD_LIT if is_gloss else UISkin.GILT_EDGE)
	return label


func _on_route_pressed(route: String) -> void:
	# Closed before the route is announced, so the world is running again by the time
	# the level starts rearranging itself and the player sees it happen.
	close()
	route_picked.emit(route)
