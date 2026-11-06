class_name DawnClockHud
extends Control
## HOW FAR OFF THE MORNING IS, in the last clearing: a small painted window on the sky, and the time.
##
## Kent: "i want the morning timer to like start off as a moon and then slowly transform into a sun,
## design it properly". One body crosses the window the whole night. It comes up as a thin crescent
## among stars, waxes to full by halfway (which is when the woods themselves start to lift), warms
## from silver to gold as the craters go, then grows its rays, and by morning it is the sun. The sky
## behind it goes the same way: indigo, mauve, morning blue over gold.
##
## ⚠ WHAT IT REPLACED: a thin strip with a dot on it and no words, under a comment saying a player
## should not be counting. Seen in a window it read as a loading bar. So now it says what it is and
## how long is left, in words and in the largest type on the HUD, and the two moments the night
## changes are marked on the body's path ahead of it. Nothing on it is red: nothing on it is a loss.
##
## ⚠ THE PICTURE IS A SUN, AND SUN IS A CLASS. The rule against picturing a class is about a lesson's
## card, and the level's lines still name none. Kent asked for this one, and a sun does hurry the
## morning (`hurried`), so what it gives away is true.
##
## Shown only while the night runs. Everything is drawn in whole pixels at the pixel rate, and the
## body baked from rules in art pixels of three screen pixels, the HUD's own lantern and brush scale.

const SIZE := Vector2(540.0, 112.0)
## The window on the sky, and the column of words beside it.
const WINDOW := Rect2(10.0, 10.0, 344.0, 92.0)
const WORDS_X := 370.0
const WINDOW_RADIUS := 8.0
const WINDOW_RING := 2

const CAPTION_FONT := UISkin.FONT_CAPTION
const TIME_FONT := UISkin.FONT_TITLE
const MORNING_FONT := UISkin.FONT_BODY
## The last of the night, in seconds: the caption says so, and the wait is nearly over.
const ALMOST_AT := 15

# The body, in art pixels.
const ART_PIXEL := 3
const BODY_R := 7
## Wide enough for the longest rays and the glow, odd so it has a middle.
const BODY_SIDE := 29
## How much of its face is lit when the night starts, and when it is full.
const CRESCENT := 0.22
const FULL_AT := 0.5
## The silver warming to gold, the craters going, and the rays coming, as shares of the night.
const WARM_FROM := 0.35
const WARM_TO := 0.85
const CRATERS_GO_FROM := 0.45
const CRATERS_GO_TO := 0.75
const RAYS_FROM := 0.62
const LONG_RAY := 4
const SHORT_RAY := 2
const DIAGONAL_RAY_FROM := 7
## The cells of its face that are craters, from its middle: placed by eye, and all on the part the
## crescent leaves dark, so they arrive as it waxes.
const CRATERS := [Vector2i(-3, -3), Vector2i(-2, -3), Vector2i(-3, -2), Vector2i(1, -4), Vector2i(2, -1),
	Vector2i(3, -1), Vector2i(2, 0), Vector2i(-4, 1), Vector2i(-1, 3), Vector2i(0, 3), Vector2i(-1, 4),
	Vector2i(3, 3), Vector2i(4, 3)]
## How many steps the whole night's change is cut into: about a step every two seconds, each one
## showing, the way a pixel face changes.
const PHASE_STEPS := 48
const TWINKLE_HZ := 3.0

# Where the body goes across the window: low on the left to high on the right.
const PATH_LEFT := 34.0
const PATH_RIGHT := 42.0
const PATH_LOW := 58.0
const PATH_HIGH := 40.0
const PATH_DOT_EVERY := 0.035
const PATH_DOT := 2.0
## Hidden once the body has passed them: what is behind her is not news.
const MARK_PIXEL := 2.0
## The second wave's mark, wings in flight; the third's, three beats of a call. By wave number.
const MARK_ART := {
	1: ["..##...##..", ".####.####.", "##..###..##", "#....#....#"],
	2: ["##.##.##", "##.##.##"],
}
const MARK_PLATE := 3

const STARS := [Vector3(26, 12, 0.5), Vector3(62, 26, 0.28), Vector3(94, 8, 0.62), Vector3(130, 30, 0.4),
	Vector3(158, 14, 0.7), Vector3(196, 22, 0.32), Vector3(226, 8, 0.56), Vector3(262, 18, 0.46),
	Vector3(296, 30, 0.24), Vector3(322, 10, 0.66), Vector3(334, 24, 0.36), Vector3(112, 44, 0.3),
	Vector3(214, 40, 0.26), Vector3(16, 34, 0.2)]
const BANDS := 6
const BAND_ROW := 4.0

## How long the morning coming nearer is said, and how long the body takes to get there.
const NEARER_SECONDS := 3.0
const GLIDE_SECONDS := 0.7

var _progress := 0.0
## Where the picture is: the night's own share, except while it glides to a jump.
var _shown := 0.0
var _glide: Tween
var _nearer_left := 0.0
var _nearer_said := 0
var _morning := false
var _tick := 0.0
var _clock := 0.0
var _sky: Control
var _baked_step := -1
var _body_steady: ImageTexture
var _body_twinkle: ImageTexture
var _near_trees: PackedFloat32Array
var _far_trees: PackedFloat32Array


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE
	size = SIZE
	visible = false
	_near_trees = _treeline(7, 18.0, 9.0)
	_far_trees = _treeline(23, 28.0, 14.0)
	_sky = Control.new()
	_sky.name = "Sky"
	_sky.position = WINDOW.position
	_sky.size = WINDOW.size
	_sky.clip_contents = true
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sky)
	_sky.draw.connect(_draw_sky)


func set_progress(share: float) -> void:
	_progress = clampf(share, 0.0, 1.0)
	if _glide == null or not _glide.is_valid() or not _glide.is_running():
		_shown = _progress


func progress() -> float:
	return _progress


## Where the picture has got to, which a jump in the night takes a moment to reach.
func shown() -> float:
	return _shown


## Whole seconds until morning, rounded up: it reads 0:00 only when it is morning.
func seconds_left() -> int:
	return ceili((1.0 - _progress) * DilimFinale2D.DAWN_SECONDS - 0.001)


func time_text() -> String:
	var left := seconds_left()
	return "%d:%02d" % [floori(left / 60.0), left % 60]


## The words over the time: what the number is, then that it is nearly over.
func caption() -> String:
	if _morning:
		return ""
	if _nearer_left > 0.0:
		return "%d s nearer" % _nearer_said
	return "Almost morning" if seconds_left() <= ALMOST_AT else "Morning in"


## A wave's mark on the path, as a share of the night: read off the night's own table, so it cannot
## drift from when they come.
func mark_share(wave: int) -> float:
	return float((DilimFinale2D.WAVES[wave] as Dictionary)["at"]) / DilimFinale2D.DAWN_SECONDS


## Where the body's middle is in the window at `share` of the night.
func body_at(share: float) -> Vector2:
	var t := clampf(share, 0.0, 1.0)
	return Vector2(lerpf(PATH_LEFT, WINDOW.size.x - PATH_RIGHT, t),
		lerpf(PATH_LOW, PATH_HIGH, sin(t * PI * 0.5))).round()


## The night has begun.
func show_night() -> void:
	_morning = false
	_nearer_left = 0.0
	_shown = _progress
	_redraw()
	Motion.pop_in(self)


func hide_night() -> void:
	if visible:
		Motion.leave(self, func() -> void: visible = false)


## A sun drawn in the night has brought the morning on: the body goes there with a glide, and the
## caption says how much nearer. Under Reduce motion it is simply there.
func hurried(seconds: float) -> void:
	_nearer_said = roundi(seconds)
	_nearer_left = NEARER_SECONDS
	if _glide != null and _glide.is_valid():
		_glide.kill()
	if Motion.reduced():
		_shown = _progress
		_redraw()
		return
	_glide = create_tween()
	Motion.step(_glide, self, "_shown", _progress, GLIDE_SECONDS, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	_redraw()


## Morning: the sun at the top of its path, and the word. It stays up until the level is done with it.
func morning() -> void:
	set_progress(1.0)
	if _glide != null and _glide.is_valid():
		_glide.kill()
	_shown = 1.0
	_morning = true
	_nearer_left = 0.0
	_redraw()


func is_morning() -> bool:
	return _morning


func _process(delta: float) -> void:
	_clock += delta
	_nearer_left = maxf(0.0, _nearer_left - delta)
	_tick += delta
	if _tick >= 1.0 / Motion.PIXEL_FPS:
		_tick = 0.0
		_redraw()


func _redraw() -> void:
	queue_redraw()
	if _sky != null:
		_sky.queue_redraw()


# --- The words ------------------------------------------------------------------------------

func _draw() -> void:
	draw_style_box(UISkin.frame(), Rect2(Vector2.ZERO, SIZE))
	var font := get_theme_default_font()
	if _morning:
		draw_string(font, Vector2(WORDS_X, SIZE.y * 0.5 + 10.0), "Morning", HORIZONTAL_ALIGNMENT_LEFT, -1,
			MORNING_FONT, UISkin.GOLD_PALE)
		return
	var near_the_end := seconds_left() <= ALMOST_AT or _nearer_left > 0.0
	draw_string(font, Vector2(WORDS_X, 44.0), caption(), HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_FONT,
		UISkin.GOLD if near_the_end else UISkin.MUTED)
	draw_string(font, Vector2(WORDS_X, 88.0), time_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, TIME_FONT,
		UISkin.GOLD_PALE)


# --- The window -----------------------------------------------------------------------------

func _phase_step() -> int:
	return roundi(_shown * PHASE_STEPS)


func _phase() -> float:
	return float(_phase_step()) / PHASE_STEPS


func _draw_sky() -> void:
	var share := _phase()
	_draw_bands(share)
	_draw_stars(share)
	_draw_path()
	_bake(_phase_step())
	var twinkled := share >= RAYS_FROM and not Motion.reduced() and int(_clock * TWINKLE_HZ * 2.0) % 2 == 1
	var body := _body_twinkle if twinkled else _body_steady
	var side := Vector2.ONE * BODY_SIDE * ART_PIXEL
	_sky.draw_texture_rect(body, Rect2(body_at(_shown) - side * 0.5, side), false)
	_draw_trees(_far_trees, UISkin.TREES_FAR_NIGHT.lerp(UISkin.TREES_FAR_MORNING, share))
	_draw_trees(_near_trees, UISkin.TREES_NIGHT.lerp(UISkin.TREES_MORNING, share))
	_draw_marks()
	_draw_corners()


## Stepped rows, bands of them, and three stops through the night: a gradient with its joints showing,
## the way everything else in this game is painted.
func _draw_bands(share: float) -> void:
	var top := _three_stop(share, UISkin.SKY_NIGHT_TOP, UISkin.SKY_PREDAWN_TOP, UISkin.SKY_MORNING_TOP)
	var low := _three_stop(share, UISkin.SKY_NIGHT_LOW, UISkin.SKY_PREDAWN_LOW, UISkin.SKY_MORNING_LOW)
	var row := 0.0
	while row < WINDOW.size.y:
		var band := floorf(row / WINDOW.size.y * BANDS) / float(BANDS - 1)
		_sky.draw_rect(Rect2(0.0, row, WINDOW.size.x, BAND_ROW), top.lerp(low, band))
		row += BAND_ROW


func _three_stop(share: float, night: Color, predawn: Color, morning: Color) -> Color:
	return night.lerp(predawn, share * 2.0) if share < 0.5 else predawn.lerp(morning, (share - 0.5) * 2.0)


## Each goes out at its own share of the night, in eighths, the small ones first.
func _draw_stars(share: float) -> void:
	for star: Vector3 in STARS:
		var left := 1.0 - share / star.z
		if left <= 0.0:
			continue
		var alpha := ceilf(left * Motion.ALPHA_STEPS) / Motion.ALPHA_STEPS
		var dot := 3.0 if int(star.x) % 3 == 0 else 2.0
		_sky.draw_rect(Rect2(star.x, star.y, dot, dot), Color(UISkin.CREAM_TEXT, alpha))


## Dots ahead of it, along where it is going; none behind.
func _draw_path() -> void:
	var at := _shown + PATH_DOT_EVERY * 1.5
	while at < 1.0:
		var dot := body_at(at)
		_sky.draw_rect(Rect2(dot, Vector2.ONE * PATH_DOT), Color(UISkin.GOLD_PALE, 0.375))
		at += PATH_DOT_EVERY


## The two moments the night changes, ahead on the path, until the body has passed them.
func _draw_marks() -> void:
	for wave: int in MARK_ART:
		var share := mark_share(wave)
		if _shown >= share:
			continue
		var art: Array = MARK_ART[wave]
		var wide := float((art[0] as String).length()) * MARK_PIXEL
		var at := body_at(share) - Vector2(wide * 0.5, float(art.size()) * MARK_PIXEL * 0.5)
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color(UISkin.TREES_NIGHT, 0.75)
		plate.set_corner_radius_all(MARK_PLATE)
		_sky.draw_style_box(plate, Rect2(at - Vector2.ONE * MARK_PLATE,
			Vector2(wide, art.size() * MARK_PIXEL) + Vector2.ONE * MARK_PLATE * 2.0))
		for row in range(art.size()):
			var line := String(art[row])
			for column in range(line.length()):
				if line[column] == "#":
					_sky.draw_rect(Rect2(at + Vector2(column, row) * MARK_PIXEL, Vector2.ONE * MARK_PIXEL),
						UISkin.GOLD_PALE)


func _draw_trees(tops: PackedFloat32Array, colour: Color) -> void:
	for column in range(tops.size()):
		_sky.draw_rect(Rect2(column * BAND_ROW, WINDOW.size.y - tops[column], BAND_ROW, tops[column]), colour)


## A skyline across the window: peaks at a settled spacing from `seed_value`, whole rows tall.
func _treeline(seed_value: int, tallest: float, shortest: float) -> PackedFloat32Array:
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	var columns := int(WINDOW.size.x / BAND_ROW) + 1
	var tops := PackedFloat32Array()
	tops.resize(columns)
	tops.fill(shortest * 0.6)
	var x := dice.randf_range(0.0, 6.0)
	while x < columns:
		var height := dice.randf_range(shortest, tallest)
		var slope := dice.randf_range(1.6, 2.8)
		for column in range(columns):
			tops[column] = maxf(tops[column], height - absf(column - x) * slope)
		x += dice.randf_range(5.0, 11.0)
	for column in range(columns):
		tops[column] = floorf(tops[column] / 2.0) * 2.0
	return tops


## The window's soft corners: the panel's own colour over what the clip left square, then its ring.
func _draw_corners() -> void:
	var r := WINDOW_RADIUS
	var size_of := WINDOW.size
	for corner: Vector2 in [Vector2.ZERO, Vector2(size_of.x, 0.0), size_of, Vector2(0.0, size_of.y)]:
		var inward := Vector2(1.0 if corner.x == 0.0 else -1.0, 1.0 if corner.y == 0.0 else -1.0)
		var points := PackedVector2Array([corner])
		for step in range(7):
			var angle := float(step) / 6.0 * PI * 0.5
			points.append(corner + inward * (Vector2.ONE * r - Vector2(cos(angle), sin(angle)) * r))
		_sky.draw_colored_polygon(points, UISkin.PANEL)
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = UISkin.RING_MID
	ring.set_border_width_all(WINDOW_RING)
	ring.set_corner_radius_all(int(r))
	ring.anti_aliasing = true
	_sky.draw_style_box(ring, Rect2(Vector2.ZERO, size_of))


# --- The body -------------------------------------------------------------------------------

func _bake(step: int) -> void:
	if step == _baked_step:
		return
	_baked_step = step
	var share := float(step) / PHASE_STEPS
	_body_steady = ImageTexture.create_from_image(body_image(share, false))
	_body_twinkle = ImageTexture.create_from_image(body_image(share, true))


## The body at `share` of the night, in art pixels, clear round it. Public so a probe can ask what it
## is at any moment by looking at it. `twinkle` is the other frame of its rays.
##
## A moon's phase is the one curve in it: a row's lit part starts where the terminator crosses that
## row, at x = half-width * (1 - 2 * waxed), so waxed 0 is new, 0.5 a half and 1 full.
func body_image(share: float, twinkle: bool = false) -> Image:
	var image := Image.create(BODY_SIDE, BODY_SIDE, false, Image.FORMAT_RGBA8)
	var mid := BODY_SIDE / 2
	var waxed := lerpf(CRESCENT, 1.0, clampf(share / FULL_AT, 0.0, 1.0))
	var warm := smoothstep(WARM_FROM, WARM_TO, share)
	var scarred := 1.0 - smoothstep(CRATERS_GO_FROM, CRATERS_GO_TO, share)
	var glow := lerpf(2.0, 5.0, warm)
	var lit_colour := UISkin.MOON_LIT.lerp(UISkin.GOLD_PALE, warm)
	var rim_colour := UISkin.MOON_SHADE.lerp(UISkin.GOLD, warm)
	var glow_colour := UISkin.MOON_LIT.lerp(UISkin.GOLD, warm)
	var hot := smoothstep(0.7, 1.0, share)
	for y in range(BODY_SIDE):
		for x in range(BODY_SIDE):
			var cell := Vector2i(x - mid, y - mid)
			var from_middle := Vector2(cell).length()
			if from_middle > BODY_R + 0.4:
				var out := (from_middle - BODY_R) / glow
				if out < 1.0:
					var alpha := ceilf((1.0 - out) * 0.375 * Motion.ALPHA_STEPS) / Motion.ALPHA_STEPS
					image.set_pixel(x, y, Color(glow_colour, alpha))
				continue
			# The disc's own edge, out to the same +0.4 as the test above: to BODY_R alone, a full moon
			# kept a fleck of its dark side on every row along its left rim.
			var half_width := sqrt(maxf(0.0, pow(BODY_R + 0.4, 2.0) - cell.y * cell.y))
			var colour: Color
			if float(cell.x) < half_width * (1.0 - 2.0 * waxed):
				colour = UISkin.MOON_DARK
			else:
				colour = lit_colour
				# Cel-lit from the upper left, as everything in the woods is: its rim darkens to the
				# lower right, and a crater is the same shade.
				if from_middle >= BODY_R - 1.2 and cell.x + cell.y > 1:
					colour = rim_colour
				elif CRATERS.has(cell):
					colour = lit_colour.lerp(rim_colour, scarred)
				if hot > 0.0 and from_middle <= BODY_R * 0.55:
					colour = colour.lerp(UISkin.SUN_CORE, hot)
			image.set_pixel(x, y, colour)
	_bake_rays(image, mid, share, twinkle)
	return image


## Long rays on the four compass points and short on the diagonals, a pixel clear of its edge, each
## wider at its foot: one pixel all the way out, at three screen pixels, was a thread beside a disc
## fifteen across, and this is the moment it stops being the moon.
func _bake_rays(image: Image, mid: int, share: float, twinkle: bool) -> void:
	var grown := clampf((share - RAYS_FROM) / (1.0 - RAYS_FROM), 0.0, 1.0)
	if grown <= 0.0:
		return
	var long := roundi(grown * LONG_RAY)
	var short := roundi(clampf((grown - 0.35) / 0.65, 0.0, 1.0) * SHORT_RAY)
	if twinkle and long > 1:
		long -= 1
	var centre := Vector2i(mid, mid)
	var start := BODY_R + 2
	for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var across := Vector2i(direction.y, direction.x)
		for step in range(long):
			var at := centre + direction * (start + step)
			image.set_pixelv(at, UISkin.GOLD)
			if step == 0 and long > 1:
				image.set_pixelv(at + across, UISkin.GOLD)
				image.set_pixelv(at - across, UISkin.GOLD)
	for direction: Vector2i in [Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		for step in range(short):
			var at := centre + direction * (DIAGONAL_RAY_FROM + step)
			image.set_pixelv(at, UISkin.GOLD)
			if step == 0:
				image.set_pixelv(at - Vector2i(direction.x, 0), UISkin.GOLD)
				image.set_pixelv(at - Vector2i(0, direction.y), UISkin.GOLD)
