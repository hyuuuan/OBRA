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
	# be told this is one too -- see TutorialCallout._hud_around_me.
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


## THE TRAY. Six loose frames floating on the level read as six separate things; one dark
## strip behind them reads as one bag. Drawn a little outside the bar's own rect, which is the
## size of the slots exactly, so the slots keep their layout and the tray is only ground.
const TRAY_PAD := 8.0


func _draw() -> void:
	var tray := Rect2(Vector2(-TRAY_PAD, -TRAY_PAD), size + Vector2(TRAY_PAD, TRAY_PAD) * 2.0)
	draw_style_box(UISkin.strip(0.0, 0.0), tray)


func set_manager(manager: InventoryManager) -> void:
	_manager = manager
	if not manager.inventory_changed.is_connected(_refresh):
		manager.inventory_changed.connect(_refresh)
	if not manager.item_moved.is_connected(_on_item_moved):
		manager.item_moved.connect(_on_item_moved)
	_refresh(manager.items())


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
	var holding := false
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


## Fly `art` from the middle of the screen into `slot`, and say `caption` over the bag. See
## ARRIVE_SIZE. Called after the drawing is already in the slot: the slot's own picture is
## held back until the flying one lands on it.
func arrive(slot: int, art: Texture2D, caption: String = "") -> void:
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


func _say(text: String) -> void:
	if text.is_empty():
		return
	var layer := get_parent()
	if layer == null:
		return
	if _caption == null:
		_caption = Label.new()
		_caption.name = "BagCaption"
		_caption.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
		_caption.add_theme_color_override(&"font_color", UISkin.GOLD_PALE)
		_caption.add_theme_constant_override(&"outline_size", 6)
		_caption.add_theme_color_override(&"font_outline_color", UISkin.INK)
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
	for flier: Variant in _arrivals.values():
		if flier != null and is_instance_valid(flier):
			(flier as CanvasItem).self_modulate.a = _curtain_alpha
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
	# Offsets only: the alpha has one writer, `_process`.
