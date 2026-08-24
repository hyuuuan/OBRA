class_name InventoryHUD
extends HBoxContainer
## The bag, showing what is in it.
##
## It used to be six identical boxes reading "1	 Empty" ... "6	Empty", 756 pixels of the
## bottom of the screen spent on the word Empty six times. Emptiness is the default state
## of this bar and it was the loudest thing on it.
##
## Now a slot holds THE PLAYER'S OWN DRAWING. Every item carries the image it was
## recognised from, so the bag is a row of the things you actually drew rather than a list
## of their names -- which is the whole premise of the game, and it was already in memory
## going unused. An empty slot recedes to its number and stops asking for attention.

signal slot_pressed(slot: int)

const SLOT := Vector2(64.0, 64.0)
const LIME := UISkin.LIME
const DIM := UISkin.MUTED

var _manager: InventoryManager
var _buttons: Array[Button] = []
var _art: Array[TextureRect] = []
var _numbers: Array[Label] = []
## The word SEL under the number of the slot in hand. A brighter frame says "this one"
## only if you already know what the frames mean; a word says it outright.
var _tags: Array[Label] = []
## One texture per drawing, keyed by the item that owns it. Rebuilding a 512x512 image
## into a texture on every inventory change, six at a time, is work for nothing.
var _thumbnails: Dictionary = {}
## Which slot the player is currently acting on, or -1.
var _selected: int = -1


func _ready() -> void:
	add_theme_constant_override(&"separation", 8)
	# Centred in its band, which is anchored bottom-CENTRE and sized to exactly its six
	# slots -- 424px rather than the 756px it used to span, so it covers a third less of
	# the ground the player sets objects down on while staying where the eye looks for it.
	alignment = BoxContainer.ALIGNMENT_CENTER
	for index in range(6):
		var button := Button.new()
		button.theme_type_variation = &"InventorySlot"
		button.custom_minimum_size = SLOT
		button.focus_mode = Control.FOCUS_NONE
		button.text = ""
		button.tooltip_text = "Empty"
		button.pressed.connect(_on_slot_pressed.bind(index))
		add_child(button)
		_buttons.append(button)

		var art := TextureRect.new()
		art.name = "Drawing"
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.offset_left = 8.0
		art.offset_top = 8.0
		art.offset_right = -8.0
		art.offset_bottom = -8.0
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(art)
		_art.append(art)

		# The number stays whatever the slot holds: it is the key that reaches it.
		var number := Label.new()
		number.name = "Number"
		number.text = str(index + 1)
		number.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
		number.add_theme_color_override(&"font_color", LIME)
		# Outlined, because it sits on a dark slot when the slot is empty and on the white
		# paper of a drawing when it is not.
		number.add_theme_constant_override(&"outline_size", 5)
		number.add_theme_color_override(&"font_outline_color", Color(0.04, 0.06, 0.04, 1.0))
		number.position = Vector2(6.0, 1.0)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(number)
		_numbers.append(number)

		var tag := Label.new()
		tag.name = "Tag"
		tag.text = "SEL"
		tag.visible = false
		tag.add_theme_font_size_override(&"font_size", UISkin.FONT_TINY)
		tag.add_theme_color_override(&"font_color", UISkin.PENDING)
		tag.add_theme_constant_override(&"outline_size", 5)
		tag.add_theme_color_override(&"font_outline_color", UISkin.INK)
		tag.position = Vector2(6.0, SLOT.y - 20.0)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(tag)
		_tags.append(tag)


func set_manager(manager: InventoryManager) -> void:
	_manager = manager
	if not manager.inventory_changed.is_connected(_refresh):
		manager.inventory_changed.connect(_refresh)
	_refresh(manager.items())


## Mark a slot as the one in hand. -1 clears it.
func set_selected(slot: int) -> void:
	_selected = slot
	if _manager != null:
		_refresh(_manager.items())


func selected_slot() -> int:
	return _selected


## Stand out of the way of the mouse while something is being placed.
##
## The bar sits across the bottom-centre of the screen, and a placement is confirmed from
## PlacementController._unhandled_input -- which never runs for a click the GUI has already
## consumed. Setting a drawn step down near the ground means clicking low, so the click
## landed on a slot button, which does nothing during a placement, and vanished with
## nothing on screen to say why.
##
## Every button is set individually. A Control is hit-tested on its own filter, not its
## parent's, so making the container ignore the mouse would leave six live buttons sitting
## in the hole.
func set_click_through(click_through: bool) -> void:
	var filter := Control.MOUSE_FILTER_IGNORE if click_through else Control.MOUSE_FILTER_STOP
	mouse_filter = filter
	for button in _buttons:
		button.mouse_filter = filter


func _refresh(items: Array) -> void:
	for index in range(_buttons.size()):
		var item := items[index] as DrawnItemData if index < items.size() else null
		var occupied := item != null
		var chosen := index == _selected and occupied
		var button := _buttons[index]
		button.tooltip_text = "Place %s" % item.display_name if occupied else "Empty"
		_art[index].texture = _thumbnail(item) if occupied else null
		# Three states, three cues, because two of them have to be told apart at a glance
		# while something is being placed: empty recedes to the panel, holding takes the
		# lime ring, in-hand takes the warm ring AND says SEL. The old version lifted the
		# button six pixels, which an HBoxContainer undoes on its next layout pass -- so
		# the only cue that ever survived was a modulate.
		#
		# The frame is applied to every state, not only the chosen one. The theme leaves
		# InventorySlot unstyled precisely so this can own it; removing the override left
		# a slot with no frame at all.
		for state in [&"normal", &"hover", &"pressed", &"disabled"]:
			button.add_theme_stylebox_override(state, UISkin.slot(occupied, chosen))
		button.modulate = Color(1.12, 1.12, 1.04) if chosen else Color.WHITE
		_numbers[index].add_theme_color_override(&"font_color", LIME if occupied else DIM)
		_tags[index].visible = chosen
	_forget_stale_thumbnails(items)


func _thumbnail(item: DrawnItemData) -> Texture2D:
	if item == null or item.image == null:
		return null
	var key := item.instance_id
	var cached: Texture2D = _thumbnails.get(key)
	if cached != null:
		return cached
	var texture := ImageTexture.create_from_image(item.image)
	_thumbnails[key] = texture
	return texture


func _forget_stale_thumbnails(items: Array) -> void:
	var live: Dictionary = {}
	for value: Variant in items:
		var item := value as DrawnItemData
		if item != null:
			live[item.instance_id] = true
	for key: Variant in _thumbnails.keys():
		if not live.has(key):
			_thumbnails.erase(key)



func _on_slot_pressed(slot: int) -> void:
	slot_pressed.emit(slot)
