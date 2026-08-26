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


## Leave user://profile.json exactly as it was found.
func _restore_profile(profile: Node, had_brush: bool, had_profile: bool) -> void:
	(profile.get("_data") as Dictionary)["brush_acquired"] = had_brush
	if had_profile:
		profile.call("save_profile")
	elif FileAccess.file_exists("user://profile.json"):
		DirAccess.remove_absolute("user://profile.json")


func _run() -> void:
	# ARRANGED BEFORE THE HOUSE IS BUILT. BrushStand2D asks the profile whether the brush is
	# still under the glass in its _ready(), so a "before" state set after the hub is in the
	# tree sets nothing -- the case has already made up its mind and the three assertions at
	# the bottom of this file fail on a gate that is working perfectly.
	var profile := root.get_node_or_null("PlayerProfile")
	var manager := root.get_node_or_null("LevelManager")
	_check(profile != null and manager != null, "the autoloads the house needs are up",
		"PlayerProfile and LevelManager")
	if profile == null or manager == null:
		quit(1)
		return
	var data: Dictionary = profile.get("_data")
	var had_brush := bool(data.get("brush_acquired", false))
	var had_profile := FileAccess.file_exists("user://profile.json")
	data["brush_acquired"] = false

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

	# THE BRUSH, WHICH IS THE WAY OUT OF THIS ROOM.
	#
	# Every verb in this game is drawing, so a player who leaves the house without the brush
	# arrives in Payyo with nothing to do. These check the whole of that: it is here, it
	# answers where the apo can reach it, it refuses the paintings until it is taken, and
	# taking it empties the case and opens them. A gate that only half works is worse than
	# no gate -- one that refuses forever strands the player in the hub, and one that lets
	# them past strands them in the level.
	#
	# THE PROFILE FILE IS PUT BACK at the end of this block. The "before" state above was
	# arranged in memory and touched nothing on disk, but `take()` is the thing under test
	# and it commits, so by here user://profile.json really does claim a brush. Whoever ran
	# this must not be handed one they did not walk over and take.
	var stand := hub.get_node_or_null("BrushStand") as Node2D
	_check(stand != null, "the brush stands at the end of the hall",
		"at x %.0f" % [stand.global_position.x if stand != null else -1.0])
	if stand == null:
		_restore_profile(profile, had_brush, had_profile)
		quit(1)
		return

	# Inside the room, past the last picture, and reachable by an apo standing at it. The
	# stand is placed by a constant in hub.gd and the wall's length by one in hub_room.gd,
	# so this is the check that fires the day either moves without the other.
	var wall_end: float = float(room.get("room_width"))
	var last_painting: float = _x_of(paintings[paintings.size() - 1])
	_check(stand.global_position.x > last_painting and stand.global_position.x < wall_end,
		"and it stands past the paintings, inside the room",
		"%.0f, between the last picture at %.0f and the wall at %.0f" % [
			stand.global_position.x, last_painting, wall_end])
	_check(bool(stand.call("within_reach", stand.global_position)),
		"an apo standing at it can reach it", "reach %.0f" % float(stand.get("reach")))
	# And it does not reach back down the hall to the picture beside it, the way a painting
	# must not reach the next painting.
	_check(not bool(stand.call("within_reach", Vector2(last_painting, 0.0))),
		"and it does not answer from the last painting",
		"%.0fpx away" % absf(stand.global_position.x - last_painting))

	_check(bool(stand.call("holds_brush")), "it holds the brush before anyone takes it",
		"under the glass")
	_check(not bool(manager.call("open_level", "level_1")),
		"and Payyo refuses until it is taken", "open_level said no")

	stand.call("take")
	await process_frame
	_check(bool(profile.call("has_brush")), "taking it is written to the profile",
		"brush_acquired")
	_check(not bool(stand.call("holds_brush")), "and the case is empty afterwards",
		"nothing left under the glass")
	_check(bool(manager.call("open_level", "level_1")), "and Payyo opens",
		"open_level started the transition")

	_restore_profile(profile, had_brush, had_profile)

	if failures == 0:
		print("OBRA_HUB_AUDIT_OK")
	else:
		print("OBRA_HUB_AUDIT_FAILED=%d" % failures)
	quit(1 if failures > 0 else 0)
