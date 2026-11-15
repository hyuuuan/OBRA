extends SceneTree
## A sun burns the creatures in its heat for a while; a fire burns those close for as long as it
## stands -- their ConceptNet Scorch and Burn, made to act.
##
##   godot --headless --path game --script res://tests/run_scorch_probe.gd
##
## In Dilim a sun lit the dark and hurt nothing, though ConceptNet gives it Scorch and Heat (Kent's
## decision, 2026-11-16: it burns what stands in its light, and its heat runs out). Checked: the
## effects are the sun's and the fire's own ConceptNet abilities; a placed sun burns a creature in
## its heat and not one beyond it; one that hunts by smell is held at its edge and still burns; the
## heat ends, and with it the ward and the burning; a fire's lasts; the encounters a light already
## answers are not burned, so a sun at the sigbin stays the light answer; and the burning is logged.

const CHECKS := 10
const STAND := Vector2(6950.0, 596.0)

var level: Node
var failures := 0
var checked := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(240.0).timeout.connect(func() -> void:
		print("OBRA_SCORCH_FAILED=watchdog")
		quit(2))
	_the_heat_is_conceptnet()
	await _where_nothing_fights_a_sun_has_no_heat()
	level = (load("res://level_4.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(30)
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": STAND + Vector2(-900.0, 0.0), "linear_velocity": Vector2.ZERO})
	(level.get("player_health") as PlayerHealth).call("_start_grace", 600.0)
	await _a_sun_burns_what_stands_in_its_heat_until_it_runs_out()
	await _a_fire_burns_for_as_long_as_it_stands()
	await _the_encounters_a_light_answers_are_not_burned()
	await _a_sun_at_the_sigbin_is_still_the_light_answer()
	_finish()


func _the_heat_is_conceptnet() -> void:
	var sun := _scorch_of("sun")
	var fire := _scorch_of("campfire")
	_check(sun == "Scorch" and fire == "Burn" and _scorch_of("flashlight").is_empty(),
		"the heat is the sun's and the fire's own ConceptNet abilities",
		"sun %s, campfire %s, flashlight %s" % [sun, fire, _scorch_of("flashlight") if not _scorch_of("flashlight").is_empty() else "none"])


## Terraces has nothing to burn: no heat, no ward, no ring -- only the light a sun always gives.
func _where_nothing_fights_a_sun_has_no_heat() -> void:
	level = (load("res://game_level.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(30)
	var player := level.get("player") as Node2D
	var sun := await _place("sun", player.global_position + Vector2(140.0, -30.0))
	await create_timer(1.0).timeout
	_check(not sun.is_scorching() and not sun.is_in_group(Enemy2D.WARDS) and sun.get_node_or_null("ScorchRing") == null,
		"where nothing fights, a sun has no heat and no ring", "scorching %s, ward %s, ring %s" % [
			sun.is_scorching(), sun.is_in_group(Enemy2D.WARDS), sun.get_node_or_null("ScorchRing") != null])
	level.queue_free()
	await _frames(3)


func _a_sun_burns_what_stands_in_its_heat_until_it_runs_out() -> void:
	var sun := await _place("sun", STAND)
	var effect := CreatureAbility.effect_of("Scorch")
	var radius := float(effect["radius"])
	var near := await _dog(STAND + Vector2(radius * 0.5, -12.0), false)
	var far := await _dog(STAND + Vector2(radius + 220.0, -12.0), false)
	var events_before := _telemetry_lines().size()
	await create_timer(2.6).timeout
	_check(near.hp < near.max_hp and far.hp == far.max_hp, "a placed sun burns a creature in its heat, not one beyond it",
		"near %d/%d, far %d/%d" % [near.hp, near.max_hp, far.hp, far.max_hp])
	# She stands in the heat, and one that hunts by smell comes for her from beyond its edge.
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": STAND + Vector2(-60.0, 0.0), "linear_velocity": Vector2.ZERO})
	(level.get("player_health") as PlayerHealth).call("_start_grace", 600.0)
	var sniffer := await _dog(STAND + Vector2(radius + 90.0, -12.0), true)
	await create_timer(3.5).timeout
	var held := sniffer.global_position.distance_to(sun.global_position)
	_check(held >= radius - 4.0 and held <= radius + UtilityObject.SCORCH_EDGE
			and sniffer.hp < sniffer.max_hp, "one that hunts by smell is held at its edge, and still burns",
		"held %.0f px off (reach %.0f), hp %d/%d" % [held, radius, sniffer.hp, sniffer.max_hp])
	var logged := false
	for line: Variant in _telemetry_lines().slice(events_before):
		var event: Variant = JSON.parse_string(String(line))
		if event is Dictionary and String(event.get("type", "")) == "object_ability_used" \
				and String(event.get("ability", "")) == "Scorch" and int(event.get("burned", 0)) >= 1:
			logged = true
	_check(logged, "and the burning is logged", "object_ability_used, Scorch")
	for foe in [near, far, sniffer]:
		foe.queue_free()
	player.call("apply_morph_state", {"position": STAND + Vector2(-900.0, 0.0), "linear_velocity": Vector2.ZERO})
	await create_timer(maxf(0.5, float(effect["lasts"]) - 5.5)).timeout
	var fresh := await _dog(STAND + Vector2(radius * 0.4, -12.0), false)
	await create_timer(2.2).timeout
	_check(not sun.is_scorching() and not sun.is_in_group(Enemy2D.WARDS) and fresh.hp == fresh.max_hp
			and sun.light_hole().size() > 0,
		"its heat runs out: no more burning, no more ward, still a light",
		"scorching %s, ward %s, fresh %d/%d, light %s" % [sun.is_scorching(), sun.is_in_group(Enemy2D.WARDS),
			fresh.hp, fresh.max_hp, sun.light_hole().size() > 0])
	fresh.queue_free()
	sun.queue_free()
	await _frames(3)


func _a_fire_burns_for_as_long_as_it_stands() -> void:
	var fire := await _place("campfire", STAND)
	await create_timer(float(CreatureAbility.effect_of("Scorch")["lasts"]) + 1.0).timeout
	var close := await _dog(STAND + Vector2(float(CreatureAbility.effect_of("Burn")["radius"]) * 0.5, -12.0), false)
	await create_timer(2.6).timeout
	_check(fire.is_scorching() and close.hp < close.max_hp, "a fire's Burn lasts while it stands",
		"scorching %s, close %d/%d" % [fire.is_scorching(), close.hp, close.max_hp])
	close.queue_free()
	fire.queue_free()
	await _frames(3)


func _the_encounters_a_light_answers_are_not_burned() -> void:
	var untouched: Array[String] = []
	var burned: Array[String] = []
	for path in ["_sigbin", "_tiyanak", "_bungisngis", "_upper"]:
		var foe := level.get(path) as Enemy2D
		if foe == null:
			continue
		var before := foe.hp
		foe.apply_scorch(1, 0.2)
		await create_timer(0.5).timeout
		(untouched if foe.hp == before and not foe.is_dead() else burned).append(String(foe.kind))
	var lower: Enemy2D = null
	for node in get_nodes_in_group(Enemy2D.FOES):
		if (node as Enemy2D).kind == "manananggal_lower":
			lower = node
	lower.apply_scorch(1, 0.2)
	await create_timer(0.5).timeout
	(untouched if not lower.is_dead() and not bool(lower.get("_salted")) else burned).append("manananggal_lower")
	_check(burned.is_empty() and untouched.size() == 5,
		"the encounters a light answers, and the giant, are not burned -- nor is the lower half salted",
		"untouched %s%s" % [", ".join(untouched), "" if burned.is_empty() else "; BURNED " + ", ".join(burned)])


## ⚠ THE RISK IS A SECOND ANSWER. Routes stay open in Dilim until one is answered, and a sigbin
## driven off answers the fight's: a sun's heat that drove it off would turn the light's answer into
## the protector's. With the light's route chosen and a hot sun beside it, it stays the light's.
func _a_sun_at_the_sigbin_is_still_the_light_answer() -> void:
	var sigbin := level.get("_sigbin") as Enemy2D
	var director = level.get("director")
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": STAND, "linear_velocity": Vector2.ZERO})
	(level.get("player_health") as PlayerHealth).call("_start_grace", 600.0)
	await _frames(20)
	if String(director.call("committed_route", "L4_SIGBIN")).is_empty():
		director.call("commit_route", "L4_SIGBIN", "artist")
	var before := sigbin.hp
	var sun := await _place("sun", sigbin.global_position + Vector2(-80.0, -20.0))
	await create_timer(3.0).timeout
	var route := String(director.call("committed_route", "L4_SIGBIN"))
	_check(route == "artist" and sigbin.hp == before, "a hot sun at the sigbin leaves its answer the light's",
		"route \"%s\", solved %s, hp %d -> %d" % [route, director.call("is_solved", "L4_SIGBIN"), before, sigbin.hp])
	_check(sun.is_scorching(), "and the sun was hot all the while", "scorching %s" % sun.is_scorching())
	sun.queue_free()


# --- Helpers -----------------------------------------------------------------------------------

func _scorch_of(id: String) -> String:
	for label in CreatureAbility.labels_of(id):
		if String(CreatureAbility.effect_of(label).get("kind", "")) == "scorch":
			return label
	return ""


func _place(id: String, at: Vector2) -> UtilityObject:
	var registry := level.get("registry") as EntityRegistry
	var thing := registry.instantiate_entity(id) as UtilityObject
	var page := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	page.fill(Color.WHITE)
	thing.apply_item_data(DrawnItemData.from_prediction(id, id.capitalize(), page,
		[{"points": PackedVector2Array([Vector2(20, 20), Vector2(100, 20), Vector2(100, 100), Vector2(20, 100), Vector2(20, 20)]),
			"width": 6.0, "color": Color.BLACK}], 1.0, registry.get_entity(id)))
	# ⚠ WHERE IT GOES BEFORE IT IS IN THE WORLD: added first and moved after, a body begins at the
	# world's origin, inside Dilim's canopy (see UtilityObject._fire_cannon).
	var world := level.get("world_item_root") as Node2D
	# As placing it does: the level's own bounds, or it is held inside a default that ends short of
	# the sigbin's woods.
	thing.set_world_bounds(Rect2((level.get("environment") as Node).get("world_bounds")))
	thing.position = world.to_local(at)
	world.add_child(thing)
	await _frames(4)
	return thing


func _dog(at: Vector2, smells: bool) -> GroundEnemy2D:
	var dog := GroundEnemy2D.new()
	dog.kind = "aswang_dog"
	dog.hunts_by_smell = smells
	dog.drops = false
	(level.get("entity_root") as Node).add_child(dog)
	dog.global_position = at
	await _frames(2)
	return dog


func _telemetry_lines() -> Array:
	var telemetry := root.get_node_or_null("Telemetry")
	var file: Variant = telemetry.get("_file") if telemetry != null else null
	if not (file is FileAccess):
		return []
	(file as FileAccess).flush()
	return Array(FileAccess.get_file_as_string((file as FileAccess).get_path_absolute()).split("\n", false))


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		if paused:
			call_group(DialogueBox.GROUP, &"hide_line")
			paused = false


func _finish() -> void:
	if checked != CHECKS:
		print("OBRA_SCORCH_FAILED: %d checks ran, %d expected" % [checked, CHECKS])
		quit(1)
	elif failures == 0:
		print("OBRA_SCORCH_OK")
		quit(0)
	else:
		print("OBRA_SCORCH_FAILED=%d" % failures)
		quit(1)


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
