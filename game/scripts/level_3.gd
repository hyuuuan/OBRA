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


# --- What the machine asks -------------------------------------------------------------

func level_config_path() -> String:
	return "res://config/level_03.json"


func dialogue_path() -> String:
	return "res://config/dialogue_l3.json"


func _dialogue_node_obstacle_id() -> String:
	return _live_node_obstacle


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
	_scatter_the_ambience()
	_bring_the_sea_to_life()
	call_deferred("_play_the_opening")

	if _bakunawa != null:
		_bakunawa_home = _bakunawa.global_position
		_bakunawa.gift_offered.connect(_on_gift_offered)
		_bakunawa.went_quiet.connect(_on_bakunawa_quiet)
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
	art.position = Vector2(0.0, -31.0)
	_bangka.add_child(art)
	_bangka.global_position = mark.global_position
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
	return {
		"jelly": Vector2(1360.0, bed), "star": Vector2(1680.0, bed + 2.0),
		"clam": Vector2(1980.0, bed + 1.0), "weed": Vector2(2180.0, bed + 4.0),
		"urchin": Vector2(2420.0, bed), "coral": Vector2(2660.0, bed + 3.0),
		"shaft": Vector2(2900.0, 900.0), "wreck": Vector2(3080.0, bed + 2.0),
		"lola1": Vector2(1780.0, bed + 4.0), "lola2": Vector2(3260.0, bed + 1.0),
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
		[AMBIENCE + "bubbles_long", Vector2(1180.0, bed - 20.0), 210.0, 3.0],
		[AMBIENCE + "bubbles_short", Vector2(1620.0, bed - 50.0), 130.0, 3.6],
		[AMBIENCE + "bubbles_long", Vector2(2280.0, bed - 10.0), 235.0, 2.6],
		[AMBIENCE + "bubbles_short", Vector2(2840.0, bed - 50.0), 140.0, 3.2],
		[AMBIENCE + "bubbles_long", Vector2(3420.0, bed - 20.0), 200.0, 2.8],
		[AMBIENCE + "bubbles_short", Vector2(4160.0, bed - 50.0), 135.0, 3.4],
		[AMBIENCE + "school", Vector2(1450.0, 1180.0), 175.0, 2.2],
		[AMBIENCE + "school", Vector2(2350.0, 1060.0), 210.0, 1.8],
		[AMBIENCE + "school", Vector2(3150.0, 1240.0), 165.0, 2.4],
		[AMBIENCE + "school", Vector2(4020.0, 1100.0), 195.0, 2.0],
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
	shot.global_position = Vector2(2350.0, 460.0)
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
	_life.jelly_spots = [Vector2(1720.0, 1240.0), Vector2(2330.0, 1060.0),
		Vector2(2780.0, 1380.0), Vector2(3180.0, 1120.0), Vector2(4300.0, 1080.0)]
	_life.player_anchor = func() -> Vector2: return _anchor_now()
	_life.player_swimming = func() -> bool:
		return player != null and is_instance_valid(player) and not (player is Wanderer) \
			and _anchor_now().y > _waterline_y + 20.0
	_life.boat = func() -> RigidBody2D:
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
		"CP1", "CP2":
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


## Where the bangka may put its passenger down: within a hull's length of either shore. Out
## past that there is only water under it -- see UtilityObject.holds_passenger.
const LANDING_REACH := 170.0
var _shore_edges := Vector2.ZERO


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
	var aboard := _launched_boat != null and is_instance_valid(_launched_boat) \
		and player != null and is_instance_valid(player) \
		and _launched_boat.has_passenger(player)
	if not aboard:
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
	var hull := _launched_boat as RigidBody2D
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


func _keep_the_passenger_aboard() -> void:
	if _launched_boat == null or not is_instance_valid(_launched_boat):
		return
	if _shore_edges == Vector2.ZERO:
		_shore_edges = level_data_shore_edges()
	var x := _launched_boat.global_position.x
	_launched_boat.holds_passenger = _shore_edges != Vector2.ZERO \
		and x > _shore_edges.x + LANDING_REACH and x < _shore_edges.y - LANDING_REACH
	_launched_boat.hold_note = "Not out here, apo. There is nothing under us but sea."


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
	if _current_form_id.is_empty() or not Input.is_action_pressed(&"move_left"):
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
## Floundering only happens below the waterline, so the apo it leaves is in the sea: straight
## to the rescue (see _taken_back_from_the_deep).
func _on_floundered(_entity_id: String, note: String) -> void:
	_say_why(note)
	_revert_to_base_form()
	_taken_back_from_the_deep.call_deferred()


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
	# it. In the sea, the rescue.
	if _anchor_now().y > _waterline_y + 20.0:
		_taken_back_from_the_deep.call_deferred()


## ⚠ STRAIGHT TO THE RESCUE, NOT UP AND THEN DOWN AGAIN. Running out of ink (or floundering)
## used to carry the apo up to the surface where they were, keeping the x -- where the apo, who
## cannot swim, sank again, and a second later the drowning rescue took them to the checkpoint
## anyway: two moves for one event, the camera chasing both. The rescue is what was always going
## to happen, so it happens now, in the rescue's own words. The checkpoint gives back the shape
## they held there -- see _give_back_the_shape -- so a rescue into deep water is a swimmer
## again, not an apo who drowns on arrival.
func _taken_back_from_the_deep() -> void:
	if player == null or not is_instance_valid(player) or not (player is Wanderer):
		return
	if not bool(player.call("is_in_water")) and _anchor_now().y <= _waterline_y + 20.0:
		return
	var words := _drowning_words()
	_return_to_safety(words[0], words[1])


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
		_say_why("It will not move for the two of us, apo. Draw something strong enough to drag it down.")
		return true
	_drag_the_bangka_in()
	return true


## E over the hull says what it will do: drag it down with a helper held, and push without one
## -- which is what the apo would try, and E then says why it will not go.
func _level_interact_offer() -> Dictionary:
	if not _at_the_beached_bangka():
		return {}
	return {"name": "Bangka", "verb": "DRAG IN" if _a_helper_is_held() else "PUSH"}


## How close to the hull E reaches it. Measured from the player's anchor, which for a drawn
## body is its middle -- an elephant's middle is a good way from whatever end of it is
## touching the boat.
const BANGKA_REACH := 190.0


## Standing at the beached bangka with the boat route chosen and the bangka not yet in the
## water.
func _at_the_beached_bangka() -> bool:
	if _bangka == null or not is_instance_valid(_bangka) or _bangka_found:
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


## THE HELPER'S ONE JOB. The hull slides down the sand and into the sea, and the shape that
## dragged it goes back into the ink as it goes -- its strength went into the boat, and the
## apo is left on the sand to get in. Changing back is free; the drain stops with it.
##
## ⚠ JUDGED FIRST, IF IT NEVER WAS. A helper is judged when it is drawn, but only against the
## beat the player is standing in -- drawn a step west of the crossing's volume it was judged
## against nothing, and the boat would then be launched by a drawing the per-class figures
## never saw. Judged here as well, quietly, and the bangka itself is closed as an item.
func _drag_the_bangka_in() -> void:
	_bangka_found = true
	if director.stage("L3_N1") == 0:
		director.enter_obstacle("L3_N1")
		director.note_submission(_current_form_id)
	var hull := _bangka
	var edges := level_data_shore_edges()
	var edge_x := edges.x if edges != Vector2.ZERO else hull.global_position.x + 160.0
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
	# Behind the apo as it passes: it is on the sand, and the apo is standing on it too.
	hull.z_index = 6
	var slide := hull.create_tween()
	slide.tween_property(hull, "global_position:x", edge_x - 30.0, 1.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Over the lip and in, nose first.
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
	# Sand thrown up behind it on the way.
	if _life != null:
		for step in range(4):
			get_tree().create_timer(0.2 + 0.22 * float(step)).timeout.connect(func() -> void:
				if is_instance_valid(hull) and _life != null:
					_life.sparkle(hull.global_position + Vector2(-50.0, 6.0), 3, 18.0))


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
	if director.is_solved("L3_N1") and director.committed_route("L3_N1") == "artist":
		var surface := _mark("SurfaceMark")
		if surface != null:
			at.y = surface.global_position.y
	var route := director.committed_route("L3_N2")
	if director.is_solved("L3_N2") and route != "pragmatist":
		_bakunawa.set_gone()
		return
	_bakunawa.reset_to(at)
	match route:
		"pragmatist":
			_bakunawa.open_a_gap()
		"protector":
			_bakunawa.enter_fight()


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
	if director == null or director.current_obstacle() != "L3_N1" \
			or director.committed_route("L3_N1") != "artist" or director.is_solved("L3_N1"):
		super(entity_id, strokes)
		return
	if director.stage("L3_N1") > 0:
		return
	super(entity_id, strokes)
	if director.stage("L3_N1") > 0:
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
	if obstacle_id != "L3_N2" or _bakunawa == null:
		return
	match route:
		"pragmatist":
			_bakunawa.open_a_gap()
			# ⚠ WHEN, NOT ONLY WHAT. "Stay out of the light" told a first-time swimmer the rule
			# and not the way through it, and played along the bed that swimmer was caught four
			# times in twenty seconds. The beam swings, and the way past is to go while it is
			# turned away -- which the line now says.
			_say_why("Watch where its light goes, apo. Cross while it is turned away.")
		"protector":
			_knocks = 0
			_bakunawa.enter_fight()
			_say_why("It is coming round. Put something in your hands, apo.")


## The light found it. Everything else about the Artist route is the creature's own doing.
func _on_gift_offered() -> void:
	var found := _uncover_the_treasure()
	if _life != null and _bakunawa != null:
		_life.sparkle(found, 8, 55.0)
	_award_the_flower()
	PlayerProfile.record_bakunawa("LIT")
	script_lines.set_flag("l3_bakunawa_lit")
	if not director.is_solved("L3_N2"):
		director.solve_with_item("L3_N2", "the light")


func _on_bakunawa_quiet(how: String) -> void:
	if how != "FOUGHT":
		return
	PlayerProfile.record_bakunawa("FOUGHT")
	script_lines.set_flag("l3_bakunawa_fought")
	_say_why("Enough. Let it go, apo — it never knew you were there.")


## Being seen, and being hit, both cost the current stretch and not the approach. CP3b sits
## partway through for exactly this: "an encounter-length reset with no mid-point turns a
## five-minute section into twenty."
func _lose_the_stretch(why: String) -> void:
	_reset_cooldown = 1.4
	_knocks = 0
	_return_to_safety(why, "%s" % why)
	_stand_them_clear_of_it()
	if _bakunawa != null and _bakunawa.state() == BakunawaClass.State.FIGHTING:
		_bakunawa.enter_fight()


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
	var clear_x := _bakunawa.global_position.x - BakunawaClass.CONE_LENGTH - RESET_CLEARANCE
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
		if route == "artist" and _bakunawa != null:
			# The drawing is accepted, so the beat is answered -- but the creature has not
			# found anything yet. It swims to what it lost, and the flower comes from THAT.
			_bakunawa.follow_the_light(_bakunawa.treasure_point())
			return true
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
func _uncover_the_treasure() -> Vector2:
	if _bakunawa == null:
		return _anchor_now()
	var at := _bakunawa.treasure_point()
	# ⚠ FROM THE BOAT IT IS BROUGHT UP, BESIDE THE BOW. The creature is staged at the surface
	# there, so its treasure point lies under its own coils: shown there, the corner was drawn
	# across the dragon's neck like something pinned to it. It rises out of the dark instead,
	# just ahead of the boat, in open water -- found, and given.
	var anchor := _anchor_now()
	if anchor.y < _waterline_y:
		var toward := signf(_bakunawa.global_position.x - anchor.x)
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
	for step in [[1250.0, "L3_BOAT.lore1"], [1850.0, "L3_BOAT.lore2"],
			[2450.0, "L3_BOAT.lore3"], [3000.0, "L3_BOAT.lore4"],
			[3300.0, "L3_BOAT.lore5"]]:
		if anchor_position.x >= float(step[0]):
			_tell(String(step[1]))
	# The shadow comes LAST and before the creature: it is the bakunawa's own silhouette,
	# seen before the bakunawa is, which makes the shape a foreshadow rather than a second
	# animal the player might think they could have drawn.
	if anchor_position.x >= 3380.0 and not _told.has("L3_BOAT.shadow"):
		_tell("L3_BOAT.shadow")
		_cast_the_shadow()
	if _told.has("L3_BOAT.lore4"):
		script_lines.set_flag("heard_how_he_died")


func _told_the_dive(anchor_position: Vector2) -> void:
	for step in [[1250.0, "L3_DIVE.lore1"], [1900.0, "L3_DIVE.lore2"],
			[2550.0, "L3_DIVE.lore3"], [3150.0, "L3_DIVE.lore4"]]:
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
				if _a_helper_is_held():
					return {"key": "drag_the_boat_now", "target": hull}
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
	return _launched_boat != null and is_instance_valid(_launched_boat) \
		and player != null and is_instance_valid(player) \
		and _launched_boat.has_passenger(player)


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
	_refills_taken = (state.get("refills_taken", []) as Array).duplicate()
	_knocks = int(state.get("knocks", 0))
	_arrived = bool(state.get("arrived", false))
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
	if director != null:
		_plant_the_refills()
