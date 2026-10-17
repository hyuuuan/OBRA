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
	if darkness_layer != null:
		darkness_layer.darkness = move_toward(darkness_layer.darkness,
			_darkness_at(anchor_position.x), DARKNESS_EASE * get_physics_process_delta_time())
	_note_lesson_moments()
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


## THE BANNER SAYS WHAT IS NEXT, BY WHERE SHE IS. Lola's rule up to the mound, rest in a
## clearing, the morning once she is in the last one, and getting through the woods everywhere
## between -- pointing at the next thing east of her. The morning points at nothing: it comes to
## her.
func _current_objective() -> Dictionary:
	if player == null or not is_instance_valid(player) or director == null:
		return {}
	var x := player.global_position.x
	var spans := _beat_spans()
	if spans.has("L4_FINALE") and x >= (spans["L4_FINALE"] as Vector2).x:
		return {"key": "dawn"}
	for rest in ["L4_REST1", "L4_REST2"]:
		var span: Vector2 = spans.get(rest, Vector2(INF, -INF))
		if x >= span.x and x <= span.y:
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
	_mound = get_node_or_null(^"EnvironmentBaseplate/GameplayPlane/Hazards/NunoMound") as NunoMound2D
	if _mound != null:
		_mound.crossed.connect(_on_mound_crossed)
		_mound.crown_touched.connect(_on_crown_touched)


## ASKED BY WHAT SHE DOES (Kent): stop beside the mound and say tabi-tabi po, then cross without
## touching its crown, and the flower is given -- the artist's way. Cross clean without asking,
## the pragmatist's. Touching the crown answers nothing.
func _level_interact_offer() -> Dictionary:
	if not _can_ask_the_mound():
		return {}
	return {"name": "Punso", "verb": "SAY TABI-TABI PO"}


## Offering it, E is hers to ask with, not to pick up a drawing lying near.
func _level_answers_first() -> bool:
	return _can_ask_the_mound()


func _interact_with_level() -> bool:
	if not _can_ask_the_mound():
		return false
	_mound.ask()
	_speak(script_lines.fire("L4_NUNO.asked"))
	return true


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


func _build_level_furniture() -> void:
	director.obstacle_entered.connect(_on_beat_entered)


## INK COMES BACK AT A CLEARING (Kent: "a single clearing restores both"). On arriving, before the
## checkpoint standing in it writes, so the checkpoint keeps her full -- and so she can always draw
## the light the clearing asks for, however dry she came in.
func _on_beat_entered(obstacle_id: String) -> void:
	if CLEARINGS.has(obstacle_id) and ink_manager != null:
		ink_manager.add_ink(ink_manager.capacity)


## RUNNING DRY IS NOT A LOSS HERE. Every drawing costs, so it will happen, and the way on is still
## open: every encounter has a way past that needs no ink, and the clearings fill it again. The
## out-of-ink screen stays shut, and she says where more is.
func _on_ink_emptied() -> bool:
	_speak(script_lines.fire("INK.empty"))
	return true
