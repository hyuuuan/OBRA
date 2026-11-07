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
##   * THE CRATER OPENS INTO TWELVE WALKABLE MEMORIES. The checkpoints stay silent.
##   * IT ENDS WITH ITS OWN SCENE. The summit and the return home are the ending (Kent,
##     2026-10-25). A foreground shadow reveals each place; the summit leads home.


const JourneyScript = preload("res://scripts/mayon_memory_journey.gd")
const CraterScript = preload("res://scripts/mayon_crater_2d.gd")
var _journey: Node
var _ascent_camera_left := 0.0
var _phase := "ascent"
var _crater_cover: ColorRect
var _crater_transition: Tween
var _restored_camera: Array = []


func level_config_path() -> String:
	return "res://config/level_05.json"


func dialogue_path() -> String:
	return "res://config/dialogue_l5.json"


func _on_backend_ready() -> void:
	status_label.text = ""


func _apo_can_swim() -> bool:
	# Mayon's only water volume is the submerged reef memory.
	return true


func _on_backend_failed(message: String) -> void:
	if _brush_refuses_here() or _lolo_moment == "going" or not _summit.is_empty():
		return
	super(message)


func _spawn_lolo() -> void:
	super()
	if lolo != null:
		lolo.set_thinness(0.25)


## Who says the level's notes and hints. Lolo, while he climbs with her; the apo once he has gone,
## as in Dilim. He goes mid-sentence, in a frame (_let_him_go), and a hint under his name after it
## -- "There is no more ink for that one", the moment a player at an empty gauge draws below the
## summit -- brought him back for a line.
func _companion_speaker() -> String:
	if lolo != null and is_instance_valid(lolo) and lolo.is_gone():
		return APO_SPEAKER
	return super()


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


## THE HOUSE IS THE ENDING NOW (DIARY.md; Kent, 2026-11-01): "lolo let's go home", and the apo is
## home -- in the house, where Lolo is in every painting and Lola is waiting (HouseEpilogue). It
## replaced the frame's return, a separate painted room with an ordinary brush in it.
func _play_own_ending() -> void:
	refresh_objective()
	objective_banner.show()
	await _speak_and_wait(script_lines.fire("APO.home"))
	AudioDirector.stop_music()
	_went_home = true
	LevelManager.return_to_house()


func _checkpoint_place(checkpoint_id: String) -> String:
	match checkpoint_id:
		"CP1":
			return "among the remembered places"
		"CP2":
			return "below the white summit"
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
	_build_memory_journey()
	_gather_fragments()
	memory_sketch.submitted.connect(_preserve_memory)
	memory_sketch.closed.connect(func() -> void: _locked_fragment = null)
	_gather_the_ash()


func _level_physics(anchor_position: Vector2) -> void:
	if action_prompts != null:
		action_prompts.set_swimming(player is Wanderer and (player as Wanderer).is_in_water())
	var crater := _anchor("crater")
	var far_rim := crater.x + CraterScript.WIDTH * 0.5
	var over_mouth := anchor_position.x >= crater.x - CraterScript.WIDTH * 0.5 and anchor_position.x <= far_rim
	var in_throat := over_mouth and anchor_position.y > crater.y + 120.0
	# A flying drawing cannot bypass the journey by clearing the far lip.
	if _phase == "ascent" and (in_throat or anchor_position.x > far_rim):
		_enter_crater()
		return
	if _phase == "crater_drop": return
	if anchor_position.y > _lowest_ground() + FALL_BELOW:
		var words := _line("FELL")
		_return_to_safety(words, words)
		return
	_hold_the_drain(get_physics_process_delta_time())
	if _phase == "ascent":
		_tend_act_one(get_physics_process_delta_time(), anchor_position.x)
	else:
		_journey.sync()
		_tend_clusters(anchor_position.x)
	_tend_summit(get_physics_process_delta_time(), anchor_position.x)
	_rescue_reserve_drawings()
	if _summit.is_empty():
		var status_visible := not status_label.text.is_empty()
		if status_label.visible != status_visible:
			status_label.visible = status_visible
			hud_panel.reset_size()
	var target := _fragment_here()
	for fragment in _fragments:
		fragment.set_targeted(fragment == target)
	_tend_lolo(get_physics_process_delta_time(), anchor_position.x)
	if _tremor != null:
		_tremor.amplitude = 0.0 if Motion.reduced() else 3.0
	if not _summit.is_empty():
		# Keep the next objective visible, with Draw as the only action during the performance.
		var brush_up := _summit in ["trying", "places"]
		for child in $CanvasLayer.get_children():
			if child is CanvasItem and child not in [hud_panel, objective_banner, objective_marker, draw_button]:
				(child as CanvasItem).hide()
		objective_banner.show()
		draw_button.visible = brush_up
		if action_prompts != null:
			action_prompts.suppressed = true
			action_prompts.keeps_draw = brush_up
		status_label.hide()
		if objective_marker != null and _summit != "quiet": objective_marker.clear()

func _on_ink_emptied() -> bool:
	# His disappearance includes his voice; an optional late morph must not bring him back.
	if lolo != null and not lolo.is_gone():
		_speak(script_lines.fire("INK.empty"))
	return true


## The banner follows the current gate or journey phase.
func _current_objective() -> Dictionary:
	if director == null: return {}
	match _summit:
		"quiet": return {"key": "summit", "target": _anchor("summit_speak")}
		"trying": return {"key": "summit_try" if _attempts == 0 else "summit_again"}
		"lowering": return {"key": "summit_lowering"}
		"places": return {"key": "summit_places"}
		"blooming": return {"key": "summit_blooming"}
		"done": return {"key": "complete"}
	if _lolo_moment == "waiting": return {"key": "farewell"}
	if _lolo_moment == "going": return {"key": "farewell_going"}
	if _lolo_moment == "gone": return {"key": "summit", "target": _anchor("summit_speak")}
	if _phase != "ascent":
		if ink_manager.remaining() < InkManager.UNIT: return {"key": "memory_empty"}
		if _fragment_here() != null: return {"key": "memory_near"}
		var here: String = _journey.current_id(_player_anchor_position())
		var saved_here := false
		var open_here := false
		var had_memory := false
		for fragment in _fragments:
			if fragment.vignette_id != here: continue
			had_memory = true
			open_here = open_here or fragment.is_open()
			saved_here = saved_here or fragment.state() == "saved"
		if not open_here and had_memory:
			return {"key": "memory_saved" if saved_here else "memory_lost"}
		return {"key": "memories"}
	match String(director.current_obstacle()):
		"L5_SPAN":
			return {"key": "span"} if not director.is_solved("L5_SPAN") else {"key": "slope"}
		"L5_CLIMB":
			return {"key": "climb"} if not director.is_solved("L5_CLIMB") else {"key": "crater"}
	return {"key": "foot" if is_instance_valid(player) and player.global_position.x < 1400.0 else "crater"}

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

## How long a fragment with lolo in it steadies him.
const STEADY_SECONDS := 60.0
## How fast his thinness follows where it should be, per second.
const THINNING := 0.25
## Where lolo goes with all three of his fragments saved; each one let go brings it nearer.
const LOLO_GOES_SOONER := 40.0
## How long she stands before raising the brush herself. Four, not eight (Kent, 2026-11-05: the
## summit "takes soo long"): long enough to press R, short enough not to read as a hang.
const RAISE_AFTER := 4.0

var _fragments: Array[MemoryFragment2D] = []
var _steady_left := 0.0
## "" before, "waiting" while the brush is raised to him, "going", then "gone".
var _lolo_moment := ""
var _framing_lolo := false
var _raise_left := 0.0
var _corridor_seen := false
@onready var memory_sketch = $MemorySketch
var _locked_fragment: MemoryFragment2D
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
	# These landmarks belong to this run, including when another level is leaving the tree.
	_fragments.assign(_journey.fragments)
	for fragment in _fragments:
		fragment.saved.connect(_on_fragment_saved)
		fragment.lost.connect(_on_fragment_lost)


func _open_the_page(tell_the_director: bool) -> void:
	if placement_controller.is_placing() or memory_sketch.is_open() or draw_panel.is_open():
		return
	var fragment := _fragment_here() if not _brush_refuses_here() else null
	if fragment == null:
		super(tell_the_director)
		return
	if ink_manager.remaining() < InkManager.UNIT:
		_say_why(_line("FRAGMENT.no_ink"))
		return
	_locked_fragment = fragment
	var reference := fragment.get_node("Picture") as Sprite2D
	memory_sketch.present(_memory_name(fragment.fragment_id), reference.texture,
		int(floor(ink_manager.remaining() / InkManager.UNIT)))


func _prepare_drawing_page() -> void:
	if _summit == "places":
		draw_panel.set_drawing_mode(DrawPanel.DrawingMode.FREE_PAINT)
	if _brush_refuses_here():
		status_label.text = ""
		_set_performance("raise")
		_raise_into_paint()
	var context := ""
	if _lolo_moment == "waiting": context = "lolo_page"
	elif _summit == "trying": context = "lola_page"
	elif _summit == "places": context = "places_page"
	var words: Dictionary = director.level_data().get("guidance", {}).get(context, {})
	draw_panel.set_drawing_context(String(words.get("title", "")), String(words.get("text", "")))


func _raise_into_paint() -> void:
	await get_tree().create_timer(0.4, true).timeout
	if draw_panel.is_open() and draw_panel.is_refusing():
		_set_performance("paint")


## Her last drawing blooms the places -- and so does a page she left untouched (DrawPanel
## QUIET_UNTOUCHED): the climax cannot fail, and it cannot stall either.
func _free_paint_completed(strokes: Array) -> void:
	if _summit != "places":
		return
	_places_strokes = DrawnItemData.copy_strokes(strokes)
	_summit = "blooming"
	refresh_objective()
	_set_performance("lower")
	_bloom_the_places()


func _spawn_or_replace(entity_id: String, display_name: String, drawing: Image, strokes: Array) -> bool:
	# Leave enough to survive the first drain tick after paying for the drawing.
	var first_tick_cost := _drain.rate_for(entity_id) / Engine.physics_ticks_per_second
	if ink_manager.remaining() <= InkManager.UNIT + first_tick_cost + InkManager.EMPTY_THRESHOLD:
		_say_why(_line("MORPH.no_ink"))
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


func _tend_clusters(_her_x: float) -> void:
	if _journey == null or not _journey.enabled: return
	var index: int = _journey.active_index(_player_anchor_position())
	var current: String = _journey.places[index].id
	if not _clusters_seen.has(current):
		_clusters_seen.append(current)
		for fragment in _fragments:
			if fragment.vignette_id == current: fragment.begin_whitening()
	for prior in range(index):
		var id: String = _journey.places[prior].id
		if _clusters_left.has(id): continue
		_clusters_left.append(id)
		for fragment in _fragments:
			if fragment.vignette_id == id: fragment.leave_behind()
		_write_checkpoint("CP1")
	_active_cluster = current

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


## The sketchbook submits raw strokes to the landmark that opened it.
func _preserve_memory(strokes: Array) -> void:
	if not memory_sketch.is_open() or strokes.is_empty():
		return
	var fragment := _locked_fragment
	memory_sketch.close()
	if not is_instance_valid(fragment) or not fragment.is_open():
		return
	if not ink_manager.spend_unit():
		_say_why(_line("FRAGMENT.no_ink"))
		return
	_save_order.append(fragment.fragment_id)
	fragment.save(strokes)
	refresh_objective()


## The nearest fragment she could still save, if one is in reach.
func _fragment_here() -> MemoryFragment2D:
	if not is_instance_valid(player) or _journey == null or not _journey.enabled or _phase not in ["memories", "farewell"]:
		return null
	var current: String = _journey.current_id(_player_anchor_position())
	var best: MemoryFragment2D = null
	var nearest := INF
	var airborne := player is CharacterBody2D and not (player as CharacterBody2D).is_on_floor()
	for fragment in _fragments:
		if fragment.vignette_id != current or (fragment.needs_footing and airborne): continue
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
	_memory_feedback("saved", fragment_id)
	AudioDirector.play_sfx(&"mayon_brush", 0.6)
	Telemetry.record_event("fragment", {"id": fragment_id, "outcome": "saved", "method": "freehand"})
	var fragment := _fragment(fragment_id)
	var can_speak := is_instance_valid(lolo) and not lolo.is_gone()
	if fragment_id == "flower" and not _flower_credited:
		# The useless one, saved anyway: the fifth flower, and the artist's choice.
		PlayerProfile.record_collectible("L5_HF")
		if not PlayerProfile.routes_taken_at("level_5", "L5_HF").has("artist"):
			PlayerProfile.record_route("level_5", "artist")
			PlayerProfile.record_obstacle_route("level_5", "L5_HF", "artist")
		_flower_credited = true
		if can_speak: _speak(script_lines.fire("FLOWER.saved"))
	elif fragment != null and fragment.holds_lolo:
		_steady_left = STEADY_SECONDS
		if can_speak: _speak(script_lines.fire("LOLO.steadied." + fragment_id))


func _on_fragment_lost(fragment_id: String) -> void:
	Telemetry.record_event("fragment", {"id": fragment_id, "outcome": "lost"})
	_memory_feedback("lost", fragment_id)


func _memory_feedback(outcome: String, fragment_id: String) -> void:
	if not _summit.is_empty() or _lolo_moment in ["waiting", "going", "gone"]: return
	var guidance: Dictionary = director.level_data().get("guidance", {})
	# HudNotice is independent of standing hints, so a successful save cannot be
	# swallowed by Lolo's teaching line. It remains until gameplay resumes.
	status_label.text = String(guidance.get(outcome, "")).replace("{memory}", _memory_name(fragment_id))
	status_label.show()


func _memory_name(fragment_id: String) -> String:
	var guidance: Dictionary = director.level_data().get("guidance", {})
	return String(guidance.get("memory_names", {}).get(fragment_id, "This memory"))


func _saved_lolo_fragments() -> int:
	var count := 0
	for fragment in _fragments:
		if fragment.holds_lolo and fragment.state() == "saved":
			count += 1
	return count


## Where he goes: sooner, the fewer of his fragments she saved. He goes either way.
func lolo_goes_at() -> float:
	return _anchor("farewell").x - LOLO_GOES_SOONER * (3 - _saved_lolo_fragments())

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
		want = 0.25 if _phase == "ascent" else minf(0.7, 0.35 + float(_journey.active_index(_player_anchor_position())) * 0.03)
		lolo.set_thinness(move_toward(lolo.thinness(), want, THINNING * delta))
	if not _corridor_seen and _phase == "memories":
		# The painting stops being Mayon: the first sight of them.
		_corridor_seen = true
		# And she sees what it is: every one of hers, going at once.
		_speak(script_lines.fire("L5_CORRIDOR.enter") + script_lines.fire("APO.why.3"))
	match _lolo_moment:
		"":
			if _phase in ["memories", "farewell"] and her_x >= lolo_goes_at():
				_phase = "farewell"
				# The preservation journey is over. Its final choices must go with it,
				# even if she walks back before the last foreground shadow clears.
				for fragment in _fragments: fragment.leave_behind()
				for index in range(_journey.places.size()-1):
					var id: String = _journey.places[index].id
					if not _clusters_left.has(id): _clusters_left.append(id)
				_lolo_moment = "waiting"
				_raise_left = RAISE_AFTER
				refresh_objective()
				_write_checkpoint("CP1")
				# Before the brush is raised to him, she thinks she can still mend it (Kent,
				# 2026-11-01): "wait i can fix this". It is what makes the refusal land.
				_speak(script_lines.fire("LOLO.fading") + script_lines.fire("APO.fix"))
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
	refresh_objective()


## He understands before she does, and says so -- and mid-sentence he is not there. No farewell,
## no fade: that is how it happens when someone is forgotten rather than when someone dies.
func _let_him_go() -> void:
	if not dialogue_box.line_progress.is_connected(_on_lolo_line_progress):
		dialogue_box.line_progress.connect(_on_lolo_line_progress)
	_framing_lolo = true
	await _speak_and_wait(script_lines.fire("LOLO.goes") + script_lines.fire(lolo_last_hook()))
	dialogue_box.line_progress.disconnect(_on_lolo_line_progress)
	_vanish_lolo()
	_framing_lolo = false
	_release_camera_focus()
	_set_performance("")


## HIS LAST LINE IS THE RUN'S (Kent, 2026-11-01: "DEPENDING ON THE MAJORITY OF THE CHOICES and the
## paths taken ... lolo will have a different last line"): what he saw in her on the way up, by the
## route the whole run leaned toward -- the summit's monologue is voiced the same way. Each ends
## mid-word at "kept m", which is where he goes (_on_lolo_line_progress). Written out, one hook a
## route, so every line is a literal a reader can find.
const LOLO_LAST := {
	"artist": "LOLO.goes.artist",
	"pragmatist": "LOLO.goes.pragmatist",
	"protector": "LOLO.goes.protector",
}


func lolo_last_hook() -> String:
	return String(LOLO_LAST.get(PlayerProfile.dominant_route(), LOLO_LAST["artist"]))


func _on_lolo_line_progress(text: String, characters: int) -> void:
	if _lolo_moment == "going" and text.ends_with("kept m") and characters >= text.length():
		_vanish_lolo()
		# Close the box after its typing callback finishes so the summit can begin.
		dialogue_box.hide_line.call_deferred()


func _vanish_lolo() -> void:
	if _lolo_moment == "gone":
		return
	lolo.vanish()
	dialogue_box.hide_speaker()
	if hint_bar != null:
		hint_bar.clear()
	status_label.text = ""
	_lolo_moment = "gone"
	refresh_objective()
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
	return {"layout_version": 5, "phase": _phase, "active_vignette": _active_cluster,
		"camera_position": [_world_camera().global_position.x, _world_camera().global_position.y], "fragments": fragments, "steady_left": _steady_left,
		"lolo_thinness": lolo.thinness() if is_instance_valid(lolo) else 1.0,
		"taken": taken, "forgot": _forgot, "wondered": _wondered, "save_order": _save_order.duplicate(),
		"clusters_seen": _clusters_seen.duplicate(), "clusters_left": _clusters_left.duplicate(),
		"lolo_moment": _lolo_moment, "corridor_seen": _corridor_seen,
		"flower_credited": _flower_credited, "places_strokes": _places_strokes.duplicate(true)}


func _restore_level_run_state(state: Dictionary) -> void:
	memory_sketch.close()
	_restored_camera = state.get("camera_position", []) if int(state.get("layout_version", 1)) >= 5 else []
	_restore_journey_phase(state)
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
	_wondered = int(state.get("wondered", 0))
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
	var saved: Dictionary = state.get("level", {})
	if int(saved.get("layout_version", 1)) < 4:
		if checkpoints.latest_id() == "CP2":
			_lolo_moment = "gone"
			if lolo != null: lolo.vanish()
			return _anchor("summit") + Vector2(-100, 0)
		if checkpoints.latest_id() == "CP1": return _anchor("entry")
		return spawn_point.global_position
	if int(saved.get("layout_version", 1)) == 4 and String(saved.get("phase", "ascent")) != "ascent":
		# The compact itinerary retains IDs and outcomes, but the old world coordinates
		# no longer point to the same place. Resume at a safe entrance with a fresh camera.
		if String(saved.get("phase")) in ["farewell", "summit"]:
			return _anchor("summit") + Vector2(-100, 0) if _lolo_moment == "gone" else _anchor("farewell")
		var index: int = _journey.index_of(String(saved.get("active_vignette", "")))
		if index >= 0:
			return Vector2(float(_journey.places[index].start)+170, _anchor("entry").y)
		return _anchor("entry")
	return super(state)

func _give_back_what_cannot_come_back(_state: Dictionary) -> void:
	# Mayon's checkpoints are beyond both gates. Their abandoned answers remain paid:
	# refunding a reserve-funded prop into visible ink would create extra memory choices.
	pass


# --- Act One: the ascent ------------------------------------------------------------------

## The ash, by where she is: thin at the foot, thick on the cone and in the corridor, gone at the
## summit -- where there is no ash, no tremor and no sound.
const ASH := [[1800.0, 0.2], [4200.0, 0.4], [5500.0, 0.6], [INF, 0.0]]
## How fast the ash thickens or thins toward where she is, per second.
const ASH_EASE := 0.1
## The eruption, felt: every so often below the summit.
const TREMOR_EVERY := 18.0
## Lolo's forgetting on the way up, by where she is. Light at first; by the third it is not funny.
const FORGETTING := [[1000.0, "LOLO.forget.1"], [2900.0, "LOLO.forget.2"], [4700.0, "LOLO.forget.3"]]
## And the apo working out why everything is going (Kent, 2026-11-01: "the apo should have dialogue
## on why everything is disappearing"): once the first thing the ash settled on has gone white
## (1800), and again once she has heard him lose a word. The third is said in the corridor.
const WONDERING := [[2100.0, "APO.why.1"], [3500.0, "APO.why.2"]]

var _taken: Array[Node2D] = []
var _going := {}
var _ash: AshFall2D
var _wind: Node2D
var _tremor: ScreenTremor
var _forgot := 0
var _wondered := 0


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
	_wind = get_node_or_null(^"EnvironmentBaseplate/WorldCamera/Wind") as Node2D
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
	if _wind != null:
		_wind.set("enabled", _phase == "ascent")
	if _tremor != null:
		_tremor.enabled = _phase == "ascent"
	if _forgot < FORGETTING.size() and her_x >= float(FORGETTING[_forgot][0]):
		var hook := String(FORGETTING[_forgot][1])
		_forgot += 1
		_speak(script_lines.fire(hook))
	if _wondered < WONDERING.size() and her_x >= float(WONDERING[_wondered][0]):
		var wondering := String(WONDERING[_wondered][1])
		_wondered += 1
		_speak(script_lines.fire(wondering))


# --- Act Three: the summit ----------------------------------------------------------------

## Where the summit begins (the world goes white and still), and where she speaks to lola.
## How long the white takes to come over everything.
const WHITE_SECONDS := 4.0
## How white: paper, not blank -- the ground she stands on stays.
const WHITE := 0.85
## Keep both people above the dialogue box while their saved places bloom above them.
## Relative to the configured floor, so the crater journey and migrated layouts share the
## incoming framing fix without reintroducing the old summit's world coordinates.
const SUMMIT_EYE_HEIGHT := 80.0
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
	"EnvironmentBaseplate/GameplayPlane/Terrain/Cone": 0.55,
	"EnvironmentBaseplate/GameplayPlane/UpperDressing": 0.85}

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
			if _phase in ["memories", "farewell", "summit"] and her_x >= _anchor("summit").x and gone:
				_phase = "summit"
				_summit = "quiet"
				if not _current_form_id.is_empty():
					_revert_to_base_form()
				for child in $CanvasLayer.get_children():
					if child is CanvasItem and child != hud_panel:
						_hud_before_summit[child] = (child as CanvasItem).visible
				if placement_controller.is_placing():
					placement_controller.cancel_placement()
				_stow_equipped()
				if _tremor != null:
					_tremor.set("_left", 0.0)
				_set_performance("")
				var camera := _world_camera()
				if camera != null:
					camera.offset = Vector2.ZERO
					var floor_y := _anchor("lola").y
					camera.set_room_bounds(Rect2(_anchor("summit").x-300,floor_y-820,1800,1200))
					camera.vertical_pin_y = floor_y-SUMMIT_EYE_HEIGHT
				_whiten(WHITE, WHITE_SECONDS)
				# And still at once: no ash left drifting over the white.
				if _ash != null:
					_ash.density = 0.0
		"quiet":
			if her_x >= _anchor("summit_speak").x:
				_summit = "trying"
				refresh_objective()
				if not _current_form_id.is_empty():
					_revert_to_base_form()
				var lola := _lola()
				if lola != null:
					player.call("apply_morph_state", {"position": lola.global_position + Vector2(-250, 0),
						"linear_velocity": Vector2.ZERO})
				player.set_physics_process(false)
				_stand_before(lola)
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
				refresh_objective()


## ⚠ STANDING, NOT STOPPED. Her physics stops in front of Lola, and her pose is set by her physics:
## she hung in whatever frame she arrived in, mid-stride or mid-jump above the floor, with every
## key gone, for the whole beat -- Kent: "when i approach lola the game freezes". She stands, facing
## Lola, and the brush's key stays on screen (_level_physics) while the brush can be raised.
func _stand_before(lola: Node2D) -> void:
	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO
	if lola != null and player.has_method("face_toward"):
		player.call("face_toward", lola.global_position.x)
	var figure := player.get_node_or_null(^"Figure")
	if figure != null:
		figure.set(&"pose", &"idle")
		figure.set(&"stride", 0.0)
		if figure.has_method(&"refresh"):
			figure.call(&"refresh")


## White in every direction except what she saved.
func _whiten(amount: float, seconds: float) -> void:
	if _journey != null and _journey.enabled:
		var scene: Node2D = _journey.scenes[-1]
		var wash := scene.get_node_or_null("SummitDrain") as Drainable
		if wash == null:
			wash = Drainable.new()
			wash.name = "SummitDrain"
			scene.add_child(wash)
		var tween := wash.drain_to(amount, seconds)
		if tween != null: tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
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


## The last page of her diary, found at her easel after she turns back to it.
const LAST_PAGE := "mayon"


## Five flowers: for a moment she is known. Fewer: lola is warm to a child she does not know.
func ending_hook() -> String:
	return "ENDING.perfect" if PlayerProfile.flower_count() >= ALL_FLOWERS else "ENDING.standard"


## WHERE WHAT SHE SAVED STANDS, relative to Lola's feet, inside what the summit's camera shows
## (SUMMIT_EYE_HEIGHT; its room in _tend_summit). They were spaced at fixed points whatever their
## sizes, so the terraces buried the church, the storm sat behind both and the bangka ran off the
## frame (Kent, 2026-11-05: "not pleasing to the eye"). Places on the ground share the frame's width,
## each reaching a little into its neighbour's share; the sky's hang across the top, behind them.
const BLOOM_LEFT := -880.0
const BLOOM_RIGHT := 680.0
const BLOOM_TOP := -510.0
const BLOOM_SPREAD := 1.3


## `pieces`: {width, height, sky, elevation} each, in bloom order. Returns {x, y, width, z} each:
## the centre of each place, its drawn width, and its depth -- the bigger a place on the ground, the
## further back it stands, so nothing small is buried behind something large; the sky behind all.
static func bloom_layout(pieces: Array) -> Array:
	var out: Array = []
	out.resize(pieces.size())
	var ground: Array[int] = []
	for layer_is_sky: bool in [false, true]:
		var members: Array[int] = []
		for index in range(pieces.size()):
			if bool(pieces[index].sky) == layer_is_sky:
				members.append(index)
		if members.is_empty():
			continue
		var share := (BLOOM_RIGHT - BLOOM_LEFT) / members.size()
		# The pair stand mid-frame: the smallest place stands behind them, the largest at the edges.
		var by_size := members.duplicate()
		by_size.sort_custom(func(a: int, b: int) -> bool:
			return float(pieces[a].width) * float(pieces[a].height) > float(pieces[b].width) * float(pieces[b].height))
		var slots: Array[int] = []
		var outer := 0
		var inner := members.size() - 1
		for rank in range(by_size.size()):
			slots.append(outer if rank % 2 == 0 else inner)
			if rank % 2 == 0:
				outer += 1
			else:
				inner -= 1
		for rank in range(by_size.size()):
			var index: int = by_size[rank]
			var slot := slots[rank]
			var piece: Dictionary = pieces[index]
			var width := minf(float(piece.width), share * BLOOM_SPREAD)
			var height := float(piece.height) * width / float(piece.width)
			if not layer_is_sky and height > -BLOOM_TOP:
				width *= -BLOOM_TOP / height
				height = -BLOOM_TOP
			var x := clampf(BLOOM_LEFT + share * (slot + 0.5), BLOOM_LEFT + width * 0.5,
				BLOOM_RIGHT - width * 0.5)
			var y := BLOOM_TOP + height * 0.5 if layer_is_sky \
				else -height * 0.5 + float(piece.elevation)
			out[index] = {"x": x, "y": y, "width": width, "z": -40 - slot if layer_is_sky else 0}
			if not layer_is_sky:
				ground.append(index)
	ground.sort_custom(func(a: int, b: int) -> bool:
		return float(out[a].width) * float(pieces[a].height) / float(pieces[a].width) * float(out[a].width) \
			> float(out[b].width) * float(pieces[b].height) / float(pieces[b].width) * float(out[b].width))
	for depth in range(ground.size()):
		out[ground[depth]].z = -4 - (ground.size() - 1 - depth)
	return out


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
	var pieces: Array = []
	for fragment in targets:
		var art := fragment.summit_texture
		if art == null:
			art = (fragment.get_node(^"Picture") as Sprite2D).texture
		pieces.append({"width": fragment.bloom_width,
			"height": fragment.bloom_width * art.get_height() / art.get_width(),
			"sky": fragment.bloom_layer == "sky", "elevation": fragment.bloom_elevation})
	var layout := bloom_layout(pieces)
	for index in range(targets.size()):
		var picture := Sprite2D.new()
		picture.set_script(preload("res://scripts/memory_bloom_2d.gd"))
		picture.set("ink", targets[index].strokes().duplicate(true))
		picture.texture = targets[index].summit_texture
		if picture.texture == null:
			picture.texture = (targets[index].get_node(^"Picture") as Sprite2D).texture
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var place: Dictionary = layout[index]
		# A landscape planted on the ground, not a row of little collectible cards.
		var fit := float(place.width) / picture.texture.get_width()
		picture.scale = Vector2.ONE * fit
		picture.set("world_scale", fit)
		picture.self_modulate = targets[index].bloom_tint
		picture.position = centre + Vector2(float(place.x), float(place.y))
		picture.z_index = int(place.z)
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
	# HER LAST PAGE, at her easel, once she has turned back to it (DIARY.md): the most broken of
	# them, and the end of the book.
	await find_diary_page(LAST_PAGE)
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
	if action_prompts != null:
		action_prompts.suppressed = false
		action_prompts.keeps_draw = false
	draw_button.mouse_filter = Control.MOUSE_FILTER_STOP
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


func went_home() -> bool:
	return _went_home


# --- The crater and the continuous remembered route --------------------------------------

func _anchor(key: String) -> Vector2:
	return _journey.anchor(key)


func journey_phase() -> String:
	return _phase


func _build_memory_journey() -> void:
	_ascent_camera_left = _world_camera().outdoor_x_limits.x
	_journey = JourneyScript.new()
	_journey.name = "MemoryJourney"
	add_child(_journey)
	_journey.build(self, director.level_data())
	_lola().position = _anchor("lola")
	var plane := get_node("EnvironmentBaseplate/GameplayPlane")
	var floor_y: float = director.level_data().journey.floor_y
	plane.get_node("Obstacles/L5_SUMMIT").position = Vector2(_anchor("summit_speak").x,floor_y-230)
	plane.get_node("Obstacles/CP2").position = Vector2(_anchor("summit").x-100,floor_y-230)
	plane.get_node("Marks/LoloGoesMark").position = Vector2(_anchor("farewell").x,floor_y)
	plane.get_node("Marks/SummitMark").position = Vector2(_anchor("lola").x,floor_y)
	var crater := CraterScript.new()
	crater.name = "Crater"
	crater.position = _anchor("crater")
	get_node("EnvironmentBaseplate/GameplayPlane").add_child(crater)
	var veil := CanvasLayer.new()
	veil.name = "CraterSmoke"
	veil.layer = 2
	veil.add_to_group(&"transition_world")
	add_child(veil)
	_crater_cover = ColorRect.new()
	_crater_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crater_cover.color = Color(0.035, 0.027, 0.04, 0)
	_crater_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.add_child(_crater_cover)


func _enter_crater() -> void:
	_phase = "crater_drop"
	if placement_controller.is_placing(): placement_controller.cancel_placement()
	_crater_transition = create_tween()
	_crater_transition.tween_property(_crater_cover, "color:a", 1.0, 0.25)
	await _crater_transition.finished
	if not is_instance_valid(player): return
	player.call("apply_morph_state", {"position": _anchor("entry"), "linear_velocity": Vector2.ZERO})
	if is_instance_valid(lolo): lolo.global_position = _anchor("entry") + Vector2(-95, 0)
	_world_camera().snap_to_target()
	_set_journey_visible(true)
	_phase = "memories"
	_write_checkpoint("CP1")
	_crater_transition = create_tween()
	_crater_transition.tween_property(_crater_cover, "color:a", 0.0, 0.4)


func _set_journey_visible(on: bool) -> void:
	# The compact entrance can show the existing far rim, but must not pan back into
	# the hidden crater gap while the first memory fills the frame.
	_world_camera().outdoor_x_limits.x = _anchor("crater").x+CraterScript.WIDTH*.5 if on else _ascent_camera_left
	for path in ["SkyFill", "SkyBand", "GameplayPlane/Dressing", "GameplayPlane/UpperDressing",
		"GameplayPlane/AshTakes", "GameplayPlane/Terrain/Slopes", "GameplayPlane/Terrain/Cone", "GameplayPlane/Crater"]:
		var item := get_node_or_null("EnvironmentBaseplate/" + path) as CanvasItem
		if item != null: item.visible = not on
	# The optional flower's rocks must be visible inside its scenery pass, never over another place.
	get_node("EnvironmentBaseplate/GameplayPlane/Terrain/FlowerLedge").visible = not on
	_journey.activate(on)
	if _ash != null: _ash.density = 0.0 if on else 0.25
	if _wind != null: _wind.set("enabled", not on)
	if _tremor != null: _tremor.enabled = not on
	if not on and minimap != null:
		minimap.get("_view").world_2d = get_viewport().find_world_2d()
	_world_camera().set_room_bounds(Rect2())
	_world_camera().vertical_pin_y = NAN


func _restore_journey_phase(state: Dictionary) -> void:
	if _crater_transition != null and _crater_transition.is_valid(): _crater_transition.kill()
	_crater_cover.color.a = 0.0
	_phase = String(state.get("phase", "ascent"))
	if int(state.get("layout_version", 1)) < 4:
		_phase = "farewell" if checkpoints.latest_id() == "CP2" else ("memories" if checkpoints.latest_id() == "CP1" else "ascent")
	if _phase == "crater_drop": _phase = "memories"
	_set_journey_visible(_phase != "ascent")


func _minimap_region() -> Rect2:
	if _journey != null and _journey.enabled: return _journey.region(_player_anchor_position())
	return super()


func _restore_checkpoint() -> String:
	var result := super()
	if result.is_empty(): return result
	var camera := _world_camera()
	if _restored_camera.size() == 2:
		camera.global_position = Vector2(float(_restored_camera[0]),float(_restored_camera[1]))
	else:
		camera.snap_to_target()
	camera.force_update_scroll()
	if _journey.enabled:
		_journey.travel_camera_x = camera.global_position.x
		_journey.sync()
	return result
