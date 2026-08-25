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

	# And a painting answers from where the apo actually stands, which is on the floor a
	# long way below it -- measured as a straight line to the picture, none ever would.
	var room: Node2D = hub.get_node("Room")
	var standing := Vector2(room.call("painting_anchor", 0).x, room.call("ground_y"))
	var answered := 0
	for node in paintings:
		if bool(node.call("within_reach", standing)):
			answered += 1
	_check(answered == 1, "standing at one painting reaches that one",
		"%d painting(s) answer from the floor at Payyo" % answered)

	if failures == 0:
		print("OBRA_HUB_AUDIT_OK")
	else:
		print("OBRA_HUB_AUDIT_FAILED=%d" % failures)
	quit(1 if failures > 0 else 0)
