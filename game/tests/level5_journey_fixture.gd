extends RefCounted
## Position-based integration probes enter the new phase explicitly. The crater probe itself
## uses real movement and never calls this helper to get through the opening.

static func prepare(level: Node, point: Vector2) -> void:
	if point.x >= 6000.0 and level.call("journey_phase") == "ascent":
		level.set("_phase", "memories")
		level.call("_set_journey_visible",true)
	elif point.x < 5000.0 and level.call("journey_phase") != "ascent":
		level.set("_phase", "ascent")
		level.call("_set_journey_visible",false)
	level.get("player").call("apply_morph_state",{"position":point,"linear_velocity":Vector2.ZERO})
	var camera: Camera2D = level.call("_world_camera")
	camera.call("snap_to_target")
	camera.force_update_scroll()
	if level.get("_journey").enabled: level.get("_journey").sync()

static func summit(level: Node) -> void:
	level.set("_phase","farewell")
	level.call("_set_journey_visible",true)
	prepare(level,level.call("_anchor","summit"))
