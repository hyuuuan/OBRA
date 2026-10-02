class_name InventoryScreen
extends ModalOverlay
## Everything the player is carrying and everything they have found, on one screen.
##
## THERE WAS NO INVENTORY SCREEN AND NO KEY THAT OPENED ONE. What existed was the six-slot
## strip across the bottom of the play area (`InventoryHUD`), which hides itself entirely
## when the bag is empty -- so for most of a first playthrough the game showed no evidence
## that a bag existed at all. Everything else the player earns is worse off than that: the
## brass key, Lola's brush, the canvas, the hidden flower and every class they have
## successfully drawn all live on the profile and were visible nowhere.
##
## Three bands, because there are three genuinely different kinds of thing here and treating
## them as one list would be a lie about how they behave:
##
##  - THE BAG is six slots of drawings, it is level-scoped, and it empties. The slots are the
##    same `UISkin.slot()` frames the strip uses, deliberately -- two views of one bag that
##    drew themselves differently would be two bags.
##  - FOUND is permanent and global. It is the profile's own list, and an entry that is not
##    yet found is shown as an empty frame rather than hidden, because the shape of what is
##    still out there is the useful part.
##  - DRAWN is the fifty-class roster as a count and a grid.
##
## ⚠ THE ROSTER IS NOT A LIST OF ANSWERS. This game's hardest interface rule is that it never
## names a drawable class the player has not earned -- it is the whole reason `RequirementStrip`
## prints ability tags instead of classes, and `run_level1_audit` checks the live HUD against
## all fifty ids for exactly this. So a class the player has drawn is named here, and one they
## have not is an unnamed empty frame with no tooltip and no hint. Printing the roster would
## turn every obstacle in the game into a lookup.
##
## Built in code rather than authored as a .tscn, for the reason `RequirementStrip` gives:
## the content is entirely dynamic, there is nothing here worth authoring, and hand-written
## scene files have shipped with silently missing scripts in this project before.

## Fires when the player chooses to actually use what is in a bag slot. The level closes the
## screen and runs the slot through the same path the number keys use -- one implementation
## of "what does this slot do", which depends on whether the drawing is a tool or a prop.
signal slot_activated(slot: int)

## Named the way GameLevel names it: the key legend is read out of the LIVE InputMap, so a
## rebinding cannot leave this screen telling the player something untrue.
const ControlsKeys = preload("res://scripts/controls_overlay.gd")

const BAG_SLOT := Vector2(84.0, 84.0)
const FOUND_SLOT := Vector2(72.0, 72.0)
## WIDE ENOUGH FOR THE LONGEST NAME IN THE ROSTER. At 58 the frames were tidy and every
## six-letter class in the game -- Ladder, Circle, Square, Spider -- wrapped its last letter
## onto a second line, which is worse than not naming them at all. Geist Pixel at the
## twenty-pixel floor needs about seventy; eight columns of eighty fits the panel beside the
## detail pane with room to spare.
## WIDE ENOUGH FOR THE LONGEST NAME AND NO TALLER THAN ONE LINE OF IT. At 58 square, every
## six-letter class in the roster -- Ladder, Circle, Square, Spider -- wrapped its last
## letter onto a second line, which is worse than not naming them at all. Eighty wide takes
## the longest of them at the twenty-pixel type floor; forty-six tall keeps fifty of them to
## five rows, which is what stops the panel running off the bottom of an 900-tall screen.
## ⚠ FORTY-SIX WAS SIZED FOR ONE GRID OF FIFTY, and there are three grids now. Split into
## bands the roster is six rows rather than five -- twenty creatures and twenty-seven
## objects each round UP to a whole number of rows -- plus three sub-headings, and at 46 the
## panel ran off the bottom of the screen and took its own "Tab to close" footer with it.
## Thirty-six still clears one line of the twenty-pixel type floor; the WIDTH is what stops
## "Ladder" wrapping and that is unchanged.
## ⚠ NINETY-TWO, BECAUSE "TRIANGLE" IS THE LONGEST NAME IN THE ROSTER. At eighty it wrapped
## its last letter onto a second line inside a frame one line tall, so the "e" sat under the
## frame on the panel. Every other name fits either width; this one sets it.
const ROSTER_SLOT := Vector2(92.0, 34.0)
## Nine across is what the column beside the detail pane holds at that width -- and it takes
## the twenty-seven objects in exactly three rows, so a band ends where its kind ends. The
## three shapes are visibly a short row of their own rather than the tail of the row above,
## which is what the bands are for.
const ROSTER_COLUMNS := 9

## The three kinds the roster is counted in, in the order the thesis counts them: twenty
## creatures, twenty-seven objects, three geometric primitives. `role` is the manifest's
## own `runtime_role`, so a class cannot land in a band this screen invented.
const BANDS: Array[Dictionary] = [
	{"role": "active_ragdoll_morph", "title": "CREATURES"},
	{"role": "utility", "title": "OBJECTS"},
	{"role": "physics_morph", "title": "SHAPES"},
]

## The permanent things, in the order they are found. `art` is resolved lazily because two of
## these are textures that only exist once their scene has been compiled.
const FOUND: Array[Dictionary] = [
	{
		"id": "brush",
		"name": "Lola's Brush",
		"note": "Her brush. Everything you can do in a level runs through it.",
	},
	{
		"id": "L1_bale_key",
		"name": "The Brass Key",
		"note": "Off a nail inside the straw. Too small for the chest it was hanging over.",
	},
	{
		"id": "canvas_2_pista",
		"name": "Pista",
		"note": "Lola's second canvas. The plaza, the bunting, the whole town in the street.",
	},
	{
		"id": "flower_1",
		"name": "Hidden Flower",
		"note": "One of five. Pressed between the pages of her sketchbook.",
	},
	# Earned by the dance in Piyesta and recorded since, but never listed here: a player who
	# won it saw nothing in the bag, and the flowers are only fair if the count can be seen.
	{
		"id": "L2_HF",
		"name": "Hidden Flower",
		"note": "One of five. The dancers gave it to you after the dance, as they once gave it to her.",
	},
	# Dagat's, and the reason the bag is where the count lives. The design asks for the five
	# to be visible somewhere between levels -- diegetically, without explaining what they are
	# for -- because a player who missed one in Payyo otherwise spends four more levels
	# chasing an ending they have already lost.
	{
		"id": "L3_HF",
		"name": "Hidden Flower",
		"note": "One of five. It had been holding on to it all along, down in the dark, and it gave it up gladly.",
	},
]

var inventory_manager: InventoryManager
var registry: EntityRegistry

var _bag_buttons: Array[Button] = []
var _bag_art: Array[TextureRect] = []
var _found_buttons: Array[Button] = []
var _roster_count: Label
## role -> the count label and the grid for that band. See _build_roster.
var _band_counts: Dictionary = {}
var _band_grids: Dictionary = {}
var _detail_art: TextureRect
var _detail_title: Label
var _detail_note: Label
var _detail_price: Label
var _use_button: Button
## What is selected, as {"kind": "bag"|"found"|"drawn", "index"/"id"}.
var _chosen: Dictionary = {}
var _thumbnails: Dictionary = {}

## ⚠ IT WAS A STILL PICTURE YOU COULD ONLY CLICK. Kent, of this screen: "i dont like how the
## animation is happening ... i cant scroll, drag, etc. from it". It snapped on in one frame,
## its slots answered a click the way a menu button does -- a dip, a pop and a ring going off
## inside the frame -- the wheel did nothing, and the only way to use a drawing was to pick it
## and then find the button. So now: it rises in the way the drawing canvas does; a slot under
## the mouse lifts and lights; the wheel, a trackpad and the arrow keys step through everything
## on it; and a drawing can be DRAGGED -- onto another slot to swap the two (the slot is the
## number key, so this is how the ladder goes on 1), or off the bag to take it out, which for
## something set down puts it on the cursor where it was dropped.
##
## IT CLOSES AT ONCE, on purpose. Pause is derived from whichever overlays are open (see
## ModalOverlay), so a closing animation is either the game held paused behind it or a panel
## that still looks open after it has stopped being one. Tab and the world come back together.
const OPEN_FROM := 0.88
const OPEN_TIME := 0.32
## How far a slot lifts under the mouse, and how fast.
const HOVER_SCALE := 1.07
const HOVER_TIME := 0.09
## A trackpad scrolls in small amounts rather than in notches; this much is one step.
const PAN_STEP := 1.0
## ⚠ AND EACH ONE ARRIVES TWICE. Godot 4.7 hands `_input` two copies of every pan gesture that
## comes through Input.parse_input_event -- same delta, same frame, two objects (measured,
## window and headless alike) -- which is the road a trackpad's events take. Counted twice, a
## swipe moved the choice two places.
var _last_pan := Vector2.INF
var _last_pan_frame := -1
var _scrim: ColorRect
var _panel: PanelContainer
var _open_run: Tween
var _pan := 0.0
## class id -> its roster frame, and the drawn classes the bands were last built for. The
## bands are rebuilt only when that changes: rebuilt on every choice, the frame under the
## mouse was freed and remade on each step of the wheel and lost its hover.
var _roster_buttons: Dictionary = {}
var _roster_built_for: Variant = null


func _ready() -> void:
	super()
	pauses_game = true
	closes_on_cancel = true
	layer = 56
	_build()


## Whatever the level wants this to read. Called once, before it is ever opened.
func wire(manager: InventoryManager, entity_registry: EntityRegistry) -> void:
	inventory_manager = manager
	registry = entity_registry
	if manager != null and not manager.inventory_changed.is_connected(_on_inventory_changed):
		manager.inventory_changed.connect(_on_inventory_changed)


func _on_inventory_changed(_items: Array) -> void:
	if is_open():
		refresh()


## THE KEY THAT OPENS IT HAS TO CLOSE IT, AND GAMELEVEL CANNOT DO THAT.
##
## `inventory_open` is read in `GameLevel._unhandled_input`, and this screen pauses the tree
## -- GameLevel's process mode is INHERIT, so while the bag is up that handler does not run
## at all. Escape would still work, because UIRouter walks its cancel chain from
## `_shortcut_input` on a node that is PROCESS_MODE_ALWAYS. But a player who pressed Tab to
## open it will press Tab to close it, and it would have done nothing.
##
## `_shortcut_input` rather than `_unhandled_input`, for the same reason UIRouter uses it:
## it runs before anything a Control might swallow. Tab is also Godot's own focus-next key.
func _shortcut_input(event: InputEvent) -> void:
	if not is_open() or not event.is_action_pressed(&"inventory_open"):
		return
	get_viewport().set_input_as_handled()
	close()


func _on_opened() -> void:
	# The story box and the bag are two claims on the same screen, and this one was opened
	# on purpose. Same courtesy MemoryOverlay pays.
	get_tree().call_group(DialogueBox.GROUP, &"hide_line")
	_chosen = {}
	_pan = 0.0
	refresh()
	_rise()


## In the drawing canvas's handwriting -- the dark arrives first, the panel settles out of the
## pale gold the interface is trimmed in and overshoots into place -- and quicker, because this
## is opened far more often than the canvas is.
func _rise() -> void:
	if _open_run != null and _open_run.is_valid():
		_open_run.kill()
	_panel.pivot_offset = _panel.size * 0.5
	_scrim.modulate.a = 0.0
	_panel.modulate = Color(UISkin.GOLD_PALE.r, UISkin.GOLD_PALE.g, UISkin.GOLD_PALE.b, 0.0)
	_panel.scale = Vector2.ONE * OPEN_FROM
	_open_run = create_tween()
	# This screen is what pauses the game; a tween bound to the pause would never start.
	_open_run.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_open_run.set_parallel(true)
	_open_run.tween_property(_scrim, "modulate:a", 1.0, OPEN_TIME * 0.6) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_open_run.tween_property(_panel, "modulate", Color.WHITE, OPEN_TIME * 0.55) \
		.set_delay(0.03).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_open_run.tween_property(_panel, "scale", Vector2.ONE, OPEN_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Whether it has finished arriving.
func is_settled() -> bool:
	return is_open() and not (_open_run != null and _open_run.is_valid() and _open_run.is_running())


# --- Looking through it ----------------------------------------------------------------

## The wheel, a trackpad and the arrows step through everything on the screen; Enter takes
## out the drawing that is chosen. In `_input` rather than `_unhandled_input`, because the
## panel and its slots stop the mouse -- a wheel turned over them never reaches unhandled.
func _input(event: InputEvent) -> void:
	if not is_open():
		return
	var wheel := event as InputEventMouseButton
	if wheel != null:
		if wheel.pressed and wheel.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT]:
			_step(1)
			get_viewport().set_input_as_handled()
		elif wheel.pressed and wheel.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT]:
			_step(-1)
			get_viewport().set_input_as_handled()
		return
	# A Mac trackpad does not turn a wheel: two fingers arrive as a pan, in small amounts.
	var pan := event as InputEventPanGesture
	if pan != null:
		get_viewport().set_input_as_handled()
		if pan.delta == _last_pan and Engine.get_process_frames() == _last_pan_frame:
			return
		_last_pan = pan.delta
		_last_pan_frame = Engine.get_process_frames()
		_pan += pan.delta.y + pan.delta.x
		while absf(_pan) >= PAN_STEP:
			_step(1 if _pan > 0.0 else -1)
			_pan -= PAN_STEP * signf(_pan)
		return
	if event.is_action_pressed(&"ui_right", true) or event.is_action_pressed(&"ui_down", true):
		_step(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_left", true) or event.is_action_pressed(&"ui_up", true):
		_step(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept") and String(_chosen.get("kind", "")) == "bag":
		get_viewport().set_input_as_handled()
		_use_chosen()


## Everything that can be chosen, in the order the screen reads: the bag, what has been found,
## then what has been drawn, band by band.
func _choices() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index in range(_bag_buttons.size()):
		if inventory_manager != null and inventory_manager.peek_item(index) != null:
			out.append({"kind": "bag", "index": index})
	for entry in FOUND:
		var id := String(entry["id"])
		if _has_found(id) and not _is_used(id):
			out.append({"kind": "found", "id": id})
	var profile := get_node_or_null(^"/root/PlayerProfile")
	var drawn: Array = profile.call("get_drawn_classes") if profile != null else []
	for band: Variant in BANDS:
		for id in _ids_with_role(String((band as Dictionary)["role"])):
			if drawn.has(id):
				out.append({"kind": "drawn", "id": id})
	return out


func _step(direction: int) -> void:
	var choices := _choices()
	if choices.is_empty():
		return
	var at := choices.find(_chosen)
	if at < 0:
		at = 0 if direction > 0 else choices.size() - 1
	else:
		at = posmod(at + direction, choices.size())
	_chosen = choices[at]
	refresh()
	_show_choice()


# --- Dragging ----------------------------------------------------------------------

func _drag_from_bag(_at: Vector2, index: int) -> Variant:
	var item := inventory_manager.peek_item(index) if inventory_manager != null else null
	if item == null:
		return null
	# What is being carried is what is chosen, so the pane says what is in the hand.
	_chosen = {"kind": "bag", "index": index}
	refresh()
	# Centred on the pointer: a preview hangs from its top-left corner otherwise.
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := TextureRect.new()
	art.texture = _thumbnail(item)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.size = BAG_SLOT
	art.position = -BAG_SLOT * 0.5
	art.modulate = Color(1.0, 1.0, 1.0, 0.85)
	holder.add_child(art)
	_bag_buttons[index].set_drag_preview(holder)
	return {"bag_slot": index}


func _can_drop_on_bag(_at: Vector2, data: Variant, index: int) -> bool:
	return data is Dictionary and (data as Dictionary).has("bag_slot") \
		and int((data as Dictionary)["bag_slot"]) != index


func _drop_on_bag(_at: Vector2, data: Variant, index: int) -> void:
	var from := int((data as Dictionary)["bag_slot"])
	# Chosen first: moving it refreshes this screen, and the pane follows the drawing.
	_chosen = {"kind": "bag", "index": index}
	if inventory_manager == null or not inventory_manager.move_item(from, index):
		_chosen = {"kind": "bag", "index": from}
	refresh()
	_show_choice()


func _can_drop_outside(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has("bag_slot")


## Out of the bag -- the same thing TAKE IT OUT does, so a tool goes into the hand and a thing
## to set down goes onto the cursor, right where it was let go.
func _drop_outside(_at: Vector2, data: Variant) -> void:
	_chosen = {"kind": "bag", "index": int((data as Dictionary)["bag_slot"])}
	_use_chosen()


# --- Building ------------------------------------------------------------------------

func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(UISkin.INK, 0.86)
	root.add_child(scrim)
	_scrim = scrim
	# Off the bag is out of the bag: a drawing dropped anywhere outside the panel is taken out.
	scrim.set_drag_forwarding(Callable(), _can_drop_outside, _drop_outside)

	var centre := CenterContainer.new()
	centre.name = "Centre"
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(centre)

	# ⚠ IN A HOLDER, NOT IN THE CENTRE CONTAINER ITSELF. A container resets the scale of every
	# child it lays out, and filling this screen on the way in lays it out -- so the rise was
	# cut off on its first frames and the panel snapped to full size anyway. A plain Control is
	# never sorted; the holder is as big as the panel, and the container centres that.
	var holder := Control.new()
	holder.name = "Holder"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(holder)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(1240.0, 0.0)
	holder.add_child(panel)
	_panel = panel
	panel.minimum_size_changed.connect(func() -> void:
		panel.reset_size()
		holder.custom_minimum_size = panel.size)
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size * 0.5)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override(&"separation", 14)
	panel.add_child(column)

	# The title, and what the screen is FOR beside it. A player opens this because they want
	# to know what they can draw; the sentence saying so belongs where their eye lands first.
	var head := HBoxContainer.new()
	head.name = "Head"
	head.add_theme_constant_override(&"separation", 16)
	column.add_child(head)
	var title := Label.new()
	title.name = "Title"
	title.theme_type_variation = &"ScreenTitle"
	title.text = "YOUR BAG"
	head.add_child(title)
	var blurb := Label.new()
	blurb.name = "Blurb"
	blurb.theme_type_variation = &"HudCaption"
	blurb.add_theme_color_override(&"font_color", UISkin.MUTED)
	blurb.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	blurb.size_flags_vertical = Control.SIZE_SHRINK_END
	blurb.text = "what you are carrying, and what this place knows you can draw"
	head.add_child(blurb)
	column.add_child(HSeparator.new())

	var body := HBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override(&"separation", 20)
	column.add_child(body)

	var left := VBoxContainer.new()
	left.name = "Left"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override(&"separation", 14)
	body.add_child(left)

	# ⚠ THE THINGS YOU HAVE, THEN THE THINGS THAT EXIST. The bag, the found objects and the
	# roster used to run down one column as three headings on one flat ground, and the detail
	# pane stood beside all three with three hundred pixels of empty panel under its own
	# button. Now: what you are carrying along the top, what exists under it, and the pane
	# down the side of both -- so the pane is as tall as what it describes and nothing on this
	# screen is a field of boxes with no ground of its own.
	# Side by side rather than stacked: six bag slots and four found ones are 800 units of
	# content in a column 900 wide, so stacked they left a hand's width of empty panel beside
	# each and pushed the roster down the screen for nothing.
	var carried := HBoxContainer.new()
	carried.name = "Carried"
	carried.add_theme_constant_override(&"separation", 14)
	left.add_child(carried)
	_build_bag(carried)
	_build_found(carried)
	_build_roster(left)
	_build_detail(body)

	column.add_child(HSeparator.new())
	var footer := Label.new()
	footer.name = "Footer"
	footer.theme_type_variation = &"HudCaption"
	footer.add_theme_color_override(&"font_color", UISkin.MUTED)
	footer.text = "%s to close  ·  scroll to look through  ·  drag a drawing to another slot, or off the bag to take it out" \
		% ControlsKeys.keys_for("inventory_open")
	column.add_child(footer)


func _heading(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"HudCaption"
	label.add_theme_color_override(&"font_color", UISkin.GOLD)
	label.text = text
	parent.add_child(label)
	return label


## A titled section: a sunk panel with its heading on a row of its own and, where there is a
## count to give, a quiet figure at the right end of that row. Returns the box the caller
## fills.
##
## The screen used to be a single column of headings and rows on one flat ground, so the eye
## had nothing to group by and read fifty empty frames and six bag slots as one field of
## boxes. A ground per section is the cheapest fix and the one the rest of the interface
## already uses.
func _section(parent: Control, text: String, note: Label = null) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = "%sSection" % text.capitalize()
	panel.add_theme_stylebox_override(&"panel", UISkin.well())
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	panel.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	column.add_child(row)
	_heading(row, text)
	if note != null:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(spacer)
		row.add_child(note)
	return column


func _build_bag(parent: Control) -> void:
	var note := Label.new()
	note.theme_type_variation = &"HudCaption"
	note.add_theme_color_override(&"font_color", UISkin.MUTED)
	note.text = "keys 1 - 6"
	var column := _section(parent, "THE BAG", note)
	var row := HBoxContainer.new()
	row.name = "Bag"
	row.add_theme_constant_override(&"separation", 8)
	column.add_child(row)
	for index in range(6):
		var button := _slot_button(BAG_SLOT)
		button.pressed.connect(_choose_bag.bind(index))
		button.set_drag_forwarding(_drag_from_bag.bind(index), _can_drop_on_bag.bind(index),
			_drop_on_bag.bind(index))
		row.add_child(button)
		_bag_buttons.append(button)

		var art := TextureRect.new()
		art.name = "Drawing"
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.offset_left = 10.0
		art.offset_top = 10.0
		art.offset_right = -10.0
		art.offset_bottom = -10.0
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(art)
		_bag_art.append(art)

		# The key that reaches this slot, which is the same number the strip prints.
		var number := Label.new()
		number.name = "Number"
		number.text = str(index + 1)
		number.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
		number.add_theme_color_override(&"font_color", UISkin.GOLD)
		number.add_theme_constant_override(&"outline_size", 5)
		number.add_theme_color_override(&"font_outline_color", UISkin.INK)
		number.position = Vector2(7.0, 2.0)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(number)


func _build_found(parent: Control) -> void:
	var note := Label.new()
	note.theme_type_variation = &"HudCaption"
	note.add_theme_color_override(&"font_color", UISkin.MUTED)
	note.text = "kept for the run"
	var column := _section(parent, "FOUND", note)
	var row := HBoxContainer.new()
	row.name = "Found"
	row.add_theme_constant_override(&"separation", 8)
	column.add_child(row)
	for entry in FOUND:
		var button := _slot_button(FOUND_SLOT)
		button.pressed.connect(_choose_found.bind(String(entry["id"])))
		row.add_child(button)
		_found_buttons.append(button)

		var art := TextureRect.new()
		art.name = "Art"
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.offset_left = 8.0
		art.offset_top = 8.0
		art.offset_right = -8.0
		art.offset_bottom = -8.0
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(art)


func _build_roster(parent: Control) -> void:
	_roster_count = Label.new()
	_roster_count.theme_type_variation = &"HudCaption"
	_roster_count.add_theme_color_override(&"font_color", UISkin.MUTED)
	var section := _section(parent, "WHAT YOU HAVE DRAWN", _roster_count)

	# ⚠ THE SHAPE OF WHAT IS STILL OUT THERE, WITHOUT NAMING ANY OF IT.
	#
	# One flat grid of fifty told a player only that more exists. It could not tell them
	# that twenty of the fifty are ANIMALS -- which is the most useful thing a player who has
	# only ever drawn ladders could learn, and the reason this screen was asked for. A first
	# attempt ordered one grid by kind and printed the split as a caption; the bands were
	# invisible, because twenty-seven objects do not end on a row boundary and the three
	# shapes sat on the end of the objects' last row looking like more objects.
	#
	# So three bands, each with its own count. COUNTING A GROUP NAMES NOTHING, so the rule at
	# the top of this file holds: a class the player has drawn is named, and one they have
	# not is an unnamed empty frame in a band that says what KIND of thing is missing.
	for band: Variant in BANDS:
		var spec: Dictionary = band
		# The band's name and its count on ONE line, to the left of its own frames rather
		# than stacked above them: three sub-headings in a column of grids read as six
		# headings, and the eye loses which count belongs to which field.
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		section.add_child(row)
		var name_label := Label.new()
		name_label.text = String(spec["title"])
		name_label.theme_type_variation = &"HudCaption"
		name_label.add_theme_color_override(&"font_color", UISkin.CREAM_TEXT)
		name_label.custom_minimum_size = Vector2(110.0, 0.0)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_label)
		var count := Label.new()
		count.name = "%sCount" % String(spec["role"])
		count.theme_type_variation = &"HudCaption"
		count.add_theme_color_override(&"font_color", UISkin.MUTED)
		count.custom_minimum_size = Vector2(62.0, 0.0)
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(count)
		_band_counts[String(spec["role"])] = count

		var grid := GridContainer.new()
		grid.name = "%sGrid" % String(spec["role"])
		grid.columns = ROSTER_COLUMNS
		grid.add_theme_constant_override(&"h_separation", 5)
		grid.add_theme_constant_override(&"v_separation", 4)
		row.add_child(grid)
		_band_grids[String(spec["role"])] = grid


func _build_detail(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "Detail"
	panel.custom_minimum_size = Vector2(268.0, 0.0)
	panel.add_theme_stylebox_override(&"panel", UISkin.well())
	parent.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	panel.add_child(column)

	# THE DRAWING ITSELF, in a frame of its own. It was a bare 168px strip of the pane's own
	# ground, so a thumbnail with a lot of white space in it -- which is most of them -- had
	# no edge and floated in the panel.
	var art_frame := PanelContainer.new()
	art_frame.add_theme_stylebox_override(&"panel", UISkin.chip(6.0, 6.0))
	# The drawing takes whatever height the pane has spare, rather than the pane holding a
	# well of nothing between the note and the button: it is the player's own drawing and it
	# is the one thing on this screen worth looking at big.
	art_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(art_frame)
	_detail_art = TextureRect.new()
	_detail_art.name = "Art"
	_detail_art.custom_minimum_size = Vector2(0.0, 140.0)
	_detail_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art_frame.add_child(_detail_art)

	_detail_title = Label.new()
	_detail_title.theme_type_variation = &"ScreenSubtitle"
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_detail_title)

	# ⚠ TWO LINES, NOT ONE JOINED BY A DOT. What it is and what it costs were printed as
	# "A tool you keep and use  ·  already paid for", which at this width wrapped wherever
	# the dot happened to fall -- and a line beginning with a separator reads as a mistake.
	# They are two different facts and they get a line each.
	_detail_note = Label.new()
	_detail_note.theme_type_variation = &"HudCaption"
	_detail_note.add_theme_color_override(&"font_color", UISkin.CREAM_TEXT)
	_detail_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_detail_note)

	_detail_price = Label.new()
	_detail_price.theme_type_variation = &"HudCaption"
	_detail_price.add_theme_color_override(&"font_color", UISkin.MUTED)
	_detail_price.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_detail_price)

	_use_button = Button.new()
	_use_button.theme_type_variation = &"PrimaryButton"
	_use_button.custom_minimum_size = Vector2(0.0, 48.0)
	_use_button.text = "TAKE IT OUT"
	_use_button.visible = false
	_use_button.pressed.connect(_use_chosen)
	column.add_child(_use_button)


func _slot_button(box: Vector2) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"InventorySlot"
	button.custom_minimum_size = box
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	# ⚠ OUT OF UIFeedback, which every other button in the game keeps. It gives each button a
	# dip on press, a pop back and a ring that leaves the click point -- right on a menu button,
	# and on this screen a ring going off inside a 34-pixel frame and a grid of frames that
	# jumped at every click. Its hover also tweened the same `scale` this one does, and
	# whichever started last won. Marked before the button enters the tree, which is when
	# UIFeedback looks.
	button.set_meta(&"ui_feedback", true)
	button.resized.connect(func() -> void: button.pivot_offset = button.size * 0.5)
	button.mouse_entered.connect(_hover.bind(button, true))
	button.mouse_exited.connect(_hover.bind(button, false))
	return button


## A slot that holds something lifts under the mouse; an empty frame does not, because there is
## nothing there to pick. Scale and self_modulate only -- the container owns the button's
## position, and `_paint` owns its modulate for the chosen state.
func _hover(button: Button, over: bool) -> void:
	if over and not bool(button.get_meta(&"live", false)):
		return
	var lift := button.create_tween()
	lift.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	lift.set_parallel(true)
	lift.tween_property(button, "scale", Vector2.ONE * (HOVER_SCALE if over else 1.0), HOVER_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	lift.tween_property(button, "self_modulate",
		Color(1.25, 1.2, 1.05, 1.0) if over else Color.WHITE, HOVER_TIME)


## The drawing in the pane comes up when something new is chosen, so the eye goes there.
func _show_choice() -> void:
	if _detail_art == null:
		return
	_detail_art.pivot_offset = _detail_art.size * 0.5
	_detail_art.scale = Vector2.ONE * 0.9
	_detail_art.modulate.a = 0.4
	var pop := _detail_art.create_tween()
	pop.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	pop.set_parallel(true)
	pop.tween_property(_detail_art, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_detail_art, "modulate:a", 1.0, 0.12)


# --- Filling -------------------------------------------------------------------------

func refresh() -> void:
	_refresh_bag()
	_refresh_found()
	_refresh_roster()
	_refresh_detail()


func _refresh_bag() -> void:
	var items: Array = inventory_manager.items() if inventory_manager != null else []
	for index in range(_bag_buttons.size()):
		var item := items[index] as DrawnItemData if index < items.size() else null
		var occupied := item != null
		var chosen := String(_chosen.get("kind", "")) == "bag" \
			and int(_chosen.get("index", -1)) == index
		_paint(_bag_buttons[index], occupied, chosen)
		_bag_buttons[index].tooltip_text = item.display_name if occupied else "Empty"
		_bag_art[index].texture = _thumbnail(item) if occupied else null


func _refresh_found() -> void:
	for index in range(_found_buttons.size()):
		var entry: Dictionary = FOUND[index]
		var id := String(entry["id"])
		var owned := _has_found(id)
		var chosen := String(_chosen.get("kind", "")) == "found" \
			and String(_chosen.get("id", "")) == id
		_paint(_found_buttons[index], owned, chosen)
		# An unfound thing is a frame and nothing else -- no name, no tooltip. The shape of
		# what is still out there is worth showing; what it is called is not this screen's
		# to give away.
		_found_buttons[index].tooltip_text = String(entry["name"]) if owned else ""
		var art := _found_buttons[index].get_node_or_null(^"Art") as TextureRect
		if art != null:
			art.texture = _found_art(id) if owned else null
		_found_buttons[index].visible = not _is_used(id)


func _refresh_roster() -> void:
	var profile := get_node_or_null(^"/root/PlayerProfile")
	var drawn: Array = profile.call("get_drawn_classes") if profile != null else []
	var total: int = int(profile.call("roster_size")) if profile != null else 50
	_roster_count.text = "%d / %d" % [drawn.size(), total]
	if _roster_built_for is Array and (_roster_built_for as Array) == drawn:
		for id: String in _roster_buttons:
			var chosen := String(_chosen.get("kind", "")) == "drawn" \
				and String(_chosen.get("id", "")) == id and drawn.has(id)
			_paint(_roster_buttons[id] as Button, drawn.has(id), chosen, true)
		return
	_roster_built_for = drawn.duplicate()
	_roster_buttons.clear()
	for band: Variant in BANDS:
		_fill_band(String((band as Dictionary)["role"]), drawn)


## One kind's frames, and the count above them.
##
## Rebuilt rather than diffed: it changes once per drawing. REMOVED, then freed --
## queue_free leaves the node in the tree until the end of the frame, so a rebuild would
## hand the GridContainer twice its children to lay out for one frame and it would visibly
## reflow.
func _fill_band(role: String, drawn: Array) -> void:
	var grid := _band_grids.get(role) as GridContainer
	var count := _band_counts.get(role) as Label
	if grid == null or count == null:
		return
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var ids := _ids_with_role(role)
	var known := 0
	for id_value: Variant in ids:
		if drawn.has(String(id_value)):
			known += 1
	count.text = "%d / %d" % [known, ids.size()]
	for id_value: Variant in ids:
		var id := String(id_value)
		var button := _slot_button(ROSTER_SLOT)
		var owned := drawn.has(id)
		var chosen := String(_chosen.get("kind", "")) == "drawn" \
			and String(_chosen.get("id", "")) == id and owned
		grid.add_child(button)
		_roster_buttons[id] = button
		_paint(button, owned, chosen, true)
		if not owned:
			# Unnamed, untooltipped, unclickable. The frame is the only thing it says, and
			# what it says is "one more of this kind is out there".
			continue
		button.tooltip_text = _display_name(id)
		button.pressed.connect(_choose_drawn.bind(id))
		var label := Label.new()
		label.text = _display_name(id)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override(&"font_size", UISkin.FONT_TINY)
		label.add_theme_color_override(&"font_color", UISkin.CREAM_TEXT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(label)


## Every class the manifest gives this `runtime_role`, in manifest order.
##
## Off the manifest rather than a list here, which is the same split the thesis counts the
## roster by -- twenty creatures, twenty-seven objects, three geometric primitives -- so the
## bands on this screen and the numbers in Chapter 4 cannot drift apart.
func _ids_with_role(role: String) -> Array[String]:
	var ids: Array[String] = []
	for id_value: Variant in (registry.get_entity_ids() if registry != null else []):
		var id := String(id_value)
		if String(registry.get_entity(id).get("runtime_role", "")) == role:
			ids.append(id)
	return ids


func _refresh_detail() -> void:
	var kind := String(_chosen.get("kind", ""))
	_use_button.visible = kind == "bag"
	_detail_price.text = ""
	if kind.is_empty():
		_detail_art.texture = null
		_detail_title.text = "Nothing chosen"
		_detail_note.text = "Pick anything on this screen to see what it is."
		return
	if kind == "bag":
		var item := inventory_manager.peek_item(int(_chosen.get("index", -1))) \
			if inventory_manager != null else null
		if item == null:
			_chosen = {}
			_refresh_detail()
			return
		_detail_art.texture = _thumbnail(item)
		_detail_title.text = item.display_name
		_detail_note.text = _role_of(item.entity_id)
		_detail_price.text = _price_of(item)
		return
	if kind == "found":
		var id := String(_chosen.get("id", ""))
		for entry in FOUND:
			if String(entry["id"]) != id:
				continue
			_detail_art.texture = _found_art(id)
			_detail_title.text = String(entry["name"])
			_detail_note.text = String(entry["note"])
			var profile := get_node_or_null(^"/root/PlayerProfile")
			if profile != null and bool(profile.call("is_canvas_damaged", id)):
				_detail_note.text += "  It is creased along the break."
			return
		return
	var class_id := String(_chosen.get("id", ""))
	_detail_art.texture = null
	_detail_title.text = _display_name(class_id)
	_detail_note.text = _role_of(class_id)
	_detail_price.text = "Drawn and recognised. Drawing it again is free."


func _paint(button: Button, occupied: bool, chosen: bool, quiet: bool = false) -> void:
	# The same factory the bottom strip uses. Two views of one bag that styled their slots
	# separately would drift the first time either was touched.
	#
	# ⚠ EXCEPT FOR THE ONES THAT ARE NOT THERE YET. Fifty roster frames in the bag slot's own
	# gold ring made a wall of gold boxes that shouted louder than the six things the player
	# is actually carrying -- and most of them stand for a class nobody has drawn. An unknown
	# class is a hollow in the panel: no ring, no fill, just enough edge to count.
	for state in [&"normal", &"hover", &"pressed", &"disabled"]:
		button.add_theme_stylebox_override(state,
			UISkin.hollow() if quiet and not occupied else UISkin.slot(occupied, chosen))
	button.modulate = Color(1.12, 1.12, 1.04) if chosen else Color.WHITE
	button.set_meta(&"live", occupied)


# --- Choosing ------------------------------------------------------------------------

func _choose_bag(index: int) -> void:
	_chosen = {"kind": "bag", "index": index}
	refresh()
	_show_choice()


func _choose_found(id: String) -> void:
	if not _has_found(id):
		return
	_chosen = {"kind": "found", "id": id}
	refresh()
	_show_choice()


func _choose_drawn(id: String) -> void:
	_chosen = {"kind": "drawn", "id": id}
	refresh()
	_show_choice()


## Hand the slot back to the level, which decides what a slot DOES -- a tool goes into the
## hand and a prop goes into a placement, and that judgement already exists in one place.
func _use_chosen() -> void:
	if String(_chosen.get("kind", "")) != "bag":
		return
	var slot := int(_chosen.get("index", -1))
	close()
	slot_activated.emit(slot)


# --- Reading -------------------------------------------------------------------------

## A found thing given up -- the brass key left in the lock it opened -- is not carried, and is
## not shown: not as found, and not as an empty frame waiting to be found either.
func _is_used(id: String) -> bool:
	var profile := get_node_or_null(^"/root/PlayerProfile")
	return profile != null and profile.has_method("is_item_used") \
		and bool(profile.call("is_item_used", id))


func _has_found(id: String) -> bool:
	var profile := get_node_or_null(^"/root/PlayerProfile")
	if profile == null:
		return false
	if id == "brush":
		return bool(profile.call("has_brush"))
	if id.begins_with("canvas_"):
		return bool(profile.call("has_object", id))
	return bool(profile.call("is_collectible_found", id))


func _found_art(id: String) -> Texture2D:
	match id:
		"brush":
			return load("res://assets/hud/brush_full.png") as Texture2D
		"L1_bale_key":
			return UIIcons.key()
		"canvas_2_pista":
			return load("res://assets/hub/paintings/level_2.png") as Texture2D
		"flower_1", "L2_HF", "L3_HF":
			return load("res://assets/Level1/hidden_flower.png") as Texture2D
		_:
			return null


func _display_name(entity_id: String) -> String:
	if registry != null:
		var entry := registry.get_entity(entity_id)
		if not entry.is_empty():
			return String(entry.get("display_name", entity_id.capitalize()))
	return entity_id.capitalize()


## What this class IS, in the game's own vocabulary rather than the manifest's.
##
## ⚠ A TOOL AND A PLACEABLE ARE BOTH "utility" IN THE MANIFEST AND ARE NOT THE SAME THING TO
## HOLD. The note read "a thing you hold or set down · costs ink when you set it down" for
## every one of them, which was the placeable's rule printed under an axe -- a tool is paid for
## once, on the page, and kept (FR-7). The bag is where the player goes to find out what they
## have; it cannot describe half of it wrongly.
func _role_of(entity_id: String) -> String:
	var entry: Dictionary = registry.get_entity(entity_id) if registry != null else {}
	match String(entry.get("runtime_role", "")):
		"utility":
			return "A tool you keep and use" if String(entry.get("ink_role", "")) == "tool" \
				else "A thing you set down"
		"physics_morph":
			return "A shape you set down"
		_:
			return "Something you become"


## What it costs from here, by the same rule the level charges: a tool once, a placeable every
## time it is set down.
func _price_of(item: DrawnItemData) -> String:
	var entry: Dictionary = registry.get_entity(item.entity_id) if registry != null else {}
	if String(entry.get("ink_role", "")) == "tool":
		return "already paid for" if item.ink_committed \
			else "a unit of ink, once"
	return "a unit of ink each time you set it down"


func _thumbnail(item: DrawnItemData) -> Texture2D:
	if item == null or item.image == null:
		return null
	var cached: Texture2D = _thumbnails.get(item.instance_id)
	if cached != null:
		return cached
	# Paper knocked out and cropped to the ink, so the slot holds the DRAWING rather than a
	# white square with something in the middle of it. See DrawingSkin2D.thumbnail.
	var texture := DrawingSkin2D.thumbnail(item.image)
	if texture == null:
		texture = ImageTexture.create_from_image(item.image)
	_thumbnails[item.instance_id] = texture
	return texture
