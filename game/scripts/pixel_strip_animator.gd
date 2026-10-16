class_name PixelStripAnimator
extends Sprite2D
## Plays a creature's pixel strips: one PNG per animation, `<folder><kind>_<anim>.png`, frames in
## a row at FRAME px. Whatever strips exist are used; a kind with none leaves `has_art()` false,
## and its owner draws its own placeholder instead. So drawn art replaces the code-drawn strips
## by being dropped in with the same names -- no code change.
##
## Facing right as drawn; `face()` mirrors it. Anchored by the feet: the frame's bottom edge is
## on the node's origin, so the owner puts the origin where the creature stands.

const FRAME := 48
## Frames a second per animation; anything not listed plays at DEFAULT_FPS.
const FPS := {"idle": 3.0, "run": 10.0, "windup": 6.0, "attack": 8.0, "hurt": 1.0, "death": 6.0}
const DEFAULT_FPS := 6.0
## These hold their last frame instead of looping.
const HOLDS := ["death", "hurt"]

var _strips: Dictionary = {}
var _anim := ""
var _clock := 0.0


func load_kind(folder: String, kind: String, anims: Array) -> void:
	_strips.clear()
	for anim: String in anims:
		var path := "%s%s_%s.png" % [folder, kind, anim]
		if ResourceLoader.exists(path):
			var sheet := load(path) as Texture2D
			if sheet != null:
				_strips[anim] = sheet
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = false
	offset = Vector2(-FRAME * 0.5, -FRAME)
	visible = has_art()


func has_art() -> bool:
	return not _strips.is_empty()


func anim() -> String:
	return _anim


func play(next: String) -> void:
	if not _strips.has(next):
		next = "idle" if _strips.has("idle") else ""
	if next == _anim or next.is_empty():
		return
	_anim = next
	_clock = 0.0
	var sheet: Texture2D = _strips[next]
	texture = sheet
	hframes = maxi(1, int(sheet.get_width() / FRAME))
	frame = 0


func face(facing: float) -> void:
	flip_h = facing < 0.0


func advance(delta: float) -> void:
	if _anim.is_empty():
		return
	_clock += delta * float(FPS.get(_anim, DEFAULT_FPS))
	var index := int(_clock)
	frame = mini(index, hframes - 1) if _anim in HOLDS else index % hframes
