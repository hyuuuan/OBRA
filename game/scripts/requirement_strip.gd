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
##   T1  the tags, named, and what each of them asks the drawing to do
##   T2  the tags, plus which of the player's own drawings would qualify
##   T3  the same, plus a note that anything from the other paths will now be taken

const TIER_HIDDEN := 0
const TIER_TAGS := 1
const TIER_OWN_CLASSES := 2
const TIER_WIDENED := 3

var _root: VBoxContainer
var _tag_line: Label
var _gloss_line: Label
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
	# IT GROWS UPWARD, off a fixed bottom edge. As a plain child at the origin the panel
	# grew DOWN by whatever its content needed, so the strip's height was decided by how
	# many lines it happened to be printing -- and the keybind row underneath is at a fixed
	# place. Three lines cleared it, four did not: adding the gloss line put the panel's
	# bottom border straight through the action prompts.
	#
	# That is the same collision the level's offset_top was hand-tuned to avoid once
	# already. Tuning it again would just move the next line's collision somewhere else, so
	# the bottom is anchored instead and every line the strip gains from here goes up into
	# empty sky.
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
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

	# WHAT THE TAG MEANS. "NEEDS SPAN" names the problem without describing it, and the
	# tags are this game's own invention -- nobody arrives knowing them. The gloss is the
	# same instruction in the player's words, and it still names no class, so the puzzle
	# keeps all four of its answers. Quieter than the tag line on purpose: the tag is the
	# thing to remember, this is the thing to read once.
	_gloss_line = Label.new()
	_gloss_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gloss_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gloss_line.custom_minimum_size = Vector2(430.0, 0.0)
	_gloss_line.add_theme_color_override("font_color", Color(0.93, 0.95, 0.88))
	_gloss_line.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.04))
	_gloss_line.add_theme_constant_override("outline_size", 4)
	_root.add_child(_gloss_line)

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
## `required` is a list of tag ids; `owned` is the player's qualifying classes; `match` is
## the spec's own combining rule, which the gloss line reads so it can join with the right
## word. Defaulted to "all" to match LevelDirector, so a caller that does not pass it gets
## the strict reading rather than the generous one.
func show_requirements(required: Array, tier: int, owned: PackedStringArray = PackedStringArray(),
		match: String = "all") -> void:
	if required.is_empty() or tier < TIER_TAGS:
		clear()
		return
	visible = true
	_tag_line.text = "NEEDS  %s" % _join_tags(required)
	_gloss_line.text = _join_glosses(required, match)
	_gloss_line.visible = not _gloss_line.text.is_empty()

	if tier >= TIER_OWN_CLASSES and not owned.is_empty():
		# Their own drawings, not a hint list. A player who has never drawn a spider is
		# not told a spider would work -- that is the T3 job, and even then the game
		# widens what it ACCEPTS rather than telling them what to draw.
		_own_line.text = "you have drawn:  %s" % _join_names(owned)
		_own_line.visible = true
	elif tier >= TIER_OWN_CLASSES:
		# A DEAD END IS NOT A HINT. "nothing you have drawn yet fits this" is true and
		# useless: it tells a player who is already stuck that they are stuck. The tier
		# exists to open something, so it says what to do with the canvas instead -- still
		# without naming a class, which is the T3 job and even then only by widening what
		# is accepted.
		_own_line.text = "nothing you have drawn yet fits this  —  draw something new"
		_own_line.visible = true
	else:
		_own_line.visible = false

	if tier >= TIER_WIDENED:
		_tag_line.text += "   ·   any path will do now"


func clear() -> void:
	visible = false
	_tag_line.text = ""
	_gloss_line.text = ""
	_own_line.text = ""


## WHAT A REQUIREMENT SAYS, IN ONE PLACE, so nothing can say it differently.
##
## The strip is no longer the only thing that has to put a requirement into words: the
## route buttons at a dialogue node now carry the requirement of the route they commit to.
## Those two MUST agree -- the whole complaint this was written for is a player choosing
## "Let us put it back" and then being told, by the strip, that the level wants something
## else. Both read this, so there is one wording and it comes from the level's own data.
static func phrase(required: Array, match: String = "all") -> String:
	if required.is_empty():
		return ""
	var tree := Engine.get_main_loop() as SceneTree
	var tags: Node = tree.root.get_node_or_null(^"/root/AbilityTags") if tree != null else null
	var names := PackedStringArray()
	var glosses := PackedStringArray()
	for tag_value: Variant in required:
		var tag := String(tag_value)
		names.append(String(tags.call("display_name", tag)).to_upper()
			if tags != null else tag.to_upper())
		if tags == null:
			continue
		var text := String(tags.call("gloss", tag))
		if not text.is_empty():
			glosses.append(text)
	# The joining word is the spec's own match rule and not a house style: Node 1's
	# Pragmatist route asks for leap OR climb, and printing that as a list of demands makes
	# the most generous requirement in the level read as the strictest.
	var joiner := "  or  " if match == "any" else "  and  "
	var head := "NEEDS  %s" % joiner.join(names)
	return head if glosses.is_empty() else "%s\n%s" % [head, joiner.join(glosses)]


func _join_tags(required: Array) -> String:
	var parts := PackedStringArray()
	for tag_value: Variant in required:
		var tag := String(tag_value)
		parts.append(String(_tags.call("display_name", tag)).to_upper()
			if _tags != null else tag.to_upper())
	return "  /  ".join(parts)


## One gloss per required tag, in the order they are asked for. Tags that carry no gloss
## are skipped rather than printed blank, and a requirement whose tags all lack one leaves
## the line hidden -- the strip is then exactly what it was before this existed.
func _join_glosses(required: Array, match: String) -> String:
	if _tags == null:
		return ""
	var parts := PackedStringArray()
	for tag_value: Variant in required:
		var text := String(_tags.call("gloss", String(tag_value)))
		if not text.is_empty():
			parts.append(text)
	# The joining word is the spec's match rule and not a house style. Node 1's Pragmatist
	# route asks for leap OR climb and the pre-choice union asks for any of all three
	# routes' tags; printing those as a list of demands would make the two most generous
	# requirements in the level read as the strictest.
	return ("  or  " if match == "any" else "  and  ").join(parts)


func _join_names(ids: PackedStringArray) -> String:
	var parts := PackedStringArray()
	for id in ids:
		parts.append(id.replace("_", " "))
	return ", ".join(parts)
