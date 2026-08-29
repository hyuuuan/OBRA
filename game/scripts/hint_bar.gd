class_name HintBar
extends Control
## What the game says while you are still playing, as opposed to what the story says.
##
## THESE ARE TWO DIFFERENT KINDS OF SPEECH AND THEY WERE SHARING ONE BOX. "Draw something
## that can span it" and "Four hundred years. Maybe less. They built this while the Spanish
## were burning the lowlands" are not the same act: the first is the game telling you what
## to do and must never stop you doing it, and the second is the game telling you something
## and deserves your attention. One box for both meant either the hint froze the game or
## the story went past unread, and in practice it did both.
##
## So this is the hint channel: small, off to the side, non-blocking, no key to press, and
## it clears itself. It wears HUD colours rather than the picture frame, because a hint is
## the interface talking and the frame is reserved for the fiction.

## WHERE IT SITS: TOP CENTRE, IN THE SKY, tucked under the level badge.
##
## It used to be lifted 396 off the BOTTOM of the screen, which on a 900-tall canvas puts
## its top at y 454 -- dead centre, straight across the path the player is trying to read.
## That number was chosen to clear the dialogue box's top rail, and it was solving a problem
## this bar does not have: a hint and a line of story are never on screen together, because
## _process fades the panel out while anybody is speaking. There was nothing down there to
## clear. The top of the frame is the one band of a side-scroller that is reliably empty,
## and it is the band the player is NOT looking at while they are judging a jump.
##
## Under the badge (which owns y 20..52) and between the two top corners: the HUD frame ends
## at x 418 and the morph card begins at x 1202, so a bar of this width centred on 800 sits
## in the gap rather than over either of them.
const TOP := 66.0
## And NARROWER than it was. A hint is one instruction, read once. At 720 wide with the
## story box's padding it was a slab half the width of the screen -- which is what a beat of
## story is supposed to look like, and the whole point of this channel is that it is not one.
const MAX_WIDTH := 560.0

## The shortest a line of a multi-line beat is held, and the longest. Between them the dwell
## is measured off the line itself -- roughly the speed of reading -- because the three route
## hints at Ang Dayami are not the same length and giving them the same beat means either the
## long one is cut off or the short one sits there.
const BEAT_MIN := 2.6
const BEAT_MAX := 7.0
const BEAT_PER_CHAR := 0.045

var _panel: PanelContainer
var _speaker: Label
var _text: Label
## Built fresh per lesson: the sentence with a real key cap set into it. Hidden, and _text
## shown, for every ordinary hint. See show_lesson.
var _lesson: HFlowContainer
## The plain string a lesson would have been, kept only so _relayout can measure a row it
## cannot ask a single Label for.
var _lesson_plain := ""
var _life := 0.0
## The rest of a beat, waiting its turn: [{text, speaker}]. Empty for every ordinary hint,
## which is one line that stands until something replaces it.
var _queue: Array[Dictionary] = []
## The fade this node's own alpha is currently under, so the next one can cancel it.
##
## A CLEAR AND A SHOW IN THE SAME FRAME USED TO CANCEL EACH OTHER THE WRONG WAY ROUND.
## `clear()` starts a 0.14s fade to zero and only flips `visible` at the end of it, so a
## `show_hint` arriving in between saw a bar that was still visible, skipped its appear
## tween, wrote the new text -- and was then faded out and hidden by the tween the clear had
## already started. The bar went blank holding a live hint. That pair happens on any beat
## that carries story and advice together, which at Ang Dayami is every beat.
var _fade: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	modulate.a = 0.0

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.add_theme_stylebox_override(&"panel", UISkin.chip(11.0, 6.0))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)

	_speaker = Label.new()
	_speaker.name = "Speaker"
	_speaker.theme_type_variation = &"HudCaption"
	# TOP, NOT CENTRE. A one-line hint looks identical either way, but a lesson wraps to two
	# or three lines and a centred plaque then sits beside the MIDDLE of what is being said
	# -- reading as though the speaker's name belonged to line two.
	_speaker.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_speaker.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_speaker)

	_text = Label.new()
	_text.name = "Text"
	_text.theme_type_variation = &"HudValue"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(0.0, 0.0)
	row.add_child(_text)

	_lesson = HFlowContainer.new()
	_lesson.name = "Lesson"
	_lesson.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Separation IS the space between words here, since the words are separate controls.
	_lesson.add_theme_constant_override(&"h_separation", 5)
	_lesson.add_theme_constant_override(&"v_separation", 2)
	_lesson.visible = false
	row.add_child(_lesson)

	set_process(false)


func _ready() -> void:
	_relayout()
	get_viewport().size_changed.connect(_relayout)


## `seconds` of 0 means "until something replaces it", which is what a hint about the
## obstacle in front of you wants to be.
## Whether a story line is up. A hint and a line of dialogue on screen together are two
## voices talking over each other, and the hint is the one that can wait: it is advice about
## the obstacle in front of you and the obstacle is not going anywhere.
func _someone_is_speaking() -> bool:
	for node in get_tree().get_nodes_in_group(DialogueBox.GROUP):
		var box := node as CanvasItem
		if box != null and box.visible:
			return true
	# AND A MODAL COUNTS. The route decision at the gorge is a full-screen framed panel that
	# stops the world, and the beat that teaches the three requirements fires from the
	# obstacle volume a hundred and sixty pixels before it -- so the advice was still playing
	# on the bar behind the panel asking the player to choose. Two channels talking at once,
	# and one of them was the one the player could not act on. This is asked of the pause
	# state rather than of any particular overlay, so it covers the ones not written yet.
	for node in get_tree().get_nodes_in_group(ModalOverlay.GROUP):
		if not node.has_method(&"is_open") or not bool(node.call(&"is_open")):
			continue
		var declares: Variant = node.get(&"pauses_game")
		if declares == null or bool(declares):
			return true
	return false


## A LESSON, WITH THE KEY DRAWN AS A KEY.
##
## Every lesson used to be a flat sentence with the key spelled into it -- "R opens it" --
## which is the game describing its own controls in prose. The prompts at the bottom of the
## screen have drawn proper caps this whole time (UISkin.action_key), so the tutorial was
## the one part of the interface that talked about keys instead of showing them.
##
## `text` keeps its `{keys}` marker and `caps` is what goes in the cap, so the sentence and
## its presentation stay separate: tutorial.json still authors words, and this decides they
## are worth drawing as hardware.
func show_lesson(text: String, speaker: String, seconds: float, caps: String) -> void:
	if text.is_empty():
		clear()
		return
	for child in _lesson.get_children():
		child.queue_free()
	var parts := text.split("{keys}", true)
	_lesson_plain = text.replace("{keys}", caps)
	# ONE CHILD PER WORD, IN A FLOW CONTAINER.
	#
	# The first cut put each half of the sentence in an autowrapping Label inside an
	# HBoxContainer, which cannot wrap: the box gave every label its minimum width, the
	# labels wrapped inside that, and the whole lesson came out as a column of single
	# letters running off the top and bottom of the screen. It loaded clean and passed every
	# assertion in the suite. A flow container wraps its CHILDREN, so the line breaks have to
	# happen between children -- which means the children have to be words.
	for index in range(parts.size()):
		var piece := String(parts[index])
		# PUNCTUATION FOLLOWING A CAP TRAVELS WITH IT. Words are separate controls here and
		# the container puts a gap between every one of them, so a sentence ending
		# "{keys}." came out as a cap, a space, and a full stop stranded on its own.
		if index > 0:
			piece = _strip_leading_punctuation(piece)
		for word in piece.split(" ", false):
			var label := Label.new()
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.theme_type_variation = &"HudValue"
			label.text = word
			_lesson.add_child(label)
		# A cap sits BETWEEN two pieces, so the last piece never gets one after it.
		if index < parts.size() - 1:
			var tail := ""
			if index + 1 < parts.size():
				tail = _leading_punctuation(String(parts[index + 1]))
			_lesson.add_child(_key_cap(caps, tail))
	_text.visible = false
	_lesson.visible = true
	_show(speaker, seconds)


const PUNCTUATION := ".,;:!?)"


func _leading_punctuation(piece: String) -> String:
	var out := ""
	for index in range(piece.length()):
		if not PUNCTUATION.contains(piece[index]):
			break
		out += piece[index]
	return out


func _strip_leading_punctuation(piece: String) -> String:
	return piece.substr(_leading_punctuation(piece).length())


## The cap, plus whatever punctuation was sitting immediately after it, in one tight group
## so the container's word gap cannot open up between them.
func _key_cap(caps: String, tail: String = "") -> Control:
	if not tail.is_empty():
		var group := HBoxContainer.new()
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_theme_constant_override(&"separation", 0)
		group.add_child(_key_cap(caps))
		var mark := Label.new()
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.theme_type_variation = &"HudValue"
		mark.text = tail
		group.add_child(mark)
		return group
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override(&"panel", UISkin.action_key(UISkin.GOLD))
	var letter := Label.new()
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	letter.text = caps
	letter.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	letter.add_theme_color_override(&"font_color", UISkin.INK)
	letter.add_theme_constant_override(&"shadow_offset_x", 0)
	letter.add_theme_constant_override(&"shadow_offset_y", 0)
	badge.add_child(letter)
	return badge


func show_hint(text: String, speaker: String = "", seconds: float = 0.0) -> void:
	if text.is_empty():
		clear()
		return
	_lesson.visible = false
	_text.visible = true
	# A standing prompt REPLACES a beat that is still playing. One channel carries several
	# voices and this one -- "there is a way in under the straw", "press E to read the sign"
	# -- is about where the player is right now, which beats advice they are part-way through
	# reading. show_beat is the entry point for something that must be read in full.
	_queue.clear()
	_text.text = text
	_lesson_plain = ""
	_show(speaker, seconds)


## The half both entry points share: who is speaking, how long it stands, and the arrival.
func _show(speaker: String, seconds: float) -> void:
	_queue.clear()
	_speaker.text = "%s:" % speaker.to_upper() if not speaker.is_empty() else ""
	_speaker.visible = not speaker.is_empty()
	_life = seconds
	set_process(true)
	if _fade != null and _fade.is_valid():
		_fade.kill()
		_fade = null
	if not visible or modulate.a < 1.0:
		visible = true
		var appear := create_tween()
		appear.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		appear.set_parallel(true)
		appear.tween_property(self, "modulate:a", 1.0, 0.14)
		# AND IT DROPS IN. A bar that only fades arrives without a direction, and at the top
		# of the frame -- the band the player is deliberately not looking at while judging a
		# jump -- a fade is easy to miss entirely. Eight pixels of travel out of the top edge
		# is what makes it register as something that just appeared.
		_panel.position.y = TOP - 8.0
		appear.tween_property(_panel, "position:y", TOP, 0.18) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_fade = appear
	_relayout()
	_relayout.call_deferred()


## SEVERAL LINES, IN TURN. This is the fix for a whole beat of advice arriving as one line.
##
## GameLevel._speak hands a beat's hint lines over in a single synchronous loop, and this bar
## had no queue -- every line overwrote the label before a frame was drawn, so only the LAST
## of them was ever seen. That is not a cosmetic loss: `L1_N2.teach` is three lines, one per
## route, and it is the ONLY place the game states the straw heap's puzzle. Two thirds of it
## went into a label that was immediately painted over, which is most of the answer to "I
## walked up to the haystack and could not see a puzzle".
##
## The identical bug was found and fixed for DialogueBox -- "This used to hand a whole beat
## over in one synchronous loop, writing five lines into the same label in the same frame.
## Only the last survived." -- and the hint channel was left with it.
##
## The LAST line stands indefinitely, like any ordinary hint: the beat ends with the advice
## still on screen rather than with the bar going blank.
func show_beat(entries: Array, speaker: String = "") -> void:
	var lines: Array[Dictionary] = []
	for value: Variant in entries:
		if value is Dictionary:
			var entry: Dictionary = value
			if not String(entry.get("text", "")).is_empty():
				lines.append({
					"text": String(entry["text"]),
					"speaker": String(entry.get("speaker", speaker)),
				})
		elif value is String and not (value as String).is_empty():
			lines.append({"text": value as String, "speaker": speaker})
	if lines.is_empty():
		return
	if lines.size() == 1:
		show_hint(String(lines[0]["text"]), String(lines[0]["speaker"]))
		return
	var head: Dictionary = lines[0]
	_queue = lines.slice(1)
	show_hint(String(head["text"]), String(head["speaker"]), _dwell_for(String(head["text"])))
	# show_hint drops the queue, because a standing prompt has to be able to. Put it back.
	_queue = lines.slice(1)


## How long one line of a beat is held. Long enough to read, capped so a wordy line cannot
## park the bar over the level for ten seconds.
func _dwell_for(text: String) -> float:
	return clampf(float(text.length()) * BEAT_PER_CHAR, BEAT_MIN, BEAT_MAX)


func clear() -> void:
	_queue.clear()
	_life = 0.0
	set_process(false)
	if not visible:
		return
	if _fade != null and _fade.is_valid():
		_fade.kill()
	var fade := create_tween()
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(self, "modulate:a", 0.0, 0.14)
	fade.tween_callback(func() -> void: visible = false)
	_fade = fade


func is_showing() -> bool:
	return visible


func current_speaker() -> String:
	return _speaker.text


## What the bar is saying right now. One channel carries several voices -- Lolo's advice
## about the obstacle, the way into the straw heap, the key that re-reads a board -- and a
## writer that wants to take its own message down has to be able to tell whether the
## message still IS its own. Clearing unconditionally takes somebody else's with it.
func current_text() -> String:
	return _text.text


func _process(delta: float) -> void:
	# Stood down while the box is speaking, and back up the moment it closes. Suppressed
	# rather than cancelled: the hint the director asked for is still the current one, so a
	# player who reads a line of story does not have to re-trigger the advice underneath it.
	# FADED, NEVER HIDDEN. _relayout sizes the panel from get_combined_minimum_size(), and a
	# container measured while it is invisible does not report the size it will be -- so
	# toggling `visible` here let a deferred relayout land on a hidden frame and stick an
	# eight-hundred-pixel empty black slab across the top of the level. Alpha changes nothing
	# about layout.
	#
	# It is the PANEL's alpha and not this node's, because show_hint and clear both tween
	# this node's, and two things writing one property is how a bar ends up half-faded.
	var speaking := _someone_is_speaking()
	if _panel != null:
		_panel.modulate.a = 0.0 if speaking else 1.0
	if speaking:
		return
	if _life <= 0.0:
		return
	_life -= delta
	if _life > 0.0:
		return
	if _queue.is_empty():
		clear()
		return
	# NOT clear() -- that drops the queue, which is the whole thing being advanced.
	var next: Dictionary = _queue.pop_front()
	var text := String(next["text"])
	# The last line of a beat stands, like any ordinary hint; the ones before it are timed.
	var dwell := 0.0 if _queue.is_empty() else _dwell_for(text)
	var rest := _queue.duplicate()
	show_hint(text, String(next.get("speaker", "")), dwell)
	_queue = rest


## Sized to its own text up to a limit, then centred. It has no fixed width because unlike
## the story box it is not something the eye returns to -- it appears, is read once, and
## goes, and a fixed bar would be mostly empty for most hints.
##
## The width is MEASURED off the font rather than asked of the layout. A Label with
## autowrap on reports a minimum width of nearly nothing -- it will happily be one
## character wide and a hundred tall -- so sizing the panel to its own minimum produced
## exactly that: a vertical strip of single letters down the middle of the screen.
func _relayout() -> void:
	var view := get_viewport_rect().size
	var font := _text.get_theme_font(&"font")
	var font_size := _text.get_theme_font_size(&"font_size")
	if font == null:
		return
	# A lesson is several controls in a row, so there is no single label to ask. Measured off
	# the plain sentence it would have been, which is the same width to within a cap's
	# padding and is the only string that exists for it.
	var measured := _lesson_plain if _lesson.visible else _text.text
	var single := font.get_string_size(
		measured, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	# A cap is wider than the word it replaces, so a lesson measured off its plain string
	# needs room to grow into or the last word wraps alone onto a second line.
	if _lesson.visible:
		single += 26.0
	var width := ceilf(minf(single, MAX_WIDTH))
	_text.custom_minimum_size = Vector2(width, 0.0)
	# THE FLOW CONTAINER WRAPS AGAINST ITS OWN WIDTH and has no opinion of its own about
	# what that should be -- left to itself it takes the width of its widest child, which is
	# one word.
	_lesson.custom_minimum_size = Vector2(width, 0.0)
	var wanted := _panel.get_combined_minimum_size()
	_panel.size = wanted
	# X only. The drop-in tween owns y while it is running, and writing both here would
	# snap the panel to its resting place on the first frame of every appearance.
	_panel.position.x = floorf((view.x - wanted.x) * 0.5)
	if _fade == null or not _fade.is_valid():
		_panel.position.y = TOP
