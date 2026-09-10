extends SceneTree
## Where the player may become something, per thesis FR-8.
##
##   godot --headless --path game --script res://tests/run_morph_gate_probe.gd
##
## FR-8: "The system shall allow creature transformation only while the player is at a
## checkpoint." A rule about PLACE -- and Payyo has almost no checkpoint places to point at.
## Of its five, only CP0 is an area in the scene and CP1b is an area on one route; CP1, CP2
## and CP3 are `route_commit` triggers, which are events. So the reading matters more here
## than the code does, and the reading is `LevelBase.at_a_checkpoint`.
##
## ⚠ THE ASSERTION THAT MATTERS IS THE STRAW HEAP. Node 2 cannot be entered except by
## becoming something small enough to get under it -- that is the whole design of the beat --
## so a gate that refuses a morph there does not make Level 1 harder, it makes it
## IMPOSSIBLE. A requirement implemented until the level stops working is not implemented.

const SPAWN_ISH := Vector2(300.0, 560.0)
## ⚠ MEASURED AGAINST THE VOLUMES, not guessed from the map. The first version of this stood
## at (3700, 240) and called it open terrace -- L1_N2 is centred (3840, 160) and is 400x300,
## so that is x 3640-4040 and the probe was standing INSIDE Node 2 while asserting it was
## nowhere. All three of this file's failures came from that one wrong coordinate, and every
## one of them read as the gate being broken.
##
## The four beats are B0 x 500-1200 · N1 x 2850-3230 · N2 x 3640-4040 · N3 x 4430-4810. The
## long terrace between the stair and the gorge is in none of them, and is far enough from
## the spawn that the restore-point radius does not reach it either.
const OPEN_GROUND := Vector2(2000.0, 200.0)
## The mouth of the straw heap, inside L1_N2.
const THE_HEAP := Vector2(3860.0, 240.0)

var level: Node2D
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-54s %s" % ["OK  " if ok else "FAIL", what, detail])


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout


## Stand the apo somewhere and let the obstacle volumes notice.
func _stand_at(at: Vector2) -> void:
	var player := level.get("player") as Node2D
	player.global_position = at
	for _frame in range(24):
		await physics_frame


func _run() -> void:
	level = (load("res://game_level.tscn") as PackedScene).instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.2)

	# --- the three places -------------------------------------------------------------
	await _stand_at(SPAWN_ISH)
	var at_spawn: bool = level.call("at_a_checkpoint")
	_check(at_spawn, "the spawn counts, before any flag is raised",
		"a reset goes here, so it is the level's zeroth checkpoint" if at_spawn
		else "the player's FIRST drawing would be refused")

	await _stand_at(OPEN_GROUND)
	var on_the_terrace: bool = level.call("at_a_checkpoint")
	_check(not on_the_terrace, "open ground between beats does not",
		"refused at %s" % OPEN_GROUND if not on_the_terrace
		else "the gate lets a player change anywhere and gates nothing")

	await _stand_at(THE_HEAP)
	var at_the_heap: bool = level.call("at_a_checkpoint")
	_check(at_the_heap, "the straw heap does, which is what keeps Payyo finishable",
		"L1_N2 declares CP2" if at_the_heap
		else "Node 2 needs a morph to enter and this refuses it -- the level is IMPOSSIBLE")

	# --- and the refusal is a refusal, not a silent nothing ----------------------------
	await _stand_at(OPEN_GROUND)
	var ink := level.get("ink_manager") as InkManager
	ink.committed = 0.0
	var before: Node2D = level.get("player") as Node2D
	var drawing := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	drawing.fill(Color.WHITE)
	level.call("_on_drawing_ready", "frog", "Frog", drawing, {}, [], 0.0)
	await _wait(0.5)
	_check(level.get("player") == before, "a refused change leaves the apo as themselves",
		"still the wanderer" if level.get("player") == before else "it morphed anyway")
	_check(is_equal_approx(ink.committed, 0.0), "and costs nothing",
		"%.0f units spent" % ink.committed)
	# ⚠ THE PROPERTY, NOT THE PATH. `CanvasLayer/StatusLabel` is where the label is authored
	# and not where it ends up: the HUD frame reparents it into its own plate at build time,
	# so a path lookup returns null and the assertion reports "no status line" whether or not
	# the game said anything at all.
	var status := level.get("status_label") as Label
	var said := status != null and status.text.to_lower().contains("checkpoint")
	_check(said, "and says why", status.text if status != null else "no status line")

	# --- at a checkpoint it goes through ------------------------------------------------
	await _stand_at(THE_HEAP)
	level.call("_on_drawing_ready", "frog", "Frog", drawing, {}, [], 0.0)
	await _wait(0.8)
	_check(level.get("player") != before, "and at a checkpoint the change happens",
		"the apo became something" if level.get("player") != before
		else "refused where it should have been allowed")

	print("OBRA_MORPH_GATE_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)
