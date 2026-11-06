class_name QuickSlotBar
extends Control
## Dilim's quick slots on screen: five soft slots, each with its key, its thing and how many.
##
## Readable mid-fight, which is the whole brief (Kent's design: "Quick-slot bar with stack counts,
## readable mid-combat"). The key on each slot is read off the live input map, so a rebinding
## cannot leave it naming a key that does nothing. A spent thing stays in its slot, faded, so
## nothing moves under her fingers; an empty slot is a faint outline. A slot flashes when it is
## used, and when something new comes into it.
##
## Draws itself; holds no state of its own beyond what the satchel says.
##
## NOT THERE UNTIL SOMETHING IS IN IT. A row of empty slots with their keys on them, from the first step
## into the woods, said nothing a player could use (Kent: "no clear instructions and not user
## friendly"): the bar pops in with the first of Lola's things she finds, and stays.

const ControlsKeys = preload("res://scripts/controls_overlay.gd")
const ICONS := "res://assets/Level4/props/"
const SLOT := Vector2(64.0, 64.0)
## Wide enough apart that the longest name and what each thing does, at the readable floor, stay
## under their own slot: Buntot Pagi, Lights here.
const GAP := 60.0
const RADIUS := 10.0
const ICON_SCALE := 1.25
const SPENT_ALPHA := 0.32
const FLASH_SECONDS := 0.35
## The first of a kind found: its slot wears a pulsing gold ring this long, so the eye finds where
## it went. A 0.35 s brighten while she reads what the thing does was over before she looked down.
const WELCOME_SECONDS := 2.6
const WELCOME_HZ := 1.4
## ⚠ THE KEY AND THE COUNT ARE READ, SO THEY ARE AT THE FLOOR. They were 12 and 15 px: the one thing
## she has to find mid-fight was the smallest type on the screen.
const CAP := Vector2(30.0, 28.0)
## WHEN TO PRESS IT, shown while it is true: the level asks for a slot, and it wears the gold ring
## and a Now chip over it. Held a little past the moment, so the chip does not flicker as a foe
## steps in and out of reach.
const WANTED_HOLD := 0.6
const NOW_TEXT := "Now"
const NOW_RISE := 32.0
## A press that could do nothing: the slot shakes for this long, whole pixels at the pixel rate.
const REFUSED_SECONDS := 0.3
const REFUSED_SHAKE := 3.0
## What she carries with no slot, standing to the left of the first: it has no key to name, and
## says so.
const NO_SLOT_TEXT := "No slot yet"
const COUNT_FONT := UISkin.FONT_CAPTION
const CAP_FONT := UISkin.FONT_CAPTION
## Under each filled slot, its name and what it does: an icon of a white heap and a 2 did not say
## "salt" to anyone who had missed the line that came with it, and "Asin" alone did not say what it
## was for to anyone who had (Kent: "not that clear to use and when to use").
const NAME_FONT := UISkin.FONT_CAPTION
const NAME_GAP := 4.0
const NAME_ROW := 22.0

var satchel: Satchel = null
var _icons: Dictionary = {}
var _flash: Array[float] = []
var _welcome: Array[float] = []
var _wanted: Array[float] = []
var _refused: Array[float] = []
var _wanted_clock := 0.0


## Each slot's count as last drawn, so a slot that gains can be told from one that is used.
var _counts: Array[int] = []

func _init() -> void:
	for timers: Array[float] in [_flash, _welcome, _wanted, _refused]:
		timers.resize(Satchel.SLOTS)
		timers.fill(0.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(SLOT.x * Satchel.SLOTS + GAP * (Satchel.SLOTS - 1),
		SLOT.y + CAP.y * 0.5 + NAME_GAP + NAME_ROW * 2.0)
	size = custom_minimum_size


func bind(source: Satchel) -> void:
	satchel = source
	_counts = _now()
	visible = holds_anything()
	# A slot that gains -- a find, a drop -- brightens, as a slot used does.
	satchel.changed.connect(func() -> void:
		var now := _now()
		for index in range(mini(now.size(), _counts.size())):
			if now[index] > _counts[index]:
				flash(index)
		_counts = now
		# A checkpoint from before the first find takes it away again.
		if visible != holds_anything():
			if visible:
				visible = false
			else:
				Motion.pop_in(self)
		queue_redraw())
	queue_redraw()


## Whether any slot has had something put in it -- a spent one still counts: it stays, faded.
func holds_anything() -> bool:
	return satchel != null and satchel.slots().any(func(id: String) -> bool: return not id.is_empty())


func _now() -> Array[int]:
	var out: Array[int] = []
	for id in satchel.slots():
		out.append(satchel.count(id) if not id.is_empty() else 0)
	return out


## A slot was used, or filled: it brightens for a moment.
func flash(index: int) -> void:
	if index >= 0 and index < _flash.size():
		_flash[index] = FLASH_SECONDS
		queue_redraw()


## The first of a kind has come into slot `index`: it wears the welcome ring for a while.
func welcome(index: int) -> void:
	if index >= 0 and index < _welcome.size():
		_welcome[index] = WELCOME_SECONDS
		flash(index)


func is_welcoming(index: int) -> bool:
	return index >= 0 and index < _welcome.size() and _welcome[index] > 0.0


## Whether slot `index` is the thing to press now. The level says each tick; it stays lit
## WANTED_HOLD past the last time it did.
func set_wanted(index: int, wanted: bool) -> void:
	if wanted and index >= 0 and index < _wanted.size():
		_wanted[index] = WANTED_HOLD
		queue_redraw()


func is_wanted(index: int) -> bool:
	return index >= 0 and index < _wanted.size() and _wanted[index] > 0.0


## A press that did nothing: it says so with a shake (nothing, under Reduce motion, but the words
## that come with it).
func refuse(index: int) -> void:
	if index >= 0 and index < _refused.size():
		_refused[index] = REFUSED_SECONDS
		queue_redraw()


func is_refusing(index: int) -> bool:
	return index >= 0 and index < _refused.size() and _refused[index] > 0.0


## What she carries with no key, for a probe as for the screen.
func waiting_names() -> Array[String]:
	var out: Array[String] = []
	if satchel != null:
		for id in satchel.waiting():
			out.append(String(satchel.row(id).get("display_name", id)))
	return out


func _process(delta: float) -> void:
	var lit := false
	_wanted_clock += delta
	for index in range(_flash.size()):
		if _wanted[index] > 0.0:
			_wanted[index] = maxf(0.0, _wanted[index] - delta)
			lit = true
		if _refused[index] > 0.0:
			_refused[index] = maxf(0.0, _refused[index] - delta)
			lit = true
		if _flash[index] > 0.0:
			_flash[index] = maxf(0.0, _flash[index] - delta)
			lit = true
		if _welcome[index] > 0.0:
			_welcome[index] = maxf(0.0, _welcome[index] - delta)
			lit = true
	if lit:
		queue_redraw()


func slot_rect(index: int) -> Rect2:
	return Rect2(Vector2(index * (SLOT.x + GAP), CAP.y * 0.5), SLOT)


func _draw() -> void:
	var font := get_theme_default_font()
	for index in range(Satchel.SLOTS):
		var rect := slot_rect(index)
		rect.position.x += _shake_of(index)
		var id := satchel.slot_item(index) if satchel != null else ""
		var count := satchel.count(id) if satchel != null and not id.is_empty() else 0
		var glow := _flash[index] / FLASH_SECONDS
		if id.is_empty():
			_round(rect, Color(UISkin.PANEL, 0.35), Color(UISkin.MUTED, 0.25), 1)
		else:
			_round(rect, UISkin.PANEL.lerp(UISkin.PANEL_LIT, glow),
				UISkin.GOLD if count > 0 else UISkin.RING_MID, 2)
			var art := _icon(id)
			if art != null:
				var side := art.get_size() * ICON_SCALE
				draw_texture_rect(art, Rect2(rect.get_center() - side * 0.5, side), false,
					Color(1, 1, 1, 1.0 if count > 0 else SPENT_ALPHA))
			var number := str(count)
			var width := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, COUNT_FONT).x
			var at := rect.end - Vector2(width + 5.0, 5.0)
			draw_string_outline(font, at, number, HORIZONTAL_ALIGNMENT_LEFT, -1, COUNT_FONT, 4,
				Color(UISkin.PANEL, 0.9))
			draw_string(font, at, number, HORIZONTAL_ALIGNMENT_LEFT, -1, COUNT_FONT,
				UISkin.CREAM_TEXT if count > 0 else UISkin.MUTED)
			_draw_label(font, rect, 0, slot_name(index), UISkin.CREAM_TEXT if count > 0 else UISkin.MUTED)
			_draw_label(font, rect, 1, slot_does(index), UISkin.GOLD if count > 0 else UISkin.MUTED)
		if _welcome[index] > 0.0:
			_draw_welcome(rect, _welcome[index])
		elif _wanted[index] > 0.0:
			_draw_wanted(font, rect)
		# The key, on a little cap over the slot's top-left corner.
		var cap := Rect2(rect.position + Vector2(-6.0, -CAP.y * 0.5), CAP)
		_round(cap, UISkin.GOLD_FILL if not id.is_empty() else Color(UISkin.GOLD_FILL, 0.4),
			UISkin.GOLD_EDGE, 1, 5.0)
		var key := ControlsKeys.key_cap_for("quick_slot_%d" % (index + 1))
		var key_width := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, CAP_FONT).x
		draw_string(font, cap.position + Vector2((CAP.x - key_width) * 0.5, CAP.y - 6.0), key,
			HORIZONTAL_ALIGNMENT_LEFT, -1, CAP_FONT, UISkin.GOLD_LABEL)
	_draw_waiting(font)


## Where a press that did nothing has its slot, this frame: left, right, left, a step at the pixel
## rate, still under Reduce motion.
func _shake_of(index: int) -> float:
	if _refused[index] <= 0.0 or Motion.reduced():
		return 0.0
	var step := int((REFUSED_SECONDS - _refused[index]) * Motion.PIXEL_FPS)
	return REFUSED_SHAKE * (1.0 if step % 2 == 0 else -1.0)


## The thing to press now: the gold ring, breathing, and a chip that says so.
func _draw_wanted(font: Font, rect: Rect2) -> void:
	var breath := 1.0 if Motion.reduced() else 0.5 + 0.5 * sin(_wanted_clock * TAU * WELCOME_HZ)
	var ring := rect.grow(4.0 + roundf(2.0 * breath))
	_round(ring, Color(UISkin.GOLD, 0.0), Color(UISkin.GOLD, 0.625 + 0.375 * breath), 2, RADIUS + 4.0)
	var width := font.get_string_size(NOW_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT).x
	var chip := Rect2(Vector2(rect.get_center().x - width * 0.5 - 8.0, rect.position.y - NOW_RISE - CAP.y * 0.5 + 6.0),
		Vector2(width + 16.0, 26.0)).abs()
	_round(chip, UISkin.GOLD_FILL, UISkin.GOLD_EDGE, 1, 6.0)
	draw_string(font, chip.position + Vector2(8.0, 20.0), NOW_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1,
		NAME_FONT, UISkin.GOLD_LABEL)


## Left of the first slot, what she carries that has no slot of its own: a slot's worth of hollow,
## its thing and how many, and no cap, because no key is what is wrong with it.
func _draw_waiting(font: Font) -> void:
	if satchel == null:
		return
	var waiting := satchel.waiting()
	for order in range(waiting.size()):
		var id := waiting[order]
		var rect := Rect2(Vector2(-(order + 1) * (SLOT.x + GAP), CAP.y * 0.5), SLOT)
		_round(rect, Color(UISkin.PANEL, 0.55), UISkin.RING_MID, 1)
		var art := _icon(id)
		if art != null:
			var side := art.get_size() * ICON_SCALE
			draw_texture_rect(art, Rect2(rect.get_center() - side * 0.5, side), false, Color(1, 1, 1, 0.625))
		var number := str(satchel.count(id))
		var width := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, COUNT_FONT).x
		draw_string(font, rect.end - Vector2(width + 5.0, 5.0), number, HORIZONTAL_ALIGNMENT_LEFT, -1,
			COUNT_FONT, UISkin.MUTED)
		_draw_label(font, rect, 0, String(satchel.row(id).get("display_name", id)), UISkin.MUTED)
		_draw_label(font, rect, 1, NO_SLOT_TEXT, UISkin.MUTED)


## A gold ring round the slot, breathing out and in, fading over its last half second. Steady
## under Reduce motion.
func _draw_welcome(rect: Rect2, left: float) -> void:
	var fade := clampf(left / 0.5, 0.0, 1.0)
	var breath := 1.0 if Motion.reduced() \
		else 0.5 + 0.5 * sin((WELCOME_SECONDS - left) * TAU * WELCOME_HZ)
	var ring := rect.grow(4.0 + roundf(2.0 * breath))
	_round(ring, Color(UISkin.GOLD, 0.0), Color(UISkin.GOLD, (0.55 + 0.45 * breath) * fade), 2, RADIUS + 4.0)


## What slot `index` is called on screen: its thing's name, or nothing while it is empty.
func slot_name(index: int) -> String:
	var id := satchel.slot_item(index) if satchel != null else ""
	return "" if id.is_empty() else String(satchel.row(id).get("display_name", id))


## What slot `index` does, in a phrase: the file's `does`, or nothing while it is empty.
func slot_does(index: int) -> String:
	var id := satchel.slot_item(index) if satchel != null else ""
	return "" if id.is_empty() else String(satchel.row(id).get("does", ""))


## One of the rows under a slot, centred on it: 0 its name, 1 what it does.
func _draw_label(font: Font, rect: Rect2, row: int, text: String, colour: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT).x
	var at := Vector2(rect.get_center().x - width * 0.5, rect.end.y + NAME_GAP + NAME_ROW * (row + 1) - 3.0)
	# Outlined: the bar sits over the world, and in Dilim the world is the dark.
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT, 4, Color(UISkin.PANEL, 0.9))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT, colour)


func _icon(id: String) -> Texture2D:
	if not _icons.has(id):
		var path := ICONS + id + ".png"
		_icons[id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _icons[id]


func _round(rect: Rect2, fill: Color, edge: Color, width: int, radius: float = RADIUS) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(int(radius))
	box.anti_aliasing = true
	box.border_color = edge
	box.set_border_width_all(width)
	draw_style_box(box, rect)
