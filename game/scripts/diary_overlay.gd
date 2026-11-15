class_name DiaryOverlay
extends ModalOverlay
## A page of Lola's diary, open in front of the apo: as it is found, and (Dilim) when a level
## opens the book at the page about what is in front of her.
##
## THE SAME BOOK AS THE BAG'S DIARY TAB, holding only this entry, so the page found is the page
## kept: what the player reads here is what they will find again under DIARY, set the same way.
## A page left unread is still found -- it is recorded before this opens, not when it closes.
##
## Built in code, as InventoryScreen is, for the reason it gives.

## Closed, by CONTINUE or by Escape -- the level waits on this.
signal dismissed()

const LAYER := 68
## How long the book stays open in an unattended run before it puts itself down. Long enough for a
## probe to see it open; short enough that a run walking past a page does not stall on it.
const AUTO_HOLD := 0.5

var _title: Label
var _note: Label
var _book: DiaryBook
var _continue: Button


func _ready() -> void:
	super()
	layer = LAYER
	closes_on_cancel = true
	_build()


## Open the book at an entry (and at a page of it, if the level names one). `note` is what the
## apo sees -- the entry's own "found" line when it is being found.
func present(entry_id: String, anchor: String = "", title: String = "A PAGE OF HER DIARY",
		note: String = "") -> void:
	var entry := Diary.entry(entry_id)
	if entry.is_empty():
		push_warning("DiaryOverlay: no entry '%s' in %s" % [entry_id, Diary.PATH])
		return
	_title.text = title
	_note.text = note if not note.is_empty() else String(entry.get("found", ""))
	_note.visible = not _note.text.is_empty()
	var only: Array[Dictionary] = [entry]
	_book.set_entries(only)
	_book.open_at(entry_id, anchor)
	open()
	if _unattended():
		_put_down_soon()


## ⚠ AN UNATTENDED RUN PUTS IT DOWN BY ITSELF, the way it drops a line of dialogue. A page opens
## over a paused game, and every probe that walked over one, or into a Dilim creature whose page
## opens on arrival, stopped there with nobody to press CONTINUE. The suites already tell the
## dialogue box to dismiss itself (DialogueBox.set_auto_dismiss); the book asks the box. It hides
## the same pause bugs that does -- turn it off when chasing one.
func _unattended() -> bool:
	var box := get_tree().get_first_node_in_group(DialogueBox.GROUP)
	return box != null and bool(box.get(&"auto_dismiss"))


## Only the page it was started for: a timer left from a page already put down must not close
## the next one early.
var _shown := 0


func _put_down_soon() -> void:
	_shown += 1
	var this_one := _shown
	await get_tree().create_timer(AUTO_HOLD, true).timeout
	if is_open() and this_one == _shown:
		close()


func book() -> DiaryBook:
	return _book


## The running dialogue line is cleared first, as MemoryOverlay does: both are story, and one
## behind the other reads as two people talking over each other.
func _on_opened() -> void:
	get_tree().call_group(DialogueBox.GROUP, &"hide_line")


func _on_closed() -> void:
	dismissed.emit()


## Left and right turn the page, as in the bag; the wheel too. Enter is CONTINUE.
func _input(event: InputEvent) -> void:
	if not is_open():
		return
	var wheel := event as InputEventMouseButton
	if wheel != null and wheel.pressed:
		if wheel.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT]:
			_book.turn(1)
			get_viewport().set_input_as_handled()
		elif wheel.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT]:
			_book.turn(-1)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_right", true):
		_book.turn(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_left", true):
		_book.turn(-1)
		get_viewport().set_input_as_handled()


func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A step darker than the memory card's: the book is tall enough that its title sits over the
	# quest banner, which showed through at 0.9.
	scrim.color = Color(UISkin.INK, 0.94)
	root.add_child(scrim)

	var centre := CenterContainer.new()
	centre.name = "Center"
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(centre)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	centre.add_child(panel)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 8)
	panel.add_child(column)

	_title = Label.new()
	_title.name = "Title"
	_title.theme_type_variation = &"ScreenSubtitle"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)

	# One line wide enough for the longest "found" line, so the book keeps the screen's height.
	_note = Label.new()
	_note.name = "Note"
	_note.theme_type_variation = &"HudCaption"
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(1160.0, 0.0)
	_note.add_theme_color_override(&"font_color", UISkin.MUTED)
	column.add_child(_note)

	_book = DiaryBook.new()
	_book.name = "Book"
	_book.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_book)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 24)
	column.add_child(row)
	var hint := Label.new()
	hint.name = "Hint"
	hint.theme_type_variation = &"HudCaption"
	hint.add_theme_color_override(&"font_color", UISkin.MUTED)
	hint.text = "kept in your bag, under DIARY  ·  click a page or use the arrows to turn it"
	row.add_child(hint)
	_continue = Button.new()
	_continue.name = "ContinueButton"
	_continue.theme_type_variation = &"PrimaryButton"
	_continue.text = "CONTINUE"
	_continue.custom_minimum_size = Vector2(220.0, 56.0)
	_continue.pressed.connect(close)
	row.add_child(_continue)
	default_focus_path = get_path_to(_continue)
