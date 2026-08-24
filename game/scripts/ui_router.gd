class_name UIRouter
extends Node
## The single owner of the cancel key, and of the tree's pause state.
##
## WHY THIS EXISTS. Four scripts used to read `ui_cancel` from _unhandled_input and
## rely on Godot's reverse-tree-order propagation to sort out who won. That order is
## a property of where nodes sit in a .tscn, so it silently encoded a priority nobody
## had written down -- and got it wrong: PauseMenu is the last child of GameLevel and
## PlacementController the sixth, so pressing Escape while placing an object opened
## the pause menu instead of cancelling the placement, and the cancel branch in
## placement_controller was unreachable code.
##
## Godot dispatches _input -> GUI -> _shortcut_input -> _unhandled_key_input ->
## _unhandled_input. Handling the key HERE, in _shortcut_input, means this router
## sees it before any _unhandled_input in the scene regardless of tree position. The
## priority then comes from `cancel_chain`, which is authored, visible in the
## inspector, and reviewable.
##
## Note that _shortcut_input only receives InputEventKey, InputEventShortcut and
## InputEventJoypadButton -- a synthetic InputEventAction will not reach it, which
## matters when testing.

## Nodes exposing `handle_cancel() -> bool`, most-modal first. Order decides only
## between handlers that are simultaneously WILLING: one that is not in a state to
## act returns false and the key falls through to the next.
@export var cancel_chain: Array[NodePath] = []


func _ready() -> void:
	# A paused router cannot receive input, and the whole point is to be reachable
	# while an overlay has the game frozen.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _shortcut_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	# The pixel wipe must not be interruptible: a scene change is already in flight
	# and opening a menu over it leaves the menu owned by a scene that is going away.
	var manager := get_node_or_null(^"/root/LevelManager")
	if manager != null and bool(manager.is_transitioning()):
		get_viewport().set_input_as_handled()
		return
	for path in cancel_chain:
		var handler := get_node_or_null(path)
		if handler == null or not handler.has_method(&"handle_cancel"):
			continue
		if bool(handler.call(&"handle_cancel")):
			get_viewport().set_input_as_handled()
			return


## Recompute the tree's pause state from whoever is currently open.
##
## This is the whole reason overlays never write `paused` themselves. Closing
## Settings on top of the pause menu would otherwise unpause the game and drop the
## player back into a level they are still looking at a menu over.
static func refresh_pause(tree: SceneTree) -> void:
	if tree == null:
		return
	var wants_pause := false
	for node in tree.get_nodes_in_group(ModalOverlay.GROUP):
		if node.has_method(&"is_open") and bool(node.call(&"is_open")):
			# Defaulted rather than read blind: `get` on a property the node does not have
			# returns null, and bool(null) is not a conversion in GDScript, it is a crash.
			# An overlay that joins the group without declaring the flag is a mistake, but
			# it should not take the pause state down with it.
			var declares: Variant = node.get(&"pauses_game")
			if declares == null or bool(declares):
				wants_pause = true
				break
	tree.paused = wants_pause
