extends SceneTree
## A painting a level has just opened is unlocked in front of the player.
##
##   godot --headless --path game --script res://tests/run_unlock_reveal_probe.gd
##
## Kent, of finishing Payyo: back to the house, and "there should be an animation wherein the
## level gets unlocked". A painting that was built and not yet reached used to hang exactly as an
## open one did. It hangs locked now -- dimmed, a padlock, LOCKED on its plate -- and the level
## that opens it tells the house to open it where the player can see.

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-52s %s" % ["OK  " if ok else "FAIL", what, detail])


func _run() -> void:
	print("\n===== UNLOCKED IN FRONT OF HER =====")
	var profile := root.get_node("PlayerProfile")
	var manager := root.get_node("LevelManager")
	profile.set("_data", profile.call("_default_profile"))
	profile.call("record_brush_acquired")
	manager.set("pending_reveal", "")

	# Finishing Payyo is what opens Piyesta, and the level says so to the house.
	var level := (load("res://game_level.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	await process_frame
	level.call("mark_finished", "level_1")
	_check(String(manager.get("pending_reveal")) == "level_2", "finishing Payyo tells the house Piyesta opened",
		"pending '%s'" % manager.get("pending_reveal"))
	manager.set("pending_reveal", "")
	level.call("mark_finished", "level_1")
	_check(String(manager.get("pending_reveal")).is_empty(), "and finishing it again tells it nothing",
		"Piyesta was already open")
	level.queue_free()
	await process_frame
	manager.set("pending_reveal", "level_2")

	var hub := (load("res://levels/hub/hub.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	await process_frame
	await process_frame
	var piyesta := _painting("level_2")
	var dagat := _painting("level_3")
	_check(piyesta != null and bool(piyesta.call("is_locked")), "Piyesta hangs locked as she comes in",
		_plate(piyesta))
	_check(dagat != null and bool(dagat.call("is_locked")) and _plate(dagat).ends_with("LOCKED"),
		"and Dagat, which is not open, hangs locked", _plate(dagat))
	var waited := 0.0
	while waited < 8.0 and (bool(piyesta.call("is_locked")) or bool(hub.call("is_revealing"))):
		await create_timer(0.1).timeout
		waited += 0.1
	_check(not bool(piyesta.call("is_locked")) and _plate(piyesta) == "PIYESTA",
		"and the house unlocks it in front of her", "in %.1f s, the plate reads %s" % [waited, _plate(piyesta)])
	_check(bool(dagat.call("is_locked")), "and leaves Dagat locked", _plate(dagat))
	var status := String((hub.get("_status") as Label).text)
	_check(status.contains("Piyesta"), "and says where to go", status)
	_check(String(manager.call("take_pending_reveal")).is_empty(), "and only once", "taken")

	print("OBRA_UNLOCK_REVEAL_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)


func _painting(level_id: String) -> Node:
	for node in get_nodes_in_group(&"paintings"):
		if String(node.get("level_id")) == level_id:
			return node
	return null


func _plate(painting: Node) -> String:
	if painting == null:
		return "-"
	var plate := painting.get_node_or_null("Plate") as Label
	return plate.text if plate != null else "-"
