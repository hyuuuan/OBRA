extends SceneTree
## The tik-tik, headless: the finale's third wave, the flier she cannot see.
##
##   godot --headless --path game --script res://tests/run_level4_tiktik_probe.gd
##
## Sent the way the night sends it -- by the finale, so the level listens to it as it would -- then
## put where each check needs it, held still by a long blinding where its moving would blur what is
## measured. A fresh level for each, so nothing leaks into the next.
##
## `-- <words>` runs only the scenarios whose name holds them (for a mutant, which needs only the
## check that guards it); the every-check-ran guard stands down for such a run.

const GROUND_Y := 600.0
## In the last clearing, where the night is.
const CLEARING_X := 21900.0

var failures := 0
var checked := 0
const CHECKS := 7
var level: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(300.0).timeout.connect(func() -> void:
		print("OBRA_L4_TIKTIK_FAILED=watchdog")
		quit(2))
	var only := " ".join(OS.get_cmdline_user_args())
	for scenario in [_unseen_a_blow_goes_through, _ash_shows_it, _its_call_is_louder_far,
			_the_level_shows_its_call, _the_lantern_leans_only_when_it_is_close, _garlic_keeps_it_out]:
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
		print("OBRA_L4_TIKTIK_OK")
		quit(0)
	else:
		print("OBRA_L4_TIKTIK_FAILED=%d" % failures)
		quit(1)


func _unseen_a_blow_goes_through() -> void:
	var tiktik := await _sent_beside_her(Vector2(40.0, -30.0))
	var hp := tiktik.hp
	var landed := tiktik.apply_tool_hit("sword", 0.0, level.get("player") as Node2D)
	_check(tiktik.modulate.a == 0.0 and not landed and tiktik.hp == hp,
		"unseen, it is not drawn and a blow goes through it",
		"alpha %.1f, landed %s, hp %d of %d" % [tiktik.modulate.a, landed, tiktik.hp, hp])


func _ash_shows_it() -> void:
	var tiktik := await _sent_beside_her(Vector2(40.0, -30.0))
	# Let go of the helper's hold first, so a blinding seen after is the ash's.
	tiktik.stun(0.01)
	await _frames(3)
	var before := tiktik.state_name()
	var dust := AboDust2D.new()
	dust.position = (level.get("player") as Node2D).global_position
	level.get_node(^"EnvironmentBaseplate/GameplayPlane").add_child(dust)
	await _frames(3)
	# Read before the blow below, which stuns it too.
	var after := tiktik.state_name()
	var hp := tiktik.hp
	var landed := tiktik.apply_tool_hit("sword", 0.0, level.get("player") as Node2D)
	_check(before != "STUN" and tiktik.is_revealed() and tiktik.modulate.a == 1.0 and after == "STUN",
		"ash shows it, and blinds it for a moment", "revealed %s, alpha %.1f, %s -> %s"
			% [tiktik.is_revealed(), tiktik.modulate.a, before, after])
	_check(landed and tiktik.hp < hp, "and shown, a blow lands", "landed %s, hp %d of %d" % [landed, tiktik.hp, hp])


## The design's numbers: nothing inside 180, all of it by 1100, and louder at every step out.
func _its_call_is_louder_far() -> void:
	var steps: Array[float] = []
	for distance in [100.0, 180.0, 300.0, 500.0, 700.0, 900.0, 1100.0, 1400.0]:
		steps.append(Tiktik2D.call_strength(distance))
	var rising := true
	for index in range(2, 7):
		rising = rising and steps[index] > steps[index - 1]
	_check(steps[0] == 0.0 and steps[1] == 0.0 and rising and steps[6] == 1.0 and steps[7] == 1.0,
		"its call is louder the further off it is", ", ".join(steps.map(func(v): return "%.2f" % v)))


## Heard far off, the level puts a violet ripple up as strong as the call.
func _the_level_shows_its_call() -> void:
	var tiktik := await _sent_beside_her(Vector2(700.0, -100.0))
	var heard := [-1.0]
	tiktik.called.connect(func(_at: Vector2, strength: float) -> void: heard[0] = strength)
	var ripple := level.get("edge_ripple") as EdgeRipple
	var shown := -1.0
	for _frame in range(int((Tiktik2D.CALL_EVERY + 0.5) * 60.0)):
		await _frames(1)
		if heard[0] >= 0.0:
			for entry: Dictionary in ripple.get("_ripples"):
				if String(entry.get("kind", "")) == "tiktik":
					shown = float(entry.get("strength", -1.0))
			break
	_check(heard[0] > 0.3 and absf(shown - heard[0]) < 0.01,
		"heard far off, its call goes up on the screen's edge, violet", "called %.2f, shown %.2f" % [heard[0], shown])


## The design's 220: beyond it the lantern is as it was; inside it, it leans and its light drops 18%.
func _the_lantern_leans_only_when_it_is_close() -> void:
	var lantern := level.get("held_lantern") as HeldLantern2D
	var hud := level.get("lantern_hud") as LanternHud
	var tiktik := await _sent_beside_her(Vector2(0.0, -600.0))
	await _frames(20)
	var full := lantern.radius()
	tiktik.global_position = lantern.global_position + Vector2(0.0, -240.0)
	await _frames(4)
	var far_lean := float(hud.get("_lean"))
	var far_dragged := lantern.is_dragged()
	tiktik.global_position = lantern.global_position + Vector2(0.0, -150.0)
	await _frames(4)
	var near_lean := float(hud.get("_lean"))
	_check(far_lean == 0.0 and not far_dragged and near_lean > 0.2 and near_lean < 0.5
			and lantern.is_dragged() and absf(lantern.radius() - full * 0.82) < 1.0,
		"the lantern leans and gutters only once it is within 220",
		"at 240: lean %.2f, dragged %s; at 150: lean %.2f, light %.0f of %.0f"
			% [far_lean, far_dragged, near_lean, lantern.radius(), full])


## Done circling and already inside its strike, it strikes -- unless she stands in garlic.
func _garlic_keeps_it_out() -> void:
	var player := level.get("player") as Node2D
	var tiktik := await _sent_beside_her(Vector2(30.0, -20.0))
	var ward := BawangWard2D.new()
	ward.seconds = 30.0
	ward.position = player.global_position
	level.get_node(^"EnvironmentBaseplate/GameplayPlane").add_child(ward)
	await _frames(2)
	tiktik.set("_circling", 0.0)
	tiktik.stun(0.05)
	var struck := [false]
	tiktik.struck_player.connect(func(_foe: Enemy2D) -> void: struck[0] = true)
	var wound_up := false
	for _frame in range(180):
		await _frames(1)
		wound_up = wound_up or tiktik.state_name() == "WINDUP"
	var held_off := tiktik.global_position.distance_to(player.global_position)
	var reach := ward.radius
	ward.queue_free()
	await _frames(2)
	tiktik.set("_circling", 0.0)
	var came := false
	for _frame in range(300):
		await _frames(1)
		if tiktik.state_name() == "WINDUP":
			came = true
			break
	_check(not wound_up and not struck[0] and held_off > reach and came,
		"in garlic it will not come in to strike; out of it, it does",
		"wound up %s, struck %s, held %.0f out of %.0f; then came %s"
			% [wound_up, struck[0], held_off, reach, came])


# --- Helpers -------------------------------------------------------------------------------

## The finale's own tik-tik, sent as the third wave would send it, and put at `offset` from her
## middle -- blinded a long while, so it stays there until a check lets it go.
func _sent_beside_her(offset: Vector2) -> Tiktik2D:
	await _put(CLEARING_X - 900.0, GROUND_Y)
	var finale := _the_finale()
	finale.call("_send_flier", "tiktik")
	var tiktik := finale.tiktik()
	tiktik.global_position = PlayerHurtbox2D.middle_of(level.get("player") as Node2D) + offset
	tiktik.stun(600.0)
	await _frames(4)
	return tiktik


func _the_finale() -> DilimFinale2D:
	for node in level.find_children("*", "Node2D", true, false):
		if node is DilimFinale2D:
			return node
	return null


## Her feet on the ground at `x`, in a long grace.
func _put(x: float, ground_y: float) -> void:
	var player := level.get("player") as Node2D
	player.call("apply_morph_state", {"position": Vector2(x, ground_y - 4.0), "linear_velocity": Vector2.ZERO})
	(level.get("player_health") as PlayerHealth).call("_start_grace", 600.0)
	await _frames(6)


func _open_level() -> Node:
	var scene := (load("res://level_4.tscn") as PackedScene).instantiate()
	(scene.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(scene)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(30)
	return scene


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
