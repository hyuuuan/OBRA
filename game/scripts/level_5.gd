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
##     2026-10-25); until they are built, finishing takes her home.
##
## This is the shell: the climb and its gates. The fragments, Lolo's thread, the summit and the
## frame come with their PRs.


func level_config_path() -> String:
	return "res://config/level_05.json"


func dialogue_path() -> String:
	return "res://config/dialogue_l5.json"


## How far under the mountain's lowest ground a fall goes before she is put back.
const FALL_BELOW := 1000.0
## The gates the climb cannot be finished without: the hidden reserve pays for them.
const GATES := ["L5_SPAN", "L5_CLIMB"]


## Every drawing costs a unit, not only the first of its kind: there is no clearing here to give
## any back, and what she spends is the story.
func _every_drawing_costs_ink() -> bool:
	return true


## Only a gate may draw on the reserve, and only while she stands in it.
func _may_use_hidden_ink(_entity_id: String) -> bool:
	return director != null and String(director.current_obstacle()) in GATES


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
	add_child(frame)
	for hook in frame_hooks():
		await _speak_and_wait(script_lines.fire(hook))
	await frame.cut_to_black()
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


func _level_physics(anchor_position: Vector2) -> void:
	if anchor_position.y > _lowest_ground() + FALL_BELOW:
		var words := _line("FELL")
		_return_to_safety(words, words)
		return
	_hold_the_drain(get_physics_process_delta_time())
	_tend_act_one(get_physics_process_delta_time(), anchor_position.x)
	_tend_summit(get_physics_process_delta_time(), anchor_position.x)
	for fragment in _fragments:
		fragment.notice(anchor_position.x)
	# The one a drawing would go into now is lit, and only it.
	var target := _fragment_here()
	for fragment in _fragments:
		fragment.set_targeted(fragment == target)
	_tend_lolo(get_physics_process_delta_time(), anchor_position.x)


func _on_ink_emptied() -> bool:
	_speak(script_lines.fire("INK.empty"))
	return true


## The banner: the gate she stands at, while it is open; the climb everywhere else.
func _current_objective() -> Dictionary:
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
const CORRIDOR := Vector2(5400.0, 13000.0)
## How long a fragment with lolo in it steadies him.
const STEADY_SECONDS := 60.0
## How thin lolo is, by where she is: the foot and the treeline, the mid slope, the corridor.
const THINNESS := [[4200.0, 0.25], [9200.0, 0.45], [INF, 0.7]]
## How fast his thinness follows where it should be, per second.
const THINNING := 0.25
## Where lolo goes with all three of his fragments saved; each one let go brings it nearer.
const LOLO_GOES_X := 12400.0
const LOLO_GOES_SOONER := 250.0
## How long she stands before raising the brush herself.
const RAISE_AFTER := 8.0

var _fragments: Array[MemoryFragment2D] = []
var _steady_left := 0.0
## "" before, "waiting" while the brush is raised to him, "going", then "gone".
var _lolo_moment := ""
var _raise_left := 0.0
var _saved_class := ""
var _corridor_seen := false


func _gather_fragments() -> void:
	_fragments.clear()
	for node in get_tree().get_nodes_in_group(&"memory_fragments"):
		var fragment := node as MemoryFragment2D
		_fragments.append(fragment)
		fragment.saved.connect(_on_fragment_saved)
		fragment.lost.connect(_on_fragment_lost)


## A DRAWING NEAR A FRAGMENT GOES INTO IT -- not into the bag, the hand or a body. One unit of ink,
## never the hidden reserve (that is the gates'), and it is saved. A drawing that does not belong
## is handed back free, with one quiet line and no class named. Away from any fragment, a drawing
## is a drawing.
func _on_drawing_ready(entity_id: String, display_name: String, drawing: Image,
		response: Dictionary, strokes: Array, ink_cost: float) -> void:
	var fragment := _fragment_here()
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
	Telemetry.record_event("fragment", {"id": fragment_id, "outcome": "saved", "class": _saved_class})
	var fragment := _fragment(fragment_id)
	if fragment_id == "flower":
		# The useless one, saved anyway: the fifth flower, and the artist's choice.
		PlayerProfile.record_collectible("L5_HF")
		PlayerProfile.record_route(LevelManager.current_level_id, "artist")
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
	elif _summit == "places":
		_summit = "blooming"
		_bloom_the_places()


## He understands before she does, and says so -- and mid-sentence he is not there. No farewell,
## no fade: that is how it happens when someone is forgotten rather than when someone dies.
func _let_him_go() -> void:
	await _speak_and_wait(script_lines.fire("LOLO.goes"))
	lolo.vanish()
	_lolo_moment = "gone"
	Telemetry.record_event("lolo_gone", {"steadied_by": _saved_lolo_fragments()})


## What a checkpoint keeps of Act Two: each fragment as it stood, her lines in the saved ones,
## and how long lolo is steady for.
func _level_run_state() -> Dictionary:
	var fragments := {}
	for fragment in _fragments:
		var held := fragment.state()
		fragments[fragment.fragment_id] = {
			"state": held if held == "saved" or held == "lost" else "whole",
			"strokes": fragment.strokes().duplicate(true),
		}
	var taken: Array = []
	for thing in _taken:
		if bool(_going.get(thing, false)):
			taken.append(String(thing.name))
	return {"fragments": fragments, "steady_left": _steady_left, "taken": taken, "forgot": _forgot}


func _restore_level_run_state(state: Dictionary) -> void:
	var fragments: Dictionary = state.get("fragments", {})
	for fragment in _fragments:
		var entry: Dictionary = fragments.get(fragment.fragment_id, {})
		fragment.restore_to(String(entry.get("state", "whole")), entry.get("strokes", []))
	_steady_left = float(state.get("steady_left", 0.0))
	# What the ash had taken by the checkpoint stays taken; what it had not comes back.
	var taken: Array = state.get("taken", [])
	for thing in _taken:
		var drainable := thing.get_node("Drainable") as Drainable
		if taken.has(String(thing.name)):
			drainable.drain_to(1.0, 0.0)
			_going[thing] = true
		else:
			drainable.restore()
			_going[thing] = false
	_forgot = int(state.get("forgot", _forgot))
	_reset_summit()
	if _lolo_moment == "waiting":
		_lolo_moment = ""


# --- Act One: the ascent ------------------------------------------------------------------

## The ash, by where she is: thin at the foot, thick on the cone and in the corridor, gone at the
## summit -- where there is no ash, no tremor and no sound.
const ASH := [[1800.0, 0.2], [4200.0, 0.4], [5400.0, 0.6], [13000.0, 1.0], [INF, 0.0]]
## How fast the ash thickens or thins toward where she is, per second.
const ASH_EASE := 0.1
## The eruption, felt: every so often below the summit.
const TREMOR_EVERY := 18.0
const SUMMIT_X := 13000.0
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
const SUMMIT_ARRIVE := 14400.0
const SUMMIT_SPEAK := 14900.0
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
	"EnvironmentBaseplate/VolcanoBand": 0.85, "EnvironmentBaseplate/MeadowBand": 0.85,
	"EnvironmentBaseplate/EarthBand": 0.85, "EnvironmentBaseplate/GameplayPlane/Terrain/Cone": 0.55}

## "" below, "quiet", "trying" (the brush raised to her), "lowering", "places", "blooming", "done".
var _summit := ""
var _attempts := 0
var _beat_left := 0.0
var _save_order: Array[String] = []
var _bloomed: Array[Sprite2D] = []


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
				_whiten(WHITE, WHITE_SECONDS)
		"quiet":
			if her_x >= SUMMIT_SPEAK:
				_summit = "trying"
				_attempts = 0
				_raise_left = RAISE_AFTER
				_speak(script_lines.fire("SUMMIT.speaks"))
		"trying", "places":
			if not draw_panel.is_open():
				_raise_left -= delta
				if _raise_left <= 0.0:
					_raise_left = RAISE_AFTER
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
		drainable.drain_to(how_far, seconds)


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
	for index in range(targets.size()):
		var picture := Sprite2D.new()
		picture.texture = (targets[index].get_node(^"Picture") as Sprite2D).texture
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.scale = Vector2(1.3, 1.3)
		picture.modulate.a = 0.0
		var share := (float(index) + 0.5) / float(targets.size())
		picture.position = centre + Vector2(lerpf(-760.0, 760.0, share), -300.0 - 70.0 * sin(share * PI))
		picture.z_index = -3
		plane.add_child(picture)
		_bloomed.append(picture)
		picture.create_tween().tween_property(picture, "modulate:a", 1.0, 0.6)
		await get_tree().create_timer(BLOOM_EVERY, false).timeout
	var said: Array = []
	for fragment in targets:
		said.append_array(script_lines.fire("SUMMIT." + fragment.fragment_id))
	await _speak_and_wait(said)
	await _speak_and_wait(script_lines.fire(voice_hook()))
	if lola != null:
		lola.turn_around()
	await get_tree().create_timer(1.2, false).timeout
	await _speak_and_wait(script_lines.fire(ending_hook()))
	_summit = "done"
	Telemetry.record_event("summit", {"bloomed": targets.size(), "voice": voice_hook(),
		"ending": ending_hook()})
	_complete_level()


## Below the summit again (a checkpoint): the world in colour, lola at her painting, nothing
## bloomed yet.
func _reset_summit() -> void:
	if _summit == "done":
		return
	_summit = ""
	_attempts = 0
	for picture in _bloomed:
		picture.queue_free()
	_bloomed.clear()
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
