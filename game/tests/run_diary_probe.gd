extends SceneTree
## Lola's diary: its pages, its book, its tab in the bag, and the page shown as it is found.
##
##   godot --headless --path game --script res://tests/run_diary_probe.gd
##
## THE DATA (config/diary.json) is held to the two rules every line in this game is held to --
## it names no drawable class, in English or Filipino, and it is reachable: every entry is given
## by some level's script. And to the book's own: every page fits its page, because the book
## does not scroll. THE ART is held to having no ribbon tab left in it. THE BOOK turns forward and
## back through its frames and stops at both ends. THE BAG has a fourth tab that shows the book
## in place of the pockets and cards, at the same size. A FOUND PAGE is kept before it is shown.

## Every check this probe makes. A script error that skips them must not pass as quiet.
const CHECKS := 20

const ENTITIES_PATH := "res://config/entities.json"
## The fifty in Filipino, as a player in the Philippines might write them. Not "bangka" (the
## story's word for Lolo's boat since Dagat) and not "araw" (it is "day" far more than "sun").
const FILIPINO := ["tulay", "hagdan", "hagdanan", "pinto", "puno", "susi", "ulap", "ibon", "isda",
	"gagamba", "unggoy", "palaka", "pating", "pugita", "alimango", "kabayo", "elepante", "ahas",
	"pagong", "langgam", "bubuyog", "baboy", "alakdan", "palakol", "espada", "kanyon", "payong",
	"orasan", "gulong", "tinapay", "balde", "gunting", "kalaykay", "paniki", "paruparo",
	"siga", "pamaypay", "submarino", "parasyut", "palihan", "bilog", "parisukat", "tatsulok"]
## The ribbons' colours (tools/build_diary_book.py); none may survive into the book.
const RIBBON := [Color8(165, 48, 48), Color8(228, 59, 68), Color8(207, 87, 60), Color8(117, 36, 56),
	Color8(235, 237, 233), Color8(247, 118, 34), Color8(255, 255, 255), Color8(199, 207, 204)]

var failures := 0
var checked := 0
var _dismissed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile := root.get_node("PlayerProfile")
	profile.call("reset_progress")
	_every_entry_is_whole_and_names_nothing()
	_every_page_fits_its_page()
	_every_entry_is_given_somewhere()
	_the_book_has_no_ribbons()
	_the_profile_keeps_pages(profile)
	await _the_book_turns(profile)
	await _the_bag_has_a_diary_tab(profile)
	await _a_found_page_is_kept_then_shown(profile)
	await _piyesta_drops_a_page_in_each_room(profile)
	profile.call("reset_progress")
	if checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_DIARY_OK")
		quit(0)
	else:
		print("OBRA_DIARY_FAILED=%d" % failures)
		quit(1)


# --- The pages ------------------------------------------------------------------------

func _every_entry_is_whole_and_names_nothing() -> void:
	var entries := Diary.entries()
	var broken: Array[String] = []
	var ids := {}
	for entry in entries:
		var id := String(entry.get("id", ""))
		if id.is_empty() or ids.has(id) or String(entry.get("level_id", "")).is_empty() \
				or String(entry.get("found", "")).is_empty() or (entry.get("pages", []) as Array).is_empty():
			broken.append(id if not id.is_empty() else "(no id)")
		ids[id] = true
	_check(not entries.is_empty() and broken.is_empty(), "every entry has an id, a painting, a find and pages",
		"%d entries%s" % [entries.size(), "" if broken.is_empty() else ", broken: %s" % ", ".join(broken)])
	var terms := _class_terms()
	var named: Array[String] = []
	for entry in entries:
		var words := "%s %s" % [entry.get("date", ""), entry.get("found", "")]
		for page: Variant in entry.get("pages", []):
			words += " " + Diary.page_text(page)
		var hit := _names_a_class(words, terms)
		if not hit.is_empty():
			named.append("%s names '%s'" % [entry.get("id", "?"), hit])
	_check(named.is_empty(), "no page names a drawable class, in English or Filipino",
		"%d terms" % terms.size() if named.is_empty() else "; ".join(named))


func _every_page_fits_its_page() -> void:
	var over: Array[String] = []
	var pages := 0
	var tallest := 0
	for entry in Diary.entries():
		var count := (entry.get("pages", []) as Array).size()
		for index in range(count):
			pages += 1
			var tall := DiaryBook.content_height(entry, index, index % 2)
			tallest = maxi(tallest, tall)
			if DiaryBook.overflows(entry, index, index % 2):
				over.append("%s page %d (%d px)" % [entry.get("id", "?"), index + 1, tall])
	# A measure that says zero measured nothing: it is how a page three times too long fitted.
	var room := int(DiaryBook.text_rect(0).size.y)
	_check(pages > 0 and tallest > 0 and over.is_empty(), "every page fits its page (the book does not scroll)",
		"%d pages, the fullest %d of %d px" % [pages, tallest, room] if over.is_empty() 			else "runs over %d px: %s" % [room, ", ".join(over)])


## Both directions of the contract: a page nobody can find is a page nobody wrote.
func _every_entry_is_given_somewhere() -> void:
	var sources := ""
	var dir := DirAccess.open("res://scripts")
	for file in dir.get_files():
		if file.ends_with(".gd"):
			sources += FileAccess.get_file_as_string("res://scripts/" + file)
	var lost: Array[String] = []
	for entry in Diary.entries():
		var id := String(entry.get("id", ""))
		if not sources.contains("\"%s\"" % id):
			lost.append(id)
	_check(lost.is_empty(), "every entry is given by some level's script",
		"%d entries" % Diary.entries().size() if lost.is_empty() else "never given: %s" % ", ".join(lost))


# --- The art --------------------------------------------------------------------------

func _the_book_has_no_ribbons() -> void:
	var sheet := DiaryBook.SHEET.get_image()
	var ribbon := 0
	for y in range(sheet.get_height()):
		for x in range(sheet.get_width()):
			var pixel := sheet.get_pixel(x, y)
			if pixel.a > 0.0 and RIBBON.has(Color(pixel.r, pixel.g, pixel.b, 1.0)):
				ribbon += 1
	var shape := Vector2i(DiaryBook.FRAME.x * (DiaryBook.REST + 1), DiaryBook.FRAME.y)
	_check(sheet.get_size() == shape and ribbon == 0, "the book is eight frames with no tab left on it",
		"%s, %d ribbon pixels" % [sheet.get_size(), ribbon])


# --- The profile ----------------------------------------------------------------------

func _the_profile_keeps_pages(profile: Node) -> void:
	profile.call("record_diary_page", "payyo")
	profile.call("record_diary_page", "payyo")
	var once := (profile.call("diary_pages") as Array) == ["payyo"]
	profile.call("load_profile")
	var kept := bool(profile.call("has_diary_page", "payyo"))
	var older := profile.call("_merge_defaults", {"schema_version": 5}) as Dictionary
	var merged := older.get("diary_pages") is Array and (older["diary_pages"] as Array).is_empty()
	profile.call("reset_progress")
	var gone := (profile.call("diary_pages") as Array).is_empty()
	_check(once and kept and merged and gone,
		"a page is kept once, survives a reload, starts empty on an older save, goes on a new game",
		"once %s, reloaded %s, older save %s, new game %s" % [once, kept, merged, gone])


# --- The book -------------------------------------------------------------------------

func _the_book_turns(profile: Node) -> void:
	var book := DiaryBook.new()
	root.add_child(book)
	await process_frame
	var empty := book.spread_count() == 1 and book.page_texts()[0] == DiaryBook.EMPTY
	_check(empty, "an empty diary says its pages are out there", book.page_texts()[0])

	var three: Array[Dictionary] = [{"id": "probe", "date": "Monday", "pages": ["One.", {"text": "Two.", "anchor": "two"}, "Three."]},
		{"id": "after", "pages": ["Four."]}]
	book.set_entries(three)
	var shape := book.spread_count() == 3 and book.page_texts()[0].begins_with("Monday") \
		and book.page_texts()[1] == "Two."
	book.open_at("probe", "two")
	var anchored := book.spread_index() == 0
	book.open_at("after")
	var own_spread := book.spread_index() == 2 and book.page_texts()[1] == ""
	_check(shape and anchored and own_spread,
		"an entry starts on a left page, dated, and the book opens at an entry or a page of it",
		"%d spreads, anchored %s, next entry on its own spread %s" % [book.spread_count(), anchored, own_spread])

	book.open_at("probe")
	var frames: Array[int] = []
	var started := book.turn(1)
	var hidden := book.page_texts()[0] == ""
	while book.is_turning():
		if frames.is_empty() or frames.back() != book.frame():
			frames.append(book.frame())
		await process_frame
	var landed := book.spread_index() == 1 and book.page_texts()[0] == "Three." and book.frame() == DiaryBook.REST
	_check(started and hidden and frames == [0, 1, 2, 3, 4, 5, 6] and landed,
		"a page turns forward through every frame, words off the page in flight",
		"frames %s, landed on %d" % [frames, book.spread_index()])

	frames.clear()
	book.turn(-1)
	while book.is_turning():
		if frames.is_empty() or frames.back() != book.frame():
			frames.append(book.frame())
		await process_frame
	var at_start := book.spread_index() == 0
	var refused := not book.turn(-1)
	book.open_at("after")
	var refused_end := not book.turn(1)
	_check(frames == [6, 5, 4, 3, 2, 1, 0] and at_start and refused and refused_end,
		"and back the other way, and it stops at both covers",
		"frames %s, back at %d, past the front %s, past the back %s" % [frames, book.spread_index(),
			not refused, not refused_end])

	profile.call("set_setting", "reduce_motion", true)
	book.open_at("probe")
	book.turn(1)
	var still := not book.is_turning() and book.spread_index() == 1
	profile.call("set_setting", "reduce_motion", false)
	book.open_at("probe")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(book.size.x * 0.75, book.size.y * 0.5)
	book._gui_input(click)
	var clicked := book.is_turning()
	_check(still and clicked, "reduced motion turns at once; a click on the right page turns on",
		"reduced %s, clicked %s" % [still, clicked])
	book.queue_free()
	await process_frame


# --- The bag --------------------------------------------------------------------------

func _the_bag_has_a_diary_tab(profile: Node) -> void:
	profile.call("reset_progress")
	var screen := InventoryScreen.new()
	root.add_child(screen)
	await process_frame
	screen.open()
	await _settle(screen)
	var tabs := screen.get("_tab_buttons") as Dictionary
	var tab := tabs.get(InventoryScreen.DIARY_TAB) as Button
	var total := Diary.entries().size()
	var counted := tab != null and tab.text == "DIARY\n0 / %d" % total
	_check(tabs.size() == 4 and counted, "the bag has a fourth tab, DIARY, counting pages found",
		"%d tabs, reads \"%s\"" % [tabs.size(), tab.text.replace("\n", " ") if tab != null else "-"])

	# The bag, not the panel: the open tab sticks out as far as its own label needs, so the tabs'
	# column is a few pixels wider under CREATURES than under OBJECTS, as it always was.
	var panel := screen.find_child("Panel", true, false) as Control
	var bag := screen.find_child("Bag", true, false) as Control
	var bag_size := bag.size
	screen.close()
	profile.call("record_diary_page", "payyo")
	screen.open()
	await _settle(screen)
	tab.emit_signal(&"pressed")
	await _settle(screen)
	var body := screen.find_child("Body", true, false) as Control
	var book := screen.diary_book()
	var reading := not body.visible and book.is_visible_in_tree() \
		and book.page_texts()[1].contains("while I still know the way") \
		and tab.text == "DIARY\n1 / %d" % total
	_check(reading, "its tab shows the book in place of the pockets and cards, open at the new page",
		"body shown %s, book shown %s, right page \"%s\"" % [body.visible, book.is_visible_in_tree(),
			book.page_texts()[1].left(40)])
	var same := bag.size == bag_size and panel.size.y <= 900.0 and panel.size.x <= 1600.0
	_check(same, "and the bag is the same size on every tab, inside 1600 x 900",
		"%s on the cards, %s on the diary, %s with its tabs" % [bag_size, bag.size, panel.size])

	# The arrows turn her pages here -- not step through the pockets. One entry found is one
	# spread, with nowhere to turn to, so the book is given three for this.
	var three: Array[Dictionary] = [{"id": "a", "pages": ["One.", "Two."]}, {"id": "b", "pages": ["Three."]},
		{"id": "c", "pages": ["Four."]}]
	book.set_entries(three)
	book.open_at("a")
	var right := InputEventAction.new()
	right.action = &"ui_right"
	right.pressed = true
	screen._input(right)
	var turned := book.is_turning()
	var chosen_before := (screen.get("_chosen") as Dictionary).is_empty()
	(tabs.get("active_ragdoll_morph") as Button).emit_signal(&"pressed")
	await _settle(screen)
	_check(turned and chosen_before and body.visible and not book.is_visible_in_tree(),
		"the arrows turn the page on the diary, and the cards come back on their own tab",
		"turned %s, nothing chosen %s, cards back %s" % [turned, chosen_before, body.visible])
	screen.close()
	screen.queue_free()
	await process_frame


func _settle(screen: InventoryScreen) -> void:
	for _frame in range(30):
		await process_frame
		if screen.is_settled():
			break
	await process_frame


# --- A page, found --------------------------------------------------------------------

func _a_found_page_is_kept_then_shown(profile: Node) -> void:
	profile.call("reset_progress")
	var level := (load("res://game_level.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(30):
		await physics_frame
	call_group(DialogueBox.GROUP, &"hide_line")
	var overlay := level.get("diary_overlay") as DiaryOverlay
	var chain: Array = level.get_node("UIRouter").get(&"cancel_chain")
	var queued := chain.has(level.get_node("UIRouter").get_path_to(overlay))
	level.call("find_diary_page", "payyo")
	await process_frame
	var kept := bool(profile.call("has_diary_page", "payyo"))
	var title := (overlay.find_child("Title", true, false) as Label).text
	var note := (overlay.find_child("Note", true, false) as Label).text
	var shown := overlay.is_open() and paused and title == "A PAGE OF HER DIARY" \
		and note.begins_with("A page from her diary") \
		and overlay.book().page_texts()[0].begins_with("Sunday")
	_check(queued and kept and shown, "a found page is kept, then opens in the book with the game held",
		"in the Escape queue %s, kept %s, open %s, paused %s, \"%s\"" % [queued, kept, overlay.is_open(),
			paused, title])
	overlay.dismissed.connect(_on_dismissed)
	var cancelled := overlay.handle_cancel()
	await process_frame
	_check(cancelled and not overlay.is_open() and _dismissed and not paused,
		"Escape puts it down, says so, and the game goes on",
		"closed %s, dismissed %s, paused %s" % [not overlay.is_open(), _dismissed, paused])
	level.queue_free()
	await process_frame


# --- Pages lying in a level ---------------------------------------------------------

## Piyesta: one in the nave and one in each alley between its doors; walked into, a page is found
## and the book opens; and a page this save already holds is not lying there next time.
func _piyesta_drops_a_page_in_each_room(profile: Node) -> void:
	profile.call("reset_progress")
	var level := await _open("res://level_2.tscn")
	var where := {}
	for node in level.find_children("*", "DiaryPage2D", true, false):
		var page := node as DiaryPage2D
		where[page.entry_id] = page
	var placed: Array[String] = []
	var rooms := {"piyesta_church": "church", "piyesta_alley_1": "alley_1", "piyesta_alley_2": "alley_2"}
	for entry_id: String in rooms:
		var page := where.get(entry_id) as DiaryPage2D
		var room := level.get(String(rooms[entry_id])) as Node2D
		if page == null or room == null or page.get_parent() != room:
			continue
		var span := Vector2(-float(room.get("room_length")) * 0.5, float(room.get("room_length")) * 0.5)
		if entry_id != "piyesta_church":
			span = level.call("_between_the_doors", room)
		if page.position.x > span.x and page.position.x < span.y and is_zero_approx(page.position.y):
			placed.append(entry_id)
	_check(where.size() == 3 and placed.size() == 3,
		"Piyesta lays a page in the nave and in each alley, on the floor she walks",
		"%d pages, %s on their floors" % [where.size(), ", ".join(placed)])

	# Walked into, as a player does: she is set down on the nave's floor where it lies.
	var church_page := where.get("piyesta_church") as DiaryPage2D
	var player := level.get("player") as Node2D
	var overlay := level.get("diary_overlay") as DiaryOverlay
	if church_page != null and player != null:
		player.global_position = church_page.global_position + Vector2(0.0, -30.0)
		for _frame in range(30):
			await physics_frame
			if overlay.is_open():
				break
	var found := bool(profile.call("has_diary_page", "piyesta_church"))
	_check(found and overlay.is_open() and overlay.book().page_texts()[0].begins_with("Fiesta Sunday")
		and (church_page == null or not is_instance_valid(church_page) or church_page.is_taken()),
		"walked into, a page is found and the book opens at it",
		"kept %s, book open %s" % [found, overlay.is_open()])
	overlay.close()
	level.queue_free()
	await process_frame

	level = await _open("res://level_2.tscn")
	await process_frame
	var left: Array[String] = []
	for node in level.find_children("*", "DiaryPage2D", true, false):
		if not (node as DiaryPage2D).is_queued_for_deletion():
			left.append((node as DiaryPage2D).entry_id)
	left.sort()
	_check(left == ["piyesta_alley_1", "piyesta_alley_2"], "a page already found is not lying there again",
		"left lying: %s" % ", ".join(left))
	level.queue_free()
	await process_frame


func _open(scene: String) -> Node:
	var level := (load(scene) as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(30):
		await physics_frame
	call_group(DialogueBox.GROUP, &"hide_line")
	paused = false
	return level


func _on_dismissed() -> void:
	_dismissed = true


# --- Helpers --------------------------------------------------------------------------

func _class_terms() -> Array[String]:
	var terms: Array[String] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ENTITIES_PATH))
	for entity_value: Variant in (parsed as Dictionary).get("entities", []):
		var entity: Dictionary = entity_value
		terms.append(String(entity.get("id", "")).replace("_", " "))
		terms.append(String(entity.get("display_name", "")))
	for word: String in FILIPINO:
		terms.append(word)
	return terms


func _names_a_class(body: String, terms: Array[String]) -> String:
	for term in terms:
		if term.is_empty():
			continue
		var pattern := RegEx.new()
		pattern.compile("(?i)\\b%s\\b" % term.replace(" ", "\\s+"))
		if pattern.search(body) != null:
			return term
	return ""


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
