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
## Where each level's lesson events are fired, besides LevelBase. Every level in the ledger
## must be here: one that is not fails, rather than having its events looked for in the
## wrong file and passing or failing by accident.
const LEVEL_SCRIPTS := {
	"level_1": [],
	"level_3": ["res://scripts/level_3.gd"],
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

	# 8. LESS OF IT. Kent: "its just knowledge dumping at this point". The four cut on that
	#    pass stay cut, and the tutorial level stays under twenty things to say.
	for cut in ["pause", "sure", "sign"]:
		_check(not ids.has(cut), "'%s' stays cut" % cut, "absent" if not ids.has(cut) else "BACK")
	_check(lessons.size() < 20, "Level 1 says fewer than twenty things", "%d" % lessons.size())
	_check(not ledger["levels"]["level_1"].has("canvas_briefing"),
		"the canvas is taught by cards, not four lines of Lolo", "no briefing")

	print("--- %d passed, %d failed ---" % [_passed, _failed])
	print("OBRA_TUTORIAL_FAILED=%d" % _failed if _failed > 0 else "OBRA_TUTORIAL_OK")
	quit(1 if _failed > 0 else 0)


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
