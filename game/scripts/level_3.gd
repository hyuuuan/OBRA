extends "res://scripts/level_base.gd"
## LEVEL 3 -- DAGAT. The sea, and the rule that replaces the clock.
##
## Extended BY PATH rather than by `class_name LevelBase`, for the reason game_level.gd and
## level_2.gd are: a `--script` run does not register class names and the probes are exactly
## that.
##
## What this level adds to the machine that neither of the first two needed:
##
##   * NO MORPH CLOCK. `_morph_has_a_life()` answers false once the new brush is found, so
##     MorphLife.begin is never called and a form is held for as long as the ink lasts. The
##     MorphCard's gauge is re-captioned INK and fed from here.
##   * A ZERO CASE THAT IS NOT A LOSS SCREEN. `_on_ink_emptied()` takes the out-of-ink
##     overlay off the table and does the design's own thing instead: revert, carry the apo
##     up to the surface, lose the crossing, never die.
##   * THE DROWNING RESCUE IN THIS LEVEL'S OWN WORDS. It is NOT switched off -- see
##     `_drowning_words` below for what happened when it was.
##   * A SECOND DIALOGUE NODE. Piyesta committed two of its three beats implicitly, through
##     the drawing. Dagat cannot: the bakunawa's Pragmatist resolution is not a drawing at
##     all, so it has to be offered out loud, and a level with two spoken forks needs two
##     volumes and a `_dialogue_node_obstacle_id()` that answers for whichever one is live.
##
## ⚠ THE DRAIN IS THE LEVEL'S, NOT THE BRUSH'S. `has_new_brush()` is a profile flag and it
## survives into Levels 4 and 5 -- but it is consulted HERE, by this level, and Payyo and
## Piyesta never ask. A player who finds the brush and then replays a memory gets that
## memory's rules back, which is the whole reason the hook is a level virtual.

const RestrictionsClass = preload("res://scripts/level_restrictions.gd")
const SkinClass = preload("res://scripts/drawing_skin_2d.gd")
## ⚠ PRELOADED, NOT NAMED. A `--script` run does not register class names -- the same reason
## this file extends level_base by path -- so naming the creature's class directly here fails
## to parse in every one of the probes that loads this level.
const BakunawaClass = preload("res://scripts/bakunawa_2d.gd")
const LifeClass = preload("res://scripts/dagat_life_2d.gd")
const NextPaintingClass = preload("res://scripts/next_painting_2d.gd")
## The house's own painting of the next place -- the picture that hangs in her house for Level 4.
const NEXT_PAINTING := preload("res://assets/hub/paintings/level_4.png")
## What the bakunawa had lost: a torn corner of one of her canvases, in its gilt. Authored by
## tools/build_dagat_props.py from the house's own painting of this sea.
const LOST_CORNER := preload("res://assets/Level3/authored/painting_fragment.png")
const FLOWER_ART := preload("res://assets/Level1/hidden_flower.png")
## A seabed jar, for its acquired card, and the blue its flourish is thrown in.
const JAR_ART := preload("res://assets/Level3/authored/ink_jar_0.png")
const JAR_BLUE := Color(0.55, 0.82, 1.0, 1.0)
## Whether the first jar's card has been shown this run. Not run state: a restore that took the
## jar back would otherwise show the card a second time.
var _jar_announced := false
const COUNT_WORDS := ["None", "One", "Two", "Three", "Four", "Five"]
## The bangka's paddle, the hull's own wood. See _row.
const PADDLE := preload("res://assets/Level3/authored/paddle.png")
const PropClass = preload("res://scripts/dagat_prop_2d.gd")
const PROPS := "res://assets/Level3/props/"
const AUTHORED := "res://assets/Level3/authored/"
const AMBIENCE := "res://assets/Level3/ambience/"
## ⚠ THE SEABED, IN WORLD Y. Three things have to agree on it and only one of them can be
## typed: the painted floor (DeepBand's plate_top 560 + floor_drop 360 + the terraces' floor at
## plate row 789), the Seabed collision's top, and everything placed on the bed here. It moved
## twice while the level was being painted; run_level3_audit fails if the collision and this
## disagree, so the third move cannot leave the coral standing in the rock.
const BED_Y := 1709.0

## Where the waterline sits, read off the mark rather than typed twice. Everything below it
## is the sea: the aquatic rule is armed there and nowhere else, because the shore and a
## boat's deck are air.
var _waterline_y := INF

var _marks: Node2D
var _sea: WaterArea2D
var _restrictions: LevelRestrictions
var _drain: InkDrain

## The second spoken fork. See the header.
var _bakunawa_node: DialogueNode2D
## The first fork's own volume, kept because `dialogue_node` is re-pointed at the second one
## and the base reads that field for both.
var _shore_node: DialogueNode2D
## Which beat the choice overlay is currently answering for. Set when a node is approached,
## because `_dialogue_node_obstacle_id()` is asked at both the presenting and the committing
## and has to give the same answer to each.
var _live_node_obstacle := "L3_N1"
## How long a drain runs before its event is noted again, so the lessons chained on it land in
## turn. The first of them stays up eight seconds.
const DRAIN_LESSON_EVERY := 8.0
var _drain_lesson_clock := 0.0
## The crossing's volume, and whether the player is standing in it. See _gate_the_crossing.
var _crossing_area: LevelObstacle2D
var _inside_crossing := false

## Latches, so a lesson and a line are each spent once per run rather than once per frame.
var _said_underwater := false
var _said_the_jars := false
var _brush_taken := false
var _bangka_found := false
## Which seabed refills have been taken this run, by index. Run state, not profile: a
## checkpoint restore that handed them all back would make the crossing free.
var _refills_taken: Array = []
## The refills standing in the water now, by index -- so a restore can put back the ones it
## rolled back without planting a second jar on top of one that is still there.
var _refill_nodes: Dictionary = {}
var _bangka: Area2D
## The boat once it is in the water -- the real sailboat, not the beached prop above.
var _launched_boat: UtilityObject
var _bakunawa: BakunawaClass
## Contacts taken in the current go at the fight. Three and the fight restarts -- which is
## the design's own "losing restarts the fight. It does not end the run."
var _knocks := 0
var _knock_cooldown := 0.0
## Stops the stealth reset firing again on the frames between being seen and being moved.
var _reset_cooldown := 0.0
var _arrived := false
## Which lore beats have been spoken this run, by hook. The crossing is a scene rather than a
## trigger the player can re-cross, and a beat spoken twice is worse than one spoken late.
var _told: Dictionary = {}
var _shadow: Sprite2D
## The canvas in the island's sand, and whether the apo has taken it -- which is what the ending
## waits on. See _land_on_the_island.
var _next_painting: NextPaintingClass
var _painting_taken := false
## Everything that moves and is not the player -- gulls, jellies, surf, rain, lightning, the
## wake, bubbles, glints. See DagatLife2D.
var _life: LifeClass
## The establishing shot at the start, while it is still running. See _play_the_opening.
var _opening_live := false
## Whether the sky has been told the encounter is over. Compared against the director every
## frame rather than set once, so a checkpoint restored to before the resolution puts the
## storm back.
var _sky_is_clear := false

## THE BANGKA IS DUG OUT, THEN MOVED. Kent (2026-10-05): "the sand/shore should be longer so that
## there will be space for the bangka to be dug then dragged to the water. let the bangka be
## pushable using an anvil, not just the ant". It lies half buried up the beach; something drawn
## digs it free, and from then it moves when it is pushed -- by a Carry shape walking it down the
## sand, by an anvil dropped behind it, or all the way in with E. Run state, both.
var _bangka_dug := false
## Where the hull has got to down the sand, or NAN where it was planted.
var _bangka_x := NAN
## How far into the sand it lies before it is dug out, and the sand heaped over its keel.
const BURIED_SINK := 6.0
var _sand_heap: Sprite2D
## A Carry shape walking it down: how far ahead of the shape's middle the hull is kept.
const PUSH_LEAD := 150.0
## One anvil dropped behind it: how far the hull goes.
const ANVIL_SHOVE := 320.0
## How fast E drags it the whole way.
const DRAG_SPEED := 300.0
var _anvil_lines := 0

## THE APO'S BREATH. See _breathe. Seconds of it, how fast it comes back at the surface, how deep
## the head has to be before it is being spent, and how far out from either shore the apo may
## swim on it before the current turns them back -- the crossing is still a drawing, not a swim.
const AIR_SECONDS := 7.0
const AIR_REFILL := 3.5
const AIR_DEPTH := 30.0
const APO_SWIM_REACH := 700.0
var _air := AIR_SECONDS
var _air_meter: _AirMeter
var _told_the_current := false

## THE LIGHT THAT LEADS IT. See _guide_the_bakunawa. How far from the player it reaches, how close
## to it the creature has to be to notice it, and how near the cave counts as home.
const LURE_REACH := 600.0
const LURE_NOTICE := 1300.0
const HOME_REACH := 520.0
var _lure: _Lure
## Where the light is for a run with no mouse to point it -- the probes set this.
var lure_override: Variant = null
var _cave_mouth := Vector2.ZERO
var _cave_inside := Vector2.ZERO
var _lead_told := false


# --- What the machine asks -------------------------------------------------------------

func level_config_path() -> String:
	return "res://config/level_03.json"


func dialogue_path() -> String:
	return "res://config/dialogue_l3.json"


func _dialogue_node_obstacle_id() -> String:
	return _live_node_obstacle


## Dagat asks at the shore and again at the bakunawa.
func _fork_for(obstacle_id: String) -> DialogueNode2D:
	match obstacle_id:
		"L3_N1":
			return _shore_node
		"L3_N2":
			return _bakunawa_node
	return super._fork_for(obstacle_id)


func _resume_committed_route(obstacle_id: String, route: String) -> void:
	_on_route_committed_here(obstacle_id, route)


func _resolve_level_nodes() -> void:
	var plane := ^"EnvironmentBaseplate/GameplayPlane"
	dialogue_node = get_node_or_null(
		plane.get_concatenated_names() + "/DialogueNode") as DialogueNode2D
	_bakunawa_node = get_node_or_null(
		plane.get_concatenated_names() + "/BakunawaNode") as DialogueNode2D
	_shore_node = dialogue_node
	_sea = get_node_or_null(plane.get_concatenated_names() + "/Sea") as WaterArea2D
	_bakunawa = get_node_or_null(plane.get_concatenated_names() + "/Bakunawa") as BakunawaClass
	_marks = get_node_or_null(plane.get_concatenated_names() + "/Marks") as Node2D
	var waterline := _mark("WaterlineMark")
	if waterline != null:
		_waterline_y = waterline.global_position.y


func _mark(mark_name: String) -> Node2D:
	return _marks.get_node_or_null(NodePath(mark_name)) as Node2D if _marks != null else null


## The world is a column as much as a crossing -- beach, surface, seabed -- so the camera
## follows height. See LevelBase._camera_follows_height for what the pinned camera did here.
func _camera_follows_height() -> bool:
	return true


func _build_level_furniture() -> void:
	var world_camera := _world_camera()
	if world_camera != null:
		world_camera.set_vertical_free(true)
		world_camera.snap_to_target()
	_restrictions = RestrictionsClass.new()
	_restrictions.name = "LevelRestrictions"
	add_child(_restrictions)
	for problem: Variant in _restrictions.load_from(director.level_data(), _roster_ids()):
		# LOUD AT STARTUP, never quiet at runtime. A swimmer list that resolves to nothing
		# does not fail open the way a ban list does -- it drowns every creature drawn here.
		push_error("Level3: %s" % problem)
	_restrictions.floundered.connect(_on_floundered)

	# ⚠ NOT set_refusal_filter. Piyesta hands the director its ban list so the hint ladder
	# stops offering what the level will refuse; here there is nothing to refuse. A land
	# creature is a legal answer that turns out to be a bad one, and the tag layer should go
	# on offering it -- the level says no with the world, not at the canvas.

	_drain = get_node_or_null(^"InkDrain") as InkDrain
	if _drain != null:
		_drain.bind(ink_manager)
		var economy: Dictionary = director.level_data().get("ink_economy", {})
		_drain.default_rate = float(economy.get("default_rate_per_second", _drain.default_rate))
		_drain.warning_ratio = float(economy.get("warning_ratio", _drain.warning_ratio))
		_drain.rates = economy.get("rates", {})
		_drain.low_ink.connect(_on_low_ink)
		_drain.ink_emptied.connect(_on_drain_emptied)

	_plant_the_brush()
	_plant_the_bangka()
	_plant_the_refills()
	_plant_the_coral_field()
	_plant_the_next_painting()
	_plant_the_cave()
	_plant_the_hook()
	_release_the_sea_creatures()
	_scatter_the_ambience()
	_bring_the_sea_to_life()
	call_deferred("_play_the_opening")

	if _bakunawa != null:
		_bakunawa_home = _bakunawa.global_position
		_bakunawa.gift_offered.connect(_on_gift_offered)
		_bakunawa.went_quiet.connect(_on_bakunawa_quiet)
		_bakunawa.hit_taken.connect(_on_bakunawa_hit)
		_bakunawa.begin_search()
	if director != null:
		director.route_committed.connect(_on_route_committed_here)
		# Deferred: the obstacle volumes are wired AFTER the furniture, so the connection this
		# replaces does not exist yet.
		call_deferred("_gate_the_crossing")
	var arrival := get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/IslandArrival") as CheckpointArea2D
	if arrival != null:
		arrival.reached.connect(_on_island_reached)


func _roster_ids() -> PackedStringArray:
	var out := PackedStringArray()
	if registry == null:
		return out
	for id: Variant in registry.get_entity_ids():
		out.append(String(id))
	return out


## THE NEW BRUSH, glinting in the wet sand. A pickup rather than an obstacle: a sub-beat
## resolves a tag, and picking something up is not a drawing.
##
## ⚠ CODE-DRAWN, AND THAT IS THE CONTRACT, NOT THE ART. Nothing on Dagat's asset list exists
## yet, so this is a shape with the right size, the right place and the right behaviour,
## the way Payyo's props were before they were painted. ART_PLACEHOLDERS.md is where its
## contract goes: the design asks for something that reads as a different tool from
## magicbrush.png at a glance, in silhouette and colour.
func _plant_the_brush() -> void:
	if PlayerProfile.has_new_brush():
		_brush_taken = true
		# Found on an earlier run: there is nothing on the sand to take, so the beat the brush
		# answers is answered from the start, or the crossing would wait for it forever.
		# Deferred, so the director's listeners are wired before it is told.
		if director != null:
			director.solve_with_item.call_deferred("L3_B0_SHORE", "new_brush")
		return
	var mark := _mark("BrushMark")
	if mark == null:
		return
	var pickup := Area2D.new()
	pickup.name = "NewBrush"
	pickup.collision_layer = 0
	pickup.collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 44.0
	shape.shape = circle
	pickup.add_child(shape)
	# ⚠ THE HUD'S OWN BRUSH, NOT A SECOND DRAWING OF ONE. What the apo picks up off the sand
	# and what the ink panel carries for the rest of the run are the same tool, and two
	# separate pictures of it are two things to keep in step. brush_full.png is 384 square
	# with the brush across its middle, so the sprite is regioned to the ink and scaled to
	# the size the design asks for -- a tool lying in the sand, not a shell.
	var art := Sprite2D.new()
	art.name = "Brush"
	art.texture = load("res://assets/hud/brush_full.png") as Texture2D
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.region_enabled = true
	art.region_rect = Rect2(6.0, 156.0, 366.0, 66.0)
	art.scale = Vector2.ONE * 0.26
	art.rotation = -0.18
	art.position = Vector2(0.0, 6.0)
	pickup.add_child(art)
	pickup.global_position = mark.global_position
	pickup.z_index = 8
	mark.get_parent().add_child(pickup)
	pickup.body_entered.connect(_on_brush_touched.bind(pickup))
	# ⚠ "Something in the sand is catching the light" is the objective this level prints while
	# the brush is on the beach, so something had better catch the light. A slow lift and a
	# glint every few seconds; both go with the pickup when it is taken.
	var lift := art.create_tween().set_loops()
	lift.tween_property(art, "position:y", 0.0, 1.4).set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	lift.tween_property(art, "position:y", 6.0, 1.4).set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	var glint := Timer.new()
	glint.wait_time = 2.4
	glint.autostart = true
	pickup.add_child(glint)
	glint.timeout.connect(func() -> void:
		if _life != null and is_instance_valid(_life) and is_instance_valid(pickup):
			_life.sparkle(pickup.global_position + Vector2(14.0, -8.0), 3, 24.0))


## THE BOAT IS FOUND, NOT DRAWN -- the design decided it, on the grounds that finding fits
## the Artist framing the way Piyesta's Artist route was about looking and asking rather than
## making. So it is beached on the sand from the start and E is what answers the route.
##
## ⚠ IT IS NOT A PROP. Taking it puts a real `sailboat` in the water, which already carries
## the player: `run_behaviour_audit` measures it at 570px with a passenger aboard. A found
## boat that could not be sailed would answer the fork and then strand the player on the
## shore with the route solved, which is a worse dead end than no boat at all.
func _plant_the_bangka() -> void:
	var mark := _mark("BangkaMark")
	if mark == null:
		return
	_bangka = Area2D.new()
	_bangka.name = "BeachedBangka"
	_bangka.collision_layer = 0
	_bangka.collision_mask = 0
	var art := Sprite2D.new()
	art.name = "Hull"
	art.texture = load(AUTHORED + "bangka_beached.png") as Texture2D
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# ⚠ PINNED BY THE SAND LINE IN THE PICTURE, NOT BY THE SPRITE'S MIDDLE. The drawing is a
	# 132-tall canvas with the hull lying across its lower third, so centred on the mark the
	# boat floated a good fifty pixels over the beach. See BANGKA_WATERLINE in
	# tools/build_dagat_props.py: the sand row is 117 down a 132 sprite, and the mark is 20
	# above the sand the apo walks on.
	art.position = Vector2(0.0, -31.0 + (0.0 if _bangka_dug else BURIED_SINK))
	_bangka.add_child(art)
	# HALF IN THE SAND until it is dug out: the keel sunk and a heap of the beach over it.
	var heap := Sprite2D.new()
	heap.name = "SandHeap"
	heap.texture = load(AUTHORED + "sand_mound.png") as Texture2D
	heap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Over the stern only: the bow sticks out of the drift, so it is a boat in the sand, not a heap.
	heap.scale = Vector2(0.85, 1.1)
	heap.position = Vector2(48.0, 4.0)
	heap.z_index = 1
	heap.visible = not _bangka_dug
	_bangka.add_child(heap)
	_sand_heap = heap
	_bangka.global_position = mark.global_position
	if is_finite(_bangka_x):
		_bangka.global_position.x = _bangka_x
	_bangka.z_index = 6
	mark.get_parent().add_child(_bangka)


## Ink comes back from sources placed in the level, never over time -- the design is explicit
## that time-based regeneration "would make the whole economy decorative". Three of them down
## the dive route, because that route is transformed from start to finish and the boat is not.
## THE NEXT PAINTING, standing in the island's sand where the landing sparkles. It is the one
## that hangs in her house for the next level, in the house's own gilt, half buried and
## catching the light -- see NextPainting2D. Where it stands is where the landing has always
## sparkled, so the glitter and the picture are one thing.
func _plant_the_next_painting() -> void:
	var sand := _mark("IslandMark")
	if sand == null:
		return
	var painting := NextPaintingClass.new()
	painting.name = "NextPainting"
	painting.art = NEXT_PAINTING
	painting.z_index = 5
	sand.get_parent().add_child(painting)
	painting.global_position = sand.global_position + Vector2(90.0, 0.0)
	painting.taken.connect(_on_next_painting_taken)
	_next_painting = painting


## THE BAKUNAWA'S HOME: a hollow in the rock face of the first beach, under the water. Kent
## (2026-10-05): "lets put a cave opening near the island where i started so we can bring the sea
## serpent home there". The light route leads it back across the sea to here, and it goes in.
##
## Drawn on the face rather than cut into the collision: the land is solid to the seabed so a
## diver cannot fall into an air pocket under the beach, and a real tunnel would be exactly that.
## What the creature does here is swim into the dark of it and be gone.
func _plant_the_cave() -> void:
	var mark := _mark("CaveMark")
	if mark == null:
		return
	var edges := level_data_shore_edges()
	var face_x := edges.x if edges != Vector2.ZERO else mark.global_position.x
	var cave := Node2D.new()
	cave.name = "Cave"
	cave.z_index = -40
	mark.get_parent().add_child(cave)
	cave.global_position = Vector2(face_x, mark.global_position.y)
	# The opening: an arch of dark going back into the rock, a rim of lit stone round it, and a
	# few stones fallen at its foot. Shapes, not a picture -- it is a hole, and holes are dark.
	var arch := PackedVector2Array()
	var rim := PackedVector2Array()
	for step in range(25):
		var t := PI * float(step) / 24.0
		arch.append(Vector2(-190.0 * sin(t) * 0.9, -150.0 * cos(t) - 10.0) + Vector2(-8.0, 0.0))
		rim.append(Vector2(-214.0 * sin(t) * 0.9, -172.0 * cos(t) - 10.0) + Vector2(-2.0, 0.0))
	var stone := Polygon2D.new()
	stone.polygon = rim
	stone.color = Color(0.13, 0.27, 0.36, 1.0)
	cave.add_child(stone)
	var dark := Polygon2D.new()
	dark.polygon = arch
	dark.color = Color(0.01, 0.03, 0.07, 1.0)
	# Darkest at the back, the water's own blue at the lip.
	var shades := PackedColorArray()
	for point in arch:
		var back := clampf(-point.x / 170.0, 0.0, 1.0)
		shades.append(Color(0.02, 0.07, 0.14, 1.0).lerp(Color(0.0, 0.01, 0.03, 1.0), back))
	dark.vertex_colors = shades
	cave.add_child(dark)
	for pebble in [[Vector2(18.0, 236.0), 26.0], [Vector2(52.0, 242.0), 18.0],
			[Vector2(-30.0, 240.0), 20.0]]:
		var rock := Polygon2D.new()
		var outline := PackedVector2Array()
		var radius: float = pebble[1]
		for k in range(9):
			var a := TAU * float(k) / 9.0
			outline.append(Vector2(cos(a) * radius * 1.3, sin(a) * radius * 0.8))
		rock.polygon = outline
		rock.position = pebble[0]
		rock.color = Color(0.1, 0.22, 0.3, 1.0)
		cave.add_child(rock)
	# Kelp either side of the mouth, so it is a place and not a smudge on the wall.
	# Their feet on the bed, which is BED_Y - the cave mark's own height below it.
	var foot := BED_Y - 4.0 - mark.global_position.y
	for side in [[Vector2(70.0, foot), "kelp_long", 210.0], [Vector2(150.0, foot), "kelp_short", 140.0]]:
		var kelp := PropClass.new()
		kelp.prefix = PROPS + String(side[1])
		kelp.target_height = side[2]
		kelp.fps = 1.8
		kelp.shadow_width = 16.0
		kelp.position = side[0]
		cave.add_child(kelp)
	_cave_mouth = cave.global_position + Vector2(90.0, 20.0)
	_cave_inside = cave.global_position + Vector2(-150.0, 10.0)
	# A glint at the mouth every few seconds while the creature is being led -- so the place it
	# is being led to can be found from across the water.
	var glint := Timer.new()
	glint.wait_time = 2.2
	glint.autostart = true
	cave.add_child(glint)
	glint.timeout.connect(func() -> void:
		if _life != null and is_instance_valid(_life) and _guiding():
			_life.sparkle(_cave_mouth + Vector2(-40.0, -60.0), 4, 40.0))


func _plant_the_refills() -> void:
	var coral := _mark("CoralMark")
	if coral == null:
		return
	# ⚠ READ FROM THE LEVEL FILE, NOT TYPED HERE. run_swim_reach_probe.gd checks that every
	# one of the seven can cover the longest stretch BETWEEN these, so the spots and the rates
	# have to be the same numbers the probe sees. Hard-coded here they could drift apart and
	# the check would be verifying a layout the level does not have.
	var economy: Dictionary = director.level_data().get("ink_economy", {})
	var amount := float(economy.get("refill_units", 1.5))
	var spots: Array[Vector2] = []
	for pair: Variant in economy.get("refill_spots", []):
		var xy: Array = pair
		spots.append(Vector2(float(xy[0]), float(xy[1])))
	for index in spots.size():
		if _refills_taken.has(index):
			continue
		var standing := _refill_nodes.get(index) as Node
		if standing != null and is_instance_valid(standing) and not standing.is_queued_for_deletion():
			continue
		var refill := Area2D.new()
		refill.name = "Refill%d" % index
		refill.collision_layer = 0
		refill.collision_mask = 1
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 52.0
		shape.shape = circle
		refill.add_child(shape)
		# The jar from the painted plate, authored as a sprite by tools/build_dagat_props.py
		# because the delivery has it in the picture rather than as a file.
		var art := PropClass.new()
		art.prefix = AUTHORED + "ink_jar"
		art.fps = 2.4
		# ⚠ ITS OWN SIZE: the picture is 90 tall, and at 92 every art pixel was 1.02 screen
		# pixels, so nearest sampling doubled one column in fifty and the glass shimmered.
		art.target_height = 90.0
		art.phase = index
		art.shadow_width = 24.0
		refill.add_child(art)
		refill.global_position = spots[index]
		refill.z_index = 6
		coral.get_parent().add_child(refill)
		refill.body_entered.connect(_on_refill_touched.bind(index, amount, refill))
		_refill_nodes[index] = refill


## THE CORAL FIELD, and the design calls it the best small idea in the draft: Lolo as
## somebody who taught children things, which is what makes his leaving at the island cost
## more than the painting does.
##
## ⚠ NO COUNTER, NO GATE, NO INK. "The moment a counter appears they become chores." Two of
## the ten are about lola rather than the animal, so a player who stops to look at everything
## gets something a rushing player does not, and it is story rather than an item.
##
## PROXIMITY RATHER THAN A KEY PRESS. The design says interact, but the player is swimming
## when they pass these and a fun fact is not an action -- asking for E ten times is the
## friction that turns them into the chores the design is warning about. They fire once each,
## through the HintBar, which does not stop the world.
##
## ⚠ ALL TEN ARE NON-DRAWABLE CREATURES ON PURPOSE. The design asks for it so the field does
## not read as a menu of things the player could have drawn -- and it is also the only way a
## field of sea life can be written at all, since seventeen of the fifty are exactly what you
## would reach for.
func _plant_the_coral_field() -> void:
	var coral := _mark("CoralMark")
	if coral == null:
		return
	var field := coral_field()
	for key: String in field.keys():
		var spot := Area2D.new()
		spot.name = "Coral_%s" % key
		spot.collision_layer = 0
		spot.collision_mask = 1
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 150.0
		shape.shape = circle
		spot.add_child(shape)
		spot.global_position = field[key]
		coral.get_parent().add_child(spot)
		spot.body_entered.connect(_on_coral_touched.bind(key))
		# ⚠ AND SOMETHING TO LOOK AT. Ten invisible trigger volumes is a field of facts about
		# nothing: Lolo names a thing the player cannot see. Each fact now stands on the piece
		# of scenery it is about.
		if not SCENERY.has(key):
			continue
		var piece := PropClass.new()
		piece.prefix = PROPS + String(SCENERY[key])
		piece.target_height = float(SCENERY_HEIGHT.get(key, 120))
		piece.fps = 1.6 + float(seed_of(key) % 5) * 0.2
		piece.phase = seed_of(key) % 3
		piece.mirrored = seed_of(key) % 2 == 1
		piece.z_index = 3
		# A frond of kelp is a stalk where it meets the sand; a coral is a heap.
		piece.shadow_width = 16.0 if String(SCENERY[key]).begins_with("kelp") else 30.0
		spot.add_child(piece)


## WHERE EACH FACT STANDS. Public so the probes swim to the level's own field rather than to a
## copy of it that the next move of the seabed leaves behind.
##
## ⚠ ON THE BED, BECAUSE THE SCENERY STANDS ON IT. Every fact carries a piece of kelp or coral,
## and a frond anchored at its foot in open water is a plant growing out of nothing -- so they
## are placed on BED_Y, a few pixels into it, and move when it does. They used to be literals
## at 1344..1350 and had to be re-typed each time the bed moved.
##
## `shaft` is the exception: its fact is "look up, that is the whole top of the world from down
## here", the light shafts it names are painted into the top of the water, and standing a coral
## under it would be answering a different sentence. It sits where the shafts are.
func coral_field() -> Dictionary:
	var bed := BED_Y - 4.0
	# Spread down the longer sea (2026-10-05) at the same intervals, half again as wide.
	return {
		"jelly": Vector2(2230.0, bed), "star": Vector2(2790.0, bed + 2.0),
		"clam": Vector2(3315.0, bed + 1.0), "weed": Vector2(3665.0, bed + 4.0),
		"urchin": Vector2(4085.0, bed), "coral": Vector2(4505.0, bed + 3.0),
		"shaft": Vector2(4925.0, 900.0), "wreck": Vector2(5240.0, bed + 2.0),
		"lola1": Vector2(2965.0, bed + 4.0), "lola2": Vector2(5555.0, bed + 1.0),
	}


## WHICH PIECE OF SCENERY EACH FACT IS ABOUT. The facts were written for the non-drawable
## set on purpose -- see the header on _plant_the_coral_field -- so the kelp, the corals and
## the urchin carry them and no fact is attached to something the player could have summoned.
const SCENERY := {
	"jelly": "coral_violet", "star": "coral_orange", "clam": "coral_blue",
	"weed": "kelp_long", "urchin": "coral_red", "coral": "coral_orange",
	"wreck": "coral_red", "lola1": "kelp_long", "lola2": "kelp_short",
}
const SCENERY_HEIGHT := {
	"weed": 190, "lola1": 205, "lola2": 140,
	"jelly": 120, "star": 105, "clam": 115, "urchin": 100, "coral": 110, "wreck": 108,
}


## A stable per-key number, so a frond's phase and lean are the same on every run rather than
## re-rolled -- a bed that rearranges itself when you swim back is worse than a still one.
static func seed_of(key: String) -> int:
	var total := 0
	for index in key.length():
		total += key.unicode_at(index) * (index + 3)
	return total


func _on_coral_touched(body: Node, key: String) -> void:
	if not _is_the_player(body):
		return
	# ⚠ NOT OVER HIM. A fact is about the thing the player is passing, and it waits while Lolo
	# is still being read (see _pace_the_advice) rather than being queued behind him -- queued,
	# it would be about a coral three screens back. Not fired until it is said, so a fact that
	# never got its moment is still there if the player swims back.
	if _advice_left > 0.0 or not _advice_waiting.is_empty():
		_coral_waiting = key
		return
	# `once` on the line does the not-twice part; firing again is free and says nothing.
	_speak(script_lines.fire("CORAL.%s" % key))


## BUBBLES AND FISH, which are the difference between a painted sea and a sea. Nothing here
## is interactive and nothing here is a fact -- the ten facts are earned by swimming up to
## something, and a field where everything moves has no way to say which things are which.
func _scatter_the_ambience() -> void:
	var coral := _mark("CoralMark")
	if coral == null:
		return
	# Columns rise off the bed; schools drift through the middle of the column. Placed by
	# hand rather than by random so nothing lands inside a terrace or on top of a fact.
	var bed := BED_Y
	var placings := [
		[AMBIENCE + "bubbles_long", Vector2(1915.0, bed - 20.0), 210.0, 3.0],
		[AMBIENCE + "bubbles_short", Vector2(2685.0, bed - 50.0), 130.0, 3.6],
		[AMBIENCE + "bubbles_long", Vector2(3840.0, bed - 10.0), 235.0, 2.6],
		[AMBIENCE + "bubbles_short", Vector2(4820.0, bed - 50.0), 140.0, 3.2],
		[AMBIENCE + "bubbles_long", Vector2(5820.0, bed - 20.0), 200.0, 2.8],
		[AMBIENCE + "bubbles_short", Vector2(6560.0, bed - 50.0), 135.0, 3.4],
		[AMBIENCE + "school", Vector2(2390.0, 1180.0), 175.0, 2.2],
		[AMBIENCE + "school", Vector2(3960.0, 1060.0), 210.0, 1.8],
		[AMBIENCE + "school", Vector2(5360.0, 1240.0), 165.0, 2.4],
		[AMBIENCE + "school", Vector2(4560.0, 1100.0), 195.0, 2.0],
	]
	for index in placings.size():
		var row: Array = placings[index]
		var piece := PropClass.new()
		piece.name = "Ambience%d" % index
		piece.prefix = String(row[0])
		# ⚠ ASSIGNED, NOT CONVERTED. float(x) on a Variant that is already a float is not a
		# constructor GDScript has, and it throws once per prop per run; the typed property
		# does the coercion on its own.
		piece.target_height = row[2]
		piece.fps = row[3]
		piece.phase = index
		piece.mirrored = index % 3 == 0
		piece.z_index = -20
		piece.modulate = Color(1.0, 1.0, 1.0, 0.75)
		coral.get_parent().add_child(piece)
		piece.global_position = row[1]
		# ⚠ A SCHOOL THAT STAYS PUT IS A PICTURE OF ONE. They patrol a stretch of the column
		# and turn at each end; the columns of bubbles stay where they rise from.
		if String(row[0]).ends_with("school"):
			_patrol(piece, 150.0 + float(index % 3) * 40.0, 7.0 + float(index % 4))


## Back and forth across `reach`, turning to face the way it swims.
func _patrol(piece: Sprite2D, reach: float, seconds: float) -> void:
	var home := piece.position.x
	var loop := piece.create_tween().set_loops()
	loop.tween_callback(func() -> void: piece.flip_h = false)
	loop.tween_property(piece, "position:x", home + reach, seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop.tween_callback(func() -> void: piece.flip_h = true)
	loop.tween_property(piece, "position:x", home - reach, seconds * 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop.tween_callback(func() -> void: piece.flip_h = false)
	loop.tween_property(piece, "position:x", home, seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## THE OPENING. Payyo opens in the house and Piyesta on Lolo talking; Dagat opens on the sea.
## The letterbox comes in with the level's name, the camera starts out over the open water
## the whole level is about -- far enough to see the weather gathering -- and a few gulls head
## in for the beach as it eases back to the apo standing on it.
##
## ⚠ NOTHING WAITS FOR IT. The tree is not paused and input is not taken: any key ends it at
## once, and a player who starts walking has simply started. It is three seconds of a level a
## player may restart many times, so it has to be skippable by doing anything at all.
func _play_the_opening() -> void:
	var world_camera := _world_camera()
	if world_camera == null or cinematic == null or _marks == null or _level_completed:
		return
	_opening_live = true
	var shot := Node2D.new()
	shot.name = "OpeningShot"
	_marks.add_child(shot)
	shot.global_position = Vector2(3960.0, 460.0)
	var title := String(LevelManager.get_level(LevelManager.current_level_id).get("title", ""))
	cinematic.close(title.to_upper() if not title.is_empty() else "DAGAT")
	world_camera.focus_on(shot, 0.9, 0.0, 0.0)
	world_camera.snap_to_target()
	if _life != null:
		_life.send_gulls(shot.global_position + Vector2(260.0, 0.0), 3, 0)
	await get_tree().create_timer(2.3).timeout
	if _opening_live:
		_opening_follow = world_camera.follow_lerp_speed
		world_camera.follow_lerp_speed = 1.5
		world_camera.release_focus(1.8)
		await get_tree().create_timer(1.7).timeout
	_end_the_opening(false)
	shot.queue_free()


var _opening_follow := -1.0


func _end_the_opening(skipped: bool) -> void:
	var world_camera := _world_camera()
	if world_camera != null and _opening_follow > 0.0:
		world_camera.follow_lerp_speed = _opening_follow
		_opening_follow = -1.0
	if not _opening_live:
		return
	_opening_live = false
	if skipped and world_camera != null and world_camera.is_focused():
		world_camera.release_focus(0.3)
	if cinematic != null and not _level_completed:
		cinematic.open()


## Any key or click during the opening ends it -- and still does whatever it was pressed for.
func _handle_level_input(event: InputEvent) -> bool:
	# The fishing key is HELD: pressed starts a cast charging (or winds a line already out), and
	# released lets the cast go. Taken here, at the press and the release, because the base only
	# hears the press.
	if event.is_action(&"use_utility") and not event.is_echo():
		if event.is_pressed():
			if _line != null:
				return true
			if _can_cast():
				_begin_charge()
				return true
		elif _charge >= 0.0:
			_release_charge()
			return true
	if _opening_live and event.is_pressed() and not event.is_echo() \
			and (event is InputEventKey or event is InputEventMouseButton
				or event is InputEventJoypadButton):
		_end_the_opening(true)
	return false


## The level's living things, and the animals the coral field talks about.
func _bring_the_sea_to_life() -> void:
	var coral := _mark("CoralMark")
	if coral == null:
		return
	_life = LifeClass.new()
	_life.name = "DagatLife"
	_life.camera = _world_camera()
	_life.storm = get_node_or_null(^"EnvironmentBaseplate/StormBand") as Node2D
	_life.waterline_y = _waterline_y if is_finite(_waterline_y) else 560.0
	_life.bed_y = BED_Y
	var edges := level_data_shore_edges()
	if edges != Vector2.ZERO:
		_life.shore_edges = edges
	_life.jelly_spots = [Vector2(2860.0, 1240.0), Vector2(3930.0, 1060.0),
		Vector2(4715.0, 1380.0), Vector2(5415.0, 1120.0), Vector2(6700.0, 1080.0)]
	_life.player_anchor = func() -> Vector2: return _anchor_now()
	_life.player_swimming = func() -> bool:
		return player != null and is_instance_valid(player) and not (player is Wanderer) \
			and _anchor_now().y > _waterline_y + 20.0
	_life.boat = func() -> RigidBody2D:
		var carrying := _boat_carrying_player()
		if carrying != null:
			return carrying
		return _launched_boat if _launched_boat != null and is_instance_valid(_launched_boat) \
			else null
	_life.creature = _bakunawa
	coral.get_parent().add_child(_life)
	# ⚠ THE ANIMALS LOLO ACTUALLY NAMES. Four of the facts are about a jellyfish, a starfish, a
	# clam and an urchin -- chosen because none of them is something the player can draw -- and
	# each stood on a piece of coral while he talked about it. Now the thing is there.
	var field := coral_field()
	# The last number is the shadow each casts on the sand; the jellyfish is not on the sand.
	for pair in [["jelly", "jelly", 70.0, Vector2(60.0, -150.0), 4.0, 0.0],
			["star", "starfish", 44.0, Vector2(58.0, 0.0), 1.2, 24.0],
			["clam", "clam", 34.0, Vector2(-56.0, 0.0), 1.0, 26.0],
			["urchin", "urchin", 40.0, Vector2(52.0, 0.0), 2.0, 22.0]]:
		if not field.has(pair[0]):
			continue
		var animal := PropClass.new()
		animal.name = "Fact_%s" % pair[0]
		animal.prefix = AUTHORED + String(pair[1])
		animal.target_height = pair[2]
		animal.fps = pair[4]
		animal.shadow_width = pair[5]
		animal.phase = seed_of(String(pair[0])) % 3
		animal.z_index = 4
		coral.get_parent().add_child(animal)
		animal.global_position = (field[pair[0]] as Vector2) + (pair[3] as Vector2)
		if pair[0] == "jelly":
			var drift := animal.create_tween().set_loops()
			drift.tween_property(animal, "position:y", animal.position.y - 34.0, 2.6) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			drift.tween_property(animal, "position:y", animal.position.y, 2.6) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _anchor_now() -> Vector2:
	if player == null or not is_instance_valid(player):
		return Vector2.ZERO
	var anchor := player.call("get_physics_anchor") as Node2D \
		if player.has_method("get_physics_anchor") else null
	return anchor.global_position if anchor != null else player.global_position


## ⚠ WHAT THE JARS ARE IS SAID WHEN ONE IS FIRST IN FRONT OF THE DIVER. Nothing did say it:
## the only line about them was "you have to find more of it" at the moment the ink was nearly
## gone, which names neither the jars nor where they are, and taking one said "that will hold you
## a while longer" after the fact. Pale jars with a drop on them, standing on a seabed full of
## scenery, read as scenery. So the first time a swimmer comes within reach of one, the lesson
## `jars` says what it is and how it is taken, beside the ink card it refills.
const JAR_NOTICE_REACH := 360.0


func _point_out_the_jars(anchor_position: Vector2) -> void:
	if tutorial == null:
		return
	for node_value: Variant in _refill_nodes.values():
		var jar := node_value as Node2D
		if jar == null or not is_instance_valid(jar):
			continue
		if jar.global_position.distance_to(anchor_position) > JAR_NOTICE_REACH:
			continue
		# A LESSON BESIDE THE INK CARD, NOT A LINE ON THE BAR. The dive is told as a story, and
		# Lolo is on the bar for most of it: a line waiting for the bar to be free waited until
		# the diver was past every jar. Noted every frame a jar is in reach; the lesson is spent
		# once, and the latch stops the asking.
		tutorial.note("jar_in_reach")
		if tutorial.has_method("has_taught") and bool(tutorial.call("has_taught", "jars")):
			_said_the_jars = true
		return


func _on_refill_touched(body: Node, index: int, amount: float, refill: Area2D) -> void:
	if _refills_taken.has(index) or not _is_the_player(body):
		return
	_refills_taken.append(index)
	_refill_nodes.erase(index)
	ink_manager.add_ink(amount)
	_say_why("There. That will hold you a while longer.")
	# ⚠ TAKEN, AND SEEN TO BE. The jar used to vanish with a line of Lolo's and nothing else.
	# The first one taken gets the acquired card -- what it is and what it did -- and every one
	# a burst of the ink's own blue where it stood. Only the first: three of the six stand in the
	# bakunawa's waters, and a card that dims the screen mid-sneak is a card that gets you seen.
	PickupFlourish2D.burst(refill.get_parent() as Node2D, refill.position, JAR_BLUE)
	if not _jar_announced:
		_jar_announced = true
		announce_acquisition("Ink Jar",
			"Your ink, filled back up. Each jar on the bottom can be taken once.", JAR_ART)
	refill.queue_free()


## ⚠ WALK THE PARENT CHAIN. `player_character` is on the morph's ROOT, and what actually
## enters an Area2D is one of the rig's RigidBody2D segments -- so a direct group test on the
## colliding body is true for the apo and false for every drawn creature. The seabed refills
## are the ones that mattered: they sit where the player is ALWAYS a morph, so they could
## never have been picked up, and the only symptom would have been a crossing that ran out of
## ink. DialogueNode2D has carried the same walk since Level 1.
func _is_the_player(body: Node) -> bool:
	var node := body
	while node != null:
		if node.is_in_group(&"player_character") or node is ActiveRagdollMorph:
			return true
		node = node.get_parent()
	return false


func _on_brush_touched(body: Node, pickup: Area2D) -> void:
	if _brush_taken or not _is_the_player(body):
		return
	_brush_taken = true
	PlayerProfile.record_new_brush()
	if tutorial != null:
		tutorial.note("new_brush_taken")
	# ⚠ THE CAPTION CHANGES HERE AND NOT AT THE NEXT MORPH. From this moment the gauge is
	# measuring ink, and a card still captioned LIFE over a bar fed by the drain is the exact
	# confusion the shore beat exists to prevent.
	if morph_card != null:
		morph_card.set_meter_caption("INK")
	_say_why("Take it, apo. Hers is spent — this one was waiting for you.")
	# ⚠ ACQUIRED, AND SAID SO. Kent: what is taken in this level "should have the acquired pop
	# up since its an acquired" -- the card every other level shows for her key, her canvas and
	# her candle. The picture is the HUD's own brush, the one the ink panel carries from here on.
	announce_acquisition("A New Brush",
		"Hers is spent. This one holds a shape for as long as there is ink.", _brush_art())
	# The rule it brings, said as it is taken -- read after the line above. It is FELT on the
	# first shape held from here (see INK.first_drain), whichever way across that turns out
	# to be.
	_speak(script_lines.fire("L3_B0_SHORE.brush"))
	# ⚠ TAKING IT IS THE BEAT. There was a practice here -- a Swim drawing at the waterline
	# before the fork would open -- and Kent had it taken out: the choice comes first, and each
	# way across asks for its own drawing. Nothing was drawn, so it is closed as an item.
	if director != null:
		director.solve_with_item("L3_B0_SHORE", "new_brush")
	pickup.queue_free()


## The HUD's brush, cut to the ink the way the one in the sand is, for its acquired card.
func _brush_art() -> Texture2D:
	var sheet := load("res://assets/hud/brush_full.png") as Texture2D
	if sheet == null:
		return null
	var cut := AtlasTexture.new()
	cut.atlas = sheet
	cut.region = Rect2(6.0, 156.0, 366.0, 66.0)
	return cut


## The second fork, wired beside the first. `super()` still owns the overlay and the memory
## screen; this only adds the volume Piyesta had no equivalent of.
func _wire_dialogue_node() -> void:
	super()
	# ⚠ THE APPROACH IS RE-ROUTED, AND THE REST OF super() IS KEPT. The base wires one node
	# and reads `dialogue_node` for everything; with two forks, something has to say WHICH
	# one is being asked before the base's handler runs. Disconnecting just the one signal
	# leaves the overlay, the memory screen and route_chosen wired exactly as they were.
	if dialogue_node != null \
			and dialogue_node.approached.is_connected(_on_dialogue_node_approached):
		dialogue_node.approached.disconnect(_on_dialogue_node_approached)
		dialogue_node.approached.connect(_on_shore_fork_approached)
	if _bakunawa_node == null:
		return
	_bakunawa_node.approached.connect(_on_bakunawa_approached)
	_bakunawa_node.route_chosen.connect(_on_route_chosen)


# --- The three rules this level changes -------------------------------------------------

## FALSE ONCE THE BRUSH IS FOUND, and true before it. The shore is played under the old rule
## on purpose: the design wants the replacement taught before the fork, and a player who has
## not picked the brush up yet has not been told anything about ink.
func _morph_has_a_life() -> bool:
	return not PlayerProfile.has_new_brush()


## The ink ran out. The design's own words, and none of them is a loss: "the transformation
## reverts and the apo is carried up to the surface or to the nearest air pocket, losing
## progress on the crossing but never dying."
func _on_ink_emptied() -> bool:
	if not PlayerProfile.has_new_brush():
		return false
	return true


## ⚠ THE RESCUE STAYS ON, AND THIS COMMENT IS HERE BECAUSE SWITCHING IT OFF STRANDED THE
## PLAYER. The reasoning for switching it off was that fishing the apo out of a level that is
## the sea would be a rescue loop. It is not: the rescue tests `player is Wanderer`, and a
## morph is not one, so it can only fire when the player has no body at all -- which in this
## level means the ink ran out or they walked in without drawing. Both of those are exactly
## when they need carrying.
##
## Measured, not argued: with it off, walking off the shore sank the apo past the waterline
## with nothing to stand on for a thousand pixels and no fall limit to catch it, because the
## seabed is well inside the world bounds. The design is explicit that the player can never
## be stranded.
##
## What a sea level needs is its own words, not an exemption. Payyo's default names Payyo's
## plank, which means nothing out here.
func _drowning_words() -> PackedStringArray:
	return PackedStringArray([
		"You cannot swim, apo. Draw yourself something that can",
		"Up you come, apo. Back to %s.",
	])


## ⚠ NOT MID-ENCOUNTER, AND NOT FROM THE SURFACE. The clam that marks CP3b stands on the seabed
## in the middle of the bakunawa's waters. Framing it took the camera down to it for two seconds
## while the sweep went on -- a player can be seen in that time and never have seen the light
## coming -- and from the boat it is a thousand pixels under the keel. It opens either way; the
## player simply keeps the view.
func _may_frame_the_checkpoint(mark: Node2D) -> bool:
	if director != null and not director.committed_route("L3_N2").is_empty() \
			and not director.is_solved("L3_N2"):
		return false
	return mark.global_position.distance_to(_anchor_now()) < 700.0


func _checkpoint_place(checkpoint_id: String) -> String:
	match checkpoint_id:
		# ⚠ ONE ON THE BEACH, NOT TWO. CP1 was an area at x 640 and CP2, written when the
		# crossing is chosen, plants its mark at the same 640 -- two checkpoints in one place
		# a few seconds apart (Kent: "why is there two checkpoints in the first part of level
		# 3, i think that is unnecessary"). Nothing on the beach can be lost before the choice,
		# so the choice's is the one kept.
		"CP2":
			return "the beach"
		"CP3":
			return "the edge of its waters"
		"CP3b":
			return "the middle of its waters"
		"CP4":
			return "the island"
	return super._checkpoint_place(checkpoint_id)


# --- Per frame --------------------------------------------------------------------------

## THE STORM ENDS WITH THE ENCOUNTER, whichever of the three resolutions ended it. The level
## darkens into the bakunawa on the way there; with it followed, evaded or subdued, the last
## stretch and the island are in daylight -- which is also the light the farewell is in.
func _keep_the_weather() -> void:
	var calm := director != null and director.is_solved("L3_N2")
	if calm == _sky_is_clear:
		return
	_sky_is_clear = calm
	var environment_node := get_node_or_null(^"EnvironmentBaseplate")
	if environment_node == null:
		return
	for band in environment_node.get_children():
		if not band.has_method("clear_the_sky"):
			continue
		if calm:
			band.call("clear_the_sky", 6.0)
		else:
			band.call("restore_the_storm")


## ⚠ UNDER THE WATER THE CAMERA LOOKS DOWN, NOT UP. The level frames the player the way a land
## level does -- 180 above them, so there is sky over their head -- and on the beach and in the
## boat that is right. A swimmer at mid-depth, framed that way, had the seabed, the jars, the clam
## and most of the bakunawa below the bottom of the screen: the stealth rule is "stay out of the
## light", and the light was mostly off it. Played, not reasoned: a first-time sneak was caught by
## a sweep it could not see.
##
## ⚠ FAR ENOUGH DOWN TO HAVE THE BED IN VIEW, NEVER SO FAR THE PLAYER LEAVES THE TOP. A fixed
## look below the player was the first answer and it was not enough: a swimmer rides at about
## 1150, five hundred and sixty above the bed, and sixty below them still left the jars cut off
## by the bottom of the screen. So the camera looks down as far as it takes to put the bed 370
## below its centre -- most of the way down the screen, the creature and its sweep above it -- but
## no further than 240 below the player, which keeps them clear of the objective line. It eases
## in over the first 300 px of depth, from the land framing at the surface.
const SURFACE_LOOK := -180.0
const LOOK_EASE_DEPTH := 300.0
const BED_IN_VIEW := 370.0
const MOST_LOOK := 240.0
const LEAST_LOOK := 60.0


func _frame_the_water(anchor_position: Vector2) -> void:
	var world_camera := _world_camera()
	if world_camera == null or not is_finite(_waterline_y):
		return
	var under := clampf((anchor_position.y - _waterline_y) / LOOK_EASE_DEPTH, 0.0, 1.0)
	var deep_look := clampf(BED_Y - BED_IN_VIEW - anchor_position.y, LEAST_LOOK, MOST_LOOK)
	world_camera.target_offset.y = lerpf(SURFACE_LOOK, deep_look, under)


## ⚠ THE APO ROWS. The design lists rowing with the waves, the wind and the gulls, and the
## boat crossed the whole of the Artist route with the apo standing in it, arms at their sides,
## while the hull slid over the sea on its own -- a boat being dragged, not rowed. The sheet has
## no seated or rowing pose, so the stroke is carried by a paddle in the apo's hands: forward,
## in with a splash, swept back along the hull, lifted and brought round again, for as long as
## the boat is moving; at rest across the lap when it is not.
var _paddle: Sprite2D
var _stroke := 0.0


func _row(delta: float) -> void:
	# Whichever boat: the bangka, or one the player drew.
	var boat := _boat_carrying_player()
	if boat == null:
		if _paddle != null and is_instance_valid(_paddle):
			_paddle.queue_free()
		_paddle = null
		return
	if _paddle == null or not is_instance_valid(_paddle) or _paddle.get_parent() != player:
		_paddle = Sprite2D.new()
		_paddle.name = "Paddle"
		_paddle.texture = PADDLE
		_paddle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_paddle.centered = false
		# The grip is the top of the texture, so the paddle turns about the upper hand.
		_paddle.offset = Vector2(-PADDLE.get_width() * 0.5, -4.0)
		_paddle.z_index = 11
		player.add_child(_paddle)
	var facing := 1.0
	if player.has_method("facing_direction"):
		facing = signf(float(player.call("facing_direction")))
		if facing == 0.0:
			facing = 1.0
	var hull := boat as RigidBody2D
	var speed := absf(hull.linear_velocity.x) if hull != null else 0.0
	var angle := 0.18
	if speed > 25.0:
		var was := _stroke
		_stroke = fmod(_stroke + delta * 0.95, 1.0)
		# In the water for three fifths of the stroke, sweeping from forward to back; lifted
		# and carried round for the rest.
		if _stroke < 0.6:
			angle = lerpf(0.55, -0.45, _stroke / 0.6)
		else:
			angle = lerpf(-0.45, 0.55, (_stroke - 0.6) / 0.4)
		if _stroke < was and _life != null:
			# A new stroke: the blade goes in, ahead of the apo on the side they are rowing to.
			_life.splash_at(player.global_position + Vector2(34.0 * facing, 0.0))
	else:
		_stroke = 0.0
	_paddle.position = Vector2(6.0 * facing, -52.0)
	_paddle.rotation = -angle * facing
	_paddle.flip_h = facing < 0.0


## ⚠ GETTING OFF ANYWHERE, NOW. The bangka used to hold its passenger out at sea, because off it
## the apo could not swim and the rescue restored a checkpoint from before the boat. The apo swims
## on a breath now and nothing in the water restores a checkpoint, and Kent: "i should be able to
## exit the boat whenever". So no boat holds anybody -- and a boat the player DREW, rowed out
## while the bangka is still on the sand, is a way across the boat route too.
func _keep_the_passenger_aboard() -> void:
	for boat in _boats():
		boat.holds_passenger = false
	var carrying := _boat_carrying_player()
	if carrying != null and director != null and carrying != _launched_boat \
			and director.committed_route("L3_N1") == "artist" and not director.is_solved("L3_N1"):
		# An item, not a submission: the boat was judged as what it is when it was drawn.
		director.solve_with_item("L3_N1", "drawn_boat")


## Every boat afloat in the level: the bangka once it is launched, and any the player drew.
func _boats() -> Array[UtilityObject]:
	var out: Array[UtilityObject] = []
	if world_item_root == null:
		return out
	for child in world_item_root.get_children():
		var boat := child as UtilityObject
		if boat != null and is_instance_valid(boat) and not boat.is_queued_for_deletion() \
				and boat.utility_behavior in ["sailboat", "submarine"]:
			out.append(boat)
	return out


## The boat the player is sitting in, or null.
func _boat_carrying_player() -> UtilityObject:
	if player == null or not is_instance_valid(player):
		return null
	for boat in _boats():
		if boat.has_passenger(player):
			return boat
	return null


## The two shores' seaward edges, from the scene rather than typed twice.
func level_data_shore_edges() -> Vector2:
	var terrain := get_node_or_null(^"EnvironmentBaseplate/GameplayPlane/Terrain")
	if terrain == null:
		return Vector2.ZERO
	var edges := Vector2.ZERO
	for pair in [["Shore", true], ["Island", false]]:
		var land := terrain.get_node_or_null(NodePath(String(pair[0]))) as Node2D
		var shape := land.get_node_or_null(^"Shape") as CollisionShape2D if land != null else null
		var box := shape.shape as RectangleShape2D if shape != null else null
		if box == null:
			return Vector2.ZERO
		if bool(pair[1]):
			edges.x = land.global_position.x + box.size.x * 0.5
		else:
			edges.y = land.global_position.x - box.size.x * 0.5
	return edges


func _level_physics(anchor_position: Vector2) -> void:
	_keep_the_weather()
	_keep_the_passenger_aboard()
	var delta := get_physics_process_delta_time()
	_row(delta)
	_frame_the_water(anchor_position)
	_pace_the_advice(delta)
	var underwater := anchor_position.y > _waterline_y
	_watch_the_bakunawa(anchor_position, delta)
	_guide_the_bakunawa(anchor_position)
	_push_the_bangka(anchor_position, delta)
	_breathe(anchor_position, delta)
	_fish()
	_mind_the_creatures(anchor_position)
	# From above the water it is a shape in the dark, not a creature. Kent: "when the player is
	# still above water, the sea serpent should just be a silhouette".
	if _bakunawa != null and is_instance_valid(_bakunawa):
		_bakunawa.set_silhouette(anchor_position.y < _waterline_y + AIR_DEPTH)
	_tell_the_crossing(anchor_position)
	_climb_out_at_home(anchor_position)

	if underwater and not _said_underwater:
		_said_underwater = true
		if tutorial != null:
			tutorial.note("underwater")
	if underwater and not _said_the_jars:
		_point_out_the_jars(anchor_position)

	# ⚠ THE DRAIN ONLY RUNS WHILE A FORM IS HELD, and `_current_form_id` is the only thing
	# that knows. Charging on "the player is not a Wanderer" would keep charging through the
	# frame a rig fails to build, which is the one frame the player has no body at all.
	if _drain == null or not PlayerProfile.has_new_brush():
		return
	if _current_form_id.is_empty():
		if _drain.is_draining():
			_drain.clear()
	else:
		if _drain.form_id() != _current_form_id:
			_drain.begin(_current_form_id)
			_drain_lesson_clock = 0.0
			if tutorial != null:
				tutorial.note("ink_draining")
			# THE RULE, FELT. Said once, on the first shape held after the brush -- the swimmer
			# that goes under, or the helper that drags the bangka down. It was the practice's
			# answer on the sand; there is no practice now, so it belongs to whichever drawing
			# the player makes first.
			_speak_on_arrival("INK.first_drain")
		else:
			# ⚠ SAID AGAIN WHILE IT GOES ON, NOT ONLY WHEN IT STARTS. Two lessons hang on this
			# event -- the drain, then how to stop it -- and the director teaches one per call.
			# Noted only when a form BEGAN, the second waited for the next drawing, which on this
			# shore is the dive: how to stop the drain arrived after the player needed it.
			_drain_lesson_clock += delta
			if _drain_lesson_clock >= DRAIN_LESSON_EVERY and tutorial != null:
				_drain_lesson_clock = 0.0
				tutorial.note("ink_draining")
		_drain.charge(delta)
		if morph_card != null:
			morph_card.set_meter_caption("INK")
			morph_card.set_drain(ink_manager.remaining(), ink_manager.capacity)
		# The medium rule, asked once per frame the way the ceiling is. It owns its own
		# clock, so a creature that leaves the water gets its whole beat back next time.
		_restrictions.check_medium(_current_form_id, underwater, delta)


## ⚠ BACK ONTO THE HOME SAND, FROM THE WATER. Kent: "i cant swim back at the sand". The home
## shore's seaward edge is a sheer face with the sand a body's height above the water, and a
## swimmer pushing at it stopped there for good -- recorded at x 1023, the surface, holding left
## and up, going nowhere. The island has its own way out (_come_ashore, at the arrival); home had
## none. So a swimmer at the top of the water by the home shore, pushing toward the sand, is
## lifted onto it: a shape that can walk on land stays itself, and one that cannot (a pure
## swimmer, which flops) is changed back -- free, as Q is -- with the apo stood on the sand.
const ASHORE_REACH := 70.0
var _land_walkers: Dictionary = {}


func _climb_out_at_home(anchor_position: Vector2) -> void:
	if not Input.is_action_pressed(&"move_left"):
		return
	# The apo, swimming on a breath, climbs out the same way: at the top of the water by the
	# home shore, pushing toward the sand.
	if _current_form_id.is_empty():
		if not (player is Wanderer) or not bool(player.call("is_in_water")):
			return
		var home := level_data_shore_edges()
		if home == Vector2.ZERO or anchor_position.x > home.x + ASHORE_REACH \
				or anchor_position.y > _waterline_y + 90.0:
			return
		var beach := _mark("BrushMark")
		player.call("apply_morph_state", {
			"position": Vector2(home.x - 70.0,
				(beach.global_position.y if beach != null else _waterline_y) - 2.0),
			"linear_velocity": Vector2.ZERO})
		return
	if player == null or not is_instance_valid(player) or not player.has_method("apply_morph_state"):
		return
	var edges := level_data_shore_edges()
	if edges == Vector2.ZERO:
		return
	if anchor_position.x > edges.x + ASHORE_REACH or anchor_position.x < edges.x - 20.0:
		return
	# The top of the water only: down the face, the way out is up first.
	if anchor_position.y > _waterline_y + 90.0 or anchor_position.y < _waterline_y - 20.0:
		return
	var sand := _mark("BrushMark")
	var ground_y := sand.global_position.y if sand != null else _waterline_y
	var onto := Vector2(edges.x - 70.0, ground_y)
	if _walks_on_land(_current_form_id):
		player.call("apply_morph_state", {"position": onto + Vector2(0.0, -30.0),
			"linear_velocity": Vector2.ZERO})
		return
	_revert_to_base_form()
	if player != null and is_instance_valid(player) and player.has_method("apply_morph_state"):
		player.call("apply_morph_state", {"position": onto + Vector2(0.0, -2.0),
			"linear_velocity": Vector2.ZERO})
	_say_why("Up you come, apo. That one cannot walk on sand.")


## Whether a class can walk once it is out of the water: everything but a swimmer's rig. Read
## off the rig profiles, the same files run_level3_audit reads, and remembered.
func _walks_on_land(entity_id: String) -> bool:
	if not _land_walkers.has(entity_id):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://config/rigs/%s.json" % entity_id))
		var rig: Dictionary = parsed as Dictionary if parsed is Dictionary else {}
		_land_walkers[entity_id] = String(rig.get("rig_type", "walker")) != "swimmer"
	return bool(_land_walkers[entity_id])


## The encounter's own frame, split out because it is the only part of this level with two
## ways to lose and both of them are per-frame questions.
func _watch_the_bakunawa(anchor_position: Vector2, delta: float) -> void:
	if _bakunawa == null or director == null:
		return
	_reset_cooldown = maxf(0.0, _reset_cooldown - delta)
	_knock_cooldown = maxf(0.0, _knock_cooldown - delta)
	if _reset_cooldown > 0.0:
		return
	var route := director.committed_route("L3_N2")

	if route == "pragmatist" and not director.is_solved("L3_N2"):
		if _bakunawa.sees(anchor_position, _carrying_a_lit_light()):
			# ⚠ WHAT TO DO, NOT ONLY WHAT HAPPENED. "It turned. Back to where you were" was
			# the whole of it, said to a player who then swam straight back into the same beam.
			_lose_the_stretch("It saw you. Wait until its light turns away, then go.")
			return
		# ⚠ AND ITS BODY IS NOT A PLACE TO SWIM THROUGH. It never was anything -- a player could
		# go straight through the coils unseen -- and the way past is meant to be UNDER it. Only
		# in the water: from the boat it lies under the keel, and the hull rides over its back.
		if anchor_position.y > _waterline_y + AIR_DEPTH and _bakunawa.touches(anchor_position):
			_lose_the_stretch("You brushed it, apo. Keep low — there is room under it, along the bottom.")
			return
		# Past the far end of the arena, in the dark, with nothing drawn at it.
		if anchor_position.x > _bakunawa.global_position.x + 420.0:
			director.solve_with_item("L3_N2", "the dark")
		return

	if _bakunawa.state() != BakunawaClass.State.FIGHTING or _knock_cooldown > 0.0:
		return
	# ⚠ CONTACT COSTS A STRIKE, AND THERE IS NO HEALTH BAR. The game has no death state and
	# this is not where one arrives: three contacts put the player back at CP3b with the
	# fight fresh, which is the design's "losing restarts the fight".
	if anchor_position.distance_to(_bakunawa.global_position) < BakunawaClass.BODY_DEPTH * 1.6:
		_knocks += 1
		_knock_cooldown = 1.1
		if _knocks >= 3:
			_lose_the_stretch("It threw you off. Again, apo.")
		else:
			_say_why("Mind yourself.")


## A lit flashlight makes the player a lamp. The design asks for this to be ALLOWED rather
## than prevented: drawing the light and then choosing to sneak is a harder encounter the
## player chose for themselves.
func _carrying_a_lit_light() -> bool:
	if _equipped_utility == null or not is_instance_valid(_equipped_utility):
		return false
	if _equipped_utility.utility_behavior != "flashlight":
		return false
	return not _equipped_utility.has_method("is_active") \
		or bool(_equipped_utility.call("is_active"))


# --- What happens when a rule bites -----------------------------------------------------

## A land creature has floundered for its beat. Revert through the SAME door Q uses -- never
## a second copy of it, which is a second chance to strand the player in a body that is gone.
## Floundering only happens below the waterline, so the apo it leaves is in the sea -- where they
## swim now, on a full breath (see _breathe), instead of being taken back to a checkpoint.
func _on_floundered(_entity_id: String, note: String) -> void:
	_say_why(note)
	_revert_to_base_form()
	_air = AIR_SECONDS


func _on_low_ink(_remaining: float, _capacity: float) -> void:
	if tutorial != null:
		tutorial.note("ink_low")
	_say_why("It is nearly gone, apo.")


## THE ZERO CASE. Revert, lose the stretch, never die. There is no death state anywhere in this
## game and none is being added here.
func _on_drain_emptied() -> void:
	if tutorial != null:
		tutorial.note("ink_emptied")
	_say_why("Out of ink, apo. Hold on to me.")
	_revert_to_base_form()
	# On the sand -- a helper dragging the bangka down, say -- changing back is all there is to
	# it. In the sea, the apo swims for it with the ink handed back.
	if _anchor_now().y > _waterline_y + 20.0:
		_taken_back_from_the_deep.call_deferred()


## ⚠ NO CHECKPOINT IN THE WATER (2026-10-05). The ink running out under a drawn body used to
## restore the last checkpoint -- the design's "lose the crossing, never die" -- and a restore rolls
## the whole run back with it. Kent: "when i fall off the boat it resets me to the previous
## checkpoint but also resets the bakunawa as well even after i sent it home. the return to last
## checkpoint should not work here if it is underwater."
##
## So nothing is rolled back. The apo is where the body was, on a full breath, and swims (see
## _breathe). What the restore did that still has to be done is the ink: it handed back what had
## been spent since the checkpoint, and without that the apo would be in the sea with an empty bar
## and nothing to draw a swimmer with. That part is kept -- the bar goes back to where it stood at
## the last checkpoint, and never below SHAPE_INK_FLOOR, so the next shape lasts a breath or two.
func _taken_back_from_the_deep() -> void:
	if player == null or not is_instance_valid(player) or not (player is Wanderer):
		return
	_air = AIR_SECONDS
	var latest := String(checkpoints.call("latest_id")) if checkpoints != null else ""
	var state: Dictionary = checkpoints.call("peek", latest) if not latest.is_empty() else {}
	if state.has("ink_committed"):
		ink_manager.committed = minf(ink_manager.committed, float(state["ink_committed"]))
	if ink_manager.remaining() < SHAPE_INK_FLOOR:
		ink_manager.committed = maxf(0.0, ink_manager.capacity - SHAPE_INK_FLOOR - ink_manager.reserved)
	_on_ink_changed(ink_manager.remaining(), ink_manager.capacity, ink_manager.reserved)
	_say_why("Swim for the top, apo. The brush has given back a little of what it took.")


## E AT THE BOAT. The only thing in this level that answers the interact key and is neither a
## drawing nor a signpost.
##
## ⚠ IT TAKES SOMETHING DRAWN. The bangka is beached too high for the apo and Lolo -- Kent's
## decision, so that the way over the water asks for a drawing the way the way under it does
## (see level_03.json L3_N1). A Carry shape held at the hull drags it down; the apo alone is
## told why it will not move, and E is spent on saying so rather than on the nearest sign.
func _interact_with_level() -> bool:
	if not _at_the_beached_bangka():
		return false
	if not _a_helper_is_held():
		if _holding_the_anvil():
			_say_why("Drop it behind the bangka, apo — %s. The weight will shove it." % \
				ControlsKeys.keys_for("use_utility"))
			return true
		_say_why("It will not move for the two of us, apo. Draw something strong enough to drag it down, or heavy enough to shove it.")
		return true
	_drag_the_bangka_in()
	return true


## E over the hull says what it will do: dig it out and drag it down with a helper held, and push
## without one -- which is what the apo would try, and E then says why it will not go.
func _level_interact_offer() -> Dictionary:
	if not _at_the_beached_bangka():
		return {}
	if not _a_helper_is_held():
		return {"name": "Bangka", "verb": "PUSH"}
	return {"name": "Bangka", "verb": "DRAG IN" if _bangka_dug else "DIG OUT"}


## The anvil in the apo's hand.
func _holding_the_anvil() -> bool:
	return _equipped_utility != null and is_instance_valid(_equipped_utility) \
		and _equipped_utility.item_data != null \
		and _equipped_utility.item_data.entity_id == "anvil"


## ⚠ THE BOAT ROUTE'S FIRST STEP, ANSWERED BY WHATEVER MOVES THE BOAT FIRST -- quietly, the way
## the drag always was: a helper is judged when it is drawn, but only against the beat the player
## is standing in, and an anvil is judged when it is used. Either way the beat is entered and the
## class noted once, so the per-class figures see exactly one drawing for it.
func _judge_the_mover(entity_id: String) -> void:
	if director == null or director.stage("L3_N1") > 0:
		return
	director.enter_obstacle("L3_N1")
	director.note_submission(entity_id)
	_refresh_requirements()


## Dug out: the keel comes up out of the sand, the heap over it goes, and sand flies. Once.
func _dig_out_the_bangka() -> void:
	if _bangka_dug or _bangka == null or not is_instance_valid(_bangka):
		return
	_bangka_dug = true
	var hull := _bangka.get_node_or_null(^"Hull") as Node2D
	if hull != null:
		var lift := hull.create_tween()
		lift.tween_property(hull, "position:y", -31.0, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _sand_heap != null and is_instance_valid(_sand_heap):
		var go := _sand_heap.create_tween()
		go.tween_property(_sand_heap, "modulate:a", 0.0, 0.35)
		go.tween_callback(_sand_heap.hide)
	if _life != null:
		for step in range(3):
			_life.sparkle(_bangka.global_position + Vector2(-60.0 + 60.0 * step, 4.0), 4, 22.0)
	_speak(script_lines.fire("L3_N1.artist.dug"))


## The hull moved `by` toward the sea, sand thrown up behind it. True when that took it to the
## water's edge, which is where it goes in.
func _move_the_bangka(to_x: float) -> bool:
	if _bangka == null or not is_instance_valid(_bangka):
		return false
	var edges := level_data_shore_edges()
	var stop := (edges.x if edges != Vector2.ZERO else to_x + 1.0) - 110.0
	_bangka.global_position.x = minf(to_x, stop)
	_bangka_x = _bangka.global_position.x
	return _bangka.global_position.x >= stop - 0.5


## ⚠ PUSHED, BY SOMETHING THAT CAN. A Carry shape on the landward side of the hull, walking toward
## the water, keeps it just ahead of itself -- the hull has no collision on the sand, so this IS the
## push: the shape walks, and the boat goes where the shape is about to be. Dug out first, if it was
## not: walking into a half-buried hull digs it.
func _push_the_bangka(anchor_position: Vector2, _delta: float) -> void:
	if _bangka == null or not is_instance_valid(_bangka) or _bangka_found or _sliding:
		return
	if director == null or director.committed_route("L3_N1") != "artist" \
			or director.is_solved("L3_N1") or not _a_helper_is_held():
		return
	var hull_x := _bangka.global_position.x
	if absf(anchor_position.y - _bangka.global_position.y) > 180.0:
		return
	if anchor_position.x > hull_x - 30.0 or anchor_position.x < hull_x - PUSH_LEAD - 140.0:
		return
	if not Input.is_action_pressed(&"move_right"):
		return
	_judge_the_mover(_current_form_id)
	if not _bangka_dug:
		_dig_out_the_bangka()
		return
	var lead := anchor_position.x + PUSH_LEAD
	if lead <= hull_x:
		return
	if _life != null and int(lead / 40.0) != int(hull_x / 40.0):
		_life.sparkle(_bangka.global_position + Vector2(-90.0, 4.0), 2, 14.0)
	if _move_the_bangka(lead):
		_send_the_bangka_in()


## ⚠ THE ANVIL SHOVES IT -- AND STAYS IN THE HAND. Dropped behind the hull, the weight knocks it a
## good way down the sand: the first drop digs it out and starts it, a few more see it into the
## water. F again is the next drop.
##
## ⚠ NOT A REAL ANVIL ON THE SAND. It used to leave the hand as a body -- the tool's own F, a drop
## from above the apo -- and land on the apo: Kent, "when i use the anchor its just stuck there and i
## cant move". A forty-kilo body resting on a character pins it, and a second drop stacked a second
## one. What falls now is the drawing of it, onto the stern, and the anvil stays where tools stay:
## in the hand, in the bag, its ink already paid.
func _shove_with_the_anvil() -> void:
	_judge_the_mover("anvil")
	var hull := _bangka
	if hull == null or not is_instance_valid(hull) or _sliding:
		return
	var stern := hull.global_position + Vector2(-95.0, -10.0)
	var weight := Sprite2D.new()
	weight.name = "DroppedAnvil"
	var item := _equipped_utility.item_data if _equipped_utility != null else null
	weight.texture = SkinClass.thumbnail(item.image) if item != null and item.image != null else null
	if weight.texture != null:
		weight.scale = Vector2.ONE * (70.0 / maxf(1.0, float(weight.texture.get_width())))
	weight.z_index = 9
	hull.get_parent().add_child(weight)
	weight.global_position = stern + Vector2(0.0, -260.0)
	_sliding = true
	var fall := weight.create_tween()
	fall.tween_property(weight, "global_position:y", stern.y - 20.0, 0.24) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_callback(func() -> void:
		if _life != null:
			_life.sparkle(stern, 6, 30.0)
		var world_camera := _world_camera()
		if world_camera != null and world_camera.has_method("shake"):
			world_camera.call("shake", 6.0, 0.25)
		if not is_instance_valid(hull) or _bangka_found:
			_sliding = false
			return
		if not _bangka_dug:
			_dig_out_the_bangka()
		var from_x := hull.global_position.x
		var arrives := _move_the_bangka(from_x + ANVIL_SHOVE)
		var to_x := hull.global_position.x
		hull.global_position.x = from_x
		var slide := hull.create_tween()
		slide.tween_property(hull, "global_position:x", to_x, 0.6) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		slide.tween_callback(func() -> void:
			_sliding = false
			if arrives:
				_send_the_bangka_in()))
	fall.tween_property(weight, "modulate:a", 0.0, 0.35)
	fall.tween_callback(weight.queue_free)
	_anvil_lines += 1
	if _anvil_lines == 1:
		_speak(script_lines.fire("L3_N1.artist.shove"))


var _sliding := false


## How close to the hull E reaches it. Measured from the player's anchor, which for a drawn
## body is its middle -- an elephant's middle is a good way from whatever end of it is
## touching the boat.
const BANGKA_REACH := 190.0


## Standing at the beached bangka with the boat route chosen and the bangka not yet in the
## water.
func _at_the_beached_bangka() -> bool:
	if _bangka == null or not is_instance_valid(_bangka) or _bangka_found or _sliding:
		return false
	if director == null or director.is_solved("L3_N1"):
		return false
	# ⚠ ONLY ONCE THE ROUTE IS TAKEN. Using the boat before the fork has been answered would
	# commit the player to a crossing they were never offered, and R6 is explicit that
	# answering the dialogue is not the answer -- but the reverse holds too: the world must
	# not answer a question the player has not been asked.
	if director.committed_route("L3_N1") != "artist":
		return false
	if player == null or not is_instance_valid(player):
		return false
	return _anchor_now().distance_to(_bangka.global_position) <= BANGKA_REACH


## The body the player is in can drag the bangka: one of the Carry shapes the route accepts.
## Read off the route itself, so the level file is the one list.
func _a_helper_is_held() -> bool:
	return not _current_form_id.is_empty() and _helpers().has(_current_form_id)


func _helpers() -> PackedStringArray:
	if director == null:
		return PackedStringArray()
	var spec: Dictionary = (director.obstacle("L3_N1").get("routes", {}) as Dictionary) \
		.get("artist", {})
	return AbilityTags.resolve(spec.get("required_tags", []),
		String(spec.get("match", "all")), spec.get("exclude", []))


## THE HELPER'S ONE JOB, ALL AT ONCE. E with a helper held digs the hull out if it is still
## buried and drags it the whole way down the sand and into the sea, and the shape that dragged it
## goes back into the ink as it goes -- its strength went into the boat, and the apo is left on the
## sand to get in. Changing back is free; the drain stops with it. (Walking it down is the other
## way -- see _push_the_bangka -- and the anvil a third, _shove_with_the_anvil.)
##
## ⚠ JUDGED FIRST, IF IT NEVER WAS. A helper is judged when it is drawn, but only against the
## beat the player is standing in -- drawn a step west of the crossing's volume it was judged
## against nothing, and the boat would then be launched by a drawing the per-class figures
## never saw. Judged here as well, quietly, and the bangka itself is closed as an item.
func _drag_the_bangka_in() -> void:
	_judge_the_mover(_current_form_id)
	if not _bangka_dug:
		_dig_out_the_bangka()
	var hull := _bangka
	var stood := _anchor_now()
	_revert_to_base_form()
	# ⚠ ON THE SAND, NOT WHERE THE HELPER'S MIDDLE WAS. A changed-back apo lands at the old
	# body's anchor, and a four-legged body carries its anchor well above the beach -- recorded at
	# 180 px for a drawn horse, which dropped the apo out of the sky with the camera chasing them
	# while the boat went in. The beach's surface is the brush's mark.
	var sand := _mark("BrushMark")
	if sand != null and player != null and is_instance_valid(player) \
			and player.has_method("apply_morph_state"):
		player.call("apply_morph_state", {
			"position": Vector2(stood.x, sand.global_position.y - 2.0),
			"linear_velocity": Vector2.ZERO})
	_say_why("Hup! Down she goes.")
	var from_x := hull.global_position.x
	_move_the_bangka(INF)
	var to_x := hull.global_position.x
	hull.global_position.x = from_x
	_sliding = true
	# Behind the apo as it passes: it is on the sand, and the apo is standing on it too.
	hull.z_index = 6
	var slide := hull.create_tween()
	slide.tween_interval(0.35)
	slide.tween_property(hull, "global_position:x", to_x,
		maxf(0.6, (to_x - from_x) / DRAG_SPEED)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	slide.tween_callback(func() -> void:
		_sliding = false
		_send_the_bangka_in())
	# Sand thrown up behind it on the way.
	if _life != null:
		var seconds := maxf(0.6, (to_x - from_x) / DRAG_SPEED)
		for step in range(int(seconds / 0.22) + 1):
			get_tree().create_timer(0.4 + 0.22 * float(step)).timeout.connect(func() -> void:
				if is_instance_valid(hull) and _life != null:
					_life.sparkle(hull.global_position + Vector2(-50.0, 6.0), 3, 18.0))


## At the water's edge: over the lip and in, nose first, and the real boat put afloat. Every way of
## moving it ends here, once. A helper still held is changed back -- the boat is in, and the apo
## gets in it.
func _send_the_bangka_in() -> void:
	if _bangka_found or _bangka == null or not is_instance_valid(_bangka):
		return
	_bangka_found = true
	_judge_the_mover(_current_form_id if not _current_form_id.is_empty() else "anvil")
	if _a_helper_is_held():
		var stood := _anchor_now()
		_revert_to_base_form()
		var sand := _mark("BrushMark")
		if sand != null and player != null and is_instance_valid(player) \
				and player.has_method("apply_morph_state"):
			player.call("apply_morph_state", {
				"position": Vector2(minf(stood.x, level_data_shore_edges().x - 60.0),
					sand.global_position.y - 2.0),
				"linear_velocity": Vector2.ZERO})
	var hull := _bangka
	var edges := level_data_shore_edges()
	var edge_x := edges.x if edges != Vector2.ZERO else hull.global_position.x + 160.0
	var slide := hull.create_tween()
	slide.tween_property(hull, "global_position", Vector2(edge_x + 70.0,
		hull.global_position.y + 30.0), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	slide.parallel().tween_property(hull, "rotation", 0.22, 0.32)
	slide.parallel().tween_property(hull, "modulate:a", 0.0, 0.32)
	slide.tween_callback(func() -> void:
		if _life != null:
			_life.splash_at(Vector2(edge_x + 70.0, _waterline_y))
		if is_instance_valid(hull):
			hull.queue_free()
		_launch_the_bangka()
		if director != null and not director.is_solved("L3_N1"):
			director.solve_with_item("L3_N1", "bangka"))


## ⚠ solve_with_item, NEVER note_submission. A beat answered by something other than a
## drawing must not go through the recogniser's path, or a class nobody drew enters the
## per-class precision and recall figures the thesis reports.
func _launch_the_bangka() -> void:
	var mark := _mark("WaterlineMark")
	if mark == null or registry == null:
		return
	var boat := registry.instantiate_entity("sailboat") as UtilityObject
	if boat == null:
		return
	# ⚠ WorldItemRoot, NOT EntityRoot. _nearest_interactable_utility skips everything whose
	# parent is not world_item_root -- that is how a tool held in the hand keeps its
	# placed_drawings group without offering E -- so a boat parented anywhere else floats
	# correctly, looks right, and cannot be boarded. EntityRoot is where the player's own
	# body goes.
	world_item_root.add_child(boat)
	# ⚠ AND TOLD HOW BIG THE WORLD IS, the way a placed drawing is. A body clamps itself to
	# the world it was built with, and a boat that never went through placement kept the
	# script's own 3760px default -- so it was stopped dead at x 3940, five hundred pixels
	# short of the island the whole route exists to reach. Connected like a placed drawing
	# too, so what it reports reaches the level.
	boat.set_world_bounds(Rect2(environment.get("world_bounds")))
	_connect_utility(boat)
	_launched_boat = boat
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	boat.apply_item_data(DrawnItemData.from_prediction(
		"sailboat", "Bangka", sheet, [{
			"points": PackedVector2Array([
				Vector2(0, 0), Vector2(120, 0), Vector2(100, 40), Vector2(20, 40), Vector2(0, 0)]),
			"width": 6.0, "color": Color.BLACK,
		}], 0.0, registry.get_entity("sailboat")))
	# Afloat, just past the waterline, where the player is standing when they find it -- and
	# clear of the land. At +120 the hull's back half was inside the shore, which now runs
	# down to the seabed, and it launched perched on the corner of the beach.
	boat.global_position = Vector2(mark.global_position.x + 170.0, mark.global_position.y + 10.0)
	boat.confirm_placement()
	_dress_the_bangka(boat)
	# What is said about it is the crossing's own solved line -- "There she goes. Somebody left
	# that and never came back for it" -- which fires as it is closed.


## ⚠ THE ONE OBJECT IN THE GAME THAT IS FOUND RATHER THAN DRAWN, and therefore the one that
## cannot get its picture from the player's ink. Everything else placed in the world is built
## out of the strokes somebody made on the canvas; this boat has none, so it wore the engine's
## bare outline -- a white wireframe trapezium -- for the whole of the crossing the Artist
## route is named after.
##
## ⚠ THE OUTLINE IS STILL WHAT THE HULL IS. The strokes handed to apply_item_data build the
## collision, the draft, the buoyancy and the seat that run_level3_boat_probe measured; this
## only turns the ink off and hangs the picture where the ink was, so the boat looks different
## and behaves identically. Anything that changed the shape would have to be re-measured.
func _dress_the_bangka(boat: Node2D) -> void:
	var picture := load(AUTHORED + "bangka_afloat.png") as Texture2D
	if picture == null:
		return
	# ⚠ THE INK IS NOT UNDER `DrawingSkin`. For rig_type "none" RuntimeRig2D hangs its
	# `SkinRoot` -- the Line2D per stroke, and the white halo under each -- off the PRIMARY
	# BODY, which for a physics object is the RigidBody2D itself. Hiding the skin node left
	# the outline drawn straight over the picture. Both go, and they go on every call rather
	# than only the first, because a restore that re-launches the boat rebuilds them.
	for node_name in ["SkinRoot", "DrawingSkin"]:
		var ink := boat.find_child(node_name, true, false) as CanvasItem
		if ink != null:
			ink.visible = false
	if boat.has_node(^"PaintedBangka"):
		return
	var art := Sprite2D.new()
	art.name = "PaintedBangka"
	art.texture = picture
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Pinned by the hull's waterline in the picture, not by the sprite's middle: the canvas
	# carries sixty pixels of mast over a hull sixty-five deep, so centred on the body the
	# boat rode a third of a hull under the sea. The waterline is row 90 of 132 (see
	# BANGKA_WATERLINE), and the body floats HULL_DRAFT under the surface.
	art.position = Vector2(0.0, -24.0 - UtilityObject.HULL_DRAFT)
	boat.add_child(art)


# --- The apo in the water ------------------------------------------------------------------

## ⚠ THE APO SWIMS HERE, ON A BREATH. Kent (2026-10-05): "the player can dive underwater without
## resetting if they still have 'air' (maybe 5-8 seconds) left. if not, then they are pushed to the
## surface." The base's "you cannot swim" rescue is off; this level keeps its own water.
func _apo_can_swim() -> bool:
	return true


## The breath, spent while the apo's head is under and given back at the top; at nothing, they are
## carried up -- not reset. And out past APO_SWIM_REACH a current turns them back: the crossing is
## a drawing's to make, and an apo who could swim it would have no reason to draw anything.
func _breathe(anchor_position: Vector2, delta: float) -> void:
	var apo := player as Wanderer
	if apo == null or not is_instance_valid(apo):
		_air = AIR_SECONDS
		if _air_meter != null and is_instance_valid(_air_meter):
			_air_meter.visible = false
		return
	apo.can_swim = true
	var wet := bool(apo.call("is_in_water"))
	var under := wet and anchor_position.y > _waterline_y + AIR_DEPTH
	if apo.surfacing and (not wet or anchor_position.y <= _waterline_y + 12.0):
		apo.surfacing = false
	if under and not apo.surfacing:
		_air = maxf(0.0, _air - delta)
		if _air <= 0.0:
			apo.surfacing = true
			_say_why("Out of breath — up you come, apo!")
	elif not under:
		_air = minf(AIR_SECONDS, _air + AIR_REFILL * delta)
	# THE CURRENT, past where the apo may swim: it holds them -- swimming further out goes nowhere --
	# but it does not carry them off and it never takes them back to a checkpoint (Kent: "the return
	# to last checkpoint should not work here if it is underwater"). Toward the nearer shore they
	# swim freely, and near a boat freely every way: stepping off the bangka out at sea is allowed
	# now (Kent: "i should be able to exit the boat whenever"), and getting back in has to be.
	var out := _distance_out(anchor_position)
	# In the sea, not only wet: floating at the top the apo bobs clear of the water for a frame at
	# a time, and that is still the open sea.
	wet = wet or (out > 0.0 and anchor_position.y > _waterline_y - 40.0)
	if wet and out > APO_SWIM_REACH and not _near_a_boat(anchor_position):
		var edges := level_data_shore_edges()
		var homeward := -1.0 if anchor_position.x - edges.x < edges.y - anchor_position.x else 1.0
		if apo.velocity.x * homeward < 0.0:
			# Held, not shoved: the way out is simply closed. Bobbing clear of the water the apo is
			# on the walk's acceleration for a frame, which a force alone let them creep out on.
			apo.velocity.x = 0.0
			apo.apply_external_force(Vector2(homeward * 1500.0, 0.0))
		if not _told_the_current:
			_told_the_current = true
			_say_why("The current is too strong out there, apo. Draw yourself something that can swim.")
	_show_the_breath(anchor_position, under or _air < AIR_SECONDS - 0.05)


## How near a boat the apo swims as freely as by the shore.
const BOAT_REACH := 450.0


func _near_a_boat(at: Vector2) -> bool:
	for boat in _boats():
		if boat.global_position.distance_to(at) <= BOAT_REACH:
			return true
	return false


## How far out into the sea from the nearer shore's edge.
func _distance_out(at: Vector2) -> float:
	var edges := level_data_shore_edges()
	if edges == Vector2.ZERO:
		return 0.0
	return minf(at.x - edges.x, edges.y - at.x)


func _show_the_breath(anchor_position: Vector2, showing: bool) -> void:
	if _air_meter == null or not is_instance_valid(_air_meter):
		if not showing or _marks == null:
			return
		_air_meter = _AirMeter.new()
		_air_meter.name = "AirMeter"
		_marks.get_parent().add_child(_air_meter)
	_air_meter.visible = showing
	_air_meter.global_position = anchor_position + Vector2(0.0, -96.0)
	_air_meter.ratio = _air / AIR_SECONDS
	_air_meter.queue_redraw()


## Bubbles over the apo's head, one going out at a time. Seven seconds is seven bubbles.
class _AirMeter extends Node2D:
	var ratio := 1.0

	func _ready() -> void:
		z_index = 40

	func _draw() -> void:
		var count := 7
		for index in range(count):
			var share := clampf(ratio * count - index, 0.0, 1.0)
			var at := Vector2((index - (count - 1) * 0.5) * 15.0, 0.0)
			draw_circle(at, 6.0, Color(0.02, 0.08, 0.16, 0.45))
			if share > 0.0:
				draw_circle(at, 5.0 * share, Color(0.72, 0.92, 1.0, 0.95))
				draw_circle(at + Vector2(-1.5, -1.5), 1.5 * share, Color(1, 1, 1, 0.95))
			draw_arc(at, 6.0, 0.0, TAU, 14, Color(0.8, 0.95, 1.0, 0.8), 1.0)


# --- The light that leads it home ------------------------------------------------------------

## The light's first step is done and its second -- bringing it home -- is not.
func _guiding() -> bool:
	return director != null and director.committed_route("L3_N2") == "artist" \
		and director.stage("L3_N2") > 0 and not director.is_solved("L3_N2")


## The light is up and it has turned to it. Lolo says where home is, a held flashlight comes on,
## and from here the creature goes where the light goes.
func _begin_the_guiding() -> void:
	if not _lead_told:
		_lead_told = true
		_speak(script_lines.fire("L3_N2.artist.lead"))
	if _equipped_utility != null and is_instance_valid(_equipped_utility) \
			and _equipped_utility.utility_behavior == "flashlight" \
			and not bool(_equipped_utility.call("is_active")):
		_equipped_utility.describe_use(player)
	refresh_objective()


## ⚠ THE LIGHT FOLLOWS THE MOUSE AND THE CREATURE FOLLOWS THE LIGHT. Kent: "when they are guided
## by the flash light, the flashlight should follow where my mouse is pointing and the sea serpent
## should follow it." A glow in the water where the pointer is -- within reach of the apo, and in
## the water, never in the sky or the rock -- with a flashlight in hand turned to shine on it. Near
## enough to see it, the creature swims after it; brought within reach of the cave, it goes in.
func _guide_the_bakunawa(anchor_position: Vector2) -> void:
	var leading := _guiding() and _bakunawa != null and is_instance_valid(_bakunawa) \
		and not _bakunawa.is_gone() and not _bakunawa.is_leaving()
	if not leading:
		if _lure != null and is_instance_valid(_lure):
			_lure.visible = false
		return
	if _lure == null or not is_instance_valid(_lure):
		_lure = _Lure.new()
		_lure.name = "Lure"
		_marks.get_parent().add_child(_lure)
	var target := _lure_target(anchor_position)
	_lure.global_position = target
	_lure.visible = true
	_aim_the_light(target)
	if _bakunawa.global_position.distance_to(target) <= LURE_NOTICE:
		_bakunawa.be_guided(target)
	else:
		_bakunawa.be_guided(_bakunawa.global_position)
	if _cave_mouth != Vector2.ZERO \
			and _bakunawa.global_position.distance_to(_cave_mouth) <= HOME_REACH:
		_lure.visible = false
		_bakunawa.go_home(_cave_mouth, _cave_inside)


## Where the light is: the pointer, or what a probe set, held within reach of the apo and inside
## the water.
func _lure_target(anchor_position: Vector2) -> Vector2:
	var wanted: Vector2 = lure_override if lure_override is Vector2 else get_global_mouse_position()
	var offset := wanted - anchor_position
	if offset.length() > LURE_REACH:
		offset = offset.normalized() * LURE_REACH
	var at := anchor_position + offset
	var top := (_waterline_y if is_finite(_waterline_y) else 560.0) + 110.0
	at.y = clampf(at.y, top, BED_Y - 110.0)
	return at


## A flashlight in hand shines where the light is -- turned to it, its beam drawn out to reach it.
func _aim_the_light(target: Vector2) -> void:
	if _equipped_utility == null or not is_instance_valid(_equipped_utility) \
			or _equipped_utility.utility_behavior != "flashlight":
		return
	if not bool(_equipped_utility.call("is_active")):
		_equipped_utility.describe_use(player)
	_equipped_utility.look_at(target)
	var cone := _equipped_utility.get_node_or_null(^"VisibleLightCone") as Node2D
	if cone != null:
		cone.scale.x = clampf(_equipped_utility.global_position.distance_to(target) / 230.0, 0.6, 3.0)


## The light at rest again, once it has done its work.
func _rest_the_light() -> void:
	if _equipped_utility == null or not is_instance_valid(_equipped_utility) \
			or _equipped_utility.utility_behavior != "flashlight":
		return
	_equipped_utility.rotation = 0.0
	var cone := _equipped_utility.get_node_or_null(^"VisibleLightCone") as Node2D
	if cone != null:
		cone.scale.x = 1.0


## The glow it follows: a soft light in the water, breathing.
class _Lure extends Node2D:
	var _clock := 0.0

	func _ready() -> void:
		z_index = 9
		var glow := CanvasItemMaterial.new()
		glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = glow

	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()

	func _draw() -> void:
		var swell := 1.0 + 0.12 * sin(_clock * 3.0)
		for ring in range(6):
			var radius := (70.0 - ring * 11.0) * swell
			draw_circle(Vector2.ZERO, radius, Color(1.0, 0.9, 0.55, 0.06 + ring * 0.035))
		draw_circle(Vector2.ZERO, 6.0 * swell, Color(1.0, 0.97, 0.85, 0.9))


# --- The sea's creatures, and fishing for them -------------------------------------------------
#
# Kent (2026-10-05): a fishing hook hidden in the sand, that the rake uncovers; cast from the boat
# (or the water's edge), the camera following the hook; a creature that swims into it is reeled in
# by drawing spirals, at a pace and for a length set by the creature; five catches and the hook
# breaks. Or swim with them -- and strike one, and every one but the bangus turns on the player:
# ten bites and they are sent up to the surface, five blows and a creature dies, and Lolo is sad
# about it. He talks about each of them, the first time the player swims up to one or lands one.

const SeaCreatureClass = preload("res://scripts/sea_creature_2d.gd")
const FishingLineClass = preload("res://scripts/fishing_line_2d.gd")
const HOOK_ART := preload("res://assets/Level3/creatures/fishing_hook.png")
## Kent: "after 5 sea creatures, the fish hook breaks" and "it takes 10 hits to the player before
## they are sent back up to the surface".
const HOOK_CATCHES := 5
const PLAYER_HITS := 10
## How near a creature the player swims before Lolo says what it is; how near the sand the rake
## reaches; how near a shore's edge the apo may stand to cast from it.
const MEET_REACH := 240.0
const RAKE_REACH := 170.0
const CAST_FROM_SHORE := 170.0
## Who lives where: the kind, the middle of the water it wanders, and how many. All of it west of
## the bakunawa's stretch -- the encounter is its own.
const SEA_LIFE := [
	["bangus", Vector2(2100.0, 780.0), 4], ["bangus", Vector2(3000.0, 900.0), 5],
	["bangus", Vector2(4300.0, 820.0), 4],
	["pawikan", Vector2(2700.0, 1250.0), 1], ["pawikan", Vector2(4000.0, 1200.0), 1],
	["pawikan", Vector2(5100.0, 1150.0), 1],
	["dikya", Vector2(2450.0, 1050.0), 1], ["dikya", Vector2(3550.0, 1350.0), 1],
	["dikya", Vector2(4700.0, 1000.0), 1],
	["pugita", Vector2(3150.0, 1560.0), 1], ["pugita", Vector2(4350.0, 1580.0), 1],
	["pugita", Vector2(5250.0, 1560.0), 1],
]
## What each card says the first time one is landed.
const CATCH_NOTES := {
	"bangus": "Silver and quick, and bony. The whole country's own -- and let go again.",
	"pawikan": "Protected, and old as the sea. Lifted for a look, and let go gently.",
	"dikya": "Mind the threads. Held a moment at arm's length, and let go.",
	"pugita": "Three hearts and a beak. It did not want to come up, and it is let go.",
}

var _hook_mound: Node2D
var _hook_revealed := false
var _has_hook := false
var _hook_broken := false
var _catches := 0
var _caught_kinds: Dictionary = {}
var _hook_hint_said := false
var _first_cast := true
var _line: Node2D
## THE CAST IS HELD. Kent: "if i hold the button longer, the stronger the cast is and the deeper it
## gets". Charging while the key is held, 0..1 over CHARGE_SECONDS; -1 when not charging.
var _charge := -1.0
const CHARGE_SECONDS := 1.2
var _power_meter: _PowerMeter
## For a run with no key to hold: true/false overrides the held cast and the held reel.
var hold_override: Variant = null
var _hooked: Node2D
var _creatures_hostile := false
var _hits_taken := 0
var _kills := 0
var _met_kinds: Dictionary = {}
var _health_meter: _HealthMeter


## THE HOOK, in the sand of the first beach, under a heap of it that glints now and then.
func _plant_the_hook() -> void:
	var mark := _mark("HookMark")
	if mark == null:
		return
	var mound := Node2D.new()
	mound.name = "HookMound"
	mound.z_index = 6
	mark.get_parent().add_child(mound)
	mound.global_position = mark.global_position
	var hook := Sprite2D.new()
	hook.name = "Hook"
	hook.texture = HOOK_ART
	hook.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hook.scale = Vector2.ONE * 2.0
	hook.rotation = 0.8
	hook.position = Vector2(0.0, -14.0)
	mound.add_child(hook)
	var sand := Sprite2D.new()
	sand.name = "Sand"
	sand.texture = load(AUTHORED + "sand_mound.png") as Texture2D
	sand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sand.scale = Vector2(0.8, 1.1)
	sand.position = Vector2(0.0, -6.0)
	sand.z_index = 1
	mound.add_child(sand)
	var pickup := Area2D.new()
	pickup.name = "Pickup"
	pickup.collision_layer = 0
	pickup.collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 50.0
	shape.shape = circle
	pickup.add_child(shape)
	mound.add_child(pickup)
	pickup.body_entered.connect(_on_hook_touched)
	var glint := Timer.new()
	glint.wait_time = 3.1
	glint.autostart = true
	mound.add_child(glint)
	glint.timeout.connect(func() -> void:
		if _life != null and is_instance_valid(_life) and not _has_hook:
			_life.sparkle(mound.global_position + Vector2(8.0, -16.0), 2, 14.0))
	_hook_mound = mound
	_show_the_hook_mound()


## The heap and the hook as the run says they are.
func _show_the_hook_mound() -> void:
	if _hook_mound == null or not is_instance_valid(_hook_mound):
		return
	var sand := _hook_mound.get_node_or_null(^"Sand") as CanvasItem
	var hook := _hook_mound.get_node_or_null(^"Hook") as CanvasItem
	if sand != null:
		sand.visible = not _hook_revealed
		sand.modulate.a = 1.0
	if hook != null:
		hook.visible = _hook_revealed and not _has_hook


func _at_the_hook_mound() -> bool:
	return _hook_mound != null and is_instance_valid(_hook_mound) and not _hook_revealed \
		and _anchor_now().distance_to(_hook_mound.global_position) <= RAKE_REACH


## The rake combs the sand away and the hook is there.
func _clear_the_sand() -> void:
	_hook_revealed = true
	var sand := _hook_mound.get_node_or_null(^"Sand") as CanvasItem
	if sand != null:
		var go := sand.create_tween()
		go.tween_property(sand, "modulate:a", 0.0, 0.4)
		go.tween_callback(sand.hide)
	var hook := _hook_mound.get_node_or_null(^"Hook") as CanvasItem
	if hook != null:
		hook.visible = true
	if _life != null:
		_life.sparkle(_hook_mound.global_position + Vector2(0.0, -14.0), 6, 26.0)
	_speak(script_lines.fire("HOOK.uncovered"))


func _on_hook_touched(body: Node) -> void:
	if not _hook_revealed or _has_hook or not _is_the_player(body):
		return
	_has_hook = true
	_show_the_hook_mound()
	announce_acquisition("Fishing Hook",
		"Found under the sand. Cast it with F from a boat or the water's edge, and work the line up and down. It will hold for five catches.",
		HOOK_ART)
	_speak(script_lines.fire("HOOK.found"))


## Where the hook can be cast from: a boat, or the apo standing at the water's edge.
func _at_a_fishing_spot() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if _boat_carrying_player() != null:
		return true
	if not (player is Wanderer) or bool(player.call("is_in_water")):
		return false
	var at := _anchor_now()
	var edges := level_data_shore_edges()
	if edges == Vector2.ZERO or at.y > _waterline_y + 4.0:
		return false
	return absf(at.x - edges.x) <= CAST_FROM_SHORE or absf(at.x - edges.y) <= CAST_FROM_SHORE


func _can_cast() -> bool:
	if not _has_hook or _hook_broken or _line != null or _level_completed:
		return false
	if _equipped_utility != null and is_instance_valid(_equipped_utility):
		return false
	return _at_a_fishing_spot()


func _rod_tip() -> Vector2:
	var facing := 1.0
	if player != null and is_instance_valid(player) and player.has_method("facing_direction"):
		facing = signf(float(player.call("facing_direction")))
		if facing == 0.0:
			facing = 1.0
	return _anchor_now() + Vector2(26.0 * facing, -44.0)


## Out it goes, toward the pointer -- and out over the water, never back at the sand -- as hard
## and as deep as it was held for.
func _cast(toward: Variant = null, power: float = 0.6) -> void:
	var tip := _rod_tip()
	var aim: Vector2
	if toward is Vector2:
		aim = toward
	elif lure_override is Vector2:
		aim = lure_override
	else:
		aim = get_global_mouse_position()
	var edges := level_data_shore_edges()
	var seaward := 1.0 if edges == Vector2.ZERO or absf(tip.x - edges.x) < absf(tip.x - edges.y) else -1.0
	if _boat_carrying_player() == null and signf(aim.x - tip.x) != seaward:
		aim.x = tip.x + 320.0 * seaward
	_line = FishingLineClass.new()
	_line.name = "FishingLine"
	_line.rod_tip = _rod_tip
	_line.reeling = _holding_the_key
	_line.waterline = _waterline_y if is_finite(_waterline_y) else 560.0
	_line.floor_y = BED_Y
	_marks.get_parent().add_child(_line)
	_line.cast(tip, aim, power)
	_line.splashed.connect(func(at: Vector2) -> void:
		if _life != null:
			_life.splash_at(at))
	_line.reeled_in.connect(_put_the_line_away)
	_line.landed.connect(_on_landed)
	_line.escaped.connect(_on_escaped)
	# The camera goes with the hook.
	var world_camera := _world_camera()
	if world_camera != null:
		world_camera.focus_on(_line.hook, 1.0, 0.4, 0.0)
	if _first_cast:
		_first_cast = false
		_speak(script_lines.fire("HOOK.cast"))
	_say_why("Up and down to work the line. Hold %s to wind it in." % ControlsKeys.keys_for("use_utility"))


## The use key, held -- or what a probe says it is.
func _holding_the_key() -> bool:
	if hold_override is bool:
		return hold_override
	return Input.is_action_pressed(&"use_utility")


func _begin_charge() -> void:
	_charge = 0.0


## Let go: the cast, at whatever it had charged to.
func _release_charge() -> void:
	if _charge < 0.0:
		return
	var power := _charge
	_charge = -1.0
	_show_the_power(Vector2.ZERO, false)
	if _can_cast():
		_cast(null, power)


func _show_the_power(anchor_position: Vector2, showing: bool) -> void:
	if _power_meter == null or not is_instance_valid(_power_meter):
		if not showing or _marks == null:
			return
		_power_meter = _PowerMeter.new()
		_power_meter.name = "PowerMeter"
		_marks.get_parent().add_child(_power_meter)
	_power_meter.visible = showing
	if showing:
		_power_meter.global_position = anchor_position + Vector2(0.0, -110.0)
		_power_meter.power = maxf(0.0, _charge)
		_power_meter.queue_redraw()


## How hard the cast will be, over the apo's head while it is held.
class _PowerMeter extends Node2D:
	var power := 0.0

	func _ready() -> void:
		z_index = 40

	func _draw() -> void:
		var bar := Rect2(Vector2(-46.0, -6.0), Vector2(92.0, 12.0))
		draw_rect(bar.grow(3.0), Color(0.02, 0.04, 0.08, 0.85))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * power, bar.size.y)),
			Color(0.5, 0.8, 1.0).lerp(Color(1.0, 0.85, 0.35), power))
		draw_rect(bar, Color(1, 1, 1, 0.7), false, 1.0)


func _reel_in_empty() -> void:
	if _line != null and is_instance_valid(_line) and not _line.is_reeling():
		_line.reel_in()


func _put_the_line_away() -> void:
	if _line != null and is_instance_valid(_line):
		_line.queue_free()
	_line = null
	var world_camera := _world_camera()
	if world_camera != null and world_camera.is_focused():
		world_camera.release_focus(0.4)


## Per frame: the line comes in if whatever was fishing stopped, and a creature that swims into the
## hook takes it.
func _fish() -> void:
	if _charge >= 0.0:
		if not _can_cast():
			_charge = -1.0
			_show_the_power(Vector2.ZERO, false)
		elif _holding_the_key():
			_charge = minf(1.0, _charge + get_physics_process_delta_time() / CHARGE_SECONDS)
			_show_the_power(_anchor_now(), true)
		else:
			_release_charge()
	if _line == null:
		return
	if not is_instance_valid(_line):
		_line = null
		return
	if _line.has_fish():
		return
	if not _at_a_fishing_spot():
		_reel_in_empty()
		return
	if not _line.in_water():
		return
	var at: Vector2 = _line.hook_position()
	for node in get_tree().get_nodes_in_group(&"sea_creatures"):
		var creature := node as Node2D
		if creature == null or not bool(creature.call("is_alive")) or bool(creature.call("is_hooked")):
			continue
		if creature.global_position.distance_to(at) <= float(creature.call("radius")) + 14.0:
			_on_bite(creature)
			return


## ⚠ ON THE LINE, IN THE WATER, WHERE IT CAN BE SEEN. Kent: "in most fishing games, we visibly see
## the fish getting pulled back, not a circle screen." Nothing stops: the camera is on the hook and
## the creature is on it, and the fight is the line's (FishingLine2D) -- hold to wind, ease off when
## it runs.
func _on_bite(creature: Node2D) -> void:
	_hooked = creature
	creature.call("hook_onto", _line.hook)
	_line.hook_creature(creature, creature.call("fight") as Dictionary)
	_say_why("A %s on the line! Hold %s to wind it in -- ease off when it runs, or the line snaps." % [
		String(creature.call("display_name")), ControlsKeys.keys_for("use_utility")])


func _on_escaped(creature: Node2D, why: String) -> void:
	_hooked = null
	if creature != null and is_instance_valid(creature):
		creature.call("release_from_hook")
	_say_why("The line snapped! It got away, apo." if why == "snapped"
		else "It took all the line and got away, apo.")


func _on_landed(creature: Node2D) -> void:
	_hooked = null
	if creature == null or not is_instance_valid(creature):
		_put_the_line_away()
		return
	_catches += 1
	var kind := String(creature.get("kind"))
	creature.call("land", _anchor_now() + Vector2(0.0, -80.0))
	_put_the_line_away()
	var first := not _caught_kinds.has(kind)
	_caught_kinds[kind] = true
	if first:
		announce_acquisition("A %s!" % String(creature.call("display_name")),
			String(CATCH_NOTES.get(kind, "")), creature.call("portrait") as Texture2D)
	_speak(script_lines.fire(("CATCH.%s" % kind) if first else "CATCH.again"))
	if _catches >= HOOK_CATCHES:
		_hook_broken = true
		_speak(script_lines.fire("HOOK.broke"))


## The sea's creatures, put in the water once.
func _release_the_sea_creatures() -> void:
	if _marks == null:
		return
	var top := (_waterline_y if is_finite(_waterline_y) else 560.0) + 70.0
	var water := Rect2(1700.0, top, 5600.0 - 1700.0, BED_Y - 30.0 - top)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3157
	for row: Array in SEA_LIFE:
		var centre: Vector2 = row[1]
		for _index in range(int(row[2])):
			var creature := SeaCreatureClass.new()
			creature.kind = String(row[0])
			creature.bounds = water
			creature.wander = Rect2(centre - Vector2(380.0, 130.0), Vector2(760.0, 260.0)) \
				.intersection(water)
			creature.target = _anchor_now
			creature.target_reachable = _creatures_can_reach_the_player
			creature.position = Vector2(
				clampf(centre.x + rng.randf_range(-220.0, 220.0), water.position.x, water.end.x),
				clampf(centre.y + rng.randf_range(-70.0, 70.0), water.position.y, water.end.y))
			_marks.get_parent().add_child(creature)
			creature.struck.connect(_on_creature_struck)
			creature.died.connect(_on_creature_died)
			creature.bit_player.connect(_on_bitten)


## They bite a player who is in the water with them -- not one sitting in a boat or on the sand.
func _creatures_can_reach_the_player() -> bool:
	return player != null and is_instance_valid(player) and _boat_carrying_player() == null \
		and _anchor_now().y > _waterline_y + AIR_DEPTH


## The first blow on any of them turns all of them but the bangus.
func _on_creature_struck(_creature: Node2D) -> void:
	if _creatures_hostile:
		return
	_creatures_hostile = true
	_set_the_creatures_hostile(true)
	_speak(script_lines.fire("SEA.provoked"))


func _set_the_creatures_hostile(on: bool) -> void:
	for node in get_tree().get_nodes_in_group(&"sea_creatures"):
		node.call("set_hostile", on)


func _on_creature_died(_creature: Node2D) -> void:
	_kills += 1
	_speak(script_lines.fire("SEA.killed%d" % mini(_kills, 4)))


func _on_bitten(_creature: Node2D) -> void:
	if _level_completed:
		return
	_hits_taken += 1
	if player != null and is_instance_valid(player):
		var flash := player.create_tween()
		flash.tween_property(player, "modulate", Color(2.0, 0.45, 0.45), 0.06)
		flash.tween_property(player, "modulate", Color.WHITE, 0.25)
	if _hits_taken >= PLAYER_HITS:
		_sent_up()


## Ten bites: up to the surface, out of it -- not back to a checkpoint -- and the sea calms down.
func _sent_up() -> void:
	_hits_taken = 0
	_creatures_hostile = false
	_set_the_creatures_hostile(false)
	_air = AIR_SECONDS
	var at := _anchor_now()
	if player != null and is_instance_valid(player) and player.has_method("apply_morph_state"):
		player.call("apply_morph_state", {"position": Vector2(at.x, _waterline_y + 24.0),
			"linear_velocity": Vector2.ZERO})
	_speak(script_lines.fire("SEA.sent_up"))


## Per frame: Lolo on each kind the first time the player swims up to one, and the bites counted
## over the player's head while the sea is angry.
func _mind_the_creatures(anchor_position: Vector2) -> void:
	if anchor_position.y > _waterline_y + AIR_DEPTH:
		for node in get_tree().get_nodes_in_group(&"sea_creatures"):
			var creature := node as Node2D
			var kind := String(creature.get("kind"))
			if _met_kinds.has(kind) or not bool(creature.call("is_alive")):
				continue
			if creature.global_position.distance_to(anchor_position) <= MEET_REACH:
				_met_kinds[kind] = true
				_speak(script_lines.fire("SEA.%s" % kind))
				break
	var showing := _creatures_hostile or _hits_taken > 0
	if _health_meter == null or not is_instance_valid(_health_meter):
		if not showing or _marks == null:
			return
		_health_meter = _HealthMeter.new()
		_health_meter.name = "HealthMeter"
		_marks.get_parent().add_child(_health_meter)
	_health_meter.visible = showing
	_health_meter.global_position = anchor_position + Vector2(0.0, -122.0)
	_health_meter.left = PLAYER_HITS - _hits_taken
	_health_meter.queue_redraw()
	# A hint for the hook, once, standing at its heap with nothing to clear it.
	if not _hook_hint_said and _hook_mound != null and not _hook_revealed \
			and anchor_position.distance_to(_hook_mound.global_position) < 140.0:
		_hook_hint_said = true
		_say_why("Something hard is under the sand here, apo. You would need something with teeth to comb it away.")


## Hearts over the player's head while the sea's creatures are angry: ten, going out one a bite.
class _HealthMeter extends Node2D:
	var left := 10

	func _ready() -> void:
		z_index = 40

	func _draw() -> void:
		for index in range(10):
			var at := Vector2((index - 4.5) * 13.0, 0.0)
			var colour := Color(0.95, 0.3, 0.32) if index < left else Color(0.25, 0.1, 0.12, 0.7)
			draw_circle(at + Vector2(-2.5, -2.0), 3.2, colour)
			draw_circle(at + Vector2(2.5, -2.0), 3.2, colour)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-5.6, -1.0),
				at + Vector2(5.6, -1.0), at + Vector2(0.0, 5.5)]), colour)


# --- The two forks -----------------------------------------------------------------------

func _on_shore_fork_approached() -> void:
	# ⚠ A QUESTION ALREADY ANSWERED IS NOT ASKED AGAIN -- a restore can put the fork's trigger
	# back under a player whose crossing was chosen before the checkpoint. Piyesta's forks have
	# always checked this.
	if director != null and not director.committed_route("L3_N1").is_empty():
		return
	_live_node_obstacle = "L3_N1"
	dialogue_node = _shore_node
	# THE CROSSING IS INTRODUCED HERE, AND THE CHOICE WAITS FOR IT. Its opening line and its
	# two ways across are held back from the volume (see _on_obstacle_arrived and
	# _teaches_on_entering) and said at the fork -- the question they set up comes straight
	# after, once the box is read, instead of opening over a conversation the player is
	# part-way through. Both are once-only, so a second visit goes straight to the question.
	# Not before the brush: the fork turns the player back for it, and says why.
	if PlayerProfile.has_new_brush():
		_speak_on_arrival("L3_N1.enter")
		_speak(script_lines.fire("L3_N1.teach"))
	if dialogue_box != null and dialogue_box.is_open():
		if not dialogue_box.conversation_finished.is_connected(_on_dialogue_node_approached):
			dialogue_box.conversation_finished.connect(_on_dialogue_node_approached,
				CONNECT_ONE_SHOT)
		return
	_on_dialogue_node_approached()


## ⚠ THE CROSSING'S OPENING LINE WAITS FOR THE FORK. Its volume starts at 640 and the brush
## lies at 620, so "That is the whole of it, then. She never painted the far side" was said the
## moment the brush was picked up -- on the same frame as the checkpoint, the brush's lesson and
## Lolo's line about the brush, four things at once, and about a crossing the player had not
## been shown yet. It is said at the fork, just before the choice it introduces.
func _on_obstacle_arrived(obstacle_id: String) -> void:
	if obstacle_id == "L3_N1":
		return
	super._on_obstacle_arrived(obstacle_id)


## And the two ways across with it, for the same reason. See _on_shore_fork_approached.
func _teaches_on_entering(obstacle_id: String) -> bool:
	return obstacle_id != "L3_N1"


## ⚠ AND THE SHORE'S INSTRUCTION WAITS FOR THE BRUSH. The shore's volume starts at 350, so its
## instruction -- "No counting down any more... Try something that can SWIM" -- went up on the
## hint bar six seconds into the level, about a brush the player had not picked up. It is said
## when the brush is taken instead (see _on_brush_touched).
func _speak_current_stage(obstacle_id: String) -> void:
	if obstacle_id == "L3_B0_SHORE" and not PlayerProfile.has_new_brush():
		return
	super._speak_current_stage(obstacle_id)


# --- Lolo, one line at a time ---------------------------------------------------------------

## ⚠ A LINE OF LOLO'S IS READ BEFORE THE NEXT ONE REPLACES IT. The hint bar writes each new
## line straight over the last, which is right for "press E to read the sign" and wrong for
## him: on the dive his story and the coral field's facts all arrive on this bar -- a fact every
## two or three hundred pixels, between lines of the story -- and played through they replaced
## one another within a second. "Your lola was never the same after" was a starfish fact before
## it could be read. Each batch of his now stands for its reading time, the bar's own measure,
## before anything of his replaces it; what arrives meanwhile waits its turn. Counted down on
## the physics step, so a conversation that stops the world stops the count too.
var _advice_waiting: Array = []
var _advice_left := 0.0
## The coral fact the player swam up to while he was talking. See _on_coral_touched.
var _coral_waiting := ""
## How close the player still has to be to a coral for its fact to be worth saying late.
const CORAL_STILL_NEAR := 260.0


func _post_advice(advice: Array[Dictionary]) -> void:
	if advice.is_empty():
		return
	if _advice_left > 0.0 or not _advice_waiting.is_empty():
		_advice_waiting.append(advice)
		return
	_advise_now(advice)


func _advise_now(advice: Array[Dictionary]) -> void:
	super._post_advice(advice)
	var reading := 0.0
	for line: Dictionary in advice:
		reading += _reading_time(String(line.get("text", "")))
	_advice_left = reading


## Immediate words -- a refill, being seen, the brush -- still go up at once, and are read
## before his next line replaces them.
func _say_why(text: String) -> void:
	super._say_why(text)
	_advice_left = maxf(_advice_left, _reading_time(text))


static func _reading_time(text: String) -> float:
	return clampf(float(text.length()) * HintBar.BEAT_PER_CHAR, HintBar.BEAT_MIN,
		HintBar.BEAT_MAX)


func _pace_the_advice(delta: float) -> void:
	if _advice_left > 0.0:
		_advice_left = maxf(0.0, _advice_left - delta)
		return
	if not _advice_waiting.is_empty():
		_advise_now(_advice_waiting.pop_front())
		return
	if _coral_waiting.is_empty():
		return
	var key := _coral_waiting
	_coral_waiting = ""
	var spot: Variant = coral_field().get(key, null)
	if spot is Vector2 and _anchor_now().distance_to(spot as Vector2) <= CORAL_STILL_NEAR:
		_speak(script_lines.fire("CORAL.%s" % key))


## THE FORK WAITS FOR THE BRUSH, AND FOR NOTHING DRAWN.
##
## It used to wait for a practice drawing -- a Swim shape at the waterline -- because both ways
## across could otherwise be taken with nothing drawn at all, and the practice was what kept
## Dagat a drawing game. Kent: "there should be the choice and then to draw if necessary." So
## the choice comes first, and each way across asks for its own drawing instead -- a swimmer to
## go under, something strong to drag the beached bangka down to go over.
##
## The brush is still waited for, and it is not a drawing: it is what switches the clock off
## and the drain on, and a player who had jumped it would be choosing a crossing under Payyo's
## ten seconds.
func _dialogue_node_is_ready() -> bool:
	if _live_node_obstacle != "L3_N1" or director == null:
		return true
	if PlayerProfile.has_new_brush():
		return true
	_say_why("Something back there in the sand is catching the light, apo. Take it first.")
	return false


## ⚠ NOTHING IS DRAWN BEFORE THE CROSSING IS CHOSEN. Choice first is the rule (see
## _dialogue_node_is_ready), and a drawing made before it would decide for the player: inside
## the crossing's volume a swimmer would be judged against the dive and commit it without the
## question ever being asked, and anywhere on the beach a body would arrive that the choice then
## has to work around. Refused before anything is made or paid for -- the ink attempt is handed
## back -- and Lolo says where the question is.
func _on_drawing_ready(
	entity_id: String,
	display_name: String,
	drawing: Image,
	response: Dictionary,
	strokes: Array,
	ink_cost: float
) -> void:
	if _crossing_unchosen():
		ink_manager.release_attempt()
		# Before the brush the next thing is the brush, not the question it leads to.
		if not PlayerProfile.has_new_brush():
			_say_why("Not yet, apo. Something in the sand is catching the light — take it first.")
		else:
			_say_why("Not yet, apo. Tell me how you mean to cross first. I am at the water.")
		return
	super(entity_id, display_name, drawing, response, strokes, ink_cost)


func _crossing_unchosen() -> bool:
	return director != null and not director.is_solved("L3_N1") \
		and director.committed_route("L3_N1").is_empty()


## Where the creature was set down in the scene, before anything staged it. See below.
var _bakunawa_home := Vector2.ZERO


## ⚠ THE CREATURE IS PUT BACK AS THE RUN NOW SAYS IT IS. A restore rolls the director back, and
## the creature went on as it was: still at the surface for a crossing chosen after the
## checkpoint, still fighting a fight the restore had undone, still following a light, or swum
## off from an encounter that is open again. Every part of it is re-derived from the director:
## where it is staged (the boat's crossing brings it up to the surface), and what it is doing --
## searching, gap open, fighting -- or, once the encounter is over by the light or the fight,
## gone.
func _put_the_bakunawa_back() -> void:
	if _bakunawa == null or not is_instance_valid(_bakunawa) or director == null:
		return
	var at := _bakunawa_home
	var surfaced := false
	if director.is_solved("L3_N1") and director.committed_route("L3_N1") == "artist":
		var surface := _mark("SurfaceMark")
		if surface != null:
			at.y = surface.global_position.y
			surfaced = true
	var route := director.committed_route("L3_N2")
	if director.is_solved("L3_N2") and route != "pragmatist":
		_bakunawa.set_gone()
		return
	_bakunawa.reset_to(at, surfaced)
	match route:
		"pragmatist":
			_bakunawa.open_a_gap()
		"protector":
			_bakunawa.enter_fight()
		"artist":
			# The light was up when this was written: it is following again, from where it was.
			if director.stage("L3_N2") > 0:
				_bakunawa.be_guided(at)


## THE SHAPE BEING HELD, AS DRAWN -- its class, its name, the picture and its strokes -- so a
## checkpoint written in deep water can give it back. See _give_back_the_shape.
var _held_shape: Dictionary = {}
var _giving_back_a_shape := false


func _spawn_or_replace(entity_id: String, display_name: String, drawing: Image,
		strokes: Array) -> bool:
	var became := super(entity_id, display_name, drawing, strokes)
	if became:
		_held_shape = {"id": entity_id, "name": display_name, "drawing": drawing,
			"strokes": strokes.duplicate(true)}
	return became


## ⚠ A CHECKPOINT IN DEEP WATER GIVES BACK THE SHAPE THAT WAS HELD THERE.
##
## Two of this level's checkpoints are on the seabed (CP3, CP3b). The base restore moves
## whatever body the player has to where the checkpoint was written -- and when that body is
## the apo (out of ink, floundered, changed back with Q in open water) it put an apo who cannot
## swim on the seabed in the middle of the bakunawa's waters. They drowned on arrival, the
## rescue fired, it restored the same checkpoint as the same apo, and that went round about once
## a second for good: "Up you come, apo. Back to the middle of its waters", forever.
##
## So the checkpoint remembers the shape and gives it back, exactly as drawn, without judging it
## again (it was judged when it was drawn) -- the crossing is lost back to the checkpoint, not
## the body. And it is given back with at least a unit of ink: a checkpoint written with the bar
## nearly empty would otherwise run out again within a breath, and that is the same loop slower.
const SHAPE_INK_FLOOR := 1.0


func _give_back_the_shape(shape: Dictionary) -> void:
	if shape.is_empty() or String(shape.get("id", "")).is_empty():
		return
	if _current_form_id == String(shape["id"]):
		return
	var drawing := shape.get("drawing") as Image
	_giving_back_a_shape = true
	var became := _spawn_or_replace(String(shape["id"]), String(shape.get("name", "")),
		drawing, shape.get("strokes", []) as Array)
	_giving_back_a_shape = false
	if became and ink_manager.remaining() < SHAPE_INK_FLOOR:
		ink_manager.committed = maxf(0.0, ink_manager.capacity - SHAPE_INK_FLOOR)
		ink_manager.reserved = 0.0
		_on_ink_changed(ink_manager.remaining(), ink_manager.capacity, ink_manager.reserved)


## THE BOAT'S SECOND STEP IS NOT A DRAWING. Once a helper has been accepted the crossing waits
## on E at the hull, and nothing drawn answers that -- a second helper, drawn after changing
## back, is simply a body to drag it with, and judging it would count it as a miss against a
## step it was never asked to answer. The first one accepted is told what it is for.
func _judge_submission(entity_id: String, strokes: Array = []) -> void:
	# A shape handed back by a checkpoint was judged when it was drawn. See _give_back_the_shape.
	if _giving_back_a_shape:
		return
	# ⚠ THE FIGHT'S SECOND STEP IS THE CREATURE GOING QUIET, and nothing drawn answers it --
	# T3's widening included, which would otherwise take any weapon at all as the fight won.
	if director != null and director.current_obstacle() == "L3_N2" \
			and director.committed_route("L3_N2") == "protector" and director.stage("L3_N2") > 0:
		return
	# ⚠ THE LIGHT'S SECOND STEP IS BRINGING IT HOME, and nothing drawn answers that either.
	if director != null and director.current_obstacle() == "L3_N2" \
			and director.committed_route("L3_N2") == "artist" and director.stage("L3_N2") > 0:
		return
	if director == null or director.current_obstacle() != "L3_N1" \
			or director.committed_route("L3_N1") != "artist" or director.is_solved("L3_N1"):
		var lit_before := _guiding()
		super(entity_id, strokes)
		if not lit_before and _guiding():
			_begin_the_guiding()
		return
	if director.stage("L3_N1") > 0:
		return
	super(entity_id, strokes)
	# A helper is told what it is for. The anvil is told when it is dropped (see the shove).
	if director.stage("L3_N1") > 0 and entity_id != "anvil":
		_speak(script_lines.fire("L3_N1.artist.helper"))


## ⚠ THE CROSSING WAITS FOR THE SHORE -- AS A PLACE, NOT ONLY AT THE FORK.
##
## The director judges a drawing against whichever beat the player walked into LAST, and the
## crossing's volume (640..1160) lies over the seaward half of the practice's (350..1050). A
## player who takes the brush and walks toward the water the objective points at is inside the
## crossing by the time they draw -- so the swimmer the practice asks for answered the CROSSING:
## the apo announced the dive ("I will go under it"), the practice stayed unsolved, the fork
## never opened, the objective and Lolo's "not yet" never moved again, and the boat could not
## be taken at all. Played, not reasoned: drawn at the waterline or right beside the brush
## (x 634, the crossing starts under the apo's own body at about 625), every time. No probe
## saw it, because every probe enters each beat by name.
##
## So the crossing is not entered while the shore is unanswered: the shore stays the current
## beat anywhere on the beach, and the moment it is answered the crossing is entered if the
## player is already standing in it.
##
## (The practice is gone -- the brush answers the shore now, and nothing is drawn before the
## crossing is chosen, see _on_drawing_ready -- but the order still matters: a crossing entered
## before the brush would be a beat with its drain unarmed.)
func _gate_the_crossing() -> void:
	if director == null:
		return
	for node in get_tree().get_nodes_in_group(&"level_obstacles"):
		var area := node as LevelObstacle2D
		if area == null or area.obstacle_id != "L3_N1":
			continue
		if area.player_entered.is_connected(director.enter_obstacle):
			area.player_entered.disconnect(director.enter_obstacle)
		area.player_entered.connect(_on_crossing_entered)
		area.player_exited.connect(_on_crossing_exited)
		_crossing_area = area
	if not director.obstacle_solved.is_connected(_on_shore_answered):
		director.obstacle_solved.connect(_on_shore_answered)
	if not director.obstacle_entered.is_connected(_on_beat_entered):
		director.obstacle_entered.connect(_on_beat_entered)


func _on_crossing_entered(obstacle_id: String) -> void:
	_inside_crossing = true
	if director != null and director.is_solved("L3_B0_SHORE"):
		director.enter_obstacle(obstacle_id)


func _on_crossing_exited(_obstacle_id: String) -> void:
	_inside_crossing = false


func _on_shore_answered(obstacle_id: String, _route: String, _label: String,
		_attempts: int, _tier: int) -> void:
	if obstacle_id == "L3_B0_SHORE":
		_open_the_crossing.call_deferred()


## The brush taken while already standing in the crossing's volume -- its pickup reaches past
## the volume's west edge -- enters the crossing then, since walking in has already happened.
## Deferred: this runs from the director's own solved signal.
func _open_the_crossing() -> void:
	if _inside_crossing and director != null:
		director.enter_obstacle("L3_N1")


## ⚠ AND ONCE THE SHORE IS ANSWERED, STANDING IN THE CROSSING MEANS THE CROSSING. The two
## volumes overlap and the director keeps whichever the player entered last. A checkpoint
## restore puts the apo back inside both at once, and when the shore's volume happened to report
## second, a finished practice was the current beat: the swimmer drawn next was judged against
## it, counted for nothing, and the dive went on with the objective asking for a drawing the
## player was already swimming in.
func _on_beat_entered(obstacle_id: String) -> void:
	if obstacle_id == "L3_B0_SHORE" and _inside_crossing and director != null \
			and director.is_solved("L3_B0_SHORE"):
		director.enter_obstacle.call_deferred("L3_N1")


## ⚠ A SWIMMER DRAWN AT THE WATER'S EDGE GOES INTO THE WATER, once the crossing is open.
##
## A new form arrives where the apo stood, and on this shore the apo stands on sand that ends
## in a drop into deep water. A swimmer there cannot move -- it lies on the sand draining ink
## until the ink runs out, the apo drops off the edge and is fished back to the beach. The apo
## cannot get into the water to draw there either: the rescue takes them out within a second.
## Played, not reasoned: the dive route could not be started at all.
##
## So a swimmer drawn within reach of either shore's edge slips into the sea just past it --
## once the dive is the way across, or the crossing is settled either way. Not on the boat route
## before the bangka is in the water: a swimmer there is the wrong answer to "drag it down", and
## slipping it in would hand the player the other crossing without the question.
const SLIP_REACH := 420.0


func _where_a_new_form_arrives(entity_id: String, state: Dictionary) -> Dictionary:
	if _restrictions == null or director == null or not _restrictions.swims(entity_id):
		return state
	if not state.has("position"):
		return state
	if director.committed_route("L3_N1") != "pragmatist" and not director.is_solved("L3_N1"):
		return state
	var edges := level_data_shore_edges()
	if edges == Vector2.ZERO:
		return state
	var at := Vector2(state["position"])
	if at.y > _waterline_y + 10.0:
		return state
	var into := state.duplicate()
	if at.x <= edges.x and at.x > edges.x - SLIP_REACH:
		into["position"] = Vector2(edges.x + 90.0, _waterline_y + 70.0)
	elif at.x >= edges.y and at.x < edges.y + SLIP_REACH:
		into["position"] = Vector2(edges.y - 90.0, _waterline_y + 70.0)
	else:
		return state
	into.erase("velocity")
	into["linear_velocity"] = Vector2.ZERO
	return into


func _on_bakunawa_approached() -> void:
	# Answered already: see the shore fork.
	if director != null and not director.committed_route("L3_N2").is_empty():
		return
	# The base's handler reads `dialogue_node` and `_dialogue_node_obstacle_id()`, so both
	# have to point at this fork before it runs.
	_live_node_obstacle = "L3_N2"
	dialogue_node = _bakunawa_node
	# The choice after the conversation that sets it up, never over it -- see the shore's.
	if dialogue_box != null and dialogue_box.is_open():
		if not dialogue_box.conversation_finished.is_connected(_on_dialogue_node_approached):
			dialogue_box.conversation_finished.connect(_on_dialogue_node_approached,
				CONNECT_ONE_SHOT)
		return
	_on_dialogue_node_approached()


## ⚠ THE CREATURE IS MET BEFORE ITS ANSWERS ARE. Its volume reaches west of the place its
## arrival is announced, so a swimmer entered the encounter first and heard the three ways of
## dealing with it -- "Something that can throw LIGHT..." -- before Lolo had seen it: "Wait.
## Wait. Do you see how it is going". And from the boat the arrival was never said at all, the
## announce area being under the keel. So entering says the arrival first, if it has not been
## said, and then the answers, as one conversation.
func _on_obstacle_entered(obstacle_id: String) -> void:
	if obstacle_id == "L3_N2":
		_speak_on_arrival("L3_N2.enter")
	super._on_obstacle_entered(obstacle_id)


## ⚠ THE ENCOUNTER STARTS AT THE COMMIT, NOT AT THE SOLVE. Two of its three resolutions need
## the world to change the moment the player says what they are doing: the gap has to open
## before they can slip through it, and the creature has to turn on them before they can
## fight it. Only the Artist one waits for a drawing.
func _on_route_committed_here(obstacle_id: String, route: String) -> void:
	# Whatever of Lolo's was still waiting to be said was about the choice just made.
	_advice_waiting.clear()
	# Kent: "when the player chooses swim, lolo prompts that the player can turn into one of the
	# sea creatures if they wanted to".
	if obstacle_id == "L3_N1" and route == "pragmatist":
		_speak(script_lines.fire("L3_N1.pragmatist.creatures"))
	if obstacle_id != "L3_N2" or _bakunawa == null:
		return
	match route:
		"pragmatist":
			_bakunawa.open_a_gap()
			# ⚠ WHEN, NOT ONLY WHAT. "Stay out of the light" told a first-time swimmer the rule
			# and not the way through it, and played along the bed that swimmer was caught four
			# times in twenty seconds. The beam swings, and the way past is to go while it is
			# turned away -- which the line now says. Down in the water its two beams lift and
			# dip together (Bakunawa2D.DEEP_REACH), so the line says which way to go when.
			if _bakunawa.reach() > BakunawaClass.CONE_LENGTH:
				_say_why("Watch its light, apo. Keep low, along the bottom — under its belly the light never reaches. Go when it looks up.")
			else:
				_say_why("Watch where its light goes, apo. Cross while it is turned away.")
		"protector":
			_knocks = 0
			_bakunawa.enter_fight()
			_say_why("It is coming round. Put something in your hands, apo.")


## Home. It swam into the cave and is gone, and what it was holding on to comes up out of the
## mouth of it to the apo. That closes the beat -- the light's second step (level_03.json).
func _on_gift_offered() -> void:
	var at := _cave_mouth if _cave_mouth != Vector2.ZERO else _bakunawa.treasure_point()
	var found := _uncover_the_treasure(at)
	if _life != null and _bakunawa != null:
		_life.sparkle(found, 8, 55.0)
	if _lure != null and is_instance_valid(_lure):
		_lure.visible = false
	_rest_the_light()
	_award_the_flower()
	PlayerProfile.record_bakunawa("LIT")
	script_lines.set_flag("l3_bakunawa_lit")
	if not director.is_solved("L3_N2"):
		director.solve_with_item("L3_N2", "led_home")


## A blow landed: the creature flashes red (Bakunawa2D), and the bar says how many are left.
func _on_bakunawa_hit(hits: int, needed: int) -> void:
	if hits < needed:
		status_label.text = "Hit! %d more" % (needed - hits)


## ⚠ WORN OUT IS WHAT ANSWERS THE FIGHT. The first swing records the weapon (see
## _use_equipped_utility); the creature going quiet closes the beat -- which is when the storm
## clears and Lolo says "It has had enough. Let it go", the route's own solved line. That line
## used to fire at the FIRST press of F, over a creature with nothing taken out of it, and this
## said a second one like it at the end. And the weapons that fought it are spent now, their
## work done -- one use, by Kent's rule, and the use was this fight.
func _on_bakunawa_quiet(how: String) -> void:
	if how != "FOUGHT":
		return
	PlayerProfile.record_bakunawa("FOUGHT")
	script_lines.set_flag("l3_bakunawa_fought")
	# ⚠ AND IT TAKES WHAT IT WAS LOOKING FOR WITH IT. Kent: "if we choose to fight it, it takes the
	# treasure with them". The torn corner the light route is given goes off in its coils, seen.
	if _bakunawa != null:
		_bakunawa.carry_away(LOST_CORNER)
	if director != null and not director.is_solved("L3_N2"):
		director.solve_with_item("L3_N2", "subdued")
	for weapon: String in _fought_with.keys():
		if _slot_holding(weapon) >= 0:
			spend_tool(weapon)
	_fought_with.clear()


## The drawn weapons swung at it this go, by class -- spent when it is subdued.
var _fought_with: Dictionary = {}


func _fighting_it() -> bool:
	return director != null and director.committed_route("L3_N2") == "protector" \
		and not director.is_solved("L3_N2")


## What the fight takes: the route's Strike classes, read off the level file.
func _weapons() -> PackedStringArray:
	if director == null:
		return PackedStringArray()
	var spec: Dictionary = (director.obstacle("L3_N2").get("routes", {}) as Dictionary) \
		.get("protector", {})
	return AbilityTags.resolve(spec.get("required_tags", []),
		String(spec.get("match", "all")), spec.get("exclude", []))


## A weapon answers the fight while the fight is on -- at its second step too, which is more of
## the same -- so F is offered as the strike it is, there and only there.
func _tool_answers_here(entity_id: String) -> bool:
	if _fighting_it() and director.current_obstacle() == "L3_N2":
		return _weapons().has(entity_id)
	return super(entity_id)


## F with the anvil at the bangka says what it does there.
func _verb_for(entity_id: String) -> String:
	if entity_id == "anvil" and _at_the_beached_bangka():
		return "SHOVE"
	return super(entity_id)


func _level_use_verb(entity_id: String) -> String:
	if entity_id == "anvil" and _at_the_beached_bangka():
		return "SHOVE"
	if entity_id == "rake" and (_at_the_hook_mound() or (_at_the_beached_bangka() and not _bangka_dug)):
		return "CLEAR SAND"
	return super(entity_id)


## ⚠ THE RAKE CLEARS SAND. Kent: "the rake should be able to get rid of the sand" -- off the hook
## hidden in the beach, and off the half-buried bangka (digging it out is not moving it: that still
## takes something strong or heavy).
func _level_uses_the_tool(item: DrawnItemData) -> bool:
	if item != null and item.entity_id == "rake":
		if _at_the_hook_mound():
			_clear_the_sand()
			return true
		if _at_the_beached_bangka() and not _bangka_dug:
			_dig_out_the_bangka()
			return true
	return super(item)


## F over the water says it casts, and with a line out that it reels in.
func _refresh_action_prompts() -> void:
	super()
	if action_prompts == null or _level_completed:
		return
	if _line != null:
		action_prompts.set_use_available(true, "Fishing Line", "HOLD TO REEL")
	elif _can_cast():
		action_prompts.set_use_available(true, "Fishing Hook", "HOLD TO CAST")


## ⚠ F IN THE FIGHT ALWAYS SWINGS. The base answers a beat with a tool's first use and stops
## there, which is right for a key at a lock: the turn IS the answer. Here the answer is three
## good hits, so the first press records the weapon and swings as well, and so does every
## press after it.
func _use_equipped_utility() -> void:
	# A line out is wound while the key is held (see _handle_level_input); a cast is charged by
	# holding it. This is the tap, for anything that reaches here without the hold.
	if _line != null:
		return
	if _can_cast():
		_cast(null, 0.4)
		return
	# The anvil behind the bangka shoves it -- at the boat's first step or any later one.
	if _holding_the_anvil() and _at_the_beached_bangka():
		_shove_with_the_anvil()
		return
	if _fighting_it() and _equipped_utility != null and is_instance_valid(_equipped_utility) \
			and _equipped_utility.item_data != null \
			and _weapons().has(_equipped_utility.item_data.entity_id):
		var item := _equipped_utility.item_data
		if director.current_obstacle() == "L3_N2" and director.stage("L3_N2") == 0:
			_judge_submission(item.entity_id, item.strokes)
		_fought_with[item.entity_id] = true
		var outcome := _equipped_utility.describe_use(player)
		status_label.text = outcome if not outcome.is_empty() else item.display_name
		return
	super()


## Being seen, and being hit, both cost the current stretch and not the approach. CP3b sits
## partway through for exactly this: "an encounter-length reset with no mid-point turns a
## five-minute section into twenty."
##
## ⚠ THE FIGHT KEEPS THE BLOWS LANDED. Fifteen to win (Bakunawa2D.HITS_TO_SUBDUE); a restore puts
## the creature back on its guard, and the blows it has taken go back on it after.
func _lose_the_stretch(why: String) -> void:
	_reset_cooldown = 1.4
	_knocks = 0
	var fighting := _bakunawa != null and _bakunawa.state() == BakunawaClass.State.FIGHTING
	var landed := _bakunawa.hits_taken() if fighting else 0.0
	_return_to_safety(why, "%s" % why)
	_stand_them_clear_of_it()
	if fighting and _bakunawa.state() == BakunawaClass.State.FIGHTING:
		_bakunawa.enter_fight(true)
		_bakunawa.restore_hits(landed)


## How far outside the creature's reach a caught player is put back. See _stand_them_clear_of_it.
const RESET_CLEARANCE := 220.0


## ⚠ A CHECKPOINT RECORDS WHERE THE PLAYER WAS, NOT WHERE ITS NODE IS. CP3b's volume is 220
## wide and the snapshot is taken at whatever point inside it the apo happened to cross, so on
## the stealth route the place a reset returns to is regularly INSIDE the creature's cone --
## measured at 384 px from a thing that sees 460, with two further resets in the ten seconds
## after, the player having done nothing at all. It is not a soft lock: they can swim out
## inside the grace. It is worse than it sounds anyway, because a checkpoint you can be caught
## standing on is not a checkpoint, and the design's whole reason for putting one mid-encounter
## is that losing the stretch should cost it ONCE.
##
## Moving the volume does not fix it. The snapshot is taken wherever the body crossed, and a
## player coming back from the east crosses at the volume's far edge. The reach is what has to
## be answered, so the reach is what this measures against.
##
## Their depth is kept, and the distance west is made up only as far as it has to be.
func _stand_them_clear_of_it() -> void:
	if _bakunawa == null or not is_instance_valid(_bakunawa):
		return
	if player == null or not is_instance_valid(player) \
			or not player.has_method("apply_morph_state"):
		return
	# ⚠ TWO SECONDS OF SWIMMING CLEAR, NOT ONE. At a hundred pixels past the reach, a player
	# still holding forward when the reset landed -- which is every player, the first time --
	# was back inside it in a second, before "wait until its light turns away" could be read,
	# and was caught again: played, four times in five seconds. Along the bed a swimmer makes
	# about a hundred pixels a second, so this is the time to read the line and look up.
	var clear_x := _bakunawa.global_position.x - _bakunawa.reach() - RESET_CLEARANCE
	var anchor := _anchor_now()
	if anchor.x <= clear_x:
		return
	# ⚠ SHIFTED, NOT SET. apply_morph_state moves the body; the anchor is what the sweep is
	# measured against and the two are not the same node on a rig.
	player.call("apply_morph_state", {
		"position": player.global_position + Vector2(clear_x - anchor.x, 0.0),
		"linear_velocity": Vector2.ZERO})


func _on_route_solved(obstacle_id: String, route: String) -> bool:
	if obstacle_id == "L3_N1":
		# ⚠ THE FLAGS ARE NOT SET HERE ANY MORE, AND SETTING THEM HERE WAS A BUG. They said
		# the lore had been heard at the moment the route was taken -- before a word of it was
		# spoken -- and the island skips whichever half is flagged. So a boat player never
		# heard how he died and a dive player never heard about lola: the heart of the level,
		# missing on both routes, with every suite green. They are set now by the crossing
		# itself, in _told_the_boat and _told_the_dive, when the last line actually lands.
		if route == "artist" and _bakunawa != null:
			# THE SURFACE STAGING. From up here it is silhouette and back; from below the
			# player is inside its space. One creature, moved -- see Bakunawa2D.stage_at.
			var surface := _mark("SurfaceMark")
			if surface != null:
				_bakunawa.stage_at(surface.global_position.y)
		return false
	if obstacle_id == "L3_N2":
		# The light's beat closes when the creature is home (see _on_gift_offered), and its own
		# solved line -- "Home ... it is giving you something" -- is the generic one.
		if route == "pragmatist":
			PlayerProfile.record_bakunawa("EVADED")
			script_lines.set_flag("l3_bakunawa_evaded")
		return false
	return false


## ⚠ THE ID HERE MUST BE IN PlayerProfile.FLOWER_IDS OR THE FLOWER COUNTS FOR NOTHING. The
## level file's `hidden_flowers[].id` is documentation; this string is the fact.
func _award_the_flower() -> void:
	PlayerProfile.record_collectible("L3_HF")
	script_lines.set_flag("has_flower_3")


## ⚠ WHAT IT HAD LOST IS SHOWN, AND SO IS WHAT IT GIVES. The light led it to what it had been
## searching the dark for, and the level marked the moment with a burst of sparkles over
## nothing: the flower was recorded silently and no object was ever there. The design asks for
## "something the player recognises -- an object from Level 1's house, or a piece of the
## painting. A generic chest wastes the beat." So it is a corner of one of her canvases, torn,
## still in the gilt the paintings in her house hang in, with this very sea painted on it.
##
## And the flower comes up out of it to the apo -- "it finds a treasure, handing you a
## flower" -- and says which of the five it is, the way Payyo's did, because the design needs
## the count seen: a player who missed one otherwise chases an ending already lost.
func _uncover_the_treasure(where: Vector2) -> Vector2:
	if _bakunawa == null:
		return _anchor_now()
	var at := where
	# ⚠ FROM THE BOAT IT IS BROUGHT UP. The cave is a long way under the keel, so what comes out
	# of it rises to the surface ahead of the boat -- found, and given.
	var anchor := _anchor_now()
	if anchor.y < _waterline_y:
		var toward := signf(where.x - anchor.x)
		at = Vector2(anchor.x + 150.0 * (toward if toward != 0.0 else 1.0), _waterline_y + 60.0)
	var parent := _bakunawa.get_parent()
	var corner := Sprite2D.new()
	corner.name = "LostCorner"
	corner.texture = LOST_CORNER
	corner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	corner.z_index = 6
	corner.rotation = -0.14
	corner.modulate.a = 0.0
	parent.add_child(corner)
	corner.global_position = at + Vector2(0.0, 18.0)
	var reveal := corner.create_tween()
	reveal.tween_property(corner, "modulate:a", 1.0, 0.7)
	reveal.parallel().tween_property(corner, "global_position:y", at.y, 1.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# ⚠ AND IT IS GIVEN, NOT LEFT LYING THERE. Kent: the things found at the bottom "should have
	# the acquired pop up since its an acquired". It holds a moment where it was found, then
	# comes to the apo and is theirs -- with its own card, ahead of the flower's.
	reveal.tween_interval(0.5)
	reveal.tween_method(func(t: float) -> void:
		if is_instance_valid(corner):
			var target := _anchor_now() + Vector2(0.0, -30.0)
			corner.global_position = at.lerp(target, t) + Vector2(0.0, -40.0 * sin(PI * t))
			corner.scale = Vector2.ONE * lerpf(1.0, 0.45, t), \
		0.0, 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	reveal.tween_property(corner, "modulate:a", 0.0, 0.2)
	reveal.tween_callback(func() -> void:
		if is_instance_valid(corner):
			corner.queue_free()
		announce_acquisition("A Torn Corner",
			"A piece of one of her canvases, with this sea on it. It was what the creature had lost.",
			LOST_CORNER))
	var flower := Sprite2D.new()
	flower.name = "GivenFlower"
	flower.texture = FLOWER_ART
	flower.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flower.z_index = 12
	flower.scale = Vector2.ONE * 0.2
	flower.modulate.a = 0.0
	parent.add_child(flower)
	flower.global_position = at + Vector2(0.0, -10.0)
	var give := flower.create_tween()
	# After the corner has been given: the two used to rise out of the same spot together.
	give.tween_interval(2.9)
	give.tween_property(flower, "modulate:a", 1.0, 0.3)
	give.parallel().tween_property(flower, "scale", Vector2.ONE * 0.9, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# To the apo -- wherever they are by the time it gets there.
	give.tween_method(func(t: float) -> void:
		if is_instance_valid(flower):
			var target := _anchor_now() + Vector2(0.0, -40.0)
			flower.global_position = at.lerp(target, t) + Vector2(0.0, -60.0 * sin(PI * t)), \
		0.0, 1.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	give.tween_property(flower, "scale", Vector2.ONE * 0.3, 0.25)
	give.parallel().tween_property(flower, "modulate:a", 0.0, 0.25)
	give.tween_callback(func() -> void:
		if is_instance_valid(flower):
			flower.queue_free()
		var count := clampi(int(PlayerProfile.flower_count()), 0, 5)
		announce_acquisition("Hidden Flower",
			"%s of five. It had been holding on to it all along, down in the dark, and it gave it up gladly."
				% String(COUNT_WORDS[count]), FLOWER_ART))
	return at


# --- The crossing, which is where the lore lives --------------------------------------------

## ⚠ THE TWO CROSSINGS TELL DIFFERENT HALVES AND THEY TELL THEM DIFFERENTLY, and that second
## part is the whole reason the fork exists rather than a coin toss.
##
## THE BOAT stops the world. The apo is seated and rowing with nothing to do but listen --
## "the only scene in the game where they cannot draw their way out of a conversation" -- so
## its lines go to the DialogueBox, which pauses and waits for a key.
##
## THE DIVE does not. He talks while the apo swims, unable to look at him, so its lines go to
## the HintBar, which does not stop anything. Making both of them pause would have thrown
## away the contrast the fork is for.
func _tell_the_crossing(anchor_position: Vector2) -> void:
	if director == null or _arrived:
		return
	match director.committed_route("L3_N1"):
		"artist":
			_told_the_boat(anchor_position)
		"pragmatist":
			_told_the_dive(anchor_position)


func _told_the_boat(anchor_position: Vector2) -> void:
	# Paced along the crossing rather than fired in a block, so the sea goes past underneath
	# it and the silence between lines is part of the scene.
	# ⚠ SPREAD DOWN THE WHOLE CROSSING, AND THE LAST TWO FAR APART. Kent: "the 'keep rowing'
	# dialogue is directly before 'stop' when they see the serpent". They were eighty pixels apart
	# -- a third of a second at the oars -- so "I would rather you did not stop" was answered by
	# "Stop" before it had been read. The sea is longer now, a line every six or seven hundred
	# pixels, one more of them in the quiet stretch, and seven hundred of open water between
	# "keep rowing" and the shadow.
	for step in [[2000.0, "L3_BOAT.lore1"], [2600.0, "L3_BOAT.lore2"],
			[3200.0, "L3_BOAT.lore3"], [3800.0, "L3_BOAT.lore4"],
			[4300.0, "L3_BOAT.hum"], [4750.0, "L3_BOAT.lore5"]]:
		if anchor_position.x >= float(step[0]):
			_tell(String(step[1]))
	# The shadow comes LAST and before the creature: it is the bakunawa's own silhouette,
	# seen before the bakunawa is, which makes the shape a foreshadow rather than a second
	# animal the player might think they could have drawn.
	if anchor_position.x >= 5450.0 and not _told.has("L3_BOAT.shadow"):
		_tell("L3_BOAT.shadow")
		_cast_the_shadow()
	if _told.has("L3_BOAT.lore4"):
		script_lines.set_flag("heard_how_he_died")


func _told_the_dive(anchor_position: Vector2) -> void:
	for step in [[2100.0, "L3_DIVE.lore1"], [2900.0, "L3_DIVE.lore2"],
			[3700.0, "L3_DIVE.lore3"], [4500.0, "L3_DIVE.lore4"], [5150.0, "L3_DIVE.light"]]:
		if anchor_position.x >= float(step[0]):
			_tell(String(step[1]))
	if _told.has("L3_DIVE.lore4"):
		script_lines.set_flag("heard_about_lola")


## Once each, and remembered in the run state so a checkpoint restore does not replay the
## crossing from the top.
func _tell(hook: String) -> void:
	if _told.has(hook):
		return
	_told[hook] = true
	_speak(script_lines.fire(hook))


## THE CREATURE'S OWN SILHOUETTE, passing under the hull and going the wrong way round. The
## delivered shadow is a four-frame swim, and it is the SAME animal the player meets a minute
## later -- which is the whole point of the beat: a foreshadow rather than a second animal
## they might think they could have drawn.
func _cast_the_shadow() -> void:
	if _shadow != null and is_instance_valid(_shadow):
		return
	var mark := _mark("SurfaceMark")
	if mark == null:
		return
	var frames: Array[Texture2D] = []
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/Level3/dagat.json"))
	if parsed is Dictionary:
		var group: Dictionary = ((parsed as Dictionary).get("groups", {}) as Dictionary) \
			.get("bakunawa/shadow", {})
		for path_value: Variant in group.get("frames", []):
			var texture := load(String(path_value)) as Texture2D
			if texture != null:
				frames.append(texture)
	if frames.is_empty():
		return
	var shape := _DriftingShadow.new()
	shape.name = "Shadow"
	shape.frames = frames
	# Under the hull and a little deeper, big enough to read as something you do not want to
	# be above. z below the boat so it passes UNDER it.
	shape.global_position = Vector2(mark.global_position.x - 1100.0,
		mark.global_position.y + 210.0)
	shape.z_index = 2
	mark.get_parent().add_child(shape)
	_shadow = shape
	var glide := create_tween()
	glide.tween_property(shape, "global_position:x",
		mark.global_position.x + 700.0, 5.4).set_trans(Tween.TRANS_SINE)
	glide.tween_callback(shape.queue_free)


## A four-frame swim cycle that fades at both ends of its crossing, so it arrives and leaves
## out of the murk rather than popping.
class _DriftingShadow extends Sprite2D:
	var frames: Array[Texture2D] = []
	var _frame := 0
	var _clock := 0.0

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture = frames[0]
		scale = Vector2.ONE * (1180.0 / maxf(1.0, float(texture.get_width())))
		modulate = Color(1.0, 1.0, 1.0, 0.0)
		var fade := create_tween()
		fade.tween_property(self, "modulate:a", 0.75, 1.3)
		fade.tween_interval(2.6)
		fade.tween_property(self, "modulate:a", 0.0, 1.3)

	func _process(delta: float) -> void:
		_clock += delta
		if _clock < 0.22:
			return
		_clock = 0.0
		_frame = (_frame + 1) % frames.size()
		texture = frames[_frame]


# --- The island ----------------------------------------------------------------------------

## Reaching the far sand, which is the end of the level.
##
## ⚠ THE ARRIVAL IS SCRIPTED, AND IT HAS TO BE. The player gets here as something that swims,
## and a thing that swims cannot walk up a beach -- the fish drive on land is a flop with no
## horizontal drive at all. Reverting them in open water instead would hand them straight to
## the drowning rescue. So the level reverts them AND puts them on the sand in one breath.
func _on_island_reached(_checkpoint_id: String) -> void:
	if _arrived or director == null:
		return
	# ⚠ REACHING THE ISLAND UNSEEN IS SLIPPING PAST IT, WHATEVER CARRIED THE PLAYER THERE.
	# Slipping past was answered only at 420 px beyond the creature, and a boat cannot get
	# there: its hull runs aground on the island with the passenger seated at x 4417. So a boat
	# player who chose to go around it sat at the island's edge -- inside the sweep's reach,
	# with the island's own checkpoint just written under them -- and was caught and put back
	# there, over and over, with the level unable to end. Played through, not reasoned.
	if director.committed_route("L3_N2") == "pragmatist" and not director.is_solved("L3_N2") \
			and _bakunawa != null and not _bakunawa.sees(_anchor_now(), _carrying_a_lit_light()):
		director.solve_with_item("L3_N2", "the dark")
	if not director.is_solved("L3_N2"):
		return
	_arrived = true
	# ⚠ DEFERRED, BECAUSE THIS ARRIVES FROM body_entered. Coming ashore reverts the player,
	# which builds a new body and disables the old one's shapes -- and Godot refuses to
	# change collision state while it is flushing queries. Every arrival printed two engine
	# errors and the revert was landing on a body mid-query.
	call_deferred("_land_on_the_island")


func _land_on_the_island() -> void:
	# Set by the arrival too; here as well so landing is landing however it was reached.
	_arrived = true
	_come_ashore()
	var sand := _mark("IslandMark")
	if _life != null and sand != null:
		# Where the painting waits: the thing they crossed the sea for, catching the light.
		_life.sparkle(sand.global_position + Vector2(90.0, -40.0), 9, 45.0)
	# THE PAINTING FIRST, THE FAREWELL SECOND, then cut. Lolo leaving is the level's real
	# ending, not the painting, so it gets the last word.
	_speak(script_lines.fire("ISLAND.enter"))
	# ⚠ AND THE PAINTING IS TAKEN, NOT ONLY SEEN. Kent: it "should have the acquired pop up
	# since its an acquired". It is armed now that the apo is ashore, the line points at it, and
	# walking into it is what carries the level on -- see _on_next_painting_taken. Without a
	# painting (a scene with no island mark) the farewell follows at once, as it always did.
	if _next_painting != null and is_instance_valid(_next_painting):
		_next_painting.arm()
		return
	await _say_goodbye()


## The canvas out of the sand and into the apo's hands, with the card that says so -- and then
## the rest of what Lolo has to say, his farewell, and the end.
func _on_next_painting_taken() -> void:
	if not _arrived or _painting_taken:
		return
	_painting_taken = true
	announce_acquisition("Dilim",
		"Lola's next canvas, half buried in the sand. Where she went after the sea.",
		NEXT_PAINTING)
	# ⚠ THE CARD FIRST, THEN HIM. Started at once, his farewell typed underneath the card and
	# the first thing he said was lost behind it. It is the card's moment; he waits for it to
	# go, and no longer than it can take.
	var waited := 0.0
	while acquired_overlay != null and is_instance_valid(acquired_overlay) \
			and acquired_overlay.is_busy() and waited < 5.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await _say_goodbye()


func _say_goodbye() -> void:
	_tell_the_other_half()
	_speak(script_lines.fire("ISLAND.farewell"))
	# ⚠ AND LEVEL 4 INHERITS IT. Dilim being unguided is the point, so it has to carry its
	# own signposting with nobody to explain anything. That is a Level 4 problem created here.
	PlayerProfile.record_lolo_departed()
	# ⚠ PAINTING FIRST, FAREWELL SECOND, THEN CUT -- and the cut used to come first. The
	# completion was staged on the same frame the lines were queued, so the level-complete
	# panel was on its way while Lolo was still speaking, and he never left: he was simply
	# there when the screen changed. Now the lines are read, he waves and goes, and then the
	# level ends.
	await _the_island_is_said()
	await _lolo_takes_his_leave()
	_complete_level()


func _the_island_is_said() -> void:
	if dialogue_box != null and dialogue_box.has_method("is_open") \
			and bool(dialogue_box.call("is_open")):
		await dialogue_box.conversation_finished


func _lolo_takes_his_leave() -> void:
	if lolo == null or not is_instance_valid(lolo) or not lolo.has_method("farewell"):
		return
	lolo.call("farewell")
	# The wall clock, not this node's process delta: the island may be paused while he goes.
	var started := Time.get_ticks_msec()
	var sparkled := false
	var length := float(lolo.call("farewell_length"))
	var waited := 0.0
	while is_instance_valid(lolo) and not bool(lolo.call("is_gone")) and waited < length + 1.0:
		await get_tree().process_frame
		waited = float(Time.get_ticks_msec() - started) / 1000.0
		# A few motes lift off him as he starts to go.
		if not sparkled and waited > length * 0.45 and _life != null:
			sparkled = true
			_life.sparkle(lolo.global_position + Vector2(0.0, -30.0), 7, 30.0)


func _come_ashore() -> void:
	# ⚠ OFF THE BOAT FIRST. A hull re-seats its passenger on the deck every physics frame, so
	# a boat player "landed" on the sand was back aboard, in the water at the island's edge,
	# one frame later -- and the farewell played to an apo sitting in a boat.
	if _launched_boat != null and is_instance_valid(_launched_boat) \
			and _launched_boat.has_passenger(player):
		_launched_boat.release_passenger()
	_revert_to_base_form()
	var sand := _mark("IslandMark")
	if sand == null or player == null or not is_instance_valid(player):
		return
	if player.has_method("apply_morph_state"):
		player.call("apply_morph_state", {
			"position": sand.global_position - Vector2(0.0, 40.0),
			"linear_velocity": Vector2.ZERO,
		})


## WHICHEVER HALF THEY HAVE NOT HEARD. The reveal splits across the two routes and both
## halves land in full here, so no player leaves Dagat without the whole of it -- the design
## uses the fork instead of working around it.
##
## Branched in code rather than with `condition`, because a dialogue line's condition fires
## when a flag IS set and what is wanted here is the inverse. There is no `unless`.
func _tell_the_other_half() -> void:
	if not script_lines.is_flag_set("heard_how_he_died"):
		_speak(script_lines.fire("ISLAND.how_he_died"))
	if not script_lines.is_flag_set("heard_about_lola"):
		_speak(script_lines.fire("ISLAND.about_lola"))


# --- What the player should be doing now --------------------------------------------------

## DERIVED, NEVER SET -- an objective written at the moment something happened is wrong after
## every checkpoint restore.
func _current_objective() -> Dictionary:
	if director == null:
		return {}
	if not PlayerProfile.has_new_brush():
		return {"key": "brush", "target": _mark_position("BrushMark")}
	if not director.is_solved("L3_N1"):
		# ⚠ ONCE A WAY ACROSS IS CHOSEN, THE LINE IS ABOUT DOING IT. It said "Get to the far side"
		# to a player who had just chosen -- the only line on screen, and it named the goal of the
		# whole level instead of the next thing to do.
		match director.committed_route("L3_N1"):
			"artist":
				var hull: Variant = _bangka.global_position + Vector2(0.0, -80.0) \
					if _bangka != null and is_instance_valid(_bangka) \
					else _mark_position("BangkaMark")
				# Sliding down the sand: the next thing is getting in.
				if _bangka_found:
					return {"key": "board_the_boat", "target": hull}
				if _holding_the_anvil():
					return {"key": "drop_on_the_boat", "target": hull}
				if _a_helper_is_held():
					return {"key": "push_the_boat" if _bangka_dug else "drag_the_boat_now",
						"target": hull}
				return {"key": "drag_the_boat", "target": hull}
			"pragmatist":
				return {"key": "dive_draw", "obstacle": "L3_N1",
					"target": _mark_position("WaterlineMark")}
		# Before the choice: to Lolo at the water, where the question is.
		var fork: Variant = _shore_node.global_position + Vector2(0.0, -110.0) \
			if _shore_node != null else _mark_position("WaterlineMark")
		return {"key": "cross", "target": fork}
	# ⚠ ON THE WAY, NOT YET THERE. Finding the boat -- or drawing the swimmer -- answers the
	# crossing on the beach, and the line jumped straight to the encounter: "It cannot see.
	# Decide what you are going to do about that", shown on the sand to a player who had never
	# seen the creature it means. Until they reach its stretch, the line is about the crossing.
	if not director.was_entered("L3_N2") and not director.is_solved("L3_N2"):
		if director.committed_route("L3_N1") == "artist":
			# Found is not aboard: the bangka goes into the water with E, and E again gets in.
			if not _aboard():
				var boat: Variant = _launched_boat.global_position \
					if _launched_boat != null and is_instance_valid(_launched_boat) \
					else _mark_position("BangkaMark")
				return {"key": "board_the_boat", "target": boat}
			return {"key": "cross_by_boat", "target": _mark_position("SurfaceMark")}
		return {"key": "cross_by_dive", "target": _mark_position("BakunawaMark")}
	if not director.is_solved("L3_N2"):
		# ⚠ ONCE CHOSEN, THE LINE IS ABOUT DOING IT. It went on saying "Decide what you are
		# going to do about that" after the player had decided -- sneaking past, told to decide.
		var chosen := {"pragmatist": "bakunawa_sneak", "artist": "bakunawa_light",
			"protector": "bakunawa_fight"}.get(director.committed_route("L3_N2"), "") as String
		# Armed and swinging: the line is about the fight now, not about drawing for it.
		if chosen == "bakunawa_fight" and director.stage("L3_N2") > 0:
			chosen = "bakunawa_fight_on"
		# The light is up and it is following: the line is about bringing it home.
		if chosen == "bakunawa_light" and director.stage("L3_N2") > 0:
			return {"key": "bakunawa_lead",
				"target": _cave_mouth if _cave_mouth != Vector2.ZERO else _mark_position("BakunawaMark")}
		if not chosen.is_empty():
			return {"key": chosen, "target": _mark_position("BakunawaMark")}
		return {"key": "bakunawa", "obstacle": "L3_N2",
			"target": _mark_position("BakunawaMark")}
	# Ashore: the painting, and nothing else, until it is taken -- and then nothing at all. The
	# goodbye is not a task, and "Go up onto the far sand" said to a player standing on it with
	# the painting in their hands was the line pointing back at the beach.
	if _arrived and _next_painting != null and is_instance_valid(_next_painting):
		if _painting_taken:
			return {}
		return {"key": "take_the_painting",
			"target": _next_painting.global_position + Vector2(0.0, -130.0)}
	return {"key": "island", "target": _mark_position("IslandMark")}


## ⚠ THE BANGKA IS NEVER PICKED UP. It is found, not drawn, and it is the only way across on
## its route: E boards it and E gets off it while it is afloat, and nothing else. Out of the
## water -- run up on the island at the end -- it was a sailboat on the sand like any other,
## and the prompt offered to put it in the bag while Lolo said goodbye.
func _nearest_interactable_utility() -> PhysicsShapeObject:
	var nearest := super._nearest_interactable_utility()
	if nearest != null and nearest == _launched_boat and not _launched_boat.boards_on_interact():
		return null
	return nearest


## Whether the apo is sitting in the bangka.
func _aboard() -> bool:
	return _boat_carrying_player() != null


func _mark_position(mark_name: String) -> Variant:
	var mark := _mark(mark_name)
	return mark.global_position if mark != null else null


# --- What a checkpoint has to carry -------------------------------------------------------

## The brush and the encounter's outcome are on the PROFILE and are permanent, so they are
## not here. What is here is the run's own shape: which fork was taken, and the latches that
## stop a lesson being spent twice.
func _level_run_state() -> Dictionary:
	return {
		"live_node": _live_node_obstacle,
		"said_underwater": _said_underwater,
		"said_the_jars": _said_the_jars,
		"brush_taken": _brush_taken,
		"bangka_found": _bangka_found,
		"bangka_dug": _bangka_dug,
		"hook_revealed": _hook_revealed,
		"has_hook": _has_hook,
		"hook_catches": _catches,
		"hook_broken": _hook_broken,
		"bangka_x": _bangka_x if is_finite(_bangka_x) else -1.0,
		"refills_taken": _refills_taken.duplicate(),
		"knocks": _knocks,
		"arrived": _arrived,
		"told": _told.keys(),
		# The shape held when this was written, and whether it was written in deep water --
		# the case where giving it back is the difference between a rescue and a drowning loop.
		"shape": _held_shape.duplicate() if not _current_form_id.is_empty() \
			and String(_held_shape.get("id", "")) == _current_form_id else {},
		"underwater": _anchor_now().y > _waterline_y + 20.0,
	}


func _restore_level_run_state(state: Dictionary) -> void:
	_live_node_obstacle = String(state.get("live_node", "L3_N1"))
	_said_underwater = bool(state.get("said_underwater", false))
	_said_the_jars = bool(state.get("said_the_jars", false))
	_brush_taken = bool(state.get("brush_taken", false))
	_bangka_found = bool(state.get("bangka_found", false))
	_bangka_dug = bool(state.get("bangka_dug", false))
	# ⚠ THE HOOK IS NEVER TAKEN BACK. What was found and caught stays found and caught -- a restore
	# from the encounter is about the encounter -- and a resumed run picks it up from the save.
	_hook_revealed = _hook_revealed or bool(state.get("hook_revealed", false))
	_has_hook = _has_hook or bool(state.get("has_hook", false))
	_catches = maxi(_catches, int(state.get("hook_catches", 0)))
	_hook_broken = _hook_broken or bool(state.get("hook_broken", false))
	_show_the_hook_mound()
	_charge = -1.0
	_show_the_power(Vector2.ZERO, false)
	_put_the_line_away()
	var hull_x := float(state.get("bangka_x", -1.0))
	_bangka_x = hull_x if hull_x > 0.0 else NAN
	_sliding = false
	_air = AIR_SECONDS
	_lead_told = false
	_refills_taken = (state.get("refills_taken", []) as Array).duplicate()
	_knocks = int(state.get("knocks", 0))
	# ⚠ NEVER RESTORED AS ARRIVED. A checkpoint can be written after the island was reached -- swim
	# back through CP3b and it is -- and resumed from it with `_arrived` set, reaching the island
	# again did nothing: the landing is guarded by it, so the painting never armed and the level
	# could not end. Wherever a restore puts the apo, arriving is something they do again; put
	# back at the island itself, they are standing in its volume and land on the next frame.
	_arrived = false
	_told.clear()
	for hook: Variant in (state.get("told", []) as Array):
		_told[String(hook)] = true
	# A restore is a new body or none at all, so the drain starts again rather than resuming
	# a form that is no longer standing.
	if _drain != null:
		_drain.clear()
	# ⚠ AND WHAT LOLO WAS WAITING TO SAY IS DROPPED. His lines are paced (see _post_advice), so a
	# few of the dive's were usually still queued when the rescue came -- and he went on telling
	# the swim ("Keep going. I can talk and you can swim") to an apo standing on the beach.
	_advice_waiting.clear()
	_advice_left = 0.0
	_coral_waiting = ""
	_put_back_what_the_restore_undid()
	_put_the_bakunawa_back()
	# Deep water: the shape held there, given back. The base moves the body to the checkpoint
	# after this, so the shape is made here and carried there with it.
	if bool(state.get("underwater", false)):
		_give_back_the_shape(state.get("shape", {}) as Dictionary)


## ⚠ A RESTORE ROLLS THE LEVEL BACK, AND TWO THINGS DID NOT COME BACK WITH IT.
##
## THE BOAT. LevelBase frees every placed object that did not exist at the checkpoint, and the
## launched bangka is one -- it is put in the water after CP2 is written. The beached one it
## replaced had been freed when it was found, and nothing planted it again. So a boat player
## put back to CP2 -- by the drowning rescue, or by being seen at the surface before CP3b --
## stood on the shore with the boat route committed, no boat, and nothing to press E at. A
## soft lock on the route the design calls the gentle one. The beached bangka goes back on the
## sand whenever the restored run says it has not been found.
##
## THE JARS. The restore hands back the ink spent since the checkpoint and takes back the ink
## gained since it -- including what a refill gave -- and rolls `_refills_taken` back too. But
## the jar itself had been freed when it was touched, so the level believed it was still there
## and it was not: every restore in the arena cost a refill the economy was counting on.
func _put_back_what_the_restore_undid() -> void:
	if not _bangka_found and (_bangka == null or not is_instance_valid(_bangka)
			or _bangka.is_queued_for_deletion()):
		_plant_the_bangka()
	elif not _bangka_found and _bangka != null and is_instance_valid(_bangka):
		# Still on the sand: where the run says it had got to, and buried or not as it says.
		var mark := _mark("BangkaMark")
		_bangka.global_position.x = _bangka_x if is_finite(_bangka_x) \
			else (mark.global_position.x if mark != null else _bangka.global_position.x)
		var hull := _bangka.get_node_or_null(^"Hull") as Node2D
		if hull != null:
			hull.position.y = -31.0 + (0.0 if _bangka_dug else BURIED_SINK)
		if _sand_heap != null and is_instance_valid(_sand_heap):
			_sand_heap.visible = not _bangka_dug
			_sand_heap.modulate.a = 1.0
	if director != null:
		_plant_the_refills()
