extends SceneTree
## Scene 3, played rather than modelled.
##
##	 godot --headless --path game --script res://tests/run_assembly_probe.gd
##
## `run_level2_systems_probe` proves `ScrapAssembly` snaps, refuses a double release and
## finishes at seven. All of that was true while the level could not be finished at all,
## because nothing opened a screen for it -- the same shape the dance was in, and the second
## time in this level that a complete, tested model shipped with no caller.
##
## So this drives the table: open it the way the level does, put pieces down where a hand
## would put them, and check that the picture being whole is what ENDS PIYESTA.

var results: Array[String] = []
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	results.append("  %s  %-44s %s" % ["OK  " if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _run() -> void:
	print("\n===== SCENE 3 =====")
	await _audit_the_pieces_are_the_ledgers()
	await _audit_it_is_put_back_together()
	for line in results:
		print(line)
	if failures == 0:
		print("OBRA_ASSEMBLY_OK")
		quit(0)
	else:
		print("OBRA_ASSEMBLY_FAILED=%d" % failures)
		quit(1)


func _open() -> Node:
	var fresh := (load("res://level_2.tscn") as PackedScene).instantiate()
	(fresh.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(fresh)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(30):
		await physics_frame
	return fresh


## ⚠ THE IDS HAVE TO MATCH THE LEDGER'S, and nothing else in the project would say if they
## did not. `ScrapAssembly` matches a slot by id; `ScrapLedger` hands out `alley1_0..4` and
## `alley2_0..1`; `tools/build_scraps.py` writes them into scraps.json. Three files agreeing
## by convention is three files that can stop agreeing.
func _audit_the_pieces_are_the_ledgers() -> void:
	var fresh := await _open()
	var table := fresh.get("assembly_screen") as AssemblyOverlay
	if table == null:
		_check(false, "the level built a table to assemble on", "no overlay")
		fresh.queue_free()
		return
	table.present()
	var ids := table.piece_ids()
	_check(ids.size() == ScrapLedger.TOTAL, "seven pieces on the table",
		"%d cut by tools/build_scraps.py" % ids.size())
	var expected: Array[String] = []
	for index in range(ScrapLedger.IN_ALLEY_1):
		expected.append("alley1_%d" % index)
	for index in range(ScrapLedger.IN_ALLEY_2):
		expected.append("alley2_%d" % index)
	var missing: Array[String] = []
	for want in expected:
		if not ids.has(want):
			missing.append(want)
	_check(missing.is_empty(), "and every one carries a ledger id",
		"the ids the birds and the bandaritas hand out" if missing.is_empty()
		else "missing: %s" % ", ".join(missing))
	# Scattered, or there is nothing to do.
	var in_place := 0
	for scrap_id in ids:
		if table.position_of(scrap_id).distance_to(table.slot_of(scrap_id)) < 1.0:
			in_place += 1
	_check(in_place == 0, "and none of them starts where it belongs",
		"the picture arrives knocked sideways")
	_check(not table.closes_on_cancel, "and Escape cannot throw it away half-mended",
		"this is the end of the level")
	table.close()
	fresh.queue_free()
	await process_frame


func _audit_it_is_put_back_together() -> void:
	var fresh := await _open()
	var table := fresh.get("assembly_screen") as AssemblyOverlay
	var assembly = fresh.get("assembly")
	if table == null or assembly == null:
		_check(false, "the table and its rule both exist", "-")
		fresh.queue_free()
		return
	table.present()
	var ids := table.piece_ids()

	# Dropped nowhere near where it came from. Nothing happens, and nothing is lost.
	var first: String = ids[0]
	var far := table.slot_of(first) + Vector2(600.0, 420.0)
	_check(not table.drag_to(first, far), "a piece dropped far from its place does not stick",
		"and it is not a failure -- there is nothing to get wrong here")
	_check(int(assembly.call("placed")) == 0, "and nothing is counted for it", "0 of 7")

	# Dropped close enough, it snaps home -- and it snaps to WHERE IT WAS TORN FROM, not to
	# where the hand let go, or the picture would reassemble slightly wrong.
	var near := table.slot_of(first) + Vector2(ScrapAssembly.SNAP_RADIUS * 0.5, 0.0)
	_check(table.drag_to(first, near), "dropped near it, it goes in", "within the snap")
	_check(table.position_of(first).distance_to(table.slot_of(first)) < 0.5,
		"and it lands exactly where it was torn from", "not where the hand let go")
	_check(not table.drag_to(first, near), "and a piece already in cannot be placed twice",
		"a double release is not two of seven")

	for index in range(1, ids.size()):
		table.drag_to(ids[index], table.slot_of(ids[index]))
	_check(bool(assembly.call("is_complete")), "the rest go home and that is seven",
		"%d of %d" % [int(assembly.call("placed")), int(assembly.call("slot_count"))])

	# ⚠ AND FINISHING IT IS WHAT ENDS THE LEVEL. Not a marker somebody has to walk to
	# afterwards -- Level 1 shipped that and players solved its hardest node and then stood
	# there wondering what to do.
	var overlay := fresh.get_node_or_null("LevelCompleteOverlay")
	_check(overlay != null and not bool(overlay.call("is_open")),
		"the level has not ended merely by assembling it", "the player still says when")
	table.call("_on_continue")
	for _frame in range(120):
		if overlay != null and bool(overlay.call("is_open")):
			break
		await physics_frame
	_check(overlay != null and bool(overlay.call("is_open")),
		"and dismissing the finished picture ends Piyesta",
		"the last thing you do is the thing that ends it")
	if overlay != null and bool(overlay.call("is_open")):
		overlay.call("close")
	paused = false
	fresh.queue_free()
	await process_frame
