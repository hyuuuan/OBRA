extends Node
## THE FIRST SCENE IS ONE THAT CAN ALWAYS LOAD.
##
## Kent: "i want it to be automatic". ImportGuard re-imports a stale cache and restarts the game,
## but it is an autoload, and autoloads only run once the first scene has loaded. On a fresh
## clone there is no cache at all, so the title screen -- all imported art and a theme with an
## imported font -- could not load, and Godot quit before ImportGuard ever ran: the one case
## where it was needed most was the one it could never reach.
##
## So the game opens on this: one node, no art, no class_name anywhere in it. It loads with
## nothing imported. If ImportGuard is importing, it waits to be restarted; otherwise it goes
## straight on to the title screen, a frame later.

const TITLE := "res://ui/main_menu.tscn"


func _ready() -> void:
	var guard := get_node_or_null(^"/root/ImportGuard")
	if guard != null and guard.has_method("is_importing") and bool(guard.call("is_importing")):
		return
	get_tree().call_deferred(&"change_scene_to_file", TITLE)
