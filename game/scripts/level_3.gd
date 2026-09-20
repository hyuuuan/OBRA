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

## Latches, so a lesson and a line are each spent once per run rather than once per frame.
var _said_underwater := false
var _brush_taken := false
var _bangka_found := false
## Which seabed refills have been taken this run, by index. Run state, not profile: a
## checkpoint restore that handed them all back would make the crossing free.
var _refills_taken: Array = []
var _bangka: Area2D
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
var _shadow: Node2D


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


func _build_level_furniture() -> void:
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

	if _bakunawa != null:
		_bakunawa.gift_offered.connect(_on_gift_offered)
		_bakunawa.went_quiet.connect(_on_bakunawa_quiet)
		_bakunawa.begin_search()
	if director != null:
		director.route_committed.connect(_on_route_committed_here)
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
	var art := Polygon2D.new()
	art.polygon = PackedVector2Array([
		Vector2(-26, 10), Vector2(14, -14), Vector2(22, -4), Vector2(-18, 20)])
	art.color = Color(0.94, 0.86, 0.58, 1.0)
	pickup.add_child(art)
	pickup.global_position = mark.global_position
	pickup.z_index = 8
	mark.get_parent().add_child(pickup)
	pickup.body_entered.connect(_on_brush_touched.bind(pickup))


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
	var art := Polygon2D.new()
	art.polygon = PackedVector2Array([
		Vector2(-70, 0), Vector2(70, 0), Vector2(52, 26), Vector2(-52, 26)])
	art.color = Color(0.45, 0.31, 0.19, 1.0)
	_bangka.add_child(art)
	_bangka.global_position = mark.global_position
	_bangka.z_index = 6
	mark.get_parent().add_child(_bangka)


## Ink comes back from sources placed in the level, never over time -- the design is explicit
## that time-based regeneration "would make the whole economy decorative". Three of them down
## the dive route, because that route is transformed from start to finish and the boat is not.
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
		var refill := Area2D.new()
		refill.name = "Refill%d" % index
		refill.collision_layer = 0
		refill.collision_mask = 1
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 52.0
		shape.shape = circle
		refill.add_child(shape)
		var art := Polygon2D.new()
		art.polygon = PackedVector2Array([
			Vector2(0, -30), Vector2(22, 0), Vector2(0, 30), Vector2(-22, 0)])
		art.color = Color(0.15, 0.13, 0.28, 0.92)
		refill.add_child(art)
		refill.global_position = spots[index]
		refill.z_index = 6
		coral.get_parent().add_child(refill)
		refill.body_entered.connect(_on_refill_touched.bind(index, amount, refill))


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
	# ⚠ ON THE BED, AND THE BED MOVED. The painted terraces rest their floor at world 1349,
	# two hundred pixels above where the placeholder seabed was, so everything that sat on it
	# came up with it. A fact left at 1490 is a fact inside the rock.
	var field := {
		"jelly": Vector2(1360.0, 980.0), "star": Vector2(1680.0, 1290.0),
		"clam": Vector2(1980.0, 1310.0), "weed": Vector2(2180.0, 1120.0),
		"urchin": Vector2(2420.0, 1300.0), "coral": Vector2(2660.0, 1200.0),
		"shaft": Vector2(2900.0, 780.0), "wreck": Vector2(3080.0, 1285.0),
		"lola1": Vector2(1780.0, 860.0), "lola2": Vector2(3260.0, 1040.0),
	}
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


func _on_coral_touched(body: Node, key: String) -> void:
	if not _is_the_player(body):
		return
	# `once` on the line does the not-twice part; firing again is free and says nothing.
	_speak(script_lines.fire("CORAL.%s" % key))


func _on_refill_touched(body: Node, index: int, amount: float, refill: Area2D) -> void:
	if _refills_taken.has(index) or not _is_the_player(body):
		return
	_refills_taken.append(index)
	ink_manager.add_ink(amount)
	_say_why("There. That will hold you a while longer.")
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
	pickup.queue_free()


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
		"You cannot swim, apo. Back to %s",
	])


# --- Per frame --------------------------------------------------------------------------

func _level_physics(anchor_position: Vector2) -> void:
	var delta := get_physics_process_delta_time()
	var underwater := anchor_position.y > _waterline_y
	_watch_the_bakunawa(anchor_position, delta)
	_tell_the_crossing(anchor_position)

	if underwater and not _said_underwater:
		_said_underwater = true
		if tutorial != null:
			tutorial.note("underwater")

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
			if tutorial != null:
				tutorial.note("ink_draining")
		_drain.charge(delta)
		if morph_card != null:
			morph_card.set_meter_caption("INK")
			morph_card.set_drain(ink_manager.remaining(), ink_manager.capacity)
		# The medium rule, asked once per frame the way the ceiling is. It owns its own
		# clock, so a creature that leaves the water gets its whole beat back next time.
		_restrictions.check_medium(_current_form_id, underwater, delta)


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
			_lose_the_stretch("It turned. Back to where you were.")
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
func _on_floundered(_entity_id: String, note: String) -> void:
	_say_why(note)
	_revert_to_base_form()
	_carry_to_the_surface()


func _on_low_ink(_remaining: float, _capacity: float) -> void:
	if tutorial != null:
		tutorial.note("ink_low")
	_say_why("It is nearly gone, apo.")


## THE ZERO CASE. Revert, carry up, lose the crossing, never die. There is no death state
## anywhere in this game and none is being added here.
func _on_drain_emptied() -> void:
	if tutorial != null:
		tutorial.note("ink_emptied")
	_say_why("Out. Up you come — you lost the crossing, nothing else.")
	_revert_to_base_form()
	_carry_to_the_surface()


## ⚠ THROUGH apply_morph_state, NOT global_position. Whatever the player is, its bodies may
## be top_level, and writing the node's position moves the node and leaves the physics where
## it was. The same trap run_water_audit.gd documents.
func _carry_to_the_surface() -> void:
	if player == null or not is_instance_valid(player):
		return
	if not player.has_method("apply_morph_state"):
		return
	var anchor := player.call("get_physics_anchor") as Node2D
	var here: Vector2 = anchor.global_position if anchor != null else player.global_position
	# Straight up to the nearest air, keeping the x: the crossing is lost, not the progress
	# along it, and dragging the player back to the shore as well would make running out of
	# ink the harshest thing in a game with no fail state.
	var surface := Vector2(here.x, _waterline_y - 40.0)
	player.call("apply_morph_state", {"position": surface, "linear_velocity": Vector2.ZERO})


## E AT THE BOAT. The only thing in this level that answers the interact key and is neither a
## drawing nor a signpost.
func _interact_with_level() -> bool:
	if _bangka == null or not is_instance_valid(_bangka) or _bangka_found:
		return false
	if director == null or director.is_solved("L3_N1"):
		return false
	# ⚠ ONLY ONCE THE ROUTE IS TAKEN. Finding the boat before the fork has been answered
	# would commit the player to a crossing they were never offered, and R6 is explicit that
	# answering the dialogue is not the answer -- but the reverse holds too: the world must
	# not answer a question the player has not been asked.
	if director.committed_route("L3_N1") != "artist":
		return false
	if player == null or not is_instance_valid(player):
		return false
	if player.global_position.distance_to(_bangka.global_position) > 140.0:
		return false
	_bangka_found = true
	_bangka.queue_free()
	_launch_the_bangka()
	director.solve_with_item("L3_N1", "bangka")
	return true


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
	var sheet := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	boat.apply_item_data(DrawnItemData.from_prediction(
		"sailboat", "Bangka", sheet, [{
			"points": PackedVector2Array([
				Vector2(0, 0), Vector2(120, 0), Vector2(100, 40), Vector2(20, 40), Vector2(0, 0)]),
			"width": 6.0, "color": Color.BLACK,
		}], 0.0, registry.get_entity("sailboat")))
	# Afloat, just past the waterline, where the player is standing when they find it.
	boat.global_position = Vector2(mark.global_position.x + 120.0, mark.global_position.y + 10.0)
	boat.confirm_placement()
	_say_why("Somebody left this and never came back for it. Get in, apo.")


# --- The two forks -----------------------------------------------------------------------

func _on_shore_fork_approached() -> void:
	_live_node_obstacle = "L3_N1"
	dialogue_node = _shore_node
	_on_dialogue_node_approached()


## ⚠ THE SHORE BEAT GATES THE FORK, AND WITHOUT THIS DAGAT IS NOT A DRAWING GAME.
##
## Both of the crossing's answers can be reached on foot -- the fork is a trigger volume, not
## a wall -- and the Artist one is `answered_by` rather than a drawing. So a player could walk
## past the practice beat, answer the fork, find the boat, get in and sail across having drawn
## nothing at all. Measured, not supposed: a probe did exactly that.
##
## The design already says where the fix belongs. The shore "has to teach the replacement
## before the fork, not after -- once they are underwater, learning the ink rule by running
## out of it is a punishment, not a lesson." A beat that can be walked past does not teach
## anything, so the fork waits for it.
func _dialogue_node_is_ready() -> bool:
	if _live_node_obstacle != "L3_N1" or director == null:
		return true
	if director.is_solved("L3_B0_SHORE"):
		return true
	_say_why("Not yet, apo. Try it here first, where you can still stand up.")
	return false


func _on_bakunawa_approached() -> void:
	# The base's handler reads `dialogue_node` and `_dialogue_node_obstacle_id()`, so both
	# have to point at this fork before it runs.
	_live_node_obstacle = "L3_N2"
	dialogue_node = _bakunawa_node
	_on_dialogue_node_approached()


## ⚠ THE ENCOUNTER STARTS AT THE COMMIT, NOT AT THE SOLVE. Two of its three resolutions need
## the world to change the moment the player says what they are doing: the gap has to open
## before they can slip through it, and the creature has to turn on them before they can
## fight it. Only the Artist one waits for a drawing.
func _on_route_committed_here(obstacle_id: String, route: String) -> void:
	if obstacle_id != "L3_N2" or _bakunawa == null:
		return
	match route:
		"pragmatist":
			_bakunawa.open_a_gap()
			_say_why("Stay out of the light and it will never know you were here.")
		"protector":
			_knocks = 0
			_bakunawa.enter_fight()
			_say_why("It is coming round. Put something in your hands, apo.")


## The light found it. Everything else about the Artist route is the creature's own doing.
func _on_gift_offered() -> void:
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
	if _bakunawa != null and _bakunawa.state() == BakunawaClass.State.FIGHTING:
		_bakunawa.enter_fight()


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


## A long shape passing under the hull, going the wrong way round. Code-drawn, like
## everything else here -- what it owes the art is the silhouette and the direction.
func _cast_the_shadow() -> void:
	if _shadow != null and is_instance_valid(_shadow):
		return
	var mark := _mark("SurfaceMark")
	if mark == null:
		return
	var shape := Polygon2D.new()
	shape.name = "Shadow"
	var points := PackedVector2Array()
	for index in range(18):
		var along := float(index) / 17.0
		points.append(Vector2(lerpf(-320.0, 320.0, along), sin(along * 5.0) * 26.0 - 16.0))
	for index in range(17, -1, -1):
		var along := float(index) / 17.0
		points.append(Vector2(lerpf(-320.0, 320.0, along), sin(along * 5.0) * 26.0 + 16.0))
	shape.polygon = points
	shape.color = Color(0.04, 0.09, 0.14, 0.42)
	shape.global_position = Vector2(mark.global_position.x - 900.0, mark.global_position.y + 90.0)
	shape.z_index = 2
	mark.get_parent().add_child(shape)
	_shadow = shape
	var glide := create_tween()
	glide.tween_property(shape, "global_position:x",
		mark.global_position.x + 500.0, 4.2).set_trans(Tween.TRANS_SINE)
	glide.tween_callback(shape.queue_free)


# --- The island ----------------------------------------------------------------------------

## Reaching the far sand, which is the end of the level.
##
## ⚠ THE ARRIVAL IS SCRIPTED, AND IT HAS TO BE. The player gets here as something that swims,
## and a thing that swims cannot walk up a beach -- the fish drive on land is a flop with no
## horizontal drive at all. Reverting them in open water instead would hand them straight to
## the drowning rescue. So the level reverts them AND puts them on the sand in one breath.
func _on_island_reached(_checkpoint_id: String) -> void:
	if _arrived or director == null or not director.is_solved("L3_N2"):
		return
	_arrived = true
	# ⚠ DEFERRED, BECAUSE THIS ARRIVES FROM body_entered. Coming ashore reverts the player,
	# which builds a new body and disables the old one's shapes -- and Godot refuses to
	# change collision state while it is flushing queries. Every arrival printed two engine
	# errors and the revert was landing on a body mid-query.
	call_deferred("_land_on_the_island")


func _land_on_the_island() -> void:
	_come_ashore()
	# THE PAINTING FIRST, THE FAREWELL SECOND, then cut. Lolo leaving is the level's real
	# ending, not the painting, so it gets the last word.
	_speak(script_lines.fire("ISLAND.enter"))
	_tell_the_other_half()
	_speak(script_lines.fire("ISLAND.farewell"))
	# ⚠ AND LEVEL 4 INHERITS IT. Dilim being unguided is the point, so it has to carry its
	# own signposting with nobody to explain anything. That is a Level 4 problem created here.
	PlayerProfile.record_lolo_departed()
	_complete_level()


func _come_ashore() -> void:
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
	if not director.is_solved("L3_B0_SHORE"):
		return {"key": "practice", "obstacle": "L3_B0_SHORE",
			"target": _mark_position("WaterlineMark")}
	if not director.is_solved("L3_N1"):
		return {"key": "cross", "obstacle": "L3_N1", "target": _mark_position("CoralMark")}
	if not director.is_solved("L3_N2"):
		return {"key": "bakunawa", "obstacle": "L3_N2",
			"target": _mark_position("BakunawaMark")}
	return {"key": "island", "target": _mark_position("IslandMark")}


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
		"brush_taken": _brush_taken,
		"bangka_found": _bangka_found,
		"refills_taken": _refills_taken.duplicate(),
		"knocks": _knocks,
		"arrived": _arrived,
		"told": _told.keys(),
	}


func _restore_level_run_state(state: Dictionary) -> void:
	_live_node_obstacle = String(state.get("live_node", "L3_N1"))
	_said_underwater = bool(state.get("said_underwater", false))
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
