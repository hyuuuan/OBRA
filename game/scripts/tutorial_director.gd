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
## SPENT ONCE PER RUN, IN MEMORY. Not on the profile: a returning player skipping these is a
## profile flag and a schema bump, deliberately -- not a side effect of a tutorial.

const CONFIG_PATH := "res://config/tutorial.json"
## PRELOADED, NOT NAMED. controls_overlay.gd declares no class_name, so the only way to
## reach its static key lookup is the script itself.
const ControlsKeys = preload("res://scripts/controls_overlay.gd")

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


func _ready() -> void:
	# The canvas lessons are shown while the drawing panel has the tree paused, so the queue
	# has to keep moving then. Everything else that pauses is a modal it waits behind.
	process_mode = Node.PROCESS_MODE_ALWAYS


func load_for(level_id: String) -> bool:
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
	if not levels.has(level_id):
		# A level with nothing to teach is not an error.
		return false
	var block: Dictionary = levels[level_id]
	for value: Variant in block.get("lessons", []):
		var lesson: Dictionary = value
		var id := String(lesson.get("id", ""))
		var at := String(lesson.get("at", ""))
		if id.is_empty() or at.is_empty():
			continue
		_lessons.append(lesson)
		var bucket: Array = _by_event.get(at, [])
		bucket.append(id)
		_by_event[at] = bucket
	return not _lessons.is_empty()


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
		if _spotlight != null and _spotlight.is_open():
			_spotlight.finish("skipped")


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
	if not _enabled or not _by_event.has(event):
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
	if _enabled and not _queue.is_empty():
		_pump(delta)
	elif _gap > 0.0:
		_gap = maxf(0.0, _gap - delta)


## THE PLAYER DID IT BEFORE WE SAID IT. A press made while a lesson is queued -- its moment
## has come, its card has not -- and that is one of the inputs it teaches, in the context
## it teaches it in, spends it unshown.
func _input(event: InputEvent) -> void:
	if not _enabled or _queue.is_empty():
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
		if not _context_holds(lesson) or not _anchor_ready(lesson):
			_ready_for[id] = 0.0
			_unready_for[id] = float(_unready_for.get(id, 0.0)) + delta
			if float(_unready_for[id]) > float(lesson.get("patience", PATIENCE)):
				_queue.erase(id)
			continue
		_unready_for[id] = 0.0
		if _gap > 0.0 or not _coast_is_clear(lesson):
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


func _show(lesson: Dictionary) -> void:
	var id := String(lesson["id"])
	_seen[id] = "shown"
	if _mode_of(lesson) == "say":
		if _hint_bar != null and _hint_bar.has_method("show_hint"):
			_hint_bar.call("show_hint", resolve(lesson), String(lesson.get("speaker", "Lolo")),
				float(lesson.get("seconds", 6.0)))
		_gap = GAP_AFTER
		lesson_taught.emit(id)
		return
	var anchor := String(lesson.get("anchor", ""))
	var finder := _find_target
	var target := func() -> Variant:
		if anchor.is_empty() or not finder.is_valid():
			return Rect2()
		return finder.call(anchor)
	# The apo, which a card the world runs under has to keep off as she moves.
	var apo := func() -> Variant:
		return finder.call("player") if finder.is_valid() else Rect2()
	_spotlight.present(_card_for(lesson), target, apo)
	lesson_taught.emit(id)


func _on_card_finished(_lesson_id: String, how: String) -> void:
	_gap = GAP_AFTER_DONE if how == "done" else GAP_AFTER


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
	for bars in get_tree().get_nodes_in_group(CinematicBars.GROUP):
		if bars.has_method(&"is_playing") and bool(bars.call(&"is_playing")):
			return false
	# Lolo's own line waits for the bar to be free: the advice about the obstacle in front of
	# the player outranks him remarking on the interface.
	if _mode_of(lesson) == "say" and _hint_bar != null and _hint_bar.has_method(&"is_showing") \
			and bool(_hint_bar.call(&"is_showing")):
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
