class_name DanceOverlay
extends ModalOverlay
## The screen the dance happens on. `dance_minigame.gd` is the scoring; this is the playing.
##
## THE MODEL SHIPPED WITHOUT IT AND THAT BROKE THE LEVEL. `DanceMinigame` has had cues,
## windows, two attempts and a clear condition since the systems pass, and nothing anywhere
## called any of it -- so committing "I will dance for them" at Problem 1 closed the other
## two routes and then nothing happened at all. No kandila, no church, no way back to the
## choice. `run_nodraw_level2` printed that as PEND on every run. This is what closes it.
##
## WHAT IS SCORED IS **WHEN THE STROKE FINISHES**, NOT WHAT IT WAS. The recogniser is not
## involved and no ink is spent: it is a performance, not a summoning. The shape on each cue
## is there to give the hand something to do that takes time -- which is what makes timing a
## skill rather than a reflex -- and it is deliberately never checked. A player who scribbles
## on the beat has danced; a player who draws a beautiful sayaw two seconds late has not.
##
## SO IT IS BUILT IN CODE, like everything else this level places. There is no `.tscn` for
## it: generating scene files by hand is trap 2 in the notes, and an overlay whose entire
## content is one custom-drawn lane has nothing a scene file would hold better.
##
## ⚠ EVERYTHING HERE RUNS WHILE THE TREE IS PAUSED. `ModalOverlay` sets
## `PROCESS_MODE_ALWAYS`, which is what lets the clock tick and the lane move under a modal
## that stopped the world -- the same reason the dialogue box's tweens had to become
## `TWEEN_PAUSE_PROCESS` (HUD_SKIN.md, six things that are not obvious, #4).

## The whole run is over. `cleared` is whether they got it; `flower` is the only thing that
## was ever at stake.
signal run_finished(cleared: bool, flower: bool)
## One attempt ended and another is coming. The level speaks Lolo's tease off this.
signal attempt_lost(attempts_used: int)

## How long a cue takes to travel the lane. Long enough to read the shape and set up for it,
## short enough that the lane is not a queue of six things at once.
const APPROACH := 2.2
## Quiet before the first cue is in the lane, so the screen can be understood before it
## starts asking for anything.
const LEAD_IN := 1.6
## How long after the last beat the attempt stays open. One beat of settle: a stroke
## finished a fraction late on the last cue still counts, and the screen does not snap shut
## on the player's hand.
const TAIL := 1.0

## Off the sheet, via HUD_SKIN.md. Nothing here invents a colour.
const INK := Color(0.027, 0.035, 0.024, 1.0)        # 070906
const PANEL := Color(0.051, 0.063, 0.035, 1.0)      # 0D1009
const PANEL_LIT := Color(0.086, 0.094, 0.063, 1.0)  # 161810
const RING_MID := Color(0.420, 0.306, 0.090, 1.0)   # 6B4E17
const MUTED := Color(0.808, 0.757, 0.612, 1.0)      # CEC19C
const GOLD := Color(0.859, 0.659, 0.208, 1.0)       # DBA835
const GOLD_PALE := Color(0.945, 0.855, 0.616, 1.0)  # F1DA9D
const CREAM := Color(0.910, 0.890, 0.769, 1.0)      # E8E3C4
const PENDING := Color(1.0, 0.741, 0.239, 1.0)      # FFBD3D
## A missed cue. Not red -- nothing in this level's palette is red, and a miss here costs
## the player nothing but a flower they were never told about.
const MISSED := Color(0.365, 0.353, 0.310, 1.0)     # 5D5A4F

var _dance: DanceMinigame
var _stage: Control
var _title: Label
var _status: Label
## Seconds into the current attempt, in the same frame of reference as the cue track --
## `judge()` compares against `_beats[index]`, so this is what gets passed to it.
var _clock := 0.0
var _running := false
## The stroke being drawn right now, in the stage's own coordinates. Kept so the player can
## see what their hand is doing; never looked at afterwards.
var _stroke: PackedVector2Array = PackedVector2Array()
var _drawing := false
## Per cue: "" while it is still coming, then the verdict.
var _verdicts: Array[String] = []
## The last verdict and when it was given, for the flash at the judgement line.
var _flash := ""
var _flash_at := -99.0
## Set when a stroke lands nowhere near a cue. Says so, and consumes nothing.
var _stray_at := -99.0


func _ready() -> void:
	super()
	layer = 66
	# NOT CLOSEABLE BY ESCAPE. This is a performance somebody asked the apo for, and it is
	# also the only door out of the route they have already committed to -- letting the
	# cancel key dismiss it would strand the player exactly where the missing screen did.
	closes_on_cancel = false
	_build()


## The overlay owns the view; the model owns the scoring. Handed in rather than found, so
## a fixture can drive this against a model it built itself.
func bind(model: DanceMinigame) -> void:
	_dance = model


func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	# NOT OPAQUE. The dancers are on the other side of this and they are who the performance
	# is for; a screen that hides them turns the beat into a rhythm exercise.
	dim.color = Color(INK.r, INK.g, INK.b, 0.74)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var centre := CenterContainer.new()
	centre.name = "Center"
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(centre)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(1280.0, 840.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(panel)
	# Framed like every other panel in the game. `wrap` is what puts the gold ring and the
	# bevel on, and doing it by hand here would be a second frame that drifts from the rest.
	UIFrame.wrap(panel)

	var pad := MarginContainer.new()
	pad.name = "Pad"
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_%s" % side, 30)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(pad)

	var box := VBoxContainer.new()
	box.name = "VBox"
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(box)

	_title = Label.new()
	_title.name = "Title"
	_title.text = "SAYAW"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", GOLD_PALE)
	box.add_child(_title)

	var rule := HSeparator.new()
	box.add_child(rule)

	_stage = Control.new()
	_stage.name = "Stage"
	_stage.custom_minimum_size = Vector2(1200.0, 660.0)
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# THE ONE THING ON THIS SCREEN THAT TAKES INPUT. Everything else ignores the mouse, so a
	# stroke started anywhere in the panel reaches here and nothing eats it on the way.
	_stage.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.gui_input.connect(_on_stage_input)
	_stage.draw.connect(_draw_stage)
	box.add_child(_stage)

	_status = Label.new()
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 19)
	_status.add_theme_color_override("font_color", MUTED)
	box.add_child(_status)


# --- Running an attempt -----------------------------------------------------------------

## Open on the first attempt. The level calls this when the Artist route commits.
func present() -> void:
	if _dance == null:
		push_error("DanceOverlay: opened with no model bound")
		return
	open()
	_begin()


func _begin() -> void:
	var attempt := _dance.begin_attempt()
	_verdicts.clear()
	for _beat in _dance.track():
		_verdicts.append("")
	_clock = -LEAD_IN
	_stroke = PackedVector2Array()
	_drawing = false
	_flash = ""
	_flash_at = -99.0
	_running = true
	_title.text = "SAYAW" if attempt == 1 else "SAYAW  ·  ULIT"
	_status.text = "Draw on the beat. Anything you like — it is the timing they are watching."
	_stage.queue_redraw()


func _process(delta: float) -> void:
	if not _running:
		return
	_clock += delta
	_expire_passed_cues()
	if _clock > _last_beat() + TAIL:
		_end_attempt()
	_stage.queue_redraw()


func _last_beat() -> float:
	var track := _dance.track()
	return track[track.size() - 1] if track.size() > 0 else 0.0


## A cue that has gone past its window with no stroke is a miss, and is SAID SO rather than
## left blank. The model would score it the same either way -- an unjudged cue is not landed
## -- but a pip that greys out as the cue passes is the difference between a player who
## knows they were late and one who thinks the game did not see them.
func _expire_passed_cues() -> void:
	var track := _dance.track()
	for index in range(track.size()):
		if index < _verdicts.size() and not _verdicts[index].is_empty():
			continue
		if _clock <= track[index] + DanceMinigame.HIT_WINDOW:
			continue
		# Judged with a time deliberately outside every window, so the model returns "miss"
		# through its own rules rather than this screen inventing a verdict.
		var verdict := _dance.judge(index, track[index] + 99.0)
		_verdicts[index] = verdict
		_flash = "MISS"
		_flash_at = _clock


func _end_attempt() -> void:
	_running = false
	var over := _dance.end_attempt()
	if over:
		# `finished` has already gone out of the model with the real answer; the screen just
		# reports what it was told, so the two can never disagree.
		var cleared := _dance.cleared()
		_title.text = "SALAMAT" if cleared else "SAYAW  ·  TAPOS"
		_status.text = "They are clapping." if cleared \
			else "They give you the candle anyway."
		await get_tree().create_timer(1.8, true, false, true).timeout
		close()
		run_finished.emit(cleared, _dance.flower_earned())
		return
	# One go left. The design asks Lolo to TEASE here rather than instruct, so the level
	# speaks and this screen only says how many cues landed.
	_status.text = "%d of %d. Again." % [_dance.landed(), _dance.track().size()]
	attempt_lost.emit(_dance.attempts_used())
	await get_tree().create_timer(2.2, true, false, true).timeout
	if is_open():
		_begin()


# --- The hand ---------------------------------------------------------------------------

func _on_stage_input(event: InputEvent) -> void:
	if not _running:
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_drawing = true
			_stroke = PackedVector2Array([button.position])
		elif _drawing:
			_drawing = false
			perform_stroke()
		_stage.accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _drawing:
		# Sampled rather than every pixel: a stroke is a line the player can see, not data.
		if _stroke.is_empty() or _stroke[_stroke.size() - 1].distance_to(motion.position) > 6.0:
			_stroke.append(motion.position)
		_stage.accept_event()


## Seconds into the attempt, in the cue track's own frame of reference. Public because a
## fixture driving this has to know when the beats are, and reading a private field from a
## test is a test that breaks when the field is renamed.
func clock() -> float:
	return _clock


## THE MOMENT THE STROKE FINISHES IS THE MOMENT THAT IS SCORED, which is the model's own
## rule: scoring where a stroke STARTED would reward one begun early and dragged onto the
## beat. The cue it counts against is the nearest one still unjudged.
##
## PUBLIC, AND NOT AS A CONCESSION TO THE TESTS. "The player completed a stroke" is the
## actual event this screen is built around; the mouse is one way to raise it and a fixture
## is another. A private handler reachable only through a synthetic `InputEventMouseButton`
## would make the suite a test of Godot's input plumbing rather than of the dance.
func perform_stroke() -> String:
	if not _running:
		return ""
	var index := _nearest_open_cue()
	if index < 0:
		# Nowhere near anything. Consumes no cue -- a stray must not spend one the player
		# can still hit -- and says so, because silence here reads as the game not seeing it.
		_stray_at = _clock
		_flash = ""
		_stroke = PackedVector2Array()
		return "stray"
	var verdict := _dance.judge(index, _clock)
	_verdicts[index] = verdict
	_flash = verdict.to_upper()
	_flash_at = _clock
	_stroke = PackedVector2Array()
	return verdict


func _nearest_open_cue() -> int:
	var track := _dance.track()
	var best := -1
	var best_gap := DanceMinigame.HIT_WINDOW
	for index in range(track.size()):
		if index < _verdicts.size() and not _verdicts[index].is_empty():
			continue
		var gap := absf(_clock - track[index])
		if gap <= best_gap:
			best_gap = gap
			best = index
	return best


# --- The stage ----------------------------------------------------------------------------

## Where the cues are judged, as a fraction across the stage. Left of centre, so a cue is
## approached from the right the way it is read.
const LINE_AT := 0.30

## Stage timber, and the runner down it.
const BOARD := Color(0.420, 0.271, 0.149, 1.0)      # 6B4526
const BOARD_LIT := Color(0.557, 0.373, 0.196, 1.0)  # 8E5F32
const BOARD_DARK := Color(0.271, 0.173, 0.082, 1.0) # 452C15
const RUNNER := Color(0.682, 0.059, 0.078, 1.0)     # AE0F14
const RUNNER_DARK := Color(0.514, 0.047, 0.063, 1.0)


## ⚠ THIS WAS A GREY BOX WITH RINGS TRAVELLING ACROSS IT, and it was the plainest screen in
## the game -- which is a strange thing for the one screen that is a PERFORMANCE.
##
## It is a stage now. Bunting across the head of the panel, boards with a red runner down
## them, the four dancers standing along the back dancing to the same beat the player is
## being asked for, a drum for the judgement post, and the cues are the dancers' own flower
## fans coming toward it. Everything on it is a thing the fiesta actually has.
func _draw_stage() -> void:
	var size := _stage.size
	_draw_bunting(size)
	var lane := Rect2(0.0, 62.0, size.x, 170.0)
	var line_x := size.x * LINE_AT
	var per_second := lane.size.x * (1.0 - LINE_AT) / APPROACH
	_draw_boards(lane)
	_draw_windows(lane, line_x, per_second)
	_draw_troupe(Rect2(0.0, lane.position.y + lane.size.y + 6.0, size.x, 138.0))
	_draw_cues(lane, line_x, per_second)
	_draw_post(lane, line_x)
	# The pips sit clear BELOW the troupe. Sharing a row with them put six markers among
	# eight dancing feet, and neither could be read.
	var pips_y := lane.position.y + lane.size.y + 176.0
	_draw_pips(Vector2(size.x * 0.5, pips_y))
	_draw_pad(Rect2(0.0, pips_y + 34.0, size.x, size.y - pips_y - 38.0))
	# Below the bunting rather than behind it.
	_draw_flash(Vector2(line_x, lane.position.y + 26.0))


## Banderitas across the top of the panel. The screen is inside the fiesta, not beside it.
func _draw_bunting(size: Vector2) -> void:
	var colours: Array[Color] = [
		Color(0.808, 0.165, 0.141, 1.0), Color(0.937, 0.757, 0.173, 1.0),
		Color(0.318, 0.643, 0.804, 1.0), Color(0.482, 0.741, 0.376, 1.0)]
	var points := PackedVector2Array()
	var steps := int(size.x / 34.0)
	for index in range(steps + 1):
		var t := float(index) / float(steps)
		points.append(Vector2(t * size.x, 8.0 + sin(t * PI) * 20.0))
	_stage.draw_polyline(points, Color(0.30, 0.27, 0.22, 1.0), 2.0)
	for index in range(steps):
		var at := points[index]
		var flag := colours[index % colours.size()]
		_stage.draw_colored_polygon(PackedVector2Array([
			at, at + Vector2(26.0, 0.0), at + Vector2(13.0, 24.0)]), flag)


## The boards, and the runner the dancers work on.
func _draw_boards(lane: Rect2) -> void:
	_stage.draw_rect(lane, BOARD)
	var y := lane.position.y
	var row := 0
	while y < lane.position.y + lane.size.y:
		_stage.draw_rect(Rect2(lane.position.x, y, lane.size.x, 13.0),
			BOARD_LIT if row % 2 == 0 else BOARD)
		_stage.draw_rect(Rect2(lane.position.x, y + 13.0, lane.size.x, 2.0), BOARD_DARK)
		y += 15.0
		row += 1
	# The runner: a red carpet down the middle of the lane, edged in gold.
	var runner := Rect2(lane.position.x, lane.position.y + lane.size.y * 0.30,
		lane.size.x, lane.size.y * 0.44)
	_stage.draw_rect(runner, RUNNER)
	_stage.draw_rect(Rect2(runner.position, Vector2(runner.size.x, 4.0)), RUNNER_DARK)
	for edge: float in [runner.position.y + 6.0,
			runner.position.y + runner.size.y - 9.0]:
		_stage.draw_rect(Rect2(runner.position.x, edge, runner.size.x, 3.0), GOLD)
	_stage.draw_rect(Rect2(lane.position.x, lane.position.y, lane.size.x, 3.0), RING_MID)
	_stage.draw_rect(Rect2(lane.position.x, lane.position.y + lane.size.y - 3.0,
		lane.size.x, 3.0), RING_MID)


## The timing windows, drawn to scale on the boards. The player can SEE how generous it is,
## which is most of what stops a rhythm screen feeling arbitrary on a first play.
func _draw_windows(lane: Rect2, line_x: float, per_second: float) -> void:
	_stage.draw_rect(Rect2(line_x - DanceMinigame.HIT_WINDOW * per_second, lane.position.y,
		DanceMinigame.HIT_WINDOW * per_second * 2.0, lane.size.y),
		Color(GOLD.r, GOLD.g, GOLD.b, 0.10))
	_stage.draw_rect(Rect2(line_x - DanceMinigame.PERFECT_WINDOW * per_second,
		lane.position.y, DanceMinigame.PERFECT_WINDOW * per_second * 2.0, lane.size.y),
		Color(GOLD_PALE.r, GOLD_PALE.g, GOLD_PALE.b, 0.20))


## THE JUDGEMENT POST IS A DRUM, because Sinulog is a drum before it is anything else -- and
## a drum gives the beat somewhere to land that a white line does not.
func _draw_post(lane: Rect2, line_x: float) -> void:
	var drum := PiyestaTiles.size_of("drum")
	_stage.draw_rect(Rect2(line_x - 2.0, lane.position.y - 10.0, 4.0, lane.size.y + 20.0),
		GOLD)
	if drum.y <= 0.0:
		return
	# It swells on the beat, which is the only clock the screen shows.
	var beat := 0.0
	for due in _dance.track():
		beat = maxf(beat, 1.0 - clampf(absf(_clock - due) / 0.22, 0.0, 1.0))
	var lift := 1.0 + beat * 0.16
	PiyestaTiles.stand(_stage, "drum",
		Vector2(line_x, lane.position.y + lane.size.y + 6.0), lift)


## The four of them along the back of the stage, dancing to the beat the player is being
## asked for. They are who the performance is FOR, and the screen never showed them.
func _draw_troupe(area: Rect2) -> void:
	var size := PiyestaTiles.size_of("dancer_a")
	if size.y <= 0.0:
		return
	var scale := minf(1.0, area.size.y / size.y)
	for index in range(4):
		var at := Vector2(area.position.x + area.size.x * (0.17 + 0.22 * float(index)),
			area.position.y + area.size.y)
		var beat := sin(_clock * TAU / 1.0 + float(index) * 1.05)
		var lift := absf(beat) * 6.0
		PiyestaTiles.stand(_stage, "dancer_a" if beat > 0.0 else "dancer_b",
			at - Vector2(0.0, lift), scale)


## THE CUES ARE THE DANCERS' OWN FANS. They were rings with a scratch inside them; a fan is
## what the dance is done with, it is already the troupe's silhouette, and it turns the lane
## into something happening rather than a meter.
func _draw_cues(lane: Rect2, line_x: float, per_second: float) -> void:
	var track := _dance.track()
	var names: Array[String] = ["fan_a", "fan_b", "fan_c"]
	for index in range(track.size()):
		var due: float = track[index]
		var x := line_x + (due - _clock) * per_second
		if x < -90.0 or x > lane.position.x + lane.size.x + 90.0:
			continue
		var judged: String = _verdicts[index] if index < _verdicts.size() else ""
		var centre := Vector2(x, lane.position.y + lane.size.y * 0.52)
		var tint := Color.WHITE
		var scale := 1.5
		match judged:
			"perfect":
				# Struck: it opens and fades where it was hit.
				scale = 2.4 + (1.0 - clampf((_clock - due) / 0.5, 0.0, 1.0)) * 1.4
				tint = Color(1.0, 1.0, 1.0, maxf(0.0, 1.0 - (_clock - due) / 0.6))
			"early", "late":
				scale = 2.4
				tint = Color(1.0, 0.94, 0.82, maxf(0.0, 1.0 - (_clock - due) / 0.6))
			"miss":
				tint = Color(0.45, 0.44, 0.42, 0.55)
			_:
				# Turning as it comes, so a fan on the way in is alive.
				scale = 2.3 + 0.22 * sin(_clock * 4.0 + float(index))
		PiyestaTiles.stand(_stage, names[index % names.size()],
			centre + Vector2(0.0, PiyestaTiles.size_of("fan_a").y * scale * 0.5),
			scale, tint)


## One pip per cue. The threshold is DRAWN -- a mark under the fourth -- rather than written
## in a sentence nobody reads mid-performance.
func _draw_pips(centre: Vector2) -> void:
	var track := _dance.track()
	var step := 46.0
	var start := centre.x - (float(track.size()) - 1.0) * step * 0.5
	for index in range(track.size()):
		var at := Vector2(start + float(index) * step, centre.y)
		var judged: String = _verdicts[index] if index < _verdicts.size() else ""
		match judged:
			"perfect", "early", "late":
				PiyestaTiles.stand(_stage, "fan_a", at + Vector2(0.0, 17.0), 1.15,
					GOLD_PALE if judged == "perfect" else PENDING)
			"miss":
				_stage.draw_arc(at, 15.0, 0.0, TAU, 18, MISSED, 3.0)
			_:
				_stage.draw_arc(at, 15.0, 0.0, TAU, 18, RING_MID, 3.0)
		if index == DanceMinigame.CUES_TO_CLEAR - 1:
			_stage.draw_rect(Rect2(at.x - 17.0, at.y + 24.0, 34.0, 4.0), GOLD)


## Where the hand goes: a marked-out square of the plaza's own paving, framed in gold.
func _draw_pad(rect: Rect2) -> void:
	if rect.size.y <= 10.0:
		return
	PiyestaTiles.fill(_stage, rect, "paving_b", Color(0.62, 0.58, 0.52, 1.0))
	for edge: Rect2 in [
			Rect2(rect.position, Vector2(rect.size.x, 3.0)),
			Rect2(rect.position + Vector2(0.0, rect.size.y - 3.0), Vector2(rect.size.x, 3.0)),
			Rect2(rect.position, Vector2(3.0, rect.size.y)),
			Rect2(rect.position + Vector2(rect.size.x - 3.0, 0.0), Vector2(3.0, rect.size.y))]:
		_stage.draw_rect(edge, GOLD)
	if _stroke.size() > 1:
		# The stroke is drawn twice: a dark backing under a bright core, so it reads on
		# stone the way a brush loaded with ink would.
		_stage.draw_polyline(_stroke, Color(0.15, 0.09, 0.04, 0.85), 7.0)
		_stage.draw_polyline(_stroke, CREAM, 4.0)
		return
	if not _drawing and _clock - _stray_at < 0.9:
		var fade := 1.0 - (_clock - _stray_at) / 0.9
		var mid := rect.get_center()
		_stage.draw_rect(Rect2(mid.x - 60.0, mid.y, 120.0, 3.0),
			Color(MISSED.r, MISSED.g, MISSED.b, fade))
		return
	if not _drawing:
		var mid := rect.get_center()
		var faint := Color(GOLD.r, GOLD.g, GOLD.b, 0.30)
		_stage.draw_line(mid - Vector2(30.0, 0.0), mid + Vector2(30.0, 0.0), faint, 2.0)
		_stage.draw_line(mid - Vector2(0.0, 30.0), mid + Vector2(0.0, 30.0), faint, 2.0)


## THE VERDICT, AND WHICH WAY THEY WERE OFF. The model names early and late separately for
## exactly one reason -- it is the whole teaching -- so this both writes the word and puts it
## on the side of the line the stroke actually fell: EARLY sits before the line, LATE after.
func _draw_flash(at: Vector2) -> void:
	if _flash.is_empty() or _clock - _flash_at > 0.7:
		return
	var font := _stage.get_theme_default_font()
	if font == null:
		return
	var fade := 1.0 - (_clock - _flash_at) / 0.7
	var colour := PENDING
	if _flash == "PERFECT":
		colour = GOLD_PALE
	elif _flash == "MISS":
		colour = MISSED
	colour.a = fade
	var size := 24
	var width := font.get_string_size(_flash, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	var lean := -width * 0.5
	if _flash == "EARLY":
		lean = -width - 30.0
	elif _flash == "LATE":
		lean = 30.0
	# A burst behind the word on a perfect, which is the only celebration the screen gets.
	if _flash == "PERFECT":
		for spoke in range(10):
			var angle := spoke * (TAU / 10.0) + _clock
			_stage.draw_line(at, at + Vector2(cos(angle), sin(angle)) * (26.0 * fade),
				Color(GOLD.r, GOLD.g, GOLD.b, fade * 0.7), 3.0)
	_stage.draw_string(font, at + Vector2(lean, 0.0), _flash,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, colour)
