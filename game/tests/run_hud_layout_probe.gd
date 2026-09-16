extends SceneTree
## NOTHING ON THE HUD MAY STAND ON ANYTHING ELSE.
##   godot --headless --path game --script res://tests/run_hud_layout_probe.gd
##
## Kent, after a playthrough: "the texts, everything is overlapping against each other". Each
## piece of this interface was placed on its own and looked right on its own -- the badge, the
## objective under it, the hint bar under that, the checkpoint chip beside the ink plate, the
## requirement strip above the prompts -- and no check anywhere asked what happens when more
## than one of them is up at the same time, which in play is most of the time.
##
## So this puts them ALL up at once, in both levels, reads the rectangle each one actually
## paints, and fails on any pair that lands on top of another or on anything that hangs off
## the edge of the screen. It measures what is drawn rather than the layout containers around
## it: a wrapper that fills the screen and paints nothing is not an overlap, and a caption
## sitting across somebody else's panel is.

const LEVELS := ["res://game_level.tscn", "res://level_2.tscn"]
## How much two painted rectangles may share before it counts. Two chips whose rings touch by
## a pixel are not the fault this is looking for.
const SLACK := 3.0

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		failures += 1
	print("  %s  %-46s %s" % ["OK  " if ok else "FAIL", what, detail])


func _run() -> void:
	print("\n===== HUD LAYOUT =====")
	for path in LEVELS:
		await _audit(path)
	print("OBRA_HUD_LAYOUT_%s" % ("OK" if failures == 0 else "FAILED=%d" % failures))
	quit(1 if failures > 0 else 0)


func _audit(path: String) -> void:
	var level := (load(path) as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	for _frame in range(40):
		await physics_frame

	# Off the opening cinematic first. Piyesta opens with the bars in, and a HUD half faded
	# out under a caption in the letterbox is a moment, not a layout.
	var bars := level.get_node_or_null(^"CinematicBars") as CinematicBars
	for _frame in range(600):
		if bars == null or not bars.is_playing():
			break
		await physics_frame
	for _frame in range(30):
		await physics_frame

	await _turn_everything_on(level)
	var painted := _painted(level)
	_check(painted.size() >= 6, "%s: the HUD is on screen" % path.get_file(),
		"%d things drawn" % painted.size())

	# --- nothing stands on anything else -------------------------------------------------
	var clashes: Array[String] = []
	for first in range(painted.size()):
		for second in range(first + 1, painted.size()):
			var a: Dictionary = painted[first]
			var b: Dictionary = painted[second]
			var shared := (a["rect"] as Rect2).intersection(b["rect"] as Rect2)
			if shared.size.x > SLACK and shared.size.y > SLACK:
				clashes.append("%s over %s (%dx%d)" % [a["name"], b["name"],
					int(shared.size.x), int(shared.size.y)])
	_check(clashes.is_empty(), "%s: nothing overlaps anything" % path.get_file(),
		"%d pieces, all clear" % painted.size() if clashes.is_empty()
		else "; ".join(clashes))

	# --- and nothing hangs off the screen ------------------------------------------------
	var view := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var escaped: Array[String] = []
	for entry_value: Variant in painted:
		var entry: Dictionary = entry_value
		var rect: Rect2 = entry["rect"]
		if not view.encloses(rect):
			escaped.append("%s at %s" % [entry["name"], rect])
	_check(escaped.is_empty(), "%s: nothing hangs off the screen" % path.get_file(),
		"all inside %s" % view.size if escaped.is_empty() else "; ".join(escaped))

	level.queue_free()
	await process_frame


## Every state the HUD can be in at once, because that is the state it is in while a player is
## standing at an obstacle holding something with a beat playing.
func _turn_everything_on(level: Node) -> void:
	var director: Object = level.get("director")
	var first := String((director.call("obstacle_ids") as Array)[0])
	director.call("enter_obstacle", first)
	for _frame in range(4):
		await physics_frame
	# The longest thing each channel can say, so the check is against the worst case rather
	# than against whatever happens to be showing.
	# THE REQUIREMENT STRIP AT ITS TALLEST. Four wrong answers takes the hint ladder to its
	# last rung, which is the state that prints a tag line, a gloss, the classes the player
	# owns and the one clue -- the tallest this strip ever gets, and the one that used to run
	# its bottom border through the action prompts.
	for _miss in range(5):
		director.call("note_submission", "clock")
		await physics_frame
	level.call("_refresh_requirements")
	for _frame in range(4):
		await physics_frame
	var bar := level.get("hint_bar") as HintBar
	bar.show_hint("There is a way in under the straw, and you are too big for it. "
		+ "NEEDS BURROW -- able to get in under something", Lolo.SPEAKER, 90.0)
	var card: Object = level.get("morph_card")
	if card != null:
		card.call("show_form", "Sea Turtle", Image.create(28, 28, false, Image.FORMAT_RGBA8), 0.94)
	var bag: Object = level.get("inventory_manager")
	for id in ["ladder", "axe", "key"]:
		var item := DrawnItemData.new()
		item.entity_id = id
		item.display_name = id.capitalize()
		bag.call("add_item", item)
	var prompts: Object = level.get("action_prompts")
	if prompts != null:
		prompts.call("set_pickup_available", true, "Ladder")
		prompts.call("set_use_available", true, "Axe")
		prompts.call("set_revert_available", true)
	var tutorial: Object = level.get("tutorial")
	if tutorial != null:
		tutorial.call("note", "level_start")
	for _frame in range(30):
		await physics_frame


## What is actually DRAWN, and where. A Control that fills the screen to hold two chips paints
## nothing itself; its chips do. So: panels that carry a stylebox, plus labels that are not
## inside one of those panels, which is what a stray caption looks like.
func _painted(level: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var panels: Array[Control] = []
	for layer in level.get_children():
		if layer is CanvasLayer:
			_collect_panels(layer, panels)
	for panel in panels:
		out.append({"name": _trail(panel, level), "rect": panel.get_global_rect()})
	for layer in level.get_children():
		if layer is CanvasLayer:
			_collect_loose_labels(layer, panels, out, level)
	return out


## Faded out is not on screen. The letterbox fades the whole HUD to nothing while its bars are
## in, and `visible` stays true through that -- so without this every chip on the screen reads
## as standing on the cinematic's caption, which nobody can see at the same time as them.
func _shows(node: CanvasItem) -> bool:
	var alpha := 1.0
	var cursor: Node = node
	while cursor != null:
		var item := cursor as CanvasItem
		if item != null:
			alpha *= item.modulate.a * item.self_modulate.a
		cursor = cursor.get_parent()
	return alpha > 0.05


func _collect_panels(node: Node, into: Array[Control]) -> void:
	var panel := node as PanelContainer
	if panel != null and panel.is_visible_in_tree() and _shows(panel) and panel.size.x > 8.0 \
			and panel.size.y > 8.0 and panel.has_theme_stylebox_override(&"panel"):
		into.append(panel)
		return
	for child in node.get_children():
		_collect_panels(child, into)


func _collect_loose_labels(node: Node, panels: Array[Control], into: Array[Dictionary],
		level: Node) -> void:
	var label := node as Label
	if label != null:
		if not label.is_visible_in_tree() or not _shows(label) \
				or label.text.strip_edges().is_empty():
			return
		for panel in panels:
			if label.is_ancestor_of(panel) or panel.is_ancestor_of(label):
				return
		into.append({"name": _trail(label, level), "rect": label.get_global_rect()})
		return
	for child in node.get_children():
		_collect_loose_labels(child, panels, into, level)


## The path, with the script's own class where a node was never named -- "@PanelContainer@224"
## says nothing about which piece of the interface is standing on which.
func _trail(node: Node, level: Node) -> String:
	var parts := PackedStringArray([_label_of(node)])
	var cursor := node.get_parent()
	while cursor != null and cursor != level:
		parts.insert(0, _label_of(cursor))
		cursor = cursor.get_parent()
	return "/".join(parts)


func _label_of(node: Node) -> String:
	var named := String(node.name)
	if not named.begins_with("@"):
		return named
	var script := node.get_script() as Script
	if script != null and not String(script.get_global_name()).is_empty():
		return String(script.get_global_name())
	return node.get_class()
