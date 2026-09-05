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
	var lessons: Array = ledger["levels"]["level_1"]["lessons"]
	_check(not lessons.is_empty(), "level 1 has lessons", "%d" % lessons.size())

	# 1. Every lesson says a real key. resolve() returns "" for an action the InputMap does
	#    not hold, which is the failure worth catching: a sentence promising a control that
	#    does not exist sends the player hunting for it.
	var director := TutorialScript.new()
	root.add_child(director)
	director.load_for("level_1")
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
		var text := String(lesson["text"]).to_lower()
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
	for value: Variant in lessons:
		var lesson: Dictionary = value
		var at := String(lesson["at"])
		_check(source.contains('tutorial.note("%s")' % at),
			"'%s' waits on an event that fires" % String(lesson["id"]), at)

	# 5. Spent once. A lesson that re-teaches is the interruption this replaced.
	director.note("level_start")
	var first := director.taught_count()
	director.note("level_start")
	_check(director.taught_count() == first, "a lesson is spent once",
		"%d taught after two identical events" % director.taught_count())
	_check(director.has_taught("move"), "level_start teaches walking", "move")

	# 6. One lesson per event per call: two writes to one label in one frame and only the
	#    last is ever drawn. The second lesson waits for the event to come round again.
	director.note("placement_started")
	_check(director.has_taught("place") and not director.has_taught("rotate"),
		"two lessons on one event do not collide", "place taught, rotate still waiting")
	director.note("placement_started")
	_check(director.has_taught("rotate"), "and the second arrives next time", "rotate")

	print("--- %d passed, %d failed ---" % [_passed, _failed])
	print("OBRA_TUTORIAL_FAILED=%d" % _failed if _failed > 0 else "OBRA_TUTORIAL_OK")
	quit(1 if _failed > 0 else 0)
