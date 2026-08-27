extends Node2D

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
const FOUND_KEY := "L1_bale_key"

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
## What the recogniser scored the sketch that is currently being adopted.
##
## Carried on the level rather than threaded through _spawn_or_replace, which is called from
## three places and cares about none of it. The score belongs to the SUBMISSION, and the
## submission is the thing that set this a moment before the morph -- see _on_drawing_ready.
var _last_confidence := 0.0
## Where the apo was standing on the terrace when they got into Ang Bale, so the ladder puts
## them back there rather than at a guess. Remembered on the way in, like _straw_return.
var _bale_return := Vector2.ZERO
## The inside the camera and the placement reach are currently framed for, or null for the
## level itself. See _refresh_room_framing.
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
var _straw_return := Vector2.ZERO
## Whether she is standing in the heap's doorway, and so whether Down means "go in".
var _at_straw_mouth := false
## The "press E to read" prompt while it is up, so the hint bar is written to on the frame
## it changes rather than on every frame the player stands still -- and so it can be taken
## down again only while it is still the thing on the bar.
var _sign_prompt := ""
## Ang Bale's padlock, which judges the STROKES of a drawn key rather than its class.
var ward_lock: WardLock2D
## The same, for the offer to open Ang Bale with the key found in the heap.
var _key_prompt := ""
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
	# Findable by the rooms, which have to ask what this RUN has already handed over rather
	# than what the profile remembers forever. See pickup_taken_this_run.
	add_to_group(RUN_STATE_GROUP)
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
	if event.is_action_pressed("move_down") and _at_straw_mouth:
		get_viewport().set_input_as_handled()
		_on_straw_entered()
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		# A drawing you can reach comes first. Both are "the thing in front of you" and
		# both are on one key, but only one of them is something the player put there --
		# reading a board instead of picking up the ladder you just placed would be the
		# game ignoring you, while the reverse is a key press that says nothing this time.
		if not _interact_with_nearest_utility() and not _use_the_found_key():
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
	if not director.load_level():
		push_warning("GameLevel: no level data; obstacles will accept nothing")

	checkpoints = CheckpointManager.new()
	checkpoints.name = "CheckpointManager"
	add_child(checkpoints)

	script_lines_l1 = DialogueScript.new()
	script_lines_l1.load_from("res://config/dialogue_l1.json")

	# Ang Bale's padlock. It draws nothing and sits nowhere -- it is a measurement, not a
	# prop -- so it is built here beside the director rather than authored into the scene.
	# level_01.json has declared L1_N3's Pragmatist route as `ward_matching_sequence` since
	# the route existed; until now nothing read that, the route was a plain Unlock tag
	# check, and WardLock2D was a class with a unit test and no caller.
	ward_lock = WardLock2D.new()
	ward_lock.name = "WardLock"
	add_child(ward_lock)

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

	# WALKING INTO THE HEAP IS FINDING THE CHEST. Node 2's routes uncover it too, and
	# reveal() is idempotent, so a player who searches the straw first and one who simply
	# ducks inside both end up looking at the same thing -- but the room is drawn the moment
	# she is in it, and an interior with a picture on the wall and nothing on the floor is a
	# room the level forgot to furnish.
	for node in get_tree().get_nodes_in_group(&"bale_interiors"):
		if node.has_signal(&"exit_reached"):
			node.connect(&"exit_reached", _on_bale_exit)
		if node.has_signal(&"painting_taken"):
			node.connect(&"painting_taken", _on_painting_taken)
		# What is in the room besides the canvas. The HINT channel, not the story box: none
		# of it is a beat, none of it may pause the world, and it clears itself.
		if node.has_signal(&"noticed"):
			node.connect(&"noticed", _on_room_notice)
		if node.has_signal(&"notice_left"):
			node.connect(&"notice_left", _on_room_notice_left)

	for node in get_tree().get_nodes_in_group(&"straw_piles"):
		if node.has_signal(&"at_mouth"):
			node.connect(&"at_mouth", _on_straw_mouth)
	for node in get_tree().get_nodes_in_group(&"straw_rooms"):
		if node.has_signal(&"key_taken"):
			node.connect(&"key_taken", _on_straw_key_taken)
		if node.has_signal(&"exit_reached"):
			node.connect(&"exit_reached", _on_straw_exit)
		# The heap's inside says things now too. It is the one room in the level with a
		# PUZZLE in it, and it was saying nothing at all -- see StrawRoom2D's nail notice.
		if node.has_signal(&"noticed"):
			node.connect(&"noticed", _on_room_notice)
		if node.has_signal(&"notice_left"):
			node.connect(&"notice_left", _on_room_notice_left)

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
	var at := Vector2(volume.trigger_size.x * 0.5 - 40.0, 0.0)
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
	if hint_bar != null:
		hint_bar.show_hint("The level will remember you from here.", "", 3.0)
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio != null:
		audio.call("play_sfx", &"checkpoint")


func _on_obstacle_entered(obstacle_id: String) -> void:
	_speak_on_arrival("%s.enter" % obstacle_id)
	# A node teaches all three of its routes' verbs BEFORE the choice, because a player
	# cannot choose a path whose verb they have never been told.
	var teaches: Array = director.obstacle(obstacle_id).get("teaches_before_choice", [])
	if not teaches.is_empty():
		_speak(script_lines_l1.fire("%s.teach" % obstacle_id))
		director.teach_before_choice(obstacle_id)
	_speak_current_stage(obstacle_id)
	_refresh_requirements()


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
	if script_lines_l1.has_heard(hook):
		return
	_speak(script_lines_l1.fire(hook))


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
		if not script_lines_l1.has_heard(board.reads):
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
	var lines := script_lines_l1.fire(board.reads)
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
func _offer_the_found_key() -> void:
	if hint_bar == null:
		return
	if not _key_prompt.is_empty() and hint_bar.current_text() != _key_prompt:
		_key_prompt = ""
	if not _found_key_would_open():
		if not _key_prompt.is_empty():
			hint_bar.clear()
			_key_prompt = ""
		return
	if not _key_prompt.is_empty() or hint_bar.is_showing():
		return
	_key_prompt = "You are carrying her key  —  press %s to try it" \
		% ControlsKeys.keys_for("interact")
	hint_bar.show_hint(_key_prompt, Lolo.SPEAKER)


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
	requirement_strip.show_requirements(director.required_tags(), director.hint_tier(), owned,
		String(spec.get("match", "all")))


## The checkpoint is written HERE, on the commit, not on the solve -- so that every morph
## on the route is protected and a death cannot make the player answer Lolo twice.
func _on_obstacle_route_committed(obstacle_id: String, route: String) -> void:
	_speak(script_lines_l1.fire("%s.%s.commit" % [obstacle_id, route]))
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
func _judge_submission(entity_id: String, strokes: Array = []) -> void:
	if director == null or director.current_obstacle().is_empty():
		return
	if _ward_refuses(entity_id, strokes):
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
		_speak(script_lines_l1.fire("%s.%s.solved" % [
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
func _ward_refuses(entity_id: String, strokes: Array) -> bool:
	if ward_lock == null or entity_id != "key":
		return false
	if director.current_obstacle() != "L1_N3" or director.is_solved("L1_N3"):
		return false
	# A key with no strokes behind it is not a drawn key -- a fixture, or one restored from
	# a checkpoint. The lock has nothing to measure, so it stands aside and the ordinary
	# Unlock tag check answers.
	if strokes.is_empty():
		return false
	var turn := ward_lock.try_key(strokes)
	if bool(turn["opens"]):
		return false
	# It turned and stopped. The attempt is real and is counted as one, which is what moves
	# the hint tier -- the player tried and it did not work -- and it is counted WITHOUT a
	# class, because the class was right and the shape was wrong. Pushing it through
	# note_submission would need an entity id, and any id put there is a class nobody drew
	# landing in the per-class figures the evaluation rests on.
	director.note_failed_attempt("L1_N3", "ward_%s" % String(turn["reason"]))
	_refresh_requirements()
	_speak(script_lines_l1.fire("L1_N3.ward.fail%d" % int(turn["attempt"])))
	if hint_bar != null:
		hint_bar.show_hint(_ward_note(String(turn["reason"]), turn["measured"]),
			Lolo.SPEAKER)
	Telemetry.record_event("ward_attempt", {
		"level_id": LevelManager.current_level_id, "obstacle_id": "L1_N3",
		"attempt": turn["attempt"], "reason": turn["reason"], "measured": turn["measured"],
	})
	return true


## WHICH PROPERTY WAS WRONG, said out loud.
##
## The authored fail lines carry the drama and say nothing actionable -- "It turned, then
## stopped. The teeth are too thick." A player who cannot see what the lock measured has
## three tries at a shape nobody described, and the third opens it regardless, which turns
## the whole sequence into a wait rather than a puzzle.
##
## So the hint channel names the one measurement that failed, and the number it read, and
## never the number it wants. Knowing you drew four teeth when the lock counted them is
## enough to draw three; being told "draw three" is the spelling test this level is built
## to avoid.
func _ward_note(reason: String, measured: Dictionary) -> String:
	match reason:
		"bits":
			return "It counted %d teeth on that one." % int(measured.get("bits", 0))
		"depth":
			return "The teeth are the wrong depth for this ward."
		"aspect":
			return "Too stubby for that slot — a longer blade."
		_:
			return "It turned, and stopped."


## The key off the nail in the heap opens Ang Bale, and that is the whole chain: what you
## find in the heap is the way into the house, and what you find in the house is the
## painting of the next place.
##
## It answers the Pragmatist route, the one that asks for Unlock -- so a player who took the
## trouble to get up to the nail does not also have to draw a key, and one who never went
## inside still can. The route is committed the ordinary way rather than the obstacle being
## marked solved behind the director's back, so the tally, CP3 and the telemetry all record
## it exactly as they would a drawn key.
##
## NOT A TAG MATCH AND NOT ASSISTED EITHER. `note_submission` is the wrong door for this: it
## takes a recognised CLASS, and this is a thing already in the bag. It is recorded as its
## own kind of solve so Chapter 5 can count "opened it with the key they found" separately
## from "drew a key that fitted", which are different claims about the same lock.
func _use_the_found_key() -> bool:
	if director == null or director.current_obstacle() != "L1_N3":
		return false
	if director.is_solved("L1_N3"):
		return false
	if not PlayerProfile.is_collectible_found(FOUND_KEY):
		return false
	director.commit_route("L1_N3", "pragmatist")
	director.solve_with_item("L1_N3", FOUND_KEY)
	Telemetry.record_event("obstacle_solved", {
		"level_id": LevelManager.current_level_id,
		"obstacle_id": "L1_N3", "route": "pragmatist", "accepted_label": FOUND_KEY,
		"solved_with": "found_item", "attempts": director.attempts("L1_N3"),
		"hint_tier": director.hint_tier("L1_N3"), "assisted": false,
	})
	return true


## Whether the house can be opened with what is already in the bag, so the level can offer
## it rather than leaving the player to guess that a key they picked up an hour ago is the
## answer to the door in front of them.
func _found_key_would_open() -> bool:
	return director != null and director.current_obstacle() == "L1_N3" \
		and not director.is_solved("L1_N3") \
		and PlayerProfile.is_collectible_found(FOUND_KEY)


## A DRAWING THAT DOES NOT WORK USED TO SAY NOTHING AT ALL.
##
## This is the single biggest reason the hint ladder was not helping: a player could draw,
## place, and watch the thing land, and the game would not say whether it had even noticed.
## The verdict was computed, the attempt was counted, the tier moved -- and the only outward
## sign of any of it was a strip in the corner that says what is needed, never what was
## wrong with what you just tried. Drawing repeatedly into silence reads as a game that is
## broken, not as a game that is asking for something else.
##
## So a miss now answers, in the hint channel, which never stops play: what the thing you
## drew CAN do, and what this needs.
##
## IT NAMES THE PLAYER'S OWN DRAWING AND THAT IS ALLOWED. The rule the tag layer exists to
## hold is that the game must not name a class it would ACCEPT -- that turns a puzzle with
## four answers into a spelling test. Reflecting back the class the player themselves just
## chose gives away nothing they did not already know, and it is the same thing the strip
## already does at T2 with "you have drawn: circle". Without it the sentence has to say
## "that" and the player is left matching a pronoun to one of six things on screen.
func _say_it_did_not_fit(entity_id: String, verdict: Dictionary) -> void:
	if hint_bar == null:
		return
	var needed := _tag_phrase(verdict.get("required_tags", []),
		String(director.requirement_spec().get("match", "all")))
	if needed.is_empty():
		return
	var drawn := entity_id.replace("_", " ")
	var mine: Array = AbilityTags.tags_for_class(entity_id)
	var text := ""
	if mine.is_empty():
		# One of the roster's unhintable classes -- a clock, a bee. It carries no tag at
		# all, so there is nothing to contrast, only the requirement to repeat.
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
const BURROW_TAG := "burrow"


## Whether whatever the player currently IS can get in under the straw. The apo cannot; a
## drawing can, if it is one of the things `burrow` resolves to.
func _fits_through_the_straw() -> bool:
	if _current_form_id.is_empty():
		return false
	return AbilityTags.class_has_tag(_current_form_id, BURROW_TAG)


func _on_straw_mouth(standing: bool) -> void:
	_at_straw_mouth = standing
	if hint_bar == null:
		return
	if not standing:
		hint_bar.clear()
		return
	if _fits_through_the_straw():
		hint_bar.show_hint("You will fit under there  —  press %s"
			% ControlsKeys.keys_for("move_down"))
		return
	# The requirement, in the same words the strip and the route buttons use, so the heap
	# cannot describe itself differently from everything else that asks for something.
	hint_bar.show_hint("There is a way in under the straw, and you are too big for it.  %s"
		% RequirementStrip.phrase([BURROW_TAG]).replace("\n", "  —  "))


## Ducking into the heap, which is the only place in Level 1 with an inside -- and the
## inside is a room the size of a screen sitting in the empty sky above the level, not a
## cutaway of the heap where the heap stands. A little hole and a big room is the whole
## point of it, and it does not survive the two being the same size.
##
## It is the same body in the same level, so ink, the bag, the drawing panel and every
## checkpoint carry in with her. Lolo comes too without being asked: he teleports to his
## target past 900px and the room is thousands away.
func _on_straw_entered() -> void:
	# REFUSED, AND SAID SO. A press that does nothing and explains nothing is a press the
	# player concludes is broken -- and this one is the level's own design rule, not a bug.
	if not _fits_through_the_straw():
		_on_straw_mouth(true)
		return
	var room := get_tree().get_first_node_in_group(&"straw_rooms") as Node2D
	if room == null or player == null or not is_instance_valid(player):
		_uncover_the_baul()
		return
	# CLEAR OF THE MOUTH, or coming back out walks straight into it again and the room is a
	# trap. Remembered on the way in rather than computed on the way out, so it is the heap
	# she actually used.
	_straw_return = _beside_the_mouth()
	_step_through(Vector2(room.call("entry_point")))
	# ARRIVING FIRST, THEN THE CHEST. `speak` appends to the queue, so the order these are
	# called in is the order the player reads them -- and uncovering first put "Locked. Of
	# course.", which is the line that CLOSES this node, ahead of "you can stand up in here",
	# which is the line that opens the room. The player was told about a lock they had not
	# seen yet, in a room they had not been told they were in.
	_speak_on_arrival("L1_N2.inside")
	_uncover_the_baul()


func _on_straw_exit() -> void:
	if _straw_return != Vector2.ZERO:
		_step_through(_straw_return)


## A spot on the terrace beside the way in, far enough off it that walking out does not
## count as walking back in.
func _beside_the_mouth() -> Vector2:
	for node in get_tree().get_nodes_in_group(&"straw_piles"):
		var pile := node as Node2D
		if pile == null or not bool(pile.get("entrance")):
			continue
		var mouth := Rect2(pile.call("mouth_rect"))
		return pile.global_position + Vector2(mouth.position.x - 46.0, 0.0)
	return player.global_position if player != null else Vector2.ZERO


## Through the straw and out the other side. Deferred because both ends of this can run
## inside a body_entered callback, and moving the player out from under the physics
## mid-signal is the same class of mistake as switching an area's monitoring there.
##
## NO FADE, AND NO TRANSITION OF ANY KIND. It had one, and it was wrong: a doorway you have
## already chosen to walk through does not want a beat of black in the middle of it, and at
## a fifth of a second twice it read as the game stopping to load. Press down and you are
## inside.
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
func _on_straw_key_taken() -> void:
	_speak(script_lines_l1.fire("L1_N2.key"))
	_take_the_bale_key("off_the_nail")


## The brass key, however it was come by: off the nail inside the heap, or out of the wreck
## of one. StrawRoom2D writes the profile itself when the nail is reached, so this is
## idempotent on purpose -- it is the telemetry and the hint that must not fire twice, and
## the profile that must not care how many times it is told.
## GUARDED ON THIS RUN, NOT ON THE PROFILE. It is reached twice -- off the nail inside the
## heap, and out of the wreck of one scattered by the Protector route -- so it has to be
## idempotent. It was idempotent against `is_collectible_found`, which is permanent: on a
## second playthrough the key was still there on the nail, still walked into, and the game
## said nothing at all about it because a previous run had already been told.
func _take_the_bale_key(how: String) -> void:
	if pickup_taken_this_run(FOUND_KEY):
		return
	note_pickup_taken(FOUND_KEY)
	announce_acquisition("The Brass Key",
		"Too small for the chest. It belongs to a door you have only seen painted.",
		UIIcons.key())
	if PlayerProfile.is_collectible_found(FOUND_KEY):
		return
	PlayerProfile.record_collectible(FOUND_KEY)
	Telemetry.record_event("collectible", {
		"level_id": LevelManager.current_level_id,
		"obstacle_id": "L1_N2", "collectible": FOUND_KEY, "found_by": how,
	})


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
			# WRECKING THE HEAP TURNS THE KEY OUT OF IT. The nail is inside, out of reach,
			# and a player who blew the whole heap across the terrace has plainly got at
			# whatever was hanging in it -- refusing them the key would mean the fast route
			# locks the door the slow one opens. It is the same key by the same name, so
			# taking both routes cannot yield two.
			_take_the_bale_key("straw_scattered")
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
	# PAUSE-AWARE, all four of the level's narrative timers. `create_timer` counts down while
	# the tree is stopped unless it is told not to, and the tree is stopped exactly when a
	# beat is on screen being read -- so a beat timed to land a second and a half after the
	# last one landed while the player was still on the first line of it, and the two arrived
	# together. Waiting on real seconds that only pass while the game is running is what
	# "a beat later" was always supposed to mean.
	await get_tree().create_timer(0.7, false).timeout
	_speak(script_lines_l1.fire("L1_N2.artist.pass2"))
	await get_tree().create_timer(1.4, false).timeout
	_speak(script_lines_l1.fire("L1_N2.artist.pass3"))
	# What the page is FOR. Node 3's Artist route reads this flag, so the patient player
	# arrives already knowing where to look.
	script_lines_l1.set_flag("knows_about_key")
	Telemetry.record_event("route_reward", {
		"level_id": LevelManager.current_level_id,
		"obstacle_id": "L1_N2", "reward": "sketchbook_page", "sets_flag": "knows_about_key",
	})


## The chest, uncovered -- by the route that dug it out, or by ducking into the heap and
## finding it standing there.
##
## SAID ONCE. Both of those happen more than once: the route can be re-run and the heap can
## be walked into as often as the player likes, and every single entry re-fired "Locked. Of
## course." with the world stopped for it. A line that closes a beat is news the first time
## and an interruption every time after, which is the whole argument written on
## _speak_on_arrival -- so this goes through the same door.
func _uncover_the_baul() -> void:
	for node in get_tree().get_nodes_in_group(&"baul"):
		var chest := node as Baul2D
		if chest != null:
			chest.reveal()
	_speak_on_arrival("L1_N2.solved")


## Ang Bale: three ways into the same chest, and the third one costs something.
## GETTING IN IS THE SOLVE; THE PAINTING IS PICKED UP. It used to be granted here, the
## instant the route landed, which made the room a cutscene with a floor -- the reward
## arrived before the player had looked at anything. It leans against the wall in there now
## and is taken by walking into it, the same way the key in the heap is taken.
func _open_the_baul(route: String) -> void:
	# IN FIRST, THEN THE BEAT. The route lines are said by people standing in the house, and
	# saying them before the player is moved framed the camera on a speaker out on the
	# terrace while the apo was already a thousand units up in the room.
	await _into_the_bale()
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
	await get_tree().create_timer(search, false).timeout
	_speak(script_lines_l1.fire("L1_N3.attic.found"))
	await get_tree().create_timer(1.2, false).timeout
	_speak(script_lines_l1.fire("L1_N3.artist.photo"))
	Telemetry.record_event("route_reward", {
		"level_id": LevelManager.current_level_id,
		"obstacle_id": "L1_N3", "reward": "photograph_unnamed_woman",
		"knew_about_key": script_lines_l1.is_flag_set("knows_about_key"),
		"search_seconds": search,
	})


## In, by whichever way was taken.
##
## THE HOUSE HAS AN INSIDE, and this is where the player finally sees it. All three routes
## arrive here because all three are ways THROUGH THE SAME WALL -- over the thatch, through
## the door, or through the hasp -- and what is on the other side does not change according
## to how you got there. The beats above still differ; the room does not.
##
## It is the arrangement the heap already uses: the room is parked in the sky a long way
## from the terrace, and this is the same body walking into it, so ink, the bag and every
## checkpoint carry in. Where they came from is remembered on the way IN rather than worked
## out on the way out, so the ladder puts them back exactly where they were standing.
func _into_the_bale() -> void:
	var room := get_tree().get_first_node_in_group(&"bale_interiors") as Node2D
	if room == null or player == null or not is_instance_valid(player):
		return
	# IDEMPOTENT, and it has to be. Node 3 reaches this by more than one path -- the solve
	# and the route both arrive here -- and a second call while the player is already inside
	# would overwrite the terrace spot with a spot IN THE ROOM. The ladder would then put
	# them back into the house they had just climbed out of, which is a trap that only shows
	# up on the way out and reads as the exit being broken.
	if _room_holding_player() == room:
		return
	# The room was built when the level loaded and is being entered now; the profile may
	# have moved in between. See BaleInterior2D.refresh_from_profile.
	if room.has_method("refresh_from_profile"):
		room.call("refresh_from_profile")
	_bale_return = player.global_position
	_step_through(Vector2(room.call("entry_point")))
	# The step is deferred, so anything that frames a camera on the player has to wait a
	# frame for them to actually be in the room.
	await get_tree().process_frame
	await get_tree().process_frame


## Something in a room worth a sentence, and the sentence going away again.
##
## It takes the bar back down only if the bar is still saying what this put there -- one
## channel carries several voices, and clearing unconditionally takes somebody else's message
## with it. Same rule the straw mouth's prompt follows.
func _on_room_notice(text: String) -> void:
	if hint_bar != null:
		hint_bar.show_hint(text)


func _on_room_notice_left() -> void:
	if hint_bar == null:
		return
	if hint_bar.current_text() == StrawRoom2D.NAIL_NOTICE:
		hint_bar.clear()
		return
	for entry: Variant in BaleInterior2D.NOTICES:
		if hint_bar.current_text() == String((entry as Dictionary)["text"]):
			hint_bar.clear()
			return


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
func _on_painting_taken() -> void:
	announce_acquisition("Pista",
		"Lola's second canvas. The way into the next place.",
		BaleInterior2D.PISTA_ART)
	_speak(script_lines_l1.fire("L1_N3.canvas.taken"))
	_grant_the_canvas()


## Back down the ladder, onto the terrace they climbed from.
##
## AND THEY DO NOT LEAVE WITHOUT IT. The painting is the reason Pista opens and the reason
## this level is over; a player who climbed down without walking into it would have solved
## Node 3, satisfied the goal marker, and finished Level 1 with nothing to show for it and
## no way back in. So the ladder takes it for them -- you would not leave it -- which costs
## the deliberate player nothing and cannot strand the distracted one.
## Back down the ladder, onto the terrace they climbed from -- AND THAT IS THE END OF THE
## LEVEL, if they have what they came for.
##
## IT USED TO BE A MARKER STONE THEY HAD TO GO AND FIND. The GoalMarker sits out on the
## Overlook, so finishing Payyo meant: solve the hardest node in the level, climb in, take the
## painting, climb back out, and then walk to a spot that looks like every other spot on the
## terrace. Players did the first four and stood there. "I don't understand why I have to exit
## the hut and then enter again to finish the game" is what that reads like from outside -- the
## level is over and the game has not said so.
##
## The door IS the ending now. You take her canvas and you walk out, which is the shape the
## whole node has: getting in was the puzzle, and getting out with it is the answer.
func _on_bale_exit() -> void:
	if not PlayerProfile.has_object("canvas_2_pista"):
		_grant_the_canvas()
	if _bale_return != Vector2.ZERO:
		_step_through(_bale_return)
	if not _completion_unlocked():
		return
	# After the step, so the level ends with the apo standing on the terrace she came from
	# rather than inside a room the completion screen is drawn over.
	await get_tree().process_frame
	_complete_level()


## What the chest held, and the reason Pista opens. The unlock happens at CP3 rather than
## at the marker stone, so a player who stops after this keeps the progress.
func _grant_the_canvas() -> void:
	note_pickup_taken("canvas_2_pista")
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
			# ONCE, and it said so here while firing every time. There are TWO of them and
			# each has its own trigger, so walking along the terrace in front of the house
			# said the same refusal twice with the world stopped for both. The hook carries
			# the memory; see _speak_on_arrival.
			figure.approached.connect(func() -> void:
				_speak_on_arrival("L1_N3.bulul_approach"))


## WHAT THIS RUN OF THE LEVEL HAS ALREADY HANDED OVER, and why it is not the profile.
##
## `PlayerProfile.has_object` is GLOBAL AND PERMANENT -- that is its job, and it is what the
## progression and the concept gates are built on. Ang Bale's interior was asking it whether
## the painting was still there, which is a different question with a different lifetime: the
## answer is yes forever after the first time anybody takes it. So the second time a player
## opened Level 1 they solved the hardest node in the level, climbed into the house, and
## found an empty room -- the reward for the whole level silently absent, with the profile
## quietly insisting they already had it.
##
## Presence in the world is a question about THIS RUN. Ownership stays on the profile.
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
		var text := script_lines_l1.display_text(line)
		if text.is_empty():
			continue
		var speaker := String(line.get("speaker", "lolo"))
		if script_lines_l1.kind_of(line) == "hint":
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


## The hidden flower in the gorge cave, which is the one thing in Payyo a player can miss
## entirely and the one thing that had no acknowledgement at all.
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


## True when it actually reached something, so the interact key can fall through to
## whatever else is standing here.
func _interact_with_nearest_utility() -> bool:
	if player == null or not is_instance_valid(player):
		return false
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
	if nearest == null:
		return false
	_connect_utility(nearest)
	nearest.interact(player)
	return true


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
	hint_bar = HintBar.new()
	hint_bar.name = "HintBar"
	layer.add_child(hint_bar)


## The top-right corner: what the player currently IS.
##
## THIS REPLACED THE R-DRAW CHIP. That chip said one word the player needs to read once, in
## the corner most likely to be looked at -- and the controls strip along the bottom already
## says R DRAW, so retiring it loses nothing and frees the corner for something that changes.
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


## The Draw button, as a key prompt rather than a button. Kept because the scene still owns
## the node and `_on_draw_pressed` is still wired to it; it is simply not shown any more --
## see _build_morph_card for what stands in that corner now.
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
	draw_button.add_theme_color_override(&"font_color", UISkin.GOLD_PALE)
	draw_button.add_theme_color_override(&"font_hover_color", UISkin.GOLD)
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
	cap.bg_color = UISkin.GOLD
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
	letter.add_theme_color_override(&"font_color", UISkin.GOLD_LABEL)
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


func _on_ink_changed(remaining: float, capacity: float, reserved: float) -> void:
	if hud_panel != null:
		hud_panel.set_ink(remaining, capacity, reserved)


func _physics_process(_delta: float) -> void:
	if _level_completed or goal_marker == null:
		return
	if player == null or not is_instance_valid(player):
		return
	_refresh_room_framing()
	_offer_the_nearest_sign()
	_offer_the_found_key()
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
			# POINTED AT THE ANSWER, not at the problem. It used to say "draw something that
			# can cross it", which is what the beat asked for when Span came first -- and
			# Span cannot cross three hundred pixels of water. The way over is the plank.
			_return_to_safety("You cannot swim, apo — put something heavy on that plank",
				"You cannot swim, apo. Back to %s")
			return
	else:
		_submerged_seconds = 0.0
	# Crossing the far lip is what earns the memory, not choosing the route that would
	# have earned it: the reward is for having rebuilt her bridge and walked over it.
	#
	# 3660 since the level was stretched: the gorge's far lip moved with Terrace5. It was
	# 2980, which after the stretch is the middle of the gorge -- so the memory fired while
	# the player was still falling into it.
	if anchor_position.x > 3660.0:
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
	# THE FLOWER SAID NOTHING. `collected` has been emitted since the flower existed and
	# nothing in the level had ever connected it: the one optional collectible in Payyo was
	# picked up in silence, with a rise-and-fade on the sprite and no other acknowledgement
	# anywhere. It is the hardest thing in the level to find.
	if hidden_flower != null and not hidden_flower.collected.is_connected(_on_flower_found):
		hidden_flower.collected.connect(_on_flower_found)
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
	var choices: Dictionary = script_lines_l1.choices_for("L1_N1") if script_lines_l1 != null else {}
	if not choices.is_empty():
		var context := ""
		for line_value: Variant in script_lines_l1.peek("L1_N1.choice"):
			context = String((line_value as Dictionary).get("text", ""))
		dialogue_overlay.call("present", "Lolo", context, choices,
			_requirements_per_route("L1_N1"))
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
		director.commit_route("L1_N1", route)
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
