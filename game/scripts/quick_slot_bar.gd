class_name QuickSlotBar
extends Control
## Dilim's quick slots on screen: four soft slots, each with its key, its thing and how many.
##
## Readable mid-fight, which is the whole brief (Kent's design: "Quick-slot bar with stack counts,
## readable mid-combat"). The key on each slot is read off the live input map, so a rebinding
## cannot leave it naming a key that does nothing. A spent thing stays in its slot, faded, so
## nothing moves under her fingers; an empty slot is a faint outline. A slot flashes when it is
## used, and when something new comes into it.
##
## Draws itself; holds no state of its own beyond what the satchel says.
##
## NOT THERE UNTIL SOMETHING IS IN IT. Four empty slots with Z X C V on them, from the first step
## into the woods, said nothing a player could use (Kent: "no clear instructions and not user
## friendly"): the bar pops in with the first of Lola's things she finds, and stays.

const ControlsKeys = preload("res://scripts/controls_overlay.gd")
const ICONS := "res://assets/Level4/props/"
const SLOT := Vector2(56.0, 56.0)
const GAP := 10.0
const RADIUS := 10.0
const ICON_SCALE := 1.25
const SPENT_ALPHA := 0.32
const FLASH_SECONDS := 0.35
const CAP := Vector2(20.0, 18.0)
const COUNT_FONT := 15
const CAP_FONT := 12
## Each filled slot's name, under it: an icon of a white heap and a 2 did not say "salt" to anyone
## who had missed the line that came with it. Shrunk to fit a slot's width, never past NAME_MIN.
const NAME_FONT := 13
const NAME_MIN := 10
const NAME_GAP := 5.0
const NAME_ROW := 15.0

var satchel: Satchel = null
var _icons: Dictionary = {}
var _flash: Array[float] = [0.0, 0.0, 0.0, 0.0]


## Each slot's count as last drawn, so a slot that gains can be told from one that is used.
var _counts: Array[int] = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(SLOT.x * Satchel.SLOTS + GAP * (Satchel.SLOTS - 1),
		SLOT.y + CAP.y * 0.5 + NAME_GAP + NAME_ROW)
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


func _process(delta: float) -> void:
	var lit := false
	for index in range(_flash.size()):
		if _flash[index] > 0.0:
			_flash[index] = maxf(0.0, _flash[index] - delta)
			lit = true
	if lit:
		queue_redraw()


func slot_rect(index: int) -> Rect2:
	return Rect2(Vector2(index * (SLOT.x + GAP), CAP.y * 0.5), SLOT)


func _draw() -> void:
	var font := get_theme_default_font()
	for index in range(Satchel.SLOTS):
		var rect := slot_rect(index)
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
			draw_string(font, rect.end - Vector2(width + 5.0, 5.0), number, HORIZONTAL_ALIGNMENT_LEFT,
				-1, COUNT_FONT, UISkin.CREAM_TEXT if count > 0 else UISkin.MUTED)
			_draw_name(font, rect, slot_name(index), count > 0)
		# The key, on a little cap over the slot's top-left corner.
		var cap := Rect2(rect.position + Vector2(-4.0, -CAP.y * 0.5), CAP)
		_round(cap, UISkin.GOLD_FILL if not id.is_empty() else Color(UISkin.GOLD_FILL, 0.4),
			UISkin.GOLD_EDGE, 1, 5.0)
		var key := ControlsKeys.key_cap_for("quick_slot_%d" % (index + 1))
		var key_width := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, CAP_FONT).x
		draw_string(font, cap.position + Vector2((CAP.x - key_width) * 0.5, CAP.y - 4.0), key,
			HORIZONTAL_ALIGNMENT_LEFT, -1, CAP_FONT, UISkin.GOLD_LABEL)


## What slot `index` is called on screen: its thing's name, or nothing while it is empty.
func slot_name(index: int) -> String:
	var id := satchel.slot_item(index) if satchel != null else ""
	return "" if id.is_empty() else String(satchel.row(id).get("display_name", id))


func _draw_name(font: Font, rect: Rect2, text: String, live: bool) -> void:
	var font_size := NAME_FONT
	var room := SLOT.x + GAP - 2.0
	while font_size > NAME_MIN and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
		font_size -= 1
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := Vector2(rect.get_center().x - width * 0.5, rect.end.y + NAME_GAP + NAME_ROW - 3.0)
	# Outlined: the bar sits over the world, and in Dilim the world is the dark.
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(UISkin.PANEL, 0.9))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		UISkin.CREAM_TEXT if live else UISkin.MUTED)


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
