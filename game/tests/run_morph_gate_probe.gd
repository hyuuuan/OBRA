extends SceneTree
## The player may become something anywhere.
##
##   godot --headless --path game --script res://tests/run_morph_gate_probe.gd
##
## Kent (2026-10-02): "why cant the player transform anywhere, why does it need to be in a
## checkpoint its so weird". Thesis FR-8 allowed it only at a checkpoint, read as standing inside
## a beat that declares one -- invisible to a player, so the same drawing became a frog on one
## patch of terrace and was refused on the next. That gate is gone, on his decision; this probe
## used to hold it and now holds the opposite: open ground, the spawn and the straw heap all
## take the change, and it costs no ink (FR-7).

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

	var ink := level.get("ink_manager") as InkManager
	var drawing := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	drawing.fill(Color.WHITE)
	for place: Array in [[OPEN_GROUND, "open ground between beats"], [SPAWN_ISH, "the spawn"],
			[THE_HEAP, "the straw heap"]]:
		level.call("_revert_to_base_form")
		await _wait(0.4)
		await _stand_at(place[0])
		ink.committed = 0.0
		var before: Node2D = level.get("player") as Node2D
		level.call("_on_drawing_ready", "frog", "Frog", drawing, {}, [], 0.0)
		await _wait(0.8)
		var became: bool = level.get("player") != before
		_check(became, "a frog drawn on %s becomes one" % place[1],
			"the apo is a frog" if became else "refused -- %s" % (level.get("status_label") as Label).text)
		_check(is_equal_approx(ink.committed, 0.0), "and costs nothing", "%.0f units spent" % ink.committed)

	print("OBRA_MORPH_GATE_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)
