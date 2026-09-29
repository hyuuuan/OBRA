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
	await _audit_the_crease_is_on_the_plaza()
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
	for _frame in range(4):
		await process_frame
	var fits: Array = _fits_on_screen(table)
	_check(bool(fits[0]), "the table fits on the screen", String(fits[1]))
	# And with CONTINUE showing, which is the tallest the panel ever gets.
	(table.get("_continue") as Control).visible = true
	for _frame in range(4):
		await process_frame
	fits = _fits_on_screen(table)
	_check(bool(fits[0]), "and still fits once CONTINUE is showing", String(fits[1]))
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


## ⚠ PAYYO'S CREASE IS ON THE CANVAS IT CREASED. Level 1's Protector route folded
## canvas_2_pista -- this plaza. It used to be drawn on the table, while the table assembled the
## plaza; the table assembles the sea now, a different canvas nobody folded. So with the damage
## on the profile the fold is on the plaza, the table's picture is whole, and Lolo says so when
## the player arrives rather than about a picture it is not on.
func _audit_the_crease_is_on_the_plaza() -> void:
	root.get_node("PlayerProfile").call("record_canvas_damage", "canvas_2_pista")
	var fresh := await _open()
	var fold := fresh.get_node_or_null(^"EnvironmentBaseplate/GameplayPlane/Crease") as Node2D
	var backdrop := fresh.get_node_or_null(^"EnvironmentBaseplate/PlazaBackdrop") as Sprite2D
	var spans := false
	if fold != null and backdrop != null:
		var top: Vector2 = fold.to_global(fold.get("top"))
		var bottom: Vector2 = fold.to_global(fold.get("bottom"))
		var painted := backdrop.get_rect()
		painted.position += backdrop.global_position
		spans = absf(top.y - painted.position.y) < 1.0 and absf(bottom.y - painted.end.y) < 1.0
	_check(fold != null and spans, "the fold runs down the plaza's painting",
		"top to bottom of the backdrop" if spans else "no fold, or not across the painting")
	var assembly = fresh.get("assembly")
	_check(assembly != null and not bool(assembly.call("is_creased")),
		"and the table's picture is not folded", "a different canvas")
	# `peek` applies a line's condition, so the fold line is in it only if the level set the
	# flag the line waits on -- and the greeting has to have been given at all.
	var lines = fresh.get("script_lines")
	_check(bool(lines.call("has_heard", "L2_START.enter")) and _fold_line_heard(lines),
		"and Lolo mentions it when they arrive", "L2_START.enter carries the fold line")
	fresh.queue_free()
	for _frame in range(4):
		await process_frame


func _fold_line_heard(lines: Object) -> bool:
	for line: Variant in lines.call("peek", "L2_START.enter"):
		if String((line as Dictionary).get("text", "")).contains("fold"):
			return true
	return false


## ⚠ THE PANEL HAS TO FIT ON THE SCREEN IT IS SHOWN ON. Its minimum size was taller than the
## 900-unit viewport once a title, a rule, a status line and the frame's own ring were added
## to the stage, so the bottom border and the line telling the player what to do sat off the
## bottom edge. Nothing measured it; it was found in a screenshot.
func _fits_on_screen(overlay: Node) -> Array:
	var panel := overlay.find_child("Panel", true, false) as Control
	if panel == null:
		return [false, "no panel"]
	var view := Rect2(Vector2.ZERO, Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height"))))
	var rect := panel.get_global_rect()
	return [view.encloses(rect), "panel %s in a %s screen" % [rect, view.size]]
