extends "res://scripts/level_base.gd"
## LEVEL 4 -- DILIM. The dark forest on Mt. Makiling, crossed alone.
##
## Extended BY PATH rather than by `class_name LevelBase`, for the reason every level is: a
## `--script` run does not register class names and the probes are exactly that.
##
## What this level is, in the machine's terms (LEVEL_4.md has the design and why):
##
##   * NO COMPANION. Lolo stopped at the water, so `_has_companion()` is false and every note the
##     level says -- the rescues, the tool notes -- is in the apo's own voice. The opening still
##     plays: it is hers now (dialogue_l4.json).
##   * A LEVEL THAT FIGHTS, built from hooks LevelBase keeps off everywhere else: the lantern as
##     her health, the dark, weapons that wear out, every drawing costing ink. Each is switched on
##     below by itself, so a probe can name the one it is about.
##   * ROUTES ARE CHOSEN BY WHAT SHE DOES. There is no dialogue node and no choice popup: the
##     drawing, or the deed, is the answer, and the level gives the ending one point -- its
##     majority route (`"tally": "majority"` in level_04.json).


func level_config_path() -> String:
	return "res://config/level_04.json"


func dialogue_path() -> String:
	return "res://config/dialogue_l4.json"


## Past what Lolo remembers: she goes on alone.
func _has_companion() -> bool:
	return false


func _companion_speaker() -> String:
	return APO_SPEAKER


## The lantern is her health (Kent): four stages, a hit takes one, a hit at the last puts her back
## where the lantern was last lit.
func _has_player_health() -> bool:
	return true


## Every weapon or light drawn costs a unit of ink, not only the first of its kind (Kent): a sword
## that wears out and is drawn again is paid for again, and the clearings are where ink comes back.
func _every_drawing_costs_ink() -> bool:
	return true


## A tool drawn here goes straight into her hand: in a fight a sword is drawn to be swung now, and
## a light to be held up now, not put in the bag.
func _draws_into_the_hand(_entity_id: String) -> bool:
	return true


## Weapons wear out by the uses in config/weapons.json's level_4 rows -- a sword good for fourteen
## swings -- and are drawn again when spent.
func _tool_wear_enabled() -> bool:
	return true


## A left click in the world swings the weapon in hand toward the pointer, Terraria's way.
func _click_attacks() -> bool:
	return true


## The camera keeps step with her in physics ticks, so a knockback or a lunge does not judder.
func _camera_follows_physics() -> bool:
	return true


## Shift walks here (the santelmo rule: it chases what runs). Set on every body of hers the level
## makes -- at the start, and each time she changes back.
func _instantiate_wanderer() -> Node2D:
	var wanderer := super()
	if wanderer != null:
		wanderer.set(&"can_walk", true)
	return wanderer


## How many times the lantern has gone out this run, so the RESPAWN pool turns over.
var _knockouts := 0


## Back where the lantern was last lit, in Lola's words rather than a failure message (Kent's
## design: "the apo's dialogue on respawn be lola's voice"). One line of the RESPAWN pool per
## knockout, in turn, so the second time is not the first time again.
func _knockout_words() -> String:
	var pool: Array = script_lines.peek("RESPAWN") if script_lines != null else []
	if pool.is_empty():
		return super()
	var line: Dictionary = pool[_knockouts % pool.size()]
	_knockouts += 1
	return script_lines.display_text(line)


## How fast the dark settles to a new zone's, per second: a change of about a tenth takes about a
## second, so walking into the deep woods is felt rather than switched.
const DARKNESS_EASE := 0.1

## [start x, darkness] for each of level_04.json's `lighting_states`, west to east. A zone starts
## at the west edge of its `from` beat's volume and runs until the next one starts; before the
## first, the first holds.
var _dark_zones: Array = []


## THE WOODS ARE DARK, AND DARKER FURTHER IN. Read off the level file rather than typed here: the
## edge of the woods 0.80, the deep woods 0.94, the far side 0.88, the last clearing 0.92. The
## level opens at the dark of wherever she starts.
func _darkness() -> float:
	return _darkness_at(spawn_point.global_position.x)


func _darkness_at(x: float) -> float:
	if _dark_zones.is_empty():
		_dark_zones = _read_dark_zones()
	if _dark_zones.is_empty():
		return 0.0
	var dark := float((_dark_zones[0] as Array)[1])
	for zone: Array in _dark_zones:
		if x >= float(zone[0]):
			dark = float(zone[1])
	return dark


func _read_dark_zones() -> Array:
	var spans := _beat_spans()
	var zones: Array = []
	for state_value: Variant in director.level_data().get("lighting_states", []):
		var state: Dictionary = state_value
		var from := String(state.get("from", ""))
		if spans.has(from) and state.has("darkness"):
			zones.append([(spans[from] as Vector2).x, float(state["darkness"])])
	zones.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return zones


func _level_physics(anchor_position: Vector2) -> void:
	# Once it is morning the dawn has the dark; the zones would only pull it back.
	if darkness_layer != null and not (_finale != null and _finale.has_dawned()):
		darkness_layer.darkness = move_toward(darkness_layer.darkness,
			_darkness_at(anchor_position.x), DARKNESS_EASE * get_physics_process_delta_time())
	_note_lesson_moments()
	_hold_the_drain(get_physics_process_delta_time())
	_watch_her_back(get_physics_process_delta_time())
	_lead_her_round()
	_tend_the_kapre(get_physics_process_delta_time())
	_tend_the_tiyanak()
	_tend_the_bungisngis(get_physics_process_delta_time())
	_tend_the_manananggal(get_physics_process_delta_time())
	if dawn_clock != null and _finale != null:
		dawn_clock.set_progress(_finale.progress())
		_place_dawn_clock()
	_tick_curse(get_physics_process_delta_time())


## Each beat's ground, west edge to east edge in world x, by obstacle id: read off the scene's
## volumes once, since they do not move.
var _spans: Dictionary = {}


func _beat_spans() -> Dictionary:
	if _spans.is_empty():
		for node in get_tree().get_nodes_in_group(&"level_obstacles"):
			var volume := node as LevelObstacle2D
			if volume != null:
				var half := volume.trigger_size.x * 0.5
				_spans[volume.obstacle_id] = Vector2(volume.global_position.x - half,
					volume.global_position.x + half)
	return _spans


## Where a rescue puts her, in words a player would use rather than "the last checkpoint".
func _checkpoint_place(checkpoint_id: String) -> String:
	match checkpoint_id:
		"CP1":
			return "the first clearing"
		"CP2":
			return "the second clearing"
		"CP3":
			return "the edge of the last clearing"
	return super(checkpoint_id)


## Each beat's mark, by obstacle id: where the thing it is about stands.
const BEAT_MARKS := {"L4_NUNO": "NunoMark", "L4_REST1": "Rest1Mark", "L4_SIGBIN": "SigbinMark",
	"L4_TIKBALANG": "TikbalangMark", "L4_KAPRE": "KapreMark", "L4_REST2": "Rest2Mark",
	"L4_TIYANAK": "TiyanakMark", "L4_BUNGISNGIS": "BungisngisMark",
	"L4_MANANANGGAL": "ManananggalMark", "L4_FINALE": "FinaleMark"}


## THE BANNER SAYS WHAT IS NEXT, BY WHERE SHE IS. Lola's rule up to the mound, a light in a
## clearing until it is lit, the morning once she is in the last one, and getting through the
## woods everywhere between -- pointing at the next thing east of her. The morning points at
## nothing: it comes to her.
func _current_objective() -> Dictionary:
	if player == null or not is_instance_valid(player) or director == null:
		return {}
	var x := player.global_position.x
	var spans := _beat_spans()
	if spans.has("L4_FINALE") and x >= (spans["L4_FINALE"] as Vector2).x:
		return {"key": "dawn"}
	for rest in ["L4_REST1", "L4_REST2"]:
		var span: Vector2 = spans.get(rest, Vector2(INF, -INF))
		# Until its light is lit: after, the woods again.
		if x >= span.x and x <= span.y and not director.is_solved(rest):
			return {"key": "rest", "target": _mark_at(rest)}
	var key := "woods"
	if spans.has("L4_NUNO") and x <= (spans["L4_NUNO"] as Vector2).y:
		key = "edge"
	return {"key": key, "target": _next_mark_east(x)}


func _mark_at(obstacle_id: String) -> Variant:
	var mark := get_node_or_null(NodePath("EnvironmentBaseplate/GameplayPlane/Marks/%s"
		% BEAT_MARKS.get(obstacle_id, ""))) as Node2D
	return mark.global_position if mark != null else null


## The nearest beat's mark still ahead of her, a little past where she stands.
func _next_mark_east(x: float) -> Variant:
	var best: Variant = null
	for obstacle_id: String in BEAT_MARKS:
		var at: Variant = _mark_at(obstacle_id)
		if at is Vector2 and (at as Vector2).x > x + 60.0 \
				and (best == null or (at as Vector2).x < (best as Vector2).x):
			best = at
	return best


## Uses left at which a weapon counts as nearly worn out: the lesson about drawing another comes
## before it is gone, not after.
const WEARING_AT := 2


## THE MOMENTS DILIM'S LESSONS WAIT FOR (tutorial.json, level_4): a santelmo that can see her, a
## weapon in her hand and one nearly worn out, polled -- nothing signals any of them -- and the
## first hit to the lantern, below. The lesson director spends each once.
func _note_lesson_moments() -> void:
	if tutorial == null:
		return
	if _a_santelmo_sees_her():
		tutorial.note("santelmo_near")
	if not _holding_a_weapon():
		return
	tutorial.note("weapon_in_hand")
	var item := _equipped_utility.item_data
	if item != null and int(item.runtime_state.get("uses_total", 0)) > 0 \
			and int(item.runtime_state.get("uses_left", WEARING_AT + 1)) <= WEARING_AT:
		tutorial.note("weapon_wearing")


## A burning santelmo close enough that running now would bring it.
func _a_santelmo_sees_her() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	for node in get_tree().get_nodes_in_group(Enemy2D.GROUP):
		var flame := node as Santelmo2D
		if flame != null and not flame.is_out() \
				and flame.global_position.distance_to(player.global_position) <= Santelmo2D.SIGHT:
			return true
	return false


func _arm_player_health() -> void:
	super()
	if player_health != null:
		player_health.hit_taken.connect(func(_stage: int) -> void:
			if tutorial != null:
				tutorial.note("lantern_hit"))


## PUT BACK, THE WOODS ARE PUT BACK TOO. A restore -- a knockout, a fall, a Continue -- goes to a
## moment before whatever is after her now, so everything in the encounters' group goes back the
## way it was then: a santelmo home, an aswang where it waited, at full strength. Before any
## checkpoint is written as well, when the moment is the start.
func _restore_checkpoint() -> String:
	var restored := super()
	get_tree().call_group(Enemy2D.GROUP, &"reset_for_restore")
	_went_to_the_cry = false
	_absurd_near = 0.0
	_lit_for = 0.0
	if dawn_clock != null:
		dawn_clock.hide_night()
	_lift_curse()
	return restored


# --- The nuno's mound -----------------------------------------------------------------------

## The flower the mound gives back, and the count it says (the design needs the count seen).
const FLOWER_ART := preload("res://assets/Level1/hidden_flower.png")
const COUNT_WORDS := ["None", "One", "Two", "Three", "Four", "Five"]
## How far west of the mound's foot she can stand and still be asking it.
const ASKING_REACH := 220.0

var _mound: NunoMound2D


func _resolve_level_nodes() -> void:
	_upper = get_node_or_null(^"EnvironmentBaseplate/GameplayPlane/Encounters/ManananggalUpper") as ManananggalUpper2D
	_lower = get_node_or_null(^"EnvironmentBaseplate/GameplayPlane/Encounters/ManananggalLower") as ManananggalLower2D
	if _upper != null:
		_upper.died.connect(func(_foe: Enemy2D) -> void: _answer("L4_MANANANGGAL", "protector"))
	if _lower != null:
		_lower.salted.connect(_on_lower_half_salted)
	_bungisngis = get_node_or_null(^"EnvironmentBaseplate/GameplayPlane/Encounters/Bungisngis") as Bungisngis2D
	if _bungisngis != null:
		_bungisngis.died.connect(func(_foe: Enemy2D) -> void: _answer("L4_BUNGISNGIS", "protector"))
	_tiyanak = get_node_or_null(^"EnvironmentBaseplate/GameplayPlane/Encounters/Tiyanak") as Tiyanak2D
	if _tiyanak != null:
		_tiyanak_x = _tiyanak.global_position.x
		_tiyanak.cried.connect(_on_tiyanak_cried)
		_tiyanak.died.connect(func(_foe: Enemy2D) -> void: _answer("L4_TIYANAK", "protector"))
	_kapre = get_node_or_null(^"EnvironmentBaseplate/GameplayPlane/Encounters/Kapre") as Kapre2D
	if _kapre != null:
		_kapre.cigar_knocked.connect(_on_cigar_knocked)
	_tikbalang = get_node_or_null(^"EnvironmentBaseplate/GameplayPlane/Encounters/Tikbalang") as Tikbalang2D
	if _tikbalang != null:
		_tikbalang.race_finished.connect(_on_race_finished)
	_sigbin = get_node_or_null(^"EnvironmentBaseplate/GameplayPlane/Encounters/Sigbin") as Sigbin2D
	if _sigbin != null:
		_sigbin.died.connect(_on_sigbin_driven_off)
	_mound = get_node_or_null(^"EnvironmentBaseplate/GameplayPlane/Hazards/NunoMound") as NunoMound2D
	_finale = get_node_or_null(^"EnvironmentBaseplate/GameplayPlane/Finale") as DilimFinale2D
	if _finale != null:
		_finale.dawned.connect(_on_dawn)
		_finale.began.connect(_on_night_began)
	if _mound != null:
		_mound.crossed.connect(_on_mound_crossed)
		_mound.crown_touched.connect(_on_crown_touched)


## ASKED BY WHAT SHE DOES (Kent): stop beside the mound and say tabi-tabi po, then cross without
## touching its crown, and the flower is given -- the artist's way. Cross clean without asking,
## the pragmatist's. Touching the crown answers nothing.
func _level_interact_offer() -> Dictionary:
	if _can_ask_the_mound():
		return {"name": "Punso", "verb": "SAY TABI-TABI PO"}
	if _can_race():
		return {"name": "Tikbalang", "verb": "RACE"}
	return {}


## Offering something, E is hers for it, not to pick up a drawing lying near.
func _level_answers_first() -> bool:
	return _can_ask_the_mound() or _can_race()


func _interact_with_level() -> bool:
	if _can_ask_the_mound():
		_mound.ask()
		_speak(script_lines.fire("L4_NUNO.asked"))
		return true
	if _can_race():
		_line_up_for_the_race()
		return true
	return false


func _can_ask_the_mound() -> bool:
	if _mound == null or _mound.asked or director == null or director.is_solved("L4_NUNO") \
			or player == null or not is_instance_valid(player):
		return false
	var foot := _mound.global_position.x - NunoMound2D.WIDTH * 0.5
	var x := player.global_position.x
	return x <= foot and x >= foot - ASKING_REACH


func _on_mound_crossed(clean: bool, asked: bool) -> void:
	if not clean or director == null or director.is_solved("L4_NUNO"):
		return
	var route := "artist" if asked else "pragmatist"
	director.commit_route("L4_NUNO", route)
	var routes: Dictionary = director.obstacle("L4_NUNO").get("routes", {})
	director.solve_with_item("L4_NUNO", String((routes.get(route, {}) as Dictionary).get("answered_by", route)))


func _on_route_solved(obstacle_id: String, route: String) -> bool:
	if obstacle_id == "L4_NUNO" and route == "artist":
		_flower_from_the_mound()
	if CLEARINGS.has(obstacle_id):
		_rest_by_the_fire()
	if obstacle_id == "L4_SIGBIN" and route == "artist" and _sigbin != null:
		_sigbin.flee()
	if obstacle_id == "L4_TIKBALANG" and _tikbalang != null:
		_tikbalang.stand_aside()
	if obstacle_id == "L4_TIYANAK" and route == "artist" and _tiyanak != null:
		_tiyanak.reveal_and_flee()
	if obstacle_id == "L4_MANANANGGAL" and _upper != null:
		_upper.leave()
	return false


## ⚠ THE ID HERE MUST BE IN PlayerProfile.FLOWER_IDS OR THE FLOWER COUNTS FOR NOTHING. It comes up
## out of the crown, to her, and says which of the five it is.
func _flower_from_the_mound() -> void:
	PlayerProfile.record_collectible("L4_HF")
	if _mound == null:
		return
	var at := _mound.global_position + Vector2(0.0, -NunoMound2D.HEIGHT)
	var flower := Sprite2D.new()
	flower.name = "GivenFlower"
	flower.texture = FLOWER_ART
	flower.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flower.z_index = 12
	flower.scale = Vector2.ONE * 0.2
	flower.modulate.a = 0.0
	_mound.get_parent().add_child(flower)
	flower.global_position = at
	var give := flower.create_tween()
	give.tween_property(flower, "modulate:a", 1.0, 0.3)
	give.parallel().tween_property(flower, "global_position:y", at.y - 60.0, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	give.parallel().tween_property(flower, "scale", Vector2.ONE * 0.9, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var risen := at + Vector2(0.0, -60.0)
	give.tween_method(func(t: float) -> void:
		if is_instance_valid(flower) and player != null and is_instance_valid(player):
			var target := player.global_position + Vector2(0.0, -80.0)
			flower.global_position = risen.lerp(target, t) + Vector2(0.0, -40.0 * sin(PI * t)), \
		0.0, 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	give.tween_property(flower, "scale", Vector2.ONE * 0.3, 0.25)
	give.parallel().tween_property(flower, "modulate:a", 0.0, 0.25)
	give.tween_callback(func() -> void:
		if is_instance_valid(flower):
			flower.queue_free()
		var count := clampi(int(PlayerProfile.flower_count()), 0, 5)
		announce_acquisition("Hidden Flower",
			"%s of five. The mound gave it back, for asking first." % String(COUNT_WORDS[count]),
			FLOWER_ART))


# --- The nuno's curse -------------------------------------------------------------------------

## Kent's design: "Step on it and the apo is cursed: swollen foot, slowed movement, hearts
## draining until it wears off." Twenty seconds: her pace to 0.6 and her jump to 0.85, the lantern
## down a stage at once and another at ten seconds -- never below LOW, never out. A restore lifts
## it, and so does the first clearing (the fire).
const CURSE_SECONDS := 20.0
const CURSE_PACE := 0.6
const CURSE_JUMP := 0.85
const CURSE_SECOND_DIM := 10.0

var _curse_left := 0.0
var _curse_dimmed_twice := false


func is_cursed() -> bool:
	return _curse_left > 0.0


## Touching it again while cursed does not curse her twice.
func _on_crown_touched() -> void:
	if is_cursed():
		return
	_curse_left = CURSE_SECONDS
	_curse_dimmed_twice = false
	if player_health != null:
		player_health.dim(PlayerHealth.LOW)
	_speak(script_lines.fire("L4_NUNO.cursed"))
	Telemetry.record_event("nuno_cursed", {"level_id": LevelManager.current_level_id,
		"obstacle_id": "L4_NUNO"})
	_weigh_on_her()


func _tick_curse(delta: float) -> void:
	if not is_cursed():
		return
	_curse_left -= delta
	if not _curse_dimmed_twice and _curse_left <= CURSE_SECONDS - CURSE_SECOND_DIM:
		_curse_dimmed_twice = true
		if player_health != null:
			player_health.dim(PlayerHealth.LOW)
	if _curse_left <= 0.0:
		_lift_curse()
	else:
		# Every tick: she may have changed body since, and a new one starts unweighted.
		_weigh_on_her()


func _weigh_on_her() -> void:
	var apo := player as Wanderer
	if apo != null:
		apo.pace_scale = CURSE_PACE
		apo.jump_scale = CURSE_JUMP


func _lift_curse() -> void:
	_curse_left = 0.0
	var apo := player as Wanderer
	if apo != null:
		apo.pace_scale = 1.0
		apo.jump_scale = 1.0



# --- The clearings ----------------------------------------------------------------------------

const CLEARINGS := ["L4_REST1", "L4_REST2"]
## WHERE A SOUND CAME FROM, for what is heard in the dark (Kent's design: "Every sound that carries
## gameplay information needs a visual equivalent"): rings where the tiyanak cries, and in the night
## the tik-tik. Above the dark, under the HUD.
var edge_ripple: EdgeRipple


func _build_level_furniture() -> void:
	director.obstacle_entered.connect(_on_beat_entered)
	_arm_the_drain()
	edge_ripple = EdgeRipple.new()
	edge_ripple.name = "EdgeRipple"
	add_child(edge_ripple)
	# Top centre, under the quest card: the last clearing's clock.
	dawn_clock = DawnClockHud.new()
	dawn_clock.name = "DawnClock"
	dawn_clock.set_anchors_preset(Control.PRESET_CENTER_TOP)
	dawn_clock.position = Vector2(-DawnClockHud.SIZE.x * 0.5, DAWN_CLOCK_TOP)
	$CanvasLayer.add_child(dawn_clock)
	# Bottom centre: Lola's things on Z, X, C and V.
	satchel = Satchel.new()
	quick_slots = QuickSlotBar.new()
	quick_slots.name = "QuickSlots"
	quick_slots.bind(satchel)
	quick_slots.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	quick_slots.position = Vector2(-quick_slots.size.x * 0.5, -quick_slots.size.y - QUICK_SLOTS_BOTTOM)
	$CanvasLayer.add_child(quick_slots)
	for node in find_children("*", "Area2D", true, false):
		if node is SatchelPickup2D:
			_wire_pickup(node as SatchelPickup2D)
		elif node is InkJar2D:
			_wire_jar(node as InkJar2D)
	# Every aswang that falls, now or later -- the finale makes its own as the night goes.
	get_tree().node_added.connect(_on_node_added)
	for node in find_children("*", "CharacterBody2D", true, false):
		_on_node_added(node)
	_drops.randomize()


## INK COMES BACK AT A CLEARING (Kent: "a single clearing restores both"). On arriving, before the
## checkpoint standing in it writes, so the checkpoint keeps her full -- and so she can always draw
## the light the clearing asks for, however dry she came in. Where is level_04.json's to say.
func _on_beat_entered(obstacle_id: String) -> void:
	if _refills_at(obstacle_id) and ink_manager != null:
		ink_manager.add_ink(ink_manager.capacity)


## And at a checkpoint the file names -- the last clearing's edge -- before it writes, so every try
## at the night starts full.
func _on_checkpoint_area_reached(checkpoint_id: String) -> void:
	if _refills_at(checkpoint_id) and ink_manager != null:
		ink_manager.add_ink(ink_manager.capacity)
	super(checkpoint_id)


## Whether the level file names this beat or checkpoint as a place her ink is filled.
func _refills_at(place: String) -> bool:
	var economy: Dictionary = director.level_data().get("ink_economy", {}) if director != null else {}
	return (economy.get("refilled_at", []) as Array).has(place)


## RUNNING DRY IS NOT A LOSS HERE. Every drawing costs, so it will happen, and the way on is still
## open: every encounter has a way past that needs no ink, and the clearings fill it again. The
## out-of-ink screen stays shut, and she says where more is.
func _on_ink_emptied() -> bool:
	_speak(script_lines.fire("INK.empty"))
	return true


## A LIGHT OF HER OWN, AND SHE RESTS BY IT. The clearing's light lit fills the lantern to full and
## lifts the nuno's curse -- the one place in the woods both happen.
func _rest_by_the_fire() -> void:
	if player_health != null:
		player_health.refill(PlayerHealth.FULL)
	_lift_curse()


# --- The last clearing --------------------------------------------------------------------------

## How long the dark takes to lift at dawn, and how long the morning is held before the level ends.
const DAWN_LIFT_SECONDS := 2.0
const MORNING_HOLD := 1.0

var _finale: DilimFinale2D
## The night's clock on screen, under the quest card; shown only while the night runs.
var dawn_clock: DawnClockHud
const DAWN_CLOCK_TOP := 104.0
## Clear air between the quest card's frame and the clock's strip.
const DAWN_CLOCK_GAP := 10.0


## UNDER THE QUEST CARD, NOT AGAINST IT. Seen in a window: placed at a fixed height the strip sat
## flush on the card's frame, and the card grows when it has a second line. So it follows the
## frame's bottom.
func _place_dawn_clock() -> void:
	var frame := objective_banner.get_node_or_null(^"Panel") as Control \
		if objective_banner != null else null
	var bottom := frame.get_global_rect().end.y if frame != null and frame.is_visible_in_tree() \
		else DAWN_CLOCK_TOP
	dawn_clock.position.y = bottom + DAWN_CLOCK_GAP - DawnClockHud.STRIP_TOP


## The night has begun: its clock comes up, and goes on the first frame of the morning.
func _on_night_began() -> void:
	if dawn_clock != null:
		dawn_clock.show_night()


## MORNING. The dark lifts -- on the dark layer's own clock, which runs while a line is up -- she says
## the line the level was for, and the level is done: the majority route settled, the one point given.
func _on_dawn() -> void:
	if dawn_clock != null:
		dawn_clock.set_progress(1.0)
		dawn_clock.hide_night()
	if darkness_layer != null:
		darkness_layer.create_tween().tween_property(darkness_layer, "darkness", 0.0, DAWN_LIFT_SECONDS)
	await _speak_and_wait(script_lines.fire("L4_FINALE.solved"))
	if not is_inside_tree():
		return
	await get_tree().create_timer(MORNING_HOLD, false).timeout
	if is_inside_tree():
		_complete_level()


# --- The satchel ----------------------------------------------------------------------------

## Lola's things, counted, four on quick slots (config/satchel.json, Satchel).
var satchel: Satchel
var quick_slots: QuickSlotBar
const QUICK_SLOTS_BOTTOM := 28.0


func _handle_level_input(event: InputEvent) -> bool:
	for index in range(Satchel.SLOTS):
		if event.is_action_pressed("quick_slot_%d" % (index + 1)):
			return use_quick_slot(index)
	return false


## Z, X, C or V: the thing on that slot, used now, and one fewer. Spent only if it did something.
## Returns whether the press was the satchel's -- it is not while a drawing is being placed (the
## same keys turn and size it), drawn, or the bag is open: those keep the key.
func use_quick_slot(index: int) -> bool:
	if not _quick_slots_answer():
		return false
	var id := satchel.slot_item(index)
	if id.is_empty() or satchel.count(id) <= 0:
		return true
	if _use_from_satchel(id):
		satchel.take(id)
		quick_slots.flash(index)
		Telemetry.record_event("satchel_used", {"level_id": LevelManager.current_level_id, "item": id})
	return true


func _quick_slots_answer() -> bool:
	if satchel == null or get_tree().paused:
		return false
	if placement_controller != null and placement_controller.is_placing():
		return false
	if draw_panel != null and draw_panel.is_open():
		return false
	return not (inventory_screen != null and inventory_screen.is_open())


## Every pickup in the woods, placed or dropped, is answered here when she walks into it. One this
## run has already taken is not there to find.
func _wire_pickup(pickup: SatchelPickup2D) -> void:
	if not pickup.pickup_id.is_empty() and pickup_taken_this_run(pickup.pickup_id):
		pickup.queue_free()
		return
	if not pickup.touched.is_connected(_on_pickup_touched):
		pickup.touched.connect(_on_pickup_touched)


## A Continue says what this run took before it: those are gone from the woods.
func _show_taken_pickups() -> void:
	for node in find_children("*", "Area2D", true, false):
		var pickup := node as SatchelPickup2D
		if pickup != null and not pickup.pickup_id.is_empty() and pickup_taken_this_run(pickup.pickup_id):
			pickup.queue_free()
		var jar := node as InkJar2D
		if jar != null and not jar.pickup_id.is_empty() and pickup_taken_this_run(jar.pickup_id):
			jar.queue_free()


## Into the satchel if there is room; if not it stays where it lies, for later. The first of each
## kind she finds says what it is and which key it is on.
func _on_pickup_touched(pickup: SatchelPickup2D) -> void:
	var first := satchel.count(pickup.item) == 0 and not _met.has(pickup.item)
	var took := satchel.add(pickup.item, pickup.amount)
	if took <= 0:
		return
	if not pickup.pickup_id.is_empty():
		note_pickup_taken(pickup.pickup_id)
	pickup.take()
	var index := satchel.slots().find(pickup.item)
	quick_slots.flash(index)
	if first:
		_met[pickup.item] = true
		var row := satchel.row(pickup.item)
		# Named through the same lookup the prompts use, so a rebinding is named as bound. Not by
		# with_keys: its {key:...} takes no digits, and every slot's action has one.
		var on := " It is on %s." % ControlsKeys.key_cap_for("quick_slot_%d" % (index + 1)) \
			if index >= 0 else ""
		hint_bar.show_hint("%s -- %s.%s" % [row.get("display_name", pickup.item),
			String(row.get("gloss", "")).to_lower(), on], _companion_speaker(), 4.0)


# --- What a fallen aswang drops -----------------------------------------------------------

## Kent's design: "Aswangs drop them. That closes the loop: fighting feeds the economy that lets
## you keep fighting." Each of Lola's things rolls its own `drop_chance`, so a fall can drop
## nothing or more than one; lamp oil never while the last clearing's night runs ("Langis carried
## in is what the player has"). Seedable, so a probe can count what a known stream gives.
var _drops := RandomNumberGenerator.new()
## How far apart two things dropped by one fall lie.
const DROP_SPREAD := 26.0


func set_drop_seed(seed_value: int) -> void:
	_drops.seed = seed_value


func _on_node_added(node: Node) -> void:
	var foe := node as Enemy2D
	if foe != null and not foe.died.is_connected(_on_foe_fell):
		foe.died.connect(_on_foe_fell)


func _on_foe_fell(foe: Enemy2D) -> void:
	if satchel == null or not is_instance_valid(foe) or not foe.drops:
		return
	var night := _finale != null and _finale.is_running()
	var dropped := 0
	for id in satchel.ids():
		var row := satchel.row(id)
		if night and bool(row.get("never_in_finale", false)):
			continue
		if _drops.randf() >= float(row.get("drop_chance", 0.0)):
			continue
		var pickup := SatchelPickup2D.new()
		pickup.item = id
		pickup.position = foe.global_position + Vector2(DROP_SPREAD * dropped, foe.body_size.y * 0.5)
		pickup.touched.connect(_on_pickup_touched)
		get_node(^"EnvironmentBaseplate/GameplayPlane").add_child(pickup)
		dropped += 1


## A jar of ink on the way: its ink back to her, and gone for the run.
func _wire_jar(jar: InkJar2D) -> void:
	if not jar.pickup_id.is_empty() and pickup_taken_this_run(jar.pickup_id):
		jar.queue_free()
		return
	jar.touched.connect(func(taken: InkJar2D) -> void:
		ink_manager.add_ink(taken.amount)
		if not taken.pickup_id.is_empty():
			note_pickup_taken(taken.pickup_id)
		taken.take())


## The kinds she has found at least once this run, for the first-find line.
var _met: Dictionary = {}


## What each thing does, by its `use` in the file. False when it cannot be used here and now, so
## it is not spent.
func _use_from_satchel(id: String) -> bool:
	var item := satchel.row(id)
	match String(item.get("use", "")):
		"oil":
			return _pour_oil(int(item.get("stages", 2)))
		"candle":
			return _set_down_a_candle(float(item.get("radius", 220.0)), float(item.get("seconds", 45.0)))
		"ward":
			return _crush_garlic(float(item.get("radius", 150.0)), float(item.get("seconds", 10.0)))
		"throw":
			return _throw_salt(item)
		"dust":
			return _throw_ash(item)
		_:
			return false


## KANDILA: lit and set down at her feet, a light that costs no ink.
func _set_down_a_candle(radius: float, seconds: float) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var candle := CandleFlame2D.new()
	candle.radius = radius
	candle.seconds = seconds
	candle.position = player.global_position
	get_node(^"EnvironmentBaseplate/GameplayPlane").add_child(candle)
	return true


## BAWANG: crushed at her feet, a ward nothing that hunts by smell will cross.
func _crush_garlic(radius: float, seconds: float) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var ward := BawangWard2D.new()
	ward.radius = radius
	ward.seconds = seconds
	ward.position = player.global_position
	get_node(^"EnvironmentBaseplate/GameplayPlane").add_child(ward)
	return true


## ASIN: a handful thrown ahead of her, the way she faces, from her middle.
func _throw_salt(item: Dictionary) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var throw := AsinThrow2D.new()
	throw.reach = float(item.get("reach", 300.0))
	throw.burn_ticks = int(item.get("burn_ticks", 3))
	throw.burn_seconds = float(item.get("burn_seconds", 2.4))
	var facing: Variant = player.get(&"_facing")
	throw.direction = signf(float(facing)) if facing != null and float(facing) != 0.0 else 1.0
	throw.position = PlayerHurtbox2D.middle_of(player)
	get_node(^"EnvironmentBaseplate/GameplayPlane").add_child(throw)
	return true


## ABO: a handful thrown into the air where she stands.
func _throw_ash(item: Dictionary) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var dust := AboDust2D.new()
	dust.radius = float(item.get("radius", 160.0))
	dust.stun_seconds = float(item.get("stun_seconds", 1.5))
	dust.reveal_seconds = float(item.get("reveal_seconds", 6.0))
	dust.position = player.global_position
	get_node(^"EnvironmentBaseplate/GameplayPlane").add_child(dust)
	return true


## LANGIS: stages back into the lantern. Not when it is already full -- that would only waste it.
func _pour_oil(stages: int) -> bool:
	if player_health == null or player_health.stage >= PlayerHealth.FULL:
		return false
	player_health.refill(stages)
	return true


# --- What a checkpoint keeps of the satchel ---------------------------------------------------

## Kent: "death rolls ink and drawings back to the checkpoint; collectibles kept." So a knockout or
## a fall leaves the satchel as it is -- what she found since the checkpoint is still hers -- and
## only a Continue, which starts the level fresh, takes it from the checkpoint. Plain counts and
## slot ids: a run state holding an object is dropped whole on its way to disk.
var _resuming := false


func _level_run_state() -> Dictionary:
	return {"satchel": satchel.to_data()} if satchel != null else {}


func _restore_level_run_state(state: Dictionary) -> void:
	if _resuming and satchel != null and state.get("satchel") is Dictionary:
		satchel.from_data(state["satchel"] as Dictionary)


func _resume_saved_checkpoint() -> bool:
	_resuming = true
	var resumed := super()
	_resuming = false
	return resumed


# --- A drawn body costs ink while it is held ------------------------------------------------

## Like everything drawn in Dilim, a creature's body is paid for in ink -- level_04.json's
## creature_drain_per_second (0.25) for as long as she holds it -- and there is no ten-second
## clock. At none she is herself again.
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


# --- The sigbin ---------------------------------------------------------------------------------

## Kent's design: "keep your back to a wall or a rock face so it cannot get behind you." Five
## seconds with her back to a surface -- within WALL_GAP of it, facing away -- while it hunts her,
## and it gives up. Shown a light (a drawing with LIGHT, in its beat), it flees. Struck down, it is
## driven off. Each is the route that was taken.
const WALL_SECONDS := 5.0
const WALL_GAP := 28.0

var _sigbin: Sigbin2D
var _back_to_wall := 0.0


func _watch_her_back(delta: float) -> void:
	if _sigbin == null or _sigbin.is_gone() or director.is_solved("L4_SIGBIN") \
			or _sigbin.state_name() == "IDLE" or not _her_back_is_to_a_surface():
		_back_to_wall = 0.0
		return
	_back_to_wall += delta
	if _back_to_wall >= WALL_SECONDS:
		_sigbin.flee()
		_answer("L4_SIGBIN", "pragmatist")


## A surface right behind her: a ray from her middle, back the way she is not facing.
func _her_back_is_to_a_surface() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var facing: Variant = player.get(&"_facing")
	var back := -signf(float(facing)) if facing != null and float(facing) != 0.0 else -1.0
	var middle := PlayerHurtbox2D.middle_of(player)
	var reach := PlayerHurtbox2D.SIZE.x * 0.5 + WALL_GAP
	var ray := PhysicsRayQueryParameters2D.create(middle, middle + Vector2(back * reach, 0.0),
		PhysicsLayers.WORLD)
	if player is CollisionObject2D:
		ray.exclude = [(player as CollisionObject2D).get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


func _on_sigbin_driven_off(_foe: Enemy2D) -> void:
	_answer("L4_SIGBIN", "protector")


## A route given by what she did: committed if nothing was yet, and answered with its own deed.
func _answer(obstacle_id: String, route: String) -> void:
	if director == null or director.is_solved(obstacle_id):
		return
	if director.committed_route(obstacle_id).is_empty():
		director.commit_route(obstacle_id, route)
	if director.committed_route(obstacle_id) != route:
		return
	var spec: Dictionary = (director.obstacle(obstacle_id).get("routes", {}) as Dictionary).get(route, {})
	var deed := String(spec.get("answered_by", (spec.get("then", {}) as Dictionary).get("answered_by", route)))
	director.solve_with_item(obstacle_id, deed)


# --- The tikbalang ------------------------------------------------------------------------------

## Kent's design: "whichever path the player takes arrives back at the same place." Past LOOP_X,
## while it is unanswered and not racing her, she is back at its rock. Answered -- a body with
## hooves it takes for its own kind (artist), any animal's body it does not chase (pragmatist), a
## race to its finish she wins (protector) -- it stands aside and the way on is open.
const LOOP_X := 9700.0
const LED_BACK_TO := 8350.0
const RACE_REACH := 150.0

var _tikbalang: Tikbalang2D
## Where she was last tick, and the most a tick of her own going could carry her.
var _her_last_x := INF
const CROSSING_STEP := 120.0


## Only for going past it -- crossing the line from the west, a step at a time. Put down beyond it
## by a restore or a Continue is not going past it: the line was never crossed.
func _lead_her_round() -> void:
	if _tikbalang == null or player == null or not is_instance_valid(player):
		return
	var x := PlayerHurtbox2D.middle_of(player).x
	var crossed := _her_last_x < LOOP_X and x >= LOOP_X and x - _her_last_x < CROSSING_STEP
	_her_last_x = x
	if not crossed or director.is_solved("L4_TIKBALANG") or _tikbalang.is_racing():
		return
	_put_her_back_at_the_rock()
	_her_last_x = PlayerHurtbox2D.middle_of(player).x
	_speak(script_lines.fire("L4_TIKBALANG.led_back"))


func _put_her_back_at_the_rock() -> void:
	var ground: Variant = _mark_at("L4_TIKBALANG")
	var y := (ground as Vector2).y - 4.0 if ground is Vector2 else player.global_position.y
	player.call("apply_morph_state", {"position": Vector2(LED_BACK_TO, y), "linear_velocity": Vector2.ZERO})


func _can_race() -> bool:
	return _tikbalang != null and not _tikbalang.is_aside() and not _tikbalang.is_racing() \
		and director != null and not director.is_solved("L4_TIKBALANG") \
		and player != null and is_instance_valid(player) \
		and absf(player.global_position.x - _tikbalang.global_position.x) <= RACE_REACH


## At its side, at its line: the race starts after its moment to get ready.
func _line_up_for_the_race() -> void:
	var line_x := _tikbalang.start_race()
	player.call("apply_morph_state", {"position": Vector2(line_x, player.global_position.y),
		"linear_velocity": Vector2.ZERO})
	_speak(script_lines.fire("L4_TIKBALANG.race"))


func _on_race_finished(she_won: bool) -> void:
	if she_won:
		_answer("L4_TIKBALANG", "protector")
		return
	_put_her_back_at_the_rock()
	_speak(script_lines.fire("L4_TIKBALANG.race.lost"))


# --- The kapre ----------------------------------------------------------------------------------

## Kent's design: its smoke turns her round -- crossing the middle of the smoke bank on her own
## feet, while it stands, puts her back at the bank's edge. Answered three ways, each a drawing
## and then a deed: a fan held up to it within FAN_REACH for FAN_SECONDS clears the smoke (artist);
## a blade used at its tree CHOPS times fells it (pragmatist); something thrown knocks the cigar
## out of its hand (protector).
const FAN_REACH := 360.0
const FAN_SECONDS := 1.5
const CHOP_REACH := 110.0
const SMOKE_EDGE_BACK := 50.0

var _kapre: Kapre2D
var _fanned := 0.0
var _smoke_last_x := INF


func _tend_the_kapre(delta: float) -> void:
	if _kapre == null or player == null or not is_instance_valid(player):
		return
	var x := PlayerHurtbox2D.middle_of(player).x
	var span := _kapre.smoke_span()
	var middle := (span.x + span.y) * 0.5
	var crossed := _smoke_last_x < middle and x >= middle and x - _smoke_last_x < CROSSING_STEP
	_smoke_last_x = x
	if crossed and _kapre.smoke_stands() and not director.is_solved("L4_KAPRE"):
		player.call("apply_morph_state", {"position": Vector2(span.x + SMOKE_EDGE_BACK, player.global_position.y),
			"linear_velocity": Vector2.ZERO})
		_smoke_last_x = span.x + SMOKE_EDGE_BACK
		_speak(script_lines.fire("L4_KAPRE.turned"))
	# The fan, held up to it.
	if director.committed_route("L4_KAPRE") == "artist" and not director.is_solved("L4_KAPRE") \
			and _holding("fan") and absf(x - _kapre.global_position.x) <= FAN_REACH:
		_fanned += delta
		if _fanned >= FAN_SECONDS:
			_kapre.clear_smoke()
			_answer("L4_KAPRE", "artist")
	else:
		_fanned = 0.0


## A blade swung at its tree is a chop -- the first one too, the swing that draws the route in.
## Read after the swing, and only of a swing that happened (a press inside a swing is nothing).
func _use_equipped_utility() -> void:
	var swung := _equipped_utility != null and is_instance_valid(_equipped_utility) \
		and _equipped_utility.is_ready()
	super()
	if swung and _kapre != null and not _kapre.is_felled() and director != null \
			and director.committed_route("L4_KAPRE") == "pragmatist" and not director.is_solved("L4_KAPRE") \
			and player != null and absf(player.global_position.x - _kapre.global_position.x) <= CHOP_REACH:
		if _kapre.chop():
			_answer("L4_KAPRE", "pragmatist")


func _on_cigar_knocked() -> void:
	_kapre.leave()
	_answer("L4_KAPRE", "protector")


func _holding(entity_id: String) -> bool:
	return _equipped_utility != null and is_instance_valid(_equipped_utility) \
		and _equipped_utility.item_data != null and _equipped_utility.item_data.entity_id == entity_id


# --- The tiyanak --------------------------------------------------------------------------------

## Kent's design: "The threat is the lure, not the creature. The cry pulls the player toward a
## drop or a nest, and the danger is the terrain it leads to." It cries down on the ground by its
## drop, which its bushes hide, and the path goes over on logs. Answered three ways: a light she
## drew shows it for what it is and it flees (artist, judged as the drawing); the far side reached
## on the path without once going down to the cry (pragmatist, `kept_clear`); struck down after a
## weapon drawn (protector) -- allowed, never rewarded: it drops nothing, and she says so.
## How far past where it cries is the far side, off the end of the path.
const KEPT_CLEAR_PAST := 560.0
## How far off its cry still shows, and how strong it is: faint at the edge, strong beside her.
const CRY_HEARD_FROM := 1400.0
const CRY_FAINTEST := 0.2

var _tiyanak: Tiyanak2D
var _tiyanak_x := 0.0
## Whether she went down to it -- into its lure -- since the last checkpoint.
var _went_to_the_cry := false


func _tend_the_tiyanak() -> void:
	if _tiyanak == null or player == null or not is_instance_valid(player) or director == null \
			or director.is_solved("L4_TIYANAK"):
		return
	var middle := PlayerHurtbox2D.middle_of(player)
	if _tiyanak.in_lure(middle):
		_went_to_the_cry = true
	if not _went_to_the_cry and middle.x >= _tiyanak_x + KEPT_CLEAR_PAST and not _tiyanak.is_gone():
		_answer("L4_TIYANAK", "pragmatist")


## The cry, where it comes from: an amber ripple, stronger the nearer she is.
func _on_tiyanak_cried(at: Vector2) -> void:
	if edge_ripple == null or player == null or not is_instance_valid(player):
		return
	var distance := PlayerHurtbox2D.middle_of(player).distance_to(at)
	if distance > CRY_HEARD_FROM:
		return
	edge_ripple.cue("tiyanak", at, maxf(CRY_FAINTEST, 1.0 - distance / CRY_HEARD_FROM))


# --- The bungisngis -----------------------------------------------------------------------------

## Kent's design: "One-eyed giant, always laughing. Strong, slow, and easily distracted. Blocks a
## crossing." It stands in the ravine's crossing, a wall. Answered three ways, each a drawing and
## then a deed: something absurd -- a sea thing on a mountain -- brought within ABSURD_REACH of it
## for ABSURD_SECONDS sets it laughing itself helpless (artist); the far bank reached over the top
## or along the high path while it still stands in the crossing (pragmatist); beaten (protector).
const ABSURD_REACH := 420.0
const ABSURD_SECONDS := 0.5
## The far bank, and how high she is on it: off the ravine's east edge, up at the rim.
const FAR_BANK_X := 19480.0
const RIM_MIDDLE_BELOW := 650.0

var _bungisngis: Bungisngis2D
var _absurd_near := 0.0


func _tend_the_bungisngis(delta: float) -> void:
	if _bungisngis == null or player == null or not is_instance_valid(player) or director == null \
			or director.is_solved("L4_BUNGISNGIS") or not _bungisngis.is_in_the_way():
		_absurd_near = 0.0
		return
	var route := director.committed_route("L4_BUNGISNGIS")
	if route == "artist" and _something_absurd_within(ABSURD_REACH):
		_absurd_near += delta
		if _absurd_near >= ABSURD_SECONDS:
			_bungisngis.laugh()
			_answer("L4_BUNGISNGIS", "artist")
		return
	_absurd_near = 0.0
	var middle := PlayerHurtbox2D.middle_of(player)
	if route == "pragmatist" and middle.x >= FAR_BANK_X and middle.y < RIM_MIDDLE_BELOW:
		_answer("L4_BUNGISNGIS", "pragmatist")


## Her, in a body with no business on a mountain, or one of those set down -- near it.
func _something_absurd_within(reach: float) -> bool:
	var absurd := AbilityTags.resolve(["absurd"], "all", [])
	var at := _bungisngis.global_position
	if absurd.has(_current_form_id) and PlayerHurtbox2D.middle_of(player).distance_to(at) <= reach:
		return true
	for node in get_tree().get_nodes_in_group(&"drawn_utilities"):
		var thing := node as UtilityObject
		if thing != null and not thing.is_preview and thing.item_data != null \
				and absurd.has(thing.item_data.entity_id) and thing.global_position.distance_to(at) <= reach:
			return true
	return false


# --- The manananggal ----------------------------------------------------------------------------

## Kent's design: "the upper half flies, so ground weapons mostly miss. This is a search under
## pressure rather than a fight. The lower half is hidden somewhere in the arena." Answered three
## ways: salt thrown on the lower half (pragmatist, `salted` -- the best one); a light drawn, then
## the lower half held in light LIT_SECONDS -- her own lantern does not count; a drawn sun lights
## the whole hollow -- and she cannot rejoin in the light (artist); the upper half driven off after
## a weapon drawn (protector), which settles the least: the lower half still stands. Any way, the
## upper half leaves.
const LIT_SECONDS := 2.0
const LIT_ENOUGH := 0.5

var _upper: ManananggalUpper2D
var _lower: ManananggalLower2D
var _lit_for := 0.0


func _tend_the_manananggal(delta: float) -> void:
	if _lower == null or director == null or director.is_solved("L4_MANANANGGAL") or _lower.is_dead():
		_lit_for = 0.0
		return
	if director.committed_route("L4_MANANANGGAL") == "artist" \
			and LightField.light_from(_drawn_light(), _lower.global_position) >= LIT_ENOUGH:
		_lit_for += delta
		if _lit_for >= LIT_SECONDS:
			_answer("L4_MANANANGGAL", "artist")
		return
	_lit_for = 0.0


## Every light in the woods but her own lantern -- the light the design means is one she made.
func _drawn_light() -> Array:
	var holes: Array = []
	for source in get_tree().get_nodes_in_group(LightField.GROUP):
		if source is HeldLantern2D or not source.has_method("light_hole") or not (source is CanvasItem) \
				or not (source as CanvasItem).is_visible_in_tree():
			continue
		var hole: Dictionary = source.call("light_hole")
		if not hole.is_empty():
			holes.append(hole)
	return holes


func _on_lower_half_salted() -> void:
	_answer("L4_MANANANGGAL", "pragmatist")
	if _upper != null:
		_upper.leave()
