class_name TutorialDirector
extends Node
## The part of the game that teaches the game.
##
## LEVEL 1 IS THE TUTORIAL. Walking, jumping, the mouse that does all of placement, the bag
## and the drawing's clock were once said nowhere; then they were all said, in sentences, in
## eight places on the screen, as fast as the events came -- and Kent, playing it: "its just
## knowledge dumping at this point, i feel so overwhelmed, why are the instructions popping
## everywhere". Both failures are the same failure: the tutorial never decided WHEN.
##
## So this decides when, and the rules are the whole class:
##
##   ONE AT A TIME, THEN A BREATH. A lesson waits for the last one to be gone and for a gap
##   after it (short when the player just did the thing, longer when they only looked). An
##   event that arrives meanwhile QUEUES its lesson rather than dropping it, which is what
##   lets a one-off moment -- the first checkpoint, the first obstacle -- still be taught
##   after the conversation it landed in.
##
##   NOTHING OVER ANYONE TALKING. A conversation, the pause menu, any modal: the lesson waits
##   behind it. A lesson about the canvas is the one exception, because the canvas IS a modal.
##
##   NOT WHAT THEY ALREADY DID. A lesson can wait a `delay` before it shows, and if in that
##   time the player presses what it would have taught, it is spent without ever appearing.
##   A player who walks at once is never told how to walk.
##
##   ONLY IN ITS MOMENT. A lesson has a `context` -- in the world, placing, a drawing, the
##   canvas -- and an `anchor` it lights up. Until both hold it waits; if they do not come
##   back within PATIENCE it goes back to unspent, and its event will offer it again.
##
## WHERE IT GOES is TutorialSpotlight: the screen dims, the thing is lit, one card shows the
## key or the mouse doing it. A lesson with `mode: "say"` is Lolo talking rather than the game
## instructing, and goes to the hint bar over the apo's head as it always did. With no
## spotlight bound -- a probe with no HUD -- every lesson is taught at once through the bar,
## one per event, which is what the data audits measure.
##
## WHAT CAN BE TAUGHT AT THE START IS, AT THE DOOR. Kent, of Payyo: "the tutorial should pop up for
## when the moment happens but there should be tutorial that is appropriate at the start like the
## movement, inventory, jump, etc". A level that asks (LevelBase._teaches_at_the_door) calls
## `teach_the_door` once its opening has been said, and the lessons marked `door` -- the ones about
## something already there: walking, jumping, the bag, the quest card, the arrow, the map, Escape --
## play back to back, in ledger order, with no lead and no delay, lighting their `entry_anchor` (or
## `anchor`). Every other lesson waits for its moment, as it always did. (For a day all of them
## played at the door; it taught a canvas, a placed drawing and a creature that were not there.)
##
## ⚠ EACH DOOR CARD WAITS FOR THE PLAYER TO DO IT. Kent: "when the tutorial says press R, when i
## press another key, it just proceeds to the next one, it does not let me experience the tutorial".
## A strict card (TutorialSpotlight) goes only on its own key or click, with a tick -- no timeout,
## no other key -- or when what it lights goes. At the door,
## walking and jumping (`entry_live`) are done for real with the world running; the rest hold the
## world, so a stray key cannot open the canvas mid-run.
##
## SPENT ONCE PER RUN, IN MEMORY. Not on the profile: a returning player skipping these is a
## profile flag and a schema bump, deliberately -- not a side effect of a tutorial. The one thing
## that outlives a level is the short list of lessons Level 1 could not reach for this player
## (`_take_on_what_is_owed`), written when a level is finished.

const CONFIG_PATH := "res://config/tutorial.json"
## The level that teaches the game, and so the one whose lessons a later level can owe.
const TUTORIAL_LEVEL := "level_1"
## PRELOADED, NOT NAMED. controls_overlay.gd declares no class_name, so the only way to
## reach its static key lookup is the script itself.
const ControlsKeys = preload("res://scripts/controls_overlay.gd")

## How long a card in the run at the entry stays up when nobody is at the keys. Every headless
## suite opens Payyo, and thirty cards at the usual AUTO_SEC held the hint bar for over a minute.
const ENTRY_AUTO_SEC := 0.05
## How long the tick on a card done at the door is seen before the next card takes its place.
## Under TutorialSpotlight.DONE_SEC, so the next card still takes over from a leaving one.
const ENTRY_TICK_SEC := 0.45

## After a card the player answered by doing the thing, and after one they only looked at.
const GAP_AFTER_DONE := 1.2
const GAP_AFTER := 2.6
## A queued lesson whose moment has passed -- its context or its anchor gone for this long --
## goes back to unspent. A lesson can ask for longer with `patience`.
const PATIENCE := 8.0

## Emitted when a lesson is actually shown, so telemetry and tests can see the teaching
## happen rather than infer it from a label.
signal lesson_taught(lesson_id: String)
## Emitted when a lesson is spent without being shown, because the player did it first.
signal lesson_skipped(lesson_id: String)
## Emitted when the player skips the rest of the tutorial, with how many lessons were left.
signal tutorial_skipped(lessons_left: int)
## Emitted when the run begun by `teach_the_door` is over: every door card shown, or skipped.
signal door_taught

var _lessons: Array[Dictionary] = []
## lesson id -> "shown" or "skipped", once spent.
var _seen: Dictionary = {}
## `at` -> Array[lesson id], built once so an event is a dictionary lookup rather than a scan
## of the ledger on every physics frame. `moved` is polled, so this runs hot.
var _by_event: Dictionary = {}
## Lesson ids waiting for their moment, oldest first.
var _queue: Array[String] = []
var _ready_for: Dictionary = {}
var _unready_for: Dictionary = {}
var _gap := 0.0
var _hint_bar: Node
var _spotlight: TutorialSpotlight
## anchor name -> screen Rect2, and context name -> bool. Handed in by the level, so this
## class stays testable without one.
var _find_target: Callable = Callable()
var _in_context: Callable = Callable()
var _enabled := true
## LOLO SAYS IT FIRST. A lesson may carry a `lead`: a line (or lines) Lolo says in the story
## box before its card appears, so the card is the answer to something he asked rather than
## an instruction out of nowhere -- "Come, apo, walk with me", THEN the keys. Said through
## whatever the level binds here, once per lesson; the card follows when he has finished,
## because nothing is shown over anyone talking (_coast_is_clear).
var _lead_speaker: Callable = Callable()
var _led: Dictionary = {}
## Which level's ledger is loaded, for the record a skip leaves.
var _level_id := ""
## The cards still to come in the run at the entry, in order, and whether one is on.
var _entry: Array[String] = []
var _entry_running := false
## ⚠ DECIDED ONCE, AT THE START OF THE RUN: whether anyone is at the keys. Asked per card, a
## suite that turned auto-dismiss off a second in -- to read one line itself -- got the next card
## as a real one, which held the world and waited for a key nobody would press.
var _entry_auto := false
## Seconds before the next card of the run, while the tick on the last one is seen.
var _entry_wait := 0.0
## What the level does to set the scene for an entry card, given its anchor ("" at the end) --
## the empty bag shown while a card about the bag is up.
var _stage := Callable()


func _ready() -> void:
	# The canvas lessons are shown while the drawing panel has the tree paused, so the queue
	# has to keep moving then. Everything else that pauses is a modal it waits behind.
	process_mode = Node.PROCESS_MODE_ALWAYS


func load_for(level_id: String) -> bool:
	# A new ledger ends a run on the old one, and the run's card goes with it: left up, a look card
	# held the world and the new ledger's first lesson waited behind it.
	if _entry_running:
		_end_entry()
		if _spotlight != null and _spotlight.is_open():
			_spotlight.finish("closed")
	_level_id = level_id
	_lessons.clear()
	_by_event.clear()
	_seen.clear()
	_queue.clear()
	var text := FileAccess.get_file_as_string(CONFIG_PATH)
	if text.is_empty():
		push_warning("TutorialDirector: could not read %s" % CONFIG_PATH)
		return false
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("TutorialDirector: %s is not a JSON object" % CONFIG_PATH)
		return false
	var levels: Dictionary = (parsed as Dictionary).get("levels", {})
	# A level with nothing to teach is not an error: most of them have no block at all.
	var block: Dictionary = levels.get(level_id, {})
	for value: Variant in block.get("lessons", []):
		_add_lesson(value as Dictionary)
	_take_on_what_is_owed(levels)
	return not _lessons.is_empty()


func _add_lesson(lesson: Dictionary) -> void:
	var id := String(lesson.get("id", ""))
	var at := String(lesson.get("at", ""))
	if id.is_empty() or at.is_empty():
		return
	_lessons.append(lesson)
	var bucket: Array = _by_event.get(at, [])
	bucket.append(id)
	_by_event[at] = bucket


## WHAT LEVEL 1 NEVER GOT TO TEACH THIS PLAYER. Level 1 covers the whole game, but most of its
## lessons wait for the player to do the thing, and a run can finish it having never become
## anything. So what is left over is owed, and a later level -- which otherwise teaches none of
## this -- shows it once, the first time its moment comes. See `carries` in tutorial.json.
func _take_on_what_is_owed(levels: Dictionary) -> void:
	if _level_id == TUTORIAL_LEVEL:
		return
	# Not on a director an audit is holding outside the tree: it has no profile to owe anything.
	var profile := get_node_or_null(^"/root/PlayerProfile") if is_inside_tree() else null
	var owed: Array = profile.call("lessons_owed") if profile != null else []
	if owed.is_empty():
		return
	var tutorial_level: Dictionary = levels.get(TUTORIAL_LEVEL, {})
	for value: Variant in tutorial_level.get("lessons", []):
		var lesson: Dictionary = value
		var id := String(lesson.get("id", ""))
		if not owed.has(id) or not bool(lesson.get("carries", false)):
			# Spent back in Level 1, so that a lesson owed behind it (`after`) can still come.
			_seen[id] = "earlier"
			continue
		# ⚠ WITHOUT ITS LEAD. Those are Lolo's, he is gone by Dilim, and "nothing speaks as him"
		# once he has gone is a rule Mayon's probes hold. A copy: the parsed block is thrown away
		# here, but nothing should have to know that to read this.
		var carried := lesson.duplicate()
		carried.erase("lead")
		_add_lesson(carried)


## The lessons a route could have missed and this one has, which is what the next level owes.
func owed_ids() -> Array:
	var out := []
	for lesson in _lessons:
		var id := String(lesson.get("id", ""))
		if bool(lesson.get("carries", false)) and not _seen.has(id):
			out.append(id)
	return out


func bind_hint_bar(bar: Node) -> void:
	_hint_bar = bar


## The one place lessons are shown, how an `anchor` becomes something on screen, and how a
## `context` is asked about. Handed in rather than looked up so a probe can bind its own.
func bind_spotlight(spotlight: TutorialSpotlight, finder: Callable, context: Callable) -> void:
	_spotlight = spotlight
	_find_target = finder
	_in_context = context
	if _spotlight != null and not _spotlight.finished.is_connected(_on_card_finished):
		_spotlight.finished.connect(_on_card_finished)
	if _spotlight != null and not _spotlight.skip_requested.is_connected(skip_rest):
		_spotlight.skip_requested.connect(skip_rest)


func bind_lead(speaker: Callable) -> void:
	_lead_speaker = speaker


## The lead lines a lesson carries, as an array. Not for `say` lessons, which are Lolo talking
## already, nor for the canvas: the story box sits under the drawing panel, so a line there
## would stop the world behind a panel that hides it. The canvas is led into by the lesson
## that opens it.
func lead_of(lesson: Dictionary) -> Array:
	if _mode_of(lesson) == "say" or String(lesson.get("context", "world")) == "canvas":
		return []
	var lead: Variant = lesson.get("lead", [])
	if lead is String:
		return [] if String(lead).is_empty() else [lead]
	return (lead as Array).duplicate() if lead is Array else []


func spotlight() -> TutorialSpotlight:
	return _spotlight


func set_enabled(on: bool) -> void:
	_enabled = on
	if not on:
		_queue.clear()
		# Before the card goes: its going would otherwise put the next one up.
		_end_entry()
		if _spotlight != null and _spotlight.is_open():
			_spotlight.finish("skipped")


func is_enabled() -> bool:
	return _enabled


## SKIP TUTORIAL, from a card. Every lesson left in this level is spent unshown and nothing else
## is taught here -- not this card's followers, not Lolo's tutorial lines on the hint bar. Cards
## do not play on a return visit (LevelBase._play_opening), so in practice the level stays
## skipped; the next level's lessons, which teach rules that level changes, still play.
## Recorded locally, so a run finished without the tutorial can be told apart in the thesis data.
func skip_rest() -> void:
	if not _enabled:
		return
	var left := 0
	for lesson in _lessons:
		var id := String(lesson.get("id", ""))
		if not _seen.has(id):
			_seen[id] = "skipped"
			left += 1
	set_enabled(false)
	# Skipping means it: nothing left over comes back in a later level.
	var profile := get_node_or_null(^"/root/PlayerProfile")
	if profile != null:
		profile.call("set_lessons_owed", [])
	var telemetry := get_node_or_null(^"/root/Telemetry")
	if telemetry != null:
		telemetry.call("record_event", "tutorial_skipped", {"level_id": _level_id, "lessons_left": left})
	tutorial_skipped.emit(left)


## Spent: shown, or skipped because the player did it first.
func has_taught(lesson_id: String) -> bool:
	return _seen.has(lesson_id)


## Shown on screen, as opposed to skipped.
func was_shown(lesson_id: String) -> bool:
	return String(_seen.get(lesson_id, "")) == "shown"


## Spent, or waiting in the queue to be: the lesson WILL be said, so the caller need not.
func is_coming(lesson_id: String) -> bool:
	return _seen.has(lesson_id) or _queue.has(lesson_id)


func taught_count() -> int:
	return _seen.size()


func pending_ids() -> Array[String]:
	return _queue.duplicate()


## Every lesson spent so far, shown or skipped -- what a saved checkpoint keeps, so resuming
## a level does not teach walking again.
func taught_ids() -> Array:
	return _seen.keys()


## Spend these lessons without showing them.
func mark_taught(ids: Array) -> void:
	for id_value: Variant in ids:
		var id := String(id_value)
		_seen[id] = "skipped"
		_queue.erase(id)


func lesson_ids() -> Array[String]:
	var out: Array[String] = []
	for lesson in _lessons:
		out.append(String(lesson["id"]))
	return out


## Something happened that a lesson might be waiting on. Cheap enough to call from a physics
## frame: an event nobody is waiting on is one dictionary miss.
func note(event: String) -> void:
	# ⚠ NOT DURING THE RUN AT THE ENTRY. A moment that comes during it -- headless, where the world
	# is not held, `level_start` comes every frame -- queued its card a second time, and _pump
	# shows what is queued without asking whether it has been shown.
	if not _enabled or _entry_running or not _by_event.has(event):
		return
	for id_value: Variant in _by_event[event]:
		var id := String(id_value)
		if _seen.has(id) or _queue.has(id):
			continue
		var lesson := _find(id)
		if lesson.is_empty():
			continue
		# Ordering that survives a player doing things out of sequence: a lesson behind
		# another waits for that one to be spent and is offered again on its next event.
		var after := String(lesson.get("after", ""))
		if not after.is_empty() and not _seen.has(after):
			continue
		_queue.append(id)
		_ready_for[id] = 0.0
		_unready_for[id] = 0.0
	_pump(0.0)


func _process(delta: float) -> void:
	if _entry_running:
		_entry_wait = maxf(0.0, _entry_wait - delta)
		_pump_entry()
	elif _enabled and not _queue.is_empty():
		_pump(delta)
	elif _gap > 0.0:
		_gap = maxf(0.0, _gap - delta)


## THE PLAYER DID IT BEFORE WE SAID IT. A press made while a lesson is queued -- its moment
## has come, its card has not -- and that is one of the inputs it teaches, in the context
## it teaches it in, spends it unshown.
func _input(event: InputEvent) -> void:
	if not _enabled or _entry_running or _queue.is_empty():
		return
	if event is InputEventMouseMotion or event.is_echo() or not event.is_pressed():
		return
	# A key pressed while somebody is talking turns the page. Counted as the lesson, the
	# space that advanced Lolo's lead line spent the jump card it was leading into.
	for box in get_tree().get_nodes_in_group(DialogueBox.GROUP):
		if box.has_method(&"is_open") and bool(box.call(&"is_open")):
			return
	for id in _queue.duplicate():
		var lesson := _find(id)
		if lesson.is_empty() or not _context_holds(lesson):
			continue
		if TutorialSpotlight.matches(_card_for(lesson), event):
			_queue.erase(id)
			_seen[id] = "skipped"
			lesson_skipped.emit(id)


## Show the first queued lesson whose moment it is, if nothing else is up.
func _pump(delta: float) -> void:
	if _spotlight == null:
		_teach_at_once()
		return
	if _spotlight.is_busy():
		return
	_gap = maxf(0.0, _gap - delta)
	for id in _queue.duplicate():
		var lesson := _find(id)
		if lesson.is_empty():
			_queue.erase(id)
			continue
		var ready := _context_holds(lesson) and _anchor_ready(lesson)
		var can_show := ready and _gap <= 0.0 and _coast_is_clear(lesson)
		# Optional reminders can go stale while waiting behind another line.
		if not ready or (_mode_of(lesson) == "say" and not can_show):
			_ready_for[id] = 0.0
			if not ready or not get_tree().paused:
				_unready_for[id] = float(_unready_for.get(id, 0.0)) + delta
			if float(_unready_for[id]) > float(lesson.get("patience", PATIENCE)):
				_queue.erase(id)
			continue
		_unready_for[id] = 0.0
		if not can_show:
			continue
		_ready_for[id] = float(_ready_for.get(id, 0.0)) + delta
		if float(_ready_for[id]) < float(lesson.get("delay", 0.0)):
			continue
		var lead := lead_of(lesson)
		if not lead.is_empty() and not _led.has(id) and _lead_speaker.is_valid():
			# Said now; the card comes on a later pump, once he has finished. It stays at the
			# front of the queue with its delay already served.
			_led[id] = true
			_lead_speaker.call(lead)
			return
		_queue.erase(id)
		_show(lesson)
		return


## No spotlight: the old channel, one lesson per call, straight to the bar. What a probe
## with no HUD gets, and what the data audits measure.
func _teach_at_once() -> void:
	if _queue.is_empty():
		return
	var id: String = _queue.pop_front()
	var lesson := _find(id)
	_seen[id] = "shown"
	if _hint_bar != null and _hint_bar.has_method("show_hint"):
		var text := resolve(lesson)
		if not text.is_empty():
			_hint_bar.call("show_hint", text, String(lesson.get("speaker", "Lolo")),
				float(lesson.get("seconds", 0.0)))
	lesson_taught.emit(id)


## THE DOOR'S CARDS, NOW, ONE AFTER ANOTHER. Awaitable: it returns when the last has gone or the
## rest were skipped. Each `door` lesson this run has not spent is shown strict, in ledger order,
## without its `lead` and lighting its `entry_anchor`; `entry_live` ones run the world under them,
## the rest hold it. `stage` is called with each card's anchor before it shows, and with "" when
## the run is over.
func teach_the_door(stage: Callable = Callable()) -> void:
	_entry.clear()
	if _enabled:
		for lesson in _lessons:
			var id := String(lesson.get("id", ""))
			if not _seen.has(id) and bool(lesson.get("door", false)) and _mode_of(lesson) != "say":
				_entry.append(id)
	if _entry.is_empty():
		return
	# Queued for a moment that is not coming now -- shown here instead.
	for id in _entry:
		_queue.erase(id)
	_stage = stage
	_entry_running = true
	_entry_wait = 0.0
	if _spotlight != null:
		_spotlight.hold(true)
		# It holds only for somebody at the keys.
		_entry_auto = not _spotlight.is_holding()
		_spotlight.set_in_run(true)
	_pump_entry()
	if _entry_running:
		await door_taught


func is_teaching_the_door() -> bool:
	return _entry_running


## Where a lesson points when it is shown at the entry: its own subject if that is already on
## screen, otherwise the control that will do it.
func entry_anchor_of(lesson: Dictionary) -> String:
	return String(lesson.get("entry_anchor", lesson.get("anchor", "")))


## The next card of the run, if nothing else is up; the end of it, if none is left.
func _pump_entry() -> void:
	if not _entry_running:
		return
	if _spotlight == null:
		# No HUD: nowhere to show them. Spent as shown, which is what the data audits measure.
		for id in _entry:
			_seen[id] = "shown"
			lesson_taught.emit(id)
		_entry.clear()
		_end_entry()
		return
	if _spotlight.is_showing():
		return
	if _entry.is_empty():
		_end_entry()
		return
	if _entry_wait > 0.0:
		return
	var lesson := _find(_entry[0])
	var quiet := lesson.duplicate()
	quiet.erase("lead")
	if not _coast_is_clear(quiet):
		return
	var id: String = _entry.pop_front()
	_seen[id] = "shown"
	var anchor := entry_anchor_of(lesson)
	if _stage.is_valid():
		_stage.call(anchor)
	var card := _card_for(lesson)
	# Done for real with the world running, or held still with the press spent on the card.
	var live := bool(lesson.get("entry_live", false))
	card["mode"] = "do" if live else "look"
	card["strict"] = true
	card["auto"] = _entry_auto
	card["auto_seconds"] = ENTRY_AUTO_SEC
	# Decided with the rest of the run's auto: a suite that sits down part-way must not be held.
	_spotlight.hold(not live and not _entry_auto)
	_present(card, anchor)
	lesson_taught.emit(id)


func _end_entry() -> void:
	if not _entry_running:
		return
	_entry_running = false
	_entry.clear()
	if _stage.is_valid():
		_stage.call("")
	_stage = Callable()
	_entry_wait = 0.0
	if _spotlight != null:
		_spotlight.set_in_run(false)
		_spotlight.hold(false)
	door_taught.emit()


func _show(lesson: Dictionary) -> void:
	var id := String(lesson["id"])
	_seen[id] = "shown"
	if _mode_of(lesson) == "say":
		# In passing, because what it speaks over is still true: the advice comes back after him.
		if _hint_bar != null and _hint_bar.has_method("interject"):
			var while_relevant := Callable()
			if lesson.has("context"):
				while_relevant = func() -> bool: return _context_holds(lesson)
			_hint_bar.call("interject", resolve(lesson), String(lesson.get("speaker", "Lolo")),
				float(lesson.get("seconds", 6.0)), while_relevant)
		_gap = GAP_AFTER
		lesson_taught.emit(id)
		return
	_present(_card_for(lesson), String(lesson.get("anchor", "")))
	lesson_taught.emit(id)


func _present(card: Dictionary, anchor: String) -> void:
	var finder := _find_target
	var target := func() -> Variant:
		if anchor.is_empty() or not finder.is_valid():
			return Rect2()
		return finder.call(anchor)
	# The apo, which a card the world runs under has to keep off as she moves.
	var apo := func() -> Variant:
		return finder.call("player") if finder.is_valid() else Rect2()
	_spotlight.present(card, target, apo)


func _on_card_finished(_lesson_id: String, how: String) -> void:
	_gap = GAP_AFTER_DONE if how == "done" else GAP_AFTER
	# ⚠ WHILE THE CARD IS STILL LEAVING: the next takes its place before the dim can fade, and
	# the hold keeps the world still in between. A card she did is given the moment its tick needs.
	if _entry_running:
		_entry_wait = ENTRY_TICK_SEC if how == "done" else 0.0
		_pump_entry()


func _context_holds(lesson: Dictionary) -> bool:
	if not _in_context.is_valid():
		return true
	return bool(_in_context.call(String(lesson.get("context", "world"))))


func _anchor_ready(lesson: Dictionary) -> bool:
	var anchor := String(lesson.get("anchor", ""))
	if anchor.is_empty() or not _find_target.is_valid():
		return true
	var rect: Variant = _find_target.call(anchor)
	return rect is Rect2 and (rect as Rect2).has_area()


## Nobody else is talking. A conversation, a line in the story box, any open modal -- except
## the drawing panel, for a lesson that is about the drawing panel.
func _coast_is_clear(lesson: Dictionary) -> bool:
	var on_canvas := String(lesson.get("context", "world")) == "canvas"
	for node in get_tree().get_nodes_in_group(ModalOverlay.GROUP):
		if node == _spotlight or not node.has_method(&"is_open"):
			continue
		if on_canvas and node is DrawPanel:
			continue
		if bool(node.call(&"is_open")):
			return false
	for box in get_tree().get_nodes_in_group(DialogueBox.GROUP):
		var shown: Variant = box.get(&"visible")
		if shown is bool and shown:
			return false
	# Nor while the letterbox is in. It frames a beat and carries its own caption -- at a
	# checkpoint, "Checkpoint" in the lower bar -- and a card over it was two things to read.
	#
	# ⚠ A CARD. LOLO'S LEAD IS SAID NOW. The bars do not stop her, so "A lantern!" waited two
	# seconds and was said 480 px past the lantern, about something behind her. The line stops
	# the world where she stands; its card still waits for the bars.
	var about_to_speak := not lead_of(lesson).is_empty() and not _led.has(String(lesson.get("id", "")))
	for bars in get_tree().get_nodes_in_group(CinematicBars.GROUP):
		if not about_to_speak and bars.has_method(&"is_playing") and bool(bars.call(&"is_playing")):
			return false
	# Lolo's own line waits for what is up to be read: the advice about the obstacle in front of
	# the player outranks him remarking on the interface.
	#
	# ⚠ READ, NOT GONE. Advice stands until its beat ends, so waiting for an empty bar meant
	# "That bar is your ink now" was not said while the bangka's advice stood, which is the whole
	# time she holds the shape it is about.
	if _mode_of(lesson) == "say" and _hint_bar != null and _hint_bar.has_method(&"is_being_read") \
			and bool(_hint_bar.call(&"is_being_read")):
		return false
	return true


func _mode_of(lesson: Dictionary) -> String:
	var mode := String(lesson.get("mode", ""))
	if not mode.is_empty():
		return mode
	var teaches := not String(lesson.get("action", "")).is_empty() \
		or not (lesson.get("mouse", []) as Array).is_empty()
	return "do" if teaches else "look"


## The spotlight's form of a lesson: what to draw, what to say under it, and which presses
## count as doing it.
func _card_for(lesson: Dictionary) -> Dictionary:
	return {
		"id": String(lesson.get("id", "")),
		"mode": _mode_of(lesson),
		"visual": String(lesson.get("visual", "keys")),
		"caps": caps_list(lesson),
		"caption": String(lesson.get("caption", resolve(lesson))),
		"seconds": float(lesson.get("seconds", 10.0)),
		"actions": actions_for(lesson),
		"mouse": lesson.get("mouse", []),
	}


func _find(id: String) -> Dictionary:
	for lesson in _lessons:
		if String(lesson.get("id", "")) == id:
			return lesson
	return {}


## The lesson's sentence with `{keys}` filled from the LIVE InputMap. What the hint bar says,
## and what a card falls back to when the lesson has no `caption`.
##
## Returns "" for a lesson whose action is not bound at all: a sentence that names no key is
## worse than silence, because the player goes looking for a control that is not there.
func resolve(lesson: Dictionary) -> String:
	var text := String(lesson.get("text", ""))
	if text.is_empty():
		return ""
	if not text.contains("{keys}"):
		return text
	var caps := caps_for(lesson)
	return "" if caps.is_empty() else text.replace("{keys}", caps)


## The keys as one string, for a sentence. Empty when the action is not bound.
func caps_for(lesson: Dictionary) -> String:
	var literal := String(lesson.get("keys", ""))
	if not literal.is_empty():
		return literal
	var action := String(lesson.get("action", ""))
	if action.is_empty() or not InputMap.has_action(action):
		return ""
	var caps := _cap(action, lesson)
	var through := String(lesson.get("through", ""))
	if not through.is_empty() and InputMap.has_action(through):
		caps = "%s%s%s" % [caps, String(lesson.get("join", " - ")), _cap(through, lesson)]
	return "" if caps.contains("unbound") else caps


## The keys as caps to draw, one per key: [A, D] for walking, [1 .. 6] for the bag.
func caps_list(lesson: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var literal := String(lesson.get("keys", ""))
	if not literal.is_empty():
		out.append(literal)
		return out
	for action in actions_for(lesson):
		var cap := _cap(String(action), lesson)
		if not cap.is_empty() and not cap.contains("unbound"):
			out.append(cap)
	return out


## Every action the lesson teaches. `through` is the other end: two actions, or -- when both
## end in a number, like inventory_slot_1 .. inventory_slot_6 -- the run between them.
func actions_for(lesson: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var action := String(lesson.get("action", ""))
	if action.is_empty() or not InputMap.has_action(action):
		return out
	var through := String(lesson.get("through", ""))
	if through.is_empty() or not InputMap.has_action(through):
		out.append(action)
		return out
	var numbered := RegEx.create_from_string("^(.*?)(\\d+)$")
	var first := numbered.search(action)
	var last := numbered.search(through)
	if first != null and last != null and first.get_string(1) == last.get_string(1):
		for n in range(int(first.get_string(2)), int(last.get_string(2)) + 1):
			var name := "%s%d" % [first.get_string(1), n]
			if InputMap.has_action(name):
				out.append(name)
		return out
	out.append(action)
	out.append(through)
	return out


## ONE KEY, NOT EVERY BINDING. ControlsOverlay lists all of them because it is a reference
## table; a lesson needs one key that works. `all_keys` opts back in.
func _cap(action: String, lesson: Dictionary) -> String:
	var caps := ControlsKeys.keys_for(action)
	if bool(lesson.get("all_keys", false)):
		return caps
	var parts := caps.split("/", false)
	return caps if parts.is_empty() else String(parts[0]).strip_edges()
