extends Node
## The ability-tag layer: obstacles ask for a TAG, never a class.
##
## An obstacle that named a class would be a puzzle with one answer, and a game whose
## whole proposition is "draw anything and it works" cannot have puzzles with one answer.
## So a gap declares that it needs something that can **span**, and this resolves that to
## {bridge, ladder, square, triangle} at load time. The player is never told which.
##
## Two consequences worth understanding before changing anything here:
##
## 1. THE ANTI-STUCK FALLBACK IS NOT AUTHORED, IT FALLS OUT OF THE DATA. Node 2's Artist
##    route asks for Forage; Forage resolves to {rake, pig}; so a pig is a valid Artist
##    solution with nothing written anywhere to allow it. Add a class to a tag and every
##    obstacle needing that tag accepts it, at once, everywhere.
##
## 2. EXCLUSIONS RUN BEFORE THE >= 2 CHECK. `exclude` is for classes that carry a tag but
##    make no physical sense at one obstacle -- scissors can cut, but not a tree. If an
##    exclusion drops an obstacle to a single solution that is a BUILD ERROR, not a design
##    choice, because the player who cannot draw that one thing has nowhere to go.
##
## Tag membership is a design artifact and is NOT ConceptNet output -- see tags.json's
## provenance block and tools/build_tags.py. Do not describe it as ConceptNet-derived.

const TAGS_PATH := "res://config/tags.json"
const ENTITIES_PATH := "res://config/entities.json"

## An obstacle resolving to fewer than this is unsolvable for someone.
const MIN_SOLUTIONS := 2

## How multiple required tags combine.
##   "all" -- the class must carry every tag (intersection). The default.
##   "any" -- the class may carry any one of them (union). Node 1's Pragmatist route
##            uses this: following the terrace walls takes a leap OR a climb, and
##            demanding one animal that does both would resolve to almost nothing.
const MATCH_ALL := "all"
const MATCH_ANY := "any"

var _tag_classes: Dictionary = {}   # tag -> PackedStringArray
var _class_tags: Dictionary = {}    # class id -> Array[String]
var _display: Dictionary = {}       # tag -> display name
var _gloss: Dictionary = {}         # tag -> what the tag means, in the player's words
var _unlock_level: Dictionary = {}  # tag -> level number that first teaches it
var _loaded := false


func _ready() -> void:
	load_tags()


func load_tags() -> bool:
	_tag_classes.clear()
	_class_tags.clear()
	_display.clear()
	_gloss.clear()
	_unlock_level.clear()
	_loaded = false

	var text := FileAccess.get_file_as_string(TAGS_PATH)
	if text.is_empty():
		push_error("AbilityTags: %s is missing or empty" % TAGS_PATH)
		return false
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("AbilityTags: %s is not a JSON object" % TAGS_PATH)
		return false

	var roster := _load_roster()
	var tags: Dictionary = (parsed as Dictionary).get("tags", {})
	for tag_value: Variant in tags.keys():
		var tag := String(tag_value)
		var entry: Dictionary = tags[tag_value]
		_display[tag] = String(entry.get("display_name", tag.capitalize()))
		_gloss[tag] = String(entry.get("gloss", ""))
		_unlock_level[tag] = int(entry.get("unlocked_in_level", 0))
		var members := PackedStringArray()
		for class_value: Variant in (entry.get("classes", {}) as Dictionary).keys():
			var class_id := String(class_value)
			# A tag naming something the recogniser cannot produce is a silent dead end:
			# the obstacle would advertise a solution that can never be drawn.
			if not roster.has(class_id):
				push_error("AbilityTags: tag '%s' names '%s', which is not in the roster"
					% [tag, class_id])
				continue
			members.append(class_id)
			if not _class_tags.has(class_id):
				_class_tags[class_id] = []
			(_class_tags[class_id] as Array).append(tag)
		members.sort()
		_tag_classes[tag] = members
	_loaded = true
	return true


func _load_roster() -> Dictionary:
	var ids: Dictionary = {}
	var text := FileAccess.get_file_as_string(ENTITIES_PATH)
	if text.is_empty():
		return ids
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return ids
	for entity_value: Variant in (parsed as Dictionary).get("entities", []):
		var entity: Dictionary = entity_value
		ids[String(entity.get("id", ""))] = true
	return ids


# --- Queries -----------------------------------------------------------------

func has_tag(tag: String) -> bool:
	return _tag_classes.has(tag)


func all_tags() -> Array:
	var keys := _tag_classes.keys()
	keys.sort()
	return keys


func display_name(tag: String) -> String:
	return String(_display.get(tag, tag.capitalize()))


## What the tag asks the drawing to DO, in a sentence, naming no class -- see GLOSS in
## tools/build_tags.py. Empty for a tag whose data predates the field, and the strip prints
## the name alone in that case rather than an empty line.
func gloss(tag: String) -> String:
	return String(_gloss.get(tag, ""))


func unlock_level(tag: String) -> int:
	return int(_unlock_level.get(tag, 0))


func classes_for_tag(tag: String) -> PackedStringArray:
	return (_tag_classes.get(tag, PackedStringArray()) as PackedStringArray).duplicate()


func tags_for_class(class_id: String) -> Array:
	return (_class_tags.get(class_id, []) as Array).duplicate()


## The tags this class carries that a player IN THIS LEVEL could have met.
##
## TAG MEMBERSHIP IS GLOBAL AND RETROACTIVE, AND THAT LEAKS BACKWARDS. Adding `frog` to
## `startle` for Level 2 immediately changed a Level 1 hint from "A frog can LEAP" to
## "A frog can LEAP or STARTLE" -- naming an ability the game does not hand over for
## another level, at an obstacle that cannot use it. Every future level's memberships
## would do the same to every level before it.
##
## The filter is the tag's own `unlocked_in_level` against the level being played, and
## deliberately NOT the profile: a hint that changes with what some previous run happened
## to unlock is a hint no test can pin down, and `user://profile.json` survives between
## runs. This is a property of where the player IS, not of what they have done.
func tags_for_class_by_level(class_id: String, level_number: int) -> Array:
	var out: Array = []
	for tag_value: Variant in tags_for_class(class_id):
		if unlock_level(String(tag_value)) <= level_number:
			out.append(tag_value)
	return out


## Does this class carry this tag? The question an obstacle asks of a submitted drawing.
func class_has_tag(class_id: String, tag: String) -> bool:
	return (_tag_classes.get(tag, PackedStringArray()) as PackedStringArray).has(class_id)


## The classes that solve an obstacle. This is the whole point of the file.
##
## `exclude` is applied LAST and deliberately: a caller must be able to see the full
## resolved set before exclusions, which is what `resolve_report` exposes for the
## load-time audit.
func resolve(required_tags: Array, match: String = MATCH_ALL, exclude: Array = []) -> PackedStringArray:
	return resolve_report(required_tags, match, exclude)["solutions"]


## resolve(), plus everything the audit needs to explain a failure. Returns
## { solutions, before_exclusions, excluded, unknown_tags, sufficient }.
func resolve_report(required_tags: Array, match: String = MATCH_ALL, exclude: Array = []) -> Dictionary:
	var unknown: Array[String] = []
	var sets: Array[PackedStringArray] = []
	for tag_value: Variant in required_tags:
		var tag := String(tag_value)
		if not _tag_classes.has(tag):
			unknown.append(tag)
			continue
		sets.append(_tag_classes[tag])

	var base: Dictionary = {}  # used as an ordered set
	if not sets.is_empty():
		if match == MATCH_ANY:
			for members in sets:
				for class_id in members:
					base[class_id] = true
		else:
			for class_id in sets[0]:
				var in_every := true
				for other in sets:
					if not other.has(class_id):
						in_every = false
						break
				if in_every:
					base[class_id] = true

	var before := PackedStringArray(base.keys())
	before.sort()
	var removed := PackedStringArray()
	var solutions := PackedStringArray()
	for class_id in before:
		if exclude.has(class_id):
			removed.append(class_id)
		else:
			solutions.append(class_id)

	return {
		"solutions": solutions,
		"before_exclusions": before,
		"excluded": removed,
		"unknown_tags": unknown,
		"sufficient": unknown.is_empty() and solutions.size() >= MIN_SOLUTIONS,
	}


# --- Unlock state ------------------------------------------------------------

## Tags accumulate across levels and never fall, so the store is the player profile
## rather than anything level-scoped. A tag the player does not have is not a refusal:
## the drawing is still accepted and still spawns, it just spawns WITHOUT its ability
## (build spec 3.2). That is why this is only ever a query and never a veto.
## Reached by path, not by name, like every other autoload-to-autoload call in this
## project. Naming the identifier compiles fine in the game but makes this script fail to
## compile under `--script` runners, where autoloads are registered AFTER scripts load --
## and a failed autoload script leaves a live node with no script behind it, which fails
## silently at every call site rather than at the cause.
func _profile() -> Node:
	return get_node_or_null(^"/root/PlayerProfile")


func is_unlocked(tag: String) -> bool:
	var profile := _profile()
	return profile != null and bool(profile.call("is_tag_unlocked", tag))


func unlock(tag: String) -> void:
	if not _tag_classes.has(tag):
		push_warning("AbilityTags: refusing to unlock unknown tag '%s'" % tag)
		return
	var profile := _profile()
	if profile != null:
		profile.call("record_tag_unlocked", tag)


## The player's own qualifying classes for an obstacle -- what the Ability Book shows at
## hint tier 2. Restricted to classes they have actually drawn and had accepted, because
## the book is a record of what they have done, not a catalogue of what exists.
func known_solutions(required_tags: Array, match: String = MATCH_ALL, exclude: Array = []) -> PackedStringArray:
	var profile := _profile()
	var drawn: Array = profile.call("get_drawn_classes") if profile != null else []
	var out := PackedStringArray()
	for class_id in resolve(required_tags, match, exclude):
		if drawn.has(class_id):
			out.append(class_id)
	return out
