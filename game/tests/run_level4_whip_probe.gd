extends SceneTree
## The buntot pagi, headless: Lola's stingray-tail whip, the satchel's one weapon.
##
##   godot --headless --path game --script res://tests/run_level4_whip_probe.gd
##
## Lashed from its quick slot the way a player does, at aswang and a flier set round her and held
## still by a long blinding, and read back off their hp; its drop read off what lies on the ground
## after a fall. A fresh level for each, so nothing leaks into the next. The numbers are the
## design's (Kent: "10 uses / 3 dmg / 130 reach / 160 arc / 0.45 s cooldown; 2% drop in waves 2-3
## only"), not the table's.
##
## `-- <words>` runs only the scenarios whose name holds them (for a mutant, which needs only the
## check that guards it); the every-check-ran guard stands down for such a run.

const GROUND_Y := 600.0
const AT_X := 19900.0
const WHIP := "buntot_pagi"

var failures := 0
var checked := 0
const CHECKS := 6
var level: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(300.0).timeout.connect(func() -> void:
		print("OBRA_L4_WHIP_FAILED=watchdog")
		quit(2))
	var only := " ".join(OS.get_cmdline_user_args())
	for scenario in [_a_lash_hits_what_is_in_front_and_in_reach, _it_reaches_what_flies, _a_press_too_soon_does_nothing,
			_ten_lashes_and_it_is_spent, _it_drops_only_in_the_second_and_third_waves]:
		if not only.is_empty() and not String((scenario as Callable).get_method()).contains(only):
			continue
		level = await _open_level()
		await scenario.call()
		level.queue_free()
		await _frames(3)
	if only.is_empty() and checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_L4_WHIP_OK")
		quit(0)
	else:
		print("OBRA_L4_WHIP_FAILED=%d" % failures)
		quit(1)


## In front at 100 it loses 3; behind at 100, or in front at 170, nothing.
func _a_lash_hits_what_is_in_front_and_in_reach() -> void:
	await _put_her(AT_X)
	var near := _foe(GroundEnemy2D, "aswang_pig", Vector2(100.0, 0.0))
	var behind := _foe(GroundEnemy2D, "aswang_pig", Vector2(-100.0, 0.0))
	var far := _foe(GroundEnemy2D, "aswang_pig", Vector2(170.0, 0.0))
	await _frames(4)
	var slot := _give_the_whip()
	level.call("use_quick_slot", slot)
	await _frames(2)
	_check(near.hp == near.max_hp - 3 and behind.hp == behind.max_hp and far.hp == far.max_hp,
		"a lash takes 3 from what is in front within 130, and nothing behind or beyond",
		"in front %d of %d, behind %d, at 170 %d" % [near.hp, near.max_hp, behind.hp, far.hp])


## Above her and ahead -- 117 off, 70 degrees up -- a flier is in it; straight overhead is not.
func _it_reaches_what_flies() -> void:
	await _put_her(AT_X)
	var ahead := _foe(FlyingEnemy2D, "wakwak", Vector2(40.0, -110.0))
	var overhead := _foe(FlyingEnemy2D, "wakwak", Vector2(0.0, -120.0))
	await _frames(4)
	level.call("use_quick_slot", _give_the_whip())
	await _frames(2)
	_check(ahead.hp == ahead.max_hp - 3, "it reaches a flier above her and ahead",
		"%d of %d" % [ahead.hp, ahead.max_hp])
	_check(overhead.hp == overhead.max_hp, "but its 160 degrees stop short of straight up",
		"%d of %d" % [overhead.hp, overhead.max_hp])


## A second press at once does nothing; one after the 0.45 s lands.
func _a_press_too_soon_does_nothing() -> void:
	await _put_her(AT_X)
	var foe := _foe(GroundEnemy2D, "aswang_pig", Vector2(80.0, 0.0))
	foe.max_hp = 20
	foe.hp = 20
	await _frames(4)
	var slot := _give_the_whip()
	level.call("use_quick_slot", slot)
	await _frames(2)
	foe.stun(600.0)
	level.call("use_quick_slot", slot)
	await _frames(2)
	var soon := foe.hp
	await _seconds(0.5)
	foe.stun(600.0)
	level.call("use_quick_slot", slot)
	await _frames(2)
	_check(soon == 17 and foe.hp == 14, "a lash again inside 0.45 s does nothing; after it, it lands",
		"20 -> %d at once, %d after 0.5 s" % [soon, foe.hp])


## Nine lashes and it is still hers; the tenth spends it.
func _ten_lashes_and_it_is_spent() -> void:
	await _put_her(AT_X)
	var satchel := level.get("satchel") as Satchel
	var slot := _give_the_whip()
	var after_nine := 0
	for lash in range(10):
		level.call("use_quick_slot", slot)
		await _seconds(0.5)
		if lash == 8:
			after_nine = satchel.count(WHIP)
	_check(after_nine == 1 and satchel.count(WHIP) == 0, "it lashes ten times, and the tenth spends it",
		"%d after nine, %d after ten" % [after_nine, satchel.count(WHIP)])


## Made certain to drop for the check, and every other thing made never to: none from a fall by day,
## none in the night's first wave, one in its second.
func _it_drops_only_in_the_second_and_third_waves() -> void:
	var satchel := level.get("satchel") as Satchel
	for id in satchel.ids():
		satchel.row(id)["drop_chance"] = 1.0 if id == WHIP else 0.0
	await _put_her(AT_X)
	var by_day := await _whips_after_a_fall()
	var finale := _the_finale()
	await _put_her(finale.arena_west + 120.0)
	await _seconds(0.5)
	var first_wave := await _whips_after_a_fall()
	finale.elapsed = 45.5
	await _frames(3)
	var second_wave := await _whips_after_a_fall()
	_check(finale.is_running() and by_day == 0 and first_wave == 0 and second_wave == 1,
		"it drops only in the night's second and third waves",
		"by day %d, wave 1 %d, wave 2 %d" % [by_day, first_wave, second_wave])


# --- Helpers -------------------------------------------------------------------------------

## One more aswang falls beside her; how many whips that left lying.
func _whips_after_a_fall() -> int:
	var before := _whips_lying()
	var foe := _foe(GroundEnemy2D, "aswang_dog", Vector2(220.0, 0.0))
	await _frames(3)
	foe.crush(99)
	await _frames(3)
	return _whips_lying() - before


func _whips_lying() -> int:
	var count := 0
	for node in level.find_children("*", "Area2D", true, false):
		if node is SatchelPickup2D and (node as SatchelPickup2D).item == WHIP and not node.is_queued_for_deletion():
			count += 1
	return count


## The whip in her satchel, and the quick slot it is on.
func _give_the_whip() -> int:
	var satchel := level.get("satchel") as Satchel
	satchel.add(WHIP)
	for index in range(Satchel.SLOTS):
		if satchel.slot_item(index) == WHIP:
			return index
	return -1


## An enemy at `offset` from her middle, blinded a long while so it stays where it is put.
func _foe(script: GDScript, kind: String, offset: Vector2) -> Enemy2D:
	var foe: Enemy2D = script.new()
	foe.kind = kind
	level.get_node(^"EnvironmentBaseplate/GameplayPlane").add_child(foe)
	foe.global_position = PlayerHurtbox2D.middle_of(level.get("player") as Node2D) + offset
	foe.reset_home()
	foe.stun(600.0)
	return foe


func _the_finale() -> DilimFinale2D:
	for node in level.find_children("*", "Node2D", true, false):
		if node is DilimFinale2D:
			return node
	return null


## Her feet on the ground at `x`, facing right, in a long grace.
func _put_her(x: float) -> void:
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": Vector2(x, GROUND_Y - 4.0), "linear_velocity": Vector2.ZERO})
	(level.get("player_health") as PlayerHealth).call("_start_grace", 600.0)
	await _frames(6)
	Input.action_press(&"move_right")
	await _frames(2)
	Input.action_release(&"move_right")
	await _frames(6)


func _open_level() -> Node:
	var scene := (load("res://level_4.tscn") as PackedScene).instantiate()
	(scene.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(scene)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(30)
	return scene


func _seconds(seconds: float) -> void:
	await _frames(int(seconds * 60.0))


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		if paused:
			call_group(DialogueBox.GROUP, &"hide_line")
			paused = false


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
