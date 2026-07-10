extends Node2D

@export var debug_timing_logs: bool = false

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

var player: Node2D
var _equipped_utility: UtilityObject


func _ready() -> void:
	registry.load_manifest()
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

	backend_supervisor.set("debug_logs", debug_timing_logs)
	backend_supervisor.connect("backend_ready", Callable(self, "_on_backend_ready"))
	backend_supervisor.connect("backend_starting", Callable(self, "_on_backend_starting"))
	backend_supervisor.connect("backend_failed", Callable(self, "_on_backend_failed"))
	environment.call("set_target", spawn_point)
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
	draw_button.grab_focus()


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
	var role := String(entry.get("runtime_role", "active_ragdoll_morph"))
	if role == "utility":
		var item := DrawnItemData.from_prediction(entity_id, display_name, drawing, strokes, ink_cost, entry)
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
	var skin := new_player.get_node_or_null("DrawingSkin")
	if skin != null:
		skin.set("debug_timing_logs", debug_timing_logs)
	if drawing != null and new_player.has_method("apply_drawing"):
		new_player.call("apply_drawing", drawing, strokes)
	if not previous_state.is_empty() and new_player.has_method("apply_morph_state"):
		new_player.call("apply_morph_state", previous_state)

	var camera_target := new_player
	if new_player.has_method("get_physics_anchor"):
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
		item.ink_committed = true
		ink_manager.commit_attempt()
		status_label.text = "%s stored in slot %d — draw a morph to place it" % [item.display_name, stored_slot + 1]
		return
	if not placement_controller.begin_placement(item, player, -1):
		var slot := inventory_manager.add_item(item)
		if slot >= 0:
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


func _on_placement_confirmed(
	item: DrawnItemData,
	utility: UtilityObject,
	_source_slot: int
) -> void:
	if not item.ink_committed:
		ink_manager.commit_attempt()
		item.ink_committed = true
	_connect_utility(utility)
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


func _on_placement_changed(active: bool, valid: bool) -> void:
	if active:
		status_label.text = "Placement %s" % ("valid" if valid else "blocked or out of range")


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


func _use_equipped_utility() -> void:
	if _equipped_utility == null or not is_instance_valid(_equipped_utility):
		status_label.text = "No utility equipped"
		return
	_equipped_utility.use_utility(player)


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
