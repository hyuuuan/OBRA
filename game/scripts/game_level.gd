extends "res://scripts/level_base.gd"
## LEVEL 1 -- PAYYO. The furniture, and the overrides that hand it to the machine.
##
## Extended BY PATH rather than by `class_name LevelBase`, because a `--script` run does not
## register class names (LEVEL_TEMPLATE.md trap 1) and a dozen of this project's runners are
## exactly that.
##
## Everything level-agnostic moved to level_base.gd. What is left is the straw heap and its
## inside, the chest, Ang Bale with its attic and its padlock, the brass key on the nail, the
## carved figures, the cave with the hidden flower, and the bridge memory.

const FOUND_KEY := "L1_bale_key"

## What the box's plaque says when the line is the player's own thought rather than Lolo's
## voice. "Apo" is what Lolo calls them, so it is the name the player already knows.
var _bale_return := Vector2.ZERO
## The inside the camera and the placement reach are currently framed for, or null for the
## level itself. See _refresh_room_framing.
var _straw_return := Vector2.ZERO
## Whether she is standing in the heap's doorway, and so whether Down means "go in".
var _at_straw_mouth := false
## The "press E to read" prompt while it is up, so the hint bar is written to on the frame
## it changes rather than on every frame the player stands still -- and so it can be taken
## down again only while it is still the thing on the bar.
var ward_lock: WardLock2D
## The same, for the offer to open Ang Bale with the key found in the heap.
var _key_prompt := ""
@onready var cave_gate: ConceptGate2D = get_node_or_null(
	^"EnvironmentBaseplate/GameplayPlane/Gorge/CaveGate")
@onready var hidden_flower: HiddenFlower2D = get_node_or_null(
	^"EnvironmentBaseplate/GameplayPlane/Gorge/HiddenFlower")

var _memory_shown := false
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
	_speak(script_lines.fire("L1_N3.ward.fail%d" % int(turn["attempt"])))
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
	if room.has_method("disarm_the_way_out"):
		room.call("disarm_the_way_out")
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
func _on_straw_key_taken() -> void:
	_speak(script_lines.fire("L1_N2.key"))
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
			_speak(script_lines.fire("L1_N2.pragmatist.solved"))
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
			script_lines.set_flag("straw_scattered")
			Telemetry.record_event("persistent_effect", {
				"level_id": LevelManager.current_level_id,
				"obstacle_id": "L1_N2", "effect": "straw_scattered",
			})
			_speak(script_lines.fire("L1_N2.protector.solved"))
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
	_speak(script_lines.fire("L1_N2.artist.pass2"))
	await get_tree().create_timer(1.4, false).timeout
	_speak(script_lines.fire("L1_N2.artist.pass3"))
	# What the page is FOR. Node 3's Artist route reads this flag, so the patient player
	# arrives already knowing where to look.
	script_lines.set_flag("knows_about_key")
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
			_speak(script_lines.fire("L1_N3.ward.solved"))
		"protector":
			# THE ONE COST THAT LEAVES THIS LEVEL. Cutting the hasp creases what is inside,
			# and the player finds out in Pista rather than here: the seam runs through the
			# painted street and Hidden Flower 2 sits on the damaged side of it.
			script_lines.set_flag("canvas_2_creased")
			PlayerProfile.record_canvas_damage("canvas_2_pista")
			Telemetry.record_event("persistent_effect", {
				"level_id": LevelManager.current_level_id,
				"obstacle_id": "L1_N3", "effect": "canvas_2_creased",
				"cross_level_effect": "L2_PISTA.painting.creased",
			})
			_speak(script_lines.fire("L1_N3.protector.solved"))


## Over the thatch and in under the eaves. The halipan are what make this the way in rather
## than the posts, and the attic is where she left the key.
##
## A player who combed the straw at Node 2 already knows to look on a nail; one who did not
## is searching a dark granary for something nobody mentioned. Same room, different length.
func _into_the_attic() -> void:
	_speak(script_lines.fire("L1_N3.artist.attic"))
	var search := 1.6
	if script_lines.is_flag_set("knows_about_key"):
		search *= float(director.obstacle("L1_N3")
			.get("routes", {})
			.get("artist", {})
			.get("search_time_modifier_if_flag", {})
			.get("knows_about_key", 1.0))
	await get_tree().create_timer(search, false).timeout
	_speak(script_lines.fire("L1_N3.attic.found"))
	await get_tree().create_timer(1.2, false).timeout
	_speak(script_lines.fire("L1_N3.artist.photo"))
	Telemetry.record_event("route_reward", {
		"level_id": LevelManager.current_level_id,
		"obstacle_id": "L1_N3", "reward": "photograph_unnamed_woman",
		"knew_about_key": script_lines.is_flag_set("knows_about_key"),
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
	if room.has_method("disarm_the_way_out"):
		room.call("disarm_the_way_out")
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
func _on_painting_taken() -> void:
	announce_acquisition("Pista",
		"Lola's second canvas. The way into the next place.",
		BaleInterior2D.PISTA_ART)
	_speak(script_lines.fire("L1_N3.canvas.taken"))
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
func _on_cave_refused(_concept: String, hint: String) -> void:
	_speak_on_arrival("L1_N1.cave")
	if hint_bar != null:
		hint_bar.show_hint(hint, Lolo.SPEAKER, 4.0)
	else:
		status_label.text = hint


func _on_cave_opened(_concept: String) -> void:
	if hidden_flower != null and is_instance_valid(hidden_flower):
		hidden_flower.reveal()
	_speak_on_arrival("L1_N1.cave.open")


## The hidden flower in the gorge cave, which is the one thing in Payyo a player can miss
## entirely and the one thing that had no acknowledgement at all.
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


# --- Handing Payyo to the machine ---------------------------------------------------
#
# Every override below is a spot where level_base.gd used to name Level 1 outright.


func level_config_path() -> String:
	return "res://config/level_01.json"


func dialogue_path() -> String:
	return "res://config/dialogue_l1.json"


## The gorge's node. Payyo is the reason the base cannot resolve this itself.
func _resolve_level_nodes() -> void:
	dialogue_node = get_node_or_null(
		^"EnvironmentBaseplate/GameplayPlane/Gorge/DialogueNode") as DialogueNode2D


func _dialogue_node_obstacle_id() -> String:
	return "L1_N1"


func _build_level_furniture() -> void:
	# Ang Bale's padlock. It draws nothing and sits nowhere -- it is a measurement, not a
	# prop -- so it is built here beside the director rather than authored into the scene.
	# level_01.json has declared L1_N3's Pragmatist route as `ward_matching_sequence` since
	# the route existed; until now nothing read that, the route was a plain Unlock tag
	# check, and WardLock2D was a class with a unit test and no caller.
	ward_lock = WardLock2D.new()
	ward_lock.name = "WardLock"
	add_child(ward_lock)

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
	_wire_the_bulul()


## Ang Bale's padlock judges the STROKES of a drawn key, not its class.
func _extra_refusals(entity_id: String, strokes: Array) -> bool:
	return _ward_refuses(entity_id, strokes)


## Node 2 opens the heap; Node 3 opens the chest. Both own their own words, which is why
## the generic ".solved" line must not also fire for them.
func _on_route_solved(obstacle_id: String, route: String) -> bool:
	if obstacle_id == "L1_N2":
		_search_the_straw(route)
		return true
	if obstacle_id == "L1_N3":
		_open_the_baul(route)
		return true
	return false


## Down, in the heap's doorway, is "go in". Bound nowhere else in this level.
func _handle_level_input(event: InputEvent) -> bool:
	if event.is_action_pressed("move_down") and _at_straw_mouth:
		_on_straw_entered()
		return true
	return false


func _interact_with_level() -> bool:
	return _use_the_found_key()


func _level_physics(anchor_position: Vector2) -> void:
	_offer_the_found_key()
	# Crossing the far lip is what earns the memory, not choosing the route that would
	# have earned it: the reward is for having rebuilt her bridge and walked over it.
	#
	# 3660 since the level was stretched: the gorge's far lip moved with Terrace5. It was
	# 2980, which after the stretch is the middle of the gorge -- so the memory fired while
	# the player was still falling into it.
	if anchor_position.x > 3660.0:
		_show_memory_if_earned()


## The cave, and the one optional collectible behind it. Wired before the base's own
## dialogue-node wiring, which is the order it ran in when this was one file.
func _wire_dialogue_node() -> void:
	# THE FLOWER SAID NOTHING. `collected` has been emitted since the flower existed and
	# nothing in the level had ever connected it: the one optional collectible in Payyo was
	# picked up in silence, with a rise-and-fade on the sprite and no other acknowledgement
	# anywhere. It is the hardest thing in the level to find.
	if hidden_flower != null and not hidden_flower.collected.is_connected(_on_flower_found):
		hidden_flower.collected.connect(_on_flower_found)
	if cave_gate != null and hidden_flower != null:
		# Re-asked now that the level is in the run-state group: at the flower's own _ready
		# there was nothing to ask, so it fell back to the permanent profile and concluded it
		# had already been picked. See HiddenFlower2D.refresh_for_run.
		if hidden_flower.has_method("refresh_for_run"):
			hidden_flower.refresh_for_run()
		# The gate is the only thing that may reveal the flower, so a player who has
		# not learned Illumination sees a dark cave rather than a prize behind glass.
		if cave_gate.can_pass():
			hidden_flower.reveal()
		cave_gate.connect(&"passage_allowed", _on_cave_opened)
		cave_gate.connect(&"passage_blocked", _on_cave_refused)
	super()
