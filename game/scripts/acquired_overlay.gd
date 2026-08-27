class_name AcquiredOverlay
extends ModalOverlay
## The second and a half that says the thing you were looking at is yours now.
##
## TAKING SOMETHING IN THIS GAME USED TO BE A LINE OF GREY TEXT. Ten different things can be
## acquired in Level 1 -- a drawing entering the bag, the brass key off the nail, Lola's
## canvas, her brush, the hidden flower -- and between them they had one world-space sparkle
## (PickupFlourish2D, on two of them) and one line on the status label, which is the same
## label that says "Placing circle" and is overwritten by whatever happens next. The hidden
## flower had nothing at all: its `collected` signal was emitted into a level that had never
## connected it.
##
## So every acquisition plays this: the world dims, the thing you took comes up large in the
## middle of the screen with its name under it, and after a beat it goes. It is punctuation
## with a picture in it -- the same job PickupFlourish2D does in the world, done where the
## player is definitely looking.
##
## IT DOES NOT PAUSE AND IT DOES NOT ASK FOR A KEY. A pickup can happen mid-jump; a card you
## have to dismiss would be a card that arrives while you are in the air over water. The dim
## is a scrim on its own CanvasLayer, so the game underneath keeps running and the player
## keeps control of it. `process_mode` is ALWAYS (from ModalOverlay), which is what lets the
## card finish playing when the pickup IS followed by a line of story -- and most of them are.
##
## IT QUEUES. Two things can be taken in the same second (a drawn tool that also completes a
## beat), and two cards fading through each other reads as a glitch rather than as two
## rewards.

## How long the card holds at full size before it goes. The whole thing is about two seconds.
## LONG ENOUGH TO BE A MOMENT. It was 1.5s in and out, which is punctuation -- and the
## report from play was that it is "just so fast": the thing you spent the level earning
## goes past before you have finished registering what it is. Two and a half seconds at
## full size, with the world properly dark behind it, is a beat you get to look at.
const HOLD := 2.6
const RISE := 0.26
const FALL := 0.40
## How dark the world goes behind it. Dark enough that the card is the only thing on screen
## -- this is the reward, and the terraces behind it were competing with it at 0.62. Still
## short of a menu's 0.86, because the player keeps control the whole time and has to be
## able to see where they are standing.
const SCRIM := 0.80
## The picture, at the size it hangs. Landscape-ish rather than square: what goes in it is
## anything from a 16:9 painting to an upright drawing of a frog, and a square well put black
## bands above and below every one of Lola's canvases.
const ART_BOX := Vector2(208.0, 152.0)

## HOW FAR IN THE CARD IS, 0 to 1, and the ONLY thing that moves.
##
## The scrim and the card used to be tweened separately with different durations -- the dark
## faded out over 0.40s and the card over 0.28 -- so the world stayed dimmed for a beat after
## the thing you had just been shown was gone. Two properties for one moment is two things
## that can disagree about when the moment is over, and they did. Both read this now, so the
## dim and the popup are the same length by construction rather than by matching numbers.
var _reveal := 0.0:
	set(value):
		_reveal = value
		if _scrim != null:
			_scrim.modulate.a = value
		if _panel != null:
			_panel.modulate.a = value
			# The pop is shaped differently from the fade -- it overshoots and settles -- but
			# it is the same clock, so it cannot outlive the dark it is standing on.
			var pop := 0.78 + 0.22 * ease(minf(value * 1.35, 1.0), 0.35)
			_panel.scale = Vector2(pop, pop)

var _scrim: ColorRect
var _panel: PanelContainer
var _art: TextureRect
var _title: Label
var _note: Label
## Acquisitions still waiting for the screen: [{title, note, art}].
var _queue: Array[Dictionary] = []
var _run: Tween
## Whether the card is fully up and will answer a key press.
var _holding := false


func _ready() -> void:
	super()
	# Nothing about this is a decision, so nothing about it should stop the world or sit
	# there waiting to be dismissed.
	pauses_game = false
	closes_on_cancel = false
	layer = 55
	_build()


func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_scrim = ColorRect.new()
	_scrim.name = "Scrim"
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.color = Color(UISkin.INK, SCRIM)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_scrim)

	var centre := CenterContainer.new()
	centre.name = "Centre"
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(centre)

	_panel = PanelContainer.new()
	_panel.name = "Card"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(_panel)
	# The pop scales the card about its middle, and a PanelContainer does not know its own
	# size until the container has laid it out -- so the pivot is taken from the size it
	# actually got rather than from the one it asked for. That distinction has bitten this
	# project before; see HUD_SKIN.md.
	_panel.resized.connect(func() -> void: _panel.pivot_offset = _panel.size * 0.5)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override(&"separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(column)

	var kicker := Label.new()
	kicker.name = "Kicker"
	kicker.text = "YOU ACQUIRED"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	kicker.add_theme_color_override(&"font_color", UISkin.MUTED)
	kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(kicker)

	# The picture sits in a WELL -- the inset trough the ink gauge and the slots use -- so a
	# drawing with a transparent background has something to be seen against.
	var well := PanelContainer.new()
	well.name = "Well"
	well.add_theme_stylebox_override(&"panel", UISkin.well())
	well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(well)

	_art = TextureRect.new()
	_art.name = "Art"
	_art.custom_minimum_size = ART_BOX
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(_art)

	_title = Label.new()
	_title.name = "Title"
	_title.theme_type_variation = &"ScreenTitle"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_title)

	_note = Label.new()
	_note.name = "Note"
	_note.theme_type_variation = &"ScreenSubtitle"
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(360.0, 0.0)
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_note)

	# Said out loud, because a card that can be dismissed and does not say so is a card the
	# player waits out.
	var prompt := Label.new()
	prompt.name = "Prompt"
	prompt.text = "press any key"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	prompt.add_theme_color_override(&"font_color", UISkin.MUTED)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(prompt)

	# STORY IS FRAMED, MENUS ARE NOT, and this is story: it is the game handing the player
	# something, not the player operating a screen. Same picture frame the Lola memory wears.
	UIFrame.wrap(_panel)


## Show one. Safe to call at any time and from anywhere -- if the screen is busy it waits.
func present(title: String, note: String, art: Texture2D = null) -> void:
	if title.strip_edges().is_empty():
		return
	_queue.append({"title": title, "note": note, "art": art})
	if not is_open():
		_next()


func is_busy() -> bool:
	return is_open() or not _queue.is_empty()


func _next() -> void:
	if _queue.is_empty():
		if is_open():
			close()
		return
	var entry: Dictionary = _queue.pop_front()
	_title.text = String(entry["title"])
	_note.text = String(entry.get("note", ""))
	_note.visible = not _note.text.is_empty()
	var art := entry.get("art") as Texture2D
	_art.texture = art
	_art.get_parent().visible = art != null
	if not is_open():
		open()
	_play()


func _play() -> void:
	if _run != null and _run.is_valid():
		_run.kill()
	_reveal = 0.0
	_holding = false
	var run := create_tween()
	# The tree can be paused underneath this -- a pickup is usually answered with a line of
	# story, and a story line stops the world. A tween bound to that would freeze one frame in.
	run.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	run.tween_property(self, "_reveal", 1.0, RISE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Only once it is fully up: a key already held down when the card arrives must not take
	# it straight back off again, and the player is usually holding a direction.
	run.tween_callback(func() -> void: _holding = true)
	run.tween_interval(HOLD)
	run.tween_callback(_dismiss)
	_run = run


## Take it down, whether the hold ran out or the player pressed something.
func _dismiss() -> void:
	if _run != null and _run.is_valid():
		_run.kill()
	_holding = false
	var out := create_tween()
	out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	out.tween_property(self, "_reveal", 0.0, FALL) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	out.tween_callback(_next)
	_run = out


## ANY KEY TAKES IT AWAY. The card holds for two and a half seconds, which is right when you
## want to look at it and long when you already have -- and this screen asks nothing, so
## there is no wrong key to press. It does NOT pause, so this is the only way a player can
## get their game back sooner; `_holding` is what stops a direction they were already holding
## from eating the card before it has finished arriving.
func _unhandled_input(event: InputEvent) -> void:
	if not _holding or not is_open():
		return
	if not (event is InputEventKey or event is InputEventMouseButton
			or event is InputEventJoypadButton):
		return
	if not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	_dismiss()
