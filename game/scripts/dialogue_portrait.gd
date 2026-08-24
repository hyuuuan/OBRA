class_name DialoguePortrait
extends Control
## The speaker, big, standing behind the dialogue box.
##
## THIS IS WHAT THE CAMERA PUSH-IN COULD NOT DO. Zooming the world camera makes the
## speaker slightly larger and still forty pixels tall, still side-on, still with their
## back half behind a terrace. What a player needs while someone talks is a FACE, and every
## game that leans on dialogue solves it the same way: a bust of the speaker, drawn at a
## size the in-game sprite never reaches, standing behind the text.
##
## HALF THE BODY, ABOVE THE BOX. Head, shoulders and hands, cut at the hip and standing on
## the box's top rail -- the two read as one object, a face with its words underneath.
##
## A full figure was tried and is wrong for this arrangement: standing someone at the
## bottom of the screen puts their head in the middle of it, which is exactly where the
## reader's eye travels between the portrait and the text. Cutting at the hip lifts the
## face to the top of the screen and leaves that path clear. The cut line has the box's own
## rail to sit on, which is what a bust needs and what it did not have when the box was
## beside it.

## Of the apo's 106-row frame: head, shoulders and hands, cut at the hip.
const BUST_ROWS := 68
const SOURCE_WIDTH := 80
## How tall the bust stands on screen. Everything else is derived, so the portrait scales
## by whole pixels and never lands the sprite on a half.
const HEIGHT := 408.0
## How far the bust's cut edge sinks behind the box's top rail, so it stands ON the box
## rather than balancing above it.
const OVERLAP := 18.0

const APO_SHEET := preload("res://assets/characters/apo/apo_turnaround.png")

var _apo: TextureRect
var _lolo: TextureRect
var _lolo_viewport: SubViewport


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	modulate.a = 0.0

	# Frame 0 of the turnaround is the only front-facing view of the apo in the game, and
	# a portrait that looks past the player rather than at them is a portrait of someone
	# ignoring you.
	var bust := AtlasTexture.new()
	bust.atlas = APO_SHEET
	bust.region = Rect2(0.0, 0.0, float(SOURCE_WIDTH), float(BUST_ROWS))
	_apo = TextureRect.new()
	_apo.name = "Apo"
	_apo.texture = bust
	_apo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_apo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_apo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apo.visible = false
	add_child(_apo)

	# Lolo has no design, so his portrait is the same placeholder that draws him in the
	# world -- but RENDERED THROUGH A SMALL VIEWPORT and then blown up with nearest
	# filtering, rather than drawn at portrait scale directly.
	#
	# Drawing him big draws him SMOOTH: his figure is circles and arcs, and a 400-pixel
	# antialiased circle beside a 6-pixel-per-pixel sprite looks like a bug rather than a
	# placeholder. Rasterising him at sprite size first makes him chunky in the same way
	# everything around him is chunky. He is still a blob, and that is tracked as art the
	# team owes -- see CONTENT_NEEDED.md.
	_lolo_viewport = SubViewport.new()
	_lolo_viewport.name = "LoloViewport"
	_lolo_viewport.size = Vector2i(SOURCE_WIDTH, BUST_ROWS)
	_lolo_viewport.transparent_bg = true
	_lolo_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_lolo_viewport.disable_3d = true
	add_child(_lolo_viewport)

	var figure := Node2D.new()
	figure.name = "Figure"
	figure.set_script(load("res://scripts/lolo_figure.gd"))
	# Centred in the viewport, sitting a little low so the leaf above his head is not cut.
	# Lolo floats rather than stands, so he sits high in his frame with air beneath him --
	# a hovering companion planted on the ground would be a different character.
	# Sat low enough that the leaf above his head has room -- the viewport clips, and a
	# cropped leaf reads as a stem growing out of nothing.
	figure.position = Vector2(float(SOURCE_WIDTH) * 0.5, float(BUST_ROWS) * 0.62)
	figure.scale = Vector2(1.35, 1.35)
	_lolo_viewport.add_child(figure)

	_lolo = TextureRect.new()
	_lolo.name = "Lolo"
	_lolo.texture = _lolo_viewport.get_texture()
	_lolo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_lolo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lolo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_lolo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lolo.visible = false
	add_child(_lolo)


func _ready() -> void:
	get_viewport().size_changed.connect(_relayout)


func show_for(speaker: String) -> void:
	var is_lolo := speaker == Lolo.SPEAKER
	_lolo.visible = is_lolo
	_apo.visible = not is_lolo
	_relayout()
	if visible:
		return
	visible = true
	var appear := create_tween()
	appear.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	appear.tween_property(self, "modulate:a", 1.0, 0.18)


## Where the bust is standing. Both faces share it, so which one is showing does not
## change the answer.
func bust_rect() -> Rect2:
	return Rect2(_apo.position, _apo.size)


func hide_portrait() -> void:
	if not visible:
		return
	var fade := create_tween()
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(self, "modulate:a", 0.0, 0.18)
	fade.tween_callback(func() -> void: visible = false)


## Both portraits stand on the same baseline and at the same size, so a beat that changes
## speaker swaps the face without moving the head.
func _relayout() -> void:
	var view := get_viewport_rect().size
	var scale := maxf(1.0, floorf(HEIGHT / float(BUST_ROWS)))
	var width := float(SOURCE_WIDTH) * scale
	var height := float(BUST_ROWS) * scale
	# The box's own top rail is the shelf the bust stands on.
	var box_top := view.y - DialogueBox.LIFT - DialogueBox.BOX.y
	var rect := Rect2(
		Vector2(floorf((view.x - width) * 0.5), floorf(box_top + OVERLAP - height)),
		Vector2(width, height))

	_apo.position = rect.position
	_apo.size = rect.size
	_lolo.position = rect.position
	_lolo.size = rect.size
