class_name RequirementStrip
extends Control
## What the obstacle in front of you needs, in the only vocabulary the game is allowed to
## use for it: ability tags.
##
## THE RULE THIS EXISTS TO HOLD: never name a class. "Needs something that can SPAN" is a
## puzzle with four answers and room to be clever; "draw a ladder" is a spelling test. The
## strip therefore prints tags, and the only classes it will ever show are ones the player
## has already drawn and had accepted -- their own vocabulary reflected back, not a
## catalogue of what exists.
##
## It builds its own children rather than living in a .tscn. Two reasons: generating scene
## files by hand has bitten this project repeatedly (a saved scene with a silently missing
## script), and a strip whose whole content is dynamic has nothing worth authoring in a
## scene anyway.
##
## Tiers, matching level_director.gd:
##   T0  hidden. The player has not asked and has not struggled
##   T1  the tags, named
##   T2  the tags, plus which of the player's own drawings would qualify
##   T3  the same, plus a note that anything from the other paths will now be taken

const TIER_HIDDEN := 0
const TIER_TAGS := 1
const TIER_OWN_CLASSES := 2
const TIER_WIDENED := 3

var _root: VBoxContainer
var _tag_line: Label
var _own_line: Label
var _tags: Node


func _ready() -> void:
	_tags = get_node_or_null(^"/root/AbilityTags")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Shrink to the text: a fixed-width panel would sit as a wide empty slab whenever the
	# requirement is a single short tag, which is most of Beat 0.
	set_h_size_flags(Control.SIZE_SHRINK_BEGIN)
	_build()
	visible = false


## IT NEEDS ITS OWN BACKGROUND, and this is the whole reason the visual pass existed.
## The first version was bare HudHint labels, which is what the keybind strip uses -- and
## that strip sits over a dark paddy at the very bottom of the screen. This one sits over
## whatever terrain the obstacle happens to be on, and at Beat 0 that is a bright yellow
## rice field: grey text on it was legible in a screenshot only if you already knew what
## it said. A tutorial's one instruction cannot be something you have to hunt for.
func _build() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	_root = VBoxContainer.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_theme_constant_override("separation", 3)
	panel.add_child(_root)

	# Bright enough to carry over the brightest terrain in the level, and the accent
	# yellow the rest of the UI already uses for "this is the thing to look at".
	_tag_line = Label.new()
	_tag_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag_line.add_theme_color_override("font_color", Color(1.0, 0.94, 0.42))
	_tag_line.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.04))
	_tag_line.add_theme_constant_override("outline_size", 5)
	_root.add_child(_tag_line)

	_own_line = Label.new()
	_own_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_own_line.add_theme_color_override("font_color", Color(0.84, 0.89, 0.78))
	_own_line.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.04))
	_own_line.add_theme_constant_override("outline_size", 4)
	_root.add_child(_own_line)


## Matches the dialogue overlay's panel so the strip reads as the same UI family rather
## than as debug text that was left on.
func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.12, 0.075, 0.92)
	style.border_color = Color(0.52, 0.67, 0.22, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


## Called by the level whenever the obstacle, its requirements, or the tier changes.
## `required` is a list of tag ids; `owned` is the player's qualifying classes.
func show_requirements(required: Array, tier: int, owned: PackedStringArray = PackedStringArray()) -> void:
	if required.is_empty() or tier < TIER_TAGS:
		clear()
		return
	visible = true
	_tag_line.text = "NEEDS  %s" % _join_tags(required)

	if tier >= TIER_OWN_CLASSES and not owned.is_empty():
		# Their own drawings, not a hint list. A player who has never drawn a spider is
		# not told a spider would work -- that is the T3 job, and even then the game
		# widens what it ACCEPTS rather than telling them what to draw.
		_own_line.text = "you have drawn:  %s" % _join_names(owned)
		_own_line.visible = true
	elif tier >= TIER_OWN_CLASSES:
		_own_line.text = "nothing you have drawn yet fits this"
		_own_line.visible = true
	else:
		_own_line.visible = false

	if tier >= TIER_WIDENED:
		_tag_line.text += "   ·   any path will do now"


func clear() -> void:
	visible = false
	_tag_line.text = ""
	_own_line.text = ""


func _join_tags(required: Array) -> String:
	var parts := PackedStringArray()
	for tag_value: Variant in required:
		var tag := String(tag_value)
		parts.append(String(_tags.call("display_name", tag)).to_upper()
			if _tags != null else tag.to_upper())
	return "  /  ".join(parts)


func _join_names(ids: PackedStringArray) -> String:
	var parts := PackedStringArray()
	for id in ids:
		parts.append(id.replace("_", " "))
	return ", ".join(parts)
