class_name Bakunawa2D
extends Node2D
## DAGAT'S ONE ENCOUNTER. Blind, frantic, and going over the same stretch of water again and
## again because it has lost something.
##
## ⚠ IT IS AN AUTHORED ENCOUNTER, NOT ONE OF THE FIFTY. The player never draws it and the
## recogniser never sees it -- the same framing the aswang gets in Dilim. It is also not a
## mythology mechanic: the game never explains it, never names what its eyes remind Lolo of,
## and never mentions the moon, which is the association a reader brings.
##
## THREE RESOLUTIONS, ONE CREATURE. Helping it see, it finds what it lost. Avoiding it, it
## keeps searching. Fighting it, you win against something that was never attacking you on
## purpose -- so it is **subdued or exhausted, never killed**, and the cost of that route is
## that nothing was healed.
##
## WHAT IT OWES THE REST OF THE GAME:
##   * `apply_tool_hit` -- the same contract Destructible2D publishes, which is what makes
##     every drawn weapon work on it without this file knowing what a sword is. The five
##     `strike` classes already differ in reach (swing 96px, boomerang 320, cannon 640) and
##     now differ in bite as well, which is the design's "more than damage".
##   * `sees()` -- the stealth rule as a real query rather than a lighting effect. Its cones
##     are drawn because they ARE the rule.
##   * `Coils`, a body across the channel, which is what "it moves aside" means mechanically.
##
## PAINTED NOW, AND THE STATES DID NOT MOVE. It was code-drawn while the art was outstanding
## and the states were chosen to be the ones the design's asset list asks for -- so the frames
## dropped into the same machine and `sees()`, `apply_tool_hit` and the coils are untouched.
##
## ⚠ THE SWEEP IS STILL DRAWN BY HAND, ON PURPOSE. It is not decoration that the art could
## replace: it IS the stealth rule, the thing `sees()` answers about, and a cone the player
## cannot see is a rule they learn by being reset.

enum State { SEARCHING, FOLLOWING, CALM, FIGHTING, SUBDUED }

## It has noticed something it should not have. The level resets the player.
signal saw_the_player
## It has found what it was looking for, and is holding it out.
signal gift_offered
## Worn out. Still blind, still searching, swimming off.
signal went_quiet(how: String)
## A blow landed, and how many it has taken of how many it can.
signal hit_taken(hits: int, needed: int)

## Long and low: this is a body the player swims the length of, not a sprite they stand next
## to. The arena is 900 wide, so it fills most of it and leaving is a real exit.
const BODY_LENGTH := 700.0
const BODY_DEPTH := 130.0
const SEGMENTS := 14

const BEAM_SHADER := preload("res://shaders/flashlight_beam.gdshader")
const CONE_LENGTH := 460.0
const CONE_HALF_ANGLE := 0.42
## How fast the sweep travels, and how far either side of straight ahead it goes. Slow enough
## that a player can read it and time a run, which is the whole of the stealth resolution.
##
## ⚠ AND NARROW ENOUGH TO LEAVE A SHADOW UNDER IT. At 1.05 either side at 0.55 a second, the
## two cones between them reached to within six degrees of straight down: the dark under its
## belly was 34 pixels of seabed, unmarked, under a 700-pixel body -- and a swimmer along the bed
## makes about 100 px/s, so there was no moment at which a run straight through its reach was
## unseen, and a run from the edge to the shadow had a 1.6-second window in every 7.6. On paper
## a stealth resolution; played, a wall. At 0.90 and 0.38 the beam never comes within fifteen
## degrees of straight down -- ninety pixels of the bed to wait in, in plain sight as the one
## place the light never goes -- and each half of the crossing had a window of three seconds in
## every nine and a half at the old reach (see DEEP_REACH for the reach now). run_bakunawa_probe
## searches for the way past at a slow swimmer's own speed.
const SWEEP_SPEED := 0.38
const SWEEP_LIMIT := 0.90

## ⚠ DOWN IN THE WATER ITS LIGHT REACHES THE WHOLE COLUMN, AND BOTH BEAMS LOOK THE SAME WAY.
## Kent: "i can get pass through it easily like the light is not doing anything". He could: the
## beam reached CONE_LENGTH from a creature lying 950 px under the surface, so once the stealth
## route opened the coils, everything above y ~1050 was out of its reach -- a swimmer along the
## top was never seen and finished the level in thirteen seconds. Longer alone did not close it.
## The two beams pointed opposite ways, back to back, so when one looked up the other looked
## down and neither ever looked straight up: a chimney of dark over it that, at this reach,
## still let three blind runs in four along the surface through. Down here the beams are two eyes. They lift together,
## past straight up, and dip together, never quite to straight down -- so the shadow under its
## belly the design keeps as the place to wait is still there, and there is no other. When it
## looks up, keep low; when it looks down, go high. run_bakunawa_probe measures every depth.
const DEEP_REACH := 1000.0
const LOOK_UP := 1.2
## ⚠ 0.45, AND THAT IS THE WAY PAST UNDER IT. Kent: "there should be space below the sea serpent
## where we can dodge the lights and not get hit by their hitbox". At 0.9 the two beams dipped to
## within a few degrees of straight down and the creature lay with its belly on the bed, so the
## dark under it was a sliver no swimmer could stand in. It is lifted off the bed now (see the
## scene) and its light dips only this far: under its belly, along the bottom, the light never
## reaches -- and the stretch either side of it is lit only while it is looking down.
const LOOK_DOWN := 0.6
## ⚠ AT THE SURFACE IT KEEPS THE SHORT, BACK-TO-BACK SWEEP. Staged for the boat it lies just
## under the hull, so the boat's lane is level with it and within a thousand pixels of it all the
## way across: with the deep beam there, the boat could not time a way past from any point in the
## cycle (run_bakunawa_probe, measured). The old sweep leaves it one, and the probe holds that.
var _surfaced := false

const MANIFEST := "res://assets/Level3/dagat.json"
## The creature is delivered at 1672px and the arena is 900 wide. Scaled by its own length so
## the number here is the one a designer would measure off the scene.
@export var target_length: float = 940.0
## ⚠ THE WORLD Y RANGE THE CHANNEL SEALS, from above the waterline to under the seabed. The
## coils used to be a fixed 1200 tall around the creature, which is a seal only while the
## creature happens to sit in the middle of the column: when the seabed moved down and the
## creature with it, a 350px gap opened under the surface and the channel could be swum over
## the top of -- the exact bug the 1200 was chosen to close. They are fitted to this span
## now, wherever the creature is staged. ZERO keeps the old fixed box.
@export var seal_span := Vector2.ZERO
var _coil_block: CollisionShape2D

## ⚠ FIFTEEN, AND EACH BLOW IS ONE. Kent: "it should take maybe fifteen hits before they swim
## away". Three was over before the fight had been felt, and with fractional bites a sword needed
## four swings and a cannon three, which no player could see. A blow is a blow now -- the five
## still differ in REACH, which is the difference a player feels -- and the meter over it counts
## them down. Getting thrown off does not undo them: see enter_fight.
const HITS_TO_SUBDUE := 15
## The weapons it answers to. Read as a list now, not as damage -- see HITS_TO_SUBDUE.
const BITE := {
	"cannon": 1.0, "anvil": 1.0, "axe": 1.0, "sword": 1.0, "boomerang": 1.0,
}
## How long a landed blow shows, in red, and how hard it jolts the body.
const HURT_SECONDS := 0.32
const HURT_JOLT := 14.0
## The look of it from above the water: a shape, not a creature. See set_silhouette.
const SILHOUETTE := Color(0.02, 0.05, 0.11, 0.9)
## How fast it goes after a light that is leading it, at most, and how close is close enough.
const GUIDE_SPEED := 230.0
const GUIDE_STOP := 50.0

@export var treasure_offset := Vector2(-260.0, 220.0)

var _state: int = State.SEARCHING
var _sweep := 0.0
var _sweep_direction := 1.0
var _thrash := 0.0
var _hits := 0.0
var _follow_target := Vector2.ZERO
var _coils: StaticBody2D
var _hurtbox: Area2D
var _skin: Sprite2D
var _clips: Dictionary = {}
var _clip := "searching"
var _frame := 0
var _clock := 0.0

## ⚠ IT MOVES. Kent: "the bakunawa should move". It was a picture with a beam: placed once and
## still for the whole encounter, though Lolo's first line about it is "back and forth over the
## same stretch, over and over". It drifts that stretch now -- slowly, along x about the place it
## was set down, with a slow rise and fall -- and faster while it fights. The sweep, sees(), the
## coils and the hurtbox are all children or read off global_position, so the rule travels with
## it; run_bakunawa_probe measures the way past against the moving creature.
const PATROL_REACH := 110.0
const PATROL_PERIOD := 22.0
const FIGHT_PERIOD := 12.0
const BOB := 16.0
const BOB_PERIOD := 5.5
var _home := Vector2.ZERO
var _homed := false
var _drift_clock := 0.0

## ⚠ AND IT GOES. "There are cases where it should go away": found what it lost, or worn out, it
## stayed coiled where it was for the rest of the level -- its own comment said it "swims off"
## and nothing made it. Now it holds a moment and swims away down into the dark, fading as it goes.
## Avoided, it does not: that resolution's whole point is that it keeps searching.
## ⚠ AWAY, AND SEEN TO GO. It sank off down-right and faded inside five seconds, mostly while
## Lolo's line was still up -- Kent: "it should swim away". It turns and swims off along the
## bottom, a good way, at a swimming pace, and only fades at the end of it.
const LEAVE_BY := Vector2(1500.0, 240.0)
const LEAVE_SECONDS := 7.5
var _leaving := false
var _gone := false
var _leave: Tween
## Which way it is heading as it goes, so it faces that way.
var _leave_heading := 1.0

## A blow's red, counting down; and the jolt it gave, decaying.
var _hurt := 0.0
## 0 in the water with the player, 1 seen from above it. Eased, so it does not snap.
var _silhouette := 0.0
var _silhouette_wanted := 0.0
## Led by a light rather than sent to a place. See be_guided.
var _guided := false
## Whatever it took with it when it was fought off. See carry_away.
var _carried: Sprite2D
var _meter: _HitMeter


func _ready() -> void:
	z_index = 4
	# First, so the creature's body is drawn over its own light.
	_build_beams()
	_load_clips()
	_build_bodies()
	_build_skin()
	_meter = _HitMeter.new()
	_meter.name = "HitMeter"
	_meter.position = Vector2(0.0, -drawn_size().y * 0.5 - 30.0)
	_meter.visible = false
	add_child(_meter)
	set_process(true)
	_home = global_position
	_homed = true


## ⚠ THE CLIPS ARE THE SORT tools/build_dagat.py DID BY EYE POSITION, not by filename. Twenty
## three delivered poses, and which way the creature faces and whether its head is reared are
## both readable from where the bright eye sits inside its own bounding box. See that file.
func _load_clips() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var groups: Dictionary = (parsed as Dictionary).get("groups", {}) if parsed is Dictionary else {}
	for clip in ["searching", "thrashing", "turned"]:
		var frames: Array[Texture2D] = []
		for path_value: Variant in (groups.get("bakunawa/%s" % clip, {}) as Dictionary).get("frames", []):
			var texture := load(String(path_value)) as Texture2D
			if texture != null:
				frames.append(texture)
		if not frames.is_empty():
			_clips[clip] = frames


func _build_skin() -> void:
	if _clips.is_empty():
		return
	_skin = Sprite2D.new()
	_skin.name = "Skin"
	_skin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_skin.centered = true
	_skin.texture = (_clips["searching"] as Array)[0]
	var native := maxf(1.0, float(_skin.texture.get_width()))
	_skin.scale = Vector2.ONE * (target_length / native)
	add_child(_skin)


func _build_bodies() -> void:
	# THE CHANNEL. "It moves aside and you can continue" is this body being switched off.
	_coils = StaticBody2D.new()
	_coils.name = "Coils"
	var block := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	# Tall enough to seal the whole column. At 1100 it left a gap at the waterline and the
	# channel could be swum over the top of, which is a barrier that is not one.
	box.size = Vector2(160.0, 1200.0)
	block.shape = box
	block.position = Vector2(BODY_LENGTH * 0.5 - 40.0, 0.0)
	_coils.add_child(block)
	add_child(_coils)
	_coil_block = block
	_fit_the_coils()

	# ⚠ collision_layer 1, AND AN AREA. UtilityObject._reachable_targets runs a shape query
	# with collide_with_areas and mask 1, then walks up the parent chain looking for something
	# with apply_tool_hit. On any other layer every drawn weapon swings straight through it.
	_hurtbox = Area2D.new()
	_hurtbox.name = "Hurtbox"
	_hurtbox.collision_layer = 1
	_hurtbox.collision_mask = 0
	_hurtbox.monitoring = false
	var hit := CollisionShape2D.new()
	var capsule := RectangleShape2D.new()
	capsule.size = Vector2(BODY_LENGTH, BODY_DEPTH * 1.4)
	hit.shape = capsule
	_hurtbox.add_child(hit)
	add_child(_hurtbox)


# --- What the level tells it -----------------------------------------------------------

## ⚠ ONE CREATURE, TWO STAGINGS, and the design calls this the most expensive single item in
## the level. From the boat it is mostly surface and silhouette; from underwater the player is
## inside its space. Same encounter, same three resolutions, same sweep -- what differs is
## where in the water column it is, and therefore what the player is looking at.
##
## Moved rather than duplicated. A second creature at the surface would be a second set of
## states to keep in step with this one, and they would drift.
func stage_at(depth_y: float, surfaced: bool = true) -> void:
	global_position.y = depth_y
	_home.y = depth_y
	_surfaced = surfaced
	_fit_the_coils()
	_sync_beams()


## Back to a place and a fresh search, as it was before anything happened to it -- what a
## checkpoint restore to before the encounter's end asks of it. Any leaving is called off.
## `surfaced` is the staging, as for stage_at: the run decides it, not where it was last.
func reset_to(at: Vector2, surfaced: bool = false) -> void:
	_surfaced = surfaced
	if _leave != null and _leave.is_valid():
		_leave.kill()
	_leaving = false
	_gone = false
	visible = true
	modulate.a = 1.0
	set_process(true)
	if _hurtbox != null:
		_hurtbox.collision_layer = 1
	global_position = at
	_home = at
	_homed = true
	_drift_clock = 0.0
	rotation = 0.0
	scale = Vector2.ONE
	_hits = 0.0
	_thrash = 0.0
	_hurt = 0.0
	_guided = false
	if _carried != null and is_instance_valid(_carried):
		_carried.queue_free()
	_carried = null
	_fit_the_coils()
	begin_search()


## Gone already -- a restore to after it left. No swim, no fade: it is simply not there.
func set_gone() -> void:
	if _leave != null and _leave.is_valid():
		_leave.kill()
	_be_gone()


func is_gone() -> bool:
	return _gone


func is_leaving() -> bool:
	return _leaving


## Stretch the channel's block over `seal_span`, measured from wherever the creature is now.
func _fit_the_coils() -> void:
	if _coil_block == null or seal_span == Vector2.ZERO:
		return
	var box := _coil_block.shape as RectangleShape2D
	box.size = Vector2(box.size.x, seal_span.y - seal_span.x)
	_coil_block.position = Vector2(_coil_block.position.x,
		(seal_span.x + seal_span.y) * 0.5 - global_position.y)


func begin_search() -> void:
	_state = State.SEARCHING
	_set_channel_open(false)
	_sync_beams()


## The Pragmatist resolution. It is still searching and still dangerous -- what changes is
## that there is now a way past, if the player stays out of the sweep.
func open_a_gap() -> void:
	_state = State.SEARCHING
	_set_channel_open(true)
	_sync_beams()


## The Artist resolution. Something is throwing light and it goes to it.
func follow_the_light(point: Vector2) -> void:
	if _state == State.SUBDUED or _state == State.CALM:
		return
	_state = State.FOLLOWING
	_follow_target = point
	_sync_beams()


## ⚠ LED, NOT SENT. Kent: "the flashlight should follow where my mouse is pointing and the sea
## serpent should follow it", home to a cave under the beach. follow_the_light sends it to one
## place and it gives up what it found when it gets there; this is asked every frame with wherever
## the light is now, it goes after it at a swimming pace, and arriving anywhere is not the end --
## the level decides when it is home (go_home). The channel is open while it is led: a wall that
## moves with a creature swimming after a light is a wall that shoves the player around.
func be_guided(point: Vector2) -> void:
	if _state == State.SUBDUED or _state == State.CALM or _gone:
		return
	if _state != State.FOLLOWING or not _guided:
		_state = State.FOLLOWING
		_guided = true
		_set_channel_open(true)
	_follow_target = point
	_sync_beams()


func is_guided() -> bool:
	return _guided and _state == State.FOLLOWING


## Home: into the cave mouth, and on into the dark of it, growing small and dim as it goes --
## and THEN it gives up what it was holding. `mouth` is where the cave opens, `inside` how far in
## it swims before it is gone.
func go_home(mouth: Vector2, inside: Vector2) -> void:
	if _leaving or _gone:
		return
	_state = State.CALM
	_guided = false
	_leaving = true
	_set_channel_open(true)
	_leave_heading = signf(inside.x - global_position.x)
	if _leave != null and _leave.is_valid():
		_leave.kill()
	_leave = create_tween()
	_leave.tween_property(self, "global_position", mouth,
		clampf(global_position.distance_to(mouth) / GUIDE_SPEED, 0.6, 3.0)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_leave.tween_property(self, "global_position", inside, 2.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_leave.parallel().tween_property(self, "scale", Vector2.ONE * 0.35, 2.4)
	_leave.parallel().tween_property(self, "modulate", Color(0.15, 0.18, 0.25, 0.0), 2.4) \
		.set_ease(Tween.EASE_IN)
	_leave.tween_callback(func() -> void:
		_be_gone()
		gift_offered.emit())


## ⚠ THE FIGHT KEEPS THE BLOWS IT HAS TAKEN. Being thrown off three times puts the player back
## at the checkpoint and the creature back on its guard -- `keep_hits` -- but taking away ten good
## blows for it would make fifteen a wall rather than a fight. Only a fresh fight starts at none.
func enter_fight(keep_hits: bool = false) -> void:
	if _state == State.SUBDUED:
		return
	_state = State.FIGHTING
	_guided = false
	if not keep_hits:
		_hits = 0.0
	if _meter != null:
		_meter.hits = int(_hits)
		_meter.queue_redraw()
	_set_channel_open(false)
	_sync_beams()


## What it swims off with when it is fought off: whatever it was searching for, held where it
## can be seen, going with it. Kent: "if we choose to fight it, it takes the treasure with them".
## `size` scales a picture drawn small -- her diary's loose page is 14 px, and under the jaw at
## its own size it was a crumb.
func carry_away(picture: Texture2D, size: float = 1.0) -> void:
	if picture == null or (_carried != null and is_instance_valid(_carried)):
		return
	_carried = Sprite2D.new()
	_carried.name = "Carried"
	_carried.texture = picture
	_carried.scale = Vector2.ONE * size
	_carried.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_carried.z_index = 1
	_carried.rotation = 0.3
	# Under its jaw, which is at the left end of the body in every clip but "turned".
	_carried.position = Vector2(-drawn_size().x * 0.36, drawn_size().y * 0.18)
	add_child(_carried)


## The size the body is drawn at, in world pixels.
func drawn_size() -> Vector2:
	if _skin == null or _skin.texture == null:
		return Vector2(BODY_LENGTH, BODY_DEPTH * 2.0)
	return _skin.texture.get_size() * _skin.scale


## ⚠ THE BODY IS A THING YOU CAN SWIM INTO. Kent: "space below the sea serpent where we can ...
## not get hit by their hitbox". An ellipse inside the drawing -- the coils fill most of the frame
## but not its corners -- so touching what you can see is touching it, and passing under its belly
## with clear water between is not.
func touches(point: Vector2) -> bool:
	if _gone or _state == State.SUBDUED or _state == State.CALM:
		return false
	var half := drawn_size() * Vector2(0.42, 0.36) * scale
	var offset := (point - global_position).rotated(-rotation)
	return pow(offset.x / half.x, 2.0) + pow(offset.y / half.y, 2.0) < 1.0


## Seen from above the water it is a shape, not a creature: the level sets this from where the
## player is. Kent: "when the player is still above water, the sea serpent should just be a
## silhouette". Eased, so a dive takes it from shadow to creature rather than switching.
func set_silhouette(on: bool) -> void:
	_silhouette_wanted = 1.0 if on else 0.0


func state() -> int:
	return _state


func hits_taken() -> float:
	return _hits


## Put back the blows a fight had landed, after a restore that started it again.
func restore_hits(value: float) -> void:
	_hits = clampf(value, 0.0, float(HITS_TO_SUBDUE) - 1.0)
	if _meter != null:
		_meter.hits = int(_hits)
		_meter.queue_redraw()


func treasure_point() -> Vector2:
	return global_position + treasure_offset


## How far its light reaches, staged where it is now. See DEEP_REACH.
func reach() -> float:
	return CONE_LENGTH if _surfaced else DEEP_REACH


## The two ways its light points this moment: back to back at the surface, side by side below.
func facings() -> Array[float]:
	if _surfaced:
		return [_sweep, _sweep + PI]
	return [_sweep, PI - _sweep]


## The sweep's ends, up (negative) and down, staged where it is now.
func sweep_range() -> Vector2:
	if _surfaced:
		return Vector2(-SWEEP_LIMIT, SWEEP_LIMIT)
	return Vector2(-LOOK_UP, LOOK_DOWN)


func _set_channel_open(open: bool) -> void:
	if _coils != null:
		_coils.process_mode = Node.PROCESS_MODE_DISABLED if open else Node.PROCESS_MODE_INHERIT
		for child in _coils.get_children():
			if child is CollisionShape2D:
				(child as CollisionShape2D).set_deferred(&"disabled", open)


# --- The stealth rule, as a query rather than a light ------------------------------------

## Is that point in the sweep? `lit` is the design's own nice interaction: a player who drew a
## flashlight and then chose to sneak has made the encounter harder for themselves, and the
## design says to allow that rather than prevent it.
func sees(point: Vector2, lit: bool = false) -> bool:
	if _state == State.SUBDUED or _state == State.CALM or _gone:
		return false
	# Led by a light, it is looking at the light.
	if _state == State.FOLLOWING and _guided:
		return false
	var offset := point - global_position
	if lit and offset.length() < CONE_LENGTH * 1.6:
		return true
	if offset.length() > reach():
		return false
	for facing in facings():
		var heading := Vector2(cos(facing), sin(facing))
		# ⚠ absf. Vector2.angle_to is SIGNED, so an unsigned test is true for every point on
		# one side of the heading and for the whole of the aft cone -- which made the sweep
		# see everything, everywhere, including straight down where the design says the way
		# past is. A stealth rule that is always true reads in a report as a stealth rule
		# that works.
		if absf(heading.angle_to(offset.normalized())) < CONE_HALF_ANGLE:
			return true
	return false


# --- The fight ----------------------------------------------------------------------------

## The Destructible2D contract, so every drawn weapon works without this file knowing what a
## sword is. It bites ONLY while fighting: hitting a creature that is searching for something
## it lost, before the player has said they mean to, is not a route -- it is an accident the
## game should not let them have.
func apply_tool_hit(tool: String, _impulse: float, _actor: Node2D) -> bool:
	if _state != State.FIGHTING or not BITE.has(tool):
		return false
	_hits += float(BITE[tool])
	_thrash = 0.5
	# ⚠ A HIT SHOWS, IN RED. Kent: "the fight ... should indicate when he is hit (like a red flash
	# or something)". It flashed white for a tenth of a second, which on a storm-dark sea read as
	# lightning. Red now, longer, with a jolt through the body and the meter over it ticking down.
	_hurt = HURT_SECONDS
	if _meter != null:
		_meter.hits = int(_hits)
		_meter.flash = 1.0
		_meter.queue_redraw()
	_sync_beams()
	hit_taken.emit(int(_hits), HITS_TO_SUBDUE)
	# Every hit, the last one too: it is subdued and swims off, never felled, so it has no fall.
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio != null:
		audio.call("play_sfx", &"foe_hit")
	if _hits >= float(HITS_TO_SUBDUE):
		_subdue()
	return true


func accepts_tool(tool: String) -> bool:
	return _state == State.FIGHTING and BITE.has(tool)


func _subdue() -> void:
	# ⚠ SUBDUED, NEVER KILLED. It swims off still blind and still searching, and that is the
	# cost of this route: the player won, and nothing was healed. Killing it would have hidden
	# exactly that.
	_state = State.SUBDUED
	_set_channel_open(true)
	_sync_beams()
	went_quiet.emit("FOUGHT")
	_leave_after(1.6)


## The Artist ending. It found what it lost and is holding it out.
func give_it_up() -> void:
	_state = State.CALM
	_set_channel_open(true)
	_home = global_position
	_sync_beams()
	gift_offered.emit()
	# After what it found has been given: the corner comes up and goes to the apo, and the
	# flower after it, over about five seconds.
	_leave_after(6.0)


func _leave_after(seconds: float) -> void:
	if _leaving or _gone:
		return
	_leaving = true
	_leave_heading = signf(LEAVE_BY.x)
	_leave = create_tween()
	_leave.tween_interval(seconds)
	_leave.tween_property(self, "global_position", global_position + LEAVE_BY, LEAVE_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_leave.parallel().tween_property(self, "modulate:a", 0.0, LEAVE_SECONDS * 0.35) \
		.set_delay(LEAVE_SECONDS * 0.65)
	_leave.tween_callback(_be_gone)


func _be_gone() -> void:
	_leaving = false
	_gone = true
	visible = false
	set_process(false)
	_set_channel_open(true)
	if _hurtbox != null:
		_hurtbox.collision_layer = 0
	if _meter != null:
		_meter.visible = false


# --- Per frame -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_thrash = maxf(0.0, _thrash - delta)
	_hurt = maxf(0.0, _hurt - delta)
	_silhouette = move_toward(_silhouette, _silhouette_wanted, delta * 2.5)
	match _state:
		State.SEARCHING, State.FIGHTING:
			var ends := sweep_range()
			_sweep += SWEEP_SPEED * _sweep_direction * delta
			if _sweep < ends.x or _sweep > ends.y:
				_sweep = clampf(_sweep, ends.x, ends.y)
				_sweep_direction = -_sweep_direction
			_drift(delta)
		State.FOLLOWING:
			var to_light := _follow_target - global_position
			_sweep = lerp_angle(_sweep, to_light.angle(), minf(1.0, delta * 2.0))
			if _guided:
				# After the light at a swimming pace, slowing as it gets there, and holding
				# there with a slow rise and fall while the light holds still.
				if to_light.length() > GUIDE_STOP:
					var speed := minf(GUIDE_SPEED, to_light.length() * 1.6)
					global_position += to_light.normalized() * speed * delta
				_drift_clock += delta
				rotation = lerp_angle(rotation, clampf(to_light.x * 0.0004, -0.08, 0.08), delta * 2.0)
				_home = global_position
				_fit_the_coils()
			elif to_light.length() > 24.0:
				global_position += to_light.normalized() * 120.0 * delta
			else:
				# It got there. Announcing this itself keeps the level from having to poll a
				# distance every frame to find out whether a creature has arrived.
				give_it_up()
		State.CALM, State.SUBDUED:
			_sweep = lerp_angle(_sweep, 0.0, minf(1.0, delta * 1.2))
	if _meter != null:
		_meter.visible = _state == State.FIGHTING and not _gone
		if _meter.flash > 0.0:
			_meter.flash = maxf(0.0, _meter.flash - delta * 3.0)
			if _meter.visible:
				_meter.queue_redraw()
	_animate(delta)
	_advance_beam_water(delta)
	_sync_beams()


## Back and forth over its stretch, and up and down a little, never far from where it was set.
## A rate rather than a clock it is handed, so a restore that puts it back mid-swing picks up
## from where it is.
func _drift(delta: float) -> void:
	if not _homed:
		return
	_drift_clock += delta
	var period := FIGHT_PERIOD if _state == State.FIGHTING else PATROL_PERIOD
	var along := sin(_drift_clock * TAU / period)
	global_position = _home + Vector2(along * PATROL_REACH,
		sin(_drift_clock * TAU / BOB_PERIOD) * BOB)
	# Leaning into the way it is going, a little.
	rotation = cos(_drift_clock * TAU / period) * 0.035
	_fit_the_coils()


## WHICH CLIP, AND HOW FAST. The states were named for what the creature is DOING, so this is
## a lookup rather than a decision -- and the two that are over (calm, subdued) hold a frame
## instead of looping, because a creature that has stopped should stop moving.
func _animate(delta: float) -> void:
	if _skin == null:
		return
	var wanted := "searching"
	var fps := 5.0
	match _state:
		State.FIGHTING:
			wanted = "thrashing"
			fps = 9.0
		State.FOLLOWING:
			# Turned toward the light if it is off to the right, which is the only time this
			# creature faces that way.
			wanted = "turned" if _follow_target.x > global_position.x else "searching"
			fps = 6.0
		State.CALM, State.SUBDUED:
			# Still while it rests; swimming again as it goes -- and facing the way it goes.
			fps = 5.0 if _leaving else 1.6
			if _leaving and _leave_heading > 0.0:
				wanted = "turned"
	if not _clips.has(wanted):
		wanted = "searching"
	if wanted != _clip:
		_clip = wanted
		_frame = 0
		_clock = 0.0
	var frames: Array = _clips.get(_clip, [])
	if frames.is_empty():
		return
	_clock += delta
	var step := 1.0 / maxf(0.01, fps)
	while _clock >= step:
		_clock -= step
		_frame = (_frame + 1) % frames.size()
	_skin.texture = frames[_frame]
	var tint := Color.WHITE
	if _state == State.SUBDUED:
		tint = Color(0.55, 0.6, 0.68)
	# From above the water, a shape. Under it, the creature.
	tint = tint.lerp(SILHOUETTE, _silhouette)
	# ⚠ A HIT SHOWS, AND IT SHOWS OVER EVERYTHING ELSE -- a blow struck from the boat lands on
	# the silhouette too. See apply_tool_hit.
	if _hurt > 0.0:
		var share := _hurt / HURT_SECONDS
		tint = tint.lerp(Color(2.2, 0.32, 0.28, tint.a), share)
		_skin.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * HURT_JOLT * share
	else:
		_skin.position = Vector2.ZERO
	_skin.modulate = tint
	# Whatever it took goes dark with it.
	if _carried != null and is_instance_valid(_carried):
		_carried.modulate = Color.WHITE.lerp(SILHOUETTE, _silhouette)
		_carried.flip_h = wanted == "turned"
		_carried.position.x = absf(_carried.position.x) * (1.0 if wanted == "turned" else -1.0)


## ⚠ ITS LIGHT IS A FLASHLIGHT'S, THE PLAYER'S OWN SHADER. Kent: "the light of bakunawa is weird
## like its nothing similar to how light is presented in a flashlight". It was a wedge cut by hand
## out of polygons, coming to a point in the creature and stopping dead on a round arc at the
## rule's own radius. Now it opens from a lit lens and goes out with distance, with no edge at all,
## and its specks stay in the water the way the player's do.
##
## ⚠ WHAT `sees()` ANSWERS ABOUT DOES NOT MOVE. The angle and the reach are the rule's, and this
## is still the only way a player can see them -- a boundary they cannot see is one they learn by
## being put back. Recorded on an earlier, fainter beam: caught four times in twenty seconds by a
## light they could barely see, which is why the numbers below are not the hand flashlight's.
const BEAM_LENS_X := 20.0  # where the shader puts the lens, along its quad
## ⚠ DRAWN WIDER AND LONGER THAN THE RULE, going out only past it. A light that stops exactly on
## the boundary teaches a player that its edge is the edge of the danger, and they are caught a
## pixel outside it. This way the faint fringe lies outside the rule, so "out of the light" is
## true whenever it looks true.
const BEAM_WIDER := 1.18
const BEAM_LONGER := 1.3
## ⚠ THE HAND FLASHLIGHT'S FALLOFF WOULD HIDE THE RULE. It lights a few hundred px at most; left at
## its numbers this one is 3% at the end of what it can see. `carry` keeps the light going out
## with distance but not gone, `side_from` holds the sides on until nearly the rule's edge (still
## two fifths lit there), and `gain` is what a storm-dark sea needs.
const BEAM_GAIN := 2.0
const BEAM_CARRY := 0.4
const BEAM_SIDE_FROM := 0.6
const BEAM_SEARCHING := Color(1.0, 0.94, 0.73)
## A fight is the same lamp gone red, so a player can tell at a glance it has turned on them.
const BEAM_FIGHTING := Color(1.0, 0.45, 0.32)
const BEAM_FIGHTING_WATER := 0.25

var _beams: Array[Polygon2D] = []
var _beam_material: ShaderMaterial
var _beam_length := -1.0
var _beam_fighting := false
var _beam_clock := 0.0
var _beam_frame := -1


## ⚠ TWO QUADS, ONE MATERIAL, AND NOT ONE _draw(). The shader shapes the light from where it lies
## along its own quad, so each beam needs a quad turned its own way. There are always two
## (`facings`), and a material on them does not touch the creature's sprite or its meter.
func _build_beams() -> void:
	_beam_material = ShaderMaterial.new()
	_beam_material.shader = BEAM_SHADER
	_beam_material.set_shader_parameter(&"half_angle", CONE_HALF_ANGLE * BEAM_WIDER)
	_beam_material.set_shader_parameter(&"underwater", 1.0)  # it is never anywhere else
	_beam_material.set_shader_parameter(&"gain", BEAM_GAIN)
	_beam_material.set_shader_parameter(&"carry", BEAM_CARRY)
	_beam_material.set_shader_parameter(&"side_from", BEAM_SIDE_FROM)
	_beam_material.set_shader_parameter(&"lamp", Vector3(BEAM_SEARCHING.r, BEAM_SEARCHING.g,
		BEAM_SEARCHING.b))
	for index in range(2):
		var beam := Polygon2D.new()
		beam.name = "Beam%d" % index
		beam.color = Color.WHITE
		beam.material = _beam_material
		add_child(beam)
		_beams.append(beam)
	_sync_beams()


## Puts the light where the rule is, this moment: lens on the point `sees()` measures from, turned
## the way it is looking, as long as it can see, and out altogether when it is not looking.
func _sync_beams() -> void:
	var lit := _state == State.SEARCHING or _state == State.FIGHTING
	for beam in _beams:
		beam.visible = lit
	if not lit or _beams.is_empty():
		return
	var length := snappedf(reach() * BEAM_LONGER, 2.0)
	if not is_equal_approx(length, _beam_length):
		_beam_length = length
		var half_width := 8.0 + length * tan(CONE_HALF_ANGLE * BEAM_WIDER)
		var quad := PackedVector2Array([Vector2(0.0, -half_width),
			Vector2(BEAM_LENS_X + length, -half_width), Vector2(BEAM_LENS_X + length, half_width),
			Vector2(0.0, half_width)])
		for beam in _beams:
			beam.polygon = quad
		_beam_material.set_shader_parameter(&"beam_length", length)
	var fighting := _state == State.FIGHTING
	if fighting != _beam_fighting:
		_beam_fighting = fighting
		var lamp := BEAM_FIGHTING if fighting else BEAM_SEARCHING
		_beam_material.set_shader_parameter(&"lamp", Vector3(lamp.r, lamp.g, lamp.b))
		# ⚠ The shader takes the far end of an underwater beam toward blue, which turns red purple.
		_beam_material.set_shader_parameter(&"underwater",
			BEAM_FIGHTING_WATER if fighting else 1.0)
	var ways := facings()
	for index in range(_beams.size()):
		_beams[index].rotation = ways[index]
		_beams[index].position = Vector2(-BEAM_LENS_X, 0.0).rotated(ways[index])


## The water moves through the light at the game's stepped rate, and not at all under Reduce Motion.
func _advance_beam_water(delta: float) -> void:
	_beam_clock += delta
	var frame := 0 if Motion.reduced() else int(_beam_clock * Motion.PIXEL_FPS)
	if frame != _beam_frame:
		_beam_frame = frame
		_beam_material.set_shader_parameter(&"phase", float(frame) / Motion.PIXEL_FPS)


## One heart for each blow Bakunawa can still take. The spent slot flashes on impact.
class _HitMeter extends Node2D:
	var needed := HITS_TO_SUBDUE
	var hits := 0
	var flash := 0.0

	const SPACING := 23.0
	var _heart := PackedVector2Array([
		Vector2(-8, -4), Vector2(-6, -4), Vector2(-6, -7), Vector2(-2, -7),
		Vector2(-2, -5), Vector2(2, -5), Vector2(2, -7), Vector2(6, -7),
		Vector2(6, -4), Vector2(8, -4), Vector2(8, 1), Vector2(6, 1),
		Vector2(6, 3), Vector2(4, 3), Vector2(4, 5), Vector2(2, 5),
		Vector2(2, 7), Vector2(-2, 7), Vector2(-2, 5), Vector2(-4, 5),
		Vector2(-4, 3), Vector2(-6, 3), Vector2(-6, 1), Vector2(-8, 1),
	])
	const OUTLINE := Color(0.08, 0.03, 0.07)
	const FULL := Color(1.0, 0.37, 0.39)
	const SPENT := Color(0.52, 0.35, 0.42)
	const GLINT := Color(1.0, 0.76, 0.67)

	func _ready() -> void:
		z_index = 20

	func _draw() -> void:
		for index in range(needed):
			var at := Vector2((index - float(needed - 1) * 0.5) * SPACING, 0.0)
			draw_set_transform(at, 0.0, Vector2.ONE * 1.20)
			draw_colored_polygon(_heart, OUTLINE)
			draw_set_transform(at)
			if index >= hits:
				draw_colored_polygon(_heart, FULL)
				draw_rect(Rect2(-5.0, -5.0, 3.0, 2.0), GLINT)
			else:
				var rim := SPENT.lerp(GLINT, flash) if index == hits - 1 else SPENT
				draw_colored_polygon(_heart, rim)
				draw_set_transform(at, 0.0, Vector2.ONE * 0.68)
				draw_colored_polygon(_heart, OUTLINE)
