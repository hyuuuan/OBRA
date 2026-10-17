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

var satchel: Satchel = null
var _icons: Dictionary = {}
var _flash: Array[float] = [0.0, 0.0, 0.0, 0.0]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(SLOT.x * Satchel.SLOTS + GAP * (Satchel.SLOTS - 1), SLOT.y + CAP.y * 0.5)
	size = custom_minimum_size


func bind(source: Satchel) -> void:
	satchel = source
	satchel.changed.connect(queue_redraw)
	queue_redraw()


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
		# The key, on a little cap over the slot's top-left corner.
		var cap := Rect2(rect.position + Vector2(-4.0, -CAP.y * 0.5), CAP)
		_round(cap, UISkin.GOLD_FILL if not id.is_empty() else Color(UISkin.GOLD_FILL, 0.4),
			UISkin.GOLD_EDGE, 1, 5.0)
		var key := ControlsKeys.key_cap_for("quick_slot_%d" % (index + 1))
		var key_width := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, CAP_FONT).x
		draw_string(font, cap.position + Vector2((CAP.x - key_width) * 0.5, CAP.y - 4.0), key,
			HORIZONTAL_ALIGNMENT_LEFT, -1, CAP_FONT, UISkin.GOLD_LABEL)


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
