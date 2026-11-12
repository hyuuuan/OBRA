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
## ⚠ DRAGGED OUT INTO THE WORLD. Kent: "make the inventory draggable so that the users wont have
## to draw the exact same thing". A drawing in the bar came out with its key or a click, and a
## player who dragged it to where it should go got nothing -- the press never landed as a click --
## and drew it again. Pulled off its slot now, a drawing comes out the way its key takes it out:
## a thing to set down puts its ghost on the pointer and is set down where it is let go; a tool
## goes into her hand. Let go back over the bar, it goes back. The level answers what each drawing
## does (drag_begins), so a drag keeps every rule its key keeps: what it costs, and whether it may
## come out at all.
signal slot_dropped(slot: int, on_bar: bool)
## Let go somewhere that would not take it -- a spot the ghost will not stand on, another panel --
## or the drag was called off.
signal slot_drag_failed(slot: int)

const SLOT := Vector2(64.0, 64.0)
const GOLD := UISkin.GOLD
const DIM := UISkin.MUTED
## The drawing canvas's own paper, so a drawing in a slot looks the way it did on the page.
const PAPER := Color(0.965, 0.95, 0.9, 1.0)
## How far the count sits in from a slot's top-right corner. Top, because the bottom-left
## carries SEL; right, because the top-left carries the key number.
const COUNT_INSET := 3.0

var _manager: InventoryManager
var _buttons: Array[Button] = []
var _art: Array[TextureRect] = []
var _numbers: Array[Label] = []
## The word SEL under the number of the slot in hand. A brighter frame says "this one"
## only if you already know what the frames mean; a word says it outright.
var _tags: Array[Label] = []
## How many drawings each slot holds, from two up. See count_badge.
var _counts: Array[Label] = []
## One texture per drawing, keyed by the item that owns it. Rebuilding a 512x512 image
## into a texture on every inventory change, six at a time, is work for nothing.
var _thumbnails: Dictionary = {}
## Which slot the player is currently acting on, or -1.
var _selected: int = -1

## The level's answer to a drawing pulled off `slot`: "place" when its ghost now follows the
## pointer, "hold" for a tool that goes into her hand where it is let go, "" when it cannot come
## out (the level has said why).
var drag_begins: Callable
## Whether letting go of `slot`'s drawing out in the world would do something -- the ghost's own
## tint, or anywhere for a tool. It is what the pointer shows: a hand that can drop, or a no.
var drop_allowed: Callable
## The mouse events a drag catches on their way to the world -- the wheel that turns the ghost,
## the right button that puts it back -- handed to whatever places it. True when it used one.
var pointer_during_drag: Callable
## What the drag carries, so nothing else's drop takes it for its own.
const HUD_DRAG := "hud_slot"
const DRAG_HINT := "Let go to set it down  ·  back on the bag to keep it"
const HOLD_HINT := "Let go to take it in hand  ·  back on the bag to keep it"
## The slot a drawing is being dragged out of, or -1.
var _dragging := -1
## Whether the pointer is back over the bar, where letting go puts it back.
var _over_bar := false
## ⚠ THE WORLD IS NOT A CONTROL, SO SOMETHING HAS TO CATCH THE DROP. Let go over nothing, Godot
## ends a drag as refused and shows a forbidden pointer the whole way there -- over the very
## ground the drawing is meant to go on. So behind the HUD lies one full-screen Control that
## ignores the mouse except while a drawing is being dragged off the bar; then it takes the drop,
## and says yes or no by the ghost (drop_allowed).
var _catcher: Control

## ⚠ IT DOES NOT HIDE WHILE THE PLAYER WALKS ANY MORE.
##
## It used to drop out of the frame every time the apo moved and come back every time she
## stopped, because the band was anchored bottom-CENTRE, which is where the camera keeps the
## player, and a bag with things in it covered her from the shins up. Hiding it was a fix for
## where it was standing, and it cost the one thing a bag bar is for: you could not glance at
## what you were carrying while doing anything. Kent: "when it disappears and reappears,
## although it is nice, it is still weird".
##
## So it stands where it cannot cover her -- docked in the bottom-LEFT corner, on a tray of its
## own, in both levels (Piyesta's scene is a text copy and still had the old centre anchor)
## -- and it stays there. `set_stowed` is kept for anything that still wants to put it away,
## and nothing in a level calls it.
const STOW_DROP := 78.0
const STOW_TIME := 0.16
const RAISE_TIME := 0.13
## How long it stays up after something changes, however hard the player is running. Picking
## a thing up and having it flash past is worse than not showing it -- the card that says
## what you got is on screen for about this long.
const DWELL := 3.2

var _stowed := false
## Shown though empty, while a lesson about the bag is up: Payyo teaches the bag before there is
## anything in it, and a lesson lighting a hidden bar lit nothing. See `show_empty`.
var _shown_empty := false
## Whether the player is standing behind the bar right now. See set_see_through.
var _see_through := false
## How much of the HUD the level's letterbox has left showing. See set_curtain_alpha.
var _curtain_alpha := 1.0
## ⚠ ONE WRITER FOR THE ALPHA. The bar's alpha used to be tweened from three places -- its own
## fade-in, the see-through fade, and the level's curtain -- and whichever finished last won.
## In play that left it faded with the player nowhere near it, or solid with her standing
## behind it. Now each of those only sets a target, and `_process` walks the alpha toward the
## product of them.
const ALPHA_SPEED := 6.5
## How much of the bar is left when she is behind it: enough to read the numbers and see what
## is in the slots, little enough that she shows through.
const SEE_THROUGH := 0.3
## Set while a placement is in progress -- see set_click_through. Kept apart from `_stowed`
## because either one alone must make the band click-through and neither may clear the other.
var _click_through := false
var _dwell := 0.0
var _slide: Tween
## Where the band sits when it is up. Read once, because the tween writes to these.
var _home_top := 0.0
var _home_bottom := 0.0

## HOW A DRAWING GETS INTO THE BAG: IT FLIES THERE.
##
## A new drawing used to come up on AcquiredOverlay -- the world dimmed to a fifth and the
## drawing held large in the middle of the screen for three and a half seconds -- and while
## it was up, every mouse press only took the card away, so the scroll that turns a placement
## and the click that sets it down did nothing. Kent: "i dont like how the animation is
## happening in like whats happening in the inventory, i cant scroll, drag, etc. from it".
## It was the wrong picture besides: it said "in your bag" from the middle of the screen,
## nowhere near the bag.
##
## Now the drawing leaves from where the canvas was and lands in its own slot, the slot lights
## as it lands, and a line over the bag says what the slot's key does with it. Nothing dims,
## nothing waits for a key, and nothing on the way takes the mouse. The card is kept for what
## the game HANDS the player -- a key, a painting, a flower -- which is what it was made for.
## How big the drawing is as it leaves the canvas, and how long it takes to reach the bag.
const ARRIVE_SIZE := 200.0
const ARRIVE_TIME := 0.45
## How far over the straight line the drawing is tossed, so it drops INTO the bag.
const ARRIVE_ARC := 120.0
## How long the line over the bag stays, and how long it takes to go.
const CAPTION_HOLD := 3.2
const CAPTION_FADE := 0.4
## Each slot's drawing in flight, so a second one into the same slot replaces the first.
var _arrivals: Dictionary = {}
var _caption: Label
var _caption_run: Tween


func _ready() -> void:
	add_theme_constant_override(&"separation", 8)
	_home_top = offset_top
	_home_bottom = offset_bottom
	set_process(true)
	# The alpha has to keep moving while a letterbox or a card has the tree stopped.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Its tray is drawn, not a panel, so anything that steers clear of the HUD's panels has to
	# be told this is one too -- see ActionPromptHUD._hud_panels.
	add_to_group(&"hud_blockers")
	# Packed to the left, from the corner it is docked in.
	alignment = BoxContainer.ALIGNMENT_BEGIN
	for index in range(6):
		var button := Button.new()
		button.theme_type_variation = &"InventorySlot"
		button.custom_minimum_size = SLOT
		button.focus_mode = Control.FOCUS_NONE
		button.text = ""
		button.tooltip_text = "Empty"
		button.pressed.connect(_on_slot_pressed.bind(index))
		button.set_drag_forwarding(_drag_from_slot.bind(index), _can_drop_on_slot.bind(index),
			_drop_on_slot.bind(index))
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

		var count := count_badge()
		button.add_child(count)
		_counts.append(count)

		var wear := Panel.new()
		wear.name = "Wear"
		wear.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wear.position = Vector2(WEAR_INSET, SLOT.y - WEAR_INSET * 0.5 - WEAR_HEIGHT)
		wear.size = Vector2(SLOT.x - WEAR_INSET * 2.0, WEAR_HEIGHT)
		wear.add_theme_stylebox_override(&"panel", _wear_box(UISkin.INK))
		wear.visible = false
		var left := Panel.new()
		left.name = "Left"
		left.mouse_filter = Control.MOUSE_FILTER_IGNORE
		left.size = wear.size
		wear.add_child(left)
		button.add_child(wear)
		_wear_bars.append(wear)


## WHAT A WEAPON HAS LEFT, where a level wears weapons out (Dilim): a soft bar along the slot's
## foot, full when drawn and gone with the last swing, warm for the last LOW_WEAR. Read off the
## item's own runtime_state ("uses_left" of "uses_total"), so it follows the item between slots.
const WEAR_HEIGHT := 5.0
const WEAR_INSET := 8.0
const LOW_WEAR := 2

var _wear_bars: Array[Panel] = []


## Redraw what each slot shows, for a change the bag did not make itself -- a swing worn off.
func refresh_wear() -> void:
	if _manager != null:
		_refresh(_manager.items())


## The share of a weapon's uses left, or -1 for anything that does not wear.
static func wear_of(item: DrawnItemData) -> float:
	if item == null:
		return -1.0
	var total := int(item.runtime_state.get("uses_total", 0))
	if total <= 0:
		return -1.0
	return clampf(float(item.runtime_state.get("uses_left", total)) / float(total), 0.0, 1.0)


func _show_wear(index: int, item: DrawnItemData) -> void:
	var bar := _wear_bars[index]
	var share := wear_of(item)
	bar.visible = share >= 0.0
	if share < 0.0:
		return
	var left := bar.get_child(0) as Panel
	left.size = Vector2(bar.size.x * share, bar.size.y)
	var low := int(item.runtime_state.get("uses_left", 0)) <= LOW_WEAR
	left.add_theme_stylebox_override(&"panel", _wear_box(UISkin.PENDING if low else UISkin.USE))


static func _wear_box(color: Color) -> StyleBox:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	return UISkin.rounded(box, int(WEAR_HEIGHT * 0.5))


## THE TRAY. Six loose frames floating on the level read as six separate things; one dark
## strip behind them reads as one bag. Drawn a little outside the bar's own rect, which is the
## size of the slots exactly, so the slots keep their layout and the tray is only ground.
const TRAY_PAD := 8.0


func _draw() -> void:
	var tray := Rect2(Vector2(-TRAY_PAD, -TRAY_PAD), size + Vector2(TRAY_PAD, TRAY_PAD) * 2.0)
	draw_style_box(UISkin.strip(0.0, 0.0), tray)
	# Dragged back over it, the bar says it will take the drawing back.
	if _dragging >= 0 and _over_bar:
		draw_style_box(UISkin.drop_ring(), tray.grow(UISkin.THIN * 2.0))


## HOW MANY OF ONE THING A SLOT HOLDS. Kent: "storing the same object in the inventory places
## them separately like the flower so instead of that how about we use the counter like x1 x2".
## One slot per kind of thing, and a small gold tab in its corner saying how many: "×2". Shared
## with the bag screen, so the pockets there and the bar here count the same way.
static func count_badge() -> Label:
	var badge := Label.new()
	badge.name = "Count"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.visible = false
	badge.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	badge.add_theme_color_override(&"font_color", UISkin.GOLD_LABEL)
	badge.add_theme_color_override(&"font_shadow_color", Color.TRANSPARENT)
	var tab := StyleBoxFlat.new()
	tab.bg_color = UISkin.GOLD_FILL
	tab.border_color = UISkin.GOLD_EDGE
	tab.set_border_width_all(UISkin.THIN)
	tab.content_margin_left = 5.0
	tab.content_margin_right = 5.0
	badge.add_theme_stylebox_override(&"normal", UISkin.rounded(tab, UISkin.KEY_RADIUS))
	# Pinned by its top-right corner and grown down and to the left, so "×2" and "×12" both
	# keep that corner where it is.
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.offset_left = -COUNT_INSET
	badge.offset_right = -COUNT_INSET
	badge.offset_top = COUNT_INSET
	badge.offset_bottom = COUNT_INSET
	return badge


## One of anything needs no number on it; from two on, the tab says how many.
static func show_count(badge: Label, count: int) -> void:
	badge.text = "×%d" % count
	badge.visible = count > 1


func set_manager(manager: InventoryManager) -> void:
	_manager = manager
	if not manager.inventory_changed.is_connected(_refresh):
		manager.inventory_changed.connect(_refresh)
	if not manager.item_moved.is_connected(_on_item_moved):
		manager.item_moved.connect(_on_item_moved)
	_refresh(manager.items())


## The six empty slots, up for a lesson about them, or back to drawing nothing while empty.
func show_empty(on: bool) -> void:
	if on == _shown_empty:
		return
	_shown_empty = on
	_refresh(_manager.items() if _manager != null else [])


func is_shown_empty() -> bool:
	return _shown_empty


## Mark a slot as the one in hand. -1 clears it.
func set_selected(slot: int) -> void:
	_selected = slot
	if _manager != null:
		_refresh(_manager.items())


func selected_slot() -> int:
	return _selected


## The thing in hand keeps its SEL when the bag screen moves it to another slot. The level
## knows what is in hand by what it IS; only this bar knows it by number. Fires before
## inventory_changed, so the refresh that follows already draws the new number.
func _on_item_moved(from_slot: int, to_slot: int) -> void:
	if _selected == from_slot:
		_selected = to_slot
	elif _selected == to_slot:
		_selected = from_slot


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
	var holding := _shown_empty
	for item_value: Variant in items:
		if item_value != null:
			holding = true
			break
	# Faded in rather than popped, the first time there is anything to show.
	if holding and not visible:
		# Faded in from nothing by `_process`, rather than popped.
		modulate.a = 0.0
		visible = true
	elif not holding:
		visible = false
	queue_redraw()
	for index in range(_buttons.size()):
		var item := items[index] as DrawnItemData if index < items.size() else null
		var occupied := item != null
		var chosen := index == _selected and occupied
		var button := _buttons[index]
		button.tooltip_text = "%s — drag it out, or press %d" % [item.display_name, index + 1] \
			if occupied else "Empty"
		# A hand over what can be picked up; the arrow over an empty frame.
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if occupied \
			else Control.CURSOR_ARROW
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
		# ⚠ A SLOT WITH A DRAWING IN IT IS PAPER. The thumbnail is dark ink with the paper
		# knocked out, and on the panel's near-black fill it disappeared.
		var frame := UISkin.slot(occupied, chosen)
		# Under the pointer, a slot with a drawing in it lifts its ring: it can be dragged out.
		var lifted := UISkin.slot(occupied, chosen, occupied)
		if occupied:
			frame.bg_color = PAPER
			lifted.bg_color = PAPER
		for state in [&"normal", &"pressed", &"disabled"]:
			button.add_theme_stylebox_override(state, frame)
		button.add_theme_stylebox_override(&"hover", lifted)
		button.modulate = Color(1.12, 1.12, 1.04) if chosen else Color.WHITE
		_numbers[index].add_theme_color_override(&"font_color", GOLD if occupied else DIM)
		_tags[index].visible = chosen
		show_count(_counts[index], _manager.count(index) if _manager != null else int(occupied))
		_show_wear(index, item)
	_forget_stale_thumbnails(items)


func _thumbnail(item: DrawnItemData) -> Texture2D:
	if item == null or item.image == null:
		return null
	var key := item.instance_id
	var cached: Texture2D = _thumbnails.get(key)
	if cached != null:
		return cached
	# THE PAPER COMES OFF. `item.image` is the grab off the drawing panel's SubViewport,
	# flattened onto cream paper, so a slot holding the player's own drawing would otherwise
	# be an opaque square with something small in the middle of it -- six of them in a row
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


# --- Dragged out -------------------------------------------------------------------------------

## Godot asks this of a slot pressed and moved. The level takes the drawing out the way its key
## does; what it answers is what follows the pointer.
func _drag_from_slot(_at: Vector2, index: int) -> Variant:
	if _dragging >= 0 or _stowed or _click_through or _manager == null \
			or not drag_begins.is_valid():
		return null
	var item := _manager.peek_item(index)
	if item == null:
		return null
	# Before the level takes it: a placeable leaves the bag as it comes out.
	var picture := _thumbnail(item)
	var kind := String(drag_begins.call(index))
	if kind.is_empty():
		return null
	_dragging = index
	_over_bar = true
	_ensure_catcher()
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	# A thing to set down is its own ghost in the world. A tool has none, so its drawing hangs
	# from the pointer instead.
	if kind == "hold" and picture != null:
		_buttons[index].set_drag_preview(_drag_picture(picture))
	_say(DRAG_HINT if kind == "place" else HOLD_HINT)
	queue_redraw()
	return {HUD_DRAG: index}


func _can_drop_on_slot(_at: Vector2, data: Variant, _index: int) -> bool:
	return _is_ours(data)


func _drop_on_slot(_at: Vector2, data: Variant, _index: int) -> void:
	if _is_ours(data):
		_let_go(true)


## The world's answer, through the catcher. `at` is a screen point: the catcher covers the screen
## from its corner.
func _can_drop_on_world(at: Vector2, data: Variant) -> bool:
	if not _is_ours(data):
		return false
	if _bar_has(at):
		return true
	return drop_allowed.is_valid() and bool(drop_allowed.call(_dragging))


func _drop_on_world(at: Vector2, data: Variant) -> void:
	if _is_ours(data):
		_let_go(_bar_has(at))


## While the left button is held on a drag, the wheel and the right button land on the catcher
## rather than in the world: handed on, and the right button ends the drag as it ends a placement.
func _on_catcher_input(event: InputEvent) -> void:
	if _dragging < 0:
		return
	if pointer_during_drag.is_valid():
		pointer_during_drag.call(event)
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
		end_drag()


func is_dragging() -> bool:
	return _dragging >= 0


## The catcher, for a probe that drops the way Godot drops.
func drop_target() -> Control:
	return _catcher


## Call the drag off: the placement it began was put back some other way (Escape, a right-click).
func end_drag() -> void:
	if _dragging < 0:
		return
	var viewport := get_viewport()
	if viewport != null and viewport.gui_is_dragging() and viewport.has_method("gui_cancel_drag"):
		viewport.call("gui_cancel_drag")
	_finish_drag()


## ⚠ A REFUSED DROP IS HEARD HERE, NOT IN A DROP FUNCTION. Let go where nothing takes it -- the
## ghost red, or over another panel -- Godot calls no drop at all; it ends the drag, unsuccessful,
## and tells every Control. That is when the level puts the drawing back and says why.
func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END or _dragging < 0:
		return
	var slot := _dragging
	_finish_drag()
	var viewport := get_viewport()
	if viewport == null or not viewport.gui_is_drag_successful():
		slot_drag_failed.emit(slot)


func _let_go(on_bar: bool) -> void:
	var slot := _dragging
	# Cleared first: what the level does next ends the placement, which calls end_drag.
	_finish_drag()
	slot_dropped.emit(slot, on_bar)


func _finish_drag() -> void:
	_dragging = -1
	_over_bar = false
	if _catcher != null and is_instance_valid(_catcher):
		_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _is_ours(data: Variant) -> bool:
	return _dragging >= 0 and data is Dictionary and (data as Dictionary).has(HUD_DRAG) \
		and int((data as Dictionary)[HUD_DRAG]) == _dragging


## Over the bar or its tray, where letting go puts a drawing back.
func _bar_has(at: Vector2) -> bool:
	return get_global_rect().grow(TRAY_PAD).has_point(at)


func _ensure_catcher() -> void:
	if _catcher != null and is_instance_valid(_catcher):
		return
	var layer := get_parent()
	_catcher = Control.new()
	_catcher.name = "BagDropCatcher"
	_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catcher.set_drag_forwarding(Callable(), _can_drop_on_world, _drop_on_world)
	_catcher.gui_input.connect(_on_catcher_input)
	# First in the layer, so everything the HUD draws is over it and is hit before it.
	layer.add_child(_catcher)
	layer.move_child(_catcher, 0)


## A tool's drawing at the pointer, centred on it -- a preview hangs from its corner otherwise.
func _drag_picture(picture: Texture2D) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := TextureRect.new()
	art.texture = picture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.size = SLOT
	art.position = -SLOT * 0.5
	art.modulate = Color(1.0, 1.0, 1.0, 0.85)
	holder.add_child(art)
	return holder


## Fly `art` into `slot` -- from the middle of the screen, or from `from` (a screen point: where a
## drawing that would not go down was let go) -- and say `caption` over the bag. See
## ARRIVE_SIZE. Called after the drawing is already in the slot: the slot's own picture is
## held back until the flying one lands on it.
func arrive(slot: int, art: Texture2D, caption: String = "", from: Variant = null) -> void:
	if slot < 0 or slot >= _buttons.size():
		return
	_say(caption)
	var layer := get_parent()
	if art == null or layer == null:
		return
	var previous := _arrivals.get(slot) as Node
	if previous != null and is_instance_valid(previous):
		previous.queue_free()
	var flier := TextureRect.new()
	flier.name = "Arriving%d" % (slot + 1)
	flier.texture = art
	flier.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flier.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flier)
	_arrivals[slot] = flier
	_art[slot].modulate.a = 0.0
	var screen := get_viewport().get_visible_rect().size
	var leaving := Rect2(screen * 0.5 - Vector2.ONE * ARRIVE_SIZE * 0.5, Vector2.ONE * ARRIVE_SIZE)
	if from is Vector2:
		leaving = Rect2((from as Vector2) - SLOT * 0.5, SLOT)
	_fly(0.0, flier, leaving, slot)
	var run := flier.create_tween()
	# A drawing is very often answered by a line of story, and a line stops the world; one
	# frozen halfway to the bag is worse than either end of the flight.
	run.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	run.tween_method(_fly.bind(flier, leaving, slot), 0.0, 1.0, ARRIVE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	run.tween_callback(_land.bind(slot, flier))


## Whether a drawing is still on its way into the bag.
func is_arriving() -> bool:
	for flier: Variant in _arrivals.values():
		if flier != null and is_instance_valid(flier):
			return true
	return false


## The line over the bag, or "" when there is none up.
func caption() -> String:
	return _caption.text if _caption != null and _caption.visible else ""


## One step of the flight: along a curve that rises over the straight line and drops into the
## slot, shrinking to the slot's picture. Aimed at where the slot IS on each step, not where it
## was at the start -- the bar fades in under the first drawing ever put in it.
func _fly(t: float, flier: TextureRect, leaving: Rect2, slot: int) -> void:
	if not is_instance_valid(flier):
		return
	var landing := _art[slot].get_global_rect()
	var from := leaving.get_center()
	var to := landing.get_center()
	var over := Vector2((from.x + to.x) * 0.5, minf(from.y, to.y) - ARRIVE_ARC)
	var at := from.lerp(over, t).lerp(over.lerp(to, t), t)
	flier.size = leaving.size.lerp(landing.size, t)
	flier.position = at - flier.size * 0.5


func _land(slot: int, flier: TextureRect) -> void:
	if is_instance_valid(flier):
		flier.queue_free()
	if _arrivals.get(slot) == flier:
		_arrivals.erase(slot)
	_art[slot].modulate.a = 1.0
	# The frame lights as the drawing lands in it -- on self_modulate, for the reason announce()
	# gives, and because `_refresh` owns the button's modulate for the in-hand state.
	var button := _buttons[slot]
	var flash := button.create_tween()
	flash.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	button.self_modulate = Color(1.6, 1.45, 1.0, 1.0)
	flash.tween_property(button, "self_modulate", Color.WHITE, 0.45)


## Whether a panel on this layer -- a lesson's bubble, a card -- is drawn over `rect`. The same
## reading of "a panel" the HUD overlap check makes: a PanelContainer with its own stylebox.
func _under_a_panel(node: Node, rect: Rect2) -> bool:
	if node == self or node == _caption:
		return false
	var panel := node as PanelContainer
	if panel != null and panel.is_visible_in_tree() and panel.has_theme_stylebox_override(&"panel"):
		return panel.get_global_rect().intersects(rect.grow(-3.0))
	for child in node.get_children():
		if _under_a_panel(child, rect):
			return true
	return false


func _say(text: String) -> void:
	if text.is_empty():
		return
	var layer := get_parent()
	if layer == null:
		return
	if _caption == null:
		# On the hint bar's own chip: an outlined line floating over the world (Kent, Dilim:
		# "not user friendly") read as stray text, not as the HUD saying what the key does.
		_caption = Label.new()
		_caption.name = "BagCaption"
		_caption.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
		_caption.add_theme_color_override(&"font_color", UISkin.GOLD_PALE)
		_caption.add_theme_stylebox_override(&"normal", UISkin.chip(10.0, 5.0))
		_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_caption)
	_caption.text = text
	_caption.reset_size()
	# Over the tray, from its left edge -- where the eye already is when a slot lights.
	var bar := get_global_rect()
	_caption.position = Vector2(bar.position.x - TRAY_PAD,
		bar.position.y - TRAY_PAD - _caption.size.y - 6.0)
	_caption.visible = true
	_caption.modulate.a = 1.0
	if _caption_run != null and _caption_run.is_valid():
		_caption_run.kill()
	_caption_run = _caption.create_tween()
	_caption_run.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_caption_run.tween_interval(CAPTION_HOLD)
	_caption_run.tween_property(_caption, "modulate:a", 0.0, CAPTION_FADE)
	_caption_run.tween_callback(func() -> void: _caption.visible = false)


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
		return
	# A brightening, not a movement: the bar is where it always is, and says "this changed".
	if not visible:
		return
	# ON self_modulate, NOT modulate. The first thing ever put in the bag arrives with the bar
	# fading in on `modulate:a`, and a pulse written to `modulate` captured that alpha at zero
	# and tweened back to it -- so the bar faded in and was pinned invisible by its own welcome.
	var pulse := create_tween()
	pulse.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	self_modulate = Color(1.35, 1.25, 0.95, 1.0)
	pulse.tween_property(self, "self_modulate", Color.WHITE, 0.45)


func is_stowed() -> bool:
	return _stowed


## SEE-THROUGH WHILE SHE IS BEHIND IT, and only then.
##
## The lower-left corner is where the thesis puts the toolbelt (§4.5.3.5, Figure 16) and it is
## clear of the player almost everywhere -- except at the left end of a level or a room, where
## the camera stops and she can walk into the corner itself. Hiding the bar on every step was
## the old answer to a bar that was in the MIDDLE; this is the answer to one in the corner: it
## thins out while she is actually behind it, stays where it is, stays clickable, and comes
## back the moment she steps out.
func set_see_through(on: bool) -> void:
	_see_through = on


func is_see_through() -> bool:
	return _see_through


func _resting_alpha() -> float:
	return SEE_THROUGH if _see_through else 1.0


## The level's letterbox, as a multiplier on whatever else the bar wants.
func set_curtain_alpha(alpha: float) -> void:
	_curtain_alpha = clampf(alpha, 0.0, 1.0)


func _process(delta: float) -> void:
	if visible:
		modulate.a = move_toward(modulate.a, _resting_alpha() * _curtain_alpha,
			ALPHA_SPEED * delta)
	# The line over the bag and a drawing on its way into it belong to the bar, and the level's
	# letterbox takes them down with it.
	if _caption != null:
		_caption.self_modulate.a = _curtain_alpha
		# ⚠ AND IT GIVES WAY. A lesson's bubble pointing at the bag or the Draw button lands right
		# here, and the bubble is the thing the player is being taught from; this line only
		# repeats the status line. Both up at once was a caption printed across the bubble
		# (run_hud_watch_level1, drawing the rake at the straw).
		if _caption.visible and _under_a_panel(get_parent(), _caption.get_global_rect()):
			_caption.visible = false
	for flier: Variant in _arrivals.values():
		if flier != null and is_instance_valid(flier):
			(flier as CanvasItem).self_modulate.a = _curtain_alpha
	if _dwell > 0.0:
		_dwell = maxf(0.0, _dwell - delta)
	# Read off the pointer, not off a drop query: over another HUD panel the catcher is not asked.
	if _dragging >= 0:
		var over := _bar_has(get_viewport().get_mouse_position())
		if over != _over_bar:
			_over_bar = over
			queue_redraw()


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
	# Offsets only: the alpha has one writer, `_process`.
