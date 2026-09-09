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
const GOLD := UISkin.GOLD
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

## HOW FAR IT DROPS OUT OF THE FRAME WHEN IT IS NOT WANTED, and the whole reason it does.
##
## The band is anchored bottom-CENTRE, and bottom-centre is where the camera keeps the
## player -- so a bag with anything in it sat squarely on top of the apo. Photographed with
## six drawings in it, the slots covered her from the shins to the eyes: you could see the
## top of her head over slot 3 and nothing else. `_refresh` already hides the bar when the
## bag is EMPTY, and the note on it is about this same band burying the paddy at the level's
## first gate. This is that rule finished: the bag is not only quiet when it holds nothing,
## it is quiet while you are moving.
const STOW_DROP := 78.0
const STOW_TIME := 0.16
const RAISE_TIME := 0.13
## How long it stays up after something changes, however hard the player is running. Picking
## a thing up and having it flash past is worse than not showing it -- the card that says
## what you got is on screen for about this long.
const DWELL := 3.2

var _stowed := false
## Set while a placement is in progress -- see set_click_through. Kept apart from `_stowed`
## because either one alone must make the band click-through and neither may clear the other.
var _click_through := false
var _dwell := 0.0
var _slide: Tween
## Where the band sits when it is up. Read once, because the tween writes to these.
var _home_top := 0.0
var _home_bottom := 0.0


func _ready() -> void:
	add_theme_constant_override(&"separation", 8)
	_home_top = offset_top
	_home_bottom = offset_bottom
	set_process(true)
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
		number.add_theme_color_override(&"font_color", GOLD)
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
	_click_through = click_through
	_apply_filter()


## ⚠ A STOWED BAR IS STILL A CLICK TARGET UNLESS IT IS TOLD NOT TO BE. Stowing drops the
## band 78px and fades it to nothing, and a Control at `modulate:a = 0` is invisible and
## fully hittable -- so the bag would have gone on eating clicks from a place the player
## cannot see it, which is a worse version of the bug `set_click_through` was written for.
func _apply_filter() -> void:
	var filter := Control.MOUSE_FILTER_IGNORE \
		if (_click_through or _stowed) else Control.MOUSE_FILTER_STOP
	mouse_filter = filter
	for button in _buttons:
		button.mouse_filter = filter


func _refresh(items: Array) -> void:
	# AN EMPTY BAG DRAWS NOTHING. Six boxes with nothing in them say nothing, and this band
	# is anchored across the bottom-centre of the screen -- which at Level 1's spawn is
	# exactly where the paddy is. It hid most of the water's depth behind a row of empty
	# frames, so the first gate in the game read as a puddle you could walk through, and
	# the player walked into it. All six come back the moment anything is held, so the slot
	# numbers never move.
	var holding := false
	for item_value: Variant in items:
		if item_value != null:
			holding = true
			break
	visible = holding
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
		_numbers[index].add_theme_color_override(&"font_color", GOLD if occupied else DIM)
		_tags[index].visible = chosen
	_forget_stale_thumbnails(items)


func _thumbnail(item: DrawnItemData) -> Texture2D:
	if item == null or item.image == null:
		return null
	var key := item.instance_id
	var cached: Texture2D = _thumbnails.get(key)
	if cached != null:
		return cached
	# THE PAPER COMES OFF. `item.image` is the raw grab off the drawing panel's SubViewport,
	# white `Paper` ColorRect and all, so a slot holding the player's own drawing was an
	# opaque white square with something small in the middle of it -- six of them in a row
	# across the bottom of the level. Knocked out and cropped to the ink, the slot holds the
	# DRAWING. Falls back to the raw grab for an image with no ink found in it.
	var texture := DrawingSkin2D.thumbnail(item.image)
	if texture == null:
		texture = ImageTexture.create_from_image(item.image)
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


## Out of the way, or back. Driven by the level: the bag stands down while the apo is
## travelling and comes up when she stops, so the one band that sits where she does is
## never between the player and what they are walking into.
##
## ⚠ THE DWELL OUTRANKS THE MOVEMENT. A drawing picked up mid-run would otherwise arrive in
## a bar that is already on its way out of the frame, which is the one moment the bag has
## something to say.
func set_stowed(stow: bool) -> void:
	if stow and _dwell > 0.0:
		return
	if stow == _stowed:
		return
	_stowed = stow
	_apply_filter()
	_slide_to(stow)


## Something happened worth looking at. Brings the bar up and holds it there for DWELL,
## whatever the player is doing.
func announce() -> void:
	_dwell = DWELL
	if _stowed:
		_stowed = false
		_apply_filter()
		_slide_to(false)


func is_stowed() -> bool:
	return _stowed


func _process(delta: float) -> void:
	if _dwell > 0.0:
		_dwell = maxf(0.0, _dwell - delta)


## ⚠ THE OFFSETS, NOT `position`. This is an anchored Control inside a CanvasLayer, so its
## rect is recomputed from the anchors on every layout pass and a written `position` is gone
## by the next frame -- which is the same class of mistake the old "lift the chosen button
## six pixels" cue made, and it is recorded two functions down.
func _slide_to(stow: bool) -> void:
	if _slide != null and _slide.is_valid():
		_slide.kill()
	var drop := STOW_DROP if stow else 0.0
	_slide = create_tween()
	# The tree is stopped for every overlay in the game and the bag has to finish moving
	# anyway -- a bar frozen half out of the frame behind a dialogue box is worse than
	# either end of the animation.
	_slide.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_slide.set_parallel(true)
	_slide.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var seconds := STOW_TIME if stow else RAISE_TIME
	_slide.tween_property(self, "offset_top", _home_top + drop, seconds)
	_slide.tween_property(self, "offset_bottom", _home_bottom + drop, seconds)
	_slide.tween_property(self, "modulate:a", 0.0 if stow else 1.0, seconds)
