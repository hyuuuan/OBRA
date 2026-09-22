extends SceneTree
const Terrace = preload("res://scripts/terrace_segment_2d.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var left := Terrace.new()
	left.position = Vector2(2160, 240)
	left.segment_size = Vector2(360, 440)
	var right := Terrace.new()
	right.position = Vector2(2520, 240)
	right.segment_size = Vector2(60, 440)
	root.add_child(left)
	root.add_child(right)
	await process_frame
	var a := left.get_node("RetainingWall") as Polygon2D
	var b := right.get_node("RetainingWall") as Polygon2D
	assert(a.texture == b.texture and not a.texture is AtlasTexture,
		"Wall must use the standalone fill, not a grass-bordered atlas slice")
	var join_a := a.polygon.find(Vector2(360, 0))
	var join_b := b.polygon.find(Vector2.ZERO)
	assert(join_a >= 0 and join_b >= 0, "Joined edges must not be rounded")
	assert(a.uv[join_a].is_equal_approx(b.uv[join_b]),
		"UVs must meet across neighboring blocks")
	assert(a.vertex_colors[join_a] == b.vertex_colors[join_b], "Lighting must meet at the join")
	assert(not a.polygon.has(Vector2.ZERO), "Exposed left corner must be rounded")
	assert(not b.polygon.has(Vector2(60, 0)), "Exposed right corner must be rounded")
	for terrace in [left, right]:
		var collision := terrace.get_node("CollisionShape2D") as CollisionShape2D
		assert(collision.shape.size == terrace.segment_size)
		assert(collision.position == terrace.segment_size * 0.5)
		var top := terrace.get_node("TerraceTop") as Polygon2D
		assert(top.position == Vector2.ZERO)
		assert(top.texture.get_height() == 90, "Use the reference grass and earth lip")
		for point in top.polygon:
			assert(point.y <= 30.0, "Cap must remain one shallow course")
	var mud := Terrace.new()
	mud.surface_style = Terrace.SurfaceStyle.MUD
	root.add_child(mud)
	assert(not mud.has_node("TerraceTop"), "Paddy mud must not acquire a walkable grass cap")
	print("OBRA_TERRAIN_PROBE_OK")
	quit()
