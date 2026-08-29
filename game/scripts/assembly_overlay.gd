class_name AssemblyOverlay
extends ModalOverlay
## Scene 3. Seven torn pieces of Lola's painting, and then Piyesta is whole.
##
## `scrap_assembly.gd` is the rule -- what snaps, what is idempotent, when it is finished.
## This is the table it happens on. Like the dance, the model shipped complete and tested
## with nothing calling it, so the level could recover all seven scraps and then had nowhere
## to put them: it could not be finished at all.
##
## KEEP IT LIGHT. The design says so in as many words -- *"seven scraps into seven slots,
## drag with a snap. Keep it a light interaction, not a puzzle with a fail state at the end
## of the level."* The player has answered three nodes and crossed two alleys to get here.
## So: no timer, no wrong answers, nothing to lose, and a snap generous enough that nobody
## fights a picture they have earned.
##
## A PIECE BELONGS WHERE IT WAS TORN FROM, which is why there is no slot table. Each scrap's
## offset in `scraps.json` IS its slot -- `tools/build_scraps.py` cut it from there -- so the
## two cannot drift apart, and "put it back" is literally what the player is doing.
##
## THE PIECES START SCATTERED, NOT IN A TRAY. Seven pieces of a 1672-wide painting are large;
## a row of them along the bottom would either be unreadably small or wider than the screen.
## Offset from their own slots on a ring, they read as a picture somebody has knocked
## sideways -- which is what happened to it -- and every one is always on screen and always
## reachable.
##
## ⚠ THE CREASE IS DRAWN, NOT LOADED. The design asks for a transparent PNG overlay sized to
## Level2_CompletedLook and it does not exist yet; this draws the fold procedurally so the
## consequence of Level 1's Protector route is visible rather than merely recorded. See
## CONTENT_NEEDED.md.

## The picture is whole and the player has dismissed it. The level ends off this.
signal assembly_done(creased: bool)

const MANIFEST := "res://assets/Level2/scraps/scraps.json"
const SCRAP_DIR := "res://assets/Level2/scraps/"

const INK := Color(0.027, 0.035, 0.024, 1.0)        # 070906
const PANEL := Color(0.051, 0.063, 0.035, 1.0)      # 0D1009
const RING_MID := Color(0.420, 0.306, 0.090, 1.0)   # 6B4E17
const MUTED := Color(0.808, 0.757, 0.612, 1.0)      # CEC19C
const GOLD := Color(0.859, 0.659, 0.208, 1.0)       # DBA835
const GOLD_PALE := Color(0.945, 0.855, 0.616, 1.0)  # F1DA9D
## The fold, where Level 1's Protector route cut the canvas open. Paper, not ink: a crease
## is a highlight along one edge of the fold and a shadow along the other.
const FOLD_DARK := Color(0.086, 0.075, 0.059, 0.55)
const FOLD_LIT := Color(1.0, 0.976, 0.902, 0.30)

var _assembly: ScrapAssembly
var _stage: Control
var _title: Label
var _status: Label
var _continue: Button

## id -> { texture, image, slot: Vector2, size: Vector2, at: Vector2 }. `slot` is where the
## piece belongs in painting pixels; `at` is where it is now.
var _pieces: Dictionary = {}
var _order: Array[String] = []
var _painting := Vector2(1672.0, 941.0)
## Painting pixels to screen pixels, and where the board's top-left sits on the stage.
var _scale := 1.0
var _origin := Vector2.ZERO
var _dragging := ""
var _grab := Vector2.ZERO
var _done := false


func _ready() -> void:
	super()
	layer = 67
	# The picture is the end of the level. Escape must not throw it away half-mended.
	closes_on_cancel = false
	_build()
	_load_pieces()


func bind(model: ScrapAssembly) -> void:
	_assembly = model


func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(INK.r, INK.g, INK.b, 0.92)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(centre)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(1340.0, 880.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(panel)
	UIFrame.wrap(panel)

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_%s" % side, 26)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(pad)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(box)

	_title = Label.new()
	_title.text = "PIYESTA"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 32)
	_title.add_theme_color_override("font_color", GOLD_PALE)
	box.add_child(_title)
	box.add_child(HSeparator.new())

	_stage = Control.new()
	_stage.name = "Stage"
	_stage.custom_minimum_size = Vector2(1260.0, 700.0)
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.gui_input.connect(_on_stage_input)
	_stage.draw.connect(_draw_stage)
	_stage.resized.connect(_fit_the_board)
	box.add_child(_stage)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 19)
	_status.add_theme_color_override("font_color", MUTED)
	box.add_child(_status)

	_continue = Button.new()
	_continue.text = "CONTINUE"
	_continue.visible = false
	_continue.pressed.connect(_on_continue)
	box.add_child(_continue)


## The pieces and where each belongs, straight out of what the cutter wrote.
func _load_pieces() -> void:
	var file := FileAccess.open(MANIFEST, FileAccess.READ)
	if file == null:
		push_error("AssemblyOverlay: %s is missing -- run tools/build_scraps.py" % MANIFEST)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("AssemblyOverlay: %s does not parse" % MANIFEST)
		return
	var manifest: Dictionary = parsed
	var size: Array = manifest.get("size", [1672, 941])
	_painting = Vector2(float(size[0]), float(size[1]))
	for entry: Variant in manifest.get("pieces", []):
		var piece: Dictionary = entry
		var texture := load(SCRAP_DIR + String(piece["file"])) as Texture2D
		if texture == null:
			push_error("AssemblyOverlay: no texture for %s" % piece.get("id", "?"))
			continue
		var scrap_id := String(piece["id"])
		var offset: Array = piece["offset"]
		var piece_size: Array = piece["size"]
		_pieces[scrap_id] = {
			"texture": texture,
			# Kept so a click can test the PAPER rather than the bounding box. Seven torn
			# pieces scattered on a table overlap constantly, and a box test picks whichever
			# is on top by a transparent corner -- which feels like the game ignoring you.
			"image": texture.get_image(),
			"slot": Vector2(float(offset[0]), float(offset[1])),
			"size": Vector2(float(piece_size[0]), float(piece_size[1])),
			"at": Vector2(float(offset[0]), float(offset[1])),
		}
		_order.append(scrap_id)


# --- Opening ------------------------------------------------------------------------------

## Lay the pieces out and hand the table to the player.
func present() -> void:
	if _assembly == null or _pieces.is_empty():
		push_error("AssemblyOverlay: opened with no model or no pieces")
		return
	var slots: Dictionary = {}
	for scrap_id: Variant in _pieces.keys():
		slots[scrap_id] = (_pieces[scrap_id] as Dictionary)["slot"]
	_assembly.set_slots(slots)
	_scatter()
	_done = false
	_continue.visible = false
	_title.text = "PIYESTA"
	_status.text = "Put her back together. Drag each piece to where it belongs."
	open()
	_fit_the_board()
	_stage.queue_redraw()


## Knocked sideways rather than shuffled. Each piece goes out from the centre of the painting
## on its own bearing, far enough to be plainly out of place and not so far that it leaves
## the board -- so the picture reads as damaged, which is what it is, and every piece is
## always on screen.
func _scatter() -> void:
	var centre := _painting * 0.5
	var count := float(_order.size())
	for index in range(_order.size()):
		var piece: Dictionary = _pieces[_order[index]]
		var slot: Vector2 = piece["slot"]
		var away := (slot + (piece["size"] as Vector2) * 0.5) - centre
		if away.length() < 1.0:
			away = Vector2.RIGHT
		var bearing := away.normalized().rotated(
			(float(index) / count - 0.5) * 0.9)
		piece["at"] = slot + bearing * 150.0
		_pieces[_order[index]] = piece


## Fit the whole painting inside the stage, with room for the pieces that are pushed out
## past its edges.
func _fit_the_board() -> void:
	if _stage == null or _painting.x <= 0.0:
		return
	# ⚠ THE BOARD DOES NOT FILL THE STAGE, and that is not a margin for looks. The pieces
	# start pushed OUT of their slots, so if the painting fills the frame there is nowhere
	# for them to be pushed to -- the first cut ran them off the panel and over the title.
	# Two thirds leaves a piece's worth of room on every side.
	var room := _stage.size * 0.66
	_scale = minf(room.x / _painting.x, room.y / _painting.y)
	_origin = (_stage.size - _painting * _scale) * 0.5
	_keep_everything_on_the_table()
	_stage.queue_redraw()


## Nothing may sit where it cannot be reached. Clamped in SCREEN space and converted back,
## because the constraint is about the frame the player is looking at and not about the
## painting's own coordinates.
func _keep_everything_on_the_table() -> void:
	for scrap_id in _order:
		var piece: Dictionary = _pieces[scrap_id]
		if piece.get("locked", false):
			continue
		piece["at"] = _clamped(piece["at"] as Vector2, piece["size"] as Vector2)
		_pieces[scrap_id] = piece


func _clamped(at: Vector2, size: Vector2) -> Vector2:
	var on_screen := _to_screen(at)
	var extent := size * _scale
	on_screen.x = clampf(on_screen.x, 4.0, maxf(4.0, _stage.size.x - extent.x - 4.0))
	on_screen.y = clampf(on_screen.y, 4.0, maxf(4.0, _stage.size.y - extent.y - 4.0))
	return _to_painting(on_screen)


func _to_screen(at: Vector2) -> Vector2:
	return _origin + at * _scale


func _to_painting(at: Vector2) -> Vector2:
	return (at - _origin) / maxf(_scale, 0.0001)


# --- The hand -------------------------------------------------------------------------------

func _on_stage_input(event: InputEvent) -> void:
	if _done:
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_dragging = _piece_under(_to_painting(button.position))
			if not _dragging.is_empty():
				var piece: Dictionary = _pieces[_dragging]
				_grab = _to_painting(button.position) - (piece["at"] as Vector2)
				# To the top of the pile, so a piece being moved is never under another.
				_order.erase(_dragging)
				_order.append(_dragging)
		elif not _dragging.is_empty():
			_release()
		_stage.accept_event()
		_stage.queue_redraw()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and not _dragging.is_empty():
		var piece: Dictionary = _pieces[_dragging]
		piece["at"] = _clamped(_to_painting(motion.position) - _grab,
			piece["size"] as Vector2)
		_pieces[_dragging] = piece
		_stage.accept_event()
		_stage.queue_redraw()


## The topmost piece whose PAPER is under the cursor. Drawn last is picked first, which is
## what "topmost" means on a table.
func _piece_under(at: Vector2) -> String:
	for index in range(_order.size() - 1, -1, -1):
		var scrap_id := _order[index]
		if _assembly.is_complete() or _placed(scrap_id):
			continue
		var piece: Dictionary = _pieces[scrap_id]
		var local := at - (piece["at"] as Vector2)
		var size: Vector2 = piece["size"]
		if local.x < 0.0 or local.y < 0.0 or local.x >= size.x or local.y >= size.y:
			continue
		var image: Image = piece["image"]
		if image.get_pixel(int(local.x), int(local.y)).a > 0.35:
			return scrap_id
	return ""


func _placed(scrap_id: String) -> bool:
	var piece: Dictionary = _pieces.get(scrap_id, {})
	return piece.get("locked", false)


## Put a piece down at `at`, in painting pixels, and let go. PUBLIC, and for the same reason
## `DanceOverlay.perform_stroke` is: "the player released a piece here" is the actual event
## this screen is built around, and the mouse is one way to raise it. Returns whether it took
## its slot.
func drag_to(scrap_id: String, at: Vector2) -> bool:
	if not _pieces.has(scrap_id) or _placed(scrap_id) or _done:
		return false
	var piece: Dictionary = _pieces[scrap_id]
	piece["at"] = at
	_pieces[scrap_id] = piece
	_dragging = scrap_id
	_release()
	_stage.queue_redraw()
	return _placed(scrap_id)


## Where a piece belongs, and where it currently is. Both in painting pixels.
func slot_of(scrap_id: String) -> Vector2:
	var piece: Dictionary = _pieces.get(scrap_id, {})
	return piece.get("slot", Vector2.INF)


func position_of(scrap_id: String) -> Vector2:
	var piece: Dictionary = _pieces.get(scrap_id, {})
	return piece.get("at", Vector2.INF)


func piece_ids() -> Array[String]:
	var out: Array[String] = []
	for scrap_id: Variant in _pieces.keys():
		out.append(String(scrap_id))
	return out


func _release() -> void:
	var scrap_id := _dragging
	_dragging = ""
	var piece: Dictionary = _pieces[scrap_id]
	if _assembly.drop(scrap_id, piece["at"] as Vector2):
		# Snapped: it goes exactly where it was torn from, not where it was dropped.
		piece["at"] = piece["slot"]
		piece["locked"] = true
		_pieces[scrap_id] = piece
		_status.text = "%d of %d." % [_assembly.placed(), _assembly.slot_count()]
		if _assembly.is_complete():
			_finish()
		return
	_pieces[scrap_id] = piece
	# NOT A FAILURE, and it must not be worded as one. There is nothing to get wrong here.
	_status.text = "Not quite there. Closer to where it came from."


func _finish() -> void:
	_done = true
	_dragging = ""
	_title.text = "PIYESTA"
	_status.text = "There she is." if not _assembly.is_creased() \
		else "There she is. The fold will not come out."
	_continue.visible = true
	_continue.grab_focus()
	_stage.queue_redraw()


func _on_continue() -> void:
	close()
	assembly_done.emit(_assembly.is_creased())


# --- The table --------------------------------------------------------------------------

func _draw_stage() -> void:
	_draw_board()
	for scrap_id in _order:
		_draw_piece(scrap_id)
	if _done:
		_draw_crease()


## What the picture will be, as an empty frame. Not a ghost of each piece -- that would make
## it a matching exercise with the answers printed on it -- but the outline has to be there
## or the player is dragging paper around an unbounded void.
func _draw_board() -> void:
	var rect := Rect2(_origin, _painting * _scale)
	_stage.draw_rect(rect, PANEL)
	for edge: Rect2 in [
			Rect2(rect.position, Vector2(rect.size.x, 3.0)),
			Rect2(rect.position + Vector2(0.0, rect.size.y - 3.0), Vector2(rect.size.x, 3.0)),
			Rect2(rect.position, Vector2(3.0, rect.size.y)),
			Rect2(rect.position + Vector2(rect.size.x - 3.0, 0.0), Vector2(3.0, rect.size.y))]:
		_stage.draw_rect(edge, RING_MID)
	# WHERE THE PIECE IN YOUR HAND GOES, and only that one. A light assist rather than a
	# solution: it appears when you pick something up and goes when you put it down.
	if _dragging.is_empty():
		return
	var piece: Dictionary = _pieces[_dragging]
	var ghost := Rect2(_to_screen(piece["slot"] as Vector2),
		(piece["size"] as Vector2) * _scale)
	_stage.draw_rect(ghost, Color(GOLD.r, GOLD.g, GOLD.b, 0.10))
	_stage.draw_rect(ghost, Color(GOLD.r, GOLD.g, GOLD.b, 0.45), false, 2.0)


func _draw_piece(scrap_id: String) -> void:
	var piece: Dictionary = _pieces[scrap_id]
	var rect := Rect2(_to_screen(piece["at"] as Vector2), (piece["size"] as Vector2) * _scale)
	# A loose piece throws a shadow and a placed one does not, which is the whole of how the
	# player sees what is still to do without anything having to say it.
	if not _placed(scrap_id):
		_stage.draw_texture_rect(piece["texture"] as Texture2D,
			Rect2(rect.position + Vector2(5.0, 6.0), rect.size), false,
			Color(0.0, 0.0, 0.0, 0.35))
	_stage.draw_texture_rect(piece["texture"] as Texture2D, rect, false)
	if scrap_id == _dragging:
		_stage.draw_rect(rect, Color(GOLD_PALE.r, GOLD_PALE.g, GOLD_PALE.b, 0.5), false, 2.0)


## Level 1's Protector route, two levels later. The player cut Lola's canvas open to get at
## it, and the fold runs through the finished picture for the rest of the game.
func _draw_crease() -> void:
	if _assembly == null or not _assembly.is_creased():
		return
	var rect := Rect2(_origin, _painting * _scale)
	# Off-centre and slightly off-vertical, because a fold somebody made in a hurry is not a
	# centre line.
	var top := rect.position + Vector2(rect.size.x * 0.43, 0.0)
	var bottom := rect.position + Vector2(rect.size.x * 0.49, rect.size.y)
	_stage.draw_line(top, bottom, FOLD_DARK, 5.0)
	_stage.draw_line(top + Vector2(4.0, 0.0), bottom + Vector2(4.0, 0.0), FOLD_LIT, 2.0)
