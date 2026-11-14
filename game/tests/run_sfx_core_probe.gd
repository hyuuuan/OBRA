extends SceneTree
## The core sounds, headless: each asked for where the screen already shows what it marks.
##
##   godot --headless --path game --script res://tests/run_sfx_core_probe.gd
##
## Headless hears nothing, so what is checked is the ASKING (AudioDirector.sfx_requested fires
## for every play_sfx) and, at the moment of asking, the visual the sound plays beside: Dilim's
## rule, that a player who cannot hear plays the same game. Every sound here is AUDIO_PLAN.md's
## table A: the button, an overlay coming and going, a page, a lantern, a found thing, a lock,
## and a finished level.
##
## `-- <words>` runs only the scenarios whose name holds them (for a mutant); the every-check-ran
## guard stands down for such a run.

const CORE := [&"ui_click", &"ui_open", &"ui_close", &"page_turn", &"checkpoint",
	&"item_acquired", &"unlock", &"level_complete"]
const PAYYO := "res://game_level.tscn"
const MAYON := "res://level_5.tscn"
const HOUSE_DOOR := ^"EnvironmentBaseplate/GameplayPlane/Bale/House"

var failures := 0
var checked := 0
const CHECKS := 13
var level: Node
## Every sound asked for in the current scenario, with what the screen showed as it was asked:
## [id, snapshot]. ⚠ A member, not a local: a lambda captures locals by value.
var heard: Array = []
## What a scenario wants recorded beside each sound, read the moment it is asked for.
var snapshot: Callable = func() -> Dictionary: return {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(300.0).timeout.connect(func() -> void:
		print("OBRA_SFX_CORE_FAILED=watchdog")
		quit(2))
	root.get_node(^"AudioDirector").connect(&"sfx_requested", _on_sfx_requested)
	var only := " ".join(OS.get_cmdline_user_args())
	# Payyo going home is last: it ends the level and loads the house.
	for scenario: Callable in [_every_core_sound_has_a_file, _every_button_clicks,
			_an_overlay_is_heard_coming_and_going, _each_found_thing_chimes_as_its_card_rises,
			_a_page_turns_with_its_sound, _a_checkpoint_is_heard_as_it_is_said,
			_mayon_saves_without_a_sound, _the_key_is_heard_turning,
			_a_finished_level_is_heard_with_its_name, _payyo_goes_home_on_its_jingle]:
		if not only.is_empty() and not String(scenario.get_method()).contains(only):
			continue
		heard.clear()
		snapshot = func() -> Dictionary: return {}
		await scenario.call()
		if level != null and is_instance_valid(level) and not String(scenario.get_method()).begins_with("_payyo"):
			level.queue_free()
			level = null
			await _frames(4)
	if only.is_empty() and checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_SFX_CORE_OK")
		quit(0)
	else:
		print("OBRA_SFX_CORE_FAILED=%d" % failures)
		quit(1)


func _on_sfx_requested(id: StringName, _loudness: float) -> void:
	heard.append([String(id), snapshot.call()])


# --- The scenarios -------------------------------------------------------------------------

## A sound with no file is silence, and nothing else says so: blanking a path is not an error.
func _every_core_sound_has_a_file() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/audio.json"))
	var sfx: Dictionary = catalog.get("sfx", {})
	var silent: Array[String] = []
	for id: StringName in CORE:
		var path := String(sfx.get(String(id), ""))
		if path.is_empty() or not (load(path) is AudioStreamWAV):
			silent.append(String(id))
	_check(silent.is_empty(), "every core sound has a file", "%d of %d" % [CORE.size() - silent.size(), CORE.size()]
		if silent.is_empty() else "silent: " + ", ".join(silent))


## Every button, including the ones built in code: AudioDirector hears each one join the tree.
func _every_button_clicks() -> void:
	var button := Button.new()
	button.text = "Probe"
	root.add_child(button)
	await _frames(1)
	button.pressed.emit()
	_check(_ids() == ["ui_click"], "a button is heard as it is pressed", "%s" % [_ids()])
	button.queue_free()


func _an_overlay_is_heard_coming_and_going() -> void:
	var overlay := (load("res://ui/controls_overlay.tscn") as PackedScene).instantiate() as ModalOverlay
	root.add_child(overlay)
	await _frames(1)
	snapshot = func() -> Dictionary: return {"open": overlay.is_open(), "shown": overlay.visible}
	overlay.open()
	var arrived := _first("ui_open")
	_check(bool(arrived.get("open", false)) and bool(arrived.get("shown", false)),
		"an overlay is heard as it comes up", "%s" % [heard])
	heard.clear()
	overlay.close()
	var left := _first("ui_close")
	_check(not left.is_empty() and not bool(left.get("open", true)) and not _ids().has("ui_open"),
		"and heard again as it goes", "%s" % [heard])
	overlay.queue_free()


## Two things taken in one second are two cards, and the second rises into an overlay already up.
func _each_found_thing_chimes_as_its_card_rises() -> void:
	var overlay := AcquiredOverlay.new()
	root.add_child(overlay)
	await _frames(1)
	snapshot = func() -> Dictionary: return {"title": (overlay.get("_title") as Label).text,
		"open": overlay.is_open()}
	overlay.present("Brass key", "")
	overlay.present("Lola's canvas", "")
	for _frame in range(60 * 10):
		if not overlay.is_busy():
			break
		await _frames(1)
	var titles: Array[String] = []
	for entry: Array in heard:
		if entry[0] == "item_acquired":
			var shown: Dictionary = entry[1]
			titles.append(String(shown.get("title", "")) + ("" if bool(shown.get("open", false)) else " (not up)"))
	_check(titles == ["Brass key", "Lola's canvas"], "each found thing chimes as its card rises",
		"%s" % [titles])
	var others := _ids().filter(func(id: String) -> bool: return id != "item_acquired")
	_check(others.is_empty() and not overlay.is_busy(), "and the card comes and goes under no other sound",
		"the cards never finished" if overlay.is_busy() else "%s" % [others])
	overlay.queue_free()


func _a_page_turns_with_its_sound() -> void:
	var book := DiaryBook.new()
	root.add_child(book)
	await _frames(1)
	var pages: Array[Dictionary] = [{"id": "probe", "pages": ["One.", "Two.", "Three."]}]
	book.set_entries(pages)
	book.open_at("probe")
	heard.clear()
	var refused := not book.turn(-1)
	var before := _ids().size()
	var turned := book.turn(1)
	var turning := book.is_turning()
	_check(refused and before == 0 and turned and turning and _ids() == ["page_turn"],
		"a page is heard turning as it starts to turn, and a page that cannot turn is not",
		"refused %s (%d heard), turned %s, turning %s, %s" % [refused, before, turned, turning, _ids()])
	book.queue_free()


func _a_checkpoint_is_heard_as_it_is_said() -> void:
	await _open(PAYYO, "level_1")
	snapshot = func() -> Dictionary: return {"status": (level.get("status_label") as Label).text}
	level.call("_on_checkpoint_area_reached", "CP1")
	var said := _first("checkpoint")
	_check(String(said.get("status", "")) == "Checkpoint", "a checkpoint is heard as it is said",
		"%s" % [heard])


## Mayon's saves are silent (the team's decision): no lantern, letterbox, line or counter, and no
## sound either.
func _mayon_saves_without_a_sound() -> void:
	await _open(MAYON, "level_5")
	var status := level.get("status_label") as Label
	status.text = ""
	level.call("_on_checkpoint_area_reached", "CP2")
	await _frames(2)
	_check(not _ids().has("checkpoint") and status.text != "Checkpoint", "a save on Mayon is silent",
		"%s, status '%s'" % [_ids(), status.text])


## The door glints, the lock is heard, and Lolo says so: Payyo's key, on the Pragmatist route.
func _the_key_is_heard_turning() -> void:
	await _open(PAYYO, "level_1")
	var house := level.get_node(HOUSE_DOOR) as Node2D
	snapshot = func() -> Dictionary:
		var glint := house.get_children().any(func(child: Node) -> bool: return child is PickupFlourish2D)
		return {"glint": glint}
	level.call("_turn_the_key")
	var heard_it := _first("unlock")
	await _frames(1)
	var hint := String((level.get("hint_bar") as Node).call("current_text"))
	_check(bool(heard_it.get("glint", false)) and hint.contains("key turns"),
		"the key is heard turning as the door glints and Lolo says so",
		"%s, hint '%s'" % [heard, hint])


## LevelBase's ending, which Piyesta, Dagat and Dilim share: the jingle starts with the bars and
## the level's name in them, and the panel arrives into it a second later without one of its own.
func _a_finished_level_is_heard_with_its_name() -> void:
	await _open(PAYYO, "level_1")
	var panel := level.get("complete_overlay") as ModalOverlay
	snapshot = func() -> Dictionary: return {"status": (level.get("status_label") as Label).text,
		"panel": panel.is_open()}
	level.call("_complete_level")
	await _frames(2)
	var jingle := _first("level_complete")
	var caption := _caption()
	_check(_count("level_complete") == 1 and String(jingle.get("status", "")) == "Level complete!"
			and not bool(jingle.get("panel", true)) and caption == _name(),
		"a finished level is heard as its name comes up, before the panel",
		"%s, bars '%s'" % [heard, caption])
	for _frame in range(60 * 3):
		if panel.is_open():
			break
		await _frames(1)
	_check(panel.is_open() and _ids() == ["level_complete"], "and the panel arrives into it unheard",
		"panel up %s, %s" % [panel.is_open(), _ids()])


## Payyo has no panel: it ends with her canvas, the bars and its name, and goes home.
func _payyo_goes_home_on_its_jingle() -> void:
	await _open(PAYYO, "level_1")
	snapshot = func() -> Dictionary: return {"status": (level.get("status_label") as Label).text}
	level.call("_go_home_with_the_canvas")
	for _frame in range(60 * 3):
		if _ids().has("level_complete"):
			break
		await _frames(1)
	await _frames(2)
	var jingle := _first("level_complete")
	var caption := _caption()
	_check(_count("level_complete") == 1 and String(jingle.get("status", "")) == "Level complete!"
			and caption == _name(),
		"Payyo is heard finishing as its name comes up, on the way home",
		"%s, bars '%s'" % [heard, caption])


# --- Helpers -------------------------------------------------------------------------------

func _open(scene: String, level_id: String) -> void:
	root.get_node(^"LevelManager").set("current_level_id", level_id)
	level = (load(scene) as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(40)
	for _frame in range(60 * 10):
		if not bool(level.get("_opening_running")):
			break
		await _frames(1)
	await _settle()
	heard.clear()


## Close what the opening left up, as a player pressing on would: UIRouter derives the pause from
## the open overlays, so writing `paused` alone is overruled on the next refresh.
func _settle() -> void:
	for _attempt in range(10):
		for node in get_nodes_in_group(ModalOverlay.GROUP):
			if node is InventoryScreen:
				continue
			if bool(node.call(&"is_open")):
				node.call(&"close")
		call_group(DialogueBox.GROUP, &"hide_line")
		paused = false
		await physics_frame


func _ids() -> Array:
	return heard.map(func(entry: Array) -> String: return entry[0])


func _count(id: String) -> int:
	return _ids().count(id)


## What the screen showed when `id` was first asked for, or {} if it never was.
func _first(id: String) -> Dictionary:
	for entry: Array in heard:
		if entry[0] == id:
			return entry[1]
	return {}


## The level's name as its bars show it.
func _name() -> String:
	var manager := root.get_node(^"LevelManager")
	var title := String((manager.call("get_level", manager.get("current_level_id")) as Dictionary).get("title", ""))
	return title.to_upper() if not title.is_empty() else "(no title)"


## The words in the level's letterbox.
func _caption() -> String:
	var bars := level.get("cinematic") as Node
	var label := bars.get("_caption") as Label if bars != null else null
	return label.text if label != null and bool(bars.call("is_playing")) else ""


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
