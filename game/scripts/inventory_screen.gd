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
const ROSTER_SLOT := Vector2(80.0, 36.0)
const ROSTER_COLUMNS := 10

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
var _use_button: Button
## What is selected, as {"kind": "bag"|"found"|"drawn", "index"/"id"}.
var _chosen: Dictionary = {}
var _thumbnails: Dictionary = {}


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
	refresh()


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

	var centre := CenterContainer.new()
	centre.name = "Centre"
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(centre)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(1200.0, 0.0)
	centre.add_child(panel)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override(&"separation", 14)
	panel.add_child(column)

	var title := Label.new()
	title.name = "Title"
	title.theme_type_variation = &"ScreenTitle"
	title.text = "YOUR BAG"
	column.add_child(title)
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

	_build_bag(left)
	_build_found(left)
	_build_roster(left)
	_build_detail(body)

	column.add_child(HSeparator.new())
	var footer := Label.new()
	footer.name = "Footer"
	footer.theme_type_variation = &"HudCaption"
	footer.add_theme_color_override(&"font_color", UISkin.MUTED)
	footer.text = "%s to close" % ControlsKeys.keys_for("inventory_open")
	column.add_child(footer)


func _heading(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"HudCaption"
	label.add_theme_color_override(&"font_color", UISkin.GOLD)
	label.text = text
	parent.add_child(label)
	return label


func _build_bag(parent: Control) -> void:
	_heading(parent, "THE BAG")
	var row := HBoxContainer.new()
	row.name = "Bag"
	row.add_theme_constant_override(&"separation", 8)
	parent.add_child(row)
	for index in range(6):
		var button := _slot_button(BAG_SLOT)
		button.pressed.connect(_choose_bag.bind(index))
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
	_heading(parent, "FOUND")
	var row := HBoxContainer.new()
	row.name = "Found"
	row.add_theme_constant_override(&"separation", 8)
	parent.add_child(row)
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
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 12)
	parent.add_child(head)
	_heading(head, "DRAWN")
	_roster_count = Label.new()
	_roster_count.theme_type_variation = &"HudCaption"
	_roster_count.add_theme_color_override(&"font_color", UISkin.MUTED)
	head.add_child(_roster_count)

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
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		parent.add_child(row)
		var name_label := Label.new()
		name_label.text = String(spec["title"])
		name_label.theme_type_variation = &"HudCaption"
		name_label.add_theme_color_override(&"font_color", UISkin.MUTED)
		row.add_child(name_label)
		var count := Label.new()
		count.name = "%sCount" % String(spec["role"])
		count.theme_type_variation = &"HudCaption"
		count.add_theme_color_override(&"font_color", UISkin.MUTED)
		row.add_child(count)
		_band_counts[String(spec["role"])] = count

		var grid := GridContainer.new()
		grid.name = "%sGrid" % String(spec["role"])
		grid.columns = ROSTER_COLUMNS
		grid.add_theme_constant_override(&"h_separation", 6)
		grid.add_theme_constant_override(&"v_separation", 4)
		parent.add_child(grid)
		_band_grids[String(spec["role"])] = grid


func _build_detail(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "Detail"
	panel.custom_minimum_size = Vector2(268.0, 0.0)
	panel.add_theme_stylebox_override(&"panel", UISkin.well())
	parent.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	panel.add_child(column)

	_detail_art = TextureRect.new()
	_detail_art.name = "Art"
	_detail_art.custom_minimum_size = Vector2(0.0, 168.0)
	_detail_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	column.add_child(_detail_art)

	_detail_title = Label.new()
	_detail_title.theme_type_variation = &"ScreenSubtitle"
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_detail_title)

	_detail_note = Label.new()
	_detail_note.theme_type_variation = &"HudCaption"
	_detail_note.add_theme_color_override(&"font_color", UISkin.MUTED)
	_detail_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_detail_note)

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
	return button


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


func _refresh_roster() -> void:
	var profile := get_node_or_null(^"/root/PlayerProfile")
	var drawn: Array = profile.call("get_drawn_classes") if profile != null else []
	var total: int = int(profile.call("roster_size")) if profile != null else 50
	_roster_count.text = "%d / %d" % [drawn.size(), total]
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
		_paint(button, owned, chosen)
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
	if kind.is_empty():
		_detail_art.texture = null
		_detail_title.text = "Nothing chosen"
		_detail_note.text = "Pick something to see what it is."
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
		_detail_note.text = "%s  ·  %s" % [_role_of(item.entity_id), _price_of(item)]
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
	_detail_note.text = "%s  ·  Drawn and recognised. Drawing it again is free." \
		% _role_of(class_id)


func _paint(button: Button, occupied: bool, chosen: bool) -> void:
	# The same factory the bottom strip uses. Two views of one bag that styled their slots
	# separately would drift the first time either was touched.
	for state in [&"normal", &"hover", &"pressed", &"disabled"]:
		button.add_theme_stylebox_override(state, UISkin.slot(occupied, chosen))
	button.modulate = Color(1.12, 1.12, 1.04) if chosen else Color.WHITE


# --- Choosing ------------------------------------------------------------------------

func _choose_bag(index: int) -> void:
	_chosen = {"kind": "bag", "index": index}
	refresh()


func _choose_found(id: String) -> void:
	if not _has_found(id):
		return
	_chosen = {"kind": "found", "id": id}
	refresh()


func _choose_drawn(id: String) -> void:
	_chosen = {"kind": "drawn", "id": id}
	refresh()


## Hand the slot back to the level, which decides what a slot DOES -- a tool goes into the
## hand and a prop goes into a placement, and that judgement already exists in one place.
func _use_chosen() -> void:
	if String(_chosen.get("kind", "")) != "bag":
		return
	var slot := int(_chosen.get("index", -1))
	close()
	slot_activated.emit(slot)


# --- Reading -------------------------------------------------------------------------

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
		"flower_1":
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
