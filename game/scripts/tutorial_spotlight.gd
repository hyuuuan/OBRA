class_name TutorialSpotlight
extends CanvasLayer
## THE ONE PLACE A LESSON APPEARS: the screen goes dim, the thing it is about stays lit,
## and a card shows the key or the mouse doing it.
##
## Kent, after playing Level 1: "i cant seem to experience the tutorial vibe since its just
## knowledge dumping at this point, i feel so overwhelmed, why are the instructions popping
## everywhere ... there should just be a single or two places that prompts pop up ... when
## there is instructions it is better that the screen goes dim and then that part is
## highlighted so that it will be read by everybody."
##
## What it replaced. Lessons went to EIGHT places: a bubble beside the draw button, the bag,
## the ink gauge, the morph card, the requirement strip, the revert, climb and use prompts,
## and a bar riding over the apo's head. Each was right about where it pointed, and together
## they were a screen that kept putting words in a different corner, never asking for
## attention and never getting it.
##
## So now there are two places. The CARD stands top-centre or bottom-centre -- whichever half
## of the screen the lit thing is not in -- and nowhere else; Lolo's own lines stay over the
## apo's head on the hint bar, which stands down while a card is up. And the screen dims
## around a hole cut where the lesson is, a gold ring leaving its edge, an arrow from the
## card's side bobbing at it: a player who never reads a word still sees where to look and
## what to press.
##
## TWO KINDS OF LESSON, because "do it" and "look at this" want opposite things:
##
##   do    The world keeps running and nothing is taken from the player. The card goes the
##         moment they press what it shows -- and that press still does its job, so the
##         lesson ENDS in the thing it taught (D walks, the click sets the drawing down).
##         Anything else they press, after a moment's grace, also lets it go: a player who
##         would rather get on is not held.
##   look  The world stops (through the derived pause state, like every modal here), because
##         it is about a reading that is moving -- the drawing's clock, the ink -- and
##         explaining a ten-second clock while it runs costs the player the drawing. Any key
##         or click after a beat dismisses it, and that press is spent on the card.
##
## ⚠ NOBODY AT THE KEYBOARD. A run with the dialogue box on auto-dismiss is a run nobody is
## playing -- every headless suite -- and a lesson that stopped the world until a key was
## pressed would hang it exactly the way an unanswered conversation used to. There the card
## still goes up (a probe can measure it), but it stops nothing, takes no input and goes by
## itself.

signal finished(lesson_id: String, how: String)
## The player asked to skip the rest of the tutorial, from the card's SKIP or its key. The
## director answers it (TutorialDirector.skip_rest); the card goes either way.
signal skip_requested

## controls_overlay.gd declares no class_name; its static key lookup is reached through the script.
const ControlsKeys = preload("res://scripts/controls_overlay.gd")

const GROUP := &"tutorial_spotlight"
const SHADER := preload("res://shaders/tutorial_spotlight.gdshader")
## Above the HUD (5), Lolo's box (8) and the drawing panel (10) -- a lesson about the canvas
## has to dim the canvas -- and below the pause menu (50), which must still open over it.
const LAYER := 45
const DIM := 0.74
## From the top of the screen to the card: clear of the quest card, which sits there -- at 72
## the card's top edge sat on the objective's frame. Measured off the quest card's own bottom.
const TOP_GAP := ObjectiveBanner.BOTTOM + 10.0
## From the bottom of the screen.
const EDGE_GAP := 52.0
## From the lit box when the card stands beside it, and the smallest it may be drawn there.
const BESIDE_GAP := 20.0
const MIN_BESIDE_SCALE := 0.72
const HOLE_PAD := 12.0
const IRIS_SEC := 0.42
const FADE_SEC := 0.3
const CLOSE_SEC := 0.32
const DONE_SEC := 0.55
const LOOK_MIN_SEC := 0.6
const GRACE_SEC := 2.0
const PULSE_SEC := 1.3
## How long a card stays up when nobody is there to press anything.
const AUTO_SEC := 2.5
## How long a STRICT card is up before it takes a press: the press that finished the card before
## it must not be able to finish this one too.
const STRICT_MIN_SEC := 0.3
const CAPTION_FONT := 26
## The least time between two moves of the card, so something going up and down across the
## line between its two places does not make it flicker from one to the other.
const MOVE_AFTER_SEC := 0.6
## How quickly it slides to the other place, per second.
const SLIDE_RATE := 14.0

## SMOOTH, LIKE THE HOME SCREEN'S BUTTONS. Kent: "lets make the tutorials smooth like the
## buttons, dimming of bg, and like the smoothness of animations". The card's corners are
## round; the dim and the card fade on an ease, not a straight line; and the card rises from a
## little smaller, just overshooting, the way the bag opens -- and sinks a little as it goes.
## The rise ends inside IRIS_SEC, so the card stands where it will stay by the time the hole
## has closed on its target, which is when the probes measure it.
const CARD_RADIUS := 16
const POP_FROM := 0.9
const POP_SEC := 0.36
const SINK_TO := 0.96
## The arrow comes in once the hole has closed, rather than appearing.
const ARROW_FADE_SEC := 0.25

## Read by UIRouter.refresh_pause through the modal_overlays group: true only while a
## `look` lesson is up and somebody is there to dismiss it -- or a run of cards is held (`hold`).
var pauses_game := false:
	get:
		return pauses_game or _held

var _open := false
var _lesson: Dictionary = {}
var _target := Callable()
var _had_target := false
var _lost_for := 0.0
var _age := 0.0
var _closing := -1.0
var _close_length := CLOSE_SEC
var _auto := false
var _hole := Rect2()
enum Place { TOP, BOTTOM, LEFT, RIGHT }
var _place := Place.TOP
## Below 1 only beside a tall box, where the full card would not fit between it and the edge.
var _card_scale := 1.0
## What a `do` card also keeps clear of, every frame: the apo, who is still being moved.
var _avoid := Callable()
## When the card last went to the other of its two places, and where it is going.
var _moved_at := -10.0
var _card_goal := Vector2.ZERO
## ⚠ THE FIRST FRAME AFTER A CARD GOES UP IS NOT COUNTED. It is the frame that first draws the
## dim, and its shader compiles then: that frame's delta came in at a seventh of a second and
## the fade began most of the way in -- a card that popped rather than rose.
var _first_frame := false
## A RUN OF CARDS, HELD. Payyo teaches every card the moment it opens, one after another, and
## the player must not be able to act between them: a card's own pause is released the moment
## it starts to leave, so the world ran for the length of every fade. While held, this counts as
## open -- the tree stays paused and the hint bar waits -- whether or not a card is up.
var _held := false
## In a run of cards (TutorialDirector.teach_the_door): a card that goes leaves the dim
## up, so the tick on a card done can be seen without the screen flashing back between cards.
var _in_run := false
## The card took over from one still up or leaving, so the dim stays where it is and the hole
## travels from where it was rather than closing in from past the screen.
var _chained := false
var _iris_from := Rect2()
var _fade_from := 0.0
var _fade := 0.0

var _root: Control
var _dim: ColorRect
var _material: ShaderMaterial
var _pointer: Control
## What is placed and what rises: the card's own scale is the smaller size it takes beside a
## tall box, and the two would fight over one property.
var _holder: Control
var _card: PanelContainer
var _visual: LessonVisual
var _caption: Label
var _skip: Button


func _ready() -> void:
	layer = LAYER
	# Must run while the tree is paused: a `look` card is what paused it, and a lesson in the
	# drawing panel is shown over a tree the panel paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(ModalOverlay.GROUP)
	add_to_group(GROUP)
	_build()
	visible = false
	set_process(false)


func _build() -> void:
	_root = Control.new()
	_root.name = "Spotlight"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# IGNORE, not STOP. The input a `do` lesson teaches has to reach what is under the dim --
	# the draw button through the hole, the canvas, the world -- so nothing here catches the
	# mouse; `_input` decides what a press means while a card is up.
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color.WHITE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter(&"dim", DIM)
	_material.set_shader_parameter(&"ring_color", UISkin.GOLD)
	_dim.material = _material
	_root.add_child(_dim)

	_pointer = Control.new()
	_pointer.name = "Pointer"
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pointer.draw.connect(_draw_pointer)
	_root.add_child(_pointer)

	_holder = Control.new()
	_holder.name = "CardHolder"
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_holder)

	_card = PanelContainer.new()
	_card.name = "LessonCard"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override(&"panel", UISkin.rounded(UISkin.frame(18.0, 12.0), CARD_RADIUS))
	_holder.add_child(_card)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 6)
	_card.add_child(column)

	_visual = LessonVisual.new()
	_visual.name = "Picture"
	column.add_child(_visual)

	_caption = Label.new()
	_caption.name = "Caption"
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.custom_minimum_size = Vector2(LessonVisual.SIZE.x, 0.0)
	_caption.add_theme_font_size_override(&"font_size", CAPTION_FONT)
	_caption.add_theme_color_override(&"font_color", UISkin.CREAM_TEXT)
	column.add_child(_caption)

	# SKIP, for a player who already knows how to play. Kent: "There should be a skip button for
	# tutorials that the players can use". In the card's own corner, so it stands beside every
	# lesson it would end, drawn as the HUD draws a key (ActionPromptHUD.make_key_chip) with the
	# key read off the InputMap. It ends every lesson left in the level, not just this card.
	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(footer)
	_skip = ActionPromptHUD.make_key_chip(&"SkipTutorial",
		[ControlsKeys.key_cap_for("skip_tutorial")], "SKIP TUTORIAL", UISkin.MUTED)
	# STOP so the cursor and the hover answer it; the click itself is taken in `_input`, which
	# runs before the GUI does and would otherwise spend it on the card.
	_skip.mouse_filter = Control.MOUSE_FILTER_STOP
	_skip.tooltip_text = "Skip the rest of the tutorial"
	_skip.pressed.connect(_ask_to_skip)
	footer.add_child(_skip)


## Put a lesson up. `lesson` is the director's resolved form of a `tutorial.json` entry:
## id, mode ("do" or "look"), visual, caps, caption, seconds, actions, mouse. `target`
## answers where the lit box is, every frame, as a screen Rect2 -- empty for none.
##
## Presented while another card is up or leaving, it takes that card's place: the dim stays,
## the hole slides from the last thing lit to this one, and the new card fades in where it
## stands. That is what a run of cards (`hold`) looks like; a lone card is unchanged.
func present(lesson: Dictionary, target: Callable, avoid: Callable = Callable()) -> void:
	_chained = _open
	_iris_from = _hole if _chained and _hole.has_area() else _screen().grow(240.0)
	_fade_from = _fade if _chained else 0.0
	_lesson = lesson
	_target = target
	_avoid = avoid
	_moved_at = -10.0
	_age = 0.0
	_first_frame = true
	_closing = -1.0
	_lost_for = 0.0
	# A run of cards says for itself, decided once when it began (TutorialDirector._entry_auto).
	_auto = bool(lesson["auto"]) if lesson.has("auto") else _nobody_at_the_keys()
	var look := _mode() == "look"
	pauses_game = look and not _auto
	# The little blinking mouse says "click to go on". On a strict card that is only true of one
	# with nothing of its own to press; on the rest the picture already shows what to press.
	var click_goes_on := look and not _auto and not (_strict() and _has_input())
	_visual.show_kind(String(lesson.get("visual", "keys")),
		PackedStringArray(lesson.get("caps", PackedStringArray())), click_goes_on)
	var caption := String(lesson.get("caption", ""))
	_caption.text = caption
	_caption.visible = not caption.is_empty()
	_open = true
	visible = true
	set_process(true)
	_card.reset_size()
	var rect := _target_rect()
	_had_target = rect.has_area()
	_card_scale = 1.0
	_place = _choose_place(rect, _card.get_combined_minimum_size())
	_card.scale = Vector2.ONE * _card_scale
	_hole = _iris_from
	_set_fade(_fade_from)
	_holder.modulate.a = 0.0 if _chained else 1.0
	_refresh(rect, 0.0)
	UIRouter.refresh_pause(get_tree())


## Up and asking for attention. Not while it fades: the moment it is closing it no longer
## holds the pause or the hint bar. A held run of cards is open the whole time (`hold`).
func is_open() -> bool:
	return is_showing() or _held


## A card is up and not leaving -- whatever the hold says.
func is_showing() -> bool:
	return _open and _closing < 0.0


## Hold the world still across a run of cards, or let it go. Not with nobody at the keys: a run
## that stopped the world there would hang the suite exactly as a look card would.
func hold(on: bool) -> void:
	_held = on and not _nobody_at_the_keys()
	UIRouter.refresh_pause(get_tree())


func is_holding() -> bool:
	return _held


## A run of cards is on: a card that goes leaves the dim up for the next.
func set_in_run(on: bool) -> void:
	_in_run = on


## STRICT: Kent, of Payyo's cards: "when the tutorial says press R, when i press another key, it
## just proceeds to the next one, it does not let me experience the tutorial". A strict card goes
## only when the player does what it shows -- its key, its click, its wheel -- or, for a `look` card
## about something to look at, a click or Enter; or when what it lights goes. Nothing times it
## out, no other key ends it, and SKIP TUTORIAL and Escape still work.
func _strict() -> bool:
	return bool(_lesson.get("strict", false))


func _has_input() -> bool:
	return not (_lesson.get("actions", []) as Array).is_empty() \
		or not (_lesson.get("mouse", []) as Array).is_empty()


## What a strict card goes on: its own input, or for a card with none, a click or Enter.
func _does_what_it_shows(event: InputEvent) -> bool:
	if _has_input():
		return TutorialSpotlight.matches(_lesson, event)
	var click := event as InputEventMouseButton
	if click != null:
		return click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	return event.is_action_pressed(&"ui_accept")


## Up at all, fading included -- what the director waits on before the next one.
func is_busy() -> bool:
	return _open


func lesson_id() -> String:
	return String(_lesson.get("id", "")) if _open else ""


func lesson_mode() -> String:
	return _mode() if _open else ""


func caption_text() -> String:
	return _caption.text if _open else ""


func visual_kind() -> String:
	return _visual.kind if _open else ""


func card_rect() -> Rect2:
	return _card.get_global_rect() if _open else Rect2()


## Where the card's SKIP is on screen; empty while no card is up.
func skip_rect() -> Rect2:
	return _skip.get_global_rect() if is_showing() and _skip.is_visible_in_tree() else Rect2()


func hole_rect() -> Rect2:
	return _hole if _open else Rect2()


func card_on_top() -> bool:
	return _place == Place.TOP


## Where the card stands: "top", "bottom", "left" or "right" of the lit box.
func card_place() -> String:
	return ["top", "bottom", "left", "right"][_place]


func is_auto() -> bool:
	return _auto


## Standing where it is going: risen, and not sliding between its two places.
func is_settled() -> bool:
	return _open and _age >= POP_SEC and _holder.position.distance_to(_card_goal) < 1.0


## The modal_overlays way of taking it down, which the probes that clear the screen use.
func close() -> void:
	finish("closed")


## Take the card down. `how` says why, for the director and for telemetry: "done" (they
## pressed what it showed), "seen" (a look card dismissed), "moved_on", "timeout", "gone"
## (what it pointed at went away), "auto", "skipped", "talked_over" (a story line began under a
## `do` card).
func finish(how: String) -> void:
	if not _open or _closing >= 0.0:
		return
	_closing = 0.0
	_close_length = DONE_SEC if how == "done" else CLOSE_SEC
	if how == "done":
		_visual.mark_done()
	# Released NOW, not when the fade ends: a `do` press is on its way to the world in this
	# same frame and has to find it running.
	pauses_game = false
	UIRouter.refresh_pause(get_tree())
	finished.emit(String(_lesson.get("id", "")), how)


func _process(delta: float) -> void:
	if not _open:
		return
	if _first_frame:
		_first_frame = false
		delta = 0.0
	_age += delta
	if _closing >= 0.0:
		_closing += delta
		var gone := _ease(clampf(_closing / _close_length, 0.0, 1.0))
		if _in_run:
			# Only the card goes; the dim waits for the next one.
			_holder.modulate.a = 1.0 - gone
		else:
			_set_fade(1.0 - gone)
		_holder.scale = Vector2.ONE * lerpf(1.0, SINK_TO, gone)
		_pointer.queue_redraw()
		if _closing >= _close_length:
			_teardown()
		return
	var fade_in := _ease_out(clampf(_age / FADE_SEC, 0.0, 1.0))
	_set_fade(lerpf(_fade_from, 1.0, fade_in))
	if _chained:
		_holder.modulate.a = fade_in
	# ⚠ A STORY LINE TAKES THE SCREEN FROM A `do` CARD. The world runs under one, so the apo can
	# walk into a beat with it still up -- in Payyo, the Jump card into Ang Hagdan's opening line --
	# and the story box (layer 8) was read through this card's dim for the whole conversation.
	# The director already keeps a card from starting over a line; this is the other direction.
	# Not on the canvas, whose card is about a modal that is meant to be up.
	if _mode() == "do" and String(_lesson.get("context", "world")) != "canvas" \
			and _someone_is_talking():
		finish("talked_over")
		return
	var rect := _target_rect()
	# What it pointed at is gone -- the placement ended, the prompt went away -- so the
	# lesson has nothing left to show. A frame or two of nothing is a layout settling.
	if _had_target and not rect.has_area():
		_lost_for += delta
		if _lost_for > 0.2:
			finish("gone")
			return
	else:
		_lost_for = 0.0
	_refresh(rect, delta)
	if _auto and _age >= float(_lesson.get("auto_seconds", AUTO_SEC)):
		finish("auto")
	elif _mode() == "do" and not _strict() and _age >= float(_lesson.get("seconds", 10.0)):
		finish("timeout")


func _input(event: InputEvent) -> void:
	if not _open or _closing >= 0.0:
		return
	if event is InputEventMouseMotion or event.is_echo() or not _is_press(event):
		return
	# ⚠ SKIP BEFORE ANYTHING ELSE. A `look` card spends every press on dismissing itself and a
	# `do` card hands presses on to the world, so a click on SKIP was never SKIP's: it dismissed
	# the one card, or set a drawing down behind it.
	if _is_skip(event):
		get_viewport().set_input_as_handled()
		_ask_to_skip()
		return
	if _strict() and not _auto:
		_strict_input(event)
		return
	# Escape is the router's. The pause menu opens over a card, and the card is still there
	# when it closes.
	if event.is_action_pressed(&"pause"):
		return
	if _mode() == "do":
		# NOT consumed: the press that ends a `do` lesson is the press it taught, and it goes
		# on to do it.
		if TutorialSpotlight.matches(_lesson, event):
			finish("done")
		elif _age >= GRACE_SEC and not _auto:
			finish("moved_on")
		return
	if _auto:
		return
	get_viewport().set_input_as_handled()
	var mouse := event as InputEventMouseButton
	var wheel := mouse != null and mouse.button_index in [MOUSE_BUTTON_WHEEL_UP,
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]
	if _age >= LOOK_MIN_SEC and not wheel:
		finish("seen")


## A strict card's press. The one it shows finishes it with a tick; anything else does not.
func _strict_input(event: InputEvent) -> void:
	var shows := _does_what_it_shows(event)
	# A `do` card with nothing to press -- Paint -- goes when what it lights goes (`gone`): a click
	# is how she draws, and must not end "Done? Press Paint" before she has.
	if _mode() == "do" and not _has_input():
		shows = false
	var done := _age >= STRICT_MIN_SEC and shows
	# Escape stays the router's: on the card that teaches it, it also opens the real pause menu,
	# which is the list of controls the card is about.
	if event.is_action_pressed(&"pause"):
		if done:
			finish("done")
		return
	# Under a `look` card the world is held, and every press is spent on the card. A `do` card's
	# own press goes on to do its job -- D walks, R opens the canvas. In the run at the door the
	# other presses are spent too, so nothing opens behind a card about something else; in its
	# moment the world goes on working under a `do` card, which only waits.
	if _mode() == "look" or (_in_run and not done):
		get_viewport().set_input_as_handled()
	if done:
		finish("done")


## Whether `event` is one of the inputs `lesson` teaches. Static so the director can ask the
## same question of a press made while no card is up -- a player who has already done the
## thing is not taught it.
static func matches(lesson: Dictionary, event: InputEvent) -> bool:
	for action_value: Variant in lesson.get("actions", []):
		var action := StringName(String(action_value))
		if InputMap.has_action(action) and event.is_action_pressed(action):
			return true
	var mouse_inputs: Array = lesson.get("mouse", [])
	if mouse_inputs.is_empty():
		return false
	if event is InputEventMagnifyGesture:
		return mouse_inputs.has("shift_wheel")
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return false
	var held := click.shift_pressed or click.ctrl_pressed
	var turning := click.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
	var sideways := click.button_index in [MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]
	for value: Variant in mouse_inputs:
		match String(value):
			"left":
				if click.button_index == MOUSE_BUTTON_LEFT and not held:
					return true
			"right":
				if click.button_index == MOUSE_BUTTON_RIGHT:
					return true
			"wheel":
				if turning and not held:
					return true
			"shift_wheel":
				if (turning or sideways) and held:
					return true
	return false


func _is_skip(event: InputEvent) -> bool:
	if InputMap.has_action(&"skip_tutorial") and event.is_action_pressed(&"skip_tutorial"):
		return true
	var click := event as InputEventMouseButton
	return click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT \
		and skip_rect().has_point(click.position)


func _ask_to_skip() -> void:
	if not is_showing():
		return
	skip_requested.emit()
	finish("skipped")


func _is_press(event: InputEvent) -> bool:
	# An action event too: what a remapped controller layer or a probe sends.
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventAction \
			or event is InputEventJoypadButton or event is InputEventScreenTouch:
		return event.is_pressed()
	return event is InputEventMagnifyGesture


func _mode() -> String:
	return String(_lesson.get("mode", "do"))


func _target_rect() -> Rect2:
	if not _target.is_valid():
		return Rect2()
	var value: Variant = _target.call()
	return (value as Rect2).abs() if value is Rect2 else Rect2()


func _screen() -> Rect2:
	return _root.get_viewport_rect()


## TOP OR BOTTOM CENTRE, whichever has more room beside the lit box -- the two places a card
## ever appears -- and it stays there for the whole lesson rather than chasing its target.
##
## ⚠ UNLESS THE BOX IS TOO TALL FOR EITHER. The drawing page is most of the screen's height,
## and a card above or below it sat across the page it was teaching the player to draw on.
## Only then does it stand beside the box instead.
func _choose_place(rect: Rect2, size: Vector2) -> Place:
	if not rect.has_area():
		return Place.TOP
	var view := _screen()
	var lit := rect.grow(HOLE_PAD)
	var top_first := rect.position.y - view.position.y > view.end.y - rect.end.y
	var order := [Place.TOP, Place.BOTTOM] if top_first else [Place.BOTTOM, Place.TOP]
	var keep := _keep_clear(rect)
	for place: Place in order:
		if _clear_at(place, lit, size, keep):
			return place
	var left_room := lit.position.x - view.position.x
	var right_room := view.end.x - lit.end.x
	var beside := Place.LEFT if left_room >= right_room else Place.RIGHT
	# Smaller rather than over the page, down to a point: a card shrunk past legibility is
	# worse than one standing across the bottom of the box.
	var fits := (maxf(left_room, right_room) - BESIDE_GAP * 2.0) / size.x
	if fits >= MIN_BESIDE_SCALE:
		_card_scale = minf(1.0, fits)
		return beside
	return order[0]


## What the card must not stand on: the lit box, and for a `do` card the apo too -- the world
## keeps running under one, and she walks wherever the player takes her.
func _keep_clear(rect: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if rect.has_area():
		out.append(rect.grow(HOLE_PAD))
	if _mode() == "do" and _avoid.is_valid():
		var apo: Variant = _avoid.call()
		if apo is Rect2 and (apo as Rect2).has_area():
			out.append(apo as Rect2)
	return out


func _clear_at(place: Place, lit: Rect2, size: Vector2, keep: Array[Rect2]) -> bool:
	var card := _card_rect_at(place, lit, size)
	for box in keep:
		if card.intersects(box):
			return false
	return true


func _card_rect_at(place: Place, lit: Rect2, unscaled: Vector2) -> Rect2:
	var view := _screen()
	var size := unscaled * _card_scale
	var centred_x := view.position.x + (view.size.x - size.x) * 0.5
	var beside_y := clampf(lit.get_center().y - size.y * 0.5, view.position.y + TOP_GAP,
		view.end.y - EDGE_GAP - size.y)
	match place:
		Place.BOTTOM:
			return Rect2(Vector2(centred_x, view.end.y - EDGE_GAP - size.y), size)
		Place.LEFT:
			return Rect2(Vector2(lit.position.x - BESIDE_GAP - size.x, beside_y), size)
		Place.RIGHT:
			return Rect2(Vector2(lit.end.x + BESIDE_GAP, beside_y), size)
	return Rect2(Vector2(centred_x, view.position.y + TOP_GAP), size)


func _refresh(rect: Rect2, delta: float) -> void:
	var view := _screen()
	var iris := _ease_out(clampf(_age / IRIS_SEC, 0.0, 1.0))
	if rect.has_area():
		var goal := rect.grow(HOLE_PAD)
		var from := _iris_from if _iris_from.has_area() else view.grow(240.0)
		_hole = Rect2(from.position.lerp(goal.position, iris), from.size.lerp(goal.size, iris))
	else:
		_hole = Rect2()
	_material.set_shader_parameter(&"rect_size", _dim.size)
	_material.set_shader_parameter(&"hole", Vector4(_hole.position.x - _dim.global_position.x,
		_hole.position.y - _dim.global_position.y, _hole.size.x, _hole.size.y))
	_material.set_shader_parameter(&"pulse", fmod(_age, PULSE_SEC) / PULSE_SEC)
	_material.set_shader_parameter(&"ring_strength", iris)
	var size := _card.get_combined_minimum_size()
	_card.size = size
	_holder.size = size * _card_scale
	_holder.pivot_offset = _holder.size * 0.5
	_holder.scale = Vector2.ONE * lerpf(POP_FROM, 1.0, _back_out(clampf(_age / POP_SEC, 0.0, 1.0)))
	var lit := rect.grow(HOLE_PAD) if rect.has_area() else Rect2()
	# ⚠ THE OTHER PLACE WHEN THIS ONE IS COVERED. A place chosen when the card went up stops
	# being clear when what it lights moves under it -- the camera rising with a climb, the apo
	# jumping into the top of the screen under a card about the draw button. Found by playing
	# Payyo with the HUD watched. It goes to the other of its two places, never anywhere else,
	# and slides there rather than jumping.
	if rect.has_area() and _place in [Place.TOP, Place.BOTTOM] \
			and _age - _moved_at >= MOVE_AFTER_SEC:
		var keep := _keep_clear(rect)
		var other := Place.BOTTOM if _place == Place.TOP else Place.TOP
		if not _clear_at(_place, lit, size, keep) and _clear_at(other, lit, size, keep):
			_place = other
			_moved_at = _age
	_card_goal = _card_rect_at(_place, lit, size).position.floor()
	if delta <= 0.0 or _holder.position.distance_to(_card_goal) < 1.0:
		_holder.position = _card_goal
	else:
		_holder.position = _holder.position.lerp(_card_goal, clampf(delta * SLIDE_RATE, 0.0, 1.0))
	_pointer.queue_redraw()


## A gold arrow just outside the lit box, on the card's side of it, bobbing at it.
func _draw_pointer() -> void:
	if not _open or not _hole.has_area() or _age < IRIS_SEC:
		return
	var shown := _ease_out(clampf((_age - IRIS_SEC) / ARROW_FADE_SEC, 0.0, 1.0))
	var view := _screen()
	# The way the arrow points: from the card's side towards the box.
	var dir := Vector2.DOWN
	var tip := Vector2(_hole.get_center().x, _hole.position.y)
	match _place:
		Place.BOTTOM:
			dir = Vector2.UP
			tip = Vector2(_hole.get_center().x, _hole.end.y)
		Place.LEFT:
			dir = Vector2.RIGHT
			tip = Vector2(_hole.position.x, _hole.get_center().y)
		Place.RIGHT:
			dir = Vector2.LEFT
			tip = Vector2(_hole.end.x, _hole.get_center().y)
	var bob := (0.5 + 0.5 * sin(_age * 6.0)) * 8.0
	tip -= dir * (6.0 + bob)
	tip.x = clampf(tip.x, view.position.x + 24.0, view.end.x - 24.0)
	# No room between the box and the edge of the screen: no arrow, rather than half of one.
	var tail := tip - dir * 30.0
	if not view.has_point(tail):
		return
	var side := dir.orthogonal()
	var shape := PackedVector2Array([tip, tip - dir * 26.0 + side * 16.0,
		tip - dir * 26.0 - side * 16.0])
	_pointer.draw_colored_polygon(shape, Color(UISkin.GOLD, shown))
	shape.append(tip)
	_pointer.draw_polyline(shape, Color(UISkin.RING_OUTER, shown), 2.0, true)


## The card and arrow fade with the node's modulate; the dim is a shader writing its own
## colour, so it is told.
func _set_fade(amount: float) -> void:
	_fade = amount
	_root.modulate.a = amount
	_material.set_shader_parameter(&"fade", amount)


func _teardown() -> void:
	_open = false
	if _in_run:
		# The run's dim was left up for a card that did not come: put it away now.
		_set_fade(0.0)
	_chained = false
	_holder.modulate.a = 1.0
	visible = false
	set_process(false)
	_lesson = {}
	_target = Callable()
	pauses_game = false
	UIRouter.refresh_pause(get_tree())


func _someone_is_talking() -> bool:
	for box in get_tree().get_nodes_in_group(DialogueBox.GROUP):
		if box.has_method(&"is_open") and bool(box.call(&"is_open")):
			return true
	return false


func _nobody_at_the_keys() -> bool:
	for box in get_tree().get_nodes_in_group(DialogueBox.GROUP):
		var auto: Variant = box.get(&"auto_dismiss")
		if auto is bool and auto:
			return true
	return false


func _ease(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


## Quick to start, slow to land: a fade or an iris that settles rather than stops.
func _ease_out(u: float) -> float:
	return 1.0 - pow(1.0 - u, 3.0)


## Like _ease_out, going a hair past the end and coming back -- the card's rise.
func _back_out(u: float) -> float:
	var overshoot := 1.2
	var v := u - 1.0
	return 1.0 + (overshoot + 1.0) * v * v * v + overshoot * v * v
