extends SceneTree
## The house, as a suite: the wall is complete, exactly what is built is enterable, and a
## painting answers when the apo is standing at it.
##
##   godot --headless --path game --script res://tests/run_hub_audit.gd
##
## Every one of these is a defect nobody would see until they walked in: a painting hung
## with no art is a black rectangle, a locked one that reports itself playable drops the
## player into an empty scene, and a reach measured the wrong way means no painting ever
## answers and the game has no way forward at all.

const HUB := "res://levels/hub/hub.tscn"

var failures: int = 0


func _init() -> void:
	_run.call_deferred()


func _check(passed: bool, what: String, detail: String) -> void:
	if not passed:
		failures += 1
	print("  %s  %-46s %s" % ["OK  " if passed else "FAIL", what, detail])


func _x_of(node: Variant) -> float:
	return (node as Node2D).global_position.x


func _run() -> void:
	var hub := (load(HUB) as PackedScene).instantiate()
	root.add_child(hub)
	for _frame in range(8):
		await process_frame

	var paintings := get_nodes_in_group(&"paintings")
	_check(paintings.size() == 5, "five paintings hang in the house",
		"%d on the wall" % paintings.size())

	# In order along the wall, and each one the level it claims to be.
	var expected := ["level_1", "level_2", "level_3", "level_4", "level_5"]
	var ids: Array[String] = []
	paintings.sort_custom(func(a, b): return _x_of(a) < _x_of(b))
	for node in paintings:
		ids.append(String(node.get("level_id")))
	_check(ids == expected, "and they hang in level order", ", ".join(ids))

	# ART, not an empty frame. A missing cover is invisible in code and obvious on screen.
	var blank: Array[String] = []
	for node in paintings:
		if node.get("art") == null:
			blank.append(String(node.get("level_id")))
	_check(blank.is_empty(), "every painting has its picture",
		"all five carry art" if blank.is_empty() else "no art: " + ", ".join(blank))

	# Exactly what is built is enterable. This is the assertion that fails the day a level
	# is added to the catalog with no scene behind it.
	var enterable: Array[String] = []
	for node in paintings:
		if bool(node.call("is_playable")):
			enterable.append(String(node.get("level_id")))
	_check(enterable == ["level_1"], "only what is built can be walked into",
		"enterable: " + ", ".join(enterable))

	# THE ROOM HAS TO FILL THE FRAME. The camera is pinned vertically -- one storey, a floor
	# that never moves -- so any part of the screen the room does not cover is grey void,
	# and it is void along the top edge, where a screenshot looks least wrong and a player
	# looks first. The house showed exactly that for as long as it was built at the scale of
	# a level, and nothing in this suite could see it.
	#
	# Measured off the camera's real zoom rather than the constant behind it, so that
	# somebody pulling the camera back to fit more of the wall on screen fails here rather
	# than in a frame nobody photographed.
	var room: Node2D = hub.get_node("Room")
	var camera := hub.get_node("Camera") as Camera2D
	var authored := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height")))
	var shown := authored / camera.zoom.y
	var drawn: float = room.call("drawn_height")
	_check(drawn >= shown.y, "the room fills the frame top to bottom",
		"%.0fpx of room against %.0fpx of screen" % [drawn, shown.y])
	_check(float(room.get("room_width")) >= shown.x, "and end to end",
		"%.0fpx of wall against %.0fpx of screen" % [float(room.get("room_width")), shown.x])

	# And a painting answers from where the apo actually stands, which is on the floor a
	# long way below it -- measured as a straight line to the picture, none ever would.
	var standing := Vector2(room.call("painting_anchor", 0).x, room.call("ground_y"))
	var answered := 0
	for node in paintings:
		if bool(node.call("within_reach", standing)):
			answered += 1
	_check(answered == 1, "standing at one painting reaches that one",
		"%d painting(s) answer from the floor at Payyo" % answered)

	# THE NAME UNDER THE PICTURE HAS TO BE UNDER THE PICTURE.
	#
	# Nothing in this suite could see the plates at all, and they were wrong for as long as
	# they existed: sized before add_child, a Label is measured against the theme's 30pt
	# instead of the 20 it draws at, Control.set_size clamps up to that and never back, and
	# a plate positioned by a fixed left offset carries the whole difference sideways. The
	# four long plates sat up to 48px right of their own paintings, out past the moulding
	# and across the doorway beside them, while the one short one was dead centre -- which
	# is exactly the shape of failure a screenshot shows and a headless suite does not.
	#
	# Measured off the built Label rather than off the arithmetic that made it, so the check
	# still means something the day the plate is built some other way.
	var gap: float = float(room.get("painting_gap"))
	var doorway: float = room.call("doorway_half")
	var worst_offset := 0.0
	var tightest := INF
	for index in range(paintings.size()):
		var painting := paintings[index] as Node2D
		var plate := painting.get_node_or_null("Plate") as Control
		if plate == null:
			_check(false, "every painting carries a name plate",
				"%s has none" % String(painting.get("level_id")))
			continue
		var plate_rect := Rect2(plate.position, plate.size * plate.scale)
		worst_offset = maxf(worst_offset, absf(plate_rect.position.x + plate_rect.size.x * 0.5))
		# A doorway sits half a painting-gap either side of every picture, and the pier the
		# picture hangs on stops at its architrave. That edge is what the lettering may not
		# reach -- measured on the TEXT and not on the label box, because the box is the
		# picture's own width and would report the same clearance whatever was written in it.
		var font: Font = plate.get_theme_font(&"font")
		var ink: float = font.get_string_size(plate.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			plate.get_theme_font_size(&"font_size")).x * plate.scale.x
		tightest = minf(tightest, gap * 0.5 - doorway - ink * 0.5)
	_check(worst_offset <= 1.0, "every name plate is centred on its painting",
		"worst is %.1fpx off centre" % worst_offset)
	_check(tightest > 0.0, "and none of them reaches the doorway beside it",
		"%.1fpx of clearance at the tightest" % tightest)

	if failures == 0:
		print("OBRA_HUB_AUDIT_OK")
	else:
		print("OBRA_HUB_AUDIT_FAILED=%d" % failures)
	quit(1 if failures > 0 else 0)
