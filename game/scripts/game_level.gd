extends Node2D

@export var debug_timing_logs: bool = false

## A morph whose anchor comes within this radius of the level's GoalMarker completes it.
const GOAL_RADIUS := 120.0

@onready var registry: EntityRegistry = $EntityRegistry
@onready var environment: Node = $EnvironmentBaseplate
@onready var spawn_point: Marker2D = $EnvironmentBaseplate/GameplayPlane/SpawnPoint
@onready var entity_root: Node2D = $EnvironmentBaseplate/GameplayPlane/EntityRoot
@onready var world_item_root: Node2D = $EnvironmentBaseplate/GameplayPlane/WorldItemRoot
@onready var backend_supervisor: Node = $BackendSupervisor
@onready var status_label: Label = $CanvasLayer/StatusLabel
@onready var draw_button: Button = $CanvasLayer/DrawButton
@onready var ink_bar: ProgressBar = $CanvasLayer/InkBar
@onready var ink_label: Label = $CanvasLayer/InkLabel
@onready var inventory_hud: InventoryHUD = $CanvasLayer/InventoryHUD
@onready var draw_panel: DrawPanel = $DrawPanel
@onready var ink_manager: InkManager = $InkManager
@onready var inventory_manager: InventoryManager = $InventoryManager
@onready var placement_controller: PlacementController = $PlacementController
@onready var goal_marker: Node2D = get_node_or_null("EnvironmentBaseplate/GameplayPlane/GoalMarker")
@onready var goal_label: Label = $CanvasLayer/GoalLabel
@onready var complete_overlay: ModalOverlay = $LevelCompleteOverlay
@onready var out_of_ink_overlay: ModalOverlay = $OutOfInkOverlay

var player: Node2D
var _equipped_utility: UtilityObject
var _level_completed := false
var _run_started_msec := 0
## entity_id -> true, for the "things drawn" stat. Distinct classes, not attempts.
var _classes_this_run: Dictionary = {}


func _ready() -> void:
	registry.load_manifest()
	Telemetry.begin_level(LevelManager.current_level_id)
	ink_manager.begin_level(12.0)
	inventory_manager.begin_level()
	placement_controller.registry = registry
	placement_controller.world_item_root = world_item_root
	draw_panel.ink_manager = ink_manager
	draw_panel.set("debug_timing_logs", debug_timing_logs)
	inventory_hud.set_manager(inventory_manager)

	draw_button.pressed.connect(_on_draw_button_pressed)
	draw_panel.drawing_ready.connect(_on_drawing_ready)
	draw_panel.panel_closed.connect(_on_draw_panel_closed)
	ink_manager.ink_changed.connect(_on_ink_changed)
	inventory_hud.slot_pressed.connect(_on_inventory_slot_pressed)
	placement_controller.placement_confirmed.connect(_on_placement_confirmed)
	placement_controller.placement_canceled.connect(_on_placement_canceled)
	placement_controller.placement_changed.connect(_on_placement_changed)
	placement_controller.placement_rejected.connect(_on_placement_rejected)
	complete_overlay.connect(&"continue_pressed", _on_complete_continue)
	complete_overlay.connect(&"retry_pressed", _on_restart_requested)
	out_of_ink_overlay.connect(&"restart_pressed", _on_restart_requested)
	out_of_ink_overlay.connect(&"level_select_pressed", LevelManager.return_to_selector)
	ink_manager.ink_exhausted.connect(_on_ink_exhausted)
	_run_started_msec = Time.get_ticks_msec()
	_apply_level_identity()
	_spawn_wanderer()

	backend_supervisor.set("debug_logs", debug_timing_logs)
	backend_supervisor.connect("backend_ready", Callable(self, "_on_backend_ready"))
	backend_supervisor.connect("backend_starting", Callable(self, "_on_backend_starting"))
	backend_supervisor.connect("backend_failed", Callable(self, "_on_backend_failed"))
	# camera target is set by _spawn_wanderer; the spawn marker is only a location
	draw_button.disabled = true
	status_label.text = "Checking backend..."
	_on_ink_changed(ink_manager.remaining(), ink_manager.capacity, ink_manager.reserved)
	backend_supervisor.call("ensure_backend")


func _unhandled_input(event: InputEvent) -> void:
	if placement_controller.is_placing():
		if event.is_action_pressed("redraw"):
			get_viewport().set_input_as_handled()
			placement_controller.cancel_placement()
			draw_panel.open_panel()
		return
	if event.is_action_pressed("redraw"):
		get_viewport().set_input_as_handled()
		draw_panel.open_panel()
		return
	for slot in range(6):
		if event.is_action_pressed("inventory_slot_%d" % (slot + 1)):
			get_viewport().set_input_as_handled()
			_on_inventory_slot_pressed(slot)
			return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_interact_with_nearest_utility()
	elif event.is_action_pressed("use_utility"):
		get_viewport().set_input_as_handled()
		_use_equipped_utility()


func _on_draw_button_pressed() -> void:
	if placement_controller.is_placing():
		placement_controller.cancel_placement()
	draw_panel.open_panel()


func _on_backend_ready() -> void:
	draw_button.disabled = false
	status_label.text = "Ready — draw a morph or utility"


func _on_backend_starting(message: String) -> void:
	draw_button.disabled = true
	status_label.text = message


func _on_backend_failed(message: String) -> void:
	draw_button.disabled = true
	status_label.text = message


func _on_draw_panel_closed() -> void:
	# Release focus rather than park it on the Draw button. The old branch here tried
	# to grab focus back and could never run -- the button is focus_mode = NONE in the
	# scene, deliberately, so it cannot eat the movement keys. Dropping focus is what
	# it was reaching for: keyboard input goes to the player again.
	get_viewport().gui_release_focus()


func _on_drawing_ready(
	entity_id: String,
	display_name: String,
	drawing: Image,
	_response: Dictionary,
	strokes: Array,
	ink_cost: float
) -> void:
	var entry := registry.get_entity(entity_id)
	if entry.is_empty():
		status_label.text = "Unknown recognized entity: %s" % entity_id
		ink_manager.release_attempt()
		return
	_classes_this_run[entity_id] = true
	var role := String(entry.get("runtime_role", "active_ragdoll_morph"))
	# A drawn shape is scenery the player positions, not a body they become. It used
	# to replace the player the instant it was recognised, which dropped them into a
	# circle wherever they happened to be standing; it takes the same placement path
	# as a utility now, so a ramp or a step lands where it was wanted.
	if role == "utility" or role == "physics_morph":
		var item := DrawnItemData.from_prediction(entity_id, display_name, drawing, strokes, ink_cost, entry)
		if PlayerProfile.has_object(entity_id):
			# Re-summoning an object the player already owns is free: refund the
			# reservation and mark the item settled so no later path charges it.
			ink_manager.release_attempt()
			item.ink_committed = true
		else:
			PlayerProfile.record_object_acquired(entity_id)
		_begin_new_utility(item)
		return
	if _spawn_or_replace(entity_id, display_name, drawing, strokes):
		ink_manager.commit_attempt()
	else:
		ink_manager.release_attempt()


func _spawn_or_replace(
	entity_id: String,
	display_name: String,
	drawing: Image,
	strokes: Array
) -> bool:
	var spawn_started := Time.get_ticks_usec()
	var previous_state: Dictionary = {}
	if player != null and is_instance_valid(player) and player.has_method("capture_morph_state"):
		previous_state = player.call("capture_morph_state")
	_drop_equipped_before_morph(previous_state)

	var new_player := registry.instantiate_entity(entity_id) as Node2D
	if new_player == null:
		status_label.text = "Spawn failed"
		return false
	entity_root.add_child(new_player)
	new_player.global_position = spawn_point.global_position
	if new_player.has_method("set_world_bounds"):
		new_player.call("set_world_bounds", Rect2(environment.get("world_bounds")))
	var skin := new_player.get_node_or_null("DrawingSkin")
	if skin != null:
		skin.set("debug_timing_logs", debug_timing_logs)
	if drawing != null and new_player.has_method("apply_drawing"):
		new_player.call("apply_drawing", drawing, strokes)
	if new_player.has_method("get_physics_anchor"):
		var built_anchor := new_player.call("get_physics_anchor") as Node2D
		if built_anchor == null or not is_finite(built_anchor.global_position.x) or not is_finite(built_anchor.global_position.y):
			status_label.text = "Rig build failed safely — previous morph kept"
			new_player.queue_free()
			return false
	if not previous_state.is_empty() and new_player.has_method("apply_morph_state"):
		new_player.call("apply_morph_state", previous_state)
	# The swap is otherwise a single frame -- one body gone, another in its place --
	# which reads as a glitch rather than as the transformation the game is about.
	MorphFlash.play(entity_root, new_player.global_position, new_player)

	var camera_target := new_player
	if new_player.has_method("get_camera_target"):
		var stable_target := new_player.call("get_camera_target") as Node2D
		if stable_target != null:
			camera_target = stable_target
	elif new_player.has_method("get_physics_anchor"):
		var anchor := new_player.call("get_physics_anchor") as Node2D
		if anchor != null:
			camera_target = anchor
	environment.call("set_target", camera_target)

	var old_player := player
	player = new_player
	if old_player != null and is_instance_valid(old_player):
		old_player.queue_free()

	var label := display_name if not display_name.is_empty() else entity_id.capitalize()
	if skin != null and skin.has_method("rig_summary"):
		label += " [%s | %d strokes]" % [skin.call("rig_summary"), strokes.size()]
	status_label.text = label
	if debug_timing_logs:
		print("Morph %s built in %.2f ms" % [entity_id, float(Time.get_ticks_usec() - spawn_started) / 1000.0])
	return true


func _begin_new_utility(item: DrawnItemData) -> void:
	if player == null or not is_instance_valid(player):
		var stored_slot := inventory_manager.add_item(item)
		if stored_slot == -1:
			status_label.text = "Draw an animal first; inventory is full"
			ink_manager.release_attempt()
			return
		if not item.ink_committed:
			item.ink_committed = true
			ink_manager.commit_attempt()
		status_label.text = "%s stored in slot %d — draw a morph to place it" % [item.display_name, stored_slot + 1]
		return
	if not placement_controller.begin_placement(item, player, -1):
		var slot := inventory_manager.add_item(item)
		if slot >= 0:
			if not item.ink_committed:
				item.ink_committed = true
				ink_manager.commit_attempt()
			status_label.text = "%s stored in slot %d" % [item.display_name, slot + 1]
		else:
			ink_manager.release_attempt()
			status_label.text = "Could not place or store %s" % item.display_name
	else:
		status_label.text = "Place %s: click confirm, right-click store" % item.display_name


func _on_inventory_slot_pressed(slot: int) -> void:
	if placement_controller.is_placing():
		return
	if player == null or not is_instance_valid(player):
		status_label.text = "Draw a morph before placing utilities"
		return
	var item := inventory_manager.take_item(slot)
	if item == null:
		return
	if not placement_controller.begin_placement(item, player, slot):
		inventory_manager.add_item(item, slot)
		status_label.text = "Could not start placement"


## Typed as the BASE for the same reason begin_placement is: a drawn circle is placed
## through this path too, and a UtilityObject parameter made the whole handler fail to
## bind -- the signal emitted, Godot refused the argument, and confirming a shape
## silently never committed its ink or said anything on screen.
func _on_placement_confirmed(
	item: DrawnItemData,
	placed: PhysicsShapeObject,
	_source_slot: int
) -> void:
	if not item.ink_committed:
		ink_manager.commit_attempt()
		item.ink_committed = true
	_connect_utility(placed as UtilityObject)
	status_label.text = "%s placed" % item.display_name


func _on_placement_canceled(item: DrawnItemData, source_slot: int) -> void:
	var slot := inventory_manager.add_item(item, source_slot)
	if slot >= 0:
		if not item.ink_committed:
			ink_manager.commit_attempt()
			item.ink_committed = true
		status_label.text = "%s stored in slot %d" % [item.display_name, slot + 1]
		return
	if not item.ink_committed:
		ink_manager.release_attempt()
	status_label.text = "Inventory full — %s discarded" % item.display_name


## The old line here read "Placement blocked or out of range" and said nothing about
## which, or what to do about it -- and because the controller re-emitted every frame,
## it was also the only thing the status line could ever say while placing.
func _on_placement_changed(active: bool, valid: bool) -> void:
	if not active:
		return
	if not valid:
		status_label.text = "No room there — aim at a clearer spot"
	elif placement_controller.is_at_reach_limit():
		status_label.text = "At arm's reach — click to place, right-click to store"
	else:
		status_label.text = "Click to place, right-click to store, scroll to rotate"


func _on_placement_rejected() -> void:
	status_label.text = "Can't build that into solid ground — move the cursor out first"


func _connect_utility(utility: UtilityObject) -> void:
	if utility == null:
		return
	if not utility.pickup_requested.is_connected(_on_utility_pickup_requested):
		utility.pickup_requested.connect(_on_utility_pickup_requested)
	if not utility.equipped.is_connected(_on_utility_equipped):
		utility.equipped.connect(_on_utility_equipped)
	if not utility.utility_used.is_connected(_on_utility_used):
		utility.utility_used.connect(_on_utility_used)
	if not utility.utility_consumed.is_connected(_on_utility_consumed):
		utility.utility_consumed.connect(_on_utility_consumed)


func _on_utility_pickup_requested(utility: UtilityObject) -> void:
	if utility == null or not is_instance_valid(utility):
		return
	if inventory_manager.is_full():
		status_label.text = "Inventory full"
		return
	var item := utility.prepare_for_inventory()
	var slot := inventory_manager.add_item(item)
	if slot == -1:
		status_label.text = "Inventory full"
		return
	if utility == _equipped_utility:
		_equipped_utility = null
	utility.queue_free()
	status_label.text = "%s stored in slot %d" % [item.display_name, slot + 1]


func _on_utility_equipped(utility: UtilityObject, _actor: Node2D) -> void:
	if _equipped_utility != null and is_instance_valid(_equipped_utility) and _equipped_utility != utility:
		var previous := _equipped_utility
		if inventory_manager.is_full():
			var drop_at := player.global_position
			if player.has_method("get_physics_anchor"):
				var anchor := player.call("get_physics_anchor") as Node2D
				if anchor != null:
					drop_at = anchor.global_position
			previous.drop_to_world(world_item_root, drop_at)
		else:
			_on_utility_pickup_requested(previous)
	_equipped_utility = utility
	status_label.text = "%s equipped — press F to use" % utility.item_data.display_name
	_show_carried(utility.item_data.entity_id)


func _on_utility_used(behavior: String, item: DrawnItemData) -> void:
	for requirement in get_tree().get_nodes_in_group("utility_requirements"):
		if requirement.has_method("report_utility_used"):
			requirement.call("report_utility_used", behavior, item)


func _on_utility_consumed(utility: UtilityObject) -> void:
	if utility == _equipped_utility:
		_equipped_utility = null
	utility.queue_free()
	status_label.text = "Key consumed"


func _interact_with_nearest_utility() -> void:
	if player == null or not is_instance_valid(player):
		return
	var origin := player.global_position
	if player.has_method("get_physics_anchor"):
		var anchor := player.call("get_physics_anchor") as Node2D
		if anchor != null:
			origin = anchor.global_position
	var nearest: UtilityObject
	var nearest_distance := 96.0
	for candidate in get_tree().get_nodes_in_group("drawn_utilities"):
		var utility := candidate as UtilityObject
		if utility == null or utility.is_preview:
			continue
		var distance := origin.distance_to(utility.global_position)
		if distance <= nearest_distance:
			nearest = utility
			nearest_distance = distance
	if nearest != null:
		_connect_utility(nearest)
		nearest.interact(player)


## F used to call through and ignore the answer, so for most utilities the key did
## nothing AND said nothing -- indistinguishable from a broken build. Every behavior
## now reports what it did, including when it could not act.
func _use_equipped_utility() -> void:
	if _equipped_utility == null or not is_instance_valid(_equipped_utility):
		status_label.text = "Nothing in hand — press E next to something you drew"
		return
	var outcome := _equipped_utility.describe_use(player)
	status_label.text = outcome if not outcome.is_empty() \
		else "%s can't do that here" % _equipped_utility.item_data.display_name


func _drop_equipped_before_morph(previous_state: Dictionary) -> void:
	if _equipped_utility == null or not is_instance_valid(_equipped_utility):
		_equipped_utility = null
		return
	var drop_position := Vector2(previous_state.get("position", spawn_point.global_position))
	_equipped_utility.drop_to_world(world_item_root, drop_position)
	_equipped_utility = null


func _on_ink_changed(remaining: float, capacity: float, reserved: float) -> void:
	ink_bar.max_value = 100.0
	ink_bar.value = remaining / maxf(0.001, capacity) * 100.0
	ink_label.text = "Ink %.1f / %.1f%s" % [
		remaining,
		capacity,
		" (%.1f reserved)" % reserved if reserved > 0.001 else ""
	]


func _physics_process(_delta: float) -> void:
	if _level_completed or goal_marker == null:
		return
	if player == null or not is_instance_valid(player):
		return
	var anchor_position := player.global_position
	if player.has_method("get_physics_anchor"):
		var anchor := player.call("get_physics_anchor") as Node2D
		if anchor != null:
			anchor_position = anchor.global_position
	var distance := anchor_position.distance_to(goal_marker.global_position)
	# The distance is already being computed to decide completion, so showing it costs
	# nothing and gives the level a legible objective -- until now the only thing
	# telling the player where to go was the level ending when they arrived.
	goal_label.text = "GOAL  %d m" % int(distance / 32.0) if distance > GOAL_RADIUS else "GOAL REACHED"
	if distance <= GOAL_RADIUS:
		_complete_level()


## Put the held item in the character's hand, and light the slot it came from, so what
## is equipped is visible on the character and in the HUD rather than only in a status
## line that the next message overwrites.
func _show_carried(entity_id: String) -> void:
	if player != null and is_instance_valid(player) and player.has_method("set_carried"):
		player.call("set_carried", entity_id)
	var slot := -1
	var items := inventory_manager.items()
	for index in range(items.size()):
		var item := items[index] as DrawnItemData
		if item != null and item.entity_id == entity_id:
			slot = index
			break
	inventory_hud.set_selected(slot)


## The player character, present from the first frame so the level is something to be
## walked around in before anything has been drawn. A recognised animal replaces it
## through the same path that replaces one morph with another -- the wanderer answers
## the same calls a drawn creature does, which is the whole reason the swap is uniform.
func _spawn_wanderer() -> void:
	var scene := load("res://creatures/wanderer.tscn") as PackedScene
	if scene == null:
		push_warning("GameLevel: no wanderer scene; the level starts empty")
		return
	var wanderer := scene.instantiate() as Node2D
	entity_root.add_child(wanderer)
	wanderer.global_position = spawn_point.global_position
	wanderer.call("set_world_bounds", Rect2(environment.get("world_bounds")))
	player = wanderer
	environment.call("set_target", wanderer)


## Name the level from the catalog instead of from strings typed into the scene. The
## badge and the pause menu's subtitle both said "BANAUE RICE TERRACES" literally, so
## a second level would have shipped mislabelled.
func _apply_level_identity() -> void:
	var entry := LevelManager.get_level(LevelManager.current_level_id)
	if entry.is_empty():
		return
	var badge := get_node_or_null(^"CanvasLayer/LevelBadge") as Label
	if badge != null:
		badge.text = "LEVEL %d  \u00b7  %s" % [int(entry.get("number", 0)), String(entry.get("title", "")).to_upper()]
	var place := get_node_or_null(^"PauseMenu/PauseRoot/Panel/VBox/Place") as Label
	if place != null:
		place.text = String(entry.get("title", "")).to_upper()


## What the completion screen shows. Ink comes from the manager rather than being
## tracked again here, so there is one number and it cannot drift.
func run_stats() -> Dictionary:
	var level_id := LevelManager.current_level_id
	return {
		"level_id": level_id,
		"level_title": String(LevelManager.get_level(level_id).get("title", "")),
		"ink_used": ink_manager.committed,
		"ink_capacity": ink_manager.capacity,
		"classes_drawn": _classes_this_run.size(),
		"elapsed_seconds": float(Time.get_ticks_msec() - _run_started_msec) / 1000.0,
	}


func _complete_level() -> void:
	if _level_completed:
		return
	_level_completed = true
	var level_id := LevelManager.current_level_id
	Telemetry.end_level(level_id, "completed")
	PlayerProfile.mark_level_completed(level_id)
	status_label.text = "Level complete!"
	# The transition used to fire HERE, on the same frame, so the one moment the game
	# acknowledges the player lasted a frame and was never read. It now waits for them.
	complete_overlay.call("present", run_stats())


## Whether the run ends with this level, or the level select comes next. The branch
## lives here rather than in the overlay so the overlay stays a view, and it is read
## from the catalog so that when levels 2-5 exist only level 5 carries the flag.
func _on_complete_continue() -> void:
	var ends_run := bool(LevelManager.get_level(LevelManager.current_level_id).get("ends_run", false))
	if ends_run and LevelManager.show_ending():
		return
	LevelManager.return_to_selector()


func _on_restart_requested() -> void:
	Telemetry.end_level(LevelManager.current_level_id, "restarted")
	LevelManager.restart_level()


func _on_ink_exhausted() -> void:
	# Advisory, not a loss: the morph already spawned is still playable and the goal
	# may still be reachable. Not shown once the level is already won.
	if not _level_completed:
		out_of_ink_overlay.open()
