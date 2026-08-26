class_name DialogueScript
extends RefCounted
## Level 1's dialogue, and the hook-driven format it is written in.
##
## The existing config/dialogue.json is a nested dictionary of named slots -- greeting,
## arrival, node.choices.artist -- which works when a level has one node and about a dozen
## lines. Payyo has seventy across a tutorial beat and three nodes, several of which fire
## on things a slot cannot name: the first time recognition declines anywhere in the level,
## the second and third raking pass, lingering near the bulul.
##
## So a line here declares WHERE it fires (`at`) and the level emits hooks. That inverts
## the dependency: adding a line is a data edit, and the level does not grow a new field
## per line. It is also what makes the "no line names a class" rule checkable in one place
## (see tests/run_level1_audit.gd) rather than scattered across call sites.
##
## Line shape:
##   id            stable, referenced by level_01.json (e.g. scripted.on_first_decline)
##   at            the hook, e.g. "L1_N1.teach" or "on_first_decline"
##   text          what is said. MUST NOT name a drawable class
##   speaker       "lolo" (default) or "apo"
##   once          fire once per level, ever -- for the refusal beat
##   choice_label  present on the three route-commit lines; the button the player presses
##   condition     a flag that must be set for the line to fire (e.g. knows_about_key)

const DEFAULT_SPEAKER := "lolo"

var _by_hook: Dictionary = {}      # hook -> Array[Dictionary]
var _by_id: Dictionary = {}        # line id -> Dictionary
var _fired_once: Dictionary = {}   # line id -> true, for `once`
var _heard: Dictionary = {}        # hook -> true, for beats that play themselves once
var _flags: Dictionary = {}        # narrative flags, e.g. knows_about_key
var _level_id := ""


func load_from(path: String) -> bool:
	_by_hook.clear()
	_by_id.clear()
	_fired_once.clear()
	_heard.clear()
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("DialogueScript: %s is missing or empty" % path)
		return false
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("DialogueScript: %s is not a JSON object" % path)
		return false
	var doc := parsed as Dictionary
	_level_id = String(doc.get("level_id", ""))
	for line_value: Variant in doc.get("lines", []):
		var line: Dictionary = line_value
		var hook := String(line.get("at", ""))
		if hook.is_empty():
			continue
		if not _by_hook.has(hook):
			_by_hook[hook] = []
		(_by_hook[hook] as Array).append(line)
		_by_id[String(line.get("id", ""))] = line
	return true


func level_id() -> String:
	return _level_id


func has_hook(hook: String) -> bool:
	return _by_hook.has(hook)


func hooks() -> Array:
	var keys := _by_hook.keys()
	keys.sort()
	return keys


## Every line that should play for this hook, in authored order, with `once` and
## `condition` already applied. Calling this MARKS once-lines as fired, so it is the act
## of playing them -- use `peek` if you only want to look.
func fire(hook: String) -> Array:
	var out := peek(hook)
	if not out.is_empty():
		_heard[hook] = true
	for line_value: Variant in out:
		var line: Dictionary = line_value
		if bool(line.get("once", false)):
			_fired_once[String(line.get("id", ""))] = true
	return out


## Whether this hook has ever played. Distinct from `once`, and the two do different jobs:
## `once` is authored per line and means "this line is spent, never give it to anyone
## again", which is right for the refusal beat and wrong for an arrival. A beat of arrival
## lore should still be READABLE afterwards -- it is the level telling you where you are --
## it just must not seize the screen every time you walk back through the door.
##
## THE BUG THIS EXISTS FOR. Level 1's straw heap sits inside L1_N2's trigger, and so does
## the spot the player is put down on when they climb back out of it. Leaving the heap
## therefore re-entered the obstacle, which re-fired `L1_N2.enter`, which paused the world
## for two lines of Lolo -- every single time. L1_N1 is worse: seven lines. The volume was
## not the fault, and neither was the sign standing next to it; the fault was that arrival
## had no memory.
func has_heard(hook: String) -> bool:
	return _heard.has(hook)


func peek(hook: String) -> Array:
	var out: Array = []
	for line_value: Variant in _by_hook.get(hook, []):
		var line: Dictionary = line_value
		if bool(line.get("once", false)) and _fired_once.has(String(line.get("id", ""))):
			continue
		var condition := String(line.get("condition", ""))
		if not condition.is_empty() and not is_flag_set(condition):
			continue
		out.append(line)
	return out


func line_by_id(id: String) -> Dictionary:
	return (_by_id.get(id, {}) as Dictionary).duplicate(true)


## The three route buttons for a node, as {route: label}. Read off the commit lines
## rather than authored separately, so the button and the line the apo says when it is
## pressed can never drift apart -- they are the same string.
func choices_for(obstacle_id: String) -> Dictionary:
	var out: Dictionary = {}
	for route in ["artist", "pragmatist", "protector"]:
		var hook := "%s.%s.commit" % [obstacle_id, route]
		for line_value: Variant in _by_hook.get(hook, []):
			var line: Dictionary = line_value
			if line.has("choice_label"):
				out[route] = String(line["choice_label"])
				break
	return out


## Hooks whose lines are the game telling you what to DO rather than telling you
## something. They go to the hint bar, which never stops play and needs no key.
##
## Derived from the hook rather than authored per line, because the hook already carries
## the distinction: `.teach` and `.sub1` fire when the player is standing in front of an
## obstacle, `.ward.fail1` fires when they have just got it wrong. A line may override with
## an explicit "kind" of "hint" or "lore" -- the data wins where the two disagree.
const HINT_HOOKS := ["teach", "sub1", "sub2", "ward.fail1", "ward.fail2"]


func kind_of(line: Dictionary) -> String:
	var explicit := String(line.get("kind", ""))
	if explicit == "hint" or explicit == "lore":
		return explicit
	var hook := String(line.get("at", ""))
	var suffix := hook.split(".", false)
	if suffix.size() > 1 and HINT_HOOKS.has(".".join(suffix.slice(1))):
		return "hint"
	return "lore"


func speaker_of(line: Dictionary) -> String:
	return String(line.get("speaker", DEFAULT_SPEAKER))


## The line as the player should SEE it.
##
## The script marks ability tags with **asterisks** so that exactly one surface form
## exists for them and the audit can find them. Lolo's bubble is a plain Label with no
## markup, so it rendered the asterisks literally -- "kayang **span**" on screen, which
## reads as a typo in the one line the tutorial most needs to be trusted.
##
## The markers become UPPERCASE instead of vanishing, because the emphasis is the point:
## SPAN is the word the requirement strip prints and the word the Ability Book indexes,
## and the player has to connect the three.
func display_text(line: Dictionary) -> String:
	var text := String(line.get("text", ""))
	var pattern := RegEx.new()
	pattern.compile("\\*\\*(.+?)\\*\\*")
	var out := text
	var found := pattern.search_all(text)
	# Backwards, so replacing one match does not shift the offsets of the next.
	for index in range(found.size() - 1, -1, -1):
		var hit := found[index]
		out = out.substr(0, hit.get_start()) + hit.get_string(1).to_upper() \
			+ out.substr(hit.get_end())
	return out


# --- Narrative flags ---------------------------------------------------------

## Set by a route's reward -- Node 2's Artist route sets knows_about_key, which is what
## makes the sketchbook page pay out at Node 3 rather than in its own cutscene.
func set_flag(flag: String) -> void:
	if not flag.is_empty():
		_flags[flag] = true


func is_flag_set(flag: String) -> bool:
	return _flags.has(flag)


func flags() -> Array:
	var keys := _flags.keys()
	keys.sort()
	return keys
