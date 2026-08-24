extends Node2D

@export var debug_timing_logs: bool = false

## A morph whose anchor comes within this radius of the level's GoalMarker completes it.
const GOAL_RADIUS := 120.0
## What the box's plaque says when the line is the player's own thought rather than Lolo's
## voice. "Apo" is what Lolo calls them, so it is the name the player already knows.
const APO_SPEAKER := "Apo"

## The body the player starts in and can always get back to.
const WANDERER_SCENE := "res://creatures/wanderer.tscn"

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
@onready var level_badge: Label = $CanvasLayer/LevelBadge
## Built in code rather than authored into the scene, like the requirement strip: it owns
## its own frame and gauge and there is nothing to lay out by hand.
var hud_panel: HudPanel
## The framed box every story line is shown in. Built here rather than authored into the
## scene because it is pure presentation with no state to save and nothing to wire.
var dialogue_box: DialogueBox
## The corner readouts and where each belongs, so they can be re-placed together.
var _chips: Array = []
## How long the player has been under the water in their own body.
var _submerged_seconds := 0.0
@onready var complete_overlay: ModalOverlay = $LevelCompleteOverlay
@onready var out_of_ink_overlay: ModalOverlay = $OutOfInkOverlay
@onready var dialogue_overlay: ModalOverlay = $DialogueChoiceOverlay
@onready var memory_overlay: ModalOverlay = $MemoryOverlay
@onready var dialogue_node: DialogueNode2D = get_node_or_null(
	^"EnvironmentBaseplate/GameplayPlane/Gorge/DialogueNode")
@onready var route_layout: RouteLayout2D = get_node_or_null(
	^"EnvironmentBaseplate/GameplayPlane/Routes")
@onready var cave_gate: ConceptGate2D = get_node_or_null(
	^"EnvironmentBaseplate/GameplayPlane/Gorge/CaveGate")
@onready var hidden_flower: HiddenFlower2D = get_node_or_null(
	^"EnvironmentBaseplate/GameplayPlane/Gorge/HiddenFlower")

var player: Node2D
var lolo: Lolo
## Lolo's lines for this level, from config/dialogue.json.
var _script_lines: Dictionary = {}
var _memory_shown := false
var _equipped_utility: UtilityObject
var _level_completed := false
## What the player is currently wearing, so changing back can name what it cost them
## and say in the telemetry which class was abandoned.
var _current_form_name := ""
var _current_form_id := ""
## Payyo's obstacle layer. The director decides what an obstacle accepts, the checkpoints
## decide what a death costs, and the script decides what Lolo says about either.
var director: LevelDirector
var checkpoints: CheckpointManager
var script_lines_l1: DialogueScript
var requirement_strip: RequirementStrip
## The refusal beat fires on the FIRST decline anywhere in the level, then never again.
var _refusal_spoken := false
var _run_started_msec := 0
## entity_id -> true, for the "things drawn" stat. Distinct classes, not attempts.
var _classes_this_run: Dictionary = {}


func _ready() -> void:
	registry.load_manifest()
	# Running this scene directly -- from the editor, or from a test -- never goes
	# through LevelManager.open_level, so nothing has said which level this is. The
	# level badge, the dialogue and the telemetry all read it, so resolving it once
	# here is what stops a direct run being an anonymous, silent, unlabelled level.
	if LevelManager.current_level_id.is_empty():
		var catalog := LevelManager.get_levels()
		if not catalog.is_empty():
			LevelManager.current_level_id = String(catalog[0].get("id", ""))
	Telemetry.begin_level(LevelManager.current_level_id)
	ink_manager.begin_level(12.0)
	inventory_manager.begin_level()
	placement_controller.registry = registry
	placement_controller.world_item_root = world_item_root
	draw_panel.ink_manager = ink_manager
	draw_panel.set("debug_timing_logs", debug_timing_logs)
	inventory_hud.set_manager(inventory_manager)
	_build_hud_frame()

	draw_button.pressed.connect(_on_draw_button_pressed)
	draw_panel.drawing_ready.connect(_on_drawing_ready)
	draw_panel.panel_closed.connect(_on_draw_panel_closed)
	draw_panel.recognition_declined.connect(_on_recognition_declined)
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
	_build_obstacle_layer()
	_spawn_wanderer()
	_load_dialogue()
	_spawn_lolo()
	_wire_dialogue_node()

	backend_supervisor.set("debug_logs", debug_timing_logs)
	backend_supervisor.connect("backend_ready", Callable(self, "_on_backend_ready"))
	backend_supervisor.connect("backend_starting", Callable(self, "_on_backend_starting"))
	backend_supervisor.connect("backend_failed", Callable(self, "_on_backend_failed"))
	# camera target is set by _spawn_wanderer; the spawn marker is only a location
	# The Draw button is NOT gated on the backend. It used to start disabled and be
	# enabled only by `backend_ready`, so a backend that was slow, absent or wedged left
	# it grey for the rest of the session with nothing watching to re-enable it -- while
	# R opened the same panel regardless. Two doors into one room, one of them locked.
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
		if director != null:
			director.note_canvas_opened()
		draw_panel.open_panel()
		return
	for slot in range(6):
		if event.is_action_pressed("inventory_slot_%d" % (slot + 1)):
			get_viewport().set_input_as_handled()
			_on_inventory_slot_pressed(slot)
			return
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_RIGHT and click.pressed:
		get_viewport().set_input_as_handled()
		# The CLICK's own position, not the live cursor. They are the same thing in play and
		# they are not the same thing anywhere else: the cursor is wherever the pointer is
		# right now, while the event carries where the button actually went down. Reading the
		# cursor made the right-click untestable -- a synthesised event asks about a spot the
		# real pointer was never at -- and it is the event that is authoritative regardless.
		_take_back_under_cursor(
			get_viewport().get_canvas_transform().affine_inverse() * click.position)
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_interact_with_nearest_utility()
	elif event.is_action_pressed("use_utility"):
		get_viewport().set_input_as_handled()
		_use_equipped_utility()
	elif event.is_action_pressed("revert_form"):
		get_viewport().set_input_as_handled()
		_revert_to_base_form()


func _on_draw_button_pressed() -> void:
	if placement_controller.is_placing():
		placement_controller.cancel_placement()
	if director != null:
		director.note_canvas_opened()
	draw_panel.open_panel()


func _on_backend_ready() -> void:
	status_label.text = "Ready — draw a morph or utility"


func _on_backend_starting(message: String) -> void:
	status_label.text = message


## Reported, not enforced. The panel says the same thing where the player is actually
## looking when it matters (draw_panel says "backend unreachable" under the canvas), and
## shutting the door to the panel does not make the backend arrive any sooner -- it only
## removes the one screen that explains what is wrong.
func _on_backend_failed(message: String) -> void:
	status_label.text = message


## Payyo's obstacle layer, built in code rather than authored into game_level.tscn. The
## director and the checkpoints have no scene presence worth authoring, and the strip's
## whole content is dynamic -- generating scene files by hand is also the single trap that
## has bitten this project most often.
func _build_obstacle_layer() -> void:
	director = LevelDirector.new()
	director.name = "LevelDirector"
	add_child(director)
	if not director.load_level():
		push_warning("GameLevel: no level data; obstacles will accept nothing")

	checkpoints = CheckpointManager.new()
	checkpoints.name = "CheckpointManager"
	add_child(checkpoints)

	script_lines_l1 = DialogueScript.new()
	script_lines_l1.load_from("res://config/dialogue_l1.json")

	requirement_strip = RequirementStrip.new()
	requirement_strip.name = "RequirementStrip"
	# Clear of the keybind strip, which sits at -108 and was being covered by this at
	# -164: the panel grows DOWNWARD from its top offset, so a two-line requirement ran
	# straight over "ESC MENU". -220 leaves room for the tallest state (tag line, own
	# classes, and the T3 note) with the keybind row still readable underneath.
	requirement_strip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	requirement_strip.offset_left = 24.0
	requirement_strip.offset_top = -220.0
	requirement_strip.offset_right = 760.0
	requirement_strip.offset_bottom = -140.0
	requirement_strip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	$CanvasLayer.add_child(requirement_strip)

	director.obstacle_entered.connect(_on_obstacle_entered)
	director.obstacle_exited.connect(_on_obstacle_exited)
	director.requirements_changed.connect(_on_requirements_changed)
	director.hint_tier_changed.connect(_on_hint_tier_changed)
	director.route_committed.connect(_on_obstacle_route_committed)
	director.obstacle_solved.connect(_on_obstacle_solved)

	# Checkpoints you walk into, for the beats with no dialogue to hang one on.
	for node in get_tree().get_nodes_in_group(&"checkpoint_areas"):
		var area := node as CheckpointArea2D
		if area == null:
			continue
		if not _checkpoint_is_declared(area.checkpoint_id):
			push_error("GameLevel: checkpoint area '%s' is not in level_01.json"
				% area.checkpoint_id)
			continue
		area.reached.connect(_on_checkpoint_area_reached)

	_wire_the_bulul()

	for node in get_tree().get_nodes_in_group(&"level_obstacles"):
		var area := node as LevelObstacle2D
		if area == null:
			continue
		# An obstacle volume whose id is not in the data is a dead trigger: the player
		# walks through it and nothing ever asks them for anything. Loud, not silent.
		if director.obstacle(area.obstacle_id).is_empty():
			push_error("GameLevel: obstacle volume '%s' has no entry in level_01.json"
				% area.obstacle_id)
			continue
		area.player_entered.connect(director.enter_obstacle)
		area.player_exited.connect(director.exit_obstacle)


func _checkpoint_is_declared(checkpoint_id: String) -> bool:
	if checkpoint_id.is_empty() or director == null:
		return false
	for entry_value: Variant in (director.level_data().get("checkpoints", []) as Array):
		if String((entry_value as Dictionary).get("id", "")) == checkpoint_id:
			return true
	return false


func _on_checkpoint_area_reached(checkpoint_id: String) -> void:
	_write_checkpoint(checkpoint_id)
	status_label.text = "Checkpoint"


func _on_obstacle_entered(obstacle_id: String) -> void:
	_speak(script_lines_l1.fire("%s.enter" % obstacle_id))
	# A node teaches all three of its routes' verbs BEFORE the choice, because a player
	# cannot choose a path whose verb they have never been told.
	var teaches: Array = director.obstacle(obstacle_id).get("teaches_before_choice", [])
	if not teaches.is_empty():
		_speak(script_lines_l1.fire("%s.teach" % obstacle_id))
		director.teach_before_choice(obstacle_id)
	_speak_current_stage(obstacle_id)
	_refresh_requirements()


## Lolo asking for the thing this sub-beat needs -- "gumuhit ka ng kayang span".
##
## These lines existed in the script from the start and nothing fired them, so Beat 0's
## actual instructions were dead: the tutorial asked for nothing out loud and the only
## thing naming the requirement was the strip, which does not appear until T1. A player
## who walks in and waits was told nothing at all for thirty seconds.
func _speak_current_stage(obstacle_id: String) -> void:
	var stage := director.stage_id(obstacle_id)
	if stage.is_empty():
		return
	_speak(script_lines_l1.fire("%s.%s" % [obstacle_id, stage]))


func _on_obstacle_exited(_obstacle_id: String) -> void:
	if requirement_strip != null:
		requirement_strip.clear()


func _on_requirements_changed(_obstacle_id: String, _required: Array) -> void:
	_refresh_requirements()


func _on_hint_tier_changed(obstacle_id: String, tier: int) -> void:
	_refresh_requirements()
	Telemetry.record_event("hint_tier_changed", {
		"level_id": LevelManager.current_level_id,
		"obstacle_id": obstacle_id, "tier": tier,
	})


func _refresh_requirements() -> void:
	if requirement_strip == null or director == null:
		return
	var obstacle_id := director.current_obstacle()
	if obstacle_id.is_empty() or director.is_solved(obstacle_id):
		requirement_strip.clear()
		return
	var spec := director.requirement_spec()
	var owned := AbilityTags.known_solutions(
		spec.get("required_tags", []),
		String(spec.get("match", "all")),
		spec.get("exclude", []))
	requirement_strip.show_requirements(director.required_tags(), director.hint_tier(), owned)


## The checkpoint is written HERE, on the commit, not on the solve -- so that every morph
## on the route is protected and a death cannot make the player answer Lolo twice.
func _on_obstacle_route_committed(obstacle_id: String, route: String) -> void:
	_speak(script_lines_l1.fire("%s.%s.commit" % [obstacle_id, route]))
	var checkpoint_id := String(director.obstacle(obstacle_id).get("checkpoint_on_commit", ""))
	if not checkpoint_id.is_empty():
		_write_checkpoint(checkpoint_id)


func _on_obstacle_solved(obstacle_id: String, route: String, label: String, attempt_count: int, tier: int) -> void:
	if obstacle_id == "L1_N2":
		_search_the_straw(route)
	elif obstacle_id == "L1_N3":
		_open_the_baul(route)
	else:
		_speak(script_lines_l1.fire("%s.%s.solved" % [obstacle_id, route]))
	_refresh_requirements()
	Telemetry.record_event("obstacle_solved", {
		"level_id": LevelManager.current_level_id,
		"obstacle_id": obstacle_id, "route": route, "accepted_label": label,
		"attempts": attempt_count, "hint_tier": tier,
		"assisted": director.was_assisted(obstacle_id),
	})


## Offer what just entered the world to whatever obstacle the player is standing in.
##
## Silent when there is no obstacle, which is most of the level: drawing a frog in an
## empty paddy is a thing the player is allowed to do for its own sake, and answering it
## with "that is not what this needs" would turn the whole level into a quiz.
func _judge_submission(entity_id: String) -> void:
	if director == null or director.current_obstacle().is_empty():
		return
	var verdict := director.note_submission(entity_id)
	# The strip re-reads the director either way: a solve moves it to the next stage, and
	# a miss may have opened the next hint tier.
	_refresh_requirements()
	if bool(verdict["solves"]) and not String(verdict["stage_id"]).is_empty():
		# Beat 0's sub-beats have their own lines ("B0_HAGDAN.sub1.solved"); a route's
		# second stage does not, and reports an empty stage id rather than a missing hook.
		_speak(script_lines_l1.fire("%s.%s.solved" % [
			verdict["obstacle_id"], verdict["stage_id"]]))
	if bool(verdict["stage_advanced"]):
		# The next sub-beat has to ask for itself, or the second half of the tutorial is
		# silent and the player is left guessing what changed.
		_speak_current_stage(String(verdict["obstacle_id"]))


## Ang Dayami: three ways to find the same chest, and they are not the same.
##
## The route decides what happens to the straw AND what the player walks away knowing. That
## second part is the one that matters later: combing turns up her sketchbook page, which is
## the only place in the level anyone is told to look for something on a nail. A player who
## took the fast route reaches Node 3 without that, and searches longer for it.
func _search_the_straw(route: String) -> void:
	var piles: Array[StrawPile2D] = []
	for node in get_tree().get_nodes_in_group(&"straw_piles"):
		var pile := node as StrawPile2D
		if pile != null:
			piles.append(pile)

	match route:
		"artist":
			for pile in piles:
				pile.comb()
			await _comb_the_piles()
		"pragmatist":
			for pile in piles:
				pile.tunnel()
			_speak(script_lines_l1.fire("L1_N2.pragmatist.solved"))
		"protector":
			for pile in piles:
				pile.scatter()
			# The cost, recorded rather than described: Lolo says nothing about it here and
			# mentions it at the marker stone, and the exit line is gated on this flag.
			script_lines_l1.set_flag("straw_scattered")
			Telemetry.record_event("persistent_effect", {
				"level_id": LevelManager.current_level_id,
				"obstacle_id": "L1_N2", "effect": "straw_scattered",
			})
			_speak(script_lines_l1.fire("L1_N2.protector.solved"))
	_uncover_the_baul()


## Three passes, and the middle two are the reward. Slowest route, and the only one that
## surfaces anything besides the chest.
func _comb_the_piles() -> void:
	await get_tree().create_timer(0.7).timeout
	_speak(script_lines_l1.fire("L1_N2.artist.pass2"))
	await get_tree().create_timer(1.4).timeout
	_speak(script_lines_l1.fire("L1_N2.artist.pass3"))
	# What the page is FOR. Node 3's Artist route reads this flag, so the patient player
	# arrives already knowing where to look.
	script_lines_l1.set_flag("knows_about_key")
	Telemetry.record_event("route_reward", {
		"level_id": LevelManager.current_level_id,
		"obstacle_id": "L1_N2", "reward": "sketchbook_page", "sets_flag": "knows_about_key",
	})


func _uncover_the_baul() -> void:
	for node in get_tree().get_nodes_in_group(&"baul"):
		var chest := node as Baul2D
		if chest != null:
			chest.reveal()
	_speak(script_lines_l1.fire("L1_N2.solved"))


## Ang Bale: three ways into the same chest, and the third one costs something.
func _open_the_baul(route: String) -> void:
	match route:
		"artist":
			await _into_the_attic()
		"pragmatist":
			# The ward sequence runs on its own, driven by the drawn key rather than by
			# the solve -- see _on_key_offered. Getting here means the lock is open.
			_speak(script_lines_l1.fire("L1_N3.ward.solved"))
		"protector":
			# THE ONE COST THAT LEAVES THIS LEVEL. Cutting the hasp creases what is inside,
			# and the player finds out in Pista rather than here: the seam runs through the
			# painted street and Hidden Flower 2 sits on the damaged side of it.
			script_lines_l1.set_flag("canvas_2_creased")
			PlayerProfile.record_canvas_damage("canvas_2_pista")
			Telemetry.record_event("persistent_effect", {
				"level_id": LevelManager.current_level_id,
				"obstacle_id": "L1_N3", "effect": "canvas_2_creased",
				"cross_level_effect": "L2_PISTA.hidden_flower_2.unreachable",
			})
			_speak(script_lines_l1.fire("L1_N3.protector.solved"))
	_grant_the_canvas()


## Over the thatch and in under the eaves. The halipan are what make this the way in rather
## than the posts, and the attic is where she left the key.
##
## A player who combed the straw at Node 2 already knows to look on a nail; one who did not
## is searching a dark granary for something nobody mentioned. Same room, different length.
func _into_the_attic() -> void:
	_speak(script_lines_l1.fire("L1_N3.artist.attic"))
	var search := 1.6
	if script_lines_l1.is_flag_set("knows_about_key"):
		search *= float(director.obstacle("L1_N3")
			.get("routes", {})
			.get("artist", {})
			.get("search_time_modifier_if_flag", {})
			.get("knows_about_key", 1.0))
	await get_tree().create_timer(search).timeout
	_speak(script_lines_l1.fire("L1_N3.attic.found"))
	await get_tree().create_timer(1.2).timeout
	_speak(script_lines_l1.fire("L1_N3.artist.photo"))
	Telemetry.record_event("route_reward", {
		"level_id": LevelManager.current_level_id,
		"obstacle_id": "L1_N3", "reward": "photograph_unnamed_woman",
		"knew_about_key": script_lines_l1.is_flag_set("knows_about_key"),
		"search_seconds": search,
	})


## What the chest held, and the reason Pista opens. The unlock happens at CP3 rather than
## at the marker stone, so a player who stops after this keeps the progress.
func _grant_the_canvas() -> void:
	PlayerProfile.record_object_acquired("canvas_2_pista")
	PlayerProfile.mark_level_completed(LevelManager.current_level_id)
	Telemetry.record_event("item_granted", {
		"level_id": LevelManager.current_level_id, "item": "canvas_2_pista",
	})


## The bulul, and the only thing they do. A refusal, not a hint: nothing unlocks, nothing
## is recorded as progress, and Lolo says it once.
func _wire_the_bulul() -> void:
	for node in get_tree().get_nodes_in_group(&"bulul"):
		var figure := node as Bulul2D
		if figure != null:
			figure.approached.connect(func() -> void:
				_speak(script_lines_l1.fire("L1_N3.bulul_approach")))


func _write_checkpoint(checkpoint_id: String) -> void:
	var anchor_position := spawn_point.global_position
	if player != null and is_instance_valid(player) and player.has_method("capture_morph_state"):
		anchor_position = Vector2((player.call("capture_morph_state") as Dictionary).get(
			"position", anchor_position))
	checkpoints.write(checkpoint_id, {
		"position": anchor_position,
		"ink_committed": ink_manager.committed,
		"toolbelt": PlayerProfile.acquired_objects(),
		"obstacles": director.obstacle_state(),
		"placed": _placed_entity_records(),
	})
	Telemetry.record_event("checkpoint_written", {
		"level_id": LevelManager.current_level_id, "checkpoint_id": checkpoint_id,
	})


## Placed props, as data rather than as nodes: a checkpoint outlives the bodies it
## describes, so storing references would restore a world full of freed objects.
func _placed_entity_records() -> Array:
	var records: Array = []
	for child in world_item_root.get_children():
		var prop := child as PhysicsShapeObject
		if prop == null or prop.is_preview or prop.item_data == null:
			continue
		records.append({
			"entity_id": prop.item_data.entity_id,
			"instance_id": prop.get_instance_id(),
			"transform": prop.global_transform,
		})
	return records


## How far below the world the player may fall before the level takes them back.
const FALL_LIMIT_MARGIN := 160.0

## Put the player back at the last checkpoint.
##
## Beat 0 has no fail state and neither does anything else in Payyo -- this is not a death,
## it is the level declining to let a fall be the end of ten minutes. What comes back is
## what the spec asks for: where they were, the ink they had, the obstacles they had
## already answered, and the props that existed at the time.
##
## PROPS ARE RE-HOMED, NOT REBUILT. A snapshot cannot carry a drawing -- the strokes and the
## image belong to the entity, not to the record -- so anything freed and re-instantiated
## would come back blank. Instead the props that existed at checkpoint time are moved back
## to where they were, and anything placed SINCE is removed, which is the part a restore
## actually has to undo.
func _restore_checkpoint() -> String:
	if checkpoints == null or not checkpoints.has_checkpoint():
		return ""
	var state := checkpoints.restore()
	if state.is_empty():
		return ""

	if director != null and state.has("obstacles"):
		director.restore_obstacle_state(state["obstacles"])

	# Ink is level-scoped and lives in committed, so restoring it is a subtraction rather
	# than a refill: anything spent since the checkpoint is given back.
	if state.has("ink_committed"):
		ink_manager.committed = minf(ink_manager.capacity, float(state["ink_committed"]))
		ink_manager.reserved = 0.0
		_on_ink_changed(ink_manager.remaining(), ink_manager.capacity, ink_manager.reserved)

	_restore_placed_entities(state.get("placed", []))

	var landing := Vector2(state.get("position", spawn_point.global_position))
	if player != null and is_instance_valid(player) and player.has_method("apply_morph_state"):
		player.call("apply_morph_state", {"position": landing, "linear_velocity": Vector2.ZERO})
	elif player != null and is_instance_valid(player):
		player.global_position = landing

	_refresh_requirements()
	var checkpoint_id := checkpoints.latest_id()
	Telemetry.record_event("checkpoint_restored", {
		"level_id": LevelManager.current_level_id,
		"checkpoint_id": checkpoint_id,
		"restores_here": checkpoints.restore_count(checkpoint_id),
	})
	return checkpoint_id


func _restore_placed_entities(records: Array) -> void:
	var kept: Dictionary = {}
	for record_value: Variant in records:
		var record: Dictionary = record_value
		kept[int(record.get("instance_id", 0))] = record
	for child in world_item_root.get_children():
		var prop := child as PhysicsShapeObject
		if prop == null or prop.is_preview:
			continue
		var id := prop.get_instance_id()
		if kept.has(id):
			prop.global_transform = Transform2D((kept[id] as Dictionary)["transform"])
			if prop is RigidBody2D:
				(prop as RigidBody2D).linear_velocity = Vector2.ZERO
				(prop as RigidBody2D).angular_velocity = 0.0
		else:
			# Placed after the checkpoint, so it did not exist at the moment being
			# restored to. The ink that paid for it comes back with the ink line above.
			prop.queue_free()


## Payyo's lines, routed by who is saying them.
##
## The visual pass caught this: everything went to the status label, so Lolo's own voice
## appeared as a caption at the top of the screen while his speech bubble carried an
## unrelated line from the old dialogue file. Two narrators, disagreeing, in the level
## whose job is to teach the game.
##
## BOTH VOICES NOW GO TO THE SAME BOX, and the plaque on it says which one is talking.
## Splitting them was the old fix for the same problem -- Lolo in a bubble over his head,
## the apo as a caption at the top of the screen -- and it worked by keeping them so far
## apart that nobody could confuse them. That is not a presentation, it is an evasion, and
## it cost the apo's lines any weight at all: the player's own thoughts appeared in the
## same grey line that says "Not enough ink".
##
## The status label keeps what it should have kept all along: the game talking about
## itself. Story is story, and story is framed.
func _speak(lines: Array) -> void:
	for line_value: Variant in lines:
		var line: Dictionary = line_value
		var text := script_lines_l1.display_text(line)
		if text.is_empty():
			continue
		if String(line.get("speaker", "lolo")) == "lolo" and lolo != null and is_instance_valid(lolo):
			lolo.say(text)
		elif dialogue_box != null:
			dialogue_box.show_line(text, APO_SPEAKER)
		else:
			status_label.text = text


## The refusal beat. It fires on the FIRST decline anywhere in the level and never again,
## and it is scripted as dialogue rather than as a rejection: the model is not rigged to
## fail, and the player is not being told they drew badly. No ink is spent -- the panel
## already released it before this runs.
func _on_recognition_declined(_entity: String, _confidence: float, _margin: float, reason: String) -> void:
	if director != null:
		director.note_decline(reason)
	if _refusal_spoken:
		return
	var lines := script_lines_l1.fire("on_first_decline")
	if lines.is_empty():
		return
	_refusal_spoken = true
	_speak(lines)


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
	_adopt_player(new_player, previous_state, true)

	var label := display_name if not display_name.is_empty() else entity_id.capitalize()
	# The bare name, before the rig summary is appended: it is what Q reports losing.
	_current_form_name = label
	_current_form_id = entity_id
	if skin != null and skin.has_method("rig_summary"):
		label += " [%s | %d strokes]" % [skin.call("rig_summary"), strokes.size()]
	status_label.text = label
	if debug_timing_logs:
		print("Morph %s built in %.2f ms" % [entity_id, float(Time.get_ticks_usec() - spawn_started) / 1000.0])
	_judge_submission(entity_id)
	return true


## Drawing something is making it, not using it. A recognised object goes into the bag
## and stays there until the player asks for it.
##
## It used to shove the player straight into a placement the moment the recogniser
## answered: the panel closed, and they were already holding a live preview stuck to
## the cursor that they had not asked for and could not put down without either
## placing it or right-clicking. Deciding WHAT to draw and deciding WHERE it goes are
## two separate thoughts, and the game was making the second one for them.
func _begin_new_utility(item: DrawnItemData) -> void:
	var slot := inventory_manager.add_item(item)
	if slot == -1:
		ink_manager.release_attempt()
		status_label.text = "Inventory full — no room for %s" % item.display_name
		return
	if not item.ink_committed:
		item.ink_committed = true
		ink_manager.commit_attempt()
	inventory_hud.set_selected(slot)
	status_label.text = "%s drawn — press %d to place it" % [item.display_name, slot + 1]


## What a slot does depends on what is in it, because the two kinds of drawn object are
## used in genuinely different ways: a ladder or a bridge is something you SET DOWN and
## then use where it stands, and an axe is something you HOLD.
##
## Everything used to go down the placement path, so using an axe meant standing it up
## in the world, walking to it, pressing E to pick the same axe back up, and only then
## swinging it. A tool now goes straight from the bag into the hand.
func _on_inventory_slot_pressed(slot: int) -> void:
	if placement_controller.is_placing():
		return
	if player == null or not is_instance_valid(player):
		status_label.text = "Nothing to hold it with yet"
		return
	var item := inventory_manager.peek_item(slot)
	if item == null:
		status_label.text = "Slot %d is empty — press R to draw something" % (slot + 1)
		return
	if _is_held_tool(item):
		_equip_from_slot(slot, item)
		return
	item = inventory_manager.take_item(slot)
	if not placement_controller.begin_placement(item, player, slot):
		inventory_manager.add_item(item, slot)
		status_label.text = "Could not start placement"
		return
	inventory_hud.set_selected(slot)
	status_label.text = "Placing %s — click to set it down, right-click to put it back" % item.display_name


func _is_held_tool(item: DrawnItemData) -> bool:
	var entry := registry.get_entity(item.entity_id)
	return String(entry.get("utility_behavior", "")) in UtilityObject.HELD_TOOLS


## Puts a tool in the player's hand without it ever touching the ground, and WITHOUT
## taking it out of the bag -- it is still yours, the slot still shows it, and pressing
## the slot again puts it away. Pressing a different tool's slot swaps.
func _equip_from_slot(slot: int, item: DrawnItemData) -> void:
	if _equipped_utility != null and is_instance_valid(_equipped_utility) \
		and _equipped_utility.item_data != null \
		and _equipped_utility.item_data.entity_id == item.entity_id:
		_stow_equipped()
		status_label.text = "%s put away" % item.display_name
		return
	_stow_equipped()
	var instance := registry.instantiate_entity(item.entity_id) as UtilityObject
	if instance == null:
		status_label.text = "Could not take out %s" % item.display_name
		return
	world_item_root.add_child(instance)
	instance.apply_item_data(item)
	instance.global_position = _player_anchor_position()
	_connect_utility(instance)
	instance.equip_to(player)
	inventory_hud.set_selected(slot)
	status_label.text = "%s in hand — F to use, %d again to put it away" % [item.display_name, slot + 1]


## Held tools live in the bag, so putting one away is destroying the instance rather
## than handing it back to the inventory -- it never left.
func _stow_equipped() -> void:
	if _equipped_utility == null or not is_instance_valid(_equipped_utility):
		_equipped_utility = null
		return
	var stowed := _equipped_utility
	_equipped_utility = null
	stowed.prepare_for_inventory()
	stowed.queue_free()
	if player != null and is_instance_valid(player) and player.has_method("set_carried"):
		player.call("set_carried", "")


func _slot_holding(entity_id: String) -> int:
	var stored := inventory_manager.items()
	for index in range(stored.size()):
		var item := stored[index] as DrawnItemData
		if item != null and item.entity_id == entity_id:
			return index
	return -1


func _player_anchor_position() -> Vector2:
	if player == null or not is_instance_valid(player):
		return Vector2.ZERO
	if player.has_method("get_physics_anchor"):
		var anchor := player.call("get_physics_anchor") as Node2D
		if anchor != null:
			return anchor.global_position
	return player.global_position


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
	_connect_utility(placed)
	# A placed object clamps itself to the world it was built with, and only the PLAYER was
	# ever told how big that is -- so every drawing carried the script's own 3760px default.
	if placed.has_method("set_world_bounds"):
		placed.call("set_world_bounds", Rect2(environment.get("world_bounds")))
	status_label.text = "%s placed — E or right-click to take it back" % item.display_name
	# Judged HERE and not at recognition. A square that was drawn but never put down has
	# not bridged anything, and letting the gap solve on recognition would mean the
	# tutorial's one lesson -- that you place what you draw -- could be skipped.
	_judge_submission(item.entity_id)


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
	# Before the early return: the bar has to come back when the placement ends, and that
	# is the call that arrives with active = false.
	inventory_hud.set_click_through(active)
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


## TYPED TO THE BASE, and the reason is the same one written on begin_placement and on
## _on_placement_confirmed: a drawn circle is a PhysicsShapeObject and not a UtilityObject,
## and Godot silently refuses a signal bind whose parameter type does not match. This used to
## take a UtilityObject, so `placed as UtilityObject` came back null for every primitive and
## nothing was ever wired up -- which is the whole of "I can't remove a drawing I just placed".
func _connect_utility(placed: PhysicsShapeObject) -> void:
	if placed == null:
		return
	# Every placed drawing owes the player a way back. This one is on the base.
	if not placed.pickup_requested.is_connected(_on_utility_pickup_requested):
		placed.pickup_requested.connect(_on_utility_pickup_requested)
	var utility := placed as UtilityObject
	if utility == null:
		return
	if not utility.equipped.is_connected(_on_utility_equipped):
		utility.equipped.connect(_on_utility_equipped)
	if not utility.utility_used.is_connected(_on_utility_used):
		utility.utility_used.connect(_on_utility_used)
	if not utility.utility_consumed.is_connected(_on_utility_consumed):
		utility.utility_consumed.connect(_on_utility_consumed)


func _on_utility_pickup_requested(utility: PhysicsShapeObject) -> void:
	if utility == null or not is_instance_valid(utility):
		return
	# A tool taken out of a slot never left the bag, so putting it away must not put a
	# second copy in. Without this, E on a held axe handed the inventory an axe it was
	# already holding and the player duplicated it every time they stowed it.
	if utility.item_data != null and _slot_holding(utility.item_data.entity_id) >= 0:
		if utility == _equipped_utility:
			_stow_equipped()
		else:
			utility.queue_free()
		status_label.text = "%s put away" % utility.item_data.display_name
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
	var nearest: PhysicsShapeObject
	var nearest_distance := 96.0
	# `placed_drawings`, not `drawn_utilities`: the second group is joined by UtilityObject
	# alone, so a placed square or triangle was not in it and E walked straight past the one
	# thing the player most wanted to pick back up.
	for candidate in get_tree().get_nodes_in_group(&"placed_drawings"):
		var utility := candidate as PhysicsShapeObject
		if utility == null or utility.is_preview:
			continue
		# Measured to the object's SURFACE. Against its centre, a standing ladder was
		# 122px away from someone with their hand on it and E could never reach it --
		# and it got worse the moment ladders were given their proper height.
		var distance := utility.distance_from(origin)
		if distance <= nearest_distance:
			nearest = utility
			nearest_distance = distance
	if nearest != null:
		_connect_utility(nearest)
		nearest.interact(player)


## POINT AT IT AND TAKE IT BACK. E reaches 96px, which is no help once a drawing has rolled
## into the paddy or been set on a ledge out of arm's reach -- and a placement that cannot be
## undone costs a slot, costs ink, and leaves a solid body standing in the level for good.
## Right-click already means "put it back" during a placement, so the gesture carries over
## unchanged to a drawing that is already down.
##
## This is deliberately NOT routed through interact(): right-click means one thing and always
## the same thing. Sending it through interact() would board a drawn boat and climb a drawn
## ladder instead of picking either of them up.
func _take_back_under_cursor(world_position: Vector2) -> void:
	if player == null or not is_instance_valid(player):
		return
	var nearest: PhysicsShapeObject
	# Measured to the SURFACE, so a click anywhere on the drawing reads as zero and the
	# tolerance is forgiveness for a near miss rather than a radius around its middle.
	var nearest_distance := 24.0
	for candidate in get_tree().get_nodes_in_group(&"placed_drawings"):
		var placed := candidate as PhysicsShapeObject
		if placed == null or placed.is_preview:
			continue
		# A tool in the player's hand is not in the world. Putting that away is what pressing
		# its slot again does; reaching into their hand with the mouse is a different verb.
		if placed == _equipped_utility or placed.get_parent() != world_item_root:
			continue
		var distance := placed.distance_from(world_position)
		if distance <= nearest_distance:
			nearest = placed
			nearest_distance = distance
	if nearest == null:
		return
	# Let go of it first if they are stood on it: the wanderer holds a collision exception
	# against the ladder it is climbing, and freeing the body without clearing that leaves
	# the exception pointing at nothing.
	if player.has_method("is_using_ladder") and bool(player.call("is_using_ladder", nearest)):
		player.call("end_ladder")
	_connect_utility(nearest)
	_on_utility_pickup_requested(nearest)


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


## One frame, top left, holding the two things the player is actually tracking: how much
## ink is left and what the game just said. They were a bare progress bar, a number beside
## it and an unstyled line of text over the level art, none of them wearing the language
## the main menu already had.
func _build_hud_frame() -> void:
	hud_panel = HudPanel.new()
	hud_panel.name = "HudPanel"
	hud_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud_panel.offset_left = 24.0
	hud_panel.offset_top = 20.0
	# Wide enough for the longest one-line status the level writes. The bitmap face is
	# wider per character than the one this was measured against, and a status line that
	# wraps makes the whole frame grow and shrink under the gauge as messages change.
	hud_panel.offset_right = 448.0
	$CanvasLayer.add_child(hud_panel)
	hud_panel.adopt_status(status_label)
	# Superseded by the gauge, kept so nothing that writes to them has to care.
	ink_bar.visible = false
	ink_label.visible = false
	# The two readouts at the far corners get the same frame, so the HUD is one language
	# rather than two framed things and two lines of text floating on the level art.
	_wrap_in_chip(level_badge, "top_centre", Vector2(0.0, 18.0), 0.0)
	# A fixed width, because this one's text changes every frame: the chip is placed
	# once, and a container that grows with "GOAL REACHED" grows rightward off the
	# edge of the screen from wherever it was parked.
	_wrap_in_chip(goal_label, "bottom_right", Vector2(-24.0, -80.0), 150.0,
		UIGlyph.Kind.FLAG)
	_style_action_tag()
	_frame_controls_legend()
	_build_dialogue_box()


## Its own layer, above the HUD and below every modal. A story line must sit over the ink
## meter -- it is the more important of the two whenever it is up -- but a decision box or
## the pause menu has to sit over IT, and the layer budget in modal_overlay.gd starts the
## modals at 50.
func _build_dialogue_box() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DialogueLayer"
	layer.layer = 8
	add_child(layer)
	dialogue_box = DialogueBox.new()
	dialogue_box.name = "DialogueBox"
	layer.add_child(dialogue_box)


## The Draw button, as a key prompt rather than a button.
##
## It was the only control on the HUD shaped like a button, which made it the loudest
## thing on screen and said the wrong thing twice: that drawing is done by clicking here
## (it is done by pressing R, from anywhere) and that this is a place to look (it is a
## reminder). Now it wears the chip frame the other readouts wear, with the key itself set
## into it, so it reads as "R does this" -- which is what the player needs to learn once
## and then never read again.
##
## It stays a Button. Clicking it still opens the panel, which is worth keeping for anyone
## who reaches for the mouse first, and the hit area is unchanged.
func _style_action_tag() -> void:
	if draw_button == null:
		return
	for state in [&"normal", &"hover", &"pressed", &"disabled"]:
		draw_button.add_theme_stylebox_override(state, UISkin.chip(8.0, 4.0))
	draw_button.add_theme_color_override(&"font_color", UISkin.LIME_PALE)
	draw_button.add_theme_color_override(&"font_hover_color", UISkin.LIME)
	draw_button.add_theme_color_override(&"font_disabled_color", UISkin.MUTED)
	draw_button.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	draw_button.add_theme_constant_override(&"h_separation", 8)
	# Room made on the left for the key badge, which is drawn over the button rather than
	# laid out inside it: a Button is not a container, so a child Control added to it is
	# positioned, not packed, and the label centres itself in the whole rect regardless.
	draw_button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	draw_button.add_theme_constant_override(&"align_to_largest_stylebox", 0)
	draw_button.add_child(_key_badge("R"))


## One key, drawn as a key: a lime tile with the letter cut out of it dark. The same shape
## the controls legend uses, at the size a chip can hold.
func _key_badge(key: String) -> Control:
	var badge := PanelContainer.new()
	badge.name = "KeyBadge"
	var cap := StyleBoxFlat.new()
	cap.bg_color = UISkin.LIME
	cap.set_corner_radius_all(UISkin.RADIUS)
	cap.content_margin_left = 5.0
	cap.content_margin_right = 5.0
	cap.content_margin_top = 1.0
	cap.content_margin_bottom = 1.0
	badge.add_theme_stylebox_override(&"panel", cap)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2(8.0, 7.0)
	var letter := Label.new()
	letter.text = key
	letter.add_theme_color_override(&"font_color", UISkin.GREEN_LABEL)
	letter.add_theme_font_size_override(&"font_size", UISkin.FONT_CAPTION)
	letter.add_theme_constant_override(&"shadow_offset_x", 0)
	letter.add_theme_constant_override(&"shadow_offset_y", 0)
	badge.add_child(letter)
	return badge


## The keybind row, on a ground it can be read against.
##
## It was bare outlined text lying directly on the level, along the bottom edge -- which
## in Level 1 is grass, stone and water, all of it the same value as the text. The row was
## unreadable in exactly the first thirty seconds it exists to serve.
##
## It still fades. That is a deliberate decision and not a look: the row is worth having
## while the player is learning where the keys are, and the Controls screen has the same
## five lines for the rest of the time.
func _frame_controls_legend() -> void:
	var keys := $CanvasLayer/HintLabel as Label
	if keys == null:
		return
	var strip := PanelContainer.new()
	strip.name = "ControlsStrip"
	strip.add_theme_stylebox_override(&"panel", UISkin.strip())
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parent := keys.get_parent()
	parent.remove_child(keys)
	strip.add_child(keys)
	parent.add_child(strip)
	keys.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	# Outlined type on a solid strip is a belt over a belt, and the outline is what makes
	# a small font look furry.
	keys.add_theme_constant_override(&"outline_size", 0)
	strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_place_chip(strip, "bottom_left", Vector2(24.0, -18.0))
	_place_chip.call_deferred(strip, "bottom_left", Vector2(24.0, -18.0))
	_chips.append({"chip": strip, "corner": "bottom_left", "offset": Vector2(24.0, -18.0)})
	if not get_viewport().size_changed.is_connected(_place_all_chips):
		get_viewport().size_changed.connect(_place_all_chips)

	var fade := create_tween()
	fade.tween_interval(14.0)
	fade.tween_property(strip, "modulate:a", 0.0, 1.2)


## A label sized to its own text, parked in a corner.
##
## Styling the Label itself is not enough: these are anchored with fixed offsets, so the
## level badge's rect is the full width of the screen and a background on it painted a bar
## from edge to edge, straight over the Draw button. A PanelContainer shrinks to what is
## inside it, which is what a chip has to do.
##
## Placed by hand rather than with an anchor preset. PRESET_MODE_MINSIZE measures a label
## that has not laid out yet and gets zero, and a preset without it keeps the offsets the
## label already had -- which is the full width of the screen. Both were tried; both put a
## dark slab across the HUD.
func _wrap_in_chip(label: Label, corner: String, offset: Vector2,
		min_width: float, glyph: int = -1) -> void:
	if label == null:
		return
	var parent := label.get_parent()
	if parent == null:
		return
	var chip := PanelContainer.new()
	chip.name = "%sChip" % label.name
	chip.add_theme_stylebox_override(&"panel", UISkin.chip())
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.remove_child(label)
	# A glyph needs a row to sit in; without one the chip has a single child and the
	# pictogram would have to be positioned by hand against a label that resizes.
	if glyph >= 0:
		var row := HBoxContainer.new()
		row.name = "Row"
		row.add_theme_constant_override(&"separation", 7)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mark := UIGlyph.new()
		mark.kind = glyph as UIGlyph.Kind
		mark.custom_minimum_size = Vector2(14.0, 16.0)
		row.add_child(mark)
		row.add_child(label)
		chip.add_child(row)
	else:
		chip.add_child(label)
	parent.add_child(chip)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	label.custom_minimum_size = Vector2(min_width, 0.0)
	chip.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_place_chip(chip, corner, offset)
	# Deferred as well, because the first call runs before the label has been laid out and
	# measures a chip with no text in it yet.
	_place_chip.call_deferred(chip, corner, offset)
	# Remembered rather than connected per chip: two bound callables over the same method
	# read as one connection, so the second chip's connect failed with an error on every
	# level load and its chip stopped following the window.
	_chips.append({"chip": chip, "corner": corner, "offset": offset})
	if not get_viewport().size_changed.is_connected(_place_all_chips):
		get_viewport().size_changed.connect(_place_all_chips)


func _place_all_chips() -> void:
	for entry: Variant in _chips:
		var spec: Dictionary = entry
		_place_chip(spec["chip"], String(spec["corner"]), Vector2(spec["offset"]))


func _place_chip(chip: PanelContainer, corner: String, offset: Vector2) -> void:
	if chip == null or not is_instance_valid(chip):
		return
	var chip_size := chip.get_combined_minimum_size()
	chip.size = chip_size
	var view := get_viewport_rect().size
	match corner:
		"bottom_right":
			chip.position = Vector2(view.x - chip_size.x + offset.x, view.y - chip_size.y + offset.y)
		"bottom_left":
			chip.position = Vector2(offset.x, view.y - chip_size.y + offset.y)
		_:
			chip.position = Vector2((view.x - chip_size.x) * 0.5 + offset.x, offset.y)


func _on_ink_changed(remaining: float, capacity: float, reserved: float) -> void:
	if hud_panel != null:
		hud_panel.set_ink(remaining, capacity, reserved)


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
	# A fall is not an ending. The wanderer used to wrap to the top of the world and a
	# drawn creature did not handle it at all, so falling off as a fish meant falling
	# forever. Either way the level takes them back to the last checkpoint instead.
	var floor_limit: float = Rect2(environment.get("world_bounds")).end.y + FALL_LIMIT_MARGIN
	if anchor_position.y > floor_limit:
		_return_to_safety("Back to the start", "Back to %s")
		return

	# THE APO CANNOT SWIM. The paddy is deep enough that wading in is not wading across --
	# the wading jump clears about twenty pixels and the bank is a hundred above the floor
	# -- so without this the water is not a gate, it is a hole to be stuck in. A drawn
	# creature that swims is not rescued: being in the water is the whole point of it.
	if player is Wanderer and bool(player.call("is_in_water")):
		_submerged_seconds += _delta
		if _submerged_seconds > 1.1:
			_submerged_seconds = 0.0
			_return_to_safety("You cannot swim, apo — draw something that can cross it",
				"You cannot swim, apo. Back to %s")
			return
	else:
		_submerged_seconds = 0.0
	# Crossing the far lip is what earns the memory, not choosing the route that would
	# have earned it: the reward is for having rebuilt her bridge and walked over it.
	if anchor_position.x > 2980.0:
		_show_memory_if_earned()
	var distance := anchor_position.distance_to(goal_marker.global_position)
	# The distance is already being computed to decide completion, so showing it costs
	# nothing and gives the level a legible objective -- until now the only thing
	# telling the player where to go was the level ending when they arrived.
	var may_finish := _completion_unlocked()
	goal_label.text = "GOAL  %d m" % int(distance / 32.0) \
		if distance > GOAL_RADIUS or not may_finish else "GOAL REACHED"
	if distance <= GOAL_RADIUS and may_finish:
		_complete_level()


## Put the player back somewhere they can stand, and say why.
##
## A fall is not an ending and neither is stepping into the paddy: both take back the
## climb, not the run.
func _return_to_safety(nothing_written: String, restored_format: String) -> void:
	var restored := _restore_checkpoint()
	if restored.is_empty():
		# Nothing written yet -- Beat 0 before its own checkpoint. Back to the start of the
		# level, which is the only earlier place there is.
		if player != null and is_instance_valid(player) and player.has_method("apply_morph_state"):
			player.call("apply_morph_state",
				{"position": spawn_point.global_position, "linear_velocity": Vector2.ZERO})
		status_label.text = nothing_written
	else:
		status_label.text = restored_format % restored


## Whether the level is allowed to end yet.
##
## The GoalMarker sits inside Ang Bale, and coming within its radius used to be the whole
## condition -- so walking up to the house ENDED LEVEL 1. Lolo had not offered the three
## ways in, the chest was still shut, the second canvas was never granted, and the
## completion screen came up over a node the player had not played. Caught by
## photographing the bale.
##
## The condition is not written here. Level 1's own file names the checkpoint that unlocks
## it (`unlocks_at_checkpoint`, CP3), the checkpoint list says which obstacle that
## checkpoint belongs to (CP3 is `at: L1_N3`), and the level may end once that obstacle has
## been SOLVED. Not committed: CP3 is written on the route commit, so asking only whether
## the checkpoint exists would let a player finish by pressing a dialogue button and walking
## four metres, without drawing anything. A level that names no such checkpoint ends on
## arrival exactly as before, which is what the levels with no obstacle layer want.
func _completion_unlocked() -> bool:
	if director == null:
		return true
	var obstacle_id := _obstacle_that_unlocks_the_exit()
	if obstacle_id.is_empty():
		return true
	return director.is_solved(obstacle_id)


func _obstacle_that_unlocks_the_exit() -> String:
	var data := director.level_data()
	var checkpoint_id := String(data.get("unlocks_at_checkpoint", ""))
	if checkpoint_id.is_empty():
		return ""
	for entry_value: Variant in (data.get("checkpoints", []) as Array):
		var entry: Dictionary = entry_value
		if String(entry.get("id", "")) != checkpoint_id:
			continue
		# "L1_N3", or "B0_HAGDAN.top" for the ones that name a place within an obstacle.
		return String(entry.get("at", "")).split(".")[0]
	return ""


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
	var wanderer := _instantiate_wanderer()
	if wanderer == null:
		return
	wanderer.global_position = spawn_point.global_position
	# No flash on the first frame: there is nothing to transform FROM, and a level that
	# opens on an effect reads as something having already happened offscreen.
	_adopt_player(wanderer, {}, false)


func _instantiate_wanderer() -> Node2D:
	var scene := load(WANDERER_SCENE) as PackedScene
	if scene == null:
		push_warning("GameLevel: no wanderer scene; the level starts empty")
		return null
	var wanderer := scene.instantiate() as Node2D
	entity_root.add_child(wanderer)
	wanderer.call("set_world_bounds", Rect2(environment.get("world_bounds")))
	return wanderer


## Q: give the player their own body back.
##
## Being a drawn animal is a commitment -- a fish cannot climb and a bird cannot push --
## and until now the only way out of one was to spend more ink drawing your way into a
## different one. That makes a wrong guess about which creature a section wants into a
## dead end, which is the opposite of what a game about trying things should do. Changing
## back is therefore FREE: it draws nothing, so it costs no ink.
##
## It is not an undo. The creature is gone and the ink that made it stays spent, so the
## status line says so rather than letting the player find out by looking for it.
func _revert_to_base_form() -> void:
	if player is Wanderer:
		status_label.text = "You are already yourself"
		return
	var previous_state: Dictionary = {}
	if player != null and is_instance_valid(player) and player.has_method("capture_morph_state"):
		previous_state = player.call("capture_morph_state")
	# Same reason a morph drops what it holds: the held item is parented to the OLD body's
	# grip, so it has to be re-homed into the world before that body is freed.
	_drop_equipped_before_morph(previous_state)

	# Where the creature was, not the spawn point -- changing back is not restarting. Both
	# kinds of player report "position", so the fallback only covers a body that answered
	# capture_morph_state with nothing at all.
	var landing := spawn_point.global_position
	if player != null and is_instance_valid(player):
		landing = player.global_position
	landing = Vector2(previous_state.get("position", landing))

	var wanderer := _instantiate_wanderer()
	if wanderer == null:
		status_label.text = "Could not change back"
		return
	wanderer.global_position = landing
	_adopt_player(wanderer, previous_state, true)

	# Which class was abandoned, and how far into the level. A creature the player draws
	# and then backs out of is the clearest signal there is that its attributed ability
	# was not the one that section needed -- a decline says the recogniser was unsure,
	# but this says the recogniser was right and the ability still did not fit.
	Telemetry.record_event("morph_reverted", {
		"level_id": LevelManager.current_level_id,
		"from_entity": _current_form_id,
		"ink_remaining": ink_manager.remaining(),
		"seconds_into_level": float(Time.get_ticks_msec() - _run_started_msec) / 1000.0,
	})

	var was := _current_form_name
	_current_form_name = ""
	_current_form_id = ""
	if was.is_empty():
		status_label.text = "Back to yourself"
	else:
		status_label.text = "Back to yourself — the %s is gone" % was.to_lower()


## Everything that has to happen when one body becomes the player in place of another,
## in one place because the wanderer and a drawn creature answer the same calls -- that
## is the whole reason the swap is uniform, and three copies of it would be three chances
## for one of them to forget the camera or leave the old body in the world.
func _adopt_player(new_player: Node2D, previous_state: Dictionary, flash: bool) -> void:
	if not previous_state.is_empty() and new_player.has_method("apply_morph_state"):
		new_player.call("apply_morph_state", previous_state)
	# The swap is otherwise a single frame -- one body gone, another in its place --
	# which reads as a glitch rather than as the transformation the game is about.
	if flash:
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
	if lolo != null and is_instance_valid(lolo):
		lolo.follow(new_player)
	if old_player != null and is_instance_valid(old_player):
		old_player.queue_free()


## Lolo's script, from config rather than from strings typed into this file, for the
## same reason the level's title is: a second level must not need a code change to say
## anything, and the writing has to be editable by whoever is writing it.
func _load_dialogue() -> void:
	var text := FileAccess.get_file_as_string("res://config/dialogue.json")
	if text.is_empty():
		push_warning("GameLevel: no dialogue config; Lolo will stay quiet")
		return
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("GameLevel: dialogue config is not a JSON object")
		return
	var levels: Dictionary = (parsed as Dictionary).get("levels", {})
	_script_lines = levels.get(LevelManager.current_level_id, {})


## The companion, present from the first frame. His ART is a placeholder; the level
## talks to him through follow/say, which a designed Lolo answers the same way.
func _spawn_lolo() -> void:
	var scene := load("res://creatures/lolo.tscn") as PackedScene
	if scene == null:
		push_warning("GameLevel: no Lolo scene; the level runs without a companion")
		return
	lolo = scene.instantiate() as Lolo
	entity_root.add_child(lolo)
	lolo.follow(player)
	if dialogue_box != null:
		lolo.set_dialogue_box(dialogue_box)
	_lolo_says("greeting")


func _lolo_says(key: String, seconds: float = 0.0) -> void:
	if lolo == null or not is_instance_valid(lolo):
		return
	var line := String(_script_lines.get(key, ""))
	if not line.is_empty():
		lolo.say(line, seconds)


func _wire_dialogue_node() -> void:
	if cave_gate != null and hidden_flower != null:
		# The gate is the only thing that may reveal the flower, so a player who has
		# not learned Illumination sees a dark cave rather than a prize behind glass.
		if cave_gate.can_pass():
			hidden_flower.reveal()
		cave_gate.connect(&"passage_allowed", func(_concept: String) -> void: hidden_flower.reveal())
		cave_gate.connect(&"passage_blocked", func(_concept: String, hint: String) -> void:
			status_label.text = hint)
	if dialogue_node == null:
		return
	dialogue_node.approached.connect(_on_dialogue_node_approached)
	dialogue_node.route_chosen.connect(_on_route_chosen)
	dialogue_overlay.connect(&"route_picked", _on_route_picked)
	memory_overlay.connect(&"dismissed", func() -> void: _lolo_says("arrival"))


## Lolo pauses time to talk (Game Design section 3). The overlay is what does the
## pausing -- it is a ModalOverlay, and UIRouter derives the tree's pause state from
## whoever is open -- so this only has to decide what he asks.
func _on_dialogue_node_approached() -> void:
	if lolo != null and is_instance_valid(lolo):
		lolo.hush()
	# Payyo's own script, when it has one. The three buttons are read off the commit
	# lines rather than authored twice, so the button and the line the apo says when it
	# is pressed are literally the same string and cannot drift.
	var choices: Dictionary = script_lines_l1.choices_for("L1_N1") if script_lines_l1 != null else {}
	if not choices.is_empty():
		var context := ""
		for line_value: Variant in script_lines_l1.peek("L1_N1.choice"):
			context = String((line_value as Dictionary).get("text", ""))
		dialogue_overlay.call("present", "Lolo", context, choices)
		return
	var node_lines: Dictionary = _script_lines.get("node", {})
	if node_lines.is_empty():
		return
	dialogue_overlay.call(
		"present",
		String(node_lines.get("speaker", "Lolo")),
		String(node_lines.get("context", "")),
		node_lines.get("choices", {})
	)


func _on_route_picked(route: String) -> void:
	if dialogue_node != null:
		dialogue_node.choose(route)


## The answer physically alters the level: one branch opens, the other two are freed.
func _on_route_chosen(route: String) -> void:
	if route_layout != null:
		route_layout.apply_route(route)
	# The single write: the tally, the checkpoint and the telemetry all happen inside
	# commit_route, and the commit line Lolo speaks is fired from route_committed.
	if director != null:
		director.commit_route("L1_N1", route)
	else:
		var routes: Dictionary = _script_lines.get("routes", {})
		if lolo != null and is_instance_valid(lolo):
			lolo.say(String(routes.get(route, "")))
		status_label.text = "Route: %s" % route.capitalize()


## The Empathy route's reward, shown once the player has actually crossed the gorge
## they chose to rebuild rather than the moment they chose to.
func _show_memory_if_earned() -> void:
	if _memory_shown or route_layout == null or route_layout.chosen_route() != "artist":
		return
	var memory: Dictionary = _script_lines.get("memory", {})
	if memory.is_empty():
		return
	_memory_shown = true
	var lines := PackedStringArray()
	for line in memory.get("lines", []):
		lines.append(String(line))
	memory_overlay.call("present", String(memory.get("title", "A memory")), lines)


## Name the level from the catalog instead of from strings typed into the scene. The
## badge and the pause menu's subtitle both said "BANAUE RICE TERRACES" literally, so
## a second level would have shipped mislabelled.
func _apply_level_identity() -> void:
	var entry := LevelManager.get_level(LevelManager.current_level_id)
	if entry.is_empty():
		return
	var badge := level_badge
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
	if _level_completed:
		return
	# And never over the canvas. The last of the ink is spent by a drawing being
	# accepted, and the panel is still on screen at that moment -- an overlay eight
	# layers above it would land on top of the drawing that just succeeded.
	if draw_panel.is_open():
		if not draw_panel.panel_closed.is_connected(_on_ink_exhausted):
			draw_panel.panel_closed.connect(_on_ink_exhausted, CONNECT_ONE_SHOT)
		return
	out_of_ink_overlay.open()
