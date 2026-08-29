class_name DialogueBox
extends Control
## The game's voice, in a frame, in one place on the screen.
##
## It used to be a speech bubble pinned to Lolo in world space. That is fine for a
## companion barking one word and wrong for everything else this game does with dialogue:
## the bubble moved while you read it, it shrank and grew per line, it could be behind
## terrain or off the side of the camera, and it put the story at whatever height Lolo
## happened to be floating. Story is not a property of where a character is standing.
##
## Presented the way a console RPG presents it, because those conventions are load-bearing
## and players already know them:
##
##   * ONE PLACE. Across the bottom, always, with the speaker's bust standing above it.
##     The two together are the shot: a face at the top of the screen and the words at the
##     bottom, which is the arrangement every game that leans on dialogue arrives at,
##     because it leaves the middle of the screen -- where the reader's eye travels
##     between the two -- clear.
##   * ONE SIZE, and a generous one. A fixed box whatever the line: one that resizes per
##     line makes the reader re-find the first word every time.
##   * TYPED OUT. Text arrives at a readable rate rather than appearing whole. This is
##     what makes a line feel spoken, and it gives a slow reader a pace to follow.
##   * AN ARROW WHEN IT IS DONE. A blinking mark is the difference between "the game is
##     still talking" and "the game is waiting for you".
##   * THE PLAYER TURNS THE PAGE. A beat is a QUEUE of lines and the player advances it --
##     first press finishes the line being typed, next press moves on. Before this the
##     level handed a whole beat over in one synchronous loop, so five lines were written
##     into the same label in the same frame and only the last one was ever visible. Four
##     of every five lines in Level 1 could not be read at all.
##
## While a conversation is up the world is stopped and the camera is pushed in on whoever
## is talking. Both of those are the same idea: a line of dialogue over a live wide shot is
## a caption on a landscape, and the player reads the box without ever looking at who is
## speaking.
##
## The frame is UIFrame, for the reason written at the top of that file: in this game the
## story is a painting, so it is presented in a picture frame.

## Emitted when the last character of the current line has landed.
signal finished()
## Emitted when the whole conversation has been read and the box has closed.
signal conversation_finished()

## Characters per second. Fast enough not to be a wait, slow enough to read along with.
## A line of Payyo's runs about ninety characters, so this is a shade under two seconds.
const SPEED := 52.0

## The box, in screen pixels. Sized for THREE lines at the body size and then fixed there,
## whatever the line -- a box that grows and shrinks per line makes the reader re-find the
## first word every time, and Payyo's script runs from "Here." to a full sentence about the
## Spanish burning the lowlands.
## Wide and low. It no longer has to leave room beside itself for the speaker, because the
## speaker is above it now rather than behind it, so it can have the whole width.
const BOX := Vector2(1300.0, 300.0)
## How far the bottom of the box sits above the bottom of the screen.
const LIFT := 44.0
## Reserved along the bottom of the canvas for the advance arrow, so the last line of a
## full paragraph does not run underneath it.
const ARROW_GUTTER := 26.0
const UNIT := 4.0

var _portrait: DialoguePortrait
var _frame: UIFrame
var _label: Label
var _speaker_tab: PanelContainer
var _speaker: Label
var _arrow: Control

## Whose line is up. Two voices share this box -- Lolo and the apo's own thoughts -- and
## a caller asking "am I still speaking?" means itself, not the box.
var current_speaker_name := ""

## Lines still to be read, each {text, speaker}. The box shows the head of it.
var _queue: Array[Dictionary] = []
var _full := ""
var _shown := 0.0
var _hold := 0.0
var _blink := 0.0
## True while a queued beat is being read. A hint shown with show_line() alone does not
## stop the world; a conversation does.
var _blocking := false
## Read by UIRouter.refresh_pause through the modal_overlays group. A conversation stops
## the world; that is what makes it a conversation rather than a caption.
var pauses_game := true
## See set_auto_dismiss().
var auto_dismiss := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	modulate.a = 0.0

	# Added before the frame, so the speaker stands BEHIND the box they are talking over.
	_portrait = DialoguePortrait.new()
	_portrait.name = "Portrait"
	add_child(_portrait)

	_frame = UIFrame.new()
	_frame.name = "Frame"
	_frame.unit = UNIT
	add_child(_frame)

	var pad := UIFrame.inset_for(UNIT) + 16.0
	_label = Label.new()
	_label.name = "Text"
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.add_theme_font_size_override(&"font_size", UISkin.FONT_BODY)
	_label.add_theme_color_override(&"font_color", UISkin.CREAM_TEXT)
	# No drop shadow. The canvas behind it is flat and dark; a shadow on type that is
	# already high-contrast only makes it look out of focus.
	_label.add_theme_constant_override(&"shadow_offset_x", 0)
	_label.add_theme_constant_override(&"shadow_offset_y", 0)
	_label.add_theme_constant_override(&"line_spacing", 10)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_label)
	_label.position = Vector2(pad, pad)
	_label.size = BOX - Vector2(pad, pad) * 2.0 - Vector2(0.0, ARROW_GUTTER)

	# Who is speaking, on a tab let into the top rail -- the way a painting carries a
	# plaque. It is also the only part of the box that changes shape, and it sits on the
	# frame rather than inside it so it costs the text no room.
	_speaker_tab = PanelContainer.new()
	_speaker_tab.name = "SpeakerTab"
	_speaker_tab.add_theme_stylebox_override(&"panel", _tab_style())
	_speaker_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speaker_tab.visible = false
	_frame.add_child(_speaker_tab)
	_speaker = Label.new()
	_speaker.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	_speaker.add_theme_color_override(&"font_color", UISkin.WOOD_EDGE)
	_speaker.add_theme_constant_override(&"shadow_offset_x", 0)
	_speaker.add_theme_constant_override(&"shadow_offset_y", 0)
	_speaker_tab.add_child(_speaker)

	_arrow = Arrow.new()
	_arrow.name = "Arrow"
	_arrow.visible = false
	_frame.add_child(_arrow)
	_arrow.size = Vector2(22.0, 14.0)

	set_process(false)


## Anything that takes over the screen with story of its own -- a decision, a memory --
## calls this to clear the running line first. Through a group rather than a reference,
## because those overlays are authored siblings that know nothing about the HUD, and a
## line left underneath a decision box is a second voice arguing with the first.
const GROUP := &"dialogue_box"


func _ready() -> void:
	# Must keep running while the tree is paused: this box IS what paused it, and the key
	# that advances it has to reach something.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	add_to_group(ModalOverlay.GROUP)
	_relayout()
	get_viewport().size_changed.connect(_relayout)


## Read a whole beat, one line at a time, at the player's pace.
##
## `lines` is a list of {text, speaker}. Appending to a conversation already up is
## deliberate: two hooks can fire in the same frame and the player should get both, in
## order, rather than the second silently replacing the first.
func speak(lines: Array) -> void:
	for entry: Variant in lines:
		var line: Dictionary = entry
		if not String(line.get("text", "")).is_empty():
			_queue.append(line)
	if _queue.is_empty():
		return
	if auto_dismiss:
		_queue.clear()
		return
	if not visible:
		_advance()
	UIRouter.refresh_pause(get_tree())


## Part of the modal_overlays contract. A CONVERSATION stops the world; a single line put
## up by show_line() does not, which is what keeps a one-off narration from freezing play.
func is_open() -> bool:
	return _blocking


## Say something. `speaker` may be empty for narration, which shows no tab.
func show_line(text: String, speaker: String = "", seconds: float = 0.0) -> void:
	if text.is_empty():
		hide_line()
		return
	_full = text
	current_speaker_name = speaker
	_shown = 0.0
	_hold = seconds
	_label.text = text
	# The whole line is set and then revealed by ratio rather than by appending to the
	# label. Appending re-wraps on every character, so a word about to overflow jumps to
	# the next line as it is typed and the paragraph reflows under the reader.
	_label.visible_ratio = 0.0
	_speaker.text = speaker.to_upper()
	_speaker_tab.visible = not speaker.is_empty()
	# Settled once per line rather than followed per frame. The camera is still easing in
	# while the first characters arrive, and a box that slid around under the text as it
	# typed would be worse than one that covered the speaker.
	_portrait.show_for(speaker)
	_arrow.visible = false
	set_process(true)
	if not visible:
		visible = true
		_fade_to(1.0)
	_relayout()


## Read and dismiss every beat the moment it starts.
##
## What a "skip cutscenes" switch does, and what every unattended fixture needs: a
## conversation stops the tree until somebody presses a key, and a headless walkthrough has
## nobody to press one. Without it, walking into the first obstacle pauses the world and
## the walker reports the paddy as a wall.
func set_auto_dismiss(on: bool) -> void:
	auto_dismiss = on
	if on:
		skip_all()


## Drop the rest of the beat and give the world back.
##
## A real skip -- what a player who has read it before wants, and what every headless
## fixture needs, because a conversation stops the tree until somebody presses a key and
## there is nobody there to press one. Without this, spawning the level in a test simply
## hangs at the greeting.
func skip_all() -> void:
	_queue.clear()
	_advance()


## Skip to the end of the line. What a press of the advance key does.
func complete() -> void:
	if not visible:
		return
	_shown = float(_full.length())
	_label.visible_ratio = 1.0
	_arrow.visible = true
	finished.emit()


## The line currently on the box, whole, whether or not it has finished arriving. Reading
## the label instead would give a test whatever fraction had been typed when it looked.
## Whose line is up, as a call rather than a bare property read, so a fixture driving the
## box through `call` gets the same answer as code holding a reference.
func current_speaker() -> String:
	return current_speaker_name


func current_line() -> String:
	return _full


## Where the frame actually ended up, so a test can ask how it sits against the portrait.
func frame_rect() -> Rect2:
	return Rect2(_frame.position, _frame.size)


## Where the speaker's bust ended up.
func portrait_rect() -> Rect2:
	return _portrait.bust_rect()


func is_typing() -> bool:
	return visible and _label.visible_ratio < 1.0


## Take the box down.
##
## TAKING THE BOX DOWN ENDS THE CONVERSATION IT WAS SHOWING, and for a long time it did not
## -- it faded the frame and left `_blocking` true with the rest of the beat still in the
## queue. Three things followed from that, and every one of them was reported as a separate
## bug. The tree stayed paused, because UIRouter derives pause from `is_open()` and this box
## still said it was. The camera stayed pushed in on whoever had been speaking, because the
## push-in is given back on `conversation_finished` and that never arrived -- so a decision
## box opened over a camera parked on the last speaker instead of on the player. And the
## abandoned lines sat in the queue until some unrelated beat called `speak()` hours later,
## which popped the stale line FIRST: story from the gorge arriving inside the straw heap.
##
## So this is the door out of a conversation as well as the way to clear a single line. The
## queue is dropped, the block is lifted, and anyone waiting on the end of the beat is told.
## `_advance` clears `_blocking` before it calls this, so the ordinary end of a conversation
## does not announce itself twice.
func hide_line() -> void:
	current_speaker_name = ""
	_portrait.hide_portrait()
	_hold = 0.0
	set_process(false)
	var was_blocking := _blocking
	_blocking = false
	_queue.clear()
	if visible:
		_fade_to(0.0).tween_callback(func() -> void: visible = false)
	if was_blocking:
		UIRouter.refresh_pause(get_tree())
		conversation_finished.emit()


## A tween is bound to its node's pause state by default, and this box is a plain child of
## the level -- so under a modal that pauses the game, the fade never advances and the box
## stays on screen at full opacity underneath. That is exactly when it must go away: a
## decision box opens over it and the stale line argues with the question.
func _fade_to(alpha: float) -> Tween:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", alpha, 0.16)
	return tween


## One key, two jobs, in the order a reader expects: the first press catches up the text
## it is still typing, and the next one turns the page. A single press that did both would
## make a fast reader skip a line they never saw.
func _unhandled_input(event: InputEvent) -> void:
	if not _blocking or not visible:
		return
	var pressed := event.is_action_pressed(&"ui_accept")
	if not pressed and event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		pressed = click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if is_typing():
		complete()
	else:
		_advance()


## Show the next line, or end the conversation if that was the last.
func _advance() -> void:
	if _queue.is_empty():
		_blocking = false
		hide_line()
		UIRouter.refresh_pause(get_tree())
		conversation_finished.emit()
		return
	_blocking = true
	var line: Dictionary = _queue.pop_front()
	show_line(String(line.get("text", "")), String(line.get("speaker", "")))


func _process(delta: float) -> void:
	var length := float(_full.length())
	if _shown < length:
		_shown = minf(length, _shown + SPEED * delta)
		_label.visible_ratio = _shown / maxf(1.0, length)
		if _shown >= length:
			_arrow.visible = true
			finished.emit()
		return

	_blink = fmod(_blink + delta, 1.0)
	_arrow.modulate.a = 1.0 if _blink < 0.6 else 0.15

	# A line given a duration clears itself; one given none stays until something
	# replaces it, which is what a hint about the obstacle in front of you wants.
	if _hold > 0.0 and not _blocking:
		_hold -= delta
		if _hold <= 0.0:
			hide_line()


func _relayout() -> void:
	var view := get_viewport_rect().size
	_frame.size = BOX
	_frame.position = Vector2(
		floorf((view.x - BOX.x) * 0.5), floorf(view.y - LIFT - BOX.y))
	# On the top rail, indented from the corner boss so it does not sit on the joint.
	_speaker_tab.position = Vector2(UNIT * 6.0, -UNIT * 2.5)
	_speaker_tab.size = _speaker_tab.get_combined_minimum_size()
	var pad := UIFrame.inset_for(UNIT) + 16.0
	_arrow.position = Vector2(BOX.x - pad - _arrow.size.x, BOX.y - pad - 4.0)


func _tab_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	# Brass: gold ground, dark letters. The plaque belongs to the frame's palette rather
	# than the HUD's -- a lime one reads as a chip that has drifted down the screen and
	# landed on a painting -- but dark-on-dark made the one word on it the hardest thing
	# in the box to read, which for a name is the whole job.
	box.bg_color = UISkin.FILLET
	box.border_color = UISkin.WOOD_EDGE
	box.set_border_width_all(2)
	box.set_corner_radius_all(UISkin.RADIUS)
	box.content_margin_left = 9.0
	box.content_margin_right = 9.0
	box.content_margin_top = 1.0
	box.content_margin_bottom = 2.0
	box.shadow_color = UISkin.INK
	box.shadow_size = 2
	return box


## The "there is more, press on" mark. A solid triangle, drawn rather than typed, because
## the glyph a font gives for it is at the mercy of whichever font is loaded.
class Arrow extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_colored_polygon(PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(w, 0.0), Vector2(w * 0.5, h),
		]), UISkin.FILLET_LIT)
