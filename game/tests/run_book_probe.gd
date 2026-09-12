extends SceneTree
## The bag screen's roster -- what the player knows, and the shape of what they do not.
##
##   godot --headless --path game --script res://tests/run_book_probe.gd
##
## ⚠ THIS SCREEN WALKS A LINE AND BOTH SIDES OF IT ARE ASSERTED HERE.
##
## The line: this game never names a drawable class the player has not earned. It is why
## `RequirementStrip` prints ability TAGS, why no line of dialogue may name a class, and why
## the tutorial may not either. Printing the fifty would turn every obstacle into a lookup.
##
## And the other side: a player who cannot tell that the roster HAS twenty animals in it
## will never think to draw one. Counting a group names nothing, so the bands say how many
## creatures, objects and shapes exist and how many of each this player has drawn -- and the
## ones they have not drawn are unnamed frames with no tooltip and nothing to click.

var level: Node2D
var screen: InventoryScreen
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-52s %s" % ["OK  " if ok else "FAIL", what, detail])


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _grid(role: String) -> GridContainer:
	return (screen.get("_band_grids") as Dictionary).get(role) as GridContainer


func _count_text(role: String) -> String:
	var label := (screen.get("_band_counts") as Dictionary).get(role) as Label
	return label.text if label != null else ""


## Every name any frame in the roster is showing right now.
func _names_on_screen() -> Array[String]:
	var shown: Array[String] = []
	for band: Variant in InventoryScreen.BANDS:
		var grid := _grid(String((band as Dictionary)["role"]))
		if grid == null:
			continue
		for child in grid.get_children():
			for inner in child.get_children():
				var label := inner as Label
				if label != null and not label.text.is_empty():
					shown.append(label.text)
	return shown


func _run() -> void:
	level = (load("res://game_level.tscn") as PackedScene).instantiate() as Node2D
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.2)
	screen = level.get("inventory_screen") as InventoryScreen
	var profile := root.get_node_or_null("PlayerProfile")
	# A fresh book: nothing drawn.
	(profile.get("_data")["classes_drawn_accepted"] as Array).clear()
	screen.call("open")
	await _wait(0.4)

	# --- the bands are the manifest's own split ------------------------------------------
	_check(_count_text("active_ragdoll_morph") == "0 / 20",
		"twenty creatures exist and none are known yet",
		_count_text("active_ragdoll_morph"))
	_check(_count_text("utility") == "0 / 27", "twenty-seven objects",
		_count_text("utility"))
	_check(_count_text("physics_morph") == "0 / 3", "three shapes",
		_count_text("physics_morph"))

	# --- ⚠ AND NOTHING IS NAMED ----------------------------------------------------------
	var named := _names_on_screen()
	_check(named.is_empty(),
		"an empty book names no class at all",
		"nothing on screen" if named.is_empty()
		else "PRINTS THE ANSWERS: %s" % ", ".join(named))

	# --- draw three things, and only those three are named -------------------------------
	for id in ["frog", "ladder", "circle"]:
		profile.call("record_class_drawn", id)
	screen.call("refresh")
	await _wait(0.3)
	_check(_count_text("active_ragdoll_morph") == "1 / 20"
		and _count_text("utility") == "1 / 27"
		and _count_text("physics_morph") == "1 / 3",
		"one of each kind lands in its own band",
		"%s · %s · %s" % [_count_text("active_ragdoll_morph"),
			_count_text("utility"), _count_text("physics_morph")])
	named = _names_on_screen()
	named.sort()
	_check(", ".join(named) == "Circle, Frog, Ladder",
		"and the named frames are exactly what was drawn",
		", ".join(named))

	# --- a band holds a frame per class, drawn or not -------------------------------------
	_check(_grid("active_ragdoll_morph").get_child_count() == 20,
		"the creature band has twenty frames whether or not they are known",
		"%d frames" % _grid("active_ragdoll_morph").get_child_count())

	print("OBRA_BOOK_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)
