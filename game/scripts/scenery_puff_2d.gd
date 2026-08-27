class_name SceneryPuff2D
extends Node2D
## Dust off a heel, dust off a landing, and rings where something went into the water.
##
## THE APO WALKED ON THE TERRACES LIKE A CURSOR. Nothing the player did left any trace on the
## world: they ran, they jumped, they landed a hundred and forty pixels down onto packed
## earth, they waded into a paddy -- and the ground and the water did not acknowledge any of
## it. The character animates beautifully and the world it is animating against did not move,
## which is most of why walking around felt like dragging a sprite.
##
## One node, three shapes, because they are the same idea at different scales: something met
## a surface and the surface said so. It frees itself and nothing has to be cleaned up.
##
## Deterministic like everything else drawn in this project -- the same landing throws the
## same dust every time, so a screenshot of it can be compared with the last one.

enum Kind { STEP, LAND, SPLASH }

const STEP_LIFE := 0.42
const LAND_LIFE := 0.55
const SPLASH_LIFE := 0.7

## Packed earth, and the paler skim that comes off the top of it.
const DUST := Color(0.678, 0.596, 0.451, 0.55)
const DUST_PALE := Color(0.812, 0.749, 0.596, 0.45)
## Paddy water: the ring, and the drops thrown off it.
const FOAM := Color(0.878, 0.937, 0.949, 0.8)
const WATER := Color(0.541, 0.729, 0.784, 0.7)

var kind: Kind = Kind.STEP
var strength := 1.0

var _age := 0.0
var _life := STEP_LIFE
var _puffs: PackedVector3Array = PackedVector3Array()


## Throw one at a spot in `parent`'s own space. `strength` is 0..1 and scales how much of it
## there is -- a walk is a wisp and a two-storey drop is a cloud.
static func burst(parent: Node2D, at: Vector2, what: Kind, force: float = 1.0) -> SceneryPuff2D:
	if parent == null or not is_instance_valid(parent):
		return null
	var puff := SceneryPuff2D.new()
	puff.name = "Puff"
	puff.position = at
	puff.kind = what
	puff.strength = clampf(force, 0.15, 1.0)
	# Over the ground it is standing on and under the player, who is at 10.
	puff.z_index = 6
	parent.add_child(puff)
	return puff


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# It outlives a pause on purpose: a landing is frequently the frame before a trigger
	# fires a line of story, and dust frozen in mid-air for the length of a conversation is
	# worse than no dust.
	process_mode = Node.PROCESS_MODE_ALWAYS
	match kind:
		Kind.STEP:
			_life = STEP_LIFE
		Kind.LAND:
			_life = LAND_LIFE
		Kind.SPLASH:
			_life = SPLASH_LIFE
	var count := 3 if kind == Kind.STEP else int(5.0 + 7.0 * strength)
	for index in range(count):
		# Fixed offsets rather than randf, so it is the same burst every time. x is the
		# sideways throw, y the lift, z the size.
		var spread := float((index * 53) % 17) / 17.0 - 0.5
		var lift := 0.35 + float((index * 31) % 11) / 11.0 * 0.65
		_puffs.append(Vector3(spread, lift, 1.0 + float((index * 7) % 3)))
	set_process(true)


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(_age / _life, 0.0, 1.0)
	match kind:
		Kind.SPLASH:
			_draw_splash(t)
		_:
			_draw_dust(t)


## Dust: whole-pixel blobs thrown out and up, growing as they thin. Drawn as squares because
## everything in this game is, and because a soft circle at this size is a grey smudge.
func _draw_dust(t: float) -> void:
	var fade := (1.0 - t) * (1.0 - t)
	var reach := (16.0 + 26.0 * strength) * ease(t, 0.4)
	var rise := (10.0 + 20.0 * strength) * ease(t, 0.5)
	for puff in _puffs:
		var at := Vector2(puff.x * reach, -puff.y * rise)
		var size := (puff.z + t * 2.5 * strength)
		var tone := DUST_PALE if int(puff.z) % 2 == 0 else DUST
		draw_rect(Rect2(at - Vector2(size, size) * 0.5, Vector2(size, size)),
			Color(tone, tone.a * fade))
	if kind == Kind.LAND:
		# The skid: a flat smear either side of the foot, which is what says the landing had
		# weight rather than that the character arrived.
		var half := reach * 0.9
		draw_rect(Rect2(-half, -2.0, half * 2.0, 2.0), Color(DUST_PALE, 0.5 * fade))


## Water: rings going out on the surface, and a few drops thrown up out of them.
func _draw_splash(t: float) -> void:
	var fade := 1.0 - t
	for ring in range(2):
		var offset := float(ring) * 0.22
		var age := clampf((t - offset) / maxf(0.01, 1.0 - offset), 0.0, 1.0)
		if age <= 0.0:
			continue
		var wide := (18.0 + 44.0 * strength) * ease(age, 0.35)
		var tall := maxf(1.0, wide * 0.22)
		var alpha := (1.0 - age) * fade
		# An ellipse would be a curve; two bars and two caps is a ring seen almost edge-on,
		# which is what a ripple on a side-on paddy actually looks like.
		draw_rect(Rect2(-wide, -tall * 0.5, wide * 2.0, 1.0), Color(FOAM, alpha))
		draw_rect(Rect2(-wide * 0.72, tall * 0.5, wide * 1.44, 1.0), Color(WATER, alpha * 0.8))
	for puff in _puffs:
		var at := Vector2(puff.x * 34.0 * strength,
			-puff.y * 30.0 * strength * sin(minf(t * PI, PI)))
		draw_rect(Rect2(at, Vector2(2.0, 2.0)), Color(FOAM, fade))
