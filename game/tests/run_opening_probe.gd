extends SceneTree
## PAYYO'S OPENING, AND WHAT LOLO SAYS WHEN YOU COME BACK.
##   godot --headless --path game --script res://tests/run_opening_probe.gd
##
## The first time into Payyo the apo wakes in a place they do not know, meets a ghost, and is
## told where they are -- a conversation with questions the player answers, played before the
## first tutorial card. Every time after, Lolo greets them from a pool, most relevant first,
## and nothing repeats until every eligible greeting has played. At a fork answered before he
## names what they chose and asks for something else.
##
## Played for real: the level is built, the opening runs through LevelBase._play_opening, the
## lines go through the dialogue box and the questions through the choice overlay, and this
## answers them the way a player would.

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-58s %s" % ["OK  " if ok else "FAIL", what, detail])


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _level() -> Node2D:
	root.get_node("LevelManager").set("current_level_id", "level_1")
	var level := (load("res://game_level.tscn") as PackedScene).instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	level.set("intro_enabled", true)
	root.add_child(level)
	return level


## The labels on the question the overlay is asking, or [] if none is up.
func _options(level: Node2D) -> Array[String]:
	var overlay := level.get_node("DialogueChoiceOverlay") as ModalOverlay
	var out: Array[String] = []
	if not overlay.is_open():
		return out
	for button in overlay.get_node("Root/Center/Panel/VBox/Choices").get_children():
		for label in button.find_children("*", "Label", true, false):
			out.append((label as Label).text)
			break
	return out


## Read every line, answer every question with `answer` (label -> index), until the opening
## has nothing left to say. Returns how many questions were answered.
func _play_through(level: Node2D, answer: Callable) -> int:
	var box := level.get("dialogue_box") as Node
	var overlay := level.get_node("DialogueChoiceOverlay")
	var asked := 0
	var quiet := 0
	for _step in range(400):
		await process_frame
		if box.call("is_open"):
			quiet = 0
			box.call("skip_all")
			continue
		var options := _options(level)
		if not options.is_empty():
			quiet = 0
			asked += 1
			await _wait(0.6)
			overlay.call("_on_option_pressed", int(answer.call(options)))
			continue
		quiet += 1
		if quiet > 90:
			break
	return asked


func _run() -> void:
	var profile := root.get_node("PlayerProfile")
	print("\n===== THE FIRST TIME =====")
	var level := _level()
	await _wait(0.3)
	var tutorial = level.get("tutorial")
	_check(not level.get("script_lines").call("has_heard", "INTRO.wake"),
		"nothing is said on the frame the level appears", "waits for OPENING_DELAY")
	await _wait(1.0)
	var script_lines = level.get("script_lines")
	_check(script_lines.call("has_heard", "INTRO.wake"), "the apo wakes up and speaks first",
		"INTRO.wake")
	_check(not tutorial.call("was_shown", "move"), "and no tutorial card is over it",
		"move not shown yet")
	var first_question: Array[String] = []
	var asked: int = await _play_through(level, func(options: Array[String]) -> int:
		if first_question.is_empty():
			first_question.assign(options)
			return 0
		# Ask one thing, then go.
		var go := options.find("Okay. Show me.")
		return 0 if options.size() == 5 else go)
	_check(first_question.size() == 3 and first_question[0].begins_with("Stay back"),
		"the apo is frightened, and the player picks how", ", ".join(first_question))
	_check(script_lines.call("has_heard", "INTRO.q1.back"), "and Lolo answers that choice",
		"INTRO.q1.back")
	_check(script_lines.call("has_heard", "INTRO.explain"), "then says who he is and where they are",
		"INTRO.explain")
	_check(script_lines.call("has_heard", "INTRO.q2.ghost")
		and not script_lines.call("has_heard", "INTRO.q2.how"),
		"the player asks what they want and nothing else", "asked why he is a ghost, then left")
	_check(script_lines.call("has_heard", "INTRO.q2.go") and asked == 3,
		"and walks on when they choose to", "%d questions answered" % asked)
	_check(int(profile.call("level_visits", "level_1")) == 1, "the visit is counted",
		"%d" % int(profile.call("level_visits", "level_1")))
	# Then Lolo asks the apo to walk, and only then does the Walk card come up.
	var box := level.get("dialogue_box") as Node
	var lead_said := false
	for _i in range(240):
		await process_frame
		if box.call("is_open"):
			lead_said = String(box.get("_full")).begins_with("Come, apo")
			break
	_check(lead_said and not tutorial.call("was_shown", "move"),
		"Lolo asks the apo to walk before the card", String(box.get("_full")))
	box.call("skip_all")
	await _wait(1.0)
	_check(tutorial.call("was_shown", "move"), "and the Walk card follows his line", "move")
	level.queue_free()
	await _wait(0.3)

	print("\n===== COMING BACK =====")
	# They went around at the gorge last time.
	profile.call("record_route", "level_1", "pragmatist")
	profile.call("record_obstacle_route", "level_1", "L1_N1", "pragmatist")
	level = _level()
	await _wait(1.3)
	script_lines = level.get("script_lines")
	_check(not script_lines.call("has_heard", "INTRO.wake"), "a second visit does not wake up again",
		"no INTRO")
	_check(script_lines.call("has_heard", "RETURN.pragmatist"),
		"Lolo remembers the route they took, first", "RETURN.pragmatist")
	await _play_through(level, func(_o: Array[String]) -> int: return 0)

	# At the fork: he says what they chose, and the buttons say which one it was.
	# Not awaited here: the reminder waits for its line to be read, and reading it is ours.
	level.call("_remind_of_last_choice", "L1_N1")
	await _play_through(level, func(_o: Array[String]) -> int: return 0)
	_check(script_lines.call("has_heard", "L1_N1.choice.again.pragmatist"),
		"at the gorge he names last time's choice", "L1_N1.choice.again.pragmatist")
	var taken: Array = profile.call("routes_taken_at", "level_1", "L1_N1")
	_check(taken == ["pragmatist"], "and knows which route it was", str(taken))
	level.queue_free()
	await _wait(0.3)

	level = _level()
	await _wait(1.3)
	script_lines = level.get("script_lines")
	_check(script_lines.call("has_heard", "RETURN.again")
		and not script_lines.call("has_heard", "RETURN.pragmatist"),
		"a third visit hears something it has not heard yet", "RETURN.again")
	await _play_through(level, func(_o: Array[String]) -> int: return 0)
	level.queue_free()
	await _wait(0.3)

	# Round the pool: nothing repeats until every greeting that applies has played.
	var heard: Array[String] = []
	for _visit in range(4):
		level = _level()
		await _wait(1.3)
		script_lines = level.get("script_lines")
		for hook in ["RETURN.pragmatist", "RETURN.again", "RETURN.back", "RETURN.quiet",
				"RETURN.remember"]:
			if script_lines.call("has_heard", hook):
				heard.append(hook)
		await _play_through(level, func(_o: Array[String]) -> int: return 0)
		level.queue_free()
		await _wait(0.3)
	_check(heard == ["RETURN.back", "RETURN.remember", "RETURN.quiet", "RETURN.pragmatist"],
		"no greeting repeats before the others have played",
		"visits 4-7: %s" % ", ".join(heard))

	print("
===== BACK FROM THE SEA =====")
	# The apo was last in Dagat, and walks back into Payyo.
	(profile.get("_data") as Dictionary)["last_level"] = "level_3"
	level = _level()
	await _wait(1.3)
	script_lines = level.get("script_lines")
	box = level.get("dialogue_box") as Node
	_check(String(box.get("_full")) == "Welcome back, apo! Tired of swimming already?",
		"Lolo remarks on where they have just been", String(box.get("_full")))
	await _play_through(level, func(_o: Array[String]) -> int: return 0)
	var facts: Array[String] = []
	for entry_value: Variant in script_lines.call("returns"):
		var entry: Dictionary = entry_value
		if String(entry.get("pool", "")) == "fact" 				and script_lines.call("has_heard", String((entry["steps"] as Array)[0]["say"])):
			facts.append(String(entry["id"]))
	_check(facts.size() == 1, "and then tells them something true about the terraces",
		", ".join(facts))
	tutorial = level.get("tutorial")
	await _wait(3.0)
	_check(not tutorial.call("was_shown", "move") and not tutorial.call("is_coming", "move"),
		"and no tutorial card plays on a return", "move neither shown nor queued")
	level.queue_free()
	await _wait(0.3)

	print("OBRA_OPENING_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(failures)
