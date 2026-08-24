extends ModalOverlay
## The keybind reference. Until now the game never told the player that R opens the
## drawing panel, that E picks things up, or that 1-6 are the inventory.
##
## Labels are authored in config/controls.json; the KEYS are read out of the live
## InputMap when the screen opens. That split is the point: a rebinding in
## project.godot changes what this screen says with no edit here, so it cannot drift
## into telling the player something that stopped being true. It is also why the
## rotate keys moving off E needed no change to this file.

const CONFIG_PATH := "res://config/controls.json"

@onready var _rows: VBoxContainer = $Root/Center/Panel/VBox/Rows
@onready var _back_button: Button = $Root/Center/Panel/VBox/BackButton

var _built := false


func _ready() -> void:
	super()
	_back_button.pressed.connect(close)


func _on_opened() -> void:
	if not _built:
		_build()
		_built = true


func _build() -> void:
	for child in _rows.get_children():
		child.queue_free()
	var text := FileAccess.get_file_as_string(CONFIG_PATH)
	if text.is_empty():
		push_warning("ControlsOverlay: could not read %s" % CONFIG_PATH)
		return
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("ControlsOverlay: %s is not a JSON object" % CONFIG_PATH)
		return

	var current_group := ""
	for row_value: Variant in (parsed as Dictionary).get("rows", []):
		var row: Dictionary = row_value
		var action := String(row.get("action", ""))
		# A row may name its keys outright instead of an action. The mouse does the three
		# things placement is made of -- aim, rotate, set down -- and taking a drawing back
		# is a right-click, none of which are in the InputMap and none of which this screen
		# could therefore say. A player who cannot undo a placement has to be TOLD they can.
		var literal_keys := String(row.get("keys", ""))
		# An action the InputMap does not have is skipped rather than shown with a
		# blank key -- a row that names nothing is worse than no row.
		if literal_keys.is_empty() and (action.is_empty() or not InputMap.has_action(action)):
			continue
		var group := String(row.get("group", ""))
		if group != current_group:
			current_group = group
			_rows.add_child(_group_heading(group))
		_rows.add_child(_control_row(
			String(row.get("label", action)), action, String(row.get("through", "")), literal_keys))


func _group_heading(text: String) -> Control:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"HudCaption"
	return label


func _control_row(
	label_text: String, action: String, through: String = "", literal_keys: String = ""
) -> Control:
	# This screen is a TABLE, and it is the one place in the game that has to fit twenty
	# rows on screen at once. At body size those rows are eight hundred pixels of list and
	# the last of them falls off the bottom, so it is set a step down -- and the two columns
	# are given a gap, because "…one already down" and "Right click" were touching.
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 36)
	var name_label := Label.new()
	name_label.text = label_text
	name_label.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var keys := Label.new()
	# A row may cover a contiguous block of actions -- the six inventory slots are one
	# idea to the player, not six rows. Showing only the first key would have the
	# screen say "1" beside a label reading "slots".
	keys.text = literal_keys if not literal_keys.is_empty() else _keys_for(action)
	if literal_keys.is_empty() and not through.is_empty() and InputMap.has_action(through):
		keys.text = "%s  -  %s" % [_keys_for(action), _keys_for(through)]
	keys.theme_type_variation = &"HudValue"
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(keys)
	return row


## Every key bound to an action, as the player would name it.
##
## physical_keycode is what this project binds for letters, and it is a position on
## the keyboard rather than a character -- so it has to be translated through the
## active layout to be shown, or a non-QWERTY player is told to press the wrong key.
func _keys_for(action: String) -> String:
	var names: Array[String] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			var label := ""
			if key.physical_keycode != 0:
				label = OS.get_keycode_string(_layout_keycode(key.physical_keycode))
			elif key.keycode != 0:
				label = OS.get_keycode_string(key.keycode)
			if not label.is_empty() and not names.has(label):
				names.append(label)
		elif event is InputEventMouseButton:
			names.append("Mouse %d" % (event as InputEventMouseButton).button_index)
	return "  /  ".join(names) if names.size() > 0 else "unbound"


## A physical keycode translated through the active keyboard layout, falling back to
## the physical code itself where that is not available.
##
## Physical codes are US-layout positions, so the fallback names the right key for
## most players and the wrong one only for a player on a non-QWERTY layout -- which
## is the same thing every hardcoded keybind list does, and better than the headless
## display server logging an error per row.
func _layout_keycode(physical: int) -> int:
	if DisplayServer.get_name() == "headless":
		return physical
	return DisplayServer.keyboard_get_keycode_from_physical(physical)
