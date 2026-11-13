extends SceneTree
## The bag screen's roster -- what the player knows, and the shape of what they do not.
##
##   godot --headless --path game --script res://tests/run_book_probe.gd
##
## ⚠ THIS SCREEN WALKS A LINE AND BOTH SIDES OF IT ARE ASSERTED HERE.
##
## The line: this game never names a drawable class the player has not earned. It is why
## `RequirementStrip` prints ability TAGS, why no line of dialogue may name a class, and why
## the tutorial may not either. Printing the fifty would turn every obstacle into a lookup.
##
## And the other side: a player who cannot tell that the roster HAS twenty animals in it
## will never think to draw one. Counting a group names nothing, so the bands say how many
## creatures, objects and shapes exist and how many of each this player has drawn -- and the
## ones they have not drawn are unnamed frames with no tooltip and nothing to click.

var level: Node2D
var screen: InventoryScreen
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-52s %s" % ["OK  " if ok else "FAIL", what, detail])


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _grid(role: String) -> GridContainer:
	return (screen.get("_band_grids") as Dictionary).get(role) as GridContainer


func _count_text(role: String) -> String:
	var label := (screen.get("_band_counts") as Dictionary).get(role) as Label
	return label.text if label != null else ""


## Every name any frame in the roster is showing right now.
func _names_on_screen() -> Array[String]:
	var shown: Array[String] = []
	for band: Variant in InventoryScreen.BANDS:
		var grid := _grid(String((band as Dictionary)["role"]))
		if grid == null:
			continue
		for child in grid.get_children():
			for inner in child.get_children():
				var label := inner as Label
				if label != null and not label.text.is_empty():
					shown.append(label.text)
	return shown


func _run() -> void:
	level = (load("res://game_level.tscn") as PackedScene).instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.2)
	screen = level.get("inventory_screen") as InventoryScreen
	var profile := root.get_node_or_null("PlayerProfile")
	# A fresh book: nothing drawn.
	(profile.get("_data")["classes_drawn_accepted"] as Array).clear()
	screen.call("open")
	await _wait(0.4)

	# --- the bands are the manifest's own split ------------------------------------------
	_check(_count_text("active_ragdoll_morph") == "0 / 20",
		"twenty creatures exist and none are known yet",
		_count_text("active_ragdoll_morph"))
	_check(_count_text("utility") == "0 / 27", "twenty-seven objects",
		_count_text("utility"))
	_check(_count_text("physics_morph") == "0 / 3", "three shapes",
		_count_text("physics_morph"))

	# --- ⚠ AND NOTHING IS NAMED ----------------------------------------------------------
	var named := _names_on_screen()
	_check(named.is_empty(),
		"an empty book names no class at all",
		"nothing on screen" if named.is_empty()
		else "PRINTS THE ANSWERS: %s" % ", ".join(named))

	# --- draw three things, and only those three are named -------------------------------
	for id in ["frog", "ladder", "circle"]:
		profile.call("record_class_drawn", id)
	screen.call("refresh")
	await _wait(0.3)
	_check(_count_text("active_ragdoll_morph") == "1 / 20"
		and _count_text("utility") == "1 / 27"
		and _count_text("physics_morph") == "1 / 3",
		"one of each kind lands in its own band",
		"%s · %s · %s" % [_count_text("active_ragdoll_morph"),
			_count_text("utility"), _count_text("physics_morph")])
	named = _names_on_screen()
	named.sort()
	_check(", ".join(named) == "Circle, Frog, Ladder",
		"and the named frames are exactly what was drawn",
		", ".join(named))

	# --- a band holds a frame per class, drawn or not -------------------------------------
	_check(_grid("active_ragdoll_morph").get_child_count() == 20,
		"the creature band has twenty frames whether or not they are known",
		"%d frames" % _grid("active_ragdoll_morph").get_child_count())

	# --- ⚠ AND IT DESCRIBES A TOOL AS A TOOL ----------------------------------------------
	# Every "utility" read "a thing you hold or set down", which is the placeable's rule
	# printed under an axe. A tool is kept; a placeable is set down. And the bag no longer
	# talks about ink at all -- the gauge says what is left.
	var bag := level.get("inventory_manager") as Node
	for id in ["axe", "ladder"]:
		var item := DrawnItemData.new()
		item.entity_id = id
		item.display_name = id.capitalize()
		item.ink_committed = id == "axe"
		bag.call("add_item", item)
	var notes: Dictionary = {}
	var stored: Array = bag.call("items")
	for index in range(stored.size()):
		var item := stored[index] as DrawnItemData
		if item == null:
			continue
		screen.call("_choose_bag", index)
		await _wait(0.1)
		notes[item.entity_id] = (screen.get("_detail_note") as Label).text
	_check(String(notes.get("axe", "")).contains("keep"),
		"an axe in the bag is described as a tool you keep", String(notes.get("axe", "")))
	_check(String(notes.get("ladder", "")).contains("set down"),
		"and a ladder as a thing you set down", String(notes.get("ladder", "")))
	var inky: Array[String] = []
	for label in screen.find_children("*", "Label", true, false):
		if (label as Label).is_visible_in_tree() and (label as Label).text.to_lower().contains("ink"):
			inky.append((label as Label).text)
	_check(inky.is_empty(), "and nothing on the bag mentions ink",
		"none" if inky.is_empty() else ", ".join(inky))

	await _a_face_down_card_hints()

	print("OBRA_BOOK_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)


## The fifty in Filipino, as run_diary_probe lists them: a hint may name none of them either.
const FILIPINO := ["tulay", "hagdan", "hagdanan", "pinto", "puno", "susi", "ulap", "ibon", "isda",
	"gagamba", "unggoy", "palaka", "pating", "pugita", "alimango", "kabayo", "elepante", "ahas",
	"pagong", "langgam", "bubuyog", "baboy", "alakdan", "palakol", "espada", "kanyon", "payong",
	"orasan", "gulong", "tinapay", "balde", "gunting", "kalaykay", "paniki", "paruparo",
	"siga", "pamaypay", "submarino", "parasyut", "palihan", "bilog", "parisukat", "tatsulok"]


## ⚠ A FACE-DOWN CARD HINTS BY ITS NAME SCRAMBLED, AND A SHORT LINE. Kent: "it should be the name
## now but in scrambled letters and its very short description. like for example a DOG = ODG".
## Clicked -- or reached with the arrows -- a card not yet drawn shows its own name with the letters
## shuffled and one line about it; nothing on the screen spells the class or any other; and the
## look is logged as assistance.
func _a_face_down_card_hints() -> void:
	var roster: Dictionary = screen.get("_roster_buttons")
	var tags := root.get_node_or_null("AbilityTags")
	var pick := ""
	for id: String in roster:
		if not profile_drawn().has(id) and not (tags.call("tags_for_class", id) as Array).is_empty():
			pick = id
			break
	if pick.is_empty():
		_check(false, "a face-down card exists to try", "none found")
		return
	# Taught one thing it does, the way a level teaches it at its first gate: the skills the card
	# used to list would show now, so the check that they are gone can fail.
	tags.call("unlock", String((tags.call("tags_for_class", pick) as Array)[0]))
	var log_before := _telemetry_lines()
	(roster[pick] as Button).pressed.emit()
	await _wait(0.2)
	var chosen: Dictionary = screen.get("_chosen")
	var title := (screen.get("_detail_title") as Label).text
	var hint := (screen.get("_ability_text") as Label).text
	var real := String((screen.get("registry") as Node).call("get_entity", pick).get("display_name", ""))
	_check(String(chosen.get("kind", "")) == "locked" and title == InventoryScreen.scrambled_name(real)
		and title != real.to_upper() and _letters(title) == _letters(real),
		"a face-down card can be picked, and shows its name scrambled",
		"chosen %s, title \"%s\"" % [str(chosen), title])
	_check(not hint.is_empty() and hint == InventoryScreen.locked_hint(pick),
		"and says its one short line", "\"%s\"" % hint)
	var chips := (screen.get("_skills_flow") as Node).find_children("*", "Label", true, false)
	var shown_chips := chips.filter(func(chip: Node) -> bool: return (chip as Label).is_visible_in_tree())
	_check(shown_chips.is_empty(), "and no longer lists its skills", "%d chips" % shown_chips.size())
	# Every word the hint puts up -- the big card and its plaques, its skill chips -- and on the
	# face-down card itself. (Drawn cards elsewhere on the screen are named, as they should be.)
	var said: Array[String] = []
	for field in ["_detail_title", "_detail_kind", "_detail_number", "_ability_verb", "_ability_text",
			"_detail_blank", "_detail_note", "_moves_value"]:
		var label := screen.get(field) as Label
		if label != null and label.is_visible_in_tree():
			said.append(label.text.to_lower())
	for chip in (screen.get("_skills_flow") as Node).find_children("*", "Label", true, false):
		said.append((chip as Label).text.to_lower())
	var card := roster[pick] as Button
	said.append(card.tooltip_text.to_lower())
	for label in card.find_children("*", "Label", true, false):
		said.append((label as Label).text.to_lower())
	var spoken := " ".join(said)
	var named := _names_in(spoken)
	_check(named.is_empty(), "and nothing on the screen names its class",
		"names nothing" if named.is_empty() else "NAMES: %s" % ", ".join(named))
	_check(not spoken.contains("ink"), "and nothing on it mentions ink",
		"none" if not spoken.contains("ink") else "SAYS: %s" % spoken)
	var logged := false
	for line: String in _telemetry_lines().slice(log_before.size()):
		var event: Variant = JSON.parse_string(line)
		if event is Dictionary and String(event.get("type", "")) == "locked_card_hint" \
				and String(event.get("entity_id", "")) == pick and bool(event.get("assisted", false)):
			logged = true
	_check(logged, "and the look is logged as assistance", "locked_card_hint, assisted")
	# And the arrows reach a face-down card, as the mouse does.
	var choices: Array = screen.call("_choices")
	var face_down := 0
	for choice: Variant in choices:
		if String((choice as Dictionary).get("kind", "")) == "locked":
			face_down += 1
	_check(face_down == 50 - profile_drawn().size(), "and the arrows can reach every face-down card",
		"%d of %d" % [face_down, 50 - profile_drawn().size()])


## A name's letters, sorted, without its spaces: two names with the same are anagrams.
func _letters(text: String) -> String:
	var letters := Array(text.to_upper().replace(" ", "").split(""))
	letters.sort()
	return "".join(PackedStringArray(letters))


func profile_drawn() -> Array:
	return root.get_node("PlayerProfile").call("get_drawn_classes")


## Which classes, in English or Filipino, `text` names as a whole word.
func _names_in(text: String) -> Array[String]:
	var words: Array[String] = []
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/entities.json"))
	var entities: Array = (manifest as Dictionary).get("entities", []) if manifest is Dictionary else manifest
	for entry: Variant in entities:
		var e := entry as Dictionary
		for term: String in [String(e.get("id", "")).replace("_", " "), String(e.get("display_name", ""))]:
			if not term.is_empty():
				words.append(term.to_lower())
	words.append_array(FILIPINO)
	var found: Array[String] = []
	var regex := RegEx.new()
	for word in words:
		regex.compile("\\b%s\\b" % word)
		if regex.search(text) != null and not found.has(word):
			found.append(word)
	return found


func _telemetry_lines() -> Array:
	var telemetry := root.get_node_or_null("Telemetry")
	var file: Variant = telemetry.get("_file") if telemetry != null else null
	if not (file is FileAccess):
		return []
	var text := FileAccess.get_file_as_string((file as FileAccess).get_path_absolute())
	return Array(text.split("\n", false))
