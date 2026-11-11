extends SceneTree
## Dilim's last clearing, headless: the night begins when she steps in, two aswang at most, one
## back after one falls, the second and third waves on time, a drawn sun bringing the morning on,
## a knockout starting it over, and the morning ending it.
##
##   godot --headless --path game --script res://tests/run_level4_finale_probe.gd
##
## She is kept in her grace throughout, so the dogs cannot knock her out of the check: what is
## measured here is the night, not the fight.

const GROUND_Y := 600.0
const CLEARING_WEST := 21400.0

var failures := 0
## Every check that ran, so one skipped by a script error is a failure rather than a silence.
var checked := 0
const CHECKS := 51
var level: Node
var finale: DilimFinale2D
## The most of them alive at once, seen on every frame of the night.
var most_alive := 0
## Everything the hint bar has said, in order: the night's words go by while the fight goes on.
var heard: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(180.0).timeout.connect(func() -> void:
		print("OBRA_L4_FINALE_FAILED=watchdog")
		quit(2))
	level = await _open_level()
	finale = _the_finale()
	var satchel := level.get("satchel") as Satchel
	for id in ["asin", "bawang", "abo"]:
		satchel.add(id, 1)
	# Every encounter answered the artist's way first, so the morning has one route to settle and
	# none is left to answer itself as she is put past it (walking by the tiyanak on its path is the
	# pragmatist's). What the profile held before, to count the morning's points against.
	set_meta(&"routes_before", _route_points())
	for encounter in ["L4_NUNO", "L4_SIGBIN", "L4_TIKBALANG", "L4_KAPRE", "L4_TIYANAK", "L4_BUNGISNGIS",
			"L4_MANANANGGAL"]:
		level.call("_answer", encounter, "artist")
	await _frames(10)
	await _nothing_before_the_clearing()
	await _stepping_in_begins_the_night()
	await _the_clock_comes_with_the_night()
	_the_clock_says_how_long()
	_the_clock_starts_a_moon_and_ends_a_sun()
	await _one_falls_and_another_comes()
	await _never_more_than_two()
	await _the_night_says_what_is_happening()
	await _ash_and_salt_reach_the_night()
	await _dawn_brightens_from_halfway()
	await _a_knockout_starts_the_night_over()
	await _the_waves_come_on_time()
	await _the_banner_goes_with_what_is_after_her()
	await _a_sun_hurries_the_morning()
	await _the_dead_tree()
	await _morning_ends_it()
	await _the_dark_lifts_and_she_is_through()
	_check(not (level.get("dawn_clock") as Control).visible, "and the night's clock is gone",
		"visible %s" % (level.get("dawn_clock") as Control).visible)
	level.queue_free()
	await _frames(3)
	level = await _open_level()
	finale = _the_finale()
	await _diary_defeats_survive_retries()
	level.queue_free()
	await _frames(3)
	if checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_L4_FINALE_OK")
		quit(0)
	else:
		print("OBRA_L4_FINALE_FAILED=%d" % failures)
		quit(1)


## The scene's own, or one at the clearing's middle until the scene has it.
func _the_finale() -> DilimFinale2D:
	for node in level.find_children("*", "Node2D", true, false):
		if node is DilimFinale2D:
			return node
	var made := DilimFinale2D.new()
	made.position = Vector2(21900.0, GROUND_Y)
	made.arena_west = CLEARING_WEST
	(level.get("entity_root") as Node2D).add_child(made)
	return made


func _diary_defeats_survive_retries() -> void:
	await _put_her_at(CLEARING_WEST + 90.0)
	finale.elapsed = 27.0
	await _frames(3)
	var lower := finale.manananggal_lower
	var upper := _night_manananggal()
	_check(upper != null and lower.visible and not lower.is_dead()
		and lower.global_position.x > CLEARING_WEST and lower.global_position.x < finale.tree.global_position.x,
		"the returning Manananggal leaves a reachable lower half in the clearing", str(lower.global_position))
	if upper == null:
		return
	for _blow in range(upper.max_hp):
		upper.apply_tool_hit("sword", 0.0, level.get("player") as Node2D)
	level.call("_knockout")
	await _put_her_at(CLEARING_WEST + 90.0)
	finale.elapsed = 27.0
	await _frames(3)
	var returned := _night_manananggal()
	_check(returned != null and lower.visible and not lower.is_salted()
		and lower.global_position.x > CLEARING_WEST,
		"after a sword-only defeat, both halves return on retry", str(lower.global_position))
	if returned == null:
		return
	var plane := level.get_node(^"EnvironmentBaseplate/GameplayPlane")
	var salt := AsinThrow2D.new()
	salt.position = lower.global_position
	plane.add_child(salt)
	finale.elapsed = 60.0
	await _frames(3)
	var tiktik := finale.tiktik()
	var ash := AboDust2D.new()
	ash.position = tiktik.global_position
	plane.add_child(ash)
	await _frames(3)
	for _blow in range(tiktik.max_hp):
		tiktik.apply_tool_hit("sword", 0.0, level.get("player") as Node2D)
	_check(lower.is_salted() and returned.is_gone() and tiktik.is_dead() and finale.tiktik_defeated,
		"salt and ash lead to the diary defeats", "salted %s, Tik-Tik defeated %s" % [lower.is_salted(), tiktik.is_dead()])
	level.call("_knockout")
	await _put_her_at(CLEARING_WEST + 90.0)
	finale.elapsed = 60.0
	await _frames(3)
	var director := level.get("director") as LevelDirector
	_check(finale.current_wave() == 2 and _night_manananggal() == null and finale.tiktik() == null
		and lower.is_salted() and lower.is_dead() and director.is_solved("L4_MANANANGGAL"),
		"the night restarts without resurrecting either diary defeat", "wave %d" % finale.current_wave())


func _night_manananggal() -> ManananggalUpper2D:
	for foe in finale.alive():
		if foe is ManananggalUpper2D:
			return foe
	return null


func _nothing_before_the_clearing() -> void:
	await _put_her_at(CLEARING_WEST - 600.0)
	await _seconds(1.0)
	_check(not finale.is_running() and finale.alive().is_empty(),
		"short of the last clearing, nothing has begun", "running %s" % finale.is_running())
	set_meta(&"clock_before", (level.get("dawn_clock") as Control).visible)


func _stepping_in_begins_the_night() -> void:
	var ink := level.get("ink_manager") as InkManager
	ink.drain(ink.remaining() - 1.0)
	var low := ink.remaining()
	await _put_her_at(CLEARING_WEST + 120.0)
	_check(low < 1.5 and is_equal_approx(ink.remaining(), ink.capacity),
		"the last clearing's edge fills her ink", "%.1f -> %.1f" % [low, ink.remaining()])
	await _seconds(0.5)
	_check(finale.is_running() and finale.alive().size() == DilimFinale2D.WAVE_SIZE,
		"stepping in begins the night, two aswang on her",
		"running %s, %d alive" % [finale.is_running(), finale.alive().size()])


## Through the start, a fall and its replacement, and three seconds more.
func _never_more_than_two() -> void:
	await _seconds(3.0)
	_check(most_alive == 2, "never more than two at once", "at most %d" % most_alive)


## Hidden before the night, up once it begins, and following it -- a share of the night, no numbers --
## within a tick or two: the level reads it before the night has counted its own.
func _the_clock_comes_with_the_night() -> void:
	var clock := level.get("dawn_clock") as DawnClockHud
	_check(not bool(get_meta(&"clock_before", true)) and clock.visible
			and absf(clock.progress() - finale.progress()) < 2.0 / (60.0 * DilimFinale2D.DAWN_SECONDS)
			and clock.progress() > 0.0,
		"the night's clock comes up with it, and follows it",
		"before %s, now %s at %.3f of %.3f" % [get_meta(&"clock_before", true), clock.visible,
			clock.progress(), finale.progress()])
	var frame := (level.get("objective_banner") as Node).get_node(^"Panel") as Control
	var gap := clock.get_global_rect().position.y - frame.get_global_rect().end.y
	# And it follows the card: a taller card (a second line) pushes its frame's bottom down.
	frame.position.y += 30.0
	await _frames(3)
	var followed := clock.get_global_rect().position.y - frame.get_global_rect().end.y
	frame.position.y -= 30.0
	_check(gap >= 6.0 and gap <= 20.0 and absf(followed - gap) < 1.0,
		"and it sits under the quest card, clear of it, following it", "%.0f px between, %.0f after the card grew"
			% [gap, followed])


## In words and a number: the old strip said neither. The design's 90 s, not the script's table.
func _the_clock_says_how_long() -> void:
	var clock := level.get("dawn_clock") as DawnClockHud
	var read := []
	for at: float in [0.0, 45.0, 74.0, 76.0, 89.5, 89.9999, 90.0]:
		clock.set_progress(at / 90.0)
		read.append("%s %s" % [clock.caption(), clock.time_text()])
	clock.set_progress(finale.progress())
	_check(read == ["Morning in 1:30", "Morning in 0:45", "Morning in 0:16", "Almost morning 0:14",
			"Almost morning 0:01", "Almost morning 0:01", "Almost morning 0:01"]
			and DawnClockHud.CAPTION_FONT >= 20 and DawnClockHud.TIME_FONT >= 20,
		"the clock says what it is and how long is left, at the readable floor", "%s" % [read])
	_check(is_equal_approx(clock.mark_share(1), 27.0 / 90.0) and is_equal_approx(clock.mark_share(2), 60.0 / 90.0),
		"and the two moments the night changes are marked where they come",
		"%.3f and %.3f" % [clock.mark_share(1), clock.mark_share(2)])


## Kent: "start off as a moon and then slowly transform into a sun". Asked of the picture itself.
func _the_clock_starts_a_moon_and_ends_a_sun() -> void:
	var clock := level.get("dawn_clock") as DawnClockHud
	var start := clock.body_image(0.0)
	var quarter := clock.body_image(0.25)
	var half := clock.body_image(0.5)
	var dawn := clock.body_image(1.0)
	var lit := [_lit_share(start), _lit_share(quarter), _lit_share(half)]
	_check(lit[0] > 0.08 and lit[0] < 0.35 and lit[1] > lit[0] and lit[1] < 1.0 and is_equal_approx(lit[2], 1.0),
		"it starts a crescent, waxes, and is full by halfway", "lit %.2f, %.2f, %.2f" % lit)
	var warmth := [_warmth(start), _warmth(half), _warmth(clock.body_image(0.75)), _warmth(dawn)]
	_check(warmth[0] < 0.0 and warmth[1] < warmth[2] and warmth[2] < warmth[3] and warmth[3] > 0.2,
		"silver at the start, warming all the way to gold", "red over blue %.2f, %.2f, %.2f, %.2f" % warmth)
	var mid := DawnClockHud.BODY_SIDE / 2
	var off_the_edge := DawnClockHud.BODY_R + 2
	var rays := func(image: Image) -> int:
		var count := 0
		for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			if image.get_pixelv(Vector2i(mid, mid) + direction * off_the_edge).a >= 1.0:
				count += 1
		return count
	_check(rays.call(start) == 0 and rays.call(half) == 0 and rays.call(dawn) == 4,
		"no rays on the moon; by morning it has them all round",
		"%d, %d, %d" % [rays.call(start), rays.call(half), rays.call(dawn)])
	# Its craters go as it warms: one crater against a plain cell as far out, either side of the turn.
	var crater := Vector2i(mid - 4, mid + 1)
	var plain := Vector2i(mid - 4, mid - 1)
	var late := clock.body_image(0.8)
	_check(half.get_pixelv(crater) != half.get_pixelv(plain) and late.get_pixelv(crater) == late.get_pixelv(plain),
		"its craters show on the full moon and are gone by the time it is gold", "%s / %s, %s / %s"
			% [half.get_pixelv(crater), half.get_pixelv(plain), late.get_pixelv(crater), late.get_pixelv(plain)])
	var from := clock.body_at(0.0)
	var over := clock.body_at(0.5)
	var to := clock.body_at(1.0)
	var inside := Rect2(Vector2.ZERO, DawnClockHud.WINDOW.size)
	_check(from.x < over.x and over.x < to.x and from.y > over.y and over.y > to.y and inside.has_point(from)
			and inside.has_point(to) and over == over.round(),
		"and it crosses the window, rising, on whole pixels", "%s, %s, %s" % [from, over, to])


## How much of its face is lit: every cell of the disc that is not its dark side.
func _lit_share(image: Image) -> float:
	var mid := DawnClockHud.BODY_SIDE / 2
	var disc := 0
	var lit := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if Vector2(x - mid, y - mid).length() > DawnClockHud.BODY_R:
				continue
			disc += 1
			# Near, not equal: the image holds it in eight bits.
			var cell := image.get_pixel(x, y)
			if absf(cell.r - UISkin.MOON_DARK.r) + absf(cell.g - UISkin.MOON_DARK.g) + absf(cell.b - UISkin.MOON_DARK.b) > 0.02:
				lit += 1
	return float(lit) / disc


## Red over blue, on a cell of the disc that is lit at every phase: on the right, inside its rim.
func _warmth(image: Image) -> float:
	var mid := DawnClockHud.BODY_SIDE / 2
	var cell := image.get_pixel(mid + DawnClockHud.BODY_R - 2, mid - 2)
	return cell.r - cell.b


## What is happening, what she must do, and which of her things helps, with their keys, in order;
## and the one line on arriving that names all three, in the box.
func _the_night_says_what_is_happening() -> void:
	# Its four lines go by at reading speed, held while a line in the box is up.
	await _seconds(5.0)
	var slots := (level.get("satchel") as Satchel).slots()
	var key := func(id: String) -> String: return String(level.call("_slot_key", slots.find(id)))
	var expected: Array[String] = ["They keep coming. Nothing has to fall: I only have to last.",
		"%s throws salt. It burns what it lands on." % key.call("asin"),
		"%s crushes garlic. They will not cross the ring for ten seconds." % key.call("bawang"),
		"Something as bright as day would bring the morning on."]
	var at := -1
	var in_order := true
	for line in expected:
		var found := heard.find(line)
		in_order = in_order and found > at
		at = found
	_check(in_order, "as the night starts she says what is happening and which of her things help, with their keys",
		"%s" % [heard])
	var script_lines = level.get("script_lines")
	var arriving: Array[String] = []
	for line: Dictionary in script_lines.peek("L4_FINALE.enter"):
		arriving.append(String(line.get("text", "")))
	_check(arriving.has("Salt burns them. Garlic keeps them off. Ash shows the one I cannot see."),
		"and on arriving, where nothing is moving yet, she says what each is for", "%s" % [arriving])
	_check(String((level.get("objective_banner") as ObjectiveBanner).text()) == "Last until morning. Keep the lamp lit.",
		"and the quest card says what to do", (level.get("objective_banner") as ObjectiveBanner).text())


## Wings, while there are wings; the ash, while the tik-tik is about and she has ash; and the plain
## task once neither is true. Asked of what is after her, never of the wave. And the ash's key is said
## this time round though the clock already ran through this wave once: the knockout that started the
## night over cut that telling off, and a line she never read has not been said.
func _the_banner_goes_with_what_is_after_her() -> void:
	var banner := level.get("objective_banner") as ObjectiveBanner
	var satchel := level.get("satchel") as Satchel
	var slots := satchel.slots()
	var told := "%s is the ash. When the lamp leans it is close: throw it then." \
		% String(level.call("_slot_key", slots.find("abo")))
	await _seconds(4.5)
	_check(heard.has(told), "and as the third wave came she said which key is the ash, and when", "%s" % [heard.slice(-3)])
	# Asked directly: the card refreshes on a timer, and these are about what it says, not when.
	level.call("refresh_objective")
	var words := [banner.text()]
	# A fall may have dropped more of it by now.
	while satchel.count("abo") > 0:
		satchel.take("abo")
	level.call("refresh_objective")
	words.append(banner.text())
	for foe in finale.alive():
		if foe is FlyingEnemy2D:
			foe.crush(99)
	level.call("refresh_objective")
	words.append(banner.text())
	satchel.add("abo", 1)
	_check(words == ["Last until morning. Ash shows what I cannot see.", "Last until morning. Step aside when they dive.",
			"Last until morning. Keep the lamp lit."],
		"the quest card goes with what is after her: the ash, then the wings, then the plain task", "%s" % [words])


func _one_falls_and_another_comes() -> void:
	var foe: Enemy2D = finale.alive()[0]
	var apo := level.get("player") as Node2D
	for _blow in range(foe.max_hp):
		foe.apply_tool_hit("sword", 0.0, apo)
	# Read now: a fallen one is cleared away once it has faded.
	var fell := foe.is_dead()
	await _seconds(1.0)
	var one := finale.alive().size()
	# The design's six seconds, not the script's constant: a shorter one would move the wait too.
	await _seconds(6.0 - 1.6)
	var still_one := finale.alive().size()
	await _seconds(1.0)
	_check(fell and one == 1 and still_one == 1 and finale.alive().size() == 2,
		"one falls, and another comes 6 s later",
		"%d, then %d just short of it, then %d" % [one, still_one, finale.alive().size()])


## The satchel is for the night: ash thrown on one of its aswang blinds it, and salt burns one.
func _ash_and_salt_reach_the_night() -> void:
	var foes := finale.alive()
	var plane := level.get_node(^"EnvironmentBaseplate/GameplayPlane")
	var dust := AboDust2D.new()
	dust.position = foes[0].global_position
	plane.add_child(dust)
	await _frames(2)
	_check(foes[0].state_name() == "STUN", "ash on one of the night's aswang blinds it", foes[0].state_name())
	var salt := AsinThrow2D.new()
	salt.position = foes[1].global_position
	plane.add_child(salt)
	await _frames(3)
	_check(foes[1].is_burning(), "and salt on one burns it", "burning %s" % foes[1].is_burning())


func _dawn_brightens_from_halfway() -> void:
	var dark := level.get("darkness_layer") as DarknessLayer
	var band := level.get_node("EnvironmentBaseplate/ForestBand")
	var art := band.get_child(0) as Sprite2D
	finale.elapsed = 44.5
	await _frames(2)
	var night := dark.darkness
	finale.elapsed = 45.0
	await _frames(2)
	_check(absf(finale.progress() - 0.5) < 0.002 and dark.darkness > 0.94,
		"the 90 s night stays dark until its 45 s midpoint", "progress %.3f, dark %.3f" % [finale.progress(), dark.darkness])
	finale.elapsed = 67.5
	await _frames(3)
	_check(absf(dark.darkness - night * 0.5) < 0.025
		and art.modulate.r > 0.6 and art.modulate.r < 0.75,
		"the second half gradually lifts darkness and the backdrop's night grade",
		"dark %.3f of %.3f, backdrop %s" % [dark.darkness, night, art.modulate])
	finale.elapsed = 89.5
	await _frames(2)
	_check(finale.is_running() and not finale.has_dawned() and dark.darkness < 0.002
		and art.modulate.r > 0.99,
		"the scene is already fully visible as the clock approaches 90 s",
		"dark %.4f, backdrop %s" % [dark.darkness, art.modulate])


func _a_knockout_starts_the_night_over() -> void:
	var before := finale.elapsed
	# Read before it: a clock nobody is feeding reads 1:30 all night, which looks like starting over.
	var read_before := (level.get("dawn_clock") as DawnClockHud).time_text()
	level.call("_knockout")
	await _frames(4)
	_grace()
	await _seconds(0.5)
	var clock := level.get("dawn_clock") as DawnClockHud
	var clock_read := clock.time_text()
	_check(clock.visible and read_before != clock_read and clock_read in ["1:30", "1:29"] and not clock.is_morning(),
		"and its clock starts over with it", "visible %s, %s then %s" % [clock.visible, read_before, clock_read])
	_check(before > 5.0 and finale.is_running() and finale.elapsed < 1.0
			and finale.alive().size() == DilimFinale2D.WAVE_SIZE
			and (level.get("darkness_layer") as DarknessLayer).darkness > 0.9
			and (level.get_node("EnvironmentBaseplate/ForestBand").get_child(0) as Sprite2D).modulate
				== level.get_node("EnvironmentBaseplate/ForestBand").tint,
		"a knockout starts the night over", "%.1f s in, then %.1f s, %d alive"
			% [before, finale.elapsed, finale.alive().size()])
	# A retried night says what is happening again, and does not read her the list again.
	await _seconds(4.5)
	var said := (level.get("hint_bar") as HintBar).current_text()
	var openings := heard.count("They keep coming. Nothing has to fall: I only have to last.")
	var salts := 0
	for line in heard:
		if line.ends_with("throws salt. It burns what it lands on."):
			salts += 1
	_check(openings == 2 and salts == 1, "and a retried night says what is happening, not the list of her things again",
		"said so %d times, salt %d, now \"%s\"" % [openings, salts, said])


## What the bar says once it comes to this, or what it says if it never does.
##
## ⚠ NOT ON THE SAME FRAME. This probe jumps straight to the night, so her first spend and her first
## sight of the tik-tik fall here, and a remark is read before what follows takes the bar
## (HintBar.show_beat). In play those were said long before.
func _bar_comes_to(start: String) -> String:
	var hints := level.get("hint_bar") as HintBar
	var began := Time.get_ticks_msec()
	while not hints.current_text().begins_with(start) and Time.get_ticks_msec() - began < 8000:
		await _frames(1)
	return hints.current_text()


## The shortened night's 27 s and 60 s, not the script's table, within half a second.
func _the_waves_come_on_time() -> void:
	finale.elapsed = 26.5
	await _frames(2)
	var before_second := finale.current_wave()
	await _seconds(1.0)
	var second := finale.current_wave()
	var box := level.get("dialogue_box") as Node
	var said_second := await _bar_comes_to("Wings over the trees")
	var boxed := bool(box.call("is_open"))
	var fliers := []
	for foe in finale.alive():
		if foe is FlyingEnemy2D:
			fliers.append(foe)
	finale.elapsed = 59.5
	await _frames(2)
	var before_third := finale.current_wave()
	await _seconds(1.0)
	var said_third := await _bar_comes_to("Tik... tik...")
	boxed = boxed or bool(box.call("is_open"))
	_check(said_second.begins_with("Wings over the trees") and said_third.begins_with("Tik... tik...") and not boxed,
		"and as each later wave comes she says what it is, on the hint bar and not the story box",
		"\"%s\" / \"%s\", box open %s" % [said_second, said_third, boxed])
	_check(before_second == 0 and second == 1 and before_third == 1 and finale.current_wave() == 2,
		"the second wave comes at 27 s, the third at 60 s", "%d then %d, %d then %d"
			% [before_second, second, before_third, finale.current_wave()])
	var kinds := []
	var drive_off := 0
	var drawn := false
	for foe: Enemy2D in fliers:
		kinds.append(foe.kind)
		if foe is ManananggalUpper2D:
			drive_off = foe.max_hp
		# Its own body, readable in her light -- not the base's dark box.
		drawn = drawn or foe is Wakwak2D
	kinds.sort()
	_check(kinds == ["manananggal_upper", "wakwak"] and drive_off == 8 and drawn,
		"and the second brings the manananggal, driven off at 8, and a wakwak",
		"%s, driven off at %d, wakwak drawn %s" % [kinds, drive_off, drawn])
	_check(finale.tiktik() != null and finale.tiktik().kind == "tiktik", "and the third brings the tik-tik",
		"%s" % finale.tiktik())


## The design's 15 s, once a wave: a second sun in the same wave changes nothing.
func _a_sun_hurries_the_morning() -> void:
	var before := finale.elapsed
	var first := await _set_down("sun", Vector2(CLEARING_WEST + 300.0, 300.0))
	var jumped := finale.elapsed - before
	var clock := level.get("dawn_clock") as DawnClockHud
	var caption := clock.caption()
	var gliding := clock.shown() < clock.progress()
	await _seconds(0.8)
	var arrived := is_equal_approx(clock.shown(), clock.progress())
	var told := await _bar_comes_to("The morning came nearer.")
	_check(caption == "15 s nearer" and gliding and arrived and told == "The morning came nearer.",
		"and the clock shows it: it says how much nearer, the body glides there, and she says so",
		"\"%s\", gliding %s then there %s, \"%s\"" % [caption, gliding, arrived, told])
	before = finale.elapsed
	var second := await _set_down("sun", Vector2(CLEARING_WEST + 600.0, 300.0))
	var again := finale.elapsed - before
	_check(jumped > 14.9 and jumped < 15.5 and again < 0.5,
		"a sun drawn in the night brings the morning 15 s on, once a wave",
		"%.1f s on, then %.1f s for the second" % [jumped, again])
	first.queue_free()
	second.queue_free()


## The design's tree: standing it stops no one; felled by something that cuts, it comes down on the
## walkers under it for 8, lies there as a wall they do not cross, and from then on the night sends
## its aswang only from the west. Late in the night on purpose: a felled tree stays down.
func _the_dead_tree() -> void:
	var tree := finale.tree
	var foot := tree.global_position.x
	await _put_her_at(foot - 120.0)
	Input.action_press(&"move_right")
	await _seconds(1.2)
	Input.action_release(&"move_right")
	var walked := (level.get("player") as Node2D).global_position.x
	_check(tree != null and walked > foot + 40.0, "standing, the dead tree stops no one",
		"walked from %.0f to %.0f, its foot at %.0f" % [foot - 120.0, walked, foot])
	# The woods' own tree, not Level 1's on loan: its trunk drawn up the box a swing finds, from
	# the ground, across its width.
	var standing := tree.get_node_or_null(^"Trunk/Art") as PixelStripAnimator
	var half := tree.trunk_size.x * 0.4
	_check(standing != null and standing.anim() == "idle"
			and standing.texture.resource_path == "res://assets/Level4/trees/dead_tree_idle.png"
			# The supplied roots split at the bottom center; sample the wood just above that gap.
			and _drawn_at(standing, Vector2(0.0, -8.0)) and _drawn_at(standing, Vector2(-half, -120.0))
			and _drawn_at(standing, Vector2(half, -120.0)) and _drawn_at(standing, Vector2(0.0, -tree.trunk_size.y * 0.6)),
		"and it is the woods' own dead tree, its trunk drawn where a swing finds it",
		"%s" % (standing.texture.resource_path if standing != null else "no drawn art"))
	# One of the night's walkers where it will fall, sturdier than it is so the 8 can be read.
	var under: Enemy2D = null
	for foe in finale.alive():
		if foe is GroundEnemy2D:
			under = foe
	under.global_position = Vector2(foot + 140.0, GROUND_Y - under.body_size.y * 0.5)
	under.hp = 20
	await _put_her_at(foot - 60.0)
	for _blow in range(4):
		if not tree.is_open():
			tree.apply_tool_hit("axe", 420.0, level.get("player") as Node2D)
	await _frames(2)
	_check(tree.is_open() and under.hp == 12, "felled, it comes down on a walker under it for 8",
		"felled %s, hp 20 -> %d" % [tree.is_open(), under.hp])
	# Lying, its own picture -- not the standing one turned on its side -- and the wood of it is
	# the wall the walkers meet: its top along the trunk's top end to end, its underside on the
	# ground.
	var lying := tree.get_node_or_null(^"Art") as PixelStripAnimator
	var tops: Array[float] = []
	var rests := true
	if lying != null:
		for x in [100.0, 140.0, 200.0, 240.0]:
			tops.append(_top_at(lying, x))
		for x in [30.0, 140.0, 250.0]:
			rests = rests and _drawn_at(lying, Vector2(x, -8.0))
	var flush := not tops.is_empty()
	for top in tops:
		flush = flush and absf(top + tree.span_height) <= 6.0
	_check(lying != null and lying.anim() == "felled" and is_zero_approx(lying.rotation) and flush and rests,
		"and it lies as a log over the trunk that stops them, not the standing tree on its side",
		"tops %s against %.0f, on the ground %s" % [tops, -tree.span_height, rests])
	# The walkers that meet it at its root plate are drawn in front of it, and so is she.
	var figure := (level.get("player") as Node2D).find_child("Figure", true, false) as CanvasItem
	_check(_drawn_over(under, tree) and figure != null and _drawn_over(figure, tree),
		"and the walkers meeting it are drawn in front of it, not hidden in it, and so is she",
		"tree z %d, walker z %d, her z %d" % [_absolute_z(tree), _absolute_z(under), _absolute_z(figure) if figure != null else -99])
	# East of the trunk lying there, with her west of it: it comes up to it and does not get across.
	# Dropped in a little above the ground to settle: set exactly on it, its look for ground ahead
	# starts on the surface, finds none, and it will not walk at all.
	var end := foot + tree.span_length
	under.global_position = Vector2(end + 160.0, GROUND_Y - under.body_size.y * 0.5 - 8.0)
	await _put_her_at(foot - 250.0)
	await _seconds(3.0)
	var at := under.global_position.x
	_check(at > end and at < end + under.body_size.x, "and lying there it is a wall the aswang do not cross",
		"came from %.0f to %.0f, the trunk ends at %.0f" % [end + 160.0, at, end])
	# Two sent after it, one after the other: both from the west.
	var sides: Array[float] = []
	for _send in range(2):
		for foe in finale.alive():
			if foe is GroundEnemy2D:
				foe.crush(99)
		await _frames(2)
		finale.call("_send_one")
		var foes: Array = finale.get("_foes")
		sides.append(signf((foes.back() as Node2D).global_position.x - finale.global_position.x))
	_check(sides == [-1.0, -1.0], "and the night sends its aswang only from the west after", "%s" % [sides])


func _morning_ends_it() -> void:
	var said := [false]
	var box := level.get("dialogue_box") as Node
	# After the level's own answer to it has begun -- connected later, so called later.
	finale.dawned.connect(func() -> void:
		said[0] = true
		var clock := level.get("dawn_clock") as DawnClockHud
		set_meta(&"clock_at_dawn", [clock.is_morning(), clock.visible, clock.caption(), clock.time_text()])
		set_meta(&"card_at_dawn", (level.get("objective_banner") as ObjectiveBanner).text())
		set_meta(&"dawn_line", String(box.call("current_line"))))
	# Lines left up for the dawn's to be read: the probe otherwise dismisses each as it comes.
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", false)
	finale.elapsed = 89.5
	await _seconds(0.8)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _seconds(DilimFinale2D.FLEE_FADE + 0.4)
	var left := 0
	for node in finale.find_children("*", "", true, false):
		if node is Enemy2D and not node.is_queued_for_deletion():
			left += 1
	_check(said[0] and finale.has_dawned() and not finale.is_running() and left == 0,
		"morning ends it, and they go", "dawned %s, %d still in the clearing" % [said[0], left])
	var at_dawn: Array = get_meta(&"clock_at_dawn", [])
	_check(at_dawn == [true, true, "", "0:00"], "and the clock stays up through her line, saying morning", "%s" % [at_dawn])
	_check(String(get_meta(&"card_at_dawn", "")) == "Morning. The night is over.",
		"and the quest card says so before her line stops the tree", "\"%s\"" % get_meta(&"card_at_dawn", ""))


## Her line, then the dark gone and the level finished: the majority route settled.
func _the_dark_lifts_and_she_is_through() -> void:
	var line := String(get_meta(&"dawn_line", ""))
	_check(line.begins_with("Morning. Lola named every one"), "at dawn she says what the night was for",
		"\"%s\"" % line)
	await _seconds(3.5)
	var dark := float((level.get("darkness_layer") as Node).get(&"darkness"))
	_check(dark < 0.05 and bool(level.get("_level_completed")), "the dark lifts, and the level is done",
		"dark %.2f, completed %s" % [dark, level.get("_level_completed")])
	var profile := root.get_node(^"PlayerProfile")
	var gained := _route_points() - int(get_meta(&"routes_before", 0))
	_check(gained == 1 and String(profile.call("last_route", "level_4")) == "artist",
		"and the morning gives the level its one route point, the way it was answered",
		"%d point(s), last route '%s'" % [gained, profile.call("last_route", "level_4")])


# --- Helpers -------------------------------------------------------------------------------

## Every route point the profile has given, all routes together.
func _route_points() -> int:
	var total := 0
	for count: Variant in (root.get_node(^"PlayerProfile").call("route_counts") as Dictionary).values():
		total += int(count)
	return total


func _open_level() -> Node:
	var scene := (load("res://level_4.tscn") as PackedScene).instantiate()
	(scene.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(scene)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(30)
	return scene


func _set_down(entity_id: String, at: Vector2) -> UtilityObject:
	var thing := (level.get("registry") as EntityRegistry).instantiate_entity(entity_id) as UtilityObject
	level.get_node(^"EnvironmentBaseplate/GameplayPlane").add_child(thing)
	thing.global_position = at
	thing.freeze = true
	await _frames(4)
	return thing


func _put_her_at(x: float) -> void:
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": Vector2(x, GROUND_Y - 4.0), "linear_velocity": Vector2.ZERO})
	_grace()
	await _frames(6)


## A long grace: the dogs reach her and land nothing.
func _grace() -> void:
	(level.get("player_health") as PlayerHealth).call("_start_grace", 600.0)


## Whether `art` has a pixel drawn at `at`, in its parent's space (it is never turned).
## Whether `a` is drawn over `b`: higher from the root, or as high and later in the tree.
func _drawn_over(a: CanvasItem, b: CanvasItem) -> bool:
	var za := _absolute_z(a)
	var zb := _absolute_z(b)
	return za > zb or (za == zb and a.is_greater_than(b))


func _absolute_z(item: CanvasItem) -> int:
	var z := 0
	var node: Node = item
	while node is CanvasItem:
		z += (node as CanvasItem).z_index
		if not (node as CanvasItem).z_as_relative:
			break
		node = node.get_parent()
	return z


func _drawn_at(art: Sprite2D, at: Vector2) -> bool:
	var image := art.texture.get_image()
	var pixel := Vector2i((at - art.position - art.offset).floor())
	return Rect2i(Vector2i.ZERO, image.get_size()).has_point(pixel) and image.get_pixelv(pixel).a > 0.0


## The height of the topmost pixel `art` draws at `x`, in its parent's space; INF where it draws none.
func _top_at(art: Sprite2D, x: float) -> float:
	var image := art.texture.get_image()
	var column := int(floorf(x - art.position.x - art.offset.x))
	if column < 0 or column >= image.get_width():
		return INF
	for row in range(image.get_height()):
		if image.get_pixel(column, row).a > 0.0:
			return art.position.y + art.offset.y + row
	return INF


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		if finale != null and is_instance_valid(finale):
			most_alive = maxi(most_alive, finale.alive().size())
		_listen()
		if paused:
			call_group(DialogueBox.GROUP, &"hide_line")
			paused = false


func _listen() -> void:
	var hints := level.get("hint_bar") as HintBar if level != null and is_instance_valid(level) else null
	if hints == null or not hints.is_showing():
		return
	var text := hints.current_text()
	if heard.is_empty() or heard.back() != text:
		heard.append(text)


func _seconds(seconds: float) -> void:
	await _frames(int(ceil(seconds * 60.0)))


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
