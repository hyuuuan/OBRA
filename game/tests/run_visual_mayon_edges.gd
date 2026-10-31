extends SceneTree
## A short visual pass over Mayon's terrain joins; no backend or story traversal.
var level: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	level = load("res://level_5.tscn").instantiate()
	level.get_node("BackendSupervisor").auto_start_backend = false
	level.set("intro_enabled", false)
	root.add_child(level)
	level.call("_on_backend_ready")
	level.set("_forgot", 3)
	level.set("_corridor_seen", true)
	level.set("_lolo_moment", "visual")
	call_group(DialogueBox.GROUP, "set_auto_dismiss", true)
	await create_timer(.6).timeout
	var suffix := "after" if OS.get_cmdline_user_args().has("--after") else "before"
	for entry in [["meadow",Vector2(1320,550)],["ascent",Vector2(1760,470)],
		["gap",Vector2(2200,400)],["wall",Vector2(4070,300)],
		["memories",Vector2(5900,0)],["ash",Vector2(9520,-280)]]:
		level.get("player").call("apply_morph_state", {"position":entry[1],"linear_velocity":Vector2.ZERO})
		await create_timer(.65).timeout
		level.call("_world_camera").snap_to_target()
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		frame.resize(1600,900,Image.INTERPOLATE_NEAREST)
		frame.save_png("/tmp/obra_mayon_edges_"+entry[0]+"_"+suffix+".png")
	# Joins must whiten with their owning terrain at the summit, rather than stay coloured.
	level.call("_whiten", .55, 0.0)
	await RenderingServer.frame_post_draw
	var pale := root.get_texture().get_image()
	pale.resize(1600,900,Image.INTERPOLATE_NEAREST)
	pale.save_png("/tmp/obra_mayon_edges_pale_"+suffix+".png")
	pale = null
	call_group(DialogueBox.GROUP, "skip_all")
	level.queue_free()
	level = null
	for frame in range(4): await process_frame
	quit()
