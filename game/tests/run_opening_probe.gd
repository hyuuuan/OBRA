extends SceneTree
## PAYYO'S OPENING, AND WHAT LOLO SAYS WHEN YOU COME BACK.
##   godot --headless --path game --script res://tests/run_opening_probe.gd
##
## The first time into Payyo the apo wakes in a place they do not know, meets a ghost, and is
## told where they are -- a conversation with questions the player answers, played before the
## first tutorial card -- and then every card, back to back, before the first step. Every time after, Lolo greets them from a pool, most relevant first,
## and nothing repeats until every eligible greeting has played. At a fork answered before he
## names what they chose and asks for something else.
##
## Played for real: the level is built, the opening runs through LevelBase._play_opening, the
## lines go through the dialogue box and the questions through the choice overlay, and this
## answers them the way a player would.

## Every check this probe makes, so a crash part-way cannot print OK.
const CHECKS := 24
const TutorialDoor = preload("res://tests/tutorial_door.gd")

var failures := 0
var checked := 0
## The level whose hint bar is being listened to, and every sentence it has shown since.
var _watched: Node2D
var _hints_heard: Array[String] = []
var _last_hint := ""
## Frames between the end of the intro and the first card on which the world ran.
var _gap_frames := 0
var _gap_level: Node2D
## Where she stood when the last card went, and cards shown on the walk to the stair. Members,
## because a lambda captures a local by value and a signal could never have counted it.
var _x_at_the_end := INF
var _cards_on_the_way := 0
var _the_level: Node2D
## How each card at the door went, by lesson id.
var _hows := {}


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
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


## The hint bar goes up and comes down between frames this probe never stops on -- it stands
## down under a story line -- so it is listened to every frame rather than looked at once.
func _watch_the_bar(level: Node2D) -> void:
	_watched = level
	_hints_heard.clear()
	_last_hint = ""
	if not process_frame.is_connected(_note_the_bar):
		process_frame.connect(_note_the_bar)


func _note_the_bar() -> void:
	if _watched == null or not is_instance_valid(_watched):
		return
	var bar := _watched.get("hint_bar") as Node
	if bar == null:
		return
	var text := String(bar.call("current_text"))
	if text != _last_hint and not text.is_empty():
		_hints_heard.append(text)
	_last_hint = text


func _hold(action: StringName, down: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = down
	Input.parse_input_event(event)


## EVERY CARD, THEN ANG HAGDAN. Kent: "i want the pop ups to all be done right before the player
## does something in level 1 like the moment the player enters level 1". Played as a player
## holding walk from the moment the intro ends: the cards come one after another with the world
## held, she does not move until the last has gone, and walking on to the stair brings no card.
func _every_card_then_the_stair(level: Node2D) -> void:
	var tutorial = level.get("tutorial")
	var spot := level.get("tutorial_spotlight") as TutorialSpotlight
	var box := level.get("dialogue_box") as Node
	var script_lines = level.get("script_lines")
	var player := level.get("player") as Node2D
	_the_level = level
	_x_at_the_end = INF
	tutorial.connect("door_taught", _note_where_she_stands)
	_hows.clear()
	spot.finished.connect(_note_how)
	# Each card is done as a player must: with what it shows. Nothing else moves one on.
	var since := Time.get_ticks_msec()
	while bool(tutorial.call("is_teaching_the_door")) and Time.get_ticks_msec() - since < 60000:
		await process_frame
		if spot.is_showing() and float(spot.get("_age")) > TutorialSpotlight.STRICT_MIN_SEC + 0.05:
			var up := spot.lesson_id()
			TutorialDoor.press_for(spot.get("_lesson") as Dictionary, root)
			while spot.is_showing() and spot.lesson_id() == up and Time.get_ticks_msec() - since < 60000:
				await process_frame
	spot.finished.disconnect(_note_how)
	var cards := 0
	var done := 0
	for id: String in tutorial.call("lesson_ids"):
		if not bool((tutorial.call("_find", id) as Dictionary).get("door", false)):
			continue
		cards += 1
		if bool(tutorial.call("was_shown", id)) and String(_hows.get(id, "")) == "done":
			done += 1
	_check(not bool(tutorial.call("is_teaching_the_door")) and done == cards and cards > 0,
		"every door card plays, and each goes when she does what it shows",
		"%d of %d door cards done" % [done, cards])
	_hold(&"move_right", true)
	var stair := level.find_child("B0_HAGDAN", true, false) as Node2D
	_cards_on_the_way = 0
	tutorial.connect("lesson_taught", _count_a_card)
	var waited := 0.0
	while waited < 20.0 and not bool(script_lines.call("has_heard", "B0_HAGDAN.enter")):
		if box.call("is_open"):
			box.call("skip_all")
		await _wait(0.05)
		waited += 0.05
	_hold(&"move_right", false)
	var on_the_way := _cards_on_the_way
	# And at the wall, through the stair's own lines: the Draw card comes in its moment, led in.
	var at_the_wall := 0.0
	while at_the_wall < 8.0 and not bool(tutorial.call("was_shown", "draw")):
		if box.call("is_open"):
			box.call("skip_all")
		await _wait(0.05)
		at_the_wall += 0.05
	tutorial.disconnect("lesson_taught", _count_a_card)
	_check(bool(script_lines.call("has_heard", "B0_HAGDAN.enter")) and on_the_way == 0
		and bool(tutorial.call("was_shown", "draw")) and spot.lesson_id() == "draw",
		"no card on the way to Ang Hagdan, and at the wall the Draw card comes",
		"%d cards on the way, at x %d of %d; Draw %s" % [on_the_way, int(player.global_position.x),
			int(stair.global_position.x), "up" if spot.lesson_id() == "draw" else "NOT UP"])


func _note_how(id: String, how: String) -> void:
	_hows[id] = how


func _note_where_she_stands() -> void:
	_x_at_the_end = (_the_level.get("player") as Node2D).global_position.x


## Lolo's own lines (`say`) are not cards, and keep their moments.
func _count_a_card(id: String) -> void:
	var lesson: Dictionary = _the_level.get("tutorial").call("_find", id)
	if String(lesson.get("mode", "")) != "say":
		_cards_on_the_way += 1


## Every frame from the intro's last word to the first card: the world must not run between them.
func _watch_the_gap(level: Node2D) -> void:
	_gap_level = level
	if not process_frame.is_connected(_note_the_gap):
		process_frame.connect(_note_the_gap)


func _note_the_gap() -> void:
	if _gap_level == null or not is_instance_valid(_gap_level):
		return
	var tutorial = _gap_level.get("tutorial")
	var box := _gap_level.get("dialogue_box") as Node
	if not bool(_gap_level.get("script_lines").call("has_heard", "INTRO.q2.go")):
		return
	if bool(box.call("is_open")) or bool(tutorial.call("was_shown", "move")):
		return
	if not paused:
		_gap_frames += 1


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
	_watch_the_bar(level)
	_watch_the_gap(level)
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
	# Then the cards, the first straight after his last word: no lead in the story box, because
	# each was written for a moment that has not come yet.
	var box := level.get("dialogue_box") as Node
	var spot := level.get("tutorial_spotlight") as TutorialSpotlight
	var first := ""
	var said := ""
	for _i in range(240):
		if box.call("is_open"):
			said = String(box.get("_full"))
			break
		if spot.is_showing():
			first = spot.lesson_id()
			break
		await process_frame
	_check(first == "move" and said.is_empty(), "the cards start as the intro ends, Walk first, with no lead",
		"first card '%s'%s" % [first, (", Lolo said: " + said) if not said.is_empty() else ""])
	_check(_gap_frames == 0, "and the world does not run between his last word and the card",
		"%d frames ran" % _gap_frames)
	# ⚠ NOT "PRESS R AND DRAW" BEFORE A STEP. The greeting used to follow the opening as a hint,
	# telling her to draw with nothing in front of her to draw for; the wall teaches it now.
	var greeting := String((level.get("_script_lines") as Dictionary).get("greeting", ""))
	_check(not greeting.is_empty() and not _hints_heard.has(greeting),
		"and no hint tells her to draw before she has walked",
		"the bar said: %s" % (" | ".join(_hints_heard) if not _hints_heard.is_empty() else "nothing"))
	await _every_card_then_the_stair(level)
	level.queue_free()
	await _wait(0.3)

	print("\n===== COMING BACK =====")
	# They went around at the gorge last time.
	profile.call("record_route", "level_1", "pragmatist")
	profile.call("record_obstacle_route", "level_1", "L1_N1", "pragmatist")
	level = _level()
	_watch_the_bar(level)
	await _wait(1.3)
	script_lines = level.get("script_lines")
	_check(not script_lines.call("has_heard", "INTRO.wake"), "a second visit does not wake up again",
		"no INTRO")
	_check(script_lines.call("has_heard", "RETURN.pragmatist"),
		"Lolo remembers the route they took, first", "RETURN.pragmatist")
	await _play_through(level, func(_o: Array[String]) -> int: return 0)
	var welcome := String((level.get("_script_lines") as Dictionary).get("greeting", ""))
	_check(_hints_heard.has(welcome), "and a return visit still hears the greeting",
		"the bar said: %s" % (" | ".join(_hints_heard) if not _hints_heard.is_empty() else "nothing"))

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

	if checked != CHECKS:
		failures += 1
		print("  FAIL  ran %d of %d checks -- something stopped the probe part-way" % [checked, CHECKS])
	print("OBRA_OPENING_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(failures)
