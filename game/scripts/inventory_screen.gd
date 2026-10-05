class_name InventoryScreen
extends ModalOverlay
## Everything the player is carrying and everything they have found, drawn as the bag itself.
##
## THERE WAS NO INVENTORY SCREEN AND NO KEY THAT OPENED ONE. What existed was the six-slot
## strip across the bottom of the play area (`InventoryHUD`), which hides itself entirely
## when the bag is empty -- so for most of a first playthrough the game showed no evidence
## that a bag existed at all. Everything else the player earns is worse off than that: the
## brass key, Lola's brush, the canvas, the hidden flower and every class they have
## successfully drawn all live on the profile and were visible nowhere.
##
## It is a leather bag (BagArt) with three things in its lining, because there are three
## genuinely different kinds of thing here and treating them as one list would be a lie about
## how they behave:
##
##  - THE POCKETS are six slots of drawings, level-scoped, and they empty. Keys 1 - 6.
##  - FOUND is permanent and global. It is the profile's own list, and an entry that is not
##    yet found is shown as an empty pocket rather than hidden, because the shape of what is
##    still out there is the useful part.
##  - THE CARDS are the fifty-class roster, one card per class, sorted onto three tabs down
##    the bag's side -- creatures, objects, shapes -- and the card that is picked is shown
##    large beside them: the player's own drawing of it, what it can do (its ConceptNet
##    ability, config/abilities.json), the skills it answers to (its ability tags, the ones
##    this player has been taught) and what it costs.
##
## ⚠ THE ROSTER IS NOT A LIST OF ANSWERS. This game's hardest interface rule is that it never
## names a drawable class the player has not earned -- it is the whole reason `RequirementStrip`
## prints ability tags instead of classes, and `run_level1_audit` checks the live HUD against
## all fifty ids for exactly this. So a class the player has drawn is a card face up, and one
## they have not is a card face DOWN: no name, no tooltip, no ability, and it cannot be picked.
## Counting the face-down cards on a tab names nothing, and says how much of each kind is left.
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
const BagArt = preload("res://scripts/bag_art.gd")

const BAG_SLOT := Vector2(76.0, 76.0)
const FOUND_SLOT := Vector2(64.0, 64.0)
## ONE CARD IN THE ROSTER. A hundred and sixteen wide because "Boomerang", the longest single
## word in the roster, is 103 pixels at the twenty-pixel type floor; a hundred and fifty-six
## tall takes the drawing over two lines of name ("Hot Air / Balloon").
const ROSTER_SLOT := Vector2(116.0, 156.0)
## Nine across takes the twenty-seven objects in exactly three rows, and three rows of cards
## is what fits under the pockets on a 900-tall screen.
const ROSTER_COLUMNS := 9
const DETAIL_WIDTH := 304.0

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

## How a creature gets about, as the card prints it.
const MOVES := {
	"fly": "Flies",
	"climb": "Climbs walls",
	"swim": "Swims",
	"hop": "Hops",
	"walk": "Walks",
	"slither": "Slithers",
}

## The bag's own colours, shared with BagArt so the pockets are cut from the same leather.
const POCKET := Color(0.239, 0.169, 0.149)        # 3D2B26
const PARCHMENT := Color(0.925, 0.816, 0.671)     # ECD0AB
const PARCHMENT_LIT := Color(0.973, 0.894, 0.776) # F8E4C6
const PARCHMENT_INK := Color(0.227, 0.149, 0.094) # 3A2618
## The brass of a name plaque, and the gallery label's own edge and quiet text.
const BRASS := Color(0.835, 0.706, 0.443)         # D5B471
const LABEL_EDGE := Color(0.576, 0.443, 0.306)    # 93714E
const LABEL_MUTED := Color(0.455, 0.345, 0.235)   # 74583C
const LABEL_ACCENT := Color(0.604, 0.247, 0.133)  # 9A3F22  the ability, in a painter's red
## The plaque under a roster card's painting, two lines of name tall.
const PLAQUE_H := 48.0

static var _weave_texture: Texture2D

var inventory_manager: InventoryManager
var registry: EntityRegistry

var _bag_buttons: Array[Button] = []
var _bag_art: Array[TextureRect] = []
var _found_buttons: Array[Button] = []
var _roster_count: Label
## role -> the count label and the grid for that band. See _build_roster.
var _band_counts: Dictionary = {}
var _band_grids: Dictionary = {}
## role -> the band's whole box (heading and grid), and its tab down the side of the bag.
var _band_boxes: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _tab_role := "active_ragdoll_morph"

## The big card. `_detail_note` is what the thing IS. What it costs in ink is not shown: the
## gauge on the HUD says what is left, and the bag is for what you have.
var _detail_card: PanelContainer
var _detail_number: Label
var _detail_kind: Label
var _detail_title: Label
## The big painting's canvas, whose linen is tinted to the kind.
var _detail_art_frame: PanelContainer
var _detail_art: TextureRect
var _detail_blank: Label
var _ability_plate: VBoxContainer
var _ability_verb: Label
var _ability_text: Label
var _skills_box: VBoxContainer
var _skills_flow: HFlowContainer
var _moves_row: HBoxContainer
var _moves_value: Label
var _note_row: HBoxContainer
var _detail_note: Label
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
	_follow_choice_to_tab()
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
	panel.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	holder.add_child(panel)
	_panel = panel
	panel.minimum_size_changed.connect(func() -> void:
		panel.reset_size()
		holder.custom_minimum_size = panel.size)
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size * 0.5)

	# The bag, and its tabs hanging off the right-hand side the way paper tabs stick out of a
	# satchel. The tabs overlap the leather a little so they read as tucked in, not glued on.
	var frame := HBoxContainer.new()
	frame.name = "Frame"
	frame.add_theme_constant_override(&"separation", -10)
	panel.add_child(frame)

	var bag := PanelContainer.new()
	bag.name = "Bag"
	bag.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	frame.add_child(bag)
	bag.add_child(BagArt.new())

	var margins := MarginContainer.new()
	margins.name = "Lining"
	margins.add_theme_constant_override(&"margin_left", 30)
	margins.add_theme_constant_override(&"margin_right", 30)
	margins.add_theme_constant_override(&"margin_top", 14)
	margins.add_theme_constant_override(&"margin_bottom", int(BagArt.FEET_H) + 12)
	bag.add_child(margins)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override(&"separation", 0)
	margins.add_child(column)

	# The flap: the title between the two straps.
	var flap := VBoxContainer.new()
	flap.name = "Flap"
	flap.custom_minimum_size = Vector2(0.0, BagArt.FLAP_H - 14.0 + 8.0)
	flap.alignment = BoxContainer.ALIGNMENT_CENTER
	flap.add_theme_constant_override(&"separation", -4)
	column.add_child(flap)
	# The bag fills most of the screen, so "off the bag" has to include the bag's own leather:
	# a drawing dropped on the flap, or on the leather around the lining, is pulled out of it.
	panel.set_drag_forwarding(Callable(), _can_drop_outside, _drop_outside)
	flap.mouse_filter = Control.MOUSE_FILTER_STOP
	flap.set_drag_forwarding(Callable(), _can_drop_outside, _drop_outside)
	var title := Label.new()
	title.name = "Title"
	title.theme_type_variation = &"ScreenTitle"
	title.text = "YOUR BAG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override(&"font_color", PARCHMENT_LIT)
	title.add_theme_constant_override(&"outline_size", 8)
	title.add_theme_color_override(&"font_outline_color", BagArt.OUTLINE)
	flap.add_child(title)
	var blurb := Label.new()
	blurb.name = "Blurb"
	blurb.theme_type_variation = &"HudCaption"
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.add_theme_color_override(&"font_color", PARCHMENT)
	blurb.add_theme_constant_override(&"outline_size", 5)
	blurb.add_theme_color_override(&"font_outline_color", BagArt.OUTLINE)
	blurb.text = "what you are carrying, and every drawing you have made your own"
	flap.add_child(blurb)

	# The lining.
	var lining := MarginContainer.new()
	lining.name = "Inside"
	lining.add_theme_constant_override(&"margin_left", 4)
	lining.add_theme_constant_override(&"margin_right", 4)
	lining.add_theme_constant_override(&"margin_top", 14)
	lining.add_theme_constant_override(&"margin_bottom", 10)
	column.add_child(lining)

	var body := HBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override(&"separation", 16)
	lining.add_child(body)

	var left := VBoxContainer.new()
	left.name = "Left"
	left.add_theme_constant_override(&"separation", 10)
	body.add_child(left)

	var carried := HBoxContainer.new()
	carried.name = "Carried"
	carried.add_theme_constant_override(&"separation", 22)
	left.add_child(carried)
	_build_bag(carried)
	_build_found(carried)
	_build_roster(left)
	_build_detail(body)

	# The footer, stitched into the bottom band.
	var footer := Label.new()
	footer.name = "Footer"
	footer.theme_type_variation = &"HudCaption"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.custom_minimum_size = Vector2(0.0, BagArt.BOTTOM_H - 12.0)
	footer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_theme_color_override(&"font_color", PARCHMENT_LIT)
	footer.add_theme_constant_override(&"outline_size", 5)
	footer.add_theme_color_override(&"font_outline_color", BagArt.OUTLINE)
	footer.text = "%s to close  ·  scroll to look through  ·  drag a drawing to another pocket, or out of the bag to use it" \
		% ControlsKeys.keys_for("inventory_open")
	column.add_child(footer)

	_build_tabs(frame)
	_show_tab(_tab_role)


func _heading(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"HudCaption"
	label.add_theme_color_override(&"font_color", PARCHMENT)
	label.text = text
	parent.add_child(label)
	return label


## A titled group in the lining: its heading, a quiet note beside it, and the box the caller
## fills.
func _section(parent: Control, text: String, note: Label = null) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = "%sSection" % text.capitalize()
	column.add_theme_constant_override(&"separation", 6)
	parent.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	column.add_child(row)
	_heading(row, text)
	if note != null:
		row.add_child(note)
	return column


func _note(text: String) -> Label:
	var note := Label.new()
	note.theme_type_variation = &"HudCaption"
	note.add_theme_color_override(&"font_color", UISkin.MUTED)
	note.text = text
	return note


func _build_bag(parent: Control) -> void:
	var column := _section(parent, "POCKETS", _note("keys 1 - 6"))
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
		art.offset_top = 12.0
		art.offset_right = -10.0
		art.offset_bottom = -8.0
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
		number.add_theme_color_override(&"font_color", PARCHMENT)
		number.add_theme_constant_override(&"outline_size", 5)
		number.add_theme_color_override(&"font_outline_color", BagArt.OUTLINE)
		number.position = Vector2(7.0, 0.0)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(number)


func _build_found(parent: Control) -> void:
	var column := _section(parent, "FOUND", _note("kept for the run"))
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


## One box per kind: its heading and count, and a grid of a card per class. Only the box
## for the open tab is shown; the others keep their cards so switching is instant.
func _build_roster(parent: Control) -> void:
	_roster_count = _note("")
	var section := _section(parent, "YOUR DRAWINGS", _roster_count)
	section.add_theme_constant_override(&"separation", 8)
	for band: Variant in BANDS:
		var spec: Dictionary = band
		var role := String(spec["role"])
		var box := VBoxContainer.new()
		box.name = "%sBand" % role
		box.add_theme_constant_override(&"separation", 6)
		section.add_child(box)
		_band_boxes[role] = box

		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		box.add_child(row)
		var name_label := Label.new()
		name_label.text = String(spec["title"])
		name_label.theme_type_variation = &"HudCaption"
		name_label.add_theme_color_override(&"font_color", _palette(role)["accent"])
		row.add_child(name_label)
		var count := Label.new()
		count.name = "%sCount" % role
		count.theme_type_variation = &"HudCaption"
		count.add_theme_color_override(&"font_color", UISkin.MUTED)
		row.add_child(count)
		_band_counts[role] = count

		var grid := GridContainer.new()
		grid.name = "%sGrid" % role
		grid.columns = ROSTER_COLUMNS
		grid.add_theme_constant_override(&"h_separation", 6)
		grid.add_theme_constant_override(&"v_separation", 6)
		# Always three rows tall, so the bag does not change size from tab to tab.
		grid.custom_minimum_size = Vector2(
			ROSTER_COLUMNS * ROSTER_SLOT.x + (ROSTER_COLUMNS - 1) * 6.0,
			3.0 * ROSTER_SLOT.y + 2.0 * 6.0)
		box.add_child(grid)
		_band_grids[role] = grid


## The paper tabs down the right-hand side of the bag, one per kind.
func _build_tabs(parent: Control) -> void:
	var column := VBoxContainer.new()
	column.name = "Tabs"
	column.add_theme_constant_override(&"separation", 10)
	parent.add_child(column)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, BagArt.FLAP_H + 36.0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	for band: Variant in BANDS:
		var role := String((band as Dictionary)["role"])
		var tab := Button.new()
		tab.name = "%sTab" % role
		tab.focus_mode = Control.FOCUS_NONE
		tab.custom_minimum_size = Vector2(132.0, 70.0)
		tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
		for state in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
			tab.add_theme_color_override(state, PARCHMENT_INK)
		tab.set_meta(&"ui_feedback", true)
		tab.pressed.connect(_show_tab.bind(role))
		column.add_child(tab)
		_tab_buttons[role] = tab



## The card that is picked, shown as a painting: the drawing on canvas in a gilt frame, and a
## museum label under it saying what it is and what it can do.
func _build_detail(parent: Control) -> void:
	var card := PanelContainer.new()
	card.name = "Detail"
	card.custom_minimum_size = Vector2(DETAIL_WIDTH, 0.0)
	card.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	parent.add_child(card)
	_detail_card = card

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	card.add_child(column)

	# THE PAINTING. It is the player's own drawing and it is the one thing on this screen worth
	# looking at big, so it takes whatever height the label leaves.
	var frame := _gilt_frame(8.0)
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size = Vector2(0.0, 190.0)
	column.add_child(frame)
	var canvas := _canvas()
	(frame.get_child(0) as Control).add_child(canvas)
	_detail_art_frame = canvas
	var art_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		art_margin.add_theme_constant_override("margin_" + side, 16)
	art_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(art_margin)
	_detail_art = TextureRect.new()
	_detail_art.name = "Art"
	_detail_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art_margin.add_child(_detail_art)
	_detail_blank = Label.new()
	_detail_blank.theme_type_variation = &"HudCaption"
	_detail_blank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_blank.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_blank.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_blank.add_theme_color_override(&"font_color", Color(PARCHMENT_INK, 0.55))
	art_margin.add_child(_detail_blank)

	# THE LABEL beside a painting in a gallery: name and number, kind, then what it does.
	var label := PanelContainer.new()
	label.add_theme_stylebox_override(&"panel", _flat(PARCHMENT, LABEL_EDGE, 3, 3, 12.0))
	column.add_child(label)
	var text := VBoxContainer.new()
	text.add_theme_constant_override(&"separation", 4)
	label.add_child(text)

	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 8)
	text.add_child(head)
	_detail_title = Label.new()
	_detail_title.theme_type_variation = &"ScreenSubtitle"
	_detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_title.add_theme_color_override(&"font_color", PARCHMENT_INK)
	head.add_child(_detail_title)
	_detail_number = Label.new()
	_detail_number.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	_detail_number.add_theme_color_override(&"font_color", LABEL_MUTED)
	_detail_number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_detail_number)
	_detail_kind = Label.new()
	_detail_kind.theme_type_variation = &"HudCaption"
	_detail_kind.add_theme_color_override(&"font_color", LABEL_MUTED)
	text.add_child(_detail_kind)

	var rule := ColorRect.new()
	rule.color = LABEL_EDGE
	rule.custom_minimum_size = Vector2(0.0, 2.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(rule)

	# What it can do: the verb large, and the sentence it comes from.
	_ability_plate = VBoxContainer.new()
	_ability_plate.add_theme_constant_override(&"separation", -2)
	text.add_child(_ability_plate)
	_ability_verb = Label.new()
	_ability_verb.theme_type_variation = &"ScreenSubtitle"
	_ability_verb.add_theme_color_override(&"font_color", LABEL_ACCENT)
	_ability_plate.add_child(_ability_verb)
	_ability_text = Label.new()
	_ability_text.theme_type_variation = &"HudCaption"
	_ability_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ability_text.add_theme_color_override(&"font_color", PARCHMENT_INK)
	_ability_plate.add_child(_ability_text)

	# The skills: every ability tag this class answers to that the player has been taught.
	_skills_box = VBoxContainer.new()
	_skills_box.add_theme_constant_override(&"separation", 4)
	text.add_child(_skills_box)
	var skills_title := Label.new()
	skills_title.theme_type_variation = &"HudCaption"
	skills_title.add_theme_color_override(&"font_color", LABEL_MUTED)
	skills_title.text = "SKILLS"
	_skills_box.add_child(skills_title)
	_skills_flow = HFlowContainer.new()
	_skills_flow.add_theme_constant_override(&"h_separation", 6)
	_skills_flow.add_theme_constant_override(&"v_separation", 6)
	_skills_box.add_child(_skills_flow)

	var moves := _stat_row(text, "MOVES", UISkin.PICKUP)
	_moves_row = moves[0]
	_moves_value = moves[1]
	var note := _stat_row(text, "IS", UISkin.USE)
	_note_row = note[0]
	_detail_note = note[1]

	_use_button = Button.new()
	_use_button.theme_type_variation = &"PrimaryButton"
	_use_button.custom_minimum_size = Vector2(0.0, 48.0)
	_use_button.text = "TAKE IT OUT"
	_use_button.visible = false
	_use_button.pressed.connect(_use_chosen)
	column.add_child(_use_button)



## A row on the label: a coloured mark, a key, and the value beside it. Returns [row, value].
func _stat_row(parent: Control, key: String, mark: Color) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	parent.add_child(row)
	var dot := ColorRect.new()
	dot.color = mark.darkened(0.25)
	dot.custom_minimum_size = Vector2(10.0, 10.0)
	dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot_box := MarginContainer.new()
	dot_box.add_theme_constant_override(&"margin_top", 8)
	dot_box.add_child(dot)
	row.add_child(dot_box)
	var key_label := Label.new()
	key_label.theme_type_variation = &"HudCaption"
	key_label.add_theme_color_override(&"font_color", LABEL_MUTED)
	key_label.custom_minimum_size = Vector2(76.0, 0.0)
	key_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	key_label.text = key
	row.add_child(key_label)
	var value := Label.new()
	value.theme_type_variation = &"HudCaption"
	value.add_theme_color_override(&"font_color", PARCHMENT_INK)
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)
	return [row, value]


func _slot_button(box: Vector2) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"InventorySlot"
	button.custom_minimum_size = box
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	button.clip_contents = true
	# ⚠ OUT OF UIFeedback, which every other button in the game keeps. It gives each button a
	# dip on press, a pop back and a ring that leaves the click point -- right on a menu button,
	# and on this screen a ring going off inside a small frame and a grid of frames that
	# jumped at every click. Its hover also tweened the same `scale` this one does, and
	# whichever started last won. Marked before the button enters the tree, which is when
	# UIFeedback looks.
	button.set_meta(&"ui_feedback", true)
	button.resized.connect(func() -> void: button.pivot_offset = button.size * 0.5)
	button.mouse_entered.connect(_hover.bind(button, true))
	button.mouse_exited.connect(_hover.bind(button, false))
	return button


## A slot that holds something lifts under the mouse; an empty one does not, because there is
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
		Color(1.15, 1.12, 1.05, 1.0) if over else Color.WHITE, HOVER_TIME)


## The drawing on the big card comes up when something new is chosen, so the eye goes there.
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


# --- Styling -------------------------------------------------------------------------

static func _flat(fill: Color, edge: Color, border: int, radius: int, margin: float = 0.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(border)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = false
	if margin > 0.0:
		box.set_content_margin_all(margin)
	return box



## Each kind's colours: the tint of the canvas its drawing is on, and its accent. Green for
## creatures, warm for objects, violet for shapes -- a wash on the linen rather than a coloured
## card, so a tab of them reads as a wall of paintings and still sorts by kind at a glance.
static func _palette(role: String) -> Dictionary:
	match role:
		"active_ragdoll_morph":
			return {"canvas": Color(0.90, 0.96, 0.88), "accent": Color(0.498, 0.706, 0.435),
				"kind": "Creature"}
		"utility":
			return {"canvas": Color(1.0, 0.95, 0.86), "accent": Color(0.878, 0.541, 0.290),
				"kind": "Object"}
		"physics_morph":
			return {"canvas": Color(0.95, 0.92, 1.0), "accent": Color(0.690, 0.533, 0.839),
				"kind": "Shape"}
		_:
			return {"canvas": Color.WHITE, "accent": UISkin.GOLD, "kind": "Found"}


## Linen, woven: a tile of crossing threads with a little grain in it, made once. Tinted by
## the TextureRect's modulate, so one texture serves every kind.
static func _weave() -> Texture2D:
	if _weave_texture != null:
		return _weave_texture
	var size := 48
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1882
	var base := Color(0.945, 0.918, 0.851)
	for y in range(size):
		for x in range(size):
			var shade := rng.randf_range(-0.022, 0.022)
			# Threads: every other row and column a touch darker, and where they cross darker
			# still, which is what reads as weave rather than noise.
			if y % 3 == 0:
				shade -= 0.03
			if x % 3 == 0:
				shade -= 0.03
			image.set_pixel(x, y, Color(base.r + shade, base.g + shade, base.b + shade * 1.2))
	_weave_texture = ImageTexture.create_from_image(image)
	return _weave_texture


## A gilt frame: the bright moulding, a dark sight edge inside it, and a slot for what hangs
## in it. Returns the outer panel; its only child is where the canvas goes.
func _gilt_frame(radius: float = 4.0) -> PanelContainer:
	var outer := PanelContainer.new()
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_theme_stylebox_override(&"panel",
		_flat(UISkin.GILT, UISkin.GILT_EDGE, 3, int(radius), 7.0))
	var sight := PanelContainer.new()
	sight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sight.add_theme_stylebox_override(&"panel", _flat(UISkin.GILT_EDGE, UISkin.GILT_HI, 0, 2, 3.0))
	outer.add_child(sight)
	return outer


## Bare canvas: the woven linen filling a panel. Anything added to it sits on the linen.
func _canvas(tint: Color = Color.WHITE) -> PanelContainer:
	var canvas := PanelContainer.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	var linen := TextureRect.new()
	linen.name = "Linen"
	linen.texture = _weave()
	linen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	linen.stretch_mode = TextureRect.STRETCH_TILE
	linen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	linen.modulate = tint
	linen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(linen)
	return canvas



func _paint(button: Button, occupied: bool, chosen: bool, quiet: bool = false) -> void:
	var box: StyleBoxFlat
	if quiet:
		# A roster card is a little painting: a gilt frame round a drawing, or a dark wooden
		# one round bare canvas for a class nobody has drawn yet.
		if occupied:
			box = _flat(UISkin.GILT_HI if chosen else UISkin.GILT,
				UISkin.GILT_HI if chosen else UISkin.GILT_EDGE, 4 if chosen else 3, 4)
		else:
			box = _flat(UISkin.WOOD_DARK, UISkin.WOOD_EDGE, 3, 4)
	else:
		# A pocket sewn into the lining -- with a sheet of the canvas's paper in it once it
		# holds a drawing, or the dark ink vanishes into the leather.
		box = _flat(InventoryHUD.PAPER if occupied else POCKET,
			UISkin.GILT_HI if chosen else BagArt.LINING_EDGE, 4 if chosen else 3, 6)
	for state in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		button.add_theme_stylebox_override(state, box)
	button.modulate = Color(1.1, 1.1, 1.04) if chosen else Color.WHITE
	button.set_meta(&"live", occupied)


func _show_tab(role: String) -> void:
	_tab_role = role
	for key: String in _band_boxes:
		(_band_boxes[key] as Control).visible = key == role
	for key: String in _tab_buttons:
		var tab := _tab_buttons[key] as Button
		var is_open_tab := key == role
		var box := _flat(PARCHMENT_LIT if is_open_tab else PARCHMENT, BagArt.OUTLINE, 3, 0, 0.0)
		box.corner_radius_top_right = 10
		box.corner_radius_bottom_right = 10
		box.content_margin_left = 22.0 if is_open_tab else 16.0
		box.content_margin_right = 10.0
		box.border_width_left = 0
		var hover := box.duplicate() as StyleBoxFlat
		hover.bg_color = PARCHMENT_LIT
		for state in [&"normal", &"focus", &"disabled"]:
			tab.add_theme_stylebox_override(state, box)
		tab.add_theme_stylebox_override(&"hover", hover)
		tab.add_theme_stylebox_override(&"pressed", hover)
		# The open tab sticks further out of the bag.
		tab.custom_minimum_size.x = 142.0 if is_open_tab else 128.0


# --- Filling -------------------------------------------------------------------------

func refresh() -> void:
	_keep_bag_drawings()
	_refresh_bag()
	_refresh_found()
	_refresh_roster()
	_refresh_detail()


## A drawing in the pockets whose class has no picture kept yet -- one drawn before the bag
## kept pictures -- gives its picture to the card.
func _keep_bag_drawings() -> void:
	var profile := get_node_or_null(^"/root/PlayerProfile")
	if profile == null or not profile.has_method("record_class_drawing") \
			or inventory_manager == null:
		return
	for item_value: Variant in inventory_manager.items():
		var item := item_value as DrawnItemData
		if item == null or item.image == null or item.entity_id.is_empty():
			continue
		if not bool(profile.call("has_class_drawing", item.entity_id)):
			profile.call("record_class_drawing", item.entity_id, item.image)


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
		# An unfound thing is an empty pocket and nothing else -- no name, no tooltip. The
		# shape of what is still out there is worth showing; what it is called is not this
		# screen's to give away.
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
	# Rebuilt when what has been drawn changes OR a kept picture does: the cards were built
	# once when the bag first opened, before a class's drawing had been kept, and stayed
	# blank after it was.
	var version: int = int(profile.get("drawings_version")) if profile != null else 0
	var built_for := [drawn.duplicate(), version]
	if _roster_built_for is Array and (_roster_built_for as Array) == built_for:
		for id: String in _roster_buttons:
			var chosen := String(_chosen.get("kind", "")) == "drawn" \
				and String(_chosen.get("id", "")) == id and drawn.has(id)
			_paint(_roster_buttons[id] as Button, drawn.has(id), chosen, true)
		return
	_roster_built_for = built_for
	_roster_buttons.clear()
	for band: Variant in BANDS:
		_fill_band(String((band as Dictionary)["role"]), String((band as Dictionary)["title"]), drawn)


## One kind's cards, its count, and its tab.
##
## Rebuilt rather than diffed: it changes once per drawing. REMOVED, then freed --
## queue_free leaves the node in the tree until the end of the frame, so a rebuild would
## hand the GridContainer twice its children to lay out for one frame and it would visibly
## reflow.
func _fill_band(role: String, title: String, drawn: Array) -> void:
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
	var tab := _tab_buttons.get(role) as Button
	if tab != null:
		tab.text = "%s\n%d / %d" % [title, known, ids.size()]
	for id_value: Variant in ids:
		var id := String(id_value)
		var button := _slot_button(ROSTER_SLOT)
		button.set_meta(&"role", role)
		var owned := drawn.has(id)
		var chosen := String(_chosen.get("kind", "")) == "drawn" \
			and String(_chosen.get("id", "")) == id and owned
		grid.add_child(button)
		_roster_buttons[id] = button
		_paint(button, owned, chosen, true)
		if not owned:
			# Face down: unnamed, untooltipped, unclickable. What it says is "one more of this
			# kind is out there", and nothing else.
			button.add_child(_card_back())
			continue
		button.tooltip_text = _display_name(id)
		button.pressed.connect(_choose_drawn.bind(id))
		button.add_child(_card_face_art(id, role))
		# ⚠ THE NAME IS THE CARD'S ONLY DIRECT LABEL. run_book_probe reads every Label directly
		# under a card as a name on show, and an empty book must show none.
		var label := Label.new()
		label.text = _display_name(id)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.offset_left = 5.0
		label.offset_right = -5.0
		label.offset_top = ROSTER_SLOT.y - PLAQUE_H - 4.0
		label.offset_bottom = -6.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override(&"font_size",
			_fitting_size(label.text, ROSTER_SLOT.x - 12.0, UISkin.FONT_TINY))
		label.add_theme_constant_override(&"line_spacing", -6)
		label.add_theme_color_override(&"font_color", PARCHMENT_INK)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(label)



## The largest type size, from `largest` down, at which every WORD of `text` fits `width`.
## Words wrap onto a second line, but a single word wider than the plaque is broken in the
## middle ("Boomeran / g"), so the longest word sets the size.
func _fitting_size(text: String, width: float, largest: int) -> int:
	var theme := load("res://ui/obra_theme.tres") as Theme
	var font: Font = theme.default_font if theme != null else null
	if font == null:
		return largest
	var size := largest
	while size > 14:
		var fits := true
		for word in text.split(" ", false):
			if font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
				fits = false
				break
		if fits:
			break
		size -= 1
	return size


## The painting on a face-up card: the player's drawing on its kind's canvas, set into the
## card's gilt, with a brass plaque under it for the name.
func _card_face_art(id: String, role: String) -> Control:
	var face := Control.new()
	face.name = "Face"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sight := PanelContainer.new()
	sight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sight.offset_left = 7.0
	sight.offset_top = 7.0
	sight.offset_right = -7.0
	sight.offset_bottom = -PLAQUE_H - 8.0
	sight.add_theme_stylebox_override(&"panel", _flat(UISkin.GILT_EDGE, UISkin.GILT_EDGE, 0, 2, 2.0))
	face.add_child(sight)
	var canvas := _canvas(_palette(role)["canvas"])
	sight.add_child(canvas)
	var texture := _class_drawing(id)
	if texture != null:
		var margin := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 6)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(margin)
		var art := TextureRect.new()
		art.texture = texture
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(art)
	var plaque := Panel.new()
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plaque.offset_left = 5.0
	plaque.offset_right = -5.0
	plaque.offset_top = ROSTER_SLOT.y - PLAQUE_H - 4.0
	plaque.offset_bottom = -6.0
	plaque.add_theme_stylebox_override(&"panel", _flat(BRASS, UISkin.GILT_EDGE, 2, 2))
	face.add_child(plaque)
	return face



## A frame nobody has painted in yet: bare, shadowed canvas and a question mark.
func _card_back() -> Control:
	var back := PanelContainer.new()
	back.name = "Back"
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.offset_left = 7.0
	back.offset_top = 7.0
	back.offset_right = -7.0
	back.offset_bottom = -7.0
	back.add_theme_stylebox_override(&"panel", _flat(UISkin.WOOD_EDGE, UISkin.WOOD_EDGE, 0, 2, 2.0))
	var canvas := _canvas(Color(0.42, 0.37, 0.32))
	back.add_child(canvas)
	var mark := Label.new()
	mark.text = "?"
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override(&"font_size", UISkin.FONT_TITLE)
	mark.add_theme_color_override(&"font_color", Color(0.22, 0.17, 0.13, 0.8))
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(mark)
	return back


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
	if kind.is_empty():
		_style_detail(_palette(""))
		_detail_number.text = ""
		_detail_title.text = "Nothing chosen"
		_detail_kind.text = ""
		_set_art(null, "Pick a painting, or anything in your pockets, to see it here.")
		_set_ability("", "")
		_set_skills([])
		_set_rows("", "")
		return
	if kind == "bag":
		var item := inventory_manager.peek_item(int(_chosen.get("index", -1))) \
			if inventory_manager != null else null
		if item == null:
			_chosen = {}
			_refresh_detail()
			return
		_fill_class_card(item.entity_id, _thumbnail(item))
		_detail_title.text = item.display_name
		return
	if kind == "found":
		var id := String(_chosen.get("id", ""))
		for entry in FOUND:
			if String(entry["id"]) != id:
				continue
			_style_detail(_palette(""))
			_detail_number.text = ""
			_detail_title.text = String(entry["name"])
			_detail_kind.text = "Found  ·  kept for the whole run"
			_set_art(_found_art(id), "")
			var note := String(entry["note"])
			var profile := get_node_or_null(^"/root/PlayerProfile")
			if profile != null and bool(profile.call("is_canvas_damaged", id)):
				note += "  It is creased along the break."
			_set_ability("", note)
			_set_skills([])
			_set_rows("", "")
			return
		return
	var class_id := String(_chosen.get("id", ""))
	_fill_class_card(class_id, _class_drawing(class_id))



## The big card for one class: everything the manifest and the ability table say about it,
## and the player's own picture of it.
func _fill_class_card(class_id: String, art: Texture2D) -> void:
	var entry: Dictionary = registry.get_entity(class_id) if registry != null else {}
	var role := String(entry.get("runtime_role", ""))
	var palette := _palette(role)
	_style_detail(palette)
	_detail_number.text = "No. %02d" % _roster_number(class_id)
	_detail_title.text = _display_name(class_id)
	_detail_kind.text = String(palette["kind"])
	_set_art(art, "Draw it again to keep a picture of it here.")
	_set_ability(String(entry.get("ability", "")), _assertion(entry))
	_set_skills(_skills_of(class_id))
	var moves := ""
	if role == "active_ragdoll_morph":
		moves = String(MOVES.get(String(entry.get("movement_type", "")), "Walks"))
		if String(entry.get("required_medium", "any")) == "water":
			moves += ", only in water"
	elif String(entry.get("required_medium", "any")) == "water":
		moves = "Only on water"
	_set_rows(moves, _role_of(class_id))



func _style_detail(palette: Dictionary) -> void:
	var linen := _detail_art_frame.get_node_or_null(^"Linen") as TextureRect
	if linen != null:
		linen.modulate = palette["canvas"]



func _set_art(texture: Texture2D, blank: String) -> void:
	_detail_art.texture = texture
	_detail_blank.text = blank if texture == null else ""
	_detail_blank.visible = texture == null


func _set_ability(verb: String, sentence: String) -> void:
	_ability_verb.text = verb.to_upper()
	_ability_verb.visible = not verb.is_empty()
	_ability_text.text = sentence
	_ability_plate.visible = not (verb.is_empty() and sentence.is_empty())



## [[name, gloss], ...] as little brass tags on the label.
func _set_skills(skills: Array) -> void:
	for child in _skills_flow.get_children():
		_skills_flow.remove_child(child)
		child.queue_free()
	_skills_box.visible = not skills.is_empty()
	for skill_value: Variant in skills:
		var skill: Array = skill_value
		var chip := PanelContainer.new()
		var box := _flat(BRASS, UISkin.GILT_EDGE, 2, 3, 0.0)
		box.content_margin_left = 8.0
		box.content_margin_right = 8.0
		chip.add_theme_stylebox_override(&"panel", box)
		chip.tooltip_text = String(skill[1])
		_skills_flow.add_child(chip)
		var label := Label.new()
		label.text = String(skill[0]).to_upper()
		label.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
		label.add_theme_color_override(&"font_color", PARCHMENT_INK)
		chip.add_child(label)



func _set_rows(moves: String, note: String) -> void:
	_moves_value.text = moves
	_moves_row.visible = not moves.is_empty()
	_detail_note.text = note
	_note_row.visible = not note.is_empty()


# --- Choosing ------------------------------------------------------------------------

func _choose_bag(index: int) -> void:
	_chosen = {"kind": "bag", "index": index}
	_follow_choice_to_tab()
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
	_follow_choice_to_tab()
	refresh()
	_show_choice()


## What is chosen -- a card, or a drawing in a pocket -- may be of a kind whose tab is not
## open; open it, so its card is in view beside the big one.
func _follow_choice_to_tab() -> void:
	var kind := String(_chosen.get("kind", ""))
	var id := ""
	if kind == "drawn":
		id = String(_chosen.get("id", ""))
	elif kind == "bag" and inventory_manager != null:
		var item := inventory_manager.peek_item(int(_chosen.get("index", -1)))
		id = item.entity_id if item != null else ""
	if id.is_empty() or registry == null:
		return
	var role := String(registry.get_entity(id).get("runtime_role", ""))
	if _band_boxes.has(role) and role != _tab_role:
		_show_tab(role)


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


## Where the class sits in the fifty, counted from one -- the number in a card's corner.
func _roster_number(entity_id: String) -> int:
	var ids: Array = registry.get_entity_ids() if registry != null else []
	return ids.find(entity_id) + 1


func _class_drawing(entity_id: String) -> Texture2D:
	var profile := get_node_or_null(^"/root/PlayerProfile")
	if profile == null or not profile.has_method("class_drawing"):
		return null
	return profile.call("class_drawing", entity_id) as Texture2D


## The ability table's sentence, as a player would read it. The three shapes carry a note
## for the thesis ("Hand-authored: ... (geometric primitive; no ConceptNet relation)") that
## is provenance, not description, and is cut off here.
func _assertion(entry: Dictionary) -> String:
	var text := String(entry.get("ability_assertion", "")).strip_edges()
	if text.begins_with("Hand-authored:"):
		text = text.trim_prefix("Hand-authored:").strip_edges()
	var aside := text.find(" (")
	if aside >= 0:
		text = text.substr(0, aside).strip_edges()
		if not text.ends_with("."):
			text += "."
	if not text.is_empty():
		text = text[0].to_upper() + text.substr(1)
	return text


## The ability tags this class answers to that the player has been taught, as [name, gloss].
## Untaught ones are left off: a tag is what an obstacle asks for, and a card that listed the
## asks of levels not reached yet would be a map of them.
func _skills_of(class_id: String) -> Array:
	var tags := get_node_or_null(^"/root/AbilityTags")
	if tags == null:
		return []
	var out: Array = []
	for tag_value: Variant in tags.call("tags_for_class", class_id):
		var tag := String(tag_value)
		if bool(tags.call("is_unlocked", tag)):
			out.append([String(tags.call("display_name", tag)), String(tags.call("gloss", tag))])
	return out


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
