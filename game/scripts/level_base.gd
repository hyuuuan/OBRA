class_name LevelBase
extends Node2D
## The half of a level that is not about any particular level.
##
## `game_level.gd` was the whole machine AND Payyo's furniture in one 3046-line file, and its
## name was the only generic thing about it: 51 hardcoded L1_N* references, Level 1's config
## baked into a `director.load_level()` with no argument, and `res://config/dialogue_l1.json`
## written into a field called `script_lines`. Level 2 could have started from a copy of
## that file. This is the alternative, taken while there was exactly one level to extract
## from -- which is the cheapest this refactor will ever be (LEVEL_TEMPLATE.md).
##
## WHAT LIVES HERE: the draw / recognise / adopt loop, ink, placement and the bag, MorphLife
## and reverting, checkpoints and restore, the obstacle layer and the hint ladder, dialogue
## plumbing, room framing, the HUD, and the completion path. None of it names a beat.
##
## WHAT A LEVEL OWES: the hooks in the next section. Every one of them exists because Payyo
## had something in that exact spot -- none is speculative -- and a level that needs none of
## them can override none of them.


# --- What a level answers -----------------------------------------------------------
#
# The two paths are REQUIRED; the rest default to doing nothing, which is what a level
# with no furniture of its own wants.

## The level file the director loads, e.g. "res://config/level_02.json".
func level_config_path() -> String:
	push_error("%s names no level config" % get_script().resource_path)
	return ""


## The dialogue file `script_lines` is read from, e.g. "res://config/dialogue_l2.json".
func dialogue_path() -> String:
	push_error("%s names no dialogue file" % get_script().resource_path)
	return ""


## Nodes this level owns whose PATHS are its own. `dialogue_node` is the one the base
## needs: Payyo keeps it under Gorge/, and a second level will not have a gorge.
func _resolve_level_nodes() -> void:
	pass


## Props, rooms and locks the level owns, built after the director and the checkpoint
## manager exist and before the obstacle volumes are wired.
func _build_level_furniture() -> void:
	pass


## A refusal that is about this level rather than about the tag layer. Payyo answers with
## Ang Bale's padlock, which judges the STROKES of a drawn key rather than its class.
## True means the submission was consumed and the director must not see it.
func _extra_refusals(_entity_id: String, _strokes: Array) -> bool:
	return false


## What this level DOES when an obstacle is solved. True means the level handled the beat
## and the generic "<obstacle>.<route>.solved" line must not also fire.
func _on_route_solved(_obstacle_id: String, _route: String) -> bool:
	return false


## A key this level binds that no other level does. True means it was consumed.
func _handle_level_input(_event: InputEvent) -> bool:
	return false


## Something to interact with on E that is neither a placed drawing nor a signpost, tried
## between the two. Payyo offers the brass key found on the nail. True means it was used.
func _interact_with_level() -> bool:
	return false


## The level's own per-frame business, given the player's anchor. Runs only while the
## level is live -- there is a player, a goal marker, and the level is unfinished.
func _level_physics(_anchor_position: Vector2) -> void:
	pass


## The obstacle the scene's DialogueNode2D presents, or "" if the level has none.
func _dialogue_node_obstacle_id() -> String:
	return ""


## WHICH LEVEL THIS IS, asked of the level's own config rather than of the hub catalog.
##
## Running a scene directly -- from the editor, or from a runner -- never goes through
## LevelManager.open_level, so nothing has said which level it is. The fallback used to be
## the FIRST card in levels.json, which is Payyo no matter what is running: Level 2 came up
## badged "LEVEL 1 - PAYYO", took Level 1's opening line out of the legacy dialogue.json,
## and -- the part that is not cosmetic -- handed level_1 to Telemetry.begin_level and to
## every profile write it made.
func _own_level_id() -> String:
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(level_config_path()))
	if parsed is Dictionary:
		var id := String((parsed as Dictionary).get("level_id", ""))
		if not id.is_empty():
			return id
	var catalog := LevelManager.get_levels()
	return String(catalog[0].get("id", "")) if not catalog.is_empty() else ""


## Anything a checkpoint must carry that is the LEVEL's rather than the machine's. Payyo
## needs none of this -- its state is all pickups and obstacles, which the generic snapshot
## already holds. Piyesta rides its scrap ledger here: five of seven pieces are recovered
## in one alley and claimed in the next, so a death between the two must not un-recover
## them, and must not spawn them a second time either.
func _level_run_state() -> Dictionary:
	return {}


func _restore_level_run_state(_state: Dictionary) -> void:
	pass


# --- The machine --------------------------------------------------------------------

@export var debug_timing_logs: bool = false

## WHERE THE INTERFACE NAMES A KEY. The doorway into the straw prompts for one, and the
## controls screen already translates a physical keycode through the active layout so a
## non-QWERTY player is not told to press the wrong thing. Preloaded rather than reached by
## class name, because controls_overlay.gd declares none.
const ControlsKeys = preload("res://scripts/controls_overlay.gd")

## A morph whose anchor comes within this radius of the level's GoalMarker completes it.
const GOAL_RADIUS := 120.0
## The key on the nail in the heap. One name, read by the room that grants it and the door
## it opens -- see straw_room_2d.gd's collectible_id.
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
## The level's SECOND clock. Ink buys a drawing; this is how long the drawing lasts.
@onready var morph_life: MorphLife = $MorphLife
@onready var inventory_manager: InventoryManager = $InventoryManager
@onready var placement_controller: PlacementController = $PlacementController
@onready var goal_marker: Node2D = get_node_or_null("EnvironmentBaseplate/GameplayPlane/GoalMarker")
@onready var goal_label: Label = $CanvasLayer/GoalLabel
@onready var level_badge: Label = $CanvasLayer/LevelBadge
## Built in code rather than authored into the scene, like the requirement strip: it owns
## its own frame and gauge and there is nothing to lay out by hand.
var hud_panel: HudPanel
## The card that says a thing is yours now. See AcquiredOverlay and announce_acquisition.
var acquired_overlay: AcquiredOverlay
## The bag, and everything found, on one screen. See InventoryScreen.
var inventory_screen: InventoryScreen
## The letterbox the level's set pieces are framed in. See CinematicBars.
var cinematic: CinematicBars
## Top right: the drawing the player is currently wearing, and how long it has left.
var morph_card: MorphCard
## R and Q at the lower left; E and F beside the current body only while they can act.
var action_prompts: ActionPromptHUD
## The part of the game that teaches the game. Level-scoped and spent once per run; a
## level with no block in tutorial.json simply never teaches anything. See
## TutorialDirector -- every lesson goes to the HintBar, so teaching never stops the tree.
var tutorial: TutorialDirector
## First horizontal input of the run, polled rather than signalled: there is nothing to
## signal on, because walking is not an event the level owns.
var _has_moved := false
## What the recogniser scored the sketch that is currently being adopted.
##
## Carried on the level rather than threaded through _spawn_or_replace, which is called from
## three places and cares about none of it. The score belongs to the SUBMISSION, and the
## submission is the thing that set this a moment before the morph -- see _on_drawing_ready.
var _last_confidence := 0.0
## Where the apo was standing on the terrace when they got into Ang Bale, so the ladder puts
## them back there rather than at a guess. Remembered on the way in, like _straw_return.
var _framed_room: Node2D = null
## The framed box every story line is shown in. Built here rather than authored into the
## scene because it is pure presentation with no state to save and nothing to wire.
var dialogue_box: DialogueBox
## The other channel: what the game says while you keep playing.
var hint_bar: HintBar
## The corner readouts and where each belongs, so they can be re-placed together.
var _chips: Array = []
## How long the player has been under the water in their own body.
var _submerged_seconds := 0.0
## Where on the terrace to put the apo back when she comes out of the straw room.
var _sign_prompt := ""
## Ang Bale's padlock, which judges the STROKES of a drawn key rather than its class.
@onready var complete_overlay: ModalOverlay = $LevelCompleteOverlay
@onready var out_of_ink_overlay: ModalOverlay = $OutOfInkOverlay
@onready var dialogue_overlay: ModalOverlay = $DialogueChoiceOverlay
@onready var memory_overlay: ModalOverlay = $MemoryOverlay
## The scene's route-choice node. Assigned by _resolve_level_nodes, because its path is
## the level's own -- Payyo keeps it under Gorge/.
var dialogue_node: DialogueNode2D
@onready var route_layout: RouteLayout2D = get_node_or_null(
	^"EnvironmentBaseplate/GameplayPlane/Routes")
var player: Node2D
var lolo: Lolo
## Lolo's lines for this level, from config/dialogue.json.
var _script_lines: Dictionary = {}
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
var script_lines: DialogueScript
var requirement_strip: RequirementStrip
## The refusal beat fires on the FIRST decline anywhere in the level, then never again.
var _refusal_spoken := false
var _run_started_msec := 0
## entity_id -> true, for the "things drawn" stat. Distinct classes, not attempts.
var _classes_this_run: Dictionary = {}


func _ready() -> void:
	# Findable by the rooms, which have to ask what this RUN has already handed over rather
	# than what the profile remembers forever. See pickup_taken_this_run.
	add_to_group(RUN_STATE_GROUP)
	registry.load_manifest()
	# Running this scene directly -- from the editor, or from a test -- never goes
	# through LevelManager.open_level, so nothing has said which level this is. The
	# level badge, the dialogue and the telemetry all read it, so resolving it once
	# here is what stops a direct run being an anonymous, silent, unlabelled level.
	if LevelManager.current_level_id.is_empty():
		LevelManager.current_level_id = _own_level_id()
	Telemetry.begin_level(LevelManager.current_level_id)
	ink_manager.begin_level(12.0)
	inventory_manager.begin_level()
	placement_controller.registry = registry
	placement_controller.world_item_root = world_item_root
	draw_panel.ink_manager = ink_manager
	draw_panel.set("debug_timing_logs", debug_timing_logs)
	inventory_hud.set_manager(inventory_manager)
	_build_hud_frame()
	acquired_overlay = AcquiredOverlay.new()
	acquired_overlay.name = "AcquiredOverlay"
	add_child(acquired_overlay)
	_build_inventory_screen()
	cinematic = CinematicBars.new()
	cinematic.name = "CinematicBars"
	add_child(cinematic)

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
	out_of_ink_overlay.connect(&"level_select_pressed", LevelManager.return_to_house)
	ink_manager.ink_exhausted.connect(_on_ink_exhausted)
	morph_life.life_changed.connect(_on_life_changed)
	morph_life.life_expired.connect(_on_life_expired)
	morph_life.form_changed.connect(_on_form_changed)
	tutorial = TutorialDirector.new()
	tutorial.name = "TutorialDirector"
	add_child(tutorial)
	tutorial.load_for(LevelManager.current_level_id)
	tutorial.bind_hint_bar(hint_bar)
	_run_started_msec = Time.get_ticks_msec()
	_apply_level_identity()
	_resolve_level_nodes()
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
	if _handle_level_input(event):
		get_viewport().set_input_as_handled()
		return
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
	if event.is_action_pressed("inventory_open"):
		get_viewport().set_input_as_handled()
		_toggle_inventory_screen()
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
		# A drawing you can reach comes first. Both are "the thing in front of you" and
		# both are on one key, but only one of them is something the player put there --
		# reading a board instead of picking up the ladder you just placed would be the
		# game ignoring you, while the reverse is a key press that says nothing this time.
		if not _interact_with_nearest_utility() and not _interact_with_level():
			_read_nearest_sign()
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
	if not director.load_level(level_config_path()):
		push_warning("%s: no level data; obstacles will accept nothing" % name)

	checkpoints = CheckpointManager.new()
	checkpoints.name = "CheckpointManager"
	add_child(checkpoints)

	script_lines = DialogueScript.new()
	script_lines.load_from(dialogue_path())

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

	# The level's own props, locks and rooms: after the director and the checkpoints exist
	# (they are what furniture wires itself to) and before the obstacle volumes below.
	_build_level_furniture()

	# Checkpoints you walk into, for the beats with no dialogue to hang one on.
	for node in get_tree().get_nodes_in_group(&"checkpoint_areas"):
		var area := node as CheckpointArea2D
		if area == null:
			continue
		if not _checkpoint_is_declared(area.checkpoint_id):
			push_error("%s: checkpoint area '%s' is not in %s"
				% [name, area.checkpoint_id, level_config_path()])
			continue
		area.reached.connect(_on_checkpoint_area_reached)

	for node in get_tree().get_nodes_in_group(&"level_obstacles"):
		var area := node as LevelObstacle2D
		if area == null:
			continue
		# An obstacle volume whose id is not in the data is a dead trigger: the player
		# walks through it and nothing ever asks them for anything. Loud, not silent.
		if director.obstacle(area.obstacle_id).is_empty():
			push_error("%s: obstacle volume '%s' has no entry in %s"
				% [name, area.obstacle_id, level_config_path()])
			continue
		area.player_entered.connect(director.enter_obstacle)
		# SCOPE AND ARRIVAL ARE TWO SIGNALS NOW. The wide box says which beat the player is
		# working on; the narrow one says they have reached the thing it is about. See
		# LevelObstacle2D.announce_size for why one box could not do both.
		area.player_arrived.connect(_on_obstacle_arrived)
		area.player_exited.connect(director.exit_obstacle)
		_plant_commit_mark(area)


## A MARK FOR THE CHECKPOINTS NOBODY COULD SEE.
##
## Payyo declares six checkpoints and exactly ONE of them had anything on screen: CP0, the
## walk-in at the top of the stair. CP1, CP2 and CP3 are written the instant a route is
## committed, which is every node in the level, and they were a dictionary entry and a
## telemetry event and nothing else. So the three moments the game is most generous to the
## player -- the ones it puts in front of every morph on a route -- said nothing at all, and
## the player found out a checkpoint existed only by dying.
##
## The flag stands at the OUTGOING edge of the obstacle, which is where the player is headed
## when the route is committed, and it is furled and grey until the commit raises it. Which
## obstacles get one is read out of `checkpoint_on_commit` in level_01.json rather than
## authored in the scene, so a checkpoint moved in the data takes its mark with it.
func _plant_commit_mark(volume: LevelObstacle2D) -> void:
	var checkpoint_id := String(
		director.obstacle(volume.obstacle_id).get("checkpoint_on_commit", ""))
	if checkpoint_id.is_empty():
		return
	var at := Vector2(volume.trigger_size.x * 0.5 - 40.0 + volume.checkpoint_mark_offset, 0.0)
	var mark := CheckpointLantern2D.plant(volume, at)
	if mark != null:
		_commit_marks[volume.obstacle_id] = mark


func _checkpoint_is_declared(checkpoint_id: String) -> bool:
	if checkpoint_id.is_empty() or director == null:
		return false
	for entry_value: Variant in (director.level_data().get("checkpoints", []) as Array):
		if String((entry_value as Dictionary).get("id", "")) == checkpoint_id:
			return true
	return false


func _on_checkpoint_area_reached(checkpoint_id: String) -> void:
	_write_checkpoint(checkpoint_id)
	_say_checkpoint()
	var area := _checkpoint_area_for(checkpoint_id)
	if area != null:
		_stage_the_checkpoint(area.get_node_or_null(^"Checkpoint") as Node2D)


func _checkpoint_area_for(checkpoint_id: String) -> Node:
	for node in get_tree().get_nodes_in_group(&"checkpoint_areas"):
		if String(node.get("checkpoint_id")) == checkpoint_id:
			return node
	return null


## THE MOMENT A CHECKPOINT IS EARNED, FRAMED.
##
## The lantern lights whether or not anybody is looking at it, and a player crossing a
## checkpoint is by definition moving -- so the one generous thing the level does was
## happening somewhere off to the side of a screen they were reading for platforms. Bars in,
## the camera takes the lantern, it catches, the camera lets go, bars out. Under three
## seconds, and it never takes the controls away: see CinematicBars on why it does not pause.
func _stage_the_checkpoint(mark: Node2D) -> void:
	if mark == null or cinematic == null or cinematic.is_playing():
		return
	var world_camera := _world_camera()
	cinematic.close("CHECKPOINT")
	if world_camera != null:
		# Pushed in a little and level with the flame rather than lifted off it -- the default
		# dialogue framing drops the camera to look up at a speaker, and there is nobody here.
		world_camera.focus_on(mark, 1.22, 0.45, -46.0)
	await get_tree().create_timer(0.42, true, false, true).timeout
	if is_instance_valid(mark) and mark.has_method("light"):
		mark.call("light", Vector2(0.0, -60.0))
	await get_tree().create_timer(1.35, true, false, true).timeout
	if world_camera != null:
		world_camera.release_focus()
	if cinematic != null:
		cinematic.open()


## WHAT A CHECKPOINT SAYS. It used to say "Checkpoint" on the status label, which is the same
## label that says "Placing circle -- click to set it down" and is overwritten by the next
## thing that happens; in practice the only time most checkpoints were ever announced was
## after the player had already died and been put back at one.
##
## The hint channel, because this is the interface talking and it must not stop play -- a
## checkpoint is frequently crossed mid-jump. The sound id has no file behind it yet and
## AudioDirector treats that as silence rather than as an error, which is what lets the call
## exist before the recording does.
func _say_checkpoint() -> void:
	status_label.text = "Checkpoint"
	if tutorial != null:
		tutorial.note("checkpoint")
	if hint_bar != null:
		hint_bar.show_hint("The level will remember you from here.", "", 3.0)
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio != null:
		audio.call("play_sfx", &"checkpoint")


func _on_obstacle_entered(obstacle_id: String) -> void:
	if tutorial != null:
		tutorial.note("first_obstacle")
	# A node teaches all three of its routes' verbs BEFORE the choice, because a player
	# cannot choose a path whose verb they have never been told.
	var teaches: Array = director.obstacle(obstacle_id).get("teaches_before_choice", [])
	if not teaches.is_empty():
		_speak(script_lines.fire("%s.teach" % obstacle_id))
		director.teach_before_choice(obstacle_id)
	_speak_current_stage(obstacle_id)
	_refresh_requirements()


## The player has reached what the beat is about, which is where its opening line belongs.
## Separate from _on_obstacle_entered because entering is a much wider event -- see
## LevelObstacle2D.announce_size.
func _on_obstacle_arrived(obstacle_id: String) -> void:
	_speak_on_arrival("%s.enter" % obstacle_id)


## ARRIVAL SPEAKS ONCE. Walking in somewhere is news the first time and an interruption
## every time after it, and the level is full of places the player walks into twice: the
## straw heap sits inside L1_N2's trigger and so does the ledge they are put back on when
## they climb out of it, so leaving the heap re-entered the obstacle and re-fired two lines
## of Lolo with the world paused. At L1_N1 it is seven lines.
##
## Narrowing the volumes was worth doing on its own and does not fix this: a trigger that
## contains the thing it is about will always be a trigger the player crosses more than
## once. The beat needs a memory, not a smaller box.
##
## THE LINES ARE NOT LOST, they move to a key. The board standing at the beat re-reads them
## on the interact key -- see _read_nearest_sign -- so a player who walked in mid-jump can
## still get the arrival, and one who has heard it can walk past in silence.
func _speak_on_arrival(hook: String) -> void:
	if script_lines.has_heard(hook):
		return
	_speak(script_lines.fire(hook))


## The board the player is standing at, if it has something to say again. Nearest wins, so
## two beats whose signs are within reach of one spot resolve rather than fighting.
func _readable_sign() -> Signpost2D:
	if player == null or not is_instance_valid(player):
		return null
	var origin := player.global_position
	var nearest: Signpost2D
	var nearest_distance := Signpost2D.READ_RANGE
	for node in get_tree().get_nodes_in_group(&"signposts"):
		var board := node as Signpost2D
		if board == null or not board.can_be_read_from(origin):
			continue
		# ONLY ONCE IT HAS ALREADY PLAYED. Before that the beat is still going to announce
		# itself when they walk in, and a board offering to tell them something they are
		# about to be told anyway is a key press that changes nothing.
		if not script_lines.has_heard(board.reads):
			continue
		var distance := origin.distance_to(board.global_position)
		if distance <= nearest_distance:
			nearest = board
			nearest_distance = distance
	return nearest


## Say a board's lines again, on the key. Fired rather than peeked, so a `once` line that
## was spent the first time stays spent -- re-reading an arrival is not a way to collect a
## beat the level meant you to get exactly one of.
func _read_nearest_sign() -> bool:
	var board := _readable_sign()
	if board == null:
		return false
	var lines := script_lines.fire(board.reads)
	if lines.is_empty():
		return false
	_speak(lines)
	return true


## Light the board the player is standing at, and say which key reads it. Driven from the
## physics step rather than from a signal because there is nothing to signal on -- the
## player walks toward a sign, and nothing about a sign is a trigger.
##
## THE HINT BAR IS A SHARED CHANNEL and this is the least important thing on it. Lolo's
## advice about the obstacle in front of you and the way into the straw heap both live
## here, both matter more than an offer to re-read a line you have already heard, and
## either can be on screen when the player wanders past a board.
##
## So the prompt only ever writes to an EMPTY bar and only ever clears its own text. The
## first cut did neither and cost two hints: it overwrote "draw something that can span the
## gap" the moment the player stepped near the sign at the same beat, and then cleared
## whatever had replaced it on the way out.
func _offer_the_nearest_sign() -> void:
	var board := _readable_sign()
	if tutorial != null and board != null:
		tutorial.note("sign_readable")
	for node in get_tree().get_nodes_in_group(&"signposts"):
		var other := node as Signpost2D
		if other != null:
			other.offer(other == board)
	if hint_bar == null:
		return
	# The claim lapses the moment somebody writes over us -- the straw heap's doorway does
	# exactly that. Held blindly, the flag would say the prompt is still up long after it
	# was replaced, and the offer would never appear again for the rest of the run.
	if not _sign_prompt.is_empty() and hint_bar.current_text() != _sign_prompt:
		_sign_prompt = ""
	if board == null:
		if not _sign_prompt.is_empty():
			hint_bar.clear()
			_sign_prompt = ""
		return
	if not _sign_prompt.is_empty():
		return
	# Somebody else is talking on this bar. The board is lit, which already says it can be
	# read; the sentence can wait until the bar is free.
	if hint_bar.is_showing():
		return
	_sign_prompt = "Press %s to read the sign" % ControlsKeys.keys_for("interact")
	hint_bar.show_hint(_sign_prompt)


## THE KEY IN THE BAG HAS TO ANNOUNCE ITSELF. A player can pick it off the nail at Node 2
## and reach the house twenty minutes later; expecting them to remember that a brass key
## they found in a straw heap is the answer to this particular door, and to guess that the
## interact key is how you offer it, is expecting them to read the code. So the door says
## so, on the same bar and under the same rule as the sign prompt: an empty bar only, and it
## clears only its own words.
func _speak_current_stage(obstacle_id: String) -> void:
	var stage := director.stage_id(obstacle_id)
	if stage.is_empty():
		return
	_speak(script_lines.fire("%s.%s" % [obstacle_id, stage]))


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
	requirement_strip.show_requirements(director.required_tags(), director.hint_tier(), owned,
		String(spec.get("match", "all")))
	# The strip is the game's own vocabulary and nobody arrives knowing it. The tags are
	# this project's invention, so the first time one is printed at the player is the moment
	# to say what the row IS.
	# TIER 1, NOT TIER 0. At T0 the strip deliberately names no tag -- it is flavour -- so a
	# lesson about "that word at the top" would be pointing at a row with no word in it.
	if tutorial != null and director.hint_tier() >= 1 \
			and not director.required_tags().is_empty():
		tutorial.note("requirement_shown")


## The checkpoint is written HERE, on the commit, not on the solve -- so that every morph
## on the route is protected and a death cannot make the player answer Lolo twice.
func _on_obstacle_route_committed(obstacle_id: String, route: String) -> void:
	_speak(script_lines.fire("%s.%s.commit" % [obstacle_id, route]))
	var checkpoint_id := String(director.obstacle(obstacle_id).get("checkpoint_on_commit", ""))
	if not checkpoint_id.is_empty():
		_write_checkpoint(checkpoint_id)
		_light_commit_mark(obstacle_id)
		_say_checkpoint()


## Light the mark standing at this beat. The apo is somewhere in the volume when a route is
## committed, so the spark leaves from wherever they actually are -- the flame is carried to
## the lantern, and that needs to know whose hands.
func _light_commit_mark(obstacle_id: String) -> void:
	var mark := _commit_marks.get(obstacle_id) as CheckpointLantern2D
	if mark == null or not is_instance_valid(mark):
		return
	# Staged like the walk-in ones. A route commit is the biggest thing that happens at a
	# node and it used to light a lantern the player was standing with their back to.
	_stage_the_checkpoint(mark)


func _on_obstacle_solved(obstacle_id: String, route: String, label: String, attempt_count: int, tier: int) -> void:
	# THE ONE MOMENT HE REACTS TO THE PLAYER rather than to the place. The cheer frame was
	# delivered with the rest of his sheet and had never been drawn on screen.
	if lolo != null and is_instance_valid(lolo) and lolo.has_method("cheer"):
		lolo.cheer()
	# A level with something to DO at this beat does it and owns the words; otherwise the
	# generic acknowledgement fires.
	if not _on_route_solved(obstacle_id, route):
		_speak(script_lines.fire("%s.%s.solved" % [obstacle_id, route]))
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
func _judge_submission(entity_id: String, strokes: Array = []) -> void:
	if director == null or director.current_obstacle().is_empty():
		return
	if _extra_refusals(entity_id, strokes):
		return
	var verdict := director.note_submission(entity_id)
	# The strip re-reads the director either way: a solve moves it to the next stage, and
	# a miss may have opened the next hint tier.
	_refresh_requirements()
	if not bool(verdict["solves"]):
		_say_it_did_not_fit(entity_id, verdict)
		return
	if bool(verdict["solves"]) and not String(verdict["stage_id"]).is_empty():
		# Beat 0's sub-beats have their own lines ("B0_HAGDAN.sub1.solved"); a route's
		# second stage does not, and reports an empty stage id rather than a missing hook.
		_speak(script_lines.fire("%s.%s.solved" % [
			verdict["obstacle_id"], verdict["stage_id"]]))
	if bool(verdict["stage_advanced"]):
		# The next sub-beat has to ask for itself, or the second half of the tutorial is
		# silent and the player is left guessing what changed.
		_speak_current_stage(String(verdict["obstacle_id"]))


## RECOGNITION IS NOT THE PUZZLE AT ANG BALE'S DOOR.
##
## Everywhere else in the level a class is the answer: the obstacle asks for Span and a
## ladder is a ladder. Here the recogniser only gets the player through the door -- once it
## accepts `key`, the lock measures THEIR OWN STROKES against the slot: how many bits they
## drew, how deep, and how long the blade is against its width. A key that is recognisably a
## key and the wrong shape turns partway and stops.
##
## This is the level's clearest demonstration of the thesis's own claim that the drawing IS
## the entity rather than a token standing in for one, and it is a geometric test on vector
## data, NOT a CNN function. The model recognises a class and has no opinion about whether a
## particular key fits a particular lock.
##
## Returns true when the lock refused, which means the caller must NOT go on to judge the
## submission: a key that did not turn has not solved anything.
##
## NOBODY FAILS PERMANENTLY -- the third turn opens it whatever was drawn. Being locked out
## of a tutorial level by a padlock is not a lesson.
func _say_it_did_not_fit(entity_id: String, verdict: Dictionary) -> void:
	if hint_bar == null:
		return
	var needed := _tag_phrase(verdict.get("required_tags", []),
		String(director.requirement_spec().get("match", "all")))
	if needed.is_empty():
		return
	var drawn := entity_id.replace("_", " ")
	# Scoped to this level: a class may carry tags a later level unlocks, and naming one
	# here advertises an ability the player has no way to reach. See
	# AbilityTags.tags_for_class_by_level.
	var mine: Array = AbilityTags.tags_for_class_by_level(entity_id, director.level_order())
	var text := ""
	if mine.is_empty():
		# Nothing this level knows the drawing can do -- either one of the roster's
		# unhintable classes (a clock, a flashlight), or a class whose only tags belong to
		# levels the player has not reached. Either way there is nothing to contrast with,
		# only the requirement to repeat.
		text = "A %s cannot do this. It needs something that can %s." % [drawn, needed]
	else:
		text = "A %s can %s. This needs something that can %s." % [
			drawn, _tag_phrase(mine, "any"), needed]
	hint_bar.show_hint(text, Lolo.SPEAKER)


## Tag names as the player sees them everywhere else: upper case, joined by the rule the
## requirement actually uses. Shared with the strip's vocabulary on purpose -- SPAN in
## Lolo's mouth, SPAN on the strip and SPAN in the Ability Book have to be one word.
func _tag_phrase(tags: Array, match: String) -> String:
	var parts := PackedStringArray()
	for tag_value: Variant in tags:
		parts.append(String(AbilityTags.display_name(String(tag_value))).to_upper())
	if parts.is_empty():
		return ""
	if parts.size() == 1:
		return parts[0]
	var joiner := " or " if match == "any" else " and "
	return joiner.join(parts)


## Standing in the doorway of the heap. The offer, not the act.
##
## Walking in cannot be walking in: Terrace5 is the way to Node 3 and the mouth is on it, so
## a heap that swallows whoever walks past is a hole in the floor of the level. run_nodraw
## found that on the first run -- its walk east stopped at the doorway and never reached the
## bale. Down is the platformer's key for a door, it is bound and unused outside a ladder,
## and the prompt reads the live InputMap rather than naming a letter that a rebinding could
## make a lie.
## THE HOLE IS A HOLE AND THE APO DOES NOT FIT THROUGH IT.
##
## The design is that the DRAWING is what goes into the heap: the way in is a gap under a
## haystack, so you have to be something small enough to use it. Going in used to be a
## keypress anybody could make, which made the one place in Level 1 with an inside a room the
## player walked into as themselves -- and made the brass key inside it free.
##
## The tag is `burrow` and it is asked of `AbilityTags` like every other requirement in this
## level, so the mouth names a PROPERTY and never a class. It is a real obstacle now, which
## means it obeys the level's rule about them: six answers, none of them written here.
func _step_through(to: Vector2) -> void:
	_walk_through.call_deferred(to)


## THE LETTERBOX, NOT A FADE. LEVEL_1.md is explicit that stepping into the heap must not
## get a beat of black -- at a fifth of a second twice it read as the game stopping to load,
## and a doorway you have already chosen to walk through does not want one. Bars are a
## different thing: they never hide the room, they take a quarter of a second at each end,
## and they say "this is a place now" rather than "please wait".
func _frame_the_step() -> void:
	if cinematic == null or cinematic.is_playing():
		return
	cinematic.close()
	await get_tree().create_timer(0.55, true, false, true).timeout
	if cinematic != null:
		cinematic.open()


func _walk_through(to: Vector2) -> void:
	if player == null or not is_instance_valid(player):
		return
	_frame_the_step()
	player.call("apply_morph_state", {"position": to, "linear_velocity": Vector2.ZERO})
	# And it has to arrive already framed: easing across four thousand units is a whip pan
	# through the whole level.
	_refresh_room_framing(true)


## Point the camera and the placement reach at whichever inside the player is standing in,
## or back at the level when they are out on the terrace.
##
## ASKED EVERY FRAME AND ACTED ON ONLY WHEN THE ANSWER CHANGES. This used to be set once, on
## the way through a doorway, which is correct for exactly as long as a doorway is the only
## way in or out of a room -- and it is not. A checkpoint restore, a fall, a morph or an
## expiry can all move the player between a room and the terrace without going through one,
## and every one of them left the camera framing somewhere the player no longer was. Asking
## `_room_holding_player` is the whole point of that function existing.
##
## WHAT A ROOM CHANGES, in order:
##  - the vertical rule: a level pins the camera near the ground, a room in the sky cannot;
##  - how far in it sits, which is the room's own number;
##  - the box it may not look out of, so the void the room is parked in never shows;
##  - and the box a placement may not leave, which is what stopped drawings being dropped
##    through the floor of a room and onto the valley two thousand units below it.
func _refresh_room_framing(snap: bool = false) -> void:
	var room := _room_holding_player()
	if room == _framed_room and not snap:
		return
	_framed_room = room
	var world_camera := _world_camera()
	if world_camera == null:
		return
	# LET GO OF WHATEVER THE CAMERA WAS LOOKING AT. Stepping through a doorway teleports the
	# player thousands of units; a dialogue focus held on a speaker they have just left is
	# pointing at the wrong place by definition. It also has to be dropped BEFORE the zoom
	# is set, because set_base_zoom defers while a focus is held -- which is how a walk into
	# a room ended up drawn at the focus's 1.15 instead of the room's 2.
	world_camera.release_focus(0.0)
	var inside := room != null
	world_camera.set_vertical_free(inside,
		float(room.call("eye_level")) if inside else NAN)
	world_camera.set_base_zoom(float(room.call("how_far_in")) if inside else 1.0)
	world_camera.set_room_bounds(_camera_rect_for(room) if inside else Rect2())
	if placement_controller != null:
		placement_controller.set_allowed_area(
			Rect2(room.call("bounds")) if inside else Rect2())
	if snap:
		world_camera.snap_to_target()


## The box the camera may not look out of, for a room that has an opinion about it.
##
## Rooms answer `bounds()` with the box they OCCUPY, which is the right answer for "is the
## player in here" and the wrong one for framing: the heap is deliberately longer than a
## screenful and is drawn wider still, so clamping the camera to its walkable extent would
## pin the view to the middle of it and let the apo walk out of frame. A room that cares says
## so; one that does not gets its bounds, which is what a single-screen room wants anyway.
func _camera_rect_for(room: Node2D) -> Rect2:
	if room.has_method("camera_rect"):
		return Rect2(room.call("camera_rect"))
	return Rect2(room.call("bounds"))


## The interior the apo is standing in, or null if they are out on the terrace.
##
## Asked of each room's own bounds rather than tracked with a flag, so a checkpoint restore
## or a fall that moves them without going through a doorway cannot leave the camera in room
## mode -- which is the bug this shape exists to make impossible.
func _room_holding_player() -> Node2D:
	if player == null or not is_instance_valid(player):
		return null
	for node in get_tree().get_nodes_in_group(&"interiors"):
		var room := node as Node2D
		if room == null:
			continue
		if Rect2(room.call("bounds")).grow(90.0).has_point(player.global_position):
			return room
	return null


## The key off the floor of the straw room. It does not open the chest beside it and it is
## not meant to: that lock is Node 3's, and this one belongs to somewhere the player has
## only seen as a painting. Recorded on the PROFILE rather than on a checkpoint, for the
## same reason canvas damage is -- a death two beats later must not take it back.
## What a room last put on the hint bar, so that leaving the room can take down THAT and
## nothing else. One channel carries several voices.
var _room_notice := ""


func _on_room_notice(text: String) -> void:
	if hint_bar != null:
		_room_notice = text
		hint_bar.show_hint(text)


## ⚠ CLEAR WHAT WE WROTE, not a list of texts we happen to know about.
##
## This used to compare the bar against `StrawRoom2D.NAIL_NOTICE` and every entry in
## `BaleInterior2D.NOTICES` -- Level 1's two interiors, named here by class. It worked for
## them and silently did nothing for anybody else: Piyesta's rooms carry an `onward_note`
## apiece, and those three sentences could be written to the bar and never taken off it,
## because they were not on the list. A room's notice is a STANDING prompt with no dwell, so
## "Not yet -- the kandila first" followed the player out of the church and through the rest
## of the level.
##
## Remembering the last write is both narrower and more general: it clears exactly the
## sentence this handler put up, leaves anything written since alone, and needs no room class
## to know it exists. The guard the old version was reaching for is kept -- it is the
## comparison against `current_text`, not the list.
func _on_room_notice_left() -> void:
	if hint_bar == null or _room_notice.is_empty():
		return
	if hint_bar.current_text() == _room_notice:
		hint_bar.clear()
	_room_notice = ""


## THE ONE PLACE THE GAME SAYS "THIS IS YOURS NOW".
##
## Every acquisition in the level goes through here rather than each one inventing its own
## feedback, which is how the level ended up with two sparkles, four lines of grey status
## text and one pickup -- the hidden flower -- that said nothing whatsoever. A reward should
## not look different according to which room it was found in.
##
## Safe to call with no overlay: fixtures that build the level headless still run every one
## of these call sites, and none of them should have to check first.
func announce_acquisition(title: String, note: String, art: Texture2D = null) -> void:
	if acquired_overlay == null or not is_instance_valid(acquired_overlay):
		return
	acquired_overlay.present(title, note, art)


## Lola's canvas, off the floor of her own house.
##
## IT USED TO SAY "ON THE NAIL. JUST AS SHE SAID." That line is `L1_N3.attic.found` and it is
## about the BRASS in the roof space on the Artist route -- the one line in the level that
## fires from a timer while the player is walking about. Firing it here meant picking the
## canvas up was answered with a sentence about something else entirely, in a room the player
## had already searched, which is exactly what "dialogue pops up randomly" looks like from the
## outside. The canvas has its own beat now.
const RUN_STATE_GROUP := &"level_run_state"

var _taken_this_run: Dictionary = {}
## The mark standing at each beat that writes a checkpoint on commit, by obstacle id.
var _commit_marks: Dictionary = {}


## Whether this run of the level has already given `pickup_id` away. Rooms ask this instead
## of the profile before deciding whether to draw what they are holding.
func pickup_taken_this_run(pickup_id: String) -> bool:
	return bool(_taken_this_run.get(pickup_id, false))


func note_pickup_taken(pickup_id: String) -> void:
	_taken_this_run[pickup_id] = true


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
		"level": _level_run_state(),
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
	_restore_level_run_state(state.get("level", {}))

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
## TWO CHANNELS, and which one a line takes is a statement about what the line is FOR.
##
## A beat of story goes to the framed box: queued, one line at a time, the player turning
## the page, the world stopped and the camera pushed in on whoever is speaking. A hint goes
## to the bar: no key, no pause, clears itself. They were sharing one box, and that could
## only ever be wrong for one of them -- in practice it was wrong for both, because the
## hint froze the game AND the story went past unread.
##
## Unread is not an exaggeration. This used to hand a whole beat over in one synchronous
## loop, writing five lines into the same label in the same frame. Only the last survived.
func _speak(lines: Array) -> void:
	var beat: Array[Dictionary] = []
	# GATHERED, NOT WRITTEN STRAIGHT THROUGH. Handing each hint to the bar as it came out of
	# the loop meant a beat of several hints was several writes to one label inside one frame,
	# and only the last of them was ever drawn -- the same defect this function's own comment
	# records fixing for the story box. `L1_N2.teach` is three lines and is the only statement
	# of the straw heap's puzzle in the game; the player was shown one of them.
	var advice: Array[Dictionary] = []
	for line_value: Variant in lines:
		var line: Dictionary = line_value
		var text := script_lines.display_text(line)
		if text.is_empty():
			continue
		var speaker := String(line.get("speaker", "lolo"))
		if script_lines.kind_of(line) == "hint":
			advice.append({
				"text": text,
				"speaker": Lolo.SPEAKER if speaker == "lolo" else APO_SPEAKER,
			})
			continue
		beat.append({
			"text": text,
			"speaker": Lolo.SPEAKER if speaker == "lolo" else APO_SPEAKER,
			"at": speaker,
		})
	if beat.is_empty() or dialogue_box == null:
		if not beat.is_empty():
			status_label.text = String(beat[-1]["text"])
		_post_advice(advice)
		return
	# A hint left on screen under a conversation is the two channels talking at once. Taken
	# down BEFORE the advice of this same beat goes up, not after -- clearing afterwards is
	# what used to throw the hints away in a beat that carried both kinds.
	if hint_bar != null:
		hint_bar.clear()
	_focus_camera_for(String(beat[0]["at"]))
	dialogue_box.speak(beat)
	# The bar fades itself out and freezes its dwell while anybody is speaking, so advice
	# posted now waits under the conversation and plays out when the player has read it.
	_post_advice(advice)


func _post_advice(advice: Array[Dictionary]) -> void:
	if advice.is_empty():
		return
	if hint_bar == null:
		status_label.text = String(advice[-1]["text"])
		return
	hint_bar.show_beat(advice)


## Push the camera in on whoever is talking, and give it back when the beat is over.
func _focus_camera_for(speaker: String) -> void:
	# Reached through the baseplate, which owns it -- the level does not hold a reference,
	# and a `camera` of its own would be a second thing to keep pointed at the right node
	# every time the player is swapped.
	var world_camera := _world_camera()
	if world_camera == null:
		return
	# LET GO OF WHATEVER THE CAMERA WAS LOOKING AT. Stepping through a doorway teleports the
	# player thousands of units; a dialogue focus held on a speaker they have just left is
	# pointing at the wrong place by definition. It also has to be dropped BEFORE the zoom
	# is set, because set_base_zoom defers while a focus is held -- which is how a walk into
	# a room ended up drawn at the focus's 1.15 instead of the room's 2.
	world_camera.release_focus(0.0)
	var subject: Node2D = lolo if speaker == "lolo" and lolo != null else player
	if subject == null or not is_instance_valid(subject):
		return
	# A BEAT IN A ROOM DOES NOT PUSH IN THE WAY A BEAT IN A VALLEY DOES. The default lift
	# drops the camera 240 units below the speaker, which frames a figure against a hillside
	# and, in a room already seen at 2, puts the floor across half the screen and the roof
	# off the top of it. In here the camera stays at eye level and barely moves.
	# ANY inside, not just the heap's. This asked `_in_the_straw_room` while there was only
	# one room in the game; Ang Bale has an interior now, and a beat fired in there took the
	# valley framing -- which pushed the camera back out to 1 and put the player in a lit
	# box in the corner of a black screen. The question was always "is this a room", so it
	# is asked that way.
	if _room_holding_player() != null:
		world_camera.focus_on(subject, 1.04, 0.45, -18.0)
	else:
		world_camera.focus_on(subject)
	if not dialogue_box.conversation_finished.is_connected(_release_camera_focus):
		dialogue_box.conversation_finished.connect(_release_camera_focus)


## THE CAVE, WHICH HAD NEVER SPOKEN TO ANYBODY. `passage_blocked` and `passage_allowed` had
## no way to fire until ConceptGate2D grew a trigger, and the level answered the first of them
## with `status_label.text` -- the small grey line in the corner that the next status message
## overwrites. It is the hint channel now, and it fires the beat's own hook, which is also
## what makes the board beside the cave readable at all.
func _on_flower_found(_collectible_id: String) -> void:
	announce_acquisition("Hidden Flower",
		"One of five. Lola pressed them between the pages.",
		HiddenFlower2D.ART)


func _release_camera_focus() -> void:
	var world_camera := _world_camera()
	if world_camera != null:
		world_camera.release_focus()


func _world_camera() -> WorldCameraController:
	var baseplate := get_node_or_null(^"EnvironmentBaseplate")
	if baseplate == null:
		return null
	return baseplate.get("camera") as WorldCameraController


## The refusal beat. It fires on the FIRST decline anywhere in the level and never again,
## and it is scripted as dialogue rather than as a rejection: the model is not rigged to
## fail, and the player is not being told they drew badly. No ink is spent -- the panel
## already released it before this runs.
func _on_recognition_declined(_entity: String, _confidence: float, _margin: float, reason: String) -> void:
	if director != null:
		director.note_decline(reason)
	if _refusal_spoken:
		return
	var lines := script_lines.fire("on_first_decline")
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
	_last_confidence = float(_response.get("confidence", 0.0))
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
		var first_time := not PlayerProfile.has_object(entity_id)
		if not first_time:
			# Re-summoning an object the player already owns is free: refund the
			# reservation and mark the item settled so no later path charges it.
			ink_manager.release_attempt()
			item.ink_committed = true
		else:
			PlayerProfile.record_object_acquired(entity_id)
		_begin_new_utility(item, first_time)
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
	# A NEW LIFE, not the remains of the old one. Drawing a second creature over the first
	# is a fresh drawing and it starts full -- otherwise the cheapest way to keep a body
	# alive forever would be to redraw it a second before it died.
	morph_life.begin(label, entity_id)
	if morph_card != null:
		morph_card.show_form(label, drawing, _last_confidence)
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
## `first_time` is whether this CLASS is new to the player, not whether the bag was empty.
## The card is for acquiring something; the fifth axe of the run is a tool coming out of the
## bag, and dimming the screen for it would make the reward beat into a loading screen.
func _begin_new_utility(item: DrawnItemData, first_time: bool = true) -> void:
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
	if not first_time:
		return
	# The player's OWN drawing, paper knocked out, held up for a second. This is the moment
	# the recogniser agreed with them, and it was a line of grey text in the corner.
	announce_acquisition(item.display_name,
		"In your bag — press %d to use it" % (slot + 1),
		DrawingSkin2D.thumbnail(item.image))


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
	# R8 in GATES.md is only true if the player KNOWS it is true. A player who believes a
	# placement is permanent plays the rest of the level as though it were.
	if tutorial != null:
		tutorial.note("placement_confirmed")
	# Judged HERE and not at recognition. A square that was drawn but never put down has
	# not bridged anything, and letting the gap solve on recognition would mean the
	# tutorial's one lesson -- that you place what you draw -- could be skipped.
	_judge_submission(item.entity_id, item.strokes)


func _on_placement_canceled(item: DrawnItemData, source_slot: int) -> void:
	var slot := inventory_manager.add_item(item, source_slot)
	if slot >= 0:
		if not item.ink_committed:
			ink_manager.commit_attempt()
			item.ink_committed = true
		status_label.text = "%s stored in slot %d" % [item.display_name, slot + 1]
		if tutorial != null:
			tutorial.note("item_stored")
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
	# The mouse is all three halves of placement and the game never said so anywhere.
	if tutorial != null:
		tutorial.note("placement_started")
	if not valid:
		status_label.text = "No room there — aim at a clearer spot"
	elif placement_controller.is_held_by_room():
		# Said differently from the reach limit on purpose. Inside a room the wall is much
		# nearer than arm's length, and "at arm's reach" sends the player looking for a
		# problem with their own reach that is not there.
		status_label.text = "That is as far as this room goes — click to set it down here"
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
	# second copy in. Without this, a pickup request on a held axe handed the inventory an
	# axe it was already holding and duplicated it every time it was stowed.
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
	if tutorial != null:
		tutorial.note("item_stored")


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


## True when it actually reached something, so the interact key can fall through to
## whatever else is standing here.
func _interact_with_nearest_utility() -> bool:
	var nearest := _nearest_interactable_utility()
	if nearest == null:
		return false
	_connect_utility(nearest)
	nearest.interact(player)
	return true


## One range query shared by the key and its prompt. If these were two loops, the most
## damaging possible UI bug would be easy to write: an E chip hovering over the apo while
## E itself reaches nothing, or a silent pickup that the HUD claims is out of range.
func _nearest_interactable_utility() -> PhysicsShapeObject:
	if player == null or not is_instance_valid(player):
		return null
	var origin := _player_anchor_position()
	var nearest: PhysicsShapeObject = null
	var nearest_distance := 96.0
	# `placed_drawings`, not `drawn_utilities`: the second group is joined by UtilityObject
	# alone, so a placed square or triangle was not in it and E walked straight past the one
	# thing the player most wanted to pick back up.
	for candidate in get_tree().get_nodes_in_group(&"placed_drawings"):
		var utility := candidate as PhysicsShapeObject
		if utility == null or utility.is_preview:
			continue
		# A held tool keeps its placed_drawings group when it is reparented to the grip, but
		# it is not in the world and E is not how it is put away (its inventory slot is).
		# Skipping everything outside WorldItemRoot lets a nearby placed drawing still offer
		# E while the tool in hand independently offers F.
		if utility == _equipped_utility or utility.get_parent() != world_item_root:
			continue
		# Measured to the object's SURFACE. Against its centre, a standing ladder was
		# 122px away from someone with their hand on it and E could never reach it --
		# and it got worse the moment ladders were given their proper height.
		var distance := utility.distance_from(origin)
		if distance <= nearest_distance:
			nearest = utility
			nearest_distance = distance
	return nearest


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


## Availability is refreshed from the same objects the actions use. R is intentionally
## absent here because it is always available; the prompt controller keeps it standing.
func _refresh_action_prompts() -> void:
	if action_prompts == null:
		return
	action_prompts.follow(player)
	_tick_tutorial()
	var can_act := not _level_completed \
		and player != null and is_instance_valid(player) \
		and not placement_controller.is_placing()
	action_prompts.set_revert_available(can_act and not (player is Wanderer))

	var pickup: PhysicsShapeObject = _nearest_interactable_utility() if can_act else null
	var can_pick_up := pickup != null
	action_prompts.set_pickup_available(
		can_pick_up,
		_drawing_display_name(pickup) if can_pick_up else "")

	var can_use := can_act and _equipped_utility != null \
		and is_instance_valid(_equipped_utility) \
		and _equipped_utility.is_held_tool()
	action_prompts.set_use_available(
		can_use,
		_drawing_display_name(_equipped_utility) if can_use else "")
	# Both read off state this function already computed rather than re-deriving it: the
	# prompt appearing IS the moment the verb became available, which is the moment to say
	# what it does.
	if tutorial != null and can_use:
		tutorial.note("tool_held")


## The lessons that have no event to hang off, polled once a frame beside the prompts that
## already are.
##
## WALKING IS NOT AN EVENT THE LEVEL OWNS. There is no signal for "the player moved"; the
## wanderer reads the input axis itself. So the first press is polled here, which is the
## same physics step _refresh_action_prompts already runs in -- and once `move` is spent
## the poll is a dictionary miss in TutorialDirector.note.
##
## `level_start` waits for a player to exist. _ready runs before the first body is adopted,
## and a lesson taught to an empty screen is a lesson nobody reads.
func _tick_tutorial() -> void:
	if tutorial == null or player == null or not is_instance_valid(player):
		return
	tutorial.note("level_start")
	if not _has_moved and absf(Input.get_axis("move_left", "move_right")) > 0.05:
		_has_moved = true
	if _has_moved:
		tutorial.note("moved")


func _drawing_display_name(drawing: PhysicsShapeObject) -> String:
	if drawing == null or not is_instance_valid(drawing):
		return ""
	if drawing.item_data != null and not drawing.item_data.display_name.is_empty():
		return drawing.item_data.display_name
	return drawing.name.replace("_", " ").capitalize()


func _drop_equipped_before_morph(previous_state: Dictionary) -> void:
	if _equipped_utility == null or not is_instance_valid(_equipped_utility):
		_equipped_utility = null
		return
	var drop_position := Vector2(previous_state.get("position", spawn_point.global_position))
	_equipped_utility.drop_to_world(world_item_root, drop_position)
	# AND TELL IT HOW BIG THE WORLD IS, which only _on_placement_confirmed was doing.
	# PhysicsShapeObject clamps itself back into Rect2(0, -520, 3760, 1200) when it is not
	# told otherwise, and both interiors sit a thousand units above the top of that -- so a
	# tool dropped by a morph inside a room was teleported out of the room and down into the
	# valley on its first physics tick.
	if _equipped_utility.has_method("set_world_bounds"):
		_equipped_utility.call("set_world_bounds", Rect2(environment.get("world_bounds")))
	_equipped_utility = null


## One frame, top left, holding everything the player is actually tracking: what they
## currently ARE and how much of it is left, the brush and what is in it, and whatever the
## game last said. See HudPanel for why the plate at the top is shaped like a nameplate and
## why the frame around all of it came back.
func _build_hud_frame() -> void:
	hud_panel = HudPanel.new()
	hud_panel.name = "HudPanel"
	hud_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud_panel.offset_left = 24.0
	hud_panel.offset_top = 20.0
	# Wide enough for the brush at full size INSIDE the frame's padding: 366 of artwork plus
	# fourteen either side. At 404 the content box came out 352 and InkBrush, which only
	# scales in whole art pixels, quietly dropped to five -- the brush got smaller and
	# nothing said why.
	hud_panel.offset_right = 24.0 + 366.0 + 28.0
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
	_build_morph_card()
	_build_action_prompts()
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
	hint_bar = HintBar.new()
	hint_bar.name = "HintBar"
	layer.add_child(hint_bar)


## The top-right corner: what the player currently IS.
##
## THIS REPLACED THE OLD TOP-RIGHT R-DRAW CHIP. Drawing now has one dedicated prompt at the
## lower left, so the corner is free for something that changes.
func _build_morph_card() -> void:
	draw_button.visible = false
	morph_card = MorphCard.new()
	morph_card.name = "MorphCard"
	morph_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	morph_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	# Anchored by its RIGHT edge, so a long creature name grows the card leftward into the
	# sky instead of pushing the slot off the side of the screen.
	morph_card.offset_left = -(MorphCard.PLATE.x + MorphCard.PORTRAIT - MorphCard.OVERLAP) - 24.0
	morph_card.offset_right = -24.0
	morph_card.offset_top = 20.0
	$CanvasLayer.add_child(morph_card)


## The old controls legend advertised six actions from the first frame, including four
## that could do nothing. Each verb now owns its availability and presentation. The old
## HintLabel remains authored in the scene only as a compatibility node; it never draws.
func _build_action_prompts() -> void:
	var old_legend := $CanvasLayer/HintLabel as Label
	if old_legend != null:
		old_legend.visible = false
	action_prompts = ActionPromptHUD.new()
	action_prompts.name = "ActionPrompts"
	$CanvasLayer.add_child(action_prompts)
	action_prompts.bind_draw_button(draw_button)
	action_prompts.interact_requested.connect(func() -> void: _interact_with_nearest_utility())
	action_prompts.use_requested.connect(_use_equipped_utility)
	action_prompts.revert_requested.connect(_revert_to_base_form)


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


## The drawing's clock moved. The HUD is the only thing that cares every frame; the level
## itself only wants to know once, when it gets low enough to be worth saying.
func _on_life_changed(remaining: float, capacity: float) -> void:
	if morph_card != null:
		morph_card.set_life(remaining, capacity)
	if morph_life.consume_warning():
		# THE HINT CHANNEL, not the dialogue box. A story beat stops the tree until the
		# player turns the page, and running low is exactly the moment they are mid-jump
		# over something -- see AGENTS.md on the two channels.
		hint_bar.show_hint("The %s is fading" % _current_form_name.to_lower())
		# AFTER the warning, not instead of it: the warning says WHAT is happening and the
		# lesson says what it means. The bar queues them; it does not stack them.
		if tutorial != null:
			tutorial.note("morph_low")


## The drawing died of its own accord.
##
## REVERTED THROUGH THE SAME DOOR Q USES, deliberately. _revert_to_base_form already puts
## the apo down where the creature was standing, re-homes anything it was carrying, and
## files the telemetry -- an expiry that did its own version of that would be a second copy
## of the one piece of code in this file most likely to strand the player in a wall.
##
## The status line is then overwritten, because Q's wording is about a choice the player
## made and this was not one.
func _on_life_expired() -> void:
	var was := _current_form_name
	_revert_to_base_form()
	if was.is_empty():
		status_label.text = "The drawing did not last"
	else:
		status_label.text = "The %s ran out — you are yourself again" % was.to_lower()


## What the player currently IS. An empty name means the apo, which has no card at all.
##
## The card wants the DRAWING, and MorphLife only knows names -- it is a clock, and handing
## it an Image to carry around would make it one. So the picture is set at the morph site,
## where the submitted image is in hand, and this only has to answer the empty case.
func _on_form_changed(form_name: String, _form_id: String) -> void:
	if morph_card != null and form_name.is_empty():
		morph_card.hide_form()
	if tutorial != null and not form_name.is_empty():
		tutorial.note("became_creature")


func _on_ink_changed(remaining: float, capacity: float, reserved: float) -> void:
	if hud_panel != null:
		hud_panel.set_ink(remaining, capacity, reserved)
	# Only once something has actually been spent. Ink explained against a full bar is a
	# rule about a resource the player has not yet had a reason to care about.
	if tutorial != null and remaining < capacity - 0.01:
		tutorial.note("ink_spent")


func _physics_process(_delta: float) -> void:
	_refresh_action_prompts()
	if _level_completed or goal_marker == null:
		return
	if player == null or not is_instance_valid(player):
		return
	_refresh_room_framing()
	_offer_the_nearest_sign()
	var anchor_position := player.global_position
	if player.has_method("get_physics_anchor"):
		var anchor := player.call("get_physics_anchor") as Node2D
		if anchor != null:
			anchor_position = anchor.global_position
	_level_physics(anchor_position)
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
			# POINTED AT THE ANSWER, not at the problem. It used to say "draw something that
			# can cross it", which is what the beat asked for when Span came first -- and
			# Span cannot cross three hundred pixels of water. The way over is the plank.
			_return_to_safety("You cannot swim, apo — put something heavy on that plank",
				"You cannot swim, apo. Back to %s")
			return
	else:
		_submerged_seconds = 0.0
	# ⚠ A DISTANCE TO THE MARKER MEANS NOTHING FROM INSIDE A ROOM. Both insides are parked in
	# the empty sky a couple of thousand units above the terraces, so the readout counted down
	# to a number that had no relation to anything the player could walk toward -- and the way
	# out of the room is what they actually have to reach. The room's own notices carry that,
	# so the strip stands down rather than lying.
	if _room_holding_player() != null:
		goal_label.text = ""
		return
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
		_say_why(nothing_written)
	else:
		_say_why(restored_format % restored)


## Why the player is suddenly standing somewhere else.
##
## IT USED TO GO TO A LABEL IN THE CORNER, forty pixels tall in the top left of a
## sixteen-hundred-pixel screen, while the camera was busy carrying the player back across
## the level -- so "you cannot swim, apo, draw something that can cross it" was written in
## the one place nobody was looking at the one moment they were looking somewhere else.
## Being fished out of the water and not knowing why is most of what makes the paddy read
## as a bug rather than as a gate.
##
## The hint bar is the channel for this: centre screen, above the hotbar, no key to press,
## and it stays up until something replaces it. The status label keeps it too, because it
## is the transcript of what the level has said and costs nothing.
func _say_why(text: String) -> void:
	status_label.text = text
	if hint_bar != null:
		hint_bar.show_hint(text, Lolo.SPEAKER)


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
	morph_life.clear()
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
	if action_prompts != null:
		action_prompts.follow(new_player)
	if lolo != null and is_instance_valid(lolo):
		lolo.follow(new_player)
	# Whoever the player is now, a loose floating tread has to ignore them -- see
	# FloatingTread2D.except_player. It is re-pointed here rather than watched from the
	# tread, because this is already the one place in the game that anything about who the
	# player is may change, and a fourth swap path is a fourth chance to forget one.
	for node in get_tree().get_nodes_in_group(&"floating_treads"):
		if node.has_method("except_player"):
			node.call("except_player", new_player)
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
	if hint_bar != null:
		lolo.set_hint_bar(hint_bar)
	_greet()


## The two set-piece lines from the old script -- the greeting and the arrival after the
## memory -- are story, not hints, so they take the framed box like everything else that
## is. They are single-line beats, which the queue handles as a conversation of one.
func _lolo_says(key: String, seconds: float = 0.0) -> void:
	if lolo == null or not is_instance_valid(lolo):
		return
	var line := String(_script_lines.get(key, ""))
	if line.is_empty():
		return
	if dialogue_box == null:
		lolo.say(line, seconds)
		return
	_focus_camera_for("lolo")
	dialogue_box.speak([{"text": line, "speaker": Lolo.SPEAKER}])


## THE OPENING IS ONE BEAT NOW, AND THIS IS NOT IT.
##
## The level used to open with three stop-the-world events inside the first forty pixels:
## this greeting, then `B0_HAGDAN.enter` (two lines) the moment the player took a step, then
## a readable signpost lighting up at their feet. Two of those were the game explaining
## itself twice before it had said anything once.
##
## The trigger moved east -- B0_HAGDAN spans 430-950 now, as LEVEL_1.md always said it did --
## so `.enter` fires after a walk instead of after a footstep, and it is the level's one
## opening CONVERSATION. This line stays, because "press R and draw" is the only place the
## player is told what the game is, but it goes on the HINT channel where an instruction
## belongs: no pause, no key, and it clears itself when the stair beat arrives. It is also
## the out-of-voice line the old dialogue.json still carries, which is a second reason not
## to give it the framed box that Payyo's own script is written for.
## The full bag screen, and its place in the queue of things Escape backs out of.
##
## THE CHAIN IS DATA, NOT NODE ORDER (see UIRouter), and it is authored in game_level.tscn --
## but this screen is built here rather than instanced, so it inserts itself. It goes in
## AHEAD of the pause menu and behind everything else: Escape should close the bag rather
## than open the pause menu over the top of it, and it should not outrank a confirmation.
func _build_inventory_screen() -> void:
	inventory_screen = InventoryScreen.new()
	inventory_screen.name = "InventoryScreen"
	add_child(inventory_screen)
	inventory_screen.wire(inventory_manager, registry)
	inventory_screen.slot_activated.connect(_on_inventory_slot_pressed)
	var router := get_node_or_null(^"UIRouter")
	if router == null:
		return
	var chain: Array[NodePath] = router.get(&"cancel_chain")
	var at := chain.size()
	for index in range(chain.size()):
		if String(chain[index]).get_file() == "PauseMenu":
			at = index
			break
	chain.insert(at, router.get_path_to(inventory_screen))
	router.set(&"cancel_chain", chain)


## The bag, opened deliberately. Refused while the drawing panel is up or something is being
## placed: both of those are already a mode the player is in the middle of, and a second
## full-screen thing over the top of either is a way to lose a drawing.
func _toggle_inventory_screen() -> void:
	if inventory_screen == null or not is_instance_valid(inventory_screen):
		return
	if inventory_screen.is_open():
		inventory_screen.close()
		return
	if draw_panel != null and draw_panel.has_method("is_open") and bool(draw_panel.is_open()):
		return
	if placement_controller != null and placement_controller.is_placing():
		return
	inventory_screen.open()


func _greet() -> void:
	if lolo == null or not is_instance_valid(lolo):
		return
	var line := String(_script_lines.get("greeting", ""))
	if line.is_empty():
		return
	lolo.say(line)


func _wire_dialogue_node() -> void:
	if dialogue_node == null:
		return
	dialogue_node.approached.connect(_on_dialogue_node_approached)
	dialogue_node.route_chosen.connect(_on_route_chosen)
	dialogue_overlay.connect(&"route_picked", _on_route_picked)
	memory_overlay.connect(&"dismissed", func() -> void: _lolo_says("arrival"))


## WHAT EACH ANSWER WILL ASK FOR, read off the level's own route data.
##
## The three buttons are sentences Lolo says and name nothing drawable, which is right --
## the level never names a class. But they named no ABILITY either, and the requirement was
## taught seconds before as three hint lines that the choice itself interrupts. So a player
## picked a sentence and was then instructed in something they had not heard. This puts the
## route's own requirement on its own button, phrased by the same function the requirement
## strip uses, so the two cannot drift.
func _requirements_per_route(obstacle_id: String) -> Dictionary:
	var notes: Dictionary = {}
	if director == null:
		return notes
	var routes: Dictionary = director.obstacle(obstacle_id).get("routes", {})
	for route_value: Variant in routes.keys():
		var route := String(route_value)
		var spec: Dictionary = routes[route]
		notes[route] = RequirementStrip.phrase(
			spec.get("required_tags", []), String(spec.get("match", "all")))
	return notes


## Lolo pauses time to talk (Game Design section 3). The overlay is what does the
## pausing -- it is a ModalOverlay, and UIRouter derives the tree's pause state from
## whoever is open -- so this only has to decide what he asks.
func _on_dialogue_node_approached() -> void:
	if lolo != null and is_instance_valid(lolo):
		lolo.hush()
	# Payyo's own script, when it has one. The three buttons are read off the commit
	# lines rather than authored twice, so the button and the line the apo says when it
	# is pressed are literally the same string and cannot drift.
	var node_obstacle := _dialogue_node_obstacle_id()
	var choices: Dictionary = script_lines.choices_for(node_obstacle) \
		if script_lines != null and not node_obstacle.is_empty() else {}
	if not choices.is_empty():
		var context := ""
		for line_value: Variant in script_lines.peek("%s.choice" % node_obstacle):
			context = String((line_value as Dictionary).get("text", ""))
		dialogue_overlay.call("present", "Lolo", context, choices,
			_requirements_per_route(node_obstacle))
		_frame_the_decision()
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
	_frame_the_decision()


## A DECISION IS FRAMED ON THE PLAYER, and it had no framing of its own at all.
##
## The choice screen inherited whatever the camera happened to be holding when it opened,
## which is a push-in on the last person who spoke -- taken by a beat that fired somewhere
## back along the terrace and never given back, because the box was hidden rather than
## finished (see DialogueBox.hide_line). So the world behind the three answers was a shot of
## a stretch of terrace or a marker the player had walked past, and the character the
## decision is ABOUT was off screen entirely.
##
## Called AFTER `present`, deliberately: opening the overlay takes the running line down,
## which is what releases the stale focus, and doing this before that would be undone by it.
func _frame_the_decision() -> void:
	var world_camera := _world_camera()
	if world_camera == null:
		return
	# AND FRAMING IT MEANS GIVING THE CAMERA BACK, not taking it. A push-in behind a panel
	# that fills the middle of the screen frames nothing anybody can see; what the player
	# needs is for the shot to be the shot they were playing in, so that the moment they
	# answer they are looking at themselves and at the thing they just decided about. The
	# ordinary follow does that already -- the bug was only ever that a stale focus from a
	# beat two hundred units back was still holding it.
	world_camera.release_focus(0.0)


func _on_route_picked(route: String) -> void:
	# The decision held the camera; answering it gives the camera back. A commit line then
	# takes its own focus a moment later, and one that does not leaves the player followed
	# normally rather than pinned to where they were standing when they answered.
	_release_camera_focus()
	if dialogue_node != null:
		dialogue_node.choose(route)


## The answer physically alters the level: one branch opens, the other two are freed.
func _on_route_chosen(route: String) -> void:
	if route_layout != null:
		route_layout.apply_route(route)
	# The single write: the tally, the checkpoint and the telemetry all happen inside
	# commit_route, and the commit line Lolo speaks is fired from route_committed.
	if director != null:
		director.commit_route(_dialogue_node_obstacle_id(), route)
	else:
		var routes: Dictionary = _script_lines.get("routes", {})
		if lolo != null and is_instance_valid(lolo):
			var chosen := String(routes.get(route, ""))
			if not chosen.is_empty() and dialogue_box != null:
				_focus_camera_for("lolo")
				dialogue_box.speak([{"text": chosen, "speaker": Lolo.SPEAKER}])
		status_label.text = "Route: %s" % route.capitalize()


## The Empathy route's reward, shown once the player has actually crossed the gorge
## they chose to rebuild rather than the moment they chose to.
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
	# STAGED BEFORE THE PANEL. The level used to end by putting a screen over an unchanged
	# view -- the last thing the player did and the acknowledgement of it happened at the same
	# size as walking around. The bars come in on the terrace she is standing on, hold for a
	# beat with her name for the level in them, and the panel arrives into that.
	if cinematic != null:
		cinematic.close("PAYYO")
		await get_tree().create_timer(1.1, true, false, true).timeout
	# The transition used to fire HERE, on the same frame, so the one moment the game
	# acknowledges the player lasted a frame and was never read. It now waits for them.
	complete_overlay.call("present", run_stats())
	if cinematic != null:
		cinematic.open()


## Whether the run ends with this level, or the level select comes next. The branch
## lives here rather than in the overlay so the overlay stays a view, and it is read
## from the catalog so that when levels 2-5 exist only level 5 carries the flag.
func _on_complete_continue() -> void:
	var ends_run := bool(LevelManager.get_level(LevelManager.current_level_id).get("ends_run", false))
	if ends_run and LevelManager.show_ending():
		return
	LevelManager.return_to_house()


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
