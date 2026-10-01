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
##
## ⚠ AND NARROW ENOUGH TO LEAVE A SHADOW UNDER IT. At 1.05 either side at 0.55 a second, the
## two cones between them reached to within six degrees of straight down: the dark under its
## belly was 34 pixels of seabed, unmarked, under a 700-pixel body -- and a swimmer along the bed
## makes about 100 px/s, so there was no moment at which a run straight through its reach was
## unseen, and a run from the edge to the shadow had a 1.6-second window in every 7.6. On paper
## a stealth resolution; played, a wall. At 0.90 and 0.38 the beam never comes within fifteen
## degrees of straight down -- ninety pixels of the bed to wait in, in plain sight as the one
## place the light never goes -- and each half of the crossing has a window of three seconds in
## every nine and a half. run_bakunawa_probe measures both against the swimmer's own speed.
const SWEEP_SPEED := 0.38
const SWEEP_LIMIT := 0.90

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
const LEAVE_BY := Vector2(760.0, 320.0)
const LEAVE_SECONDS := 5.5
var _leaving := false
var _gone := false
var _leave: Tween


func _ready() -> void:
	z_index = 4
	# ⚠ THE CONE IS LIGHT, SO IT IS ADDED RATHER THAN LAID OVER. A translucent polygon on top
	# of a dark blue seabed is a grey wedge however it is tinted -- it takes brightness out of
	# what it covers and puts its own flat colour in. Added, the same shape brightens what is
	# under it and disappears where there is nothing, which is what a beam in water does. The
	# material is on THIS node, so it applies to _draw() and not to the creature's sprite,
	# which is a child with its own.
	var beam := CanvasItemMaterial.new()
	beam.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = beam
	_load_clips()
	_build_bodies()
	_build_skin()
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
func stage_at(depth_y: float) -> void:
	global_position.y = depth_y
	_home.y = depth_y
	_fit_the_coils()
	queue_redraw()


## Back to a place and a fresh search, as it was before anything happened to it -- what a
## checkpoint restore to before the encounter's end asks of it. Any leaving is called off.
func reset_to(at: Vector2) -> void:
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
	_hits = 0.0
	_thrash = 0.0
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
	_leave_after(2.5)


## The Artist ending. It found what it lost and is holding it out.
func give_it_up() -> void:
	_state = State.CALM
	_set_channel_open(true)
	_home = global_position
	queue_redraw()
	gift_offered.emit()
	# After what it found has been given: the corner comes up and goes to the apo, and the
	# flower after it, over about five seconds.
	_leave_after(6.0)


func _leave_after(seconds: float) -> void:
	if _leaving or _gone:
		return
	_leaving = true
	_leave = create_tween()
	_leave.tween_interval(seconds)
	_leave.tween_property(self, "global_position", global_position + LEAVE_BY, LEAVE_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_leave.parallel().tween_property(self, "modulate:a", 0.0, LEAVE_SECONDS * 0.7) \
		.set_delay(LEAVE_SECONDS * 0.3)
	_leave.tween_callback(_be_gone)


func _be_gone() -> void:
	_leaving = false
	_gone = true
	visible = false
	set_process(false)
	_set_channel_open(true)
	if _hurtbox != null:
		_hurtbox.collision_layer = 0


# --- Per frame -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_thrash = maxf(0.0, _thrash - delta)
	match _state:
		State.SEARCHING, State.FIGHTING:
			_sweep += SWEEP_SPEED * _sweep_direction * delta
			if absf(_sweep) > SWEEP_LIMIT:
				_sweep = clampf(_sweep, -SWEEP_LIMIT, SWEEP_LIMIT)
				_sweep_direction = -_sweep_direction
			_drift(delta)
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
			# Still while it rests; swimming again as it goes.
			fps = 5.0 if _leaving else 1.6
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
	# ⚠ WHAT `sees()` ANSWERS ABOUT DOES NOT MOVE. The angle and the reach are the rule's;
	# what has changed twice here is only how the inside of it is shaded, and both earlier
	# answers were reported as ugly. Flat, one alpha corner to corner, it was a grey wedge
	# laid over the ruins -- a translucent polygon takes brightness OUT of what it covers and
	# puts its own colour in. Added instead (see the material in _ready), and shaded across
	# its width as well as down its length, it brightens what is under it and disappears where
	# there is nothing, which is what a beam in water does.
	#
	# ⚠ AND IT IS DRAWN A LITTLE WIDER THAN THE RULE, fading to nothing past it. A beam whose
	# light stops exactly on the boundary teaches a player that the edge of the light is the
	# edge of the danger, and they are then caught a pixel outside it. Wider, the faint fringe
	# lies outside the rule, so "out of the light" is true whenever it looks true.
	#
	# The rim lines this carried are gone. The two cones are drawn back to back, so a rim
	# joined its opposite number into one straight line 920 px long across the whole screen --
	# on a seabed that is not a beam, it is a scratch on the picture, and was reported as one.
	#
	# ⚠ AND IT HAS TO BE SEEN, WHICH IS THE WHOLE OF THE STEALTH RULE. At 0.34 at its head and
	# 0.13 across its body, added onto a seabed the storm has already darkened, the beam was a
	# faint pale wedge a first-time player swam into without noticing -- recorded: caught four
	# times in twenty seconds holding right along the bed, from a light they could barely see. It
	# is half as bright again, and the water in it is full of motes that drift through the light
	# and are gone outside it, which is how a beam in murky water reads before anything else does.
	var tint := Color(0.85, 0.92, 0.70, 1.0)
	if _state == State.FIGHTING:
		tint = Color(0.97, 0.70, 0.58, 1.0)
	# A slow swell, so the beam is alive while it is holding still at the end of a sweep.
	var clock := float(Time.get_ticks_msec()) * 0.001
	var swell := 1.0 + 0.14 * sin(clock * 2.1)
	# ⚠ RINGS AND SPOKES, NOT ONE FAN. A fan from a single bright vertex at the creature is bright
	# all along each of its two edge rays near that vertex -- the colour of every triangle runs
	# from the bright middle to the dark rim -- so close in, the beam had a hard straight side.
	# Cut into cells, the light goes to nothing across the width at every distance.
	var spread := CONE_HALF_ANGLE * 1.18
	for facing in [_sweep, _sweep + PI]:
		for ring in range(BEAM_RINGS):
			var near := float(ring) / float(BEAM_RINGS)
			var far := float(ring + 1) / float(BEAM_RINGS)
			for spoke in range(BEAM_SPOKES):
				var left := float(spoke) / float(BEAM_SPOKES)
				var right := float(spoke + 1) / float(BEAM_SPOKES)
				var cell := PackedVector2Array()
				var shades := PackedColorArray()
				for corner: Vector2 in [Vector2(left, far), Vector2(right, far),
						Vector2(right, near), Vector2(left, near)]:
					if ring == 0 and corner.y == 0.0 and corner.x == right:
						continue  # the cell against the creature is a triangle
					var angle: float = facing - spread + spread * 2.0 * corner.x
					var middle := corner.x if ring > 0 or corner.y > 0.0 else (left + right) * 0.5
					if ring == 0 and corner.y == 0.0:
						angle = facing - spread + spread * 2.0 * middle
					cell.append(Vector2(cos(angle), sin(angle)) * CONE_LENGTH * corner.y)
					shades.append(Color(tint.r, tint.g, tint.b,
						_beam_strength(middle, corner.y) * swell))
				draw_polygon(cell, shades)
		_draw_motes(facing, tint, clock)


const BEAM_RINGS := 5
const BEAM_SPOKES := 12


## How bright the beam is at a point, by how far across it (0..1, the axis at 0.5) and how far
## along it (0..1): brightest close in, a little brighter on the axis.
##
## ⚠ LIT ALL THE WAY TO THE RULE'S EDGE, AND FADING ONLY OUTSIDE IT. The cells are drawn 1.18
## times the rule's width. A falloff across the whole of that left the rule's own edge at a
## fifteenth of the axis's light, so the part of the beam that looked lit was narrower than the
## part that catches you, and a player would be seen standing in what looked like the dark.
## Full strength to three quarters of the rule's angle, then down to nothing just past it: at
## the rule's edge the light is still two fifths on, and gone by the fringe.
static func _beam_strength(across: float, along: float) -> float:
	var off_axis := absf(across * 2.0 - 1.0) * 1.18
	var body := 1.0 - smoothstep(0.75, 1.18, off_axis)
	return (0.16 + 0.3 * pow(1.0 - along, 2.0)) * body * (0.8 + 0.2 * (1.0 - off_axis))


## Specks in the water, lit only while they are inside the beam: each drifts slowly outward
## along its own line through the cone and wraps, whole pixels, brightest near the axis.
const MOTES := 26


func _draw_motes(facing: float, tint: Color, clock: float) -> void:
	for index in range(MOTES):
		var seed := float(index) * 12.9898
		var across := fposmod(sin(seed) * 43758.5453, 1.0) * 2.0 - 1.0
		var reach := fposmod(fposmod(sin(seed * 1.7) * 24634.6345, 1.0) + clock * 0.05, 1.0)
		var angle := facing + across * CONE_HALF_ANGLE
		var at := (Vector2(cos(angle), sin(angle)) * reach * CONE_LENGTH).round()
		var bright := (1.0 - absf(across)) * (1.0 - reach) * 0.9
		if bright < 0.08:
			continue
		var size := 2.0 if index % 3 == 0 else 1.0
		draw_rect(Rect2(at, Vector2(size, size)), Color(tint.r, tint.g, tint.b, bright))
