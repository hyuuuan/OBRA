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

## Long and low: this is a body the player swims the length of, not a sprite they stand next
## to. The arena is 900 wide, so it fills most of it and leaving is a real exit.
const BODY_LENGTH := 700.0
const BODY_DEPTH := 130.0
const SEGMENTS := 14

const CONE_LENGTH := 460.0
const CONE_HALF_ANGLE := 0.42
## How fast the sweep travels, and how far either side of straight ahead it goes. Slow enough
## that a player can read it and time a run, which is the whole of the stealth resolution.
const SWEEP_SPEED := 0.55
const SWEEP_LIMIT := 1.05

## Three good hits. The design asks that the fight be survivable without combat skill: this is
## a story game and a player who picks Protector for character reasons should not be walled by
## execution.
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

const HITS_TO_SUBDUE := 3
## What each drawn weapon is worth against it. Present so the five differ in more than reach,
## which the design asks for outright -- "or drawing anything becomes drawing the best one".
const BITE := {
	"cannon": 1.0, "anvil": 1.0, "axe": 0.8, "sword": 0.8, "boomerang": 0.6,
}

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


func _ready() -> void:
	z_index = 4
	_load_clips()
	_build_bodies()
	_build_skin()
	set_process(true)


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
func stage_at(depth_y: float) -> void:
	global_position.y = depth_y
	_fit_the_coils()
	queue_redraw()


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
	queue_redraw()


## The Pragmatist resolution. It is still searching and still dangerous -- what changes is
## that there is now a way past, if the player stays out of the sweep.
func open_a_gap() -> void:
	_state = State.SEARCHING
	_set_channel_open(true)
	queue_redraw()


## The Artist resolution. Something is throwing light and it goes to it.
func follow_the_light(point: Vector2) -> void:
	if _state == State.SUBDUED or _state == State.CALM:
		return
	_state = State.FOLLOWING
	_follow_target = point
	queue_redraw()


func enter_fight() -> void:
	if _state == State.SUBDUED:
		return
	_state = State.FIGHTING
	_hits = 0.0
	_set_channel_open(false)
	queue_redraw()


func state() -> int:
	return _state


func hits_taken() -> float:
	return _hits


func treasure_point() -> Vector2:
	return global_position + treasure_offset


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
	if _state == State.SUBDUED or _state == State.CALM:
		return false
	var offset := point - global_position
	if lit and offset.length() < CONE_LENGTH * 1.6:
		return true
	if offset.length() > CONE_LENGTH:
		return false
	for facing in [_sweep, _sweep + PI]:
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
	queue_redraw()
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
	queue_redraw()
	went_quiet.emit("FOUGHT")


## The Artist ending. It found what it lost and is holding it out.
func give_it_up() -> void:
	_state = State.CALM
	_set_channel_open(true)
	queue_redraw()
	gift_offered.emit()


# --- Per frame -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_thrash = maxf(0.0, _thrash - delta)
	match _state:
		State.SEARCHING, State.FIGHTING:
			_sweep += SWEEP_SPEED * _sweep_direction * delta
			if absf(_sweep) > SWEEP_LIMIT:
				_sweep = clampf(_sweep, -SWEEP_LIMIT, SWEEP_LIMIT)
				_sweep_direction = -_sweep_direction
		State.FOLLOWING:
			var to_light := _follow_target - global_position
			_sweep = lerp_angle(_sweep, to_light.angle(), minf(1.0, delta * 2.0))
			if to_light.length() > 24.0:
				global_position += to_light.normalized() * 120.0 * delta
			else:
				# It got there. Announcing this itself keeps the level from having to poll a
				# distance every frame to find out whether a creature has arrived.
				give_it_up()
		State.CALM, State.SUBDUED:
			_sweep = lerp_angle(_sweep, 0.0, minf(1.0, delta * 1.2))
	_animate(delta)
	queue_redraw()


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
			fps = 1.6
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
	# ⚠ A HIT SHOWS. The white flash is the only feedback the fight has, and without it three
	# good swings and one miss look exactly alike.
	_skin.modulate = Color(1.6, 1.6, 1.6) if _thrash > 0.0 else Color.WHITE
	if _state == State.SUBDUED:
		_skin.modulate = Color(0.55, 0.6, 0.68)


## ⚠ ONLY THE SWEEP. The body is a Sprite2D now, but the cone stays hand-drawn because it is
## not decoration -- it is the rule `sees()` answers about, and a boundary the player cannot
## see is one they learn by being put back.
func _draw() -> void:
	if _state != State.SEARCHING and _state != State.FIGHTING:
		return
	# ⚠ THE EDGE KEEPS ITS EXACT ANGLE AND ITS EXACT REACH. What changes here is only how the
	# inside of the cone is shaded: flat, one alpha corner to corner, it read as a grey
	# triangle laid over the ruins rather than as something looking. It is brightest at the
	# head and falls off down its length, with a rim drawn along the two edges so the boundary
	# `sees()` answers about is still the clearest line in it -- a softer cone that a player
	# could only guess the edge of would be a rule learned by being put back.
	var tint := Color(0.85, 0.92, 0.70, 1.0)
	if _state == State.FIGHTING:
		tint = Color(0.97, 0.70, 0.58, 1.0)
	# A slow swell, so the beam is alive while it is holding still at the end of a sweep.
	var swell := 1.0 + 0.14 * sin(float(Time.get_ticks_msec()) * 0.0021)
	var near := Color(tint.r, tint.g, tint.b, 0.30 * swell)
	var far := Color(tint.r, tint.g, tint.b, 0.07 * swell)
	var rim := Color(tint.r, tint.g, tint.b, 0.34 * swell)
	for facing in [_sweep, _sweep + PI]:
		var points := PackedVector2Array([Vector2.ZERO])
		var shades := PackedColorArray([near])
		for step in range(9):
			var angle: float = facing - CONE_HALF_ANGLE \
				+ CONE_HALF_ANGLE * 2.0 * (float(step) / 8.0)
			points.append(Vector2(cos(angle), sin(angle)) * CONE_LENGTH)
			shades.append(far)
		draw_polygon(points, shades)
		for side in [-1.0, 1.0]:
			var along := Vector2(cos(facing + CONE_HALF_ANGLE * side),
				sin(facing + CONE_HALF_ANGLE * side))
			draw_line(Vector2.ZERO, along * CONE_LENGTH, rim, 2.0)
