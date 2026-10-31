extends "res://scripts/level_base.gd"
## LEVEL 5 -- MAYON. The last painting, coming apart while the apo stands in it.
##
## Extended BY PATH rather than by `class_name LevelBase`, for the reason every level is: a
## `--script` run does not register class names and the probes are exactly that.
##
## What this level is, in the machine's terms (LEVEL_5.md has the design and why):
##
##   * NO COMBAT, NO HEALTH. The antagonist is the clock and the ink.
##   * THE INK IS THE STORY. Six units, every drawing costs one, a creature form drains it, and
##     nothing on the mountain gives any back. The gauge never steps aside. Two units nobody sees
##     keep the climb's two gates always payable (`_may_use_hidden_ink`): a player locked out of
##     the climax by over-spending would be a disaster.
##   * ONE CONTINUOUS ASCENT. The checkpoints are written without a word.
##   * IT ENDS WITH ITS OWN SCENE. The summit and the frame's return are the ending (Kent,
##     2026-10-25). Three clustered choices lead into the summit and the ordinary room.


func level_config_path() -> String:
	return "res://config/level_05.json"


func dialogue_path() -> String:
	return "res://config/dialogue_l5.json"


func _on_backend_ready() -> void:
	status_label.text = ""


func _on_backend_failed(message: String) -> void:
	if _brush_refuses_here() or _lolo_moment == "going" or not _summit.is_empty():
		return
	super(message)


func _spawn_lolo() -> void:
	super()
	if lolo != null:
		lolo.set_thinness(0.25)


func _speaker_subject(speaker_id: String) -> Node2D:
	if speaker_id == "lola":
		return _lola()
	return super(speaker_id)


func _focus_camera_for(_speaker: String) -> void:
	# Keep the painted composition intact. Push-ins cropped memories out of their own
	# cluster and pulled the floor upward during every travel line.
	var camera := _world_camera()
	if camera != null:
		if _framing_lolo and is_instance_valid(player):
			# The last sentence needs both world figures above the dialogue box.
			# Keep the landscape's scale; only this staged beat changes its eye line.
			camera.focus_on(player, 1.0, 0.0 if Motion.reduced() else 0.45, -80.0)
			if Motion.reduced():
				camera.snap_to_target()
		else:
			camera.release_focus(0.0)


## How far under the mountain's lowest ground a fall goes before she is put back.
## Catch her BEFORE Wanderer's world-bottom wrap, or a missed gap becomes free flight.
const FALL_BELOW := 700.0
## The gates the climb cannot be finished without: the hidden reserve pays for them.
const GATES := ["L5_SPAN", "L5_CLIMB"]


## Every drawing costs a unit, not only the first of its kind: there is no clearing here to give
## any back, and what she spends is the story.
func _every_drawing_costs_ink() -> bool:
	return true


## Only a gate may draw on the reserve, and only while she stands in it.
func _may_use_hidden_ink(entity_id: String) -> bool:
	if director == null or String(director.current_obstacle()) not in GATES:
		return false
	var gate := String(director.current_obstacle())
	if director.is_solved(gate):
		return false
	# A body with no visible ink would immediately revert. Only usable placements can borrow.
	if String(registry.get_entity(entity_id).get("runtime_role", "")) == "active_ragdoll_morph":
		return false
	for obstacle: Dictionary in director.level_data().get("obstacles", []):
		if String(obstacle.id) == gate:
			var beat: Dictionary = obstacle.sub_beats[0]
			var report := AbilityTags.resolve_report(beat.required_tags, "all", beat.get("exclude", []))
			return entity_id in report.get("solutions", [])
	return false


func _saves_silently() -> bool:
	return true


func _ink_always_visible() -> bool:
	return true


## A climb as tall as it is wide: the camera centres on her rather than pinning the ground.
func _camera_follows_height() -> bool:
	return true


func _ends_with_its_own_scene() -> bool:
	return true


## The summit was the ending; the frame's return is its last shot (Kent, 2026-10-25): the real
## room, the stories she saved told to lola, lolo last, an ordinary brush -- then black, then home.
func _play_own_ending() -> void:
	var frame := FrameReturn.new()
	frame.name = "FrameReturn"
	frame.has_flowers = ending_hook() == "ENDING.perfect"
	add_child(frame)
	for hook in frame_hooks():
		if hook == "FRAME.brush":
			script_lines.fire(hook)
			await frame.pick_up_brush()
		else:
			var id := hook.trim_prefix("FRAME.")
			var fragment := _fragment(id)
			if fragment != null:
				frame.show_memory(fragment.summit_texture)
			await _speak_and_wait(script_lines.fire(hook))
	await frame.cut_to_black()
	AudioDirector.stop_music()
	_went_home = true
	LevelManager.return_to_house()


func _checkpoint_place(checkpoint_id: String) -> String:
	match checkpoint_id:
		"CP1":
			return "the mid slope"
		"CP2":
			return "below the summit"
	return super(checkpoint_id)


## The ink economy's own numbers: the drain while a form is held, and the reserve nobody sees.
func _build_level_furniture() -> void:
	super()
	# ⚠ THE HOOK ALONE DOES NOT FREE THE CAMERA. _camera_follows_height is read only when a room
	# is framed, and Mayon has no rooms -- so, as Dagat does, it is freed here, or the camera
	# stays pinned at her feet with the ground filling half the screen.
	var world_camera := _world_camera()
	if world_camera != null:
		world_camera.set_vertical_free(true)
		world_camera.snap_to_target()
	var economy: Dictionary = director.level_data().get("ink_economy", {})
	ink_manager.hidden_reserve = float(economy.get("hidden_reserve", 0.0))
	_arm_the_drain()
	_gather_fragments()
	_gather_the_ash()
	_cluster_data = director.level_data().get("memory_clusters", [])
	_start_weather_audio()


func _level_physics(anchor_position: Vector2) -> void:
	if anchor_position.y > _lowest_ground() + FALL_BELOW:
		var words := _line("FELL")
		_return_to_safety(words, words)
		return
	_hold_the_drain(get_physics_process_delta_time())
	_tend_clusters(anchor_position.x)
	_tend_act_one(get_physics_process_delta_time(), anchor_position.x)
	_tend_summit(get_physics_process_delta_time(), anchor_position.x)
	_rescue_reserve_drawings()
	if _summit.is_empty():
		var status_visible := not status_label.text.is_empty()
		if status_label.visible != status_visible:
			status_label.visible = status_visible
			hud_panel.reset_size()
	for fragment in _fragments:
		fragment.notice(anchor_position.x)
	# The one a drawing would go into now is lit, and only it.
	var target := _fragment_here()
	for fragment in _fragments:
		fragment.set_targeted(fragment == target)
	_tend_lolo(get_physics_process_delta_time(), anchor_position.x)
	if _tremor != null:
		_tremor.amplitude = 0.0 if Motion.reduced() else 3.0
	if not _summit.is_empty():
		for child in $CanvasLayer.get_children():
			if child is CanvasItem and child != hud_panel:
				(child as CanvasItem).hide()
		if action_prompts != null:
			action_prompts.suppressed = true
		status_label.hide()
		if objective_marker != null:
			objective_marker.clear()


func _on_ink_emptied() -> bool:
	# His disappearance includes his voice; an optional late morph must not bring him back.
	if lolo != null and not lolo.is_gone():
		_speak(script_lines.fire("INK.empty"))
	return true


## The banner: the gate she stands at, while it is open; the climb everywhere else.
func _current_objective() -> Dictionary:
	if not _summit.is_empty():
		return {}
	if director == null:
		return {}
	match String(director.current_obstacle()):
		"L5_SPAN":
			return {"key": "span"} if not director.is_solved("L5_SPAN") else {"key": "slope"}
		"L5_CLIMB":
			return {"key": "climb"} if not director.is_solved("L5_CLIMB") else {"key": "slope"}
	if player != null and is_instance_valid(player):
		var x := player.global_position.x
		if x < 1400.0:
			return {"key": "foot"}
		if x >= CORRIDOR.x and x < CORRIDOR.y and _lolo_moment == "":
			return {"key": "corridor"}
	return {"key": "slope"}


func _lowest_ground() -> float:
	return 600.0


## A line's own words, for the rescue's hint (it takes text, not a line).
func _line(hook: String) -> String:
	var lines := script_lines.fire(hook)
	return String((lines[0] as Dictionary).get("text", "")) if not lines.is_empty() else ""


# --- A drawn body costs ink while it is held ------------------------------------------------

## As in Dilim: a creature's body is paid for in ink -- level_05.json's creature_drain_per_second
## -- for as long as she holds it, and there is no ten-second clock. At none she is herself again.
var _drain: InkDrain


func _morph_has_a_life() -> bool:
	return false


func _arm_the_drain() -> void:
	_drain = get_node_or_null(^"InkDrain") as InkDrain
	if _drain == null:
		return
	_drain.bind(ink_manager)
	var economy: Dictionary = director.level_data().get("ink_economy", {})
	_drain.default_rate = float(economy.get("creature_drain_per_second", _drain.default_rate))
	_drain.ink_emptied.connect(_revert_to_base_form)


func _hold_the_drain(delta: float) -> void:
	if _drain == null:
		return
	if _current_form_id.is_empty():
		if _drain.is_draining():
			_drain.clear()
		return
	if _drain.form_id() != _current_form_id:
		_drain.begin(_current_form_id)
	_drain.charge(delta)
	if morph_card != null:
		morph_card.set_meter_caption("INK")
		morph_card.set_drain(ink_manager.remaining(), ink_manager.capacity)


# --- Act Two: what she carries ------------------------------------------------------------

## Where the fragments drift, along the slope.
const CORRIDOR := Vector2(5300.0, 11000.0)
## How long a fragment with lolo in it steadies him.
const STEADY_SECONDS := 60.0
## How thin lolo is, by where she is: the foot and the treeline, the mid slope, the corridor.
const THINNESS := [[4200.0, 0.25], [8800.0, 0.45], [INF, 0.7]]
## How fast his thinness follows where it should be, per second.
const THINNING := 0.25
## Where lolo goes with all three of his fragments saved; each one let go brings it nearer.
const LOLO_GOES_X := 11500.0
const LOLO_GOES_SOONER := 250.0
## How long she stands before raising the brush herself.
const RAISE_AFTER := 8.0

var _fragments: Array[MemoryFragment2D] = []
var _steady_left := 0.0
## "" before, "waiting" while the brush is raised to him, "going", then "gone".
var _lolo_moment := ""
var _framing_lolo := false
var _raise_left := 0.0
var _saved_class := ""
var _corridor_seen := false
var _locked_fragment: MemoryFragment2D
var _page_had_fragment := false
var _cluster_data: Array = []
var _clusters_seen: Array[String] = []
var _clusters_left: Array[String] = []
var _active_cluster := ""
var _flower_credited := false
var _reserve_drawings: Array[PhysicsShapeObject] = []
var _places_strokes: Array = []
var _hud_before_summit := {}


func _handle_level_input(event: InputEvent) -> bool:
	if _summit.is_empty() or event.is_action_pressed("ui_cancel"):
		return false
	# Ordinary actions cannot replace the apo or open recognition during the performance.
	return not (event.is_action_pressed("redraw") and _summit in ["trying", "places"])


func _gather_fragments() -> void:
	_fragments.clear()
	for node in get_tree().get_nodes_in_group(&"memory_fragments"):
		var fragment := node as MemoryFragment2D
		_fragments.append(fragment)
		for entry: Dictionary in director.level_data().get("memories", []):
			if String(entry.get("id", "")) == fragment.fragment_id:
				fragment.configure_memory(entry)
		fragment.saved.connect(_on_fragment_saved)
		fragment.lost.connect(_on_fragment_lost)


func _prepare_drawing_page() -> void:
	_locked_fragment = null if _brush_refuses_here() else _fragment_here()
	_page_had_fragment = _locked_fragment != null
	if _page_had_fragment or _brush_refuses_here():
		status_label.text = ""
	draw_panel.set_memory_reference(
		(_locked_fragment.get_node("Picture") as Sprite2D).texture if _page_had_fragment else null)
	if _summit == "places":
		draw_panel.set_drawing_mode(DrawPanel.DrawingMode.FREE_PAINT)
	if _brush_refuses_here():
		_set_performance("raise")
		_raise_into_paint()


func _raise_into_paint() -> void:
	await get_tree().create_timer(0.4, true).timeout
	if draw_panel.is_open() and draw_panel.is_refusing():
		_set_performance("paint")


func _free_paint_completed(strokes: Array) -> void:
	if _summit != "places" or strokes.is_empty():
		return
	_places_strokes = DrawnItemData.copy_strokes(strokes)
	_summit = "blooming"
	_set_performance("lower")
	_bloom_the_places()


func _spawn_or_replace(entity_id: String, display_name: String, drawing: Image, strokes: Array) -> bool:
	if ink_manager.remaining() < InkManager.UNIT:
		_say_why(_line("FRAGMENT.no_ink"))
		return false
	var became := super(entity_id, display_name, drawing, strokes)
	if became:
		ink_manager.spend_unit()
	return became


func _on_placement_confirmed(item: DrawnItemData, placed: PhysicsShapeObject, source_slot: int) -> void:
	var before := ink_manager.hidden_reserve
	super(item, placed, source_slot)
	if ink_manager.hidden_reserve < before and is_instance_valid(placed):
		_reserve_drawings.append(placed)


func _rescue_reserve_drawings() -> void:
	# A paid answer can always be picked up and placed again free. Catch one lost down a gap.
	for index in range(_reserve_drawings.size() - 1, -1, -1):
		var placed := _reserve_drawings[index]
		if not is_instance_valid(placed):
			_reserve_drawings.remove_at(index)
		elif placed.global_position.y > 900.0 and inventory_manager.has_room_for(placed.item_data):
			_on_utility_pickup_requested(placed)
			_reserve_drawings.remove_at(index)


func _tend_clusters(her_x: float) -> void:
	var current := ""
	for entry: Dictionary in _cluster_data:
		var id := String(entry.id)
		if her_x >= float(entry.entry) and her_x < float(entry.exit) and not _clusters_left.has(id):
			current = id
			if not _clusters_seen.has(id):
				_clusters_seen.append(id)
				for fragment in _fragments:
					if fragment.cluster_id == id:
						fragment.begin_whitening()
		if (her_x < float(entry.entry) or her_x >= float(entry.exit)) \
				and _clusters_seen.has(id) and not _clusters_left.has(id):
			_clusters_left.append(id)
			for fragment in _fragments:
				if fragment.cluster_id == id:
					fragment.leave_behind()
			# The new floor is safe; changing scenes or falling never reopens a spent choice.
			_write_checkpoint("CP1")
	if current != _active_cluster:
		_active_cluster = current
		var camera := _world_camera()
		if camera != null:
			camera.set_room_bounds(Rect2())
			camera.vertical_pin_y = NAN
			for entry: Dictionary in _cluster_data:
				if String(entry.id) == current:
					var box: Array = entry.camera
					camera.set_room_bounds(Rect2(float(box[0]), float(box[1]), float(box[2]), float(box[3])))
					camera.vertical_pin_y = float(box[1]) + float(box[3]) * 0.5


var _performance: Sprite2D


func _set_performance(pose: String) -> void:
	var figure := player.get_node_or_null("Figure") as CanvasItem if is_instance_valid(player) else null
	if pose.is_empty():
		if figure != null:
			figure.visible = true
		if is_instance_valid(_performance):
			_performance.visible = false
		return
	if _current_form_id != "":
		_revert_to_base_form()
	if not is_instance_valid(_performance):
		_performance = Sprite2D.new()
		_performance.name = "BrushPerformance"
		_performance.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		player.add_child(_performance)
		_performance.position = Vector2(0, -56)
		_performance.z_index = 20
	figure = player.get_node_or_null("Figure") as CanvasItem
	if figure != null:
		figure.visible = false
	_performance.texture = load("res://assets/Level5/people/apo_%s.png" % pose)
	# The offer cell faces left on its source sheet; Lola stands to the apo's right.
	_performance.flip_h = pose == "offer"
	_performance.visible = true


## A DRAWING NEAR A FRAGMENT GOES INTO IT -- not into the bag, the hand or a body. One unit of ink,
## never the hidden reserve (that is the gates'), and it is saved. A drawing that does not belong
## is handed back free, with one quiet line and no class named. Away from any fragment, a drawing
## is a drawing.
func _on_drawing_ready(entity_id: String, display_name: String, drawing: Image,
		response: Dictionary, strokes: Array, ink_cost: float) -> void:
	var fragment := _locked_fragment if _page_had_fragment else _fragment_here()
	if _page_had_fragment and (not is_instance_valid(fragment) or not fragment.is_open()):
		ink_manager.release_attempt()
		return
	if fragment == null:
		super(entity_id, display_name, drawing, response, strokes, ink_cost)
		return
	ink_manager.release_attempt()
	if not fragment.belongs(entity_id):
		_say_why(_line("FRAGMENT.not_this"))
		return
	if not ink_manager.spend_unit():
		_say_why(_line("FRAGMENT.no_ink"))
		return
	_saved_class = entity_id
	status_label.text = ""
	_save_order.append(fragment.fragment_id)
	fragment.save(strokes)


## The nearest fragment she could still save, if one is in reach.
func _fragment_here() -> MemoryFragment2D:
	if player == null or not is_instance_valid(player):
		return null
	var best: MemoryFragment2D = null
	var nearest := INF
	for fragment in _fragments:
		var away := fragment.global_position.distance_to(player.global_position)
		if fragment.is_open() and away <= fragment.reach and away < nearest:
			best = fragment
			nearest = away
	return best


func _fragment(fragment_id: String) -> MemoryFragment2D:
	for fragment in _fragments:
		if fragment.fragment_id == fragment_id:
			return fragment
	return null


func _on_fragment_saved(fragment_id: String) -> void:
	AudioDirector.play_sfx(&"mayon_brush", 0.6)
	Telemetry.record_event("fragment", {"id": fragment_id, "outcome": "saved", "class": _saved_class})
	var fragment := _fragment(fragment_id)
	if fragment_id == "flower" and not _flower_credited:
		# The useless one, saved anyway: the fifth flower, and the artist's choice.
		PlayerProfile.record_collectible("L5_HF")
		if not PlayerProfile.routes_taken_at("level_5", "L5_HF").has("artist"):
			PlayerProfile.record_route("level_5", "artist")
			PlayerProfile.record_obstacle_route("level_5", "L5_HF", "artist")
		_flower_credited = true
		_speak(script_lines.fire("FLOWER.saved"))
	elif fragment != null and fragment.holds_lolo:
		_steady_left = STEADY_SECONDS
		_speak(script_lines.fire("LOLO.steadied." + fragment_id))


func _on_fragment_lost(fragment_id: String) -> void:
	Telemetry.record_event("fragment", {"id": fragment_id, "outcome": "lost"})


func _saved_lolo_fragments() -> int:
	var count := 0
	for fragment in _fragments:
		if fragment.holds_lolo and fragment.state() == "saved":
			count += 1
	return count


## Where he goes: sooner, the fewer of his fragments she saved. He goes either way.
func lolo_goes_at() -> float:
	return LOLO_GOES_X - LOLO_GOES_SOONER * (3 - _saved_lolo_fragments())


## LOLO'S THREAD. He thins as the painting comes apart -- by where she is on the mountain -- and
## a fragment with him in it brings him back into focus for a while. Near the top he stops, and
## the brush is raised to him: by her, or after a moment by the apo herself.
func _tend_lolo(delta: float, her_x: float) -> void:
	if lolo == null or not is_instance_valid(lolo) or lolo.is_gone():
		return
	_steady_left = maxf(0.0, _steady_left - delta)
	if _steady_left > 0.0:
		lolo.set_thinness(0.0)
	else:
		var want := 0.0
		for band: Array in THINNESS:
			if her_x < float(band[0]):
				want = float(band[1])
				break
		lolo.set_thinness(move_toward(lolo.thinness(), want, THINNING * delta))
	if not _corridor_seen and her_x >= CORRIDOR.x:
		# The painting stops being Mayon: the first sight of them.
		_corridor_seen = true
		_speak(script_lines.fire("L5_CORRIDOR.enter"))
	match _lolo_moment:
		"":
			if her_x >= lolo_goes_at():
				_lolo_moment = "waiting"
				_raise_left = RAISE_AFTER
				_speak(script_lines.fire("LOLO.fading"))
		"waiting":
			if not draw_panel.is_open():
				_raise_left -= delta
				if _raise_left <= 0.0:
					# She raises the brush herself.
					_raise_left = RAISE_AFTER
					_open_the_page(true)


## The brush refuses him (the first time it refuses anything), and her twice; and the page that
## draws the places takes no guess either -- whatever she draws there becomes them.
func _brush_refuses_here() -> bool:
	return _lolo_moment == "waiting" or _summit == "trying" or _summit == "places"


func _brush_refused(_strokes: int) -> void:
	_set_performance("failed")
	if _lolo_moment == "waiting":
		_lolo_moment = "going"
		_let_him_go()
	elif _summit == "trying":
		_attempts += 1
		_raise_left = RAISE_AFTER
		if _attempts >= REFUSALS:
			# The third time, she lowers the brush herself. No line over it.
			_summit = "lowering"
			_beat_left = LOWERING_BEAT
			_set_performance("lower")


## He understands before she does, and says so -- and mid-sentence he is not there. No farewell,
## no fade: that is how it happens when someone is forgotten rather than when someone dies.
func _let_him_go() -> void:
	if not dialogue_box.line_progress.is_connected(_on_lolo_line_progress):
		dialogue_box.line_progress.connect(_on_lolo_line_progress)
	_framing_lolo = true
	await _speak_and_wait(script_lines.fire("LOLO.goes"))
	_vanish_lolo()
	_framing_lolo = false
	_release_camera_focus()
	_set_performance("")


func _on_lolo_line_progress(text: String, characters: int) -> void:
	if _lolo_moment == "going" and text.ends_with("kept m") and characters >= text.length() - 2:
		_vanish_lolo()


func _vanish_lolo() -> void:
	if _lolo_moment == "gone":
		return
	lolo.vanish()
	dialogue_box.hide_speaker()
	status_label.text = ""
	_lolo_moment = "gone"
	Telemetry.record_event("lolo_gone", {"steadied_by": _saved_lolo_fragments()})


## What a checkpoint keeps of Act Two: each fragment as it stood, her lines in the saved ones,
## and how long lolo is steady for.
func _level_run_state() -> Dictionary:
	var fragments := {}
	for fragment in _fragments:
		fragments[fragment.fragment_id] = fragment.snapshot()
	var taken: Array = []
	for thing in _taken:
		if bool(_going.get(thing, false)):
			taken.append(String(thing.name))
	return {"layout_version": 3, "fragments": fragments, "steady_left": _steady_left,
		"lolo_thinness": lolo.thinness() if is_instance_valid(lolo) else 1.0,
		"taken": taken, "forgot": _forgot, "save_order": _save_order.duplicate(),
		"clusters_seen": _clusters_seen.duplicate(), "clusters_left": _clusters_left.duplicate(),
		"lolo_moment": _lolo_moment, "corridor_seen": _corridor_seen,
		"flower_credited": _flower_credited, "places_strokes": _places_strokes.duplicate(true)}


func _restore_level_run_state(state: Dictionary) -> void:
	var fragments: Dictionary = state.get("fragments", {})
	for fragment in _fragments:
		fragment.restore_snapshot(fragments.get(fragment.fragment_id, {}))
	_save_order.assign(state.get("save_order", []))
	_clusters_seen.assign(state.get("clusters_seen", []))
	_clusters_left.assign(state.get("clusters_left", []))
	_active_cluster = ""
	_steady_left = float(state.get("steady_left", 0.0))
	_flower_credited = _flower_credited or bool(state.get("flower_credited", false))
	_corridor_seen = bool(state.get("corridor_seen", false))
	var taken: Array = state.get("taken", [])
	for thing in _taken:
		var drainable := thing.get_node("Drainable") as Drainable
		_going[thing] = taken.has(String(thing.name))
		drainable.drain_to(1.0 if _going[thing] else 0.0, 0.0)
	_forgot = int(state.get("forgot", 0))
	_reset_summit()
	_lolo_moment = String(state.get("lolo_moment", ""))
	# Resume a failed attempt from its beginning, never half a transient tween.
	if _lolo_moment == "going":
		_lolo_moment = "waiting"
	_raise_left = RAISE_AFTER
	if lolo != null:
		if _lolo_moment == "gone":
			lolo.vanish()
		else:
			lolo.set("_vanished", false)
			lolo.visible = true
			lolo.set_thinness(float(state.get("lolo_thinness", 0.25)))
	_places_strokes = state.get("places_strokes", []).duplicate(true)
	_set_performance("")


func _checkpoint_landing(state: Dictionary) -> Vector2:
	var level_state: Dictionary = state.get("level", {})
	if int(level_state.get("layout_version", 1)) < 2:
		if checkpoints.latest_id() == "CP2":
			_lolo_moment = "gone"
			if lolo != null:
				lolo.vanish()
			return Vector2(11900, -500)
		return Vector2(4800, 50) if checkpoints.latest_id() == "CP1" else Vector2(260, 510)
	if int(level_state.get("layout_version", 1)) < 3:
		# The old stacked shelves are gone. Resume above the new ground, beyond the last
		# departed cluster, while retaining every memory outcome and its original strokes.
		if checkpoints.latest_id() == "CP2":
			return Vector2(11900, -500)
		var left: Array = level_state.get("clusters_left", [])
		if "memory_3" in left:
			return Vector2(10500, -510)
		if "memory_2" in left:
			return Vector2(8700, -350)
		if "memory_1" in left:
			return Vector2(6900, -190)
		return Vector2(4800, 50)
	return super(state)


func _give_back_what_cannot_come_back(_state: Dictionary) -> void:
	# Mayon's checkpoints are beyond both gates. Their abandoned answers remain paid:
	# refunding a reserve-funded prop into visible ink would create extra memory choices.
	pass


# --- Act One: the ascent ------------------------------------------------------------------

## The ash, by where she is: thin at the foot, thick on the cone and in the corridor, gone at the
## summit -- where there is no ash, no tremor and no sound.
const ASH := [[1800.0, 0.2], [4200.0, 0.4], [5400.0, 0.6], [12200.0, 1.0], [INF, 0.0]]
## How fast the ash thickens or thins toward where she is, per second.
const ASH_EASE := 0.1
## The eruption, felt: every so often below the summit.
const TREMOR_EVERY := 18.0
const SUMMIT_X := 12200.0
## Lolo's forgetting on the way up, by where she is. Light at first; by the third it is not funny.
const FORGETTING := [[1000.0, "LOLO.forget.1"], [2900.0, "LOLO.forget.2"], [4700.0, "LOLO.forget.3"]]

var _taken: Array[Node2D] = []
var _going := {}
var _ash: AshFall2D
var _tremor: ScreenTremor
var _forgot := 0


## What the ash takes is marked in the ground (group ash_takes, taken_at, taken_over); each gets a
## Drainable. The ash itself is on the camera, and the eruption rumbles from here.
func _gather_the_ash() -> void:
	_taken.clear()
	for node in get_tree().get_nodes_in_group(&"ash_takes"):
		var thing := node as Node2D
		var drainable := Drainable.new()
		drainable.name = "Drainable"
		thing.add_child(drainable)
		_taken.append(thing)
		_going[thing] = false
	_ash = get_node_or_null(^"EnvironmentBaseplate/WorldCamera/Ash") as AshFall2D
	_tremor = ScreenTremor.new()
	_tremor.name = "Eruption"
	_tremor.every = TREMOR_EVERY
	add_child(_tremor)
	_tremor.trembled.connect(_on_tremor)


## The rumble's visual twin: the ash surges with it.
func _on_tremor(strength: float) -> void:
	if _ash != null:
		_ash.pulse(strength)


func ash_at(her_x: float) -> float:
	for band: Array in ASH:
		if her_x < float(band[0]):
			return float(band[1])
	return 0.0


func _tend_act_one(delta: float, her_x: float) -> void:
	for thing in _taken:
		if not bool(_going[thing]) and her_x >= float(thing.get_meta("taken_at")):
			_going[thing] = true
			(thing.get_node("Drainable") as Drainable).drain_to(1.0, float(thing.get_meta("taken_over")))
	if _ash != null:
		_ash.density = move_toward(_ash.density, ash_at(her_x), ASH_EASE * delta)
	if _tremor != null:
		_tremor.enabled = her_x < SUMMIT_X
	if _forgot < FORGETTING.size() and her_x >= float(FORGETTING[_forgot][0]):
		var hook := String(FORGETTING[_forgot][1])
		_forgot += 1
		_speak(script_lines.fire(hook))


# --- Act Three: the summit ----------------------------------------------------------------

## Where the summit begins (the world goes white and still), and where she speaks to lola.
const SUMMIT_ARRIVE := 12200.0
const SUMMIT_SPEAK := 12700.0
## How long the white takes to come over everything.
const WHITE_SECONDS := 4.0
## How white: paper, not blank -- the ground she stands on stays.
const WHITE := 0.85
## The brush refuses her this many times; the next, she lowers it herself.
const REFUSALS := 2
## The beat after she lowers it, with nothing said over it.
const LOWERING_BEAT := 3.0
## The saved places bloom this far apart.
const BLOOM_EVERY := 0.8
const ALL_FLOWERS := 5
## What the summit whitens, and how far: the backdrop to paper; the ground she stands on only to a
## pale ghost of itself, so the white plateau still shows where she can walk.
const WHITENED := {"EnvironmentBaseplate/SkyFill": 0.85, "EnvironmentBaseplate/SkyBand": 0.85,
	"EnvironmentBaseplate/GameplayPlane/Terrain/Cone": 0.55}

## "" below, "quiet", "trying" (the brush raised to her), "lowering", "places", "blooming", "done".
var _summit := ""
var _attempts := 0
var _beat_left := 0.0
var _save_order: Array[String] = []
var _bloomed: Array[Sprite2D] = []
var _places_ink: Node2D


func _lola() -> Lola2D:
	return get_node_or_null(^"EnvironmentBaseplate/GameplayPlane/Lola") as Lola2D


func summit_state() -> String:
	return _summit


func _tend_summit(delta: float, her_x: float) -> void:
	match _summit:
		"":
			# Not before lolo has gone: the brush is raised to him first, wherever she has got to.
			var gone := lolo == null or not is_instance_valid(lolo) or lolo.is_gone()
			if her_x >= SUMMIT_ARRIVE and gone:
				_summit = "quiet"
				if not _current_form_id.is_empty():
					_revert_to_base_form()
				for child in $CanvasLayer.get_children():
					if child is CanvasItem and child != hud_panel:
						_hud_before_summit[child] = (child as CanvasItem).visible
				_stop_weather_audio()
				if placement_controller.is_placing():
					placement_controller.cancel_placement()
				_stow_equipped()
				if _tremor != null:
					_tremor.set("_left", 0.0)
				_set_performance("")
				var camera := _world_camera()
				if camera != null:
					camera.offset = Vector2.ZERO
					camera.set_room_bounds(Rect2(11900, -1240, 1800, 1000))
					camera.vertical_pin_y = -740.0
				_whiten(WHITE, WHITE_SECONDS)
				# And still at once: no ash left drifting over the white.
				if _ash != null:
					_ash.density = 0.0
		"quiet":
			if her_x >= SUMMIT_SPEAK:
				_summit = "trying"
				if not _current_form_id.is_empty():
					_revert_to_base_form()
				var lola := _lola()
				if lola != null:
					player.call("apply_morph_state", {"position": lola.global_position + Vector2(-250, 0),
						"linear_velocity": Vector2.ZERO})
				player.set_physics_process(false)
				_attempts = 0
				_raise_left = RAISE_AFTER
				_speak(script_lines.fire("SUMMIT.speaks"))
		"trying", "places":
			if not draw_panel.is_open():
				_raise_left -= delta
				if _raise_left <= 0.0:
					_raise_left = RAISE_AFTER
					_set_performance("raise")
					_open_the_page(true)
		"lowering":
			_beat_left -= delta
			if _beat_left <= 0.0:
				# She does what lolo told her: the page opens for the places.
				_summit = "places"
				_raise_left = 0.0


## White in every direction except what she saved.
func _whiten(amount: float, seconds: float) -> void:
	for path: String in WHITENED:
		var how_far := minf(amount, float(WHITENED[path])) if amount > 0.0 else 0.0
		var thing := get_node_or_null(NodePath(path)) as CanvasItem
		if thing == null:
			continue
		var drainable := thing.get_node_or_null(^"Drainable") as Drainable
		if drainable == null:
			drainable = Drainable.new()
			drainable.name = "Drainable"
			thing.add_child(drainable)
		if seconds <= 0.0:
			drainable.restore()
		var wash := drainable.drain_to(how_far, seconds)
		# This is the summit's scene transition. It finishes while a line or quiet page
		# is open; the memory fragments still keep their ordinary paused gameplay clocks.
		if wash != null:
			wash.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)


## What she saved, in the order she saved it, and any a checkpoint brought back.
func bloom_targets() -> Array[MemoryFragment2D]:
	var out: Array[MemoryFragment2D] = []
	for id in _save_order:
		var fragment := _fragment(id)
		if fragment != null and fragment.state() == "saved" and not out.has(fragment):
			out.append(fragment)
	for fragment in _fragments:
		if fragment.state() == "saved" and not out.has(fragment):
			out.append(fragment)
	return out


func bloomed() -> int:
	return _bloomed.size()


## Her monologue, voiced by the route the whole run leaned toward.
func voice_hook() -> String:
	var route := PlayerProfile.dominant_route()
	return "SUMMIT.voice." + (route if not route.is_empty() else "artist")


## Five flowers: for a moment she is known. Fewer: lola is warm to a child she does not know.
func ending_hook() -> String:
	return "ENDING.perfect" if PlayerProfile.flower_count() >= ALL_FLOWERS else "ENDING.standard"


## Everything she saved blooms into the white around them, one by one; each with what she says
## of it; then her monologue; then lola turns around.
func _bloom_the_places() -> void:
	var targets := bloom_targets()
	var lola := _lola()
	var centre := lola.global_position if lola != null else player.global_position
	var plane := get_node(^"EnvironmentBaseplate/GameplayPlane")
	AudioDirector.play_music(&"mayon_ending")
	# Her last drawing itself stays, even if no earlier memory was saved.
	if not _places_strokes.is_empty():
		var ink := Node2D.new()
		_places_ink = ink
		ink.name = "HerPlaces"
		ink.position = centre + Vector2(-260, -220)
		ink.z_index = -1
		plane.add_child(ink)
		for stroke: Dictionary in _places_strokes:
			var line := Line2D.new()
			line.points = stroke.get("points", PackedVector2Array())
			line.width = float(stroke.get("width", 6.0))
			line.default_color = stroke.get("color", Color.BLACK)
			ink.add_child(line)
		ink.scale = Vector2.ONE * 0.55
		ink.position -= Vector2(156, 156)
	for index in range(targets.size()):
		var picture := Sprite2D.new()
		picture.set_script(preload("res://scripts/memory_bloom_2d.gd"))
		picture.set("ink", targets[index].strokes().duplicate(true))
		picture.texture = targets[index].summit_texture
		if picture.texture == null:
			picture.texture = (targets[index].get_node(^"Picture") as Sprite2D).texture
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var share := (float(index) + 0.5) / maxf(1.0, float(targets.size()))
		# A landscape planted on the ground, not a row of little collectible cards.
		var fit := targets[index].bloom_width / picture.texture.get_width()
		picture.scale = Vector2.ONE * fit
		picture.self_modulate = targets[index].bloom_tint
		picture.position = centre + Vector2(lerpf(-720, 520, share),
			-picture.texture.get_height() * fit * 0.5 + targets[index].bloom_elevation)
		picture.z_index = -4 - index
		plane.add_child(picture)
		_bloomed.append(picture)
		Motion.fade_in(picture, 1.0)
		# Motion._show normalizes Node2D scale. Restore this scenery's measured size after it.
		picture.scale = Vector2.ONE * fit
		await get_tree().create_timer(BLOOM_EVERY, false).timeout
	var said: Array = []
	for fragment in targets:
		said.append_array(script_lines.fire("SUMMIT." + fragment.fragment_id))
	await _speak_and_wait(said)
	await _speak_and_wait(script_lines.fire(voice_hook()))
	if lola != null:
		await lola.turn_around()
		await get_tree().create_timer(0.45, false).timeout
	_set_performance("")
	var ending := script_lines.fire(ending_hook())
	if ending_hook() == "ENDING.perfect" and ending.size() >= 3:
		_set_performance("offer")
		if lola != null:
			var beside := lola.global_position + Vector2(-82, 0)
			if Motion.reduced():
				player.global_position = beside
			else:
				var approach := create_tween()
				approach.tween_property(player, "global_position", beside, 0.65).set_trans(Tween.TRANS_SINE)
				await approach.finished
		await _speak_and_wait([ending[0]])
		if lola != null:
			lola.receive_flowers()
		_set_performance("lower")
		await get_tree().create_timer(0.7, false).timeout
		await _speak_and_wait([ending[1]])
		await get_tree().create_timer(1.0, false).timeout
		if lola != null:
			await lola.turn_back(true)
			await get_tree().create_timer(0.4, false).timeout
		_set_performance("")
		await _speak_and_wait([ending[2]])
	else:
		if not ending.is_empty():
			await _speak_and_wait([ending[0]])
		await get_tree().create_timer(0.5, false).timeout
		if lola != null:
			await lola.turn_back()
			await get_tree().create_timer(0.4, false).timeout
		await _speak_and_wait(ending.slice(1))
	_summit = "done"
	Telemetry.record_event("summit", {"bloomed": targets.size(), "voice": voice_hook(),
		"ending": ending_hook()})
	_complete_level()


## Below the summit again (a checkpoint): the world in colour, lola at her painting, nothing
## bloomed yet.
func _reset_summit() -> void:
	_framing_lolo = false
	if _summit == "done":
		return
	_summit = ""
	for child in _hud_before_summit:
		if is_instance_valid(child):
			(child as CanvasItem).visible = bool(_hud_before_summit[child])
	_hud_before_summit.clear()
	# A restore can land outside the last cluster. Clear its camera room before the
	# following physics tick decides which authored region the new landing belongs to.
	var camera := _world_camera()
	if camera != null:
		camera.release_focus(0.0)
		camera.set_room_bounds(Rect2())
		camera.vertical_pin_y = NAN
		camera.offset = Vector2.ZERO
	for voice in _weather_players:
		if not voice.playing:
			voice.play()
	if action_prompts != null:
		action_prompts.suppressed = false
	status_label.show()
	if is_instance_valid(player):
		player.set_physics_process(true)
	_attempts = 0
	for picture in _bloomed:
		picture.queue_free()
	_bloomed.clear()
	if is_instance_valid(_places_ink):
		_places_ink.queue_free()
	_places_ink = null
	_whiten(0.0, 0.0)
	var lola := _lola()
	if lola != null:
		lola.face_the_painting()


# --- The frame returns --------------------------------------------------------------------

var _went_home := false


## What the apo tells lola in the real room: the places she saved, in the order she saved them,
## and lolo last -- the man lola lost first, given back to her last.
func frame_hooks() -> Array[String]:
	var hooks: Array[String] = ["FRAME.open"]
	for fragment in bloom_targets():
		hooks.append("FRAME." + fragment.fragment_id)
	hooks.append("FRAME.lolo")
	hooks.append("FRAME.brush")
	return hooks


func went_home() -> bool:
	return _went_home


# --- The mountain heard, then silence ------------------------------------------------------
var _weather_players: Array[AudioStreamPlayer] = []


func _start_weather_audio() -> void:
	for sound in ["eruption", "wind"]:
		var voice := AudioStreamPlayer.new()
		voice.name = "Mayon" + sound.capitalize()
		var recording := load("res://assets/Level5/audio/%s.wav" % sound) as AudioStreamWAV
		if recording == null:
			continue
		var loop := recording.duplicate() as AudioStreamWAV
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_end = int(loop.get_length() * loop.mix_rate)
		voice.stream = loop
		voice.bus = &"SFX"
		voice.volume_db = -12.0 if sound == "eruption" else -18.0
		add_child(voice)
		voice.play()
		_weather_players.append(voice)


func _stop_weather_audio() -> void:
	for voice in _weather_players:
		voice.stop()
