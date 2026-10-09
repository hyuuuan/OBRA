extends SceneTree
## Does Dagat's encounter actually resolve, all three ways?
##
##   godot --headless --path game --script res://tests/run_bakunawa_probe.gd
##
## The most expensive single item in the level, and the one with the most ways to be quietly
## wrong: a channel that never opens is a level that cannot be finished, a sweep that never
## sees anybody is a stealth section with no stealth in it, and a creature that cannot be hit
## is a Protector route that is a second Pragmatist.
##
## ⚠ EVERY SEGMENT UNPAUSES THE TREE FIRST. Committing a route speaks the apo's line, a
## DialogueBox pauses the tree, and nothing moves after that -- a creature frozen mid-sweep
## reads exactly like a creature whose logic is broken. Three rounds of this level's own
## development went into bodies that "would not simulate" and were simply standing still.

const BakunawaClass = preload("res://scripts/bakunawa_2d.gd")

var level: Node
var results: Array[String] = []
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	results.append("  %s  %-40s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _run() -> void:
	print("\n===== THE BAKUNAWA =====")
	await _the_light()
	await _the_dark()
	await _the_fight()
	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_BAKUNAWA_OK")
		quit(0)
	else:
		print("OBRA_BAKUNAWA_FAILED=%d" % failures)
		quit(1)


# --- The three resolutions ---------------------------------------------------------------

func _the_light() -> void:
	var bits := await _open_at_the_encounter("artist")
	if bits.is_empty():
		_check(false, "the light: set up", "could not reach the encounter")
		return
	var creature: BakunawaClass = bits["bakunawa"]
	var director = bits["director"]
	var profile = root.get_node_or_null("PlayerProfile")
	# The flashlight is accepted, which answers the beat. The flower comes from what the
	# creature then does, not from the drawing.
	director.call("note_submission", "flashlight")
	await physics_frame
	_check(creature.state() == BakunawaClass.State.FOLLOWING,
		"the light: it goes to the light",
		"state %d" % creature.state())
	# ⚠ LED HOME, THEN IT GIVES (2026-10-05). Kent: the light follows the pointer, the creature
	# follows the light, and it is brought home to a cave under the first beach -- where it goes in,
	# and what it had lost comes out to the apo. Brought within reach of the cave here; the sea
	# probe leads it by the light.
	var mouth: Vector2 = level.get("_cave_mouth")
	creature.global_position = mouth + Vector2(380.0, -260.0)
	level.set("lure_override", mouth)
	for _frame in range(600):
		await physics_frame
		if paused:
			await _unpause()
		if creature.is_gone():
			break
	_check(creature.state() == BakunawaClass.State.CALM and creature.is_gone(),
		"and it finds what it lost: home", "state %d, gone in %s" % [creature.state(),
			creature.is_gone()])
	_check(bool(profile.call("is_collectible_found", "L3_HF")),
		"and hands over the flower", "L3_HF recorded")
	# ⚠ AND BOTH THINGS IT GIVES ARE SEEN TO BE TAKEN, in the order they come: the torn corner
	# of her canvas it had been searching for, then the flower. The corner was left lying on the
	# seabed with no card at all (Kent: what is found at the bottom "should have the acquired pop
	# up since its an acquired"). Read off the card as it plays, every distinct title in turn.
	var cards: Node = null
	for node in get_nodes_in_group(&"modal_overlays"):
		if node is AcquiredOverlay:
			cards = node
	var titles: Array[String] = []
	for _frame in range(720):
		await physics_frame
		if cards != null and bool(cards.call("is_open")):
			var title := (cards.get("_title") as Label).text
			if titles.is_empty() or titles.back() != title:
				titles.append(title)
		if titles.has("Hidden Flower"):
			break
	_check(titles.size() >= 2 and titles[0] == "A Torn Corner" and titles[1] == "Hidden Flower",
		"and gives the corner, then the flower, each with its card", str(titles))
	_check(String(profile.call("bakunawa_outcome")) == "LIT",
		"and the run remembers how", String(profile.call("bakunawa_outcome")))
	_check(not creature.sees(creature.global_position + Vector2(120.0, 0.0)),
		"and a calm one sees nobody", "the sweep is down")
	_check(await _channel_is_open(creature), "and the way on is open", "coils disabled")
	# ⚠ AND THEN IT GOES. Found what it lost, it stayed coiled where it was for the rest of the
	# level; it swims off now, once what it found has been given.
	var gone_after := -1.0
	for _frame in range(960):
		await physics_frame
		if creature.is_gone():
			gone_after = float(_frame) / 60.0
			break
	# Home, it is gone into the cave before what it held comes out -- so it may be gone already.
	_check(gone_after >= 0.0 and not creature.visible, "and is gone, once it has given it",
		"gone after %.1f s" % gone_after if gone_after >= 0.0 else "still there after 16 s")
	_close()


func _the_dark() -> void:
	var bits := await _open_at_the_encounter("pragmatist")
	if bits.is_empty():
		_check(false, "the dark: set up", "could not reach the encounter")
		return
	var creature: BakunawaClass = bits["bakunawa"]
	var director = bits["director"]
	_check(await _channel_is_open(creature),
		"the dark: a gap opens on the commit", "coils disabled")
	# ⚠ IT MOVES. Kent: "the bakunawa should move" -- it was set down once and held still,
	# though Lolo's first words about it are "back and forth over the same stretch".
	var least := INF
	var most := -INF
	for _frame in range(420):
		await physics_frame
		least = minf(least, creature.global_position.x)
		most = maxf(most, creature.global_position.x)
	_check(most - least > 60.0, "and it goes back and forth over its stretch",
		"%.0f px of drift in seven seconds" % (most - least))
	# THE SWEEP HAS TO CATCH SOMEBODY. A cone that never returns true is a stealth section
	# with no stealth in it, and it looks identical to a well-played one in a report.
	var caught := false
	var missed := false
	for _frame in range(240):
		await physics_frame
		if creature.sees(creature.global_position + Vector2(300.0, 0.0)):
			caught = true
		else:
			missed = true
		if caught and missed:
			break
	_check(caught, "and the sweep catches somebody in it", "a point ahead of it was seen")
	_check(missed, "and misses them the rest of the time",
		"the same point was unseen as the sweep travelled")
	# Straight down, below the body, is where the design says to swim.
	var below: Vector2 = creature.global_position + Vector2(0.0, 340.0)
	_check(not creature.sees(below), "and below it is dark", "the way past is under it")
	# ⚠ AND THERE IS ROOM TO WAIT UNDER IT. "Below it is dark" was true of a strip 34 px wide.
	# Measured with the creature's own sees() over its whole sweep, at the bed a swimmer holds to.
	var bed := float((load("res://scripts/level_3.gd") as GDScript).get_script_constant_map()["BED_Y"])
	var home: Vector2 = creature.get("_home")
	var shadow := _shadow_under(creature, home, bed - BED_CLEARANCE)
	_check(shadow >= 60.0, "and there is room to wait under it",
		"%.0f px of the bed below it the beam never reaches" % shadow)
	# ⚠ AND NO DEPTH IS OUT OF ITS LIGHT. Kent: "i can get pass through it easily like the light
	# is not doing anything". Its beam reached 460 px from a creature 950 px under the surface,
	# so everything above y ~1050 was out of reach and a swimmer along the top was never seen --
	# finished the level in thirteen seconds holding right. Held forward at a fast swimmer's
	# speed from outside its reach, at every depth from under the surface to the bed, a run
	# that does not watch the light has to be caught at least two times in three. Measured when
	# this went in: 70% right under the surface (the water farthest from its eyes), 88% just
	# below, 100% at every depth from there to the bed -- against 0% anywhere above y 1034.
	var worst := 1.0
	var worst_at := 0.0
	var free: Array[String] = []
	var depth := 600.0
	while depth <= bed - BED_CLEARANCE + 0.5:
		var caught_share := 1.0 - _blind_runs(creature, home, depth, FAST_SWIM, 60)
		if caught_share < worst:
			worst = caught_share
			worst_at = depth
		# ⚠ UNDER ITS BELLY THE BAR IS LOWER, ON PURPOSE. Kent (2026-10-05): "there should be space
		# below the sea serpent where we can dodge the lights". The lane along the bottom is the way
		# past -- dark straight under it, lit either side while it looks down -- so a blind run there
		# is meant to get through more often than in open water. Not free: caught one time in three.
		var under_it := depth > home.y + creature.drawn_size().y * 0.5
		if caught_share < (1.0 / 3.0 if under_it else 2.0 / 3.0):
			free.append("y %.0f caught %.0f%%" % [depth, caught_share * 100.0])
		depth += 108.6
	_check(free.is_empty(), "and no depth is out of its light",
		"a blind run at %.0f px/s caught at least %.0f%% of the time at every depth (worst y %.0f)"
			% [FAST_SWIM, worst * 100.0, worst_at] if free.is_empty() else ", ".join(free))
	# ⚠ AND A PLAYER WHO WATCHES IT STILL GETS PAST, slowly. Closing the free lane must not close
	# the way: at the bed (through the shadow under it) and along the top, a swimmer at the slow
	# speed a swimmer makes along the bed, stopping and backing off and going when it looks
	# away, gets past from wherever in its cycle they arrive -- searched, not hoped for.
	var period := 2.0 * (creature.sweep_range().y - creature.sweep_range().x) / BakunawaClass.SWEEP_SPEED
	# ⚠ THE BED ONLY, SINCE 2026-10-05. Lifted off the bottom so there is room under it (Kent:
	# "space below the sea serpent where we can dodge the lights"), it is nearer the surface, and
	# the top of the water is in its reach for most of the sweep: the way past is under it now, and
	# Lolo says so ("Keep low, along the bottom"). Along the top was the other way when it lay on
	# the bed; it is not asked of it any more.
	for lane: Array in [["along the bed", bed - BED_CLEARANCE]]:
		var slowest := 0.0
		var stuck := 0
		for phase in range(4):
			var took := _careful_run(creature, home, float(lane[1]), BED_SWIM, float(phase) * period * 0.83)
			if took < 0.0:
				stuck += 1
			slowest = maxf(slowest, took)
		_check(stuck == 0 and slowest <= 45.0, "and a careful swimmer gets past %s" % lane[0],
			"from 4 of 4 arrivals at %.0f px/s, the slowest in %.0f s" % [BED_SWIM, slowest]
				if stuck == 0 else "stuck from %d of 4 arrivals" % stuck)
	# A lit flashlight gives the player away wherever they are.
	_check(creature.sees(below, true), "unless you brought a light",
		"drawing one and then sneaking is a harder encounter, on purpose")
	# ⚠ FROM THE BOAT THE OLD SWEEP STAYS, AND THE BOAT CAN STILL TIME IT. Staged just under
	# the hull, the boat's lane is level with it, where two beams rising and falling together
	# would light it nearly all the time.
	var surface := level.call("_mark", "SurfaceMark") as Node2D
	creature.stage_at(surface.global_position.y)
	var surfaced_home: Vector2 = creature.get("_home")
	_check(is_equal_approx(creature.reach(), BakunawaClass.CONE_LENGTH),
		"and from the boat its light is the short sweep", "reach %.0f" % creature.reach())
	var boat_period := 2.0 * (creature.sweep_range().y - creature.sweep_range().x) / BakunawaClass.SWEEP_SPEED
	var boat_stuck := 0
	for phase in range(4):
		if _careful_run(creature, surfaced_home, surface.global_position.y - 170.0, FAST_SWIM,
				float(phase) * boat_period * 0.83) < 0.0:
			boat_stuck += 1
	_check(boat_stuck == 0, "and the boat can time its way past it",
		"from 4 of 4 arrivals" if boat_stuck == 0 else "stuck from %d of 4 arrivals" % boat_stuck)
	# Reaching the far side answers the beat: past it, and out of its light.
	var player := level.get("player") as Node2D
	player.global_position = Vector2(creature.global_position.x + creature.reach() + 60.0, 480.0)
	for _frame in range(20):
		await physics_frame
	_check(bool(director.call("is_solved", "L3_N2")),
		"and getting past answers the beat", "solved by the dark, with nothing drawn at it")
	_close()


## How fast a swimmer makes along the bed holding right and down, and how far above the bed its
## anchor rides there. Clocked, not assumed: a fish on the Dagat bed covers about 25 px every
## quarter second at y 1686, with the bed at 1709. FAST_SWIM is a fish held forward in open water
## (run_swim_reach_probe), and the boat's own pace is about the same.
const BED_SWIM := 100.0
const FAST_SWIM := 150.0
const BED_CLEARANCE := 23.0


## Put the creature where it would be `t` seconds into its drift and its sweep, as
## Bakunawa2D._process and _drift move it, and return where it is.
func _at_moment(creature: BakunawaClass, home: Vector2, t: float) -> Vector2:
	var ends := creature.sweep_range()
	creature.set("_sweep", _sweep_at(t, ends, BakunawaClass.SWEEP_SPEED))
	creature.global_position = home + Vector2(
		sin(t * TAU / BakunawaClass.PATROL_PERIOD) * BakunawaClass.PATROL_REACH,
		sin(t * TAU / BakunawaClass.BOB_PERIOD) * BakunawaClass.BOB)
	return creature.global_position


## How much of the bed straight under it the beam never reaches, held still at home.
func _shadow_under(creature: BakunawaClass, home: Vector2, bed_y: float) -> float:
	var kept_at := creature.global_position
	var kept_sweep := float(creature.get("_sweep"))
	var ends := creature.sweep_range()
	creature.global_position = home
	var shadow := 0.0
	for across in range(-200, 201, 2):
		var ever := false
		for step in range(160):
			creature.set("_sweep", lerpf(ends.x, ends.y, float(step) / 159.0))
			if creature.sees(home + Vector2(float(across), bed_y - home.y)):
				ever = true
				break
		if not ever:
			shadow += 2.0
	creature.global_position = kept_at
	creature.set("_sweep", kept_sweep)
	return shadow


## A straight run at one depth, held forward at `speed` from outside its reach until past it
## (the level's own rule: 420 east of it): the share of arrival times that go unseen.
func _blind_runs(creature: BakunawaClass, home: Vector2, depth_y: float, speed: float,
		tries: int) -> float:
	var kept_at := creature.global_position
	var kept_sweep := float(creature.get("_sweep"))
	var ends := creature.sweep_range()
	var period := 2.0 * (ends.y - ends.x) / BakunawaClass.SWEEP_SPEED
	var unseen := 0
	for attempt in range(tries):
		# Spread over three sweeps, so the drift's phase varies as well as the sweep's.
		var t := float(attempt) / float(tries) * period * 3.0
		var x := home.x - creature.reach() - 150.0
		var seen := false
		while true:
			var at := _at_moment(creature, home, t)
			if x > at.x + 420.0:
				break
			if creature.sees(Vector2(x, depth_y)):
				seen = true
				break
			t += 0.02
			x += speed * 0.02
		if not seen:
			unseen += 1
	creature.global_position = kept_at
	creature.set("_sweep", kept_sweep)
	return float(unseen) / float(tries)


## Can a swimmer who watches it get past at this depth -- stopping, backing off, going when it
## looks away? Every place they could be, a tenth of a second at a time, from outside its reach
## at `t0`. The seconds the quickest way takes, or -1 if there is none within a minute.
func _careful_run(creature: BakunawaClass, home: Vector2, depth_y: float, speed: float,
		t0: float) -> float:
	var kept_at := creature.global_position
	var kept_sweep := float(creature.get("_sweep"))
	var tick := 0.1
	var stride := speed * tick
	var start := home.x - creature.reach() - 150.0
	var places := {0: true}
	var t := t0
	var took := -1.0
	for _step in range(600):
		t += tick
		var at := _at_moment(creature, home, t)
		var next := {}
		for place: int in places:
			for move in [-1, 0, 1]:
				var p: int = place + move
				if p < 0 or next.has(p):
					continue
				var x := start + float(p) * stride
				if creature.sees(Vector2(x, depth_y)):
					continue
				if x > at.x + 420.0:
					took = t - t0
					break
				next[p] = true
			if took >= 0.0:
				break
		if took >= 0.0 or next.is_empty():
			break
		places = next
	creature.global_position = kept_at
	creature.set("_sweep", kept_sweep)
	return took


## The sweep's angle `t` seconds into its travel between `ends` (up, down) and back -- the bounce
## Bakunawa2D._process makes.
static func _sweep_at(t: float, ends: Vector2, speed: float) -> float:
	var leg := (ends.y - ends.x) / speed
	t = fposmod(t, 2.0 * leg)
	if t < leg:
		return ends.x + speed * t
	return ends.y - speed * (t - leg)


func _the_fight() -> void:
	var bits := await _open_at_the_encounter("protector")
	if bits.is_empty():
		_check(false, "the fight: set up", "could not reach the encounter")
		return
	var creature: BakunawaClass = bits["bakunawa"]
	var profile = root.get_node_or_null("PlayerProfile")
	_check(creature.state() == BakunawaClass.State.FIGHTING,
		"the fight: it turns on the commit", "state %d" % creature.state())
	_check(not await _channel_is_open(creature), "and the channel stays shut", "coils active")
	# ⚠ EVERY `strike` CLASS HAS TO BITE. The tag resolves five and the design asks that they
	# differ in more than damage -- which is only true if they all work at all.
	var refused: Array[String] = []
	for tool in ["boomerang", "axe", "sword", "anvil", "cannon"]:
		if not creature.accepts_tool(tool):
			refused.append(tool)
	_check(refused.is_empty(), "and every drawn weapon bites",
		"5 of 5 accepted" if refused.is_empty() else "refused: %s" % ", ".join(refused))
	# And nothing else does.
	_check(not creature.accepts_tool("bread"), "and nothing that is not a weapon does",
		"bread is refused")
	# ⚠ A WEAPON DRAWN AND SWUNG ONCE DOES NOT END THE FIGHT. With the fight one step, the first
	# press of F answered the beat: the storm cleared, Lolo said "It has had enough. Let it go",
	# and the sword -- one use -- was spent before it had swung. Drawn and used here the way a
	# player does, through the drawing panel's door and F.
	var director = bits["director"]
	var lines = level.get("script_lines")
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	level.call("_on_drawing_ready", "sword", "Sword", sheet, {"confidence": 0.9},
		[{"points": PackedVector2Array([Vector2(0, 0), Vector2(0, 80)]), "width": 6.0,
			"color": Color.BLACK}], 1.0)
	await _unpause()
	level.call("_use_equipped_utility")
	await _unpause()
	_check(not bool(director.call("is_solved", "L3_N2")) and int(director.call("stage", "L3_N2")) == 1,
		"the first swing records the weapon and does not end the fight",
		"solved %s, step %d" % [director.call("is_solved", "L3_N2"), director.call("stage", "L3_N2")])
	_check(int(level.call("_slot_holding", "sword")) >= 0
			and not bool(lines.call("has_heard", "L3_N2.protector.solved")),
		"and keeps the weapon, and Lolo says nothing of it being over",
		"the sword is still to hand")
	var hits := 0
	# Fifteen blows to subdue it now (Bakunawa2D.HITS_TO_SUBDUE), one of which was the first swing.
	for _swing in range(BakunawaClass.HITS_TO_SUBDUE + 1):
		if creature.state() != BakunawaClass.State.FIGHTING:
			break
		if creature.apply_tool_hit("cannon", 420.0, null):
			hits += 1
		await physics_frame
	_check(creature.state() == BakunawaClass.State.SUBDUED,
		"and it goes quiet rather than dying", "%d hits, state %d" % [hits, creature.state()])
	_check(String(profile.call("bakunawa_outcome")) == "FOUGHT",
		"and the run remembers that too", String(profile.call("bakunawa_outcome")))
	_check(await _channel_is_open(creature), "and the way on opens", "coils disabled")
	_check(not creature.accepts_tool("cannon"), "and a subdued one cannot be hit again",
		"there is no killing it")
	await _unpause()
	_check(bool(director.call("is_solved", "L3_N2"))
			and bool(lines.call("has_heard", "L3_N2.protector.solved")),
		"subdued is what answers the fight, and Lolo says so then", "solved, the line said")
	_check(int(level.call("_slot_holding", "sword")) < 0, "and the weapon that fought it is spent",
		"one use, and the use was this fight")
	var gone_after := -1.0
	for _frame in range(720):
		await physics_frame
		if creature.is_gone():
			gone_after = float(_frame) / 60.0
			break
	_check(gone_after > 0.0, "and worn out, it swims off",
		"gone after %.1f s" % gone_after if gone_after > 0.0 else "still there after 12 s")
	# ⚠ AND A RESTORE TO BEFORE IT WAS SUBDUED PUTS IT BACK. CP3 was written at the commit; put
	# back there, the fight is on again and the creature is in it -- not swum off from a fight the
	# restore has undone.
	level.call("_return_to_safety", "", "%s")
	await _unpause()
	_check(creature.visible and not creature.is_gone()
			and creature.state() == BakunawaClass.State.FIGHTING,
		"and a restore to before the end of it brings it back to the fight",
		"visible %s, state %d" % [creature.visible, creature.state()])
	_close()


# --- Harness -------------------------------------------------------------------------------

## Put the run at the encounter with a route committed, the way a player arrives: the shore
## beat answered, the crossing taken, and the fork answered out loud.
func _open_at_the_encounter(route: String) -> Dictionary:
	level = (load("res://level_3.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(40):
		await physics_frame
	var director = level.get("director")
	var creature: BakunawaClass = level.get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/Bakunawa")
	if director == null or creature == null:
		return {}
	# The shore, then the crossing, then the fork -- in the order the level asks for them.
	#
	# ⚠ enter_obstacle FIRST. note_submission answers whatever the CURRENT obstacle is, and
	# a probe that never walked into a volume has no current obstacle -- so every drawing it
	# makes is judged against nothing and silently solves nothing.
	# The shore is the brush, and taking it answers the beat with nothing drawn.
	director.call("solve_with_item", "L3_B0_SHORE", "new_brush")
	director.call("enter_obstacle", "L3_N1")
	director.call("commit_route", "L3_N1", "pragmatist")
	director.call("note_submission", "fish")
	director.call("exit_obstacle", "L3_N1")
	director.call("enter_obstacle", "L3_N2")
	director.call("commit_route", "L3_N2", route)
	await _unpause()
	return {"director": director, "bakunawa": creature}


## Close whatever the commit opened and let the world run. See the header.
func _unpause() -> void:
	for node in root.get_tree().get_nodes_in_group(&"modal_overlays"):
		if node.has_method("is_open") and bool(node.call("is_open")):
			node.call("close")
	call_group(DialogueBox.GROUP, &"hide_line")
	root.get_tree().paused = false
	for _frame in range(4):
		await physics_frame


func _channel_is_open(creature: BakunawaClass) -> bool:
	await physics_frame
	var coils := creature.get_node_or_null(^"Coils") as StaticBody2D
	if coils == null:
		return true
	for child in coils.get_children():
		if child is CollisionShape2D and not (child as CollisionShape2D).disabled:
			return false
	return true


func _close() -> void:
	if level != null and is_instance_valid(level):
		level.queue_free()
	level = null
