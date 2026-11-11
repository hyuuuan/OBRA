extends SceneTree
## WHEN THE GAME SPEAKS: walked, with the keys held, and written down as it happens.
##   godot --headless --path game --script res://tests/run_line_timing_probe.gd
##   ... -- boards gorge      just those sections, for mutation runs (no count is enforced)
##
## A playtester: "the dialogues do not play at the right moment like some dialogues start at
## moments that should not be or like some are late and stuff especially the signs". Every probe
## before this one fired lines through `set_auto_dismiss`, which reads and dismisses them on the
## frame they begin, so nothing could see WHERE a line started, what it landed on, or whether the
## next thing wiped it. So this listens to the box and the bar every frame, walks up to each thing
## with real input, and turns the pages with the key a player presses.
##
## The list of what it found is in LEVEL_TEMPLATE.md, "When the game speaks".

## Every check this probe makes, so a crash part-way cannot print OK.
const CHECKS := 55

const LEVELS := {
	"level_1": "res://game_level.tscn",
	"level_2": "res://level_2.tscn",
	"level_3": "res://level_3.tscn",
	"level_4": "res://level_4.tscn",
	"level_5": "res://level_5.tscn",
}
## The beats whose opening line is said at their fork rather than at their own volume, by the name
## of the node the fork is, or by being the alley's. See LevelBase._on_dialogue_node_approached.
const SAID_AT_THE_FORK := {"L2_N1": "DialogueNode", "L3_N1": "DialogueNode"}
const ALLEYS := ["L2_N2", "L2_N3"]
## What each of Dilim's beats is about, from the scene. Her lamp reaches 230 and a line should land
## when the thing is about to come into it, not six hundred pixels out in the dark.
const DILIM_SUBJECTS := {
	"L4_NUNO": 3400.0, "L4_REST1": 5000.0, "L4_SIGBIN": 6800.0, "L4_TIKBALANG": 8450.0,
	"L4_KAPRE": 13800.0, "L4_REST2": 15400.0, "L4_TIYANAK": 17150.0, "L4_BUNGISNGIS": 19000.0,
	"L4_MANANANGGAL": 20500.0, "L4_FINALE": 21900.0,
}
const DILIM_SAID_WITHIN := 420.0

var failures := 0
var checked := 0

var level: Node2D
var box: DialogueBox
var bar: HintBar
var overlay: ModalOverlay
var bars: Node
## Every line of story as it started: {text, x, on_floor, question}.
var said: Array[Dictionary] = []
## Every change on the bar: {text, x, ms}.
var written: Array[Dictionary] = []
## Seconds each sentence has actually been readable on the bar.
var readable: Dictionary = {}
## Frames the question and a line of story were both up.
var talked_over_question := 0
## The lines the letterbox was over, by text.
var under_the_bars: Dictionary = {}
var bars_seen_since_marked := false
var _line := ""
var _hint := ""
var _clock := 0.0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if not ok:
		failures += 1
	print("  %s  %-62s %s" % ["OK  " if ok else "FAIL", what, detail])


# --- The level, and what is said in it -------------------------------------------------------

func _open(level_id: String, intro: bool = false, teaching: bool = false) -> void:
	await _close()
	root.get_node("LevelManager").set("current_level_id", level_id)
	level = (load(String(LEVELS[level_id])) as PackedScene).instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	level.set("intro_enabled", intro)
	root.add_child(level)
	box = level.get("dialogue_box") as DialogueBox
	bar = level.get("hint_bar") as HintBar
	overlay = level.get_node("DialogueChoiceOverlay") as ModalOverlay
	bars = get_first_node_in_group(CinematicBars.GROUP)
	_forget()
	if not process_frame.is_connected(_listen):
		process_frame.connect(_listen)
	if not teaching:
		var tutorial = level.get("tutorial")
		if tutorial != null:
			tutorial.call("set_enabled", false)


func _close() -> void:
	if level != null and is_instance_valid(level):
		level.queue_free()
		level = null
		await process_frame
		await process_frame
	# A level freed in the middle of a conversation leaves the tree stopped.
	paused = false


func _forget() -> void:
	said.clear()
	written.clear()
	readable.clear()
	under_the_bars.clear()
	talked_over_question = 0
	bars_seen_since_marked = false
	_line = ""
	_hint = ""


func _listen() -> void:
	if level == null or not is_instance_valid(level) or box == null or not is_instance_valid(box):
		return
	var delta := root.get_process_delta_time()
	var bars_up := bars != null and is_instance_valid(bars) and bool(bars.call("is_playing"))
	if bars_up:
		bars_seen_since_marked = true
	if box.is_open():
		var now := box.current_line()
		if now != _line:
			_line = now
			said.append({"text": now, "x": _x(), "on_floor": _on_floor(), "question": overlay.is_open()})
		if overlay.is_open():
			talked_over_question += 1
		if bars_up:
			under_the_bars[now] = true
	else:
		_line = ""
	var up := bar.current_text()
	if up != _hint:
		_hint = up
		if not up.is_empty():
			written.append({"text": up, "x": _x(), "ms": Time.get_ticks_msec()})
	if not up.is_empty() and (bar.get("_panel") as Control).modulate.a > 0.5 and bar.modulate.a > 0.5:
		readable[up] = float(readable.get(up, 0.0)) + delta


func _player() -> Node2D:
	return level.get("player") as Node2D


func _x() -> float:
	var who := _player()
	return who.global_position.x if who != null and is_instance_valid(who) else 0.0


func _on_floor() -> bool:
	var who := _player() as CharacterBody2D
	return who != null and is_instance_valid(who) and who.is_on_floor()


func _lines_of(hook: String) -> Array[String]:
	var script_lines = level.get("script_lines")
	var out: Array[String] = []
	for line_value: Variant in script_lines.call("peek", hook):
		out.append(String(script_lines.call("display_text", line_value)))
	return out


func _said_index(text: String) -> int:
	for index in range(said.size()):
		if String(said[index]["text"]) == text:
			return index
	return -1


func _said_entry(text: String) -> Dictionary:
	var index := _said_index(text)
	return said[index] if index >= 0 else {}


func _heard(hook: String) -> bool:
	return bool(level.get("script_lines").call("has_heard", hook))


# --- What a player does ----------------------------------------------------------------------

func _hold(action: StringName, down: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = down
	Input.parse_input_event(event)


func _tap(action: StringName) -> void:
	_hold(action, true)
	await process_frame
	await process_frame
	_hold(action, false)
	await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _settle(frames: int = 20) -> void:
	for _i in range(frames):
		await physics_frame


## Fixture only: where a walk begins. What is checked is what the walk then does.
func _stand_at(x: float, look_from: float) -> void:
	var who := _player()
	var start := Vector2(x, look_from)
	var query := PhysicsRayQueryParameters2D.create(start, start + Vector2(0.0, 1500.0))
	query.collide_with_areas = false
	var hit := who.get_world_2d().direct_space_state.intersect_ray(query)
	who.global_position = (hit["position"] as Vector2) + Vector2(0.0, -6.0) if not hit.is_empty() else start
	if who is CharacterBody2D:
		(who as CharacterBody2D).velocity = Vector2.ZERO
	await _settle(8)


## Read at the pace of somebody pressing on: the first press finishes a line, the next turns it.
func _turn_pages() -> void:
	while box.is_open():
		await _tap(&"ui_accept")
		await _wait(0.04)


## Walk with the key held until she reaches `x` or `seconds` runs out, reading whatever stops her.
func _walk_to(x: float, seconds: float = 12.0, read: bool = true) -> void:
	var east := x > _x()
	var key := &"move_right" if east else &"move_left"
	_hold(key, true)
	_clock = 0.0
	while _clock < seconds and (_x() < x if east else _x() > x):
		await process_frame
		_clock += root.get_process_delta_time()
		if read and box.is_open():
			await _turn_pages()
		elif overlay.is_open():
			break
	_hold(key, false)
	await process_frame


func _until_question(seconds: float = 6.0) -> bool:
	var waited := 0.0
	while waited < seconds and not overlay.is_open():
		await process_frame
		waited += root.get_process_delta_time()
		if box.is_open():
			await _turn_pages()
	return overlay.is_open()


## Answer with the key: the first answer takes the focus a beat after the question opens.
func _answer(downs: int = 0) -> void:
	await _wait(0.45)
	for _i in range(downs):
		await _tap(&"ui_down")
	await _tap(&"ui_accept")


# --- Sections --------------------------------------------------------------------------------

func _run() -> void:
	var only := OS.get_cmdline_user_args()
	var sections := {
		"opening": _the_opening_comes_first,
		"gorge": _the_gorge_asks_after_it_has_told,
		"lantern": _the_lantern_is_named_where_it_stands,
		"lake": _the_lake_teaches_a_swimming_form,
		"heap": _the_heap_says_what_it_is_first,
		"house": _the_house_speaks_on_foot,
		"air": _a_line_waits_for_her_to_land,
		"piyesta": _piyesta_says_its_own_first,
		"dilim": _dilim_speaks_when_it_can_be_seen,
		"sign": _the_sign_offers_to_those_who_stay,
		"aside": _an_aside_gives_the_bar_back,
		"boards": _boards_stand_where_lines_fire,
	}
	for section: String in sections:
		if only.is_empty() or only.has(section):
			print("\n===== %s =====" % section.to_upper())
			await (sections[section] as Callable).call()
	await _close()
	if only.is_empty() and checked != CHECKS:
		failures += 1
		print("  FAIL  ran %d of %d checks -- something stopped the probe part-way" % [checked, CHECKS])
	print("OBRA_LINE_TIMING_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(failures)


## A KEY ALREADY HELD WHEN THE LEVEL APPEARS. It was "the first step", so the lesson that comes
## after walking was led in by Lolo before the apo had woken up, and Walk was spent unshown.
func _the_opening_comes_first() -> void:
	await _open("level_1", true, true)
	_hold(&"move_right", true)
	var waited := 0.0
	while said.is_empty() and waited < 4.0:
		await process_frame
		waited += root.get_process_delta_time()
	_hold(&"move_right", false)
	var first := String(said[0]["text"]) if not said.is_empty() else "nothing"
	var wake := _lines_of("INTRO.wake")
	_check(not wake.is_empty() and first == wake[0], "holding a key from the first frame, the opening is first",
		first.left(46))
	var tutorial = level.get("tutorial")
	_check(not tutorial.call("was_shown", "jump") and not tutorial.call("has_taught", "move"),
		"and the lessons wait for it to be over", "Walk unspent, Jump not shown")


## THE WORST OF IT. The fork's box and the arrival's box both begin at x 2950.
func _the_gorge_asks_after_it_has_told() -> void:
	await _open("level_1")
	await _settle()
	await _stand_at(2884.0, 100.0)
	var director = level.get("director")
	var teach := _lines_of("L1_N1.teach")
	var opening := _lines_of("L1_N1.enter")
	_hold(&"move_right", true)
	var asked: bool = await _until_question(10.0)
	_hold(&"move_right", false)
	_check(talked_over_question == 0, "the question and a line are never up together",
		"%d frames" % talked_over_question)
	_check(asked and String(director.call("committed_route", "L1_N1")).is_empty(),
		"the keys that turn his pages do not answer it",
		"route: %s" % String(director.call("committed_route", "L1_N1")))
	var last_opening := _said_index(opening[-1]) if not opening.is_empty() else -1
	var first_way := _said_index(teach[0]) if not teach.is_empty() else -1
	var last_way := _said_index(teach[-1]) if not teach.is_empty() else -1
	_check(_said_index(opening[0]) == 0 and last_opening >= 0 and first_way > last_opening
		and last_way == said.size() - 1, "its opening, then its three ways, then the question",
		"%d lines said" % said.size())
	_forget()
	await _answer()
	var commit := _lines_of("L1_N1.artist.commit")
	var waited := 0.0
	while not box.is_open() and waited < 2.0:
		await process_frame
		waited += root.get_process_delta_time()
	_check(box.is_open() and not bars_seen_since_marked,
		"the answer is said before the letterbox comes in", box.current_line().left(40))
	await _turn_pages()
	await _wait(0.3)
	_check(not under_the_bars.has(commit[0] if not commit.is_empty() else "") and bars_seen_since_marked,
		"and the lantern has its moment after it", "bars after the line: %s" % bars_seen_since_marked)


func _the_lake_teaches_a_swimming_form() -> void:
	await _open("level_1")
	var water := level.get_node(^"EnvironmentBaseplate/GameplayPlane/WaterAreas/CentralPaddy") as WaterArea2D
	var west := water.global_position.x - water.surface_size.x * 0.5
	var words := "Too deep to wade, apo. Draw an animal that can swim and become it to cross."
	await _stand_at(west - 180.0, water.surface_y() - 100.0)
	_hold(&"jump", true)
	await _walk_to(west - 25.0, 2.0)
	_hold(&"jump", false)
	await _settle()
	var reached := _player().global_position
	var said_at := _said_entry(words)
	await _turn_pages()
	await _walk_to(west - 180.0, 2.0)
	await _settle()
	_hold(&"jump", true)
	await _walk_to(west - 25.0, 2.0)
	_hold(&"jump", false)
	await _settle()
	var heard := said.filter(func(entry: Dictionary) -> bool: return entry.get("text") == words).size()
	_check(heard == 1 and bool(said_at.get("on_floor", false)) and float(said_at.get("x", 0.0)) >= west - 120.0
		and float(said_at.get("x", INF)) < west and _x() >= west - 120.0 and _x() < west,
		"Lolo teaches swimming forms once on the bank",
		"said %d time(s) at x %.0f, reached %s" % [heard, float(said_at.get("x", 0.0)), reached.round()])


func _the_lantern_is_named_where_it_stands() -> void:
	await _open("level_1", false, true)
	await _settle()
	var tutorial = level.get("tutorial")
	tutorial.call("mark_taught", ["move", "jump", "draw", "requirement"])
	var lantern := level.find_child("CP0", true, false) as Node2D
	var words := "A lantern! She lit these so nobody would lose their way."
	# A lesson has only just gone, as one usually has by the top of the wall (Draw): the next waits
	# out the breath after it, and by then the bars are in. A first lesson would slip in ahead.
	tutorial.set("_gap", 0.6)
	await _stand_at(1190.0, 200.0)
	_hold(&"move_right", true)
	var waited := 0.0
	while _said_index(words) < 0 and waited < 5.0:
		await process_frame
		waited += root.get_process_delta_time()
	_hold(&"move_right", false)
	var at := _said_entry(words)
	_check(not at.is_empty() and absf(float(at["x"]) - lantern.global_position.x) <= 200.0,
		"\"A lantern!\" is said beside the lantern",
		"at x %d, it stands at %d" % [int(at.get("x", -1.0)), int(lantern.global_position.x)])
	await _turn_pages()


func _the_heap_says_what_it_is_first() -> void:
	await _open("level_1")
	await _settle()
	await _stand_at(3560.0, 130.0)
	var teach := _lines_of("L1_N2.teach")
	var opening := _lines_of("L1_N2.enter")
	var board := _board_reading("L1_N2.enter")
	await _walk_to(3790.0)
	var line_at := _said_entry(opening[0])
	_check(not line_at.is_empty() and absf(float(line_at["x"]) - board.global_position.x) <= Signpost2D.READ_RANGE,
		"its opening starts at its board", "at x %d, board %d" % [int(line_at.get("x", -1.0)), int(board.global_position.x)])
	var first_way_at := -1
	for entry: Dictionary in written:
		if String(entry["text"]) == teach[0]:
			first_way_at = int(entry["x"])
			break
	_check(first_way_at >= int(line_at.get("x", INF)),
		"its advice comes after it, not at the edge of the beat",
		"first way up at x %d" % first_way_at)
	# She walks on, off the mouth of the first heap, and stands.
	await _walk_to(4020.0, 2.0)
	await _wait(0.1)
	_check(bar.current_text() == teach[0], "walking off a heap leaves his words up",
		bar.current_text().left(40))
	var waited := 0.0
	while waited < 16.0 and bar.current_text() != teach[-1]:
		await process_frame
		waited += root.get_process_delta_time()
	await _wait(1.0)
	var shortest := 99.0
	for text in teach:
		shortest = minf(shortest, float(readable.get(text, 0.0)))
	_check(shortest >= 0.9, "all three ways are up long enough to read",
		"shortest %.1f s" % shortest)
	# Off the far side of the beat: the last of them stops being true there.
	await _walk_to(4060.0, 3.0)
	await _wait(2.0)
	_check(bar.current_text() != teach[-1], "and they go when she leaves the beat",
		bar.current_text().left(40))
	# Back in from the near side, short of the first heap: he may say it again, the player has
	# been away, unless something else is being said.
	await _stand_at(3590.0, 130.0)
	await _wait(1.5)
	await _walk_to(3670.0, 3.0)
	await _wait(0.2)
	_check(bar.current_text() == teach[0], "walking back in, he reminds her", bar.current_text().left(40))
	await _stand_at(3590.0, 130.0)
	await _wait(1.5)
	bar.show_hint("Something else is being said.", "", 8.0)
	await _walk_to(3670.0, 3.0)
	await _wait(0.2)
	_check(bar.current_text() == "Something else is being said.",
		"but not over something else", bar.current_text().left(40))
	bar.clear()
	# Answered, and it never asks again.
	var director = level.get("director")
	await _stand_at(3590.0, 130.0)
	await _wait(1.5)
	director.call("commit_route", "L1_N2", "artist")
	await _turn_pages()
	var spoken := int(level.get("script_lines").call("lines_spoken"))
	bar.clear()
	await _walk_to(3670.0, 3.0)
	await _wait(0.3)
	_check(int(level.get("script_lines").call("lines_spoken")) == spoken and not teach.has(bar.current_text()),
		"and a route chosen is not taught again", "%d lines" % int(level.get("script_lines").call("lines_spoken")))


## "THERE IS THE HOUSE" WAS BEHIND THE POST. The box began at 4530 and the post stops her at 4516,
## so nobody on foot ever heard it: it played once she had climbed onto the deck.
func _the_house_speaks_on_foot() -> void:
	await _open("level_1")
	await _settle()
	await _stand_at(4345.0, 0.0)
	var opening := _lines_of("L1_N3.enter")
	var board := _board_reading("L1_N3.enter")
	var refusal := "L1_N3.bulul_approach"
	await _walk_to(4492.0, 4.0)
	var line_at := _said_entry(opening[0])
	_check(not line_at.is_empty() and float(line_at["x"]) < 4508.0
		and absf(float(line_at["x"]) - board.global_position.x) <= Signpost2D.READ_RANGE,
		"walking up to it, the house is introduced at its board",
		"at x %d, board %d" % [int(line_at.get("x", -1.0)), int(board.global_position.x)])
	# Her reach of the nearer figure begins a step before the post stops her, and she has only
	# just got there: a walk past would have set it off by now.
	_check(_x() >= 4490.0 and not _heard(refusal), "\"Do not\" is not said to someone walking past",
		"at x %d" % int(_x()))
	await _walk_to(4600.0, 0.3, false)
	var waited := 0.0
	while waited < 3.0 and not box.is_open():
		await process_frame
		waited += root.get_process_delta_time()
	_check(_heard(refusal), "and is said to someone who stays", box.current_line().left(30))
	await _turn_pages()


func _a_line_waits_for_her_to_land() -> void:
	await _open("level_1")
	await _settle()
	await _stand_at(3560.0, 130.0)
	var opening := _lines_of("L1_N2.enter")
	var area := level.find_child("L1_N2", true, false) as LevelObstacle2D
	var crossed_on_floor := [true]
	area.player_arrived.connect(func(_id: String) -> void: crossed_on_floor[0] = _on_floor())
	_hold(&"move_right", true)
	var jumped := false
	var waited := 0.0
	while waited < 6.0 and not box.is_open():
		await process_frame
		waited += root.get_process_delta_time()
		if not jumped and _x() >= 3650.0:
			jumped = true
			_tap(&"jump")
	_hold(&"move_right", false)
	_check(not bool(crossed_on_floor[0]), "she crossed its volume in the air", "the jump is real")
	var line := _said_entry(opening[0])
	_check(not line.is_empty() and bool(line["on_floor"]), "and it spoke once she had landed",
		"at x %d" % int(line.get("x", -1.0)))
	await _turn_pages()


func _piyesta_says_its_own_first() -> void:
	await _open("level_2", true)
	var opening := _lines_of("L2_START.enter")
	# Its first lantern stands where she wakes, so it is reached at once. Then, inside the wait
	# before the opening, a step from the fork with a key held: a player who pressed on at once.
	await _settle(10)
	await _stand_at(580.0, 400.0)
	_hold(&"move_right", true)
	var waited := 0.0
	while said.is_empty() and waited < 5.0:
		await process_frame
		waited += root.get_process_delta_time()
	_hold(&"move_right", false)
	var first := String(said[0]["text"]) if not said.is_empty() else "nothing"
	_check(first == opening[0], "with a key held at the start: its own opening first", first.left(46))
	_check(not bars_seen_since_marked, "and no lantern's moment under it", "bars: %s" % bars_seen_since_marked)
	# And somebody who waited for it, and then took a step.
	await _open("level_2")
	await _settle(4)
	await _turn_pages()
	var rules := _lines_of("L2_START.teach")
	var beat := _lines_of("L2_N1.enter")
	var ways := _lines_of("L2_N1.teach")
	_hold(&"move_right", true)
	var asked: bool = await _until_question(8.0)
	_hold(&"move_right", false)
	_check(not _heard("L2_N1.protector.warn"), "and nobody is warned before they have been told anything",
		"%d things on the bar" % written.size())
	var at := _said_entry(beat[0])
	var fork := level.find_child("DialogueNode", true, false) as DialogueNode2D
	_check(not at.is_empty() and float(at["x"]) >= fork.global_position.x - fork.trigger_size.x * 0.5 - 40.0,
		"\"The church first\" waits for the fork, not her first step",
		"at x %d, fork at %d" % [int(at.get("x", -1.0)), int(fork.global_position.x)])
	_check(asked and talked_over_question == 0 and _said_index(ways[0]) > _said_index(beat[-1])
		and _said_index(ways[-1]) == said.size() - 1,
		"its opening, its three ways, then the question", "%d lines said" % said.size())
	# The second answer: the first is the dance, whose screen stands over everything for a while.
	await _answer(1)
	await _turn_pages()
	# Past the plaza's doors, whose prompts stand for as long as she stands at them.
	await _walk_to(1500.0, 5.0)
	var settled := 0.0
	while settled < 14.0 and float(readable.get(rules[-1], 0.0)) < 1.0:
		await process_frame
		settled += root.get_process_delta_time()
		if box.is_open():
			await _turn_pages()
	var shortest := 99.0
	for text in rules:
		shortest = minf(shortest, float(readable.get(text, 0.0)))
	_check(shortest >= 1.0, "and the plaza's two rules are still read", "shortest %.1f s" % shortest)
	# Back among them from outside their notice, which is when they would say it.
	await _walk_to(700.0, 4.0)
	await _wait(0.2)
	_check(not _heard("L2_N1.protector.warn"), "somebody who chose another way is not warned",
		"walked back among them to x %d" % int(_x()))
	# Chose to clear them, and is standing among them with the deed still ahead.
	await _open("level_2")
	await _settle(4)
	await _turn_pages()
	_hold(&"move_right", true)
	await _until_question(8.0)
	_hold(&"move_right", false)
	await _answer(2)
	await _turn_pages()
	_check(_heard("L2_N1.protector.warn"), "and somebody who chose to clear them is",
		bar.current_text().left(40))


func _dilim_speaks_when_it_can_be_seen() -> void:
	await _open("level_4")
	await _settle()
	var too_far := PackedStringArray()
	for node in get_nodes_in_group(&"level_obstacles"):
		var area := node as LevelObstacle2D
		var distance := float(DILIM_SUBJECTS.get(area.obstacle_id, 0.0)) - _fires_at(area)
		if not DILIM_SUBJECTS.has(area.obstacle_id) or distance < 0.0 or distance > DILIM_SAID_WITHIN:
			too_far.append("%s %d" % [area.obstacle_id, int(distance)])
	_check(too_far.is_empty(), "every beat speaks as its subject comes into the lamp",
		"; ".join(too_far) if not too_far.is_empty() else "within %d" % int(DILIM_SAID_WITHIN))
	await _stand_at(2700.0, 400.0)
	var line := _lines_of("L4_NUNO.enter")
	await _walk_to(3200.0)
	var at := _said_entry(line[0])
	_check(not at.is_empty() and float(at["x"]) > 3400.0 - DILIM_SAID_WITHIN,
		"walking up to the mound, it is named near the mound", "at x %d" % int(at.get("x", -1.0)))
	# ⚠ "I HAVE PASSED IT THREE TIMES NOW" IS SAID WHEN SHE HAS.
	var same_rock := _lines_of("L4_TIKBALANG.enter")
	var round_again := _lines_of("L4_TIKBALANG.led_back")
	await _stand_at(7950.0, 400.0)
	await _walk_to(8300.0, 3.0)
	_check(_said_index(same_rock[0]) < 0, "on the way in, the rock is just a rock",
		"%d lines at the rock" % said.size())
	await _led_round()
	var noticed := false
	for entry: Dictionary in written:
		noticed = noticed or String(entry["text"]) == round_again[0]
	_check(noticed and _said_index(same_rock[0]) < 0, "led back once, she notices",
		bar.current_text().left(40))
	await _led_round()
	_check(_said_index(same_rock[0]) >= 0, "and only the next time has she passed it three times",
		String(said[-1]["text"]).left(40) if not said.is_empty() else "")


## Up to the line past the rock on foot, and over it. The level takes her back.
func _led_round() -> void:
	await _stand_at(9560.0, 400.0)
	await _walk_to(9720.0, 2.0)
	await _wait(0.1)
	if box.is_open():
		await _turn_pages()


## THE OFFER IS FOR SOMEBODY WHO STAYED. It went up on the frame the line ended, and was gone half
## a second later as she walked on, at every board in the game.
func _the_sign_offers_to_those_who_stay() -> void:
	await _open("level_4")
	await _settle()
	var offer := "Press %s to read the sign" % preload("res://scripts/controls_overlay.gd").keys_for("interact")
	await _stand_at(2950.0, 400.0)
	await _walk_to(3120.0, 3.0)
	await _turn_pages()
	await _walk_to(3300.0, 2.0)
	await _wait(0.2)
	var flashed := false
	for entry: Dictionary in written:
		flashed = flashed or String(entry["text"]) == offer
	_check(not flashed, "walking past a board, it says nothing", "%d things written" % written.size())
	bar.clear()
	await _walk_to(3140.0, 2.0)
	await _wait(1.4)
	_check(bar.current_text() == offer, "standing at one, it offers", bar.current_text().left(40))


func _an_aside_gives_the_bar_back() -> void:
	await _open("level_1")
	await _settle()
	bar.show_beat(["The first thing he says at length.", "And the second."], "Lolo")
	await _wait(0.2)
	bar.interject("A remark in passing.", "", 0.4)
	_check(bar.current_text() == "A remark in passing.", "a remark takes the bar", bar.current_text())
	await _wait(0.7)
	var back := bar.current_text()
	var waited := 0.0
	while waited < 8.0 and bar.current_text() != "And the second.":
		await process_frame
		waited += root.get_process_delta_time()
	_check(back == "The first thing he says at length." and bar.current_text() == "And the second.",
		"and gives it back, and the rest of the beat with it", back.left(40))
	# A prompt stands as long as she stands there, and then the same.
	bar.show_beat(["Something he is saying.", "And the rest of it."], "Lolo")
	await _wait(0.2)
	bar.interject("Press a key to open this door.", "", 0.0)
	await _wait(0.6)
	var standing := bar.current_text()
	bar.take_down("Press a key to open this door.")
	await _wait(0.1)
	_check(standing == "Press a key to open this door." and bar.current_text() == "Something he is saying.",
		"a prompt stands, and walking off gives it back", bar.current_text().left(40))
	bar.take_down("Not what is up.")
	await _wait(0.1)
	_check(bar.current_text() == "Something he is saying.", "and only its own words are ever taken down",
		bar.current_text().left(40))
	# She walks off a door while a remark stands over its prompt. Nothing comes back for that door.
	bar.interject("Press a key to open this door.", "", 0.0)
	await _wait(0.1)
	bar.interject("A remark over the prompt.", "", 0.3)
	await _wait(0.1)
	bar.take_down("Press a key to open this door.")
	await _wait(0.5)
	_check(bar.current_text() == "Something he is saying.", "a prompt she has left does not come back later",
		bar.current_text().left(40))
	bar.clear()
	await _wait(0.3)
	await _a_remark_lets_advice_be_read()


## LOLO'S REMARKS AND A BEAT'S ADVICE SHARE ONE BAR, and the advice now stands as long as its beat.
func _a_remark_lets_advice_be_read() -> void:
	var tutorial = level.get("tutorial")
	var remark := {"id": "probe_remark", "mode": "say", "speaker": "Lolo", "seconds": 0.5,
		"text": "A remark about the interface."}
	while bars != null and bool(bars.call("is_playing")):
		await process_frame
	bar.show_beat(["Draw something for this wall."], "Lolo")
	_check(not bool(tutorial.call("_coast_is_clear", remark)),
		"a remark waits while the advice is still being read", bar.current_text())
	var waited := 0.0
	while waited < 6.0 and not bool(tutorial.call("_coast_is_clear", remark)):
		await process_frame
		waited += root.get_process_delta_time()
	_check(waited < 6.0 and bar.current_text() == "Draw something for this wall.",
		"and speaks once it has been read, though it still stands", "after %.1f s" % waited)
	tutorial.call("_show", remark)
	var over := bar.current_text()
	await _wait(0.8)
	_check(over == "A remark about the interface." and bar.current_text() == "Draw something for this wall.",
		"and the advice comes back after him", "%s, then %s" % [over.left(20), bar.current_text().left(20)])
	# New advice arrives while he is part-way through. Remarks are spent as they go up.
	var long_remark := "A remark she is part-way through reading, and long enough for it."
	bar.interject(long_remark, "Lolo", 6.0)
	await _wait(0.2)
	bar.show_beat(["Advice for the next step."], "Lolo")
	_check(bar.current_text() == long_remark, "advice that comes under a remark waits for it to be read",
		bar.current_text().left(40))
	waited = 0.0
	while waited < 7.0 and bar.current_text() == long_remark:
		await process_frame
		waited += root.get_process_delta_time()
	_check(bar.current_text() == "Advice for the next step." and waited < 4.5,
		"and takes the bar then, not after his whole time", "%.1f s of 6" % waited)
	# Her beat ends while Lolo is talking over its advice.
	bar.clear()
	await _wait(0.3)
	var ended := "Advice for a beat she is leaving."
	(level.get("_beat_advice") as Array).append(ended)
	bar.show_beat([ended], "Lolo")
	await _wait(0.1)
	bar.interject("A remark over it.", "Lolo", 0.3)
	await _wait(0.1)
	level.call("_retire_beat_advice")
	await _wait(0.5)
	_check(bar.current_text() != ended, "advice retired under a remark does not come back",
		"bar: '%s'" % bar.current_text().left(40))
	bar.clear()
	await _wait(0.3)
	var diving := [true]
	var underwater := func() -> bool: return diving[0]
	bar.show_beat(["Advice that still applies."], "Lolo")
	bar.interject("A reminder for the dive.", "Lolo", 6.0, underwater)
	diving[0] = false
	await _wait(0.2)
	_check(bar.current_text() == "Advice that still applies.",
		"surfacing dismisses the dive reminder and restores relevant advice", bar.current_text())
	diving[0] = true
	bar.show_beat(["Advice for the dive."], "Lolo", true, underwater)
	bar.interject("A remark over it.", "Lolo", 0.3)
	diving[0] = false
	await _wait(0.6)
	_check(not bar.is_showing(), "dive advice cannot come back under a remark after surfacing",
		bar.current_text())


## WHERE A BOARD STANDS IS WHERE SOMETHING IS SAID. Signpost2D says so and the player believes it:
## she walks up, and either it speaks or she is told she can read it.
func _boards_stand_where_lines_fire() -> void:
	for level_id: String in LEVELS:
		await _open(level_id)
		await _settle(30)
		var wrong := PackedStringArray()
		var beats := 0
		for node in get_nodes_in_group(&"level_obstacles"):
			var area := node as LevelObstacle2D
			var hook := "%s.enter" % area.obstacle_id
			if not bool(level.get("script_lines").call("has_hook", hook)):
				continue
			beats += 1
			var board := _board_reading(hook)
			if board == null:
				wrong.append("%s has no board" % area.obstacle_id)
				continue
			var fires := _fires_at(area)
			if ALLEYS.has(area.obstacle_id):
				fires = board.global_position.x
			if absf(board.global_position.x - fires) > Signpost2D.READ_RANGE:
				wrong.append("%s board %d, line %d" % [area.obstacle_id, int(board.global_position.x), int(fires)])
		_check(wrong.is_empty() and beats > 0, "%s: every board stands where its line fires" % level_id,
			"; ".join(wrong) if not wrong.is_empty() else "%d beats" % beats)


func _board_reading(hook: String) -> Signpost2D:
	for node in get_nodes_in_group(&"signposts"):
		var board := node as Signpost2D
		if board != null and board.reads == hook:
			return board
	return null


## Where somebody coming from the west first sets it off.
func _fires_at(area: LevelObstacle2D) -> float:
	if SAID_AT_THE_FORK.has(area.obstacle_id):
		var fork := level.find_child(String(SAID_AT_THE_FORK[area.obstacle_id]), true, false) as DialogueNode2D
		if fork != null:
			return fork.global_position.x - fork.trigger_size.x * 0.5
	var half := area.trigger_size.x * 0.5
	if area.announce_size == Vector2.ZERO:
		return area.global_position.x - half
	var width := minf(area.announce_size.x, area.trigger_size.x)
	var reach := maxf(0.0, half - width * 0.5)
	return area.global_position.x + clampf(area.announce_offset, -reach, reach) - width * 0.5
