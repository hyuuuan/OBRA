extends SceneTree
## Does the tutorial level actually teach?
##
## Level 1 IS the tutorial and taught nothing: the controls screen is a reference behind
## the pause menu, ActionPromptHUD shows four caps with no sentence, and walking, jumping,
## the mouse, the bag and the ten-second clock were said nowhere. This proves the lessons
## exist, say a real key, name no drawable class, and can actually fire.

const LEDGER := "res://config/tutorial.json"
const LEVEL_BASE := "res://scripts/level_base.gd"
const TutorialScript = preload("res://scripts/tutorial_director.gd")
const CONTROLS := "res://config/controls.json"
## Controls that have no lesson, deliberately: `skip_tutorial` is printed on every card, which is
## the only place it does anything. (`pause` was cut once, and is back: see below.)
const UNTAUGHT_ON_PURPOSE := ["skip_tutorial"]
## A controls row that names the mouse, and the name a lesson's `mouse` list gives it.
const MOUSE_ROWS := {"Left click": "left", "Right click": "right", "Scroll": "wheel",
	"Shift + Scroll": "shift_wheel"}
## Every card shown outside Level 1, and why Level 1 cannot be the place it is taught.
const NECESSARY_CARDS := {
	"new_brush": "Dagat's brush changes the ink rule, and Level 1 never has that brush",
	"jars": "the only refill, in a sea Level 1 does not have",
	"lamp": "Dilim's lamp is her life, and nothing else in the game has one",
	"swing": "the click only swings in Dilim",
}
## Where each level's lesson events are fired, besides LevelBase. Every level in the ledger
## must be here: one that is not fails, rather than having its events looked for in the
## wrong file and passing or failing by accident.
const LEVEL_SCRIPTS := {
	"level_1": [],
	"level_3": ["res://scripts/level_3.gd"],
	"level_4": ["res://scripts/level_4.gd"],
	"level_5": ["res://scripts/level_5.gd"],
}

var _passed := 0
var _failed := 0


func _check(ok: bool, what: String, detail: String = "") -> void:
	if ok:
		_passed += 1
		print("  OK    %-44s %s" % [what, detail])
	else:
		_failed += 1
		print("  FAIL  %-44s %s" % [what, detail])


func _initialize() -> void:
	print("--- tutorial ---")
	var ledger: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LEDGER))
	# ⚠ EVERY LEVEL'S LESSONS, NOT ONLY THE TUTORIAL LEVEL'S. This read only level_1, so
	# Dagat's cards were never held to any of it -- and its first card's caption ran to ten
	# words, two past the rule, the whole time.
	for level_id: String in ledger["levels"]:
		_audit_level(ledger, level_id)

	# Level 1 IS the tutorial: the order it teaches in, and what it was cut down to.
	var lessons: Array = ledger["levels"]["level_1"]["lessons"]
	var ids: Array[String] = []
	for value: Variant in lessons:
		ids.append(String((value as Dictionary)["id"]))
	var director := TutorialScript.new()
	root.add_child(director)
	director.load_for("level_1")

	# 5. Spent once. A lesson that re-teaches is the interruption this replaced.
	director.note("level_start")
	var first := director.taught_count()
	director.note("level_start")
	_check(director.taught_count() == first, "a lesson is spent once",
		"%d taught after two identical events" % director.taught_count())
	_check(director.has_taught("move"), "level_start teaches walking", "move")

	# 6. One lesson per event per call: the placement's three lessons are three placements,
	#    not one placement with three things said over it. Resize before turning -- the lake
	#    is crossed by a drawing made longer, and that comes before anything wants turning.
	director.note("placement_started")
	_check(director.has_taught("place") and not director.has_taught("resize"),
		"two lessons on one event do not collide", "place taught, resize still waiting")
	director.note("placement_started")
	_check(director.has_taught("resize") and not director.has_taught("rotate"),
		"and the second arrives next time", "resize")
	director.note("placement_started")
	_check(director.has_taught("rotate"), "and the third the time after", "rotate")

	# 8. LESS OF IT. Kent: "its just knowledge dumping at this point". Two of the four cut on that
	#    pass stay cut. `pause` is back: every card now plays at the door, and Escape's list of
	#    controls is where a player who has forgotten one of them goes. Every card costs every
	#    new player a card before their first step, so the list stays under thirty -- a new one
	#    has to raise this on purpose.
	for cut in ["sure", "sign"]:
		_check(not ids.has(cut), "'%s' stays cut" % cut, "absent" if not ids.has(cut) else "BACK")
	_check(ids.has("pause"), "and Escape is taught, for everything else", "pause")
	_check(lessons.size() < 30, "Level 1 says fewer than thirty things", "%d" % lessons.size())
	_check(not ledger["levels"]["level_1"].has("canvas_briefing"),
		"the canvas is taught by cards, not four lines of Lolo", "no briefing")

	_audit_level_1_covers_every_control(lessons, director)
	_audit_level_1_teaches_at_the_door(lessons)
	_audit_later_levels_only_say_what_changes(ledger)
	_audit_what_a_route_can_miss(ledger)

	print("--- %d passed, %d failed ---" % [_passed, _failed])
	print("OBRA_TUTORIAL_FAILED=%d" % _failed if _failed > 0 else "OBRA_TUTORIAL_OK")
	quit(1 if _failed > 0 else 0)


## LEVEL 1 COVERS EVERYTHING. Kent: "fix level 1 like tutorial part make sure it covers
## everything". The controls screen is the list of what the game can do, so it is what this reads:
## a row that works in Level 1 and that no lesson teaches is a control the game never mentions.
## `E` was exactly that, with an anchor waiting for it the whole time.
func _audit_level_1_covers_every_control(lessons: Array, director: Node) -> void:
	print("  -- Level 1 covers every control --")
	var taught_actions := {}
	var taught_mouse := {}
	for value: Variant in lessons:
		var lesson: Dictionary = value
		for action: String in director.actions_for(lesson):
			taught_actions[action] = true
		for button: Variant in lesson.get("mouse", []):
			taught_mouse[String(button)] = true
	var controls: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTROLS))
	var rows := 0
	for value: Variant in controls["rows"]:
		var row: Dictionary = value
		# A row for another level does nothing here, and teaching it would be a false lesson.
		if row.has("levels") and not (row["levels"] as Array).has("level_1"):
			continue
		var action := String(row.get("action", ""))
		if UNTAUGHT_ON_PURPOSE.has(action):
			continue
		rows += 1
		if not action.is_empty():
			# A run of keys (inventory_slot_1 .. 6) is taught if its first and last are.
			var through := String(row.get("through", ""))
			var covered: bool = taught_actions.has(action) \
				and (through.is_empty() or taught_actions.has(through))
			_check(covered, "'%s' has a lesson" % action, String(row.get("label", "")))
		else:
			var button: String = MOUSE_ROWS.get(String(row.get("keys", "")), "")
			_check(taught_mouse.has(button), "'%s' has a lesson" % String(row.get("keys", "")),
				String(row.get("label", "")))
	_check(rows >= 15, "and the controls screen was really read", "%d rows" % rows)


## WHAT CAN BE TAUGHT AT THE START, AT THE DOOR; THE REST IN ITS MOMENT. Kent: "the tutorial should
## pop up for when the moment happens but there should be tutorial that is appropriate at the start
## like the movement, inventory, jump, etc". The door's cards are named here one by one, so a card
## about something not there at the start (a canvas, a placed drawing, a creature) cannot slip back
## onto it; each needs something on screen then to light. And Payyo's cards wait for the player.
func _audit_level_1_teaches_at_the_door(lessons: Array) -> void:
	print("  -- Level 1: the door, and the moments --")
	var anchors: Array = (load(LEVEL_BASE) as Script).get_script_constant_map()["TUTORIAL_ANCHORS"]
	var door: Array[String] = []
	var live: Array[String] = []
	for value: Variant in lessons:
		var lesson: Dictionary = value
		var id := String(lesson["id"])
		if bool(lesson.get("entry_live", false)):
			live.append(id)
		if not bool(lesson.get("door", false)):
			_check(not lesson.has("entry_anchor"), "'%s', in its moment, has no door anchor" % id,
				"lights its own subject" if not lesson.has("entry_anchor") else "STALE entry_anchor")
			continue
		door.append(id)
		var anchor := String(lesson.get("entry_anchor", lesson.get("anchor", "")))
		_check(anchors.has(anchor), "'%s' lights something at the door" % id, anchor)
	_check(door == ["move", "jump", "bag_open", "bag_hints", "quest", "marker", "map", "pause"],
		"the door teaches walking, jumping, the bag, the HUD, then Escape", ", ".join(door))
	# Done for real at the door, with the world running: walking and jumping, and nothing else. A
	# card that let the world run under it would let a stray R open the canvas mid-run.
	_check(live == ["move", "jump"], "at the door, only walking and jumping run the world",
		", ".join(live))
	var ledger: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LEDGER))
	var strict: Array[String] = []
	for level_id: String in ledger["levels"]:
		if bool((ledger["levels"][level_id] as Dictionary).get("strict", false)):
			strict.append(level_id)
	_check(strict == ["level_1"], "Payyo's cards wait for the player to do them; other levels' do not change",
		", ".join(strict))


## A LATER LEVEL ONLY SAYS WHAT IT CHANGES. Kent: "other levels wont have any tutorials if
## necessary". A card dims the screen, so one outside Level 1 has to be something Level 1 cannot
## teach: a rule or a control that does not exist until that level. Named here one by one, so a
## new card has to be argued for rather than slipping in. Anything else goes on the hint bar.
func _audit_later_levels_only_say_what_changes(ledger: Dictionary) -> void:
	print("  -- later levels only say what they change --")
	var levels: Dictionary = ledger["levels"]
	for level_id in ["level_2", "level_5"]:
		_check(not levels.has(level_id), "%s teaches nothing of its own" % level_id,
			"no block" if not levels.has(level_id) else "HAS LESSONS")
	var cards := 0
	for level_id: String in levels:
		if level_id == "level_1":
			continue
		for value: Variant in (levels[level_id] as Dictionary)["lessons"]:
			var lesson: Dictionary = value
			if String(lesson.get("mode", "")) == "say":
				continue
			cards += 1
			_check(NECESSARY_CARDS.has(String(lesson["id"])),
				"%s's card '%s' is one Level 1 cannot teach" % [level_id, lesson["id"]],
				String(NECESSARY_CARDS.get(String(lesson["id"]), "NOT ON THE LIST")))
	# ⚠ BOTH WAYS. A card converted away but left on the list would make the list a lie, and
	# the rule above would still pass with no cards at all.
	_check(cards == NECESSARY_CARDS.size(), "and every one on the list is still a card",
		"%d cards, %d listed" % [cards, NECESSARY_CARDS.size()])


## WHAT A ROUTE CAN MISS comes back in a later level, so it has to make sense in one.
func _audit_what_a_route_can_miss(ledger: Dictionary) -> void:
	print("  -- what a route can miss --")
	var source := FileAccess.get_file_as_string(LEVEL_BASE)
	var carried := 0
	var later := {}
	for level_id: String in ledger["levels"]:
		if level_id != "level_1":
			for value: Variant in (ledger["levels"][level_id] as Dictionary)["lessons"]:
				later[String((value as Dictionary)["id"])] = level_id
	for value: Variant in ledger["levels"]["level_1"]["lessons"]:
		var lesson: Dictionary = value
		if not bool(lesson.get("carries", false)):
			continue
		carried += 1
		var id := String(lesson["id"])
		# The event has to fire in every level, not only the level that owns the lesson.
		_check(source.contains('tutorial.note("%s")' % String(lesson["at"])),
			"'%s' can come round in any level" % id, String(lesson["at"]))
		_check(not later.has(id), "'%s' is not a later level's id too" % id,
			String(later.get(id, "unique")))
		# Their mode is theirs: a `say` line would go out as "Lolo" in a level he has left.
		_check(String(lesson.get("mode", "")) != "say", "'%s' speaks as nobody if it carries" % id,
			String(lesson.get("mode", "")))
	_check(carried >= 10, "and the things a route can skip do carry", "%d lessons" % carried)
	# The ones whose rule is not true everywhere must not: the ink changes level by level.
	for value: Variant in ledger["levels"]["level_1"]["lessons"]:
		var lesson: Dictionary = value
		if String(lesson["id"]) in ["undo", "ink", "checkpoint"]:
			_check(not bool(lesson.get("carries", false)), "'%s' stays in Level 1" % lesson["id"],
				"its rule changes later")


func _audit_level(ledger: Dictionary, level_id: String) -> void:
	print("  -- %s --" % level_id)
	var lessons: Array = ledger["levels"][level_id]["lessons"]
	_check(not lessons.is_empty(), "%s has lessons" % level_id, "%d" % lessons.size())
	_check(LEVEL_SCRIPTS.has(level_id), "%s says where its lessons fire" % level_id,
		"LEVEL_SCRIPTS" if LEVEL_SCRIPTS.has(level_id) else "NOT IN LEVEL_SCRIPTS")

	# 1. Every lesson says a real key. resolve() returns "" for an action the InputMap does
	#    not hold, which is the failure worth catching: a sentence promising a control that
	#    does not exist sends the player hunting for it.
	var director := TutorialScript.new()
	root.add_child(director)
	director.load_for(level_id)
	var ids: Array[String] = []
	for value: Variant in lessons:
		var lesson: Dictionary = value
		var id := String(lesson["id"])
		ids.append(id)
		var text: String = director.resolve(lesson)
		_check(not text.is_empty() and not text.contains("{keys}"),
			"'%s' names a live key" % id, text if not text.is_empty() else "UNBOUND")

	# 2. NO LESSON MAY NAME A DRAWABLE CLASS. The same rule the dialogue is held to, and it
	#    bites harder here: `key` and `door` are both classes AND both the answer to a Level
	#    1 route. This check caught "scroll wheel" on the first run -- `wheel` carries the
	#    Roll tag, which is the answer to Beat 0's first sub-beat.
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://config/entities.json"))
	var terms: Array[String] = []
	for entry_value: Variant in manifest["entities"]:
		var entry: Dictionary = entry_value
		terms.append(String(entry["id"]).replace("_", " "))
		terms.append(String(entry["id"]))
	for value: Variant in lessons:
		var lesson: Dictionary = value
		# The caption too: it is the line under the picture, read by everyone who reads.
		var text := ("%s %s" % [lesson.get("text", ""), lesson.get("caption", "")]).to_lower()
		var named := ""
		for term in terms:
			var re := RegEx.new()
			re.compile("\\b%s\\b" % term.to_lower())
			if re.search(text) != null:
				named = term
				break
		_check(named.is_empty(), "'%s' names no drawable class" % String(lesson["id"]),
			"clean" if named.is_empty() else "says '%s'" % named)

	# 3. `after` must point at a lesson that exists, or the lesson waits forever.
	for value: Variant in lessons:
		var lesson: Dictionary = value
		var after := String(lesson.get("after", ""))
		if after.is_empty():
			continue
		_check(ids.has(after), "'%s' waits on a real lesson" % String(lesson["id"]), after)

	# 4. EVERY `at` IS AN EVENT SOMETHING ACTUALLY FIRES. A lesson whose event is never
	#    noted is a lesson the player never sees, and nothing else in this suite would say
	#    so -- it looks exactly like a lesson that is simply waiting its turn.
	var source := FileAccess.get_file_as_string(LEVEL_BASE)
	for path: String in LEVEL_SCRIPTS.get(level_id, []):
		source += FileAccess.get_file_as_string(path)
	for value: Variant in lessons:
		var lesson: Dictionary = value
		var at := String(lesson["at"])
		_check(source.contains('tutorial.note("%s")' % at),
			"'%s' waits on an event that fires" % String(lesson["id"]), at)

	# 7. A PICTURE FIRST, A FEW WORDS SECOND. Kent: "avoid like just texts since there are
	#    players that will play it without reading it". Every lesson the game shows -- all but
	#    Lolo's own `say` lines -- names a picture LessonVisual knows how to draw, and its
	#    caption is short enough to be a label rather than a paragraph.
	for value: Variant in lessons:
		var lesson: Dictionary = value
		var id := String(lesson["id"])
		var mode := String(lesson.get("mode", ""))
		_check(mode in ["do", "look", "say"], "'%s' says how it is shown" % id, mode)
		if mode == "say":
			_check(not lesson.has("visual") and not lesson.has("anchor"),
				"'%s' is Lolo talking, with no card" % id, "say")
			continue
		var visual := String(lesson.get("visual", ""))
		_check(LessonVisual.KINDS.has(visual), "'%s' has a picture" % id, visual)
		var caption := String(lesson.get("caption", ""))
		var words := caption.split(" ", false).size()
		_check(words > 0 and words <= 8, "'%s' has a few words, not a paragraph" % id,
			"%d words" % words)
		_check(not String(lesson.get("anchor", "")).is_empty(),
			"'%s' lights up what it is about" % id, String(lesson.get("anchor", "NONE")))
		if visual == "keys":
			_check(not director.caps_list(lesson).is_empty(), "'%s' has keys to draw" % id,
				", ".join(director.caps_list(lesson)))
		# A `do` card goes when its input is pressed -- or, for a button the player clicks,
		# when the button it lights goes away. One with neither could only time out.
		if mode == "do":
			var ends := not director.actions_for(lesson).is_empty() \
				or not (lesson.get("mouse", []) as Array).is_empty() \
				or String(lesson.get("anchor", "")) == "transform_button"
			_check(ends, "'%s' ends when it is done" % id, "has an input" if ends else "ONLY TIMES OUT")
	director.queue_free()
