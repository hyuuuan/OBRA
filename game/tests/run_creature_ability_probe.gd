extends SceneTree
## A drawn body does what ConceptNet says it can, not only move.
##
##   godot --headless --path game --script res://tests/run_creature_ability_probe.gd
##
## The study's abilities come from ConceptNet, and a body only ever moved: a bird flew, but nothing
## stung, rammed or held. config/ability_effects.json makes the combat abilities act, and on Kent's
## decision (2026-11-16) only those ConceptNet gives: every effect must be a label
## config/abilities.json gives the class, and a class ConceptNet gives none gets none (the shark's
## is Rough Hide). Checked here: the table against ConceptNet, what each body resolves to, and each
## kind in play in Dilim -- a strike that wounds and poisons, a ram that wounds twice, a grab that
## holds, a body with nothing, the way she faces, the crab's armor, the sigbin driven off by stings
## answering its fight -- and Dagat's creatures taking a sting as they take a blade.

const CHECKS := 12
const STAND := Vector2(6950.0, 596.0)

var level: Node
var failures := 0
var checked := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(240.0).timeout.connect(func() -> void:
		print("OBRA_CREATURE_ABILITY_FAILED=watchdog")
		quit(2))
	_the_table_is_conceptnet()
	_each_body_resolves_to_its_own_abilities()
	level = (load("res://level_4.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(30)
	await _a_sting_wounds_and_poisons()
	await _a_ram_wounds_twice()
	await _a_squeeze_holds_and_does_not_wound()
	await _a_body_with_nothing_does_nothing()
	await _a_blow_goes_the_way_she_faces()
	await _a_shell_takes_one_blow()
	await _stings_drive_off_the_sigbin_and_answer_its_fight()
	_dagat_takes_a_sting()
	_finish()


# --- The table ---------------------------------------------------------------------------------

## ConceptNet only: every label the effects name is an ability abilities.json gives some class, and
## every strike has its numbers in weapons.json.
func _the_table_is_conceptnet() -> void:
	var known: Dictionary = {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/abilities.json"))
	for entry: Variant in ((parsed as Dictionary).get("abilities", {}) as Dictionary).values():
		for row: Variant in (entry as Dictionary).get("abilities", []):
			known[String((row as Dictionary).get("label", ""))] = true
	var invented: Array[String] = []
	var unnumbered: Array[String] = []
	for label: String in CreatureAbility.effects():
		if not known.has(label):
			invented.append(label)
		var effect: Dictionary = CreatureAbility.effect_of(label)
		if String(effect.get("kind", "")) == "strike" and not WeaponTable.is_weapon(String(effect.get("id", ""))):
			unnumbered.append(label)
	_check(invented.is_empty() and CreatureAbility.effects().size() >= 11,
		"every effect is a ConceptNet ability", "%d effects; %s" % [CreatureAbility.effects().size(),
		"none invented" if invented.is_empty() else "NOT IN CONCEPTNET: " + ", ".join(invented)])
	_check(unnumbered.is_empty(), "and every strike has its numbers", "none missing" if unnumbered.is_empty()
		else "NO ROW: " + ", ".join(unnumbered))


## What each body gets is what ConceptNet gives it: a strike before a grab, armor apart.
func _each_body_resolves_to_its_own_abilities() -> void:
	var expect := {
		"bee": ["Sting", ""], "scorpion": ["Sting", ""], "spider": ["Venom", ""],
		"elephant": ["Tusk Ram", ""], "snake": ["Squeeze", ""], "octopus": ["Grapple", ""],
		"crab": ["Grip", "Armor"], "frog": ["Tongue Grab", ""], "shark": ["", "Rough Hide"],
		"sea_turtle": ["", "Shell"], "fish": ["", ""], "bird": ["", ""],
	}
	var wrong: Array[String] = []
	for id: String in expect:
		var ability := CreatureAbility.for_class(id)
		var got := [String(ability.action.get("label", "")), String(ability.armor.get("label", ""))]
		if got != expect[id]:
			wrong.append("%s %s (wanted %s)" % [id, str(got), str(expect[id])])
	_check(wrong.is_empty(), "each body gets its own ConceptNet abilities", "12 bodies right" if wrong.is_empty()
		else "; ".join(wrong))


# --- In Dilim ----------------------------------------------------------------------------------

func _a_sting_wounds_and_poisons() -> void:
	var dog := await _dog_in_front()
	await _become("bee")
	var prompt := (level.get("action_prompts") as ActionPromptHUD).get("_use") as Button
	var events_before := _telemetry_lines().size()
	var before := dog.hp
	level.call("_use_equipped_utility")
	await _frames(2)
	var logged := false
	for line: Variant in _telemetry_lines().slice(events_before):
		var event: Variant = JSON.parse_string(String(line))
		if event is Dictionary and String(event.get("type", "")) == "form_ability_used" \
				and String(event.get("ability", "")) == "Sting" and int(event.get("landed", 0)) == 1:
			logged = true
	_check(prompt.text == "STING" and dog.hp == before - 1 and dog.is_burning() and logged,
		"a bee's F stings: a blow, poison, and it is logged",
		"prompt \"%s\", hp %d -> %d, burning %s, logged %s" % [prompt.text, before, dog.hp, dog.is_burning(), logged])
	var after_one := dog.hp
	level.call("_use_equipped_utility")
	await _frames(2)
	_check(dog.hp == after_one, "and a second press inside its cooldown is nothing", "hp %d -> %d" % [after_one, dog.hp])
	dog.queue_free()


func _a_ram_wounds_twice() -> void:
	var dog := await _dog_in_front()
	await _become("elephant")
	var before := dog.hp
	level.call("_use_equipped_utility")
	await _frames(2)
	_check(dog.hp == before - 2, "an elephant's Tusk Ram takes two", "hp %d -> %d" % [before, dog.hp])
	dog.queue_free()


func _a_squeeze_holds_and_does_not_wound() -> void:
	var dog := await _dog_in_front()
	await _become("snake")
	var before := dog.hp
	level.call("_use_equipped_utility")
	await _frames(2)
	_check(dog.state == Enemy2D.State.STUN and dog.hp == before, "a snake's Squeeze holds it, and wounds nothing",
		"state %s, hp %d -> %d" % [dog.state_name(), before, dog.hp])
	dog.queue_free()


func _a_body_with_nothing_does_nothing() -> void:
	var dog := await _dog_in_front()
	await _become("fish")
	await _frames(2)
	var prompts := level.get("action_prompts") as ActionPromptHUD
	var before := dog.hp
	level.call("_use_equipped_utility")
	await _frames(2)
	_check(dog.hp == before and dog.state != Enemy2D.State.STUN and not prompts.use_is_available(),
		"a body ConceptNet gives no blow does nothing, and F offers nothing",
		"hp %d -> %d, state %s, F shown %s" % [before, dog.hp, dog.state_name(), prompts.use_is_available()])
	dog.queue_free()


func _a_blow_goes_the_way_she_faces() -> void:
	var dog := await _dog_in_front()
	await _become("bee")
	level.set("_form_facing", -1.0)
	var before := dog.hp
	level.call("_use_equipped_utility")
	await _frames(2)
	level.set("_form_facing", 1.0)
	_check(dog.hp == before, "a sting goes the way she faces, not behind her", "hp %d -> %d" % [before, dog.hp])
	dog.queue_free()


func _a_shell_takes_one_blow() -> void:
	await _become("crab")
	var health := level.get("player_health") as PlayerHealth
	var hurtbox := level.get("player_hurtbox") as PlayerHurtbox2D
	health.call("reset_full")
	health.set("_grace_left", 0.0)
	var full := health.stage
	var first := hurtbox.receive_hit(hurtbox.middle() + Vector2(40.0, 0.0))
	var after_first := health.stage
	var second := hurtbox.receive_hit(hurtbox.middle() + Vector2(40.0, 0.0))
	_check(not first and after_first == full and second and health.stage == full - 1,
		"a crab's Armor takes the first blow, not one right after",
		"first landed %s (stage %d), second landed %s (stage %d of %d)" % [first, after_first, second,
			health.stage, full])
	health.call("reset_full")


func _stings_drive_off_the_sigbin_and_answer_its_fight() -> void:
	var sigbin := level.get("_sigbin") as Enemy2D
	var director = level.get("director")
	await _become("bee")
	var player := level.get("player") as Node2D
	for _try in range(12):
		if director.call("is_solved", "L4_SIGBIN") or sigbin.is_dead():
			break
		player.call("apply_morph_state", {"position": sigbin.global_position + Vector2(-50.0, 0.0),
			"linear_velocity": Vector2.ZERO})
		(level.get("player_health") as PlayerHealth).call("_start_grace", 600.0)
		level.set("_form_facing", 1.0)
		await _frames(4)
		level.call("_use_equipped_utility")
		await create_timer(0.75).timeout
	_check(bool(director.call("is_solved", "L4_SIGBIN")) and String(director.call("committed_route", "L4_SIGBIN")) == "protector",
		"stings that drive the sigbin off answer its fight", "solved %s, route \"%s\"" % [
			director.call("is_solved", "L4_SIGBIN"), director.call("committed_route", "L4_SIGBIN")])


func _dagat_takes_a_sting() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/bakunawa_2d.gd")
	_check(CreatureAbility.is_strike("sting") and not CreatureAbility.is_strike("squeeze")
			and not CreatureAbility.is_strike("sword")
			and source.contains("CreatureAbility.is_strike(tool)")
			and FileAccess.get_file_as_string("res://scripts/sea_creature_2d.gd").contains("CreatureAbility.is_strike(tool)"),
		"Dagat's creatures take a sting as they take a blade", "sting is a strike; squeeze and sword are not")


# --- Helpers -----------------------------------------------------------------------------------

## An aswang dog just ahead of her, on Dilim's ground, she standing still and graced.
func _dog_in_front() -> GroundEnemy2D:
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": STAND, "linear_velocity": Vector2.ZERO})
	(level.get("player_health") as PlayerHealth).call("_start_grace", 600.0)
	level.set("_form_facing", 1.0)
	var dog := GroundEnemy2D.new()
	dog.kind = "aswang_dog"
	dog.hunts_by_smell = false
	dog.drops = false
	(level.get("entity_root") as Node).add_child(dog)
	dog.global_position = STAND + Vector2(64.0, -12.0)
	await _frames(3)
	dog.call("_enter", Enemy2D.State.IDLE)
	return dog


func _become(entity_id: String) -> void:
	var ink = level.get("ink_manager")
	ink.set("committed", 0.0)
	ink.call("release_attempt")
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	level.call("_on_drawing_ready", entity_id, entity_id.capitalize(), sheet, {"confidence": 0.9},
		[{"points": PackedVector2Array([Vector2(0, 0), Vector2(40, 0), Vector2(40, 30)]), "width": 6.0,
			"color": Color.BLACK}], 1.0)
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": STAND, "linear_velocity": Vector2.ZERO})
	(level.get("player_health") as PlayerHealth).call("_start_grace", 600.0)
	await _frames(10)


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
		print("OBRA_CREATURE_ABILITY_FAILED: %d checks ran, %d expected" % [checked, CHECKS])
		quit(1)
	elif failures == 0:
		print("OBRA_CREATURE_ABILITY_OK")
		quit(0)
	else:
		print("OBRA_CREATURE_ABILITY_FAILED=%d" % failures)
		quit(1)


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
