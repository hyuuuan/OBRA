class_name TutorialDirector
extends Node
## The part of the game that teaches the game.
##
## LEVEL 1 IS THE TUTORIAL AND IT WAS NOT TEACHING ANYTHING. Two things existed and
## neither is instruction: `ControlsOverlay` is a REFERENCE table behind the pause menu,
## which a player only reaches if they already suspect the verb they are looking for
## exists; and `ActionPromptHUD` puts four key caps on screen (R, Q, E, F) with a verb
## printed on them and no sentence anywhere. Walking, jumping, the mouse -- which is all
## three halves of placement -- the six-slot bag, and the fact that a drawing is on a
## ten-second clock were said in no place at all. A player who never right-clicks
## concludes a misplaced drawing is permanent, which is the single most expensive wrong
## belief this game can give somebody: it costs a drawing and the ink that made it against
## a budget of twelve.
##
## LOLO IS WHY THIS IS A NODE AND NOT A TOOLTIP. The game already has a guide standing
## next to the player, in voice, whose whole narrative job is knowing this place better
## than the apo does. Instruction routed through him is characterisation; instruction
## routed through a popup is an interruption wearing the game's font.
##
## EVERYTHING GOES TO THE HINT BAR. Never DialogueBox. The bar does not pause the tree,
## needs no key to dismiss, fades under a conversation and clears itself -- and pausing
## the world to explain walking is the exact complaint this class was written to answer.
## `_speak` in the level already routes hint-kind lines this way; a lesson is the same
## channel with a key cap in it.
##
## SPENT ONCE PER RUN, IN MEMORY. Not on the profile: a lesson is cheap (it does not stop
## the game), the ledger is small, and a profile schema bump costs a migration plus the
## EXPECTED_SCHEMA literal in test_player_profile.gd. If a returning player should skip
## these, that is a profile flag and a v6 bump, deliberately -- not a side effect of
## adding a tutorial.

const CONFIG_PATH := "res://config/tutorial.json"
## PRELOADED, NOT NAMED. controls_overlay.gd declares no class_name, so the only way to
## reach its static key lookup is the script itself -- the same const inventory_screen.gd
## and level_base.gd both already keep, for the same reason.
const ControlsKeys = preload("res://scripts/controls_overlay.gd")

## Emitted when a lesson is actually shown, so telemetry and tests can see the teaching
## happen rather than infer it from a label.
signal lesson_taught(lesson_id: String)

var _lessons: Array[Dictionary] = []
## lesson id -> true once it has been shown. Also the `after` gate's memory.
var _seen: Dictionary = {}
## `at` -> Array[lesson id], built once so an event is a dictionary lookup rather than a
## scan of the ledger on every physics frame. `moved` is polled, so this runs hot.
var _by_event: Dictionary = {}
var _hint_bar: Node
var _enabled := true


func load_for(level_id: String) -> bool:
	_lessons.clear()
	_by_event.clear()
	_seen.clear()
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
		# A level with nothing to teach is not an error. Level 2 introduces one verb and
		# will want two lessons; Level 5 may want none.
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


func set_enabled(on: bool) -> void:
	_enabled = on


func has_taught(lesson_id: String) -> bool:
	return _seen.has(lesson_id)


func taught_count() -> int:
	return _seen.size()


func lesson_ids() -> Array[String]:
	var out: Array[String] = []
	for lesson in _lessons:
		out.append(String(lesson["id"]))
	return out


## Something happened that a lesson might be waiting on. Cheap enough to call from a
## physics frame: an event nobody is waiting on is one dictionary miss.
##
## AT MOST ONE LESSON PER EVENT, per call. Two lessons landing in the same frame is two
## writes to one label inside one frame, and only the last is ever drawn -- the defect
## `_speak` in the level already carries a comment about fixing twice. The second lesson
## is not lost; its event fires again (placement starts more than once, items are stored
## more than once) and by then the first is spent and no longer shadows it.
func note(event: String) -> void:
	if not _enabled or not _by_event.has(event):
		return
	for id_value: Variant in _by_event[event]:
		var id := String(id_value)
		if _seen.has(id):
			continue
		var lesson := _find(id)
		if lesson.is_empty():
			continue
		var after := String(lesson.get("after", ""))
		# Ordering that survives a player doing things out of sequence. The lesson is not
		# discarded -- it waits for its event to come round again, by which time the one it
		# depends on has been spent.
		if not after.is_empty() and not _seen.has(after):
			continue
		_teach(lesson)
		return


func _find(id: String) -> Dictionary:
	for lesson in _lessons:
		if String(lesson.get("id", "")) == id:
			return lesson
	return {}


func _teach(lesson: Dictionary) -> void:
	var text := resolve(lesson)
	if text.is_empty():
		return
	# NEVER OVER A BUSY BAR, and the lesson is NOT spent when it yields.
	#
	# The HintBar is a shared channel and this is the least important thing on it: Lolo
	# telling you what the obstacle in front of you needs outranks the game explaining its
	# own interface, always. Measured -- the requirement lesson landed in the same frame as
	# Beat 0's "draw something that can roll" and replaced it, which is the one statement of
	# the puzzle the player gets. Leaving the lesson unspent means it simply arrives the
	# next time its event comes round, by which point the bar has cleared itself.
	if _hint_bar != null and _hint_bar.has_method("is_showing") \
			and bool(_hint_bar.call("is_showing")):
		return
	var id := String(lesson["id"])
	_seen[id] = true
	var speaker := String(lesson.get("speaker", "Lolo"))
	var seconds := float(lesson.get("seconds", 0.0))
	# THE KEY IS DRAWN, NOT SPELLED, where the bar can do it. `resolve()` is still the
	# fallback and is still what the tests read, so a bar without the richer entry point --
	# a fixture, an older scene -- degrades to the sentence rather than to nothing.
	var caps := caps_for(lesson)
	if _hint_bar != null and _hint_bar.has_method("show_lesson") and not caps.is_empty():
		_hint_bar.call("show_lesson", String(lesson.get("text", "")), speaker, seconds, caps)
	elif _hint_bar != null and _hint_bar.has_method("show_hint"):
		_hint_bar.call("show_hint", text, speaker, seconds)
	lesson_taught.emit(id)


## The lesson's sentence with `{keys}` filled from the LIVE InputMap.
##
## Public and static-shaped so a test can assert what a lesson would say without a HUD, a
## level or a viewport. Returns "" for a lesson whose action is not bound at all, which is
## the same call ControlsOverlay makes: a sentence that names no key is worse than silence,
## because the player goes looking for a control that is not there.
func resolve(lesson: Dictionary) -> String:
	var text := String(lesson.get("text", ""))
	if text.is_empty():
		return ""
	if not text.contains("{keys}"):
		return text
	var caps := caps_for(lesson)
	return "" if caps.is_empty() else text.replace("{keys}", caps)


## What goes on the cap. Empty for a lesson whose action is not bound at all, which is the
## same call ControlsOverlay makes: a sentence that names no key is worse than silence,
## because the player goes looking for a control that is not there.
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


## ONE KEY, NOT EVERY BINDING. ControlsOverlay lists all of them because it is a reference
## table and completeness is the whole point of a reference table. A lesson is a sentence,
## and movement bound to both WASD and the arrows came out as "D  /  Right - A  /  Left",
## which is four keys, two separators and no instruction. The player needs one key that
## works; the controls screen is still there for the rest. `all_keys` opts back in.
func _cap(action: String, lesson: Dictionary) -> String:
	var caps := ControlsKeys.keys_for(action)
	if bool(lesson.get("all_keys", false)):
		return caps
	var parts := caps.split("/", false)
	return caps if parts.is_empty() else String(parts[0]).strip_edges()
