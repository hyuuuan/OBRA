extends Control
## The ending, and the first thing in the game ever to call EndingResolver.
##
## The resolver has been complete and tested since it was written -- four endings,
## fixed precedence, a display-ready explain() -- and until now its only caller was a
## test. This is a full scene rather than an overlay because the ending belongs to the
## RUN and not to a level: it reads only the profile, needs no level state, reaches
## the player through the existing pixel wipe, and is what Level 5 will show when it
## exists.
##
## It shows the inputs beside the verdict. An ending that just names itself invites
## "why that one"; showing the diversity, the redraw rate and the routes answers it,
## and doubles as a readable summary of the save file during a defence.

@onready var _title: Label = $Panel/VBox/Title
@onready var _ending_label: Label = $Panel/VBox/EndingName
@onready var _rows: VBoxContainer = $Panel/VBox/Rows
@onready var _continue_button: Button = $Panel/VBox/ContinueButton


func _ready() -> void:
	_continue_button.pressed.connect(_on_continue)
	_continue_button.grab_focus()
	_render(EndingResolver.explain(get_node_or_null(^"/root/PlayerProfile")))


func _render(payload: Dictionary) -> void:
	_title.text = "YOUR ENDING"
	_ending_label.text = String(payload.get("title", "")).to_upper()

	var diversity := int(payload.get("class_diversity", 0))
	var roster := maxi(1, int(payload.get("roster_size", 1)))
	_add_row("Classes drawn", "%d of %d" % [diversity, roster])
	_add_row("Redraw rate", "%d%%" % int(round(float(payload.get("redraw_rate", 0.0)) * 100.0)))
	_add_row("Flowers found", str(int(payload.get("collectibles", 0))))

	var routes: Dictionary = payload.get("route_counts", {})
	var parts: Array[String] = []
	for route: Variant in routes.keys():
		if int(routes[route]) > 0:
			parts.append("%s %d" % [String(route).capitalize(), int(routes[route])])
	_add_row("Routes taken", "  ".join(parts) if parts.size() > 0 else "none yet")


func _add_row(caption: String, value: String) -> void:
	var row := HBoxContainer.new()
	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption_label)
	var value_label := Label.new()
	value_label.text = value
	value_label.theme_type_variation = &"ScreenSubtitle"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	_rows.add_child(row)


## Resolved through the tree rather than by the autoload's global name, so this script
## still compiles when something loads it before the autoloads register -- a scene
## generator, a tool script, an editor import. The same reason draw_panel.gd does it.
func _on_continue() -> void:
	var manager := get_node_or_null(^"/root/LevelManager")
	if manager != null:
		manager.return_to_selector()
