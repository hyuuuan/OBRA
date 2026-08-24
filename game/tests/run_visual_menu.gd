extends SceneTree
## The main menu and its level selector, photographed. Needs a real viewport:
##   godot --path game --script res://tests/run_visual_menu.gd
## Frames land in /tmp/obra_menu_*.png
##
## The menu is the only screen that still carries its own StyleBoxes and font sizes inline
## in the .tscn rather than taking them from the theme, so it is the one place a palette or
## type-scale change can silently fail to arrive. It is also the first thing anyone sees.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var menu := (load("res://ui/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await _wait(1.2)
	await _capture("00_title")

	menu.call("_show_selector")
	await _wait(1.4)
	await _capture("01_levels")

	print("OBRA_VISUAL_MENU_DONE")
	quit(0)


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/obra_menu_%s.png" % label)


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout
