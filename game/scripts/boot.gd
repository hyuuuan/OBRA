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
## nothing imported. If ImportGuard is importing, it waits to be restarted; otherwise it puts
## up the loading screen, which loads the title screen behind it and then fades onto it.
## The loading screen is reached with load() at run time, never preload(): only once
## ImportGuard has said the cache is whole is it safe to load anything that is drawn.

const TITLE := "res://ui/main_menu.tscn"
const LOADING := "res://scripts/loading_screen.gd"


func _ready() -> void:
	var guard := get_node_or_null(^"/root/ImportGuard")
	if guard != null and guard.has_method("is_importing") and bool(guard.call("is_importing")):
		return
	var screen: Node = (load(LOADING) as GDScript).new()
	get_tree().root.add_child.call_deferred(screen)
	screen.call(&"begin", TITLE)
