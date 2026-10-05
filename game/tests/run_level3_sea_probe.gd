extends SceneTree
## DAGAT'S SEA, THE WAY KENT ASKED FOR IT (2026-10-05):
##   godot --headless --path game --script res://tests/run_level3_sea_probe.gd
##
## Each of these was asked for in one message, and each is a thing a probe that plays the level
## "correctly" would walk straight past:
##
##   * the level is longer -- a beach with room to dig the bangka out and drag it down, and a sea
##     long enough that "keep rowing" is not followed at once by "stop";
##   * the ink lasts longer;
##   * the apo dives on a breath and is pushed up when it runs out, not reset -- and a current
##     still keeps them from swimming the crossing;
##   * the bangka is dug out, then pushed: by a Carry shape walking it down, or an anvil dropped
##     behind it;
##   * the fight shows every blow in red, takes fifteen, and the creature swims off with what it
##     was guarding -- and being thrown off does not undo the blows;
##   * the light follows the pointer, the creature follows the light, and brought to the cave under
##     the first beach it goes home and gives up the treasure;
##   * from above the water it is a silhouette;
##   * there is room under it: the light never reaches under its belly, and its body is something
##     you can be caught touching.

const RosterFixtures = preload("res://tests/roster_fixtures.gd")
const Bakunawa = preload("res://scripts/bakunawa_2d.gd")


var level: Node
var results: Array[String] = []
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	results.append("  %s  %-58s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _run() -> void:
	print("\n===== DAGAT'S SEA =====")
	await _the_longer_level()
	await _the_apo_dives_on_a_breath()
	await _the_bangka_is_dug_and_pushed()
	await _the_anvil_shoves_it()
	await _fifteen_blows_and_away()
	await _led_home_by_the_light()
	await _a_silhouette_from_above()
	await _room_under_it()
	await _the_hook_under_the_sand()
	await _fishing_from_the_boat()
	await _the_creatures_fight_back()
	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_LEVEL3_SEA_OK")
		quit(0)
	else:
		print("OBRA_LEVEL3_SEA_FAILED=%d" % failures)
		quit(1)


# --- The level is longer -------------------------------------------------------------------

func _the_longer_level() -> void:
	await _open_the_level()
	var edges: Vector2 = level.call("level_data_shore_edges")
	var hull := level.get("_bangka") as Node2D
	_check(edges.x >= 1600.0 and edges.y - edges.x >= 5000.0,
		"the beach and the sea are both longer",
		"sand to %.0f, open water %.0f px" % [edges.x, edges.y - edges.x])
	_check(hull != null and edges.x - hull.global_position.x >= 500.0,
		"and the bangka is beached well up the sand",
		"%.0f px from the water" % (edges.x - hull.global_position.x if hull != null else 0.0))
	var rates: Dictionary = ((level.get("director").call("level_data") as Dictionary)
		.get("ink_economy", {}) as Dictionary).get("rates", {})
	_check(float(rates.get("fish", 1.0)) <= 0.09 and float(rates.get("shark", 1.0)) <= 0.17,
		"and a shape drinks ink half as fast", "fish %.3f/s, shark %.3f/s" % [
			float(rates.get("fish", 0.0)), float(rates.get("shark", 0.0))])
	# "Keep rowing" is said well before "stop": rowed to the line, the shadow is not yet due.
	var director = level.get("director")
	await _take_the_brush()
	director.call("enter_obstacle", "L3_N1")
	director.call("commit_route", "L3_N1", "artist")
	director.call("solve_with_item", "L3_N1", "bangka")
	await _unpause()
	level.call("_told_the_boat", Vector2(4760.0, 520.0))
	var told: Dictionary = level.get("_told")
	_check(told.has("L3_BOAT.lore5") and not told.has("L3_BOAT.shadow"),
		"'keep rowing' is said a good way before 'stop'",
		"at x 4760 the one, and not yet the other")
	level.call("_told_the_boat", Vector2(5460.0, 520.0))
	_check(told.has("L3_BOAT.shadow"), "and the shadow comes seven hundred on", "at x 5460")
	await _close_the_level()


# --- The apo dives on a breath ---------------------------------------------------------------

func _the_apo_dives_on_a_breath() -> void:
	await _open_the_level()
	var apo := level.get("player") as Wanderer
	var waterline := float(level.get("_waterline_y"))
	_place(Vector2(1850.0, 900.0))
	await _seconds(2.0)
	apo = level.get("player") as Wanderer
	var anchor := _anchor()
	_check(apo != null and anchor.x > 1650.0 and anchor.y > waterline,
		"the apo under the water is not fished out",
		"still swimming at %s after two seconds" % anchor.round())
	_check(float(level.get("_air")) < float(_level_const("AIR_SECONDS")),
		"and is spending a breath", "%.1f of %.0f s left" % [float(level.get("_air")),
			float(_level_const("AIR_SECONDS"))])
	# Down, and held down, until the breath is gone.
	var pushed_up := false
	Input.action_press(&"move_down")
	for _frame in range(int(9.0 * 60.0)):
		await physics_frame
		if paused:
			await _unpause()
		if apo != null and is_instance_valid(apo) and apo.surfacing:
			pushed_up = true
			break
	Input.action_release(&"move_down")
	_check(pushed_up, "out of breath, the apo is pushed up", "surfacing")
	var surfaced := false
	for _frame in range(int(6.0 * 60.0)):
		await physics_frame
		if paused:
			await _unpause()
		if _anchor().y <= waterline + 40.0:
			surfaced = true
			break
	_check(surfaced and _anchor().x > 1650.0, "to the surface, where they were -- not reset",
		"at %s" % _anchor().round())
	# Out past where the apo may swim, the current turns them back.
	_place(Vector2(2450.0, 600.0))
	var from_x := _anchor().x
	Input.action_press(&"move_right")
	await _seconds(2.5)
	Input.action_release(&"move_right")
	_check(_anchor().x < from_x + 60.0, "swimming out past reach, a current holds them back",
		"from %.0f to %.0f holding right" % [from_x, _anchor().x])
	# And far out -- off the boat, or changed back mid-crossing -- nothing takes them back to a
	# checkpoint (Kent, 2026-10-05): they are held where they are, and can swim for the nearer shore.
	_place(Vector2(3600.0, 600.0))
	Input.action_press(&"move_right")
	await _seconds(2.5)
	Input.action_release(&"move_right")
	_check(absf(_anchor().x - 3600.0) < 120.0, "far out at sea they are held, not reset",
		"at %s holding outward" % _anchor().round())
	Input.action_press(&"move_left")
	await _seconds(2.0)
	Input.action_release(&"move_left")
	_check(_anchor().x < 3450.0, "and can swim for the nearer shore", "at %s" % _anchor().round())
	await _close_the_level()


# --- The bangka is dug out, then pushed ------------------------------------------------------

func _the_bangka_is_dug_and_pushed() -> void:
	await _open_the_level()
	var director = level.get("director")
	await _take_the_brush()
	director.call("enter_obstacle", "L3_N1")
	director.call("commit_route", "L3_N1", "artist")
	await _unpause()
	var hull := level.get("_bangka") as Node2D
	var art := hull.get_node("Hull") as Node2D
	_check(not bool(level.get("_bangka_dug")) and art.position.y > -31.0 + 1.0,
		"the bangka starts half in the sand", "keel %.0f px down" % (art.position.y + 31.0))
	var start_x := hull.global_position.x
	_place(Vector2(start_x - 210.0, 500.0))
	await _become("ant", "walker")
	_place(Vector2(start_x - 210.0, 500.0))
	await _seconds(0.3)
	Input.action_press(&"move_right")
	var dug_at := -1.0
	for _frame in range(int(20.0 * 60.0)):
		await physics_frame
		if paused:
			Input.action_release(&"move_right")
			await _unpause()
			Input.action_press(&"move_right")
		if dug_at < 0.0 and bool(level.get("_bangka_dug")):
			dug_at = hull.global_position.x if is_instance_valid(hull) else 0.0
		if bool(director.call("is_solved", "L3_N1")):
			break
	Input.action_release(&"move_right")
	_check(dug_at >= 0.0 and absf(dug_at - start_x) < 20.0,
		"walking into it digs it out first, where it lay", "dug at x %.0f" % dug_at)
	_check(bool(director.call("is_solved", "L3_N1")) and level.get("_launched_boat") != null,
		"and walked down the sand it goes into the sea", "a hull afloat")
	await _close_the_level()


func _the_anvil_shoves_it() -> void:
	await _open_the_level()
	var director = level.get("director")
	await _take_the_brush()
	director.call("enter_obstacle", "L3_N1")
	director.call("commit_route", "L3_N1", "artist")
	await _unpause()
	var hull := level.get("_bangka") as Node2D
	var registry = level.get("registry")
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	var item := DrawnItemData.from_prediction("anvil", "Anvil", sheet,
		RosterFixtures.for_rig("none", "anvil"), 1.0, registry.call("get_entity", "anvil"))
	item.ink_committed = true
	var slot := int((level.get("inventory_manager") as Object).call("add_item", item))
	var start_x := hull.global_position.x
	var shoves := 0
	var first_move := 0.0
	for _try in range(5):
		if bool(director.call("is_solved", "L3_N1")) or not is_instance_valid(hull):
			break
		_place(Vector2(hull.global_position.x - 90.0, 500.0))
		await _seconds(0.3)
		level.call("_equip_from_slot", slot, item)
		await _seconds(0.2)
		if shoves == 0:
			_check(String(level.call("_verb_for", "anvil")) == "SHOVE",
				"an anvil in hand at the bangka offers to shove it", "F SHOVE")
		var before := hull.global_position.x
		level.call("_use_equipped_utility")
		shoves += 1
		await _seconds(1.4)
		if shoves == 1 and is_instance_valid(hull):
			first_move = hull.global_position.x - before
	_check(bool(level.get("_bangka_dug")) and first_move >= 250.0,
		"dropped behind it, the anvil digs it out and shoves it", "%.0f px the first time" % first_move)
	_check(bool(director.call("is_solved", "L3_N1")) and level.get("_launched_boat") != null,
		"and a few drops see it into the sea", "%d drop(s) from x %.0f" % [shoves, start_x])
	await _close_the_level()


# --- Fifteen blows ---------------------------------------------------------------------------

func _fifteen_blows_and_away() -> void:
	await _open_the_level()
	var director = level.get("director")
	var creature := level.get_node("EnvironmentBaseplate/GameplayPlane/Bakunawa") as Bakunawa
	director.call("enter_obstacle", "L3_N2")
	director.call("commit_route", "L3_N2", "protector")
	await _unpause()
	creature.apply_tool_hit("sword", 420.0, null)
	await process_frame
	await process_frame
	var skin := creature.get_node("Skin") as Sprite2D
	_check(skin.modulate.r > skin.modulate.g * 2.0, "a blow shows, in red",
		"tint %s" % skin.modulate)
	for _blow in range(9):
		creature.apply_tool_hit("sword", 420.0, null)
	# Thrown off: the creature is put back on its guard and keeps the ten.
	level.call("_lose_the_stretch", "Thrown off.")
	await _seconds(0.5)
	_check(int(creature.state()) == Bakunawa.State.FIGHTING and int(creature.hits_taken()) == 10,
		"being thrown off does not undo the blows", "%d of %d still landed" % [
			int(creature.hits_taken()), Bakunawa.HITS_TO_SUBDUE])
	for _blow in range(4):
		creature.apply_tool_hit("sword", 420.0, null)
	_check(int(creature.state()) == Bakunawa.State.FIGHTING, "fourteen is not enough",
		"%d landed" % int(creature.hits_taken()))
	var from := creature.global_position
	creature.apply_tool_hit("sword", 420.0, null)
	_check(int(creature.state()) == Bakunawa.State.SUBDUED, "the fifteenth is",
		"subdued")
	_check(creature.get("_carried") != null, "and it takes what it was guarding with it",
		"carried off in its coils")
	var furthest := 0.0
	for _frame in range(int(12.0 * 60.0)):
		await physics_frame
		if paused:
			await _unpause()
		furthest = maxf(furthest, creature.global_position.distance_to(from))
		if creature.is_gone():
			break
	_check(creature.is_gone() and furthest > 1000.0, "and it swims away, a good way, before it is gone",
		"%.0f px off" % furthest)
	_check(bool(director.call("is_solved", "L3_N2")), "and the fight is over", "L3_N2 solved")
	await _close_the_level()


# --- Led home by the light -------------------------------------------------------------------

func _led_home_by_the_light() -> void:
	await _open_the_level()
	var director = level.get("director")
	var creature := level.get_node("EnvironmentBaseplate/GameplayPlane/Bakunawa") as Bakunawa
	await _take_the_brush()
	director.call("enter_obstacle", "L3_N1")
	director.call("commit_route", "L3_N1", "pragmatist")
	director.call("note_submission", "fish")
	await _unpause()
	await _become("fish", "swimmer")
	director.call("enter_obstacle", "L3_N2")
	director.call("commit_route", "L3_N2", "artist")
	await _unpause()
	director.call("note_submission", "flashlight")
	await _unpause()
	_check(bool(level.call("_guiding")) and not bool(director.call("is_solved", "L3_N2")),
		"the light is the first step, and leading it home the second", "stage %d" % int(
			director.call("stage", "L3_N2")))
	var key := String((level.call("_current_objective") as Dictionary).get("key", ""))
	_check(key == "bakunawa_lead", "and the line says to lead it home", "key '%s'" % key)
	var start := creature.global_position
	_place(start + Vector2(-500.0, 120.0))
	level.set("lure_override", start + Vector2(-500.0, 0.0))
	await _seconds(2.0)
	_check(creature.global_position.x < start.x - 200.0, "it follows the light",
		"%.0f px toward it in two seconds" % (start.x - creature.global_position.x))
	var lure := level.get("_lure") as Node2D
	_check(lure != null and lure.visible, "and the light is there to see", "a glow in the water")
	_check(not creature.sees(_anchor()), "and, led, it is not looking for anybody",
		"the apo in plain view is not seen")
	# Brought within reach of its cave, it goes in, and what it held comes out to the apo.
	var mouth: Vector2 = level.get("_cave_mouth")
	creature.global_position = mouth + Vector2(380.0, -260.0)
	_place(mouth + Vector2(420.0, -200.0))
	level.set("lure_override", mouth)
	var profile := root.get_node("PlayerProfile")
	for _frame in range(int(10.0 * 60.0)):
		await physics_frame
		if paused:
			await _unpause()
		if String(profile.call("bakunawa_outcome")) == "LIT":
			break
	_check(creature.is_gone() and bool(director.call("is_solved", "L3_N2")),
		"brought to the cave under the first beach, it goes home", "gone in, the beat answered")
	_check(String(profile.call("bakunawa_outcome")) == "LIT"
			and bool(profile.call("is_collectible_found", "L3_HF")),
		"and gives up the treasure, with the flower", "outcome LIT, L3_HF found")
	await _close_the_level()


# --- A silhouette from above -----------------------------------------------------------------

func _a_silhouette_from_above() -> void:
	await _open_the_level()
	var creature := level.get_node("EnvironmentBaseplate/GameplayPlane/Bakunawa") as Bakunawa
	_place(Vector2(600.0, 500.0))
	await _seconds(1.0)
	var skin := creature.get_node("Skin") as Sprite2D
	_check(float(creature.get("_silhouette")) > 0.95 and skin.modulate.r < 0.2,
		"from above the water it is a silhouette", "tint %s" % skin.modulate)
	await _become("fish", "swimmer")
	_place(creature.global_position + Vector2(-700.0, 300.0))
	await _seconds(1.0)
	_check(float(creature.get("_silhouette")) < 0.05, "and in the water with it, the creature",
		"tint %s" % skin.modulate)
	await _close_the_level()


# --- Room under it ---------------------------------------------------------------------------

func _room_under_it() -> void:
	await _open_the_level()
	var director = level.get("director")
	var creature := level.get_node("EnvironmentBaseplate/GameplayPlane/Bakunawa") as Bakunawa
	var bed := float(_level_const("BED_Y"))
	var belly := creature.global_position.y + creature.drawn_size().y * 0.5
	_check(bed - belly >= 250.0, "it lies off the bed, with water under it",
		"%.0f px between its belly and the bottom" % (bed - belly))
	var lane: Array[Vector2] = []
	for dx in [-200.0, -100.0, 0.0, 100.0, 200.0]:
		lane.append(Vector2(creature.global_position.x + dx, bed - 70.0))
	var lit := 0
	var sweep := Bakunawa.LOOK_DOWN
	var ends: Vector2 = creature.sweep_range()
	var angle := ends.x
	while angle <= ends.y + 0.001:
		creature.set("_sweep", angle)
		for point in lane:
			if creature.sees(point) or creature.touches(point):
				lit += 1
		angle += 0.05
	_check(lit == 0, "along the bottom under its belly, the light never reaches",
		"%d lit readings across its whole sweep (down to %.2f)" % [lit, sweep])
	# And the body is a thing to keep off.
	await _take_the_brush()
	director.call("enter_obstacle", "L3_N1")
	director.call("commit_route", "L3_N1", "pragmatist")
	director.call("note_submission", "fish")
	await _unpause()
	await _become("fish", "swimmer")
	director.call("enter_obstacle", "L3_N2")
	director.call("commit_route", "L3_N2", "pragmatist")
	await _unpause()
	var caught := false
	var told := ""
	for _frame in range(30):
		_place(creature.global_position + Vector2(-60.0, 20.0))
		await physics_frame
		if float(level.get("_reset_cooldown")) > 0.0:
			caught = true
			told = (level.get("hint_bar") as HintBar).current_text()
			break
		if paused:
			await _unpause()
	_check(caught, "swimming into its body costs the stretch", "\"%s\"" % told)
	await _close_the_level()


# --- The hook, the line and the creatures (2026-10-05) ----------------------------------------

func _the_hook_under_the_sand() -> void:
	await _open_the_level()
	await _take_the_brush()
	var mound := level.get("_hook_mound") as Node2D
	_check(mound != null and not bool(level.get("_hook_revealed")),
		"a fishing hook is hidden in the sand of the first beach", "under a heap at x %.0f" % (
			mound.global_position.x if mound != null else 0.0))
	var item := _tool_item("rake", "Rake")
	var slot := int((level.get("inventory_manager") as Object).call("add_item", item))
	_place(mound.global_position + Vector2(-90.0, -40.0))
	await _seconds(0.4)
	level.call("_equip_from_slot", slot, item)
	await _seconds(0.2)
	_check(String(level.call("_level_use_verb", "rake")) == "CLEAR SAND",
		"the rake at the heap offers to clear the sand", "F CLEAR SAND")
	level.call("_use_equipped_utility")
	await _seconds(0.6)
	_check(bool(level.get("_hook_revealed")), "and clears it, and the hook is there", "uncovered")
	level.call("_stow_equipped")
	_place(mound.global_position + Vector2(0.0, -30.0))
	await _seconds(0.6)
	_check(bool(level.get("_has_hook")), "walking onto it takes it", "the hook is the apo's")
	await _close_the_level()


func _fishing_from_the_boat() -> void:
	await _open_the_level()
	var director = level.get("director")
	await _take_the_brush()
	director.call("enter_obstacle", "L3_N1")
	director.call("commit_route", "L3_N1", "artist")
	await _unpause()
	level.call("_launch_the_bangka")
	await _seconds(0.6)
	var boat := level.get("_launched_boat") as Node2D
	_place(boat.global_position + Vector2(0.0, -40.0))
	await _seconds(0.1)
	level.call("press_interact")
	await _unpause()
	level.set("_has_hook", true)
	level.set("lure_override", boat.global_position + Vector2(400.0, 300.0))
	await _seconds(0.2)
	_check(bool(level.call("_can_cast")), "with the hook, F in the boat casts", "HOLD TO CAST")
	# Held a moment: a short, shallow cast. Held long: far, and deep.
	var shallow := await _held_cast(0.15)
	_check(shallow > 0.0 and shallow < 420.0, "a tap of a cast is short and shallow",
		"lets it sink %.0f px" % shallow)
	level.call("_put_the_line_away")
	await _seconds(0.2)
	var deep := await _held_cast(1.4)
	_check(deep > 850.0, "held longer, it is stronger and goes deeper", "lets it sink %.0f px" % deep)
	var camera := level.call("_world_camera") as Node
	_check(camera != null and bool(camera.call("is_focused")), "and the camera follows the hook",
		"focused on it")
	var line := level.get("_line") as Node2D
	for _frame in range(300):
		await physics_frame
		if line != null and bool(line.call("in_water")):
			break
	# A bangus swims into it: on the line, in the water -- nothing stops.
	var catch := await _hook_one("bangus")
	_check(catch != null and bool(catch.call("is_hooked")) and not paused,
		"a creature that swims into the hook is on the line, and the world goes on",
		"%s fighting it" % (String(catch.call("display_name")) if catch != null else "nothing"))
	# Wound in, easing off when it runs: it comes up to the boat, pulled through the water.
	var start := catch.global_position.distance_to(level.call("_rod_tip"))
	var closest := start
	for _frame in range(60 * 30):
		if int(level.get("_catches")) >= 1:
			break
		line = level.get("_line") as Node2D
		var easy: bool = line != null and is_instance_valid(line) and line.has_method("has_fish") \
			and bool(line.call("has_fish")) and not bool(line.call("is_fish_running")) \
			and float(line.get("tension")) < 0.6
		level.set("hold_override", easy)
		await physics_frame
		if is_instance_valid(catch) and bool(catch.call("is_hooked")):
			closest = minf(closest, catch.global_position.distance_to(level.call("_rod_tip")))
	level.set("hold_override", false)
	_check(closest < start - 200.0, "winding pulls it back toward the boat, where it can be seen",
		"from %.0f to %.0f px off" % [start, closest])
	_check(int(level.get("_catches")) == 1, "wound in, easing off when it runs, it is landed",
		"one caught")
	await _seconds(0.5)
	await _unpause()
	# Wound hard through its runs: the line snaps.
	await _held_cast(0.8)
	await _seconds(1.0)
	var fighter := await _hook_one("pugita")
	var snapped := false
	level.set("hold_override", true)
	for _frame in range(60 * 30):
		await physics_frame
		if fighter != null and is_instance_valid(fighter) and not bool(fighter.call("is_hooked")):
			snapped = true
			break
	level.set("hold_override", false)
	_check(snapped and int(level.get("_catches")) == 1 and bool(fighter.call("is_alive")),
		"wound hard through its runs, the line snaps and it gets away", "still one caught")
	await _seconds(2.0)
	level.call("_put_the_line_away")
	await _unpause()
	# Left to run, it takes the line.
	await _held_cast(0.8)
	await _seconds(1.0)
	var runner := await _hook_one("pawikan")
	var ran := false
	for _frame in range(60 * 60):
		await physics_frame
		if runner != null and is_instance_valid(runner) and not bool(runner.call("is_hooked")):
			ran = true
			break
	_check(ran and int(level.get("_catches")) == 1, "not wound at all, it takes all the line",
		"still one caught")
	level.call("_put_the_line_away")
	await _unpause()
	# Five, and the hook breaks.
	level.set("_catches", 4)
	await _held_cast(0.8)
	await _seconds(1.0)
	var fifth := await _hook_one("dikya")
	for _frame in range(60 * 40):
		if int(level.get("_catches")) >= 5:
			break
		line = level.get("_line") as Node2D
		var easy: bool = line != null and is_instance_valid(line) and bool(line.call("has_fish")) \
			and not bool(line.call("is_fish_running")) and float(line.get("tension")) < 0.6
		level.set("hold_override", easy)
		await physics_frame
	level.set("hold_override", false)
	await _unpause()
	_check(bool(level.get("_hook_broken")) and not bool(level.call("_can_cast")),
		"after five catches the hook breaks", "%d caught" % int(level.get("_catches")))
	await _close_the_level()


## Hold the cast for `seconds`, let go, and say how deep the line will let the hook sink.
func _held_cast(seconds: float) -> float:
	level.set("hold_override", true)
	level.call("_begin_charge")
	await _seconds(seconds)
	level.set("hold_override", false)
	for _frame in range(4):
		await physics_frame
	var line := level.get("_line") as Node2D
	if line == null:
		return -1.0
	return float(line.get("max_depth")) - float(level.get("_waterline_y"))


## The nearest of a kind put on the hook once it is in the water, and its bite seen.
func _hook_one(kind: String) -> Node2D:
	var line := level.get("_line") as Node2D
	for _frame in range(300):
		await physics_frame
		if line != null and is_instance_valid(line) and bool(line.call("in_water")):
			break
	if line == null or not is_instance_valid(line):
		return null
	var creature := _nearest_creature(kind, line.call("hook_position"))
	creature.global_position = line.call("hook_position")
	for _frame in range(10):
		await physics_frame
		if bool(creature.call("is_hooked")):
			break
	return creature


func _the_creatures_fight_back() -> void:
	await _open_the_level()
	await _become("fish", "swimmer")
	var lines = level.get("script_lines")
	var pugita := _nearest_creature("pugita", Vector2(3150.0, 1560.0))
	_place(pugita.global_position + Vector2(-150.0, 0.0))
	await _seconds(0.6)
	_check(bool(lines.call("has_heard", "SEA.pugita")), "swimming up to one, Lolo says what it is",
		"the pugita's line")
	var apo := level.get("player") as Node2D
	pugita.call("apply_tool_hit", "sword", 420.0, apo)
	var angry := 0
	var calm_bangus := true
	for node in get_nodes_in_group(&"sea_creatures"):
		if String(node.get("kind")) == "bangus":
			calm_bangus = calm_bangus and not bool(node.call("is_hostile"))
		elif bool(node.call("is_hostile")):
			angry += 1
	_check(angry > 0 and calm_bangus, "strike one, and everything but the bangus turns on you",
		"%d angry, the bangus calm" % angry)
	for _blow in range(4):
		pugita.call("apply_tool_hit", "sword", 420.0, apo)
	_check(not bool(pugita.call("is_alive")), "five blows and it dies", "dead")
	await _seconds(0.2)
	_check(bool(lines.call("has_heard", "SEA.killed1")), "and Lolo is sad about it", "SEA.killed1")
	var waterline := float(level.get("_waterline_y"))
	_place(Vector2(4000.0, 1400.0))
	await _seconds(0.2)
	for _bite in range(9):
		level.call("_on_bitten", pugita)
	_check(int(level.get("_hits_taken")) == 9 and _anchor().y > waterline + 300.0,
		"nine bites and the player is still down there", "%d taken" % int(level.get("_hits_taken")))
	level.call("_on_bitten", pugita)
	await _seconds(0.3)
	_check(_anchor().y < waterline + 80.0 and int(level.get("_hits_taken")) == 0
			and not bool(level.get("_creatures_hostile")),
		"the tenth sends them up to the surface, and the sea calms", "at %s" % _anchor().round())
	await _close_the_level()


func _nearest_creature(kind: String, near: Vector2) -> Node2D:
	var best: Node2D = null
	for node in get_nodes_in_group(&"sea_creatures"):
		var creature := node as Node2D
		if not bool(creature.call("is_alive")) or bool(creature.call("is_hooked")):
			continue
		if not kind.is_empty() and String(creature.get("kind")) != kind:
			continue
		if best == null or creature.global_position.distance_to(near) < best.global_position.distance_to(near):
			best = creature
	return best


func _tool_item(entity_id: String, display: String) -> DrawnItemData:
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	var item := DrawnItemData.from_prediction(entity_id, display, sheet,
		RosterFixtures.for_rig("none", entity_id), 1.0,
		(level.get("registry") as Object).call("get_entity", entity_id))
	item.ink_committed = true
	return item


# --- The machinery ---------------------------------------------------------------------------

## Read at run time: preloaded at the top, level_3.gd compiles before the autoloads it names exist.
func _level_const(name: String) -> Variant:
	return (load("res://scripts/level_3.gd") as GDScript).get_script_constant_map()[name]


func _open_the_level() -> void:
	level = (load("res://level_3.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(40):
		await physics_frame
	for node_name in ["DialogueNode", "BakunawaNode"]:
		var fork := level.get_node_or_null(
			NodePath("EnvironmentBaseplate/GameplayPlane/%s" % node_name)) as Node2D
		if fork != null:
			fork.set_process_mode(Node.PROCESS_MODE_DISABLED)
	await _unpause()


func _close_the_level() -> void:
	Input.action_release(&"move_right")
	Input.action_release(&"move_down")
	level.queue_free()
	for _frame in range(4):
		await physics_frame


func _take_the_brush() -> void:
	var mark := level.get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/Marks/BrushMark") as Node2D
	if mark == null:
		return
	_place(mark.global_position)
	for _frame in range(20):
		await physics_frame
	await _unpause()
	var director = level.get("director")
	if not bool(director.call("is_solved", "L3_B0_SHORE")):
		director.call("solve_with_item", "L3_B0_SHORE", "new_brush")
	await _unpause()


func _become(entity_id: String, rig: String) -> void:
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	level.call("_spawn_or_replace", entity_id, entity_id.capitalize(), sheet,
		RosterFixtures.for_rig(rig, entity_id))
	for _frame in range(6):
		await physics_frame
	await _unpause()


func _anchor() -> Vector2:
	return level.call("_anchor_now") as Vector2


func _place(at: Vector2) -> void:
	var body := level.get("player") as Node2D
	if body == null or not is_instance_valid(body):
		return
	if body.has_method("apply_morph_state"):
		body.call("apply_morph_state", {"position": at, "linear_velocity": Vector2.ZERO})
	else:
		body.global_position = at


func _seconds(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await physics_frame
		if paused:
			await _unpause()
			continue
		elapsed += 1.0 / 60.0


func _unpause() -> void:
	for _attempt in range(60):
		for node in get_nodes_in_group(&"modal_overlays"):
			if node.name == "LevelCompleteOverlay":
				continue
			if node.has_method("is_open") and node.has_method("close") \
					and bool(node.call("is_open")):
				node.call("close")
		call_group(DialogueBox.GROUP, &"hide_line")
		paused = false
		await physics_frame
		if not paused:
			await physics_frame
			if not paused:
				return
