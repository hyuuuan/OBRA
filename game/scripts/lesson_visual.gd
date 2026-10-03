class_name LessonVisual
extends Control
## THE PICTURE IN A LESSON: the real key, the real mouse button, doing the thing.
##
## Kent: "not like those just text but add visuals like the button itself ... there are
## players that will play it without reading it, just watching/seeing what is presented."
## So a lesson is first a small loop that SHOWS the input -- a key cap going down, a mouse
## button lighting, the wheel turning -- beside what it does: the apo walking the way the key
## says, a drawing turning as the wheel turns, growing and shrinking with corner arrows as the
## size keys go down. The caption under it is the second way in, never the first.
##
## DRAWN, NOT IMPORTED. Every cap carries the live binding the director read off the
## InputMap, so a rebinding redraws the key; and nothing here needs an art pass to change.
##
## ⚠ THE STAND-IN FOR "YOUR DRAWING" IS A SCRAP OF PAPER WITH A SCRIBBLE ON IT, never a
## shape. A square is one of the fifty classes (so are a circle and a triangle), and a
## tutorial that animates one at the moment the player is choosing what to draw is a hint
## the level did not mean to give.

## Every picture `_draw` knows. `keys` is the plain row of caps; anything unknown draws as that.
const KINDS := ["keys", "walk", "jump", "hold", "draw_key", "revert", "place", "take_back",
	"rotate", "resize", "draw", "click", "clock", "ink", "checkpoint", "requirement"]
const SIZE := Vector2(440.0, 150.0)
const CAP_HEIGHT := 50.0
const CAP_TRAVEL := 5.0
const CAP_FONT := 24
const PAPER := Color(0.965, 0.95, 0.9, 1.0)
const SCRIBBLE := Color(0.16, 0.13, 0.09, 1.0)
const FIGURE := UISkin.CREAM_TEXT
const LIT := UISkin.GOLD
const DIM_LINE := Color(UISkin.CREAM_TEXT, 0.35)

## What to show. One of the names `_draw` matches; anything else is a row of key caps.
var kind := "keys"
## The key caps, as the player's keyboard labels them.
var caps := PackedStringArray()
## A small mouse in the corner, its button blinking: this card goes when you click.
var waits_for_click := false

var _t := 0.0
## Seconds since the player did the thing, or < 0 while they have not.
var _done := -1.0
var _boxes := {}


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_kind(new_kind: String, new_caps: PackedStringArray, click_to_continue: bool) -> void:
	kind = new_kind
	caps = new_caps
	waits_for_click = click_to_continue
	_t = 0.0
	_done = -1.0
	queue_redraw()


## The player did it: a tick lands over the picture while the card goes.
func mark_done() -> void:
	if _done < 0.0:
		_done = 0.0


func is_marked_done() -> bool:
	return _done >= 0.0


func _process(delta: float) -> void:
	_t += delta
	if _done >= 0.0:
		_done += delta
	queue_redraw()


func _draw() -> void:
	match kind:
		"walk":
			_draw_walk()
		"jump":
			_draw_jump()
		"hold":
			_draw_hold()
		"draw_key":
			_draw_draw_key()
		"revert":
			_draw_revert()
		"place":
			_draw_place()
		"take_back":
			_draw_take_back()
		"rotate":
			_draw_rotate()
		"resize":
			_draw_resize()
		"draw":
			_draw_drawing()
		"click":
			_draw_click()
		"clock":
			_draw_clock()
		"ink":
			_draw_ink()
		"checkpoint":
			_draw_checkpoint()
		"requirement":
			_draw_requirement()
		_:
			_draw_keys()
	if waits_for_click:
		_draw_continue()
	if _done >= 0.0:
		_draw_tick()


# --- the pictures ----------------------------------------------------------------------

## Left key, right key, and the apo walking whichever way the pressed one says.
func _draw_walk() -> void:
	var p := _phase(2.4)
	var left_down := _pulse(p, 0.04, 0.40)
	var right_down := _pulse(p, 0.54, 0.40)
	_cap(Vector2(62.0, 62.0), _cap_label(0, "A"), left_down)
	_cap(Vector2(378.0, 62.0), _cap_label(1, "D"), right_down)
	_chevron(Vector2(62.0, 118.0), Vector2.LEFT, left_down)
	_chevron(Vector2(378.0, 118.0), Vector2.RIGHT, right_down)
	draw_line(Vector2(140.0, 128.0), Vector2(300.0, 128.0), DIM_LINE, 2.0)
	var x := 0.0
	var facing := 1.0
	if p < 0.5:
		x = lerpf(268.0, 172.0, _ease(p / 0.5))
		facing = -1.0
	else:
		x = lerpf(172.0, 268.0, _ease((p - 0.5) / 0.5))
	_figure(Vector2(x, 128.0), facing, true)


## The jump key going down, and the apo going up.
func _draw_jump() -> void:
	var p := _phase(1.6)
	var down := _pulse(p, 0.02, 0.16)
	_cap(Vector2(140.0, 70.0), _cap_label(0, "Space"), down, 168.0)
	var air := clampf((p - 0.08) / 0.5, 0.0, 1.0)
	var lift := sin(PI * air) * 58.0
	draw_line(Vector2(270.0, 128.0), Vector2(370.0, 128.0), DIM_LINE, 2.0)
	_figure(Vector2(320.0, 128.0 - lift), 1.0, false)
	if lift > 2.0:
		_arrow(Vector2(390.0, 112.0), Vector2(390.0, 52.0), Color(LIT, clampf(lift / 40.0, 0.0, 1.0)))


## A key held down while a bar fills, and the apo going up the whole time it is held.
func _draw_hold() -> void:
	var p := _phase(2.4)
	var held := _pulse(p, 0.08, 0.72)
	_cap(Vector2(110.0, 58.0), _cap_label(0, "W"), held)
	var fill := clampf((p - 0.08) / 0.72, 0.0, 1.0) if held > 0.0 else 0.0
	var bar := Rect2(66.0, 104.0, 88.0, 10.0)
	draw_rect(bar, UISkin.INK)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y)), LIT)
	draw_rect(bar, UISkin.RING_MID, false, 2.0)
	# The way up as a dotted line, not rungs: rungs would be a picture of one of the fifty.
	for dot in 9:
		draw_circle(Vector2(320.0, 136.0 - dot * 11.0), 2.0, DIM_LINE)
	var climb := _ease(fill)
	_figure(Vector2(320.0, 136.0 - climb * 84.0), 1.0, held > 0.0)
	_arrow(Vector2(380.0, 120.0), Vector2(380.0, 46.0), Color(LIT, 0.35 + 0.65 * held))


## The draw key, and the scribble it opens the page for.
func _draw_draw_key() -> void:
	var p := _phase(2.2)
	var down := _pulse(p, 0.04, 0.18)
	_cap(Vector2(110.0, 72.0), _cap_label(0, "R"), down)
	_arrow(Vector2(170.0, 72.0), Vector2(226.0, 72.0), Color(LIT, 0.7))
	var page := Rect2(248.0, 22.0, 152.0, 106.0)
	draw_rect(page, PAPER)
	draw_rect(page, UISkin.GOLD_EDGE, false, 3.0)
	_scribble(page.get_center(), Vector2(56.0, 24.0), clampf((p - 0.22) / 0.55, 0.0, 1.0))


## The change-back key, and the drawing the apo was turning back into her.
func _draw_revert() -> void:
	var p := _phase(2.4)
	var down := _pulse(p, 0.30, 0.16)
	_cap(Vector2(96.0, 72.0), _cap_label(0, "Q"), down)
	var turned := clampf((p - 0.34) / 0.12, 0.0, 1.0)
	var spot := Vector2(310.0, 112.0)
	if turned < 1.0:
		_scrap(spot + Vector2(0.0, -30.0), Vector2(64.0, 52.0), 0.0, 1.0 - turned)
	if turned > 0.0:
		_figure(spot + Vector2(0.0, 16.0), 1.0, false, turned)
	if turned > 0.0 and turned < 1.0:
		draw_arc(spot + Vector2(0.0, -26.0), 20.0 + turned * 40.0, 0.0, TAU, 32,
			Color(LIT, 1.0 - turned), 3.0)


## The mouse aiming a drawing, then the left button setting it down.
func _draw_place() -> void:
	var p := _phase(2.6)
	var aim := clampf(p / 0.55, 0.0, 1.0)
	var x := 220.0 + sin(aim * TAU) * 70.0
	var click := _pulse(p, 0.58, 0.12)
	var set_down := p >= 0.6
	draw_line(Vector2(90.0, 92.0), Vector2(350.0, 92.0), DIM_LINE, 2.0)
	var scrap_y := 64.0 if set_down else 52.0
	_scrap(Vector2(x if not set_down else 220.0, scrap_y), Vector2(84.0, 52.0), 0.0,
		1.0 if set_down else 0.5)
	if set_down and p < 0.75:
		var dust := (p - 0.6) / 0.15
		for side: float in [-1.0, 1.0]:
			draw_line(Vector2(220.0 + side * (46.0 + dust * 16.0), 90.0),
				Vector2(220.0 + side * (56.0 + dust * 22.0), 84.0 - dust * 6.0),
				Color(FIGURE, 1.0 - dust), 2.0)
	_mouse(Vector2(x if not set_down else 220.0, 126.0), click, 0.0, 0.0, 0.62)


## A drawing already set down, the right button, and the drawing going back to the bag.
func _draw_take_back() -> void:
	var p := _phase(2.6)
	var click := _pulse(p, 0.25, 0.12)
	var gone := clampf((p - 0.3) / 0.35, 0.0, 1.0)
	var from := Vector2(150.0, 64.0)
	var bag := Vector2(370.0, 92.0)
	draw_line(Vector2(80.0, 96.0), Vector2(220.0, 96.0), DIM_LINE, 2.0)
	_bag(bag)
	if gone < 1.0:
		var at := from.lerp(bag + Vector2(0.0, -10.0), _ease(gone))
		_scrap(at - Vector2(0.0, sin(gone * PI) * 40.0), Vector2(84.0, 52.0) * (1.0 - 0.7 * gone),
			gone * 0.6, 1.0)
	_mouse(Vector2(262.0, 86.0), 0.0, click, 0.0, 0.7)


## Two keys, the wheel, and the drawing turning one way and then the other.
func _draw_rotate() -> void:
	var p := _phase(2.8)
	var first := _pulse(p, 0.04, 0.40)
	var second := _pulse(p, 0.54, 0.40)
	_cap(Vector2(46.0, 60.0), _cap_label(0, "Z"), first)
	_cap(Vector2(112.0, 60.0), _cap_label(1, "X"), second)
	_chevron_turn(Vector2(46.0, 116.0), -1.0, first)
	_chevron_turn(Vector2(112.0, 116.0), 1.0, second)
	_plus(Vector2(158.0, 70.0))
	var wheel := -1.0 if first > 0.0 else (1.0 if second > 0.0 else 0.0)
	_mouse(Vector2(212.0, 76.0), 0.0, 0.0, wheel, 0.85)
	var angle := 0.0
	if p < 0.5:
		angle = -0.8 * _ease(p / 0.5)
	else:
		angle = -0.8 + 0.8 * _ease((p - 0.5) / 0.5)
	_arrow(Vector2(258.0, 76.0), Vector2(290.0, 76.0), Color(LIT, 0.7))
	_scrap(Vector2(354.0, 76.0), Vector2(84.0, 56.0), angle, 1.0)


## Kent: "For the resizing, add like the resize icon or animation that represents it." The
## size keys and Shift with the wheel, beside a drawing growing with its corner arrows
## pointing out, then shrinking with them pointing in.
func _draw_resize() -> void:
	var p := _phase(3.0)
	var shrink := _pulse(p, 0.54, 0.40)
	var grow := _pulse(p, 0.04, 0.40)
	_cap(Vector2(34.0, 60.0), _cap_label(0, "C"), shrink, 44.0)
	_cap(Vector2(88.0, 60.0), _cap_label(1, "V"), grow, 44.0)
	_chevron(Vector2(34.0, 116.0), Vector2.DOWN, shrink)
	_chevron(Vector2(88.0, 116.0), Vector2.UP, grow)
	_plus(Vector2(130.0, 70.0))
	var held := maxf(grow, shrink)
	_cap(Vector2(186.0, 46.0), "Shift", held, 74.0)
	var wheel := -1.0 if grow > 0.0 else (1.0 if shrink > 0.0 else 0.0)
	_mouse(Vector2(186.0, 112.0), 0.0, 0.0, wheel, 0.5)
	var size := 1.0
	if p < 0.5:
		size = lerpf(0.62, 1.22, _ease(p / 0.5))
	else:
		size = lerpf(1.22, 0.62, _ease((p - 0.5) / 0.5))
	var centre := Vector2(338.0, 76.0)
	var extent := Vector2(76.0, 50.0) * size
	_scrap(centre, extent, 0.0, 1.0)
	# The resize icon: an arrow out of every corner while it grows, into it while it shrinks.
	var outward := p < 0.5
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var tip := centre + Vector2(corner.x * extent.x, corner.y * extent.y) * 0.5
		var away := tip + corner * 18.0
		if outward:
			_arrow(tip + corner * 4.0, away + corner * 6.0, LIT, 3.0)
		else:
			_arrow(away + corner * 6.0, tip + corner * 4.0, LIT, 3.0)


## The page, the mouse held down, and a line following it across.
func _draw_drawing() -> void:
	var p := _phase(2.6)
	var page := Rect2(60.0, 14.0, 250.0, 122.0)
	draw_rect(page, PAPER)
	draw_rect(page, UISkin.GOLD_EDGE, false, 3.0)
	var progress := clampf(p / 0.7, 0.0, 1.0)
	var tip := _scribble(page.get_center(), Vector2(96.0, 34.0), progress)
	var drawing := p < 0.7
	_cursor(tip)
	_mouse(Vector2(372.0, 82.0), 1.0 if drawing else 0.0, 0.0, 0.0, 0.8)


## A cursor going to the big button and pressing it.
func _draw_click() -> void:
	var p := _phase(2.2)
	var travel := _ease(clampf(p / 0.45, 0.0, 1.0))
	var press := _pulse(p, 0.48, 0.14)
	var button := Rect2(196.0, 46.0, 190.0, 58.0)
	var sink := Vector2(0.0, 3.0 * press)
	draw_rect(Rect2(button.position + Vector2(0.0, 4.0), button.size), UISkin.GOLD_EDGE)
	draw_rect(Rect2(button.position + sink, button.size), UISkin.GOLD_FILL.lerp(UISkin.GOLD_DARK, press))
	draw_rect(Rect2(button.position + sink, button.size), UISkin.GOLD_LIT, false, 2.0)
	_sparkle(button.get_center() + sink, 14.0, UISkin.GOLD_LABEL)
	if p > 0.5 and p < 0.8:
		var burst := (p - 0.5) / 0.3
		for i in 8:
			var dir := Vector2.RIGHT.rotated(TAU * float(i) / 8.0)
			draw_line(button.get_center() + dir * (40.0 + burst * 30.0),
				button.get_center() + dir * (52.0 + burst * 34.0), Color(LIT, 1.0 - burst), 3.0)
	var tip := Vector2(70.0, 128.0).lerp(button.get_center() + Vector2(30.0, 6.0), travel)
	_cursor(tip)


## The drawing's life: a bar running down, and when it is empty, the apo again.
func _draw_clock() -> void:
	var p := _phase(3.0)
	var left := 1.0 - clampf(p / 0.75, 0.0, 1.0)
	var bar := Rect2(150.0, 64.0, 250.0, 22.0)
	draw_rect(bar, UISkin.INK)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * left, bar.size.y)),
		LIT if left > 0.25 else UISkin.RED_FILL)
	draw_rect(bar, UISkin.RING_MID, false, 2.0)
	var spot := Vector2(76.0, 100.0)
	if left > 0.0:
		_scrap(spot + Vector2(0.0, -26.0), Vector2(70.0, 54.0), 0.0, 1.0)
	else:
		var back := clampf((p - 0.75) / 0.1, 0.0, 1.0)
		_figure(spot + Vector2(0.0, 20.0), 1.0, false, back)
		if back < 1.0:
			draw_arc(spot + Vector2(0.0, -22.0), 18.0 + back * 36.0, 0.0, TAU, 32,
				Color(LIT, 1.0 - back), 3.0)


## The ink: a row of notches, and a drop leaving it each time something is made.
func _draw_ink() -> void:
	var p := _phase(3.6)
	var spent := int(floor(p * 3.0))
	var within := fmod(p * 3.0, 1.0)
	var notches := 6
	for i in notches:
		var cell := Rect2(70.0 + i * 52.0, 40.0, 42.0, 30.0)
		var full := i < notches - spent - (1 if within > 0.35 else 0)
		draw_rect(cell, UISkin.INK)
		if full:
			draw_rect(cell.grow(-4.0), Color(0.18, 0.32, 0.55, 1.0))
		draw_rect(cell, UISkin.RING_MID, false, 2.0)
	var leaving := notches - spent - 1
	if leaving >= 0 and within > 0.35:
		var fall := clampf((within - 0.35) / 0.5, 0.0, 1.0)
		var at := Vector2(91.0 + leaving * 52.0, 76.0 + fall * 52.0)
		_drop(at, Color(0.32, 0.5, 0.82, 1.0 - fall))


## A checkpoint: the apo falls, and comes back beside the lantern.
func _draw_checkpoint() -> void:
	var p := _phase(3.0)
	var lantern := Vector2(300.0, 92.0)
	_lantern(lantern)
	draw_line(Vector2(90.0, 128.0), Vector2(210.0, 128.0), DIM_LINE, 2.0)
	draw_line(Vector2(250.0, 128.0), Vector2(380.0, 128.0), DIM_LINE, 2.0)
	if p < 0.45:
		var walk := _ease(clampf(p / 0.3, 0.0, 1.0))
		var drop := clampf((p - 0.3) / 0.15, 0.0, 1.0)
		_figure(Vector2(lerpf(120.0, 228.0, walk), 128.0 + drop * drop * 60.0), 1.0, p < 0.3,
			1.0 - drop)
	else:
		var back := clampf((p - 0.5) / 0.15, 0.0, 1.0)
		var at := lantern + Vector2(-46.0, 36.0)
		_figure(at, 1.0, false, back)
		if back > 0.0 and back < 1.0:
			draw_arc(at + Vector2(0.0, -30.0), 16.0 + back * 34.0, 0.0, TAU, 32,
				Color(LIT, 1.0 - back), 3.0)


## The word at the top is something to DO: the word, an arrow, the apo doing it.
func _draw_requirement() -> void:
	var p := _phase(2.4)
	var chip := Rect2(40.0, 48.0, 150.0, 44.0)
	draw_rect(chip, UISkin.PANEL_LIT)
	draw_rect(chip, LIT, false, 3.0)
	for i in 3:
		draw_rect(Rect2(chip.position + Vector2(18.0 + i * 40.0, 16.0), Vector2(30.0, 12.0)),
			UISkin.CREAM_TEXT)
	_arrow(Vector2(204.0, 70.0), Vector2(250.0, 70.0), LIT, 4.0)
	# The apo DOING something -- moving, with the lines behind her -- and nothing being made.
	# Anything she climbed onto or crossed here would be a picture of an answer.
	var go := _ease(clampf((p - 0.15) / 0.6, 0.0, 1.0))
	var at := Vector2(lerpf(290.0, 380.0, go), 112.0)
	draw_line(Vector2(270.0, 112.0), Vector2(410.0, 112.0), DIM_LINE, 2.0)
	if go > 0.0 and go < 1.0:
		for i in 3:
			var y := at.y - 34.0 + i * 10.0
			draw_line(Vector2(at.x - 18.0 - i * 4.0, y), Vector2(at.x - 36.0 - i * 6.0, y),
				Color(LIT, 0.8), 2.0)
	_figure(at, 1.0, go > 0.0 and go < 1.0)


## A row of caps pressed in turn: one key, or a run of them like the bag's 1 to 6.
func _draw_keys() -> void:
	if caps.is_empty():
		return
	var count := caps.size()
	var widths: Array[float] = []
	var total := 0.0
	for label in caps:
		var w := _cap_width(label, 52.0 if count < 5 else 46.0)
		widths.append(w)
		total += w
	var gap := 14.0 if count < 5 else 8.0
	total += gap * float(count - 1)
	var x := (SIZE.x - total) * 0.5
	var step := 0.5
	var p := _phase(maxf(1.3, step * float(count) + 0.4))
	var seconds := p * maxf(1.3, step * float(count) + 0.4)
	for i in count:
		var down := 0.0
		if count == 1:
			down = _pulse(p, 0.1, 0.3)
		else:
			down = _pulse(seconds, 0.2 + step * float(i), step * 0.6)
		var centre := Vector2(x + widths[i] * 0.5, 66.0)
		_cap(centre, caps[i], down, widths[i])
		if down > 0.0:
			_ripple(centre, widths[i], down)
		x += widths[i] + gap


# --- the parts -------------------------------------------------------------------------

## A key cap: the side of the key below, the face on top, and the face goes down when the
## key does. The face is gold like every key the HUD draws.
func _cap(centre: Vector2, label: String, down: float, min_width := 52.0) -> void:
	var w := _cap_width(label, min_width)
	var h := CAP_HEIGHT
	var base := Rect2(centre.x - w * 0.5, centre.y - h * 0.5 + CAP_TRAVEL, w, h)
	draw_rect(Rect2(base.position + Vector2(0.0, 2.0), base.size), Color(0, 0, 0, 0.35))
	draw_rect(base, UISkin.GOLD_EDGE)
	var face := Rect2(base.position - Vector2(0.0, CAP_TRAVEL * (1.0 - down)), base.size)
	draw_rect(face, UISkin.GOLD_FILL.lerp(UISkin.GOLD_DARK, down * 0.7))
	draw_line(face.position + Vector2(2.0, 2.0), face.position + Vector2(face.size.x - 2.0, 2.0),
		UISkin.GOLD_LIT.lerp(UISkin.GILT_HI, 0.5 * (1.0 - down)), 2.0)
	draw_rect(face, UISkin.GOLD_EDGE, false, 2.0)
	var font := get_theme_default_font()
	if font == null:
		return
	var baseline := face.position.y + (h + font.get_ascent(CAP_FONT) - font.get_descent(CAP_FONT)) * 0.5
	draw_string(font, Vector2(face.position.x, baseline), label, HORIZONTAL_ALIGNMENT_CENTER,
		face.size.x, CAP_FONT, UISkin.GOLD_LABEL)


func _cap_width(label: String, min_width: float) -> float:
	var font := get_theme_default_font()
	var text := 0.0
	if font != null:
		text = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, CAP_FONT).x
	return maxf(min_width, text + 26.0)


func _cap_label(index: int, fallback: String) -> String:
	return caps[index] if index < caps.size() and not caps[index].is_empty() else fallback


## A mouse: the body, the two buttons (lit while pressed), and the wheel with chevrons
## running the way it is being turned (-1 away from you, +1 towards you).
func _mouse(centre: Vector2, left: float, right: float, wheel: float, scale := 1.0) -> void:
	var size := Vector2(62.0, 92.0) * scale
	var body := Rect2(centre - size * 0.5, size)
	var split := body.position.y + size.y * 0.42
	draw_style_box(_box("mouse_%.2f" % scale, UISkin.PANEL_LIT, UISkin.CREAM_TEXT,
		maxf(2.0, 3.0 * scale), size.x * 0.48), body)
	var inset := 3.0 * scale
	var button_size := Vector2(size.x * 0.5 - inset - 1.0, split - body.position.y - inset)
	if left > 0.0:
		draw_style_box(_box("left_%.2f" % scale, Color(LIT, left), Color(0, 0, 0, 0), 0.0,
			size.x * 0.44, true, false), Rect2(body.position + Vector2(inset, inset), button_size))
	if right > 0.0:
		draw_style_box(_box("right_%.2f" % scale, Color(LIT, right), Color(0, 0, 0, 0), 0.0,
			size.x * 0.44, false, true),
			Rect2(Vector2(centre.x + 1.0, body.position.y + inset), button_size))
	draw_line(Vector2(centre.x, body.position.y + 2.0), Vector2(centre.x, split),
		UISkin.CREAM_TEXT, maxf(1.5, 2.0 * scale))
	draw_line(Vector2(body.position.x + 2.0, split), Vector2(body.end.x - 2.0, split),
		UISkin.CREAM_TEXT, maxf(1.5, 2.0 * scale))
	var wheel_rect := Rect2(centre.x - 5.0 * scale, body.position.y + size.y * 0.1,
		10.0 * scale, size.y * 0.22)
	draw_rect(wheel_rect, LIT if wheel != 0.0 else UISkin.INK)
	draw_rect(wheel_rect, UISkin.CREAM_TEXT, false, maxf(1.0, 1.5 * scale))
	if wheel != 0.0:
		var run := fmod(_t * 2.2, 1.0)
		var dir := Vector2(0.0, signf(wheel))
		for i in 2:
			var along := fmod(run + 0.5 * float(i), 1.0)
			var at := Vector2(body.end.x + 14.0 * scale,
				centre.y - size.y * 0.25 + dir.y * (along - 0.5) * size.y * 0.5)
			_chevron(at, dir, 1.0 - along, 7.0 * maxf(scale, 0.7))


## The arrow pointer.
func _cursor(tip: Vector2) -> void:
	var shape := PackedVector2Array([tip, tip + Vector2(0.0, 28.0), tip + Vector2(7.0, 21.0),
		tip + Vector2(12.0, 32.0), tip + Vector2(17.0, 30.0), tip + Vector2(12.0, 19.0),
		tip + Vector2(21.0, 19.0)])
	draw_colored_polygon(shape, UISkin.CREAM_TEXT)
	shape.append(tip)
	draw_polyline(shape, UISkin.INK, 2.0)


## "Your drawing": a scrap of paper with a scribble on it. Never a shape -- see the top.
func _scrap(centre: Vector2, extent: Vector2, angle: float, alpha: float) -> void:
	if alpha <= 0.01:
		return
	draw_set_transform(centre, angle, Vector2.ONE)
	var rect := Rect2(-extent * 0.5, extent)
	draw_rect(rect, Color(PAPER, alpha))
	draw_rect(rect, Color(UISkin.GOLD_EDGE, alpha), false, 2.0)
	var points := PackedVector2Array()
	for i in 13:
		var u := float(i) / 12.0
		points.append(Vector2(lerpf(-extent.x * 0.32, extent.x * 0.32, u),
			sin(u * TAU * 1.5) * extent.y * 0.22))
	draw_polyline(points, Color(SCRIBBLE, alpha), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A scribble drawn up to `progress`, returning where the pen is.
func _scribble(centre: Vector2, extent: Vector2, progress: float) -> Vector2:
	var points := PackedVector2Array()
	var steps := 40
	var last := centre - Vector2(extent.x, 0.0)
	for i in steps + 1:
		var u := float(i) / float(steps)
		if u > progress:
			break
		last = centre + Vector2(lerpf(-extent.x, extent.x, u),
			sin(u * TAU * 1.5) * extent.y - cos(u * TAU * 3.0) * extent.y * 0.25)
		points.append(last)
	if points.size() > 1:
		draw_polyline(points, SCRIBBLE, 4.0)
	return last


## The apo, small: a head, a body, legs that swing while walking. `facing` is ±1.
func _figure(feet: Vector2, facing: float, walking: bool, alpha := 1.0) -> void:
	if alpha <= 0.01:
		return
	var colour := Color(FIGURE, alpha)
	var swing := sin(_t * 14.0) * 7.0 if walking else 0.0
	var hip := feet + Vector2(0.0, -20.0)
	draw_line(hip, feet + Vector2(swing, 0.0), colour, 4.0)
	draw_line(hip, feet + Vector2(-swing, 0.0), colour, 4.0)
	var neck := hip + Vector2(0.0, -22.0)
	draw_line(hip, neck, colour, 6.0)
	draw_line(neck + Vector2(0.0, 4.0), neck + Vector2(facing * 10.0 - swing * 0.4, 16.0), colour, 3.0)
	draw_circle(neck + Vector2(0.0, -9.0), 8.0, colour)
	draw_circle(neck + Vector2(facing * 3.5, -10.0), 1.8, Color(UISkin.INK, alpha))


func _bag(at: Vector2) -> void:
	var body := Rect2(at - Vector2(28.0, 22.0), Vector2(56.0, 46.0))
	draw_style_box(_box("bag", UISkin.WOOD, UISkin.WOOD_LIT, 2.0, 14.0), body)
	draw_line(at + Vector2(-14.0, -22.0), at + Vector2(-8.0, -32.0), UISkin.WOOD_LIT, 3.0)
	draw_line(at + Vector2(14.0, -22.0), at + Vector2(8.0, -32.0), UISkin.WOOD_LIT, 3.0)
	draw_line(at + Vector2(-8.0, -32.0), at + Vector2(8.0, -32.0), UISkin.WOOD_LIT, 3.0)


func _lantern(at: Vector2) -> void:
	var flicker := 0.85 + 0.15 * sin(_t * 9.0)
	draw_circle(at + Vector2(0.0, -6.0), 34.0 * flicker, Color(LIT, 0.16))
	draw_rect(Rect2(at - Vector2(14.0, 22.0), Vector2(28.0, 36.0)), UISkin.WOOD_DARK)
	draw_rect(Rect2(at - Vector2(10.0, 18.0), Vector2(20.0, 28.0)), Color(LIT, 0.55 * flicker))
	var flame := PackedVector2Array([at + Vector2(0.0, -14.0 - 4.0 * flicker),
		at + Vector2(6.0, 4.0), at + Vector2(-6.0, 4.0)])
	draw_colored_polygon(flame, UISkin.GILT_HI)
	draw_line(at + Vector2(0.0, 14.0), at + Vector2(0.0, 36.0), UISkin.WOOD_DARK, 4.0)


func _drop(at: Vector2, colour: Color) -> void:
	draw_circle(at + Vector2(0.0, 4.0), 7.0, colour)
	draw_colored_polygon(PackedVector2Array([at + Vector2(0.0, -10.0), at + Vector2(6.0, 2.0),
		at + Vector2(-6.0, 2.0)]), colour)


func _sparkle(at: Vector2, radius: float, colour: Color) -> void:
	var points := PackedVector2Array()
	for i in 8:
		var r := radius if i % 2 == 0 else radius * 0.35
		points.append(at + Vector2.UP.rotated(TAU * float(i) / 8.0) * r)
	draw_colored_polygon(points, colour)


func _arrow(from: Vector2, to: Vector2, colour: Color, width := 4.0) -> void:
	var dir := (to - from).normalized()
	if dir == Vector2.ZERO:
		return
	var head := 4.0 + width * 2.2
	draw_line(from, to - dir * head * 0.6, colour, width)
	draw_colored_polygon(PackedVector2Array([to, to - dir * head + dir.orthogonal() * head * 0.6,
		to - dir * head - dir.orthogonal() * head * 0.6]), colour)


## A small solid triangle pointing `dir`, lit by `lit` (0..1).
func _chevron(at: Vector2, dir: Vector2, lit: float, size := 10.0) -> void:
	var colour := DIM_LINE.lerp(LIT, clampf(lit, 0.0, 1.0))
	var side := dir.orthogonal()
	draw_colored_polygon(PackedVector2Array([at + dir * size, at - dir * size * 0.6 + side * size,
		at - dir * size * 0.6 - side * size]), colour)


## A curved arrow under a turn key: anticlockwise for -1, clockwise for +1.
func _chevron_turn(at: Vector2, turn: float, lit: float) -> void:
	var colour := DIM_LINE.lerp(LIT, clampf(lit, 0.0, 1.0))
	var start := PI * 1.15
	var end := PI * 1.85
	draw_arc(at, 14.0, start, end, 12, colour, 3.0)
	var tip_angle := end if turn > 0.0 else start
	var tip := at + Vector2.RIGHT.rotated(tip_angle) * 14.0
	var along := Vector2.RIGHT.rotated(tip_angle + PI * 0.5 * signf(turn))
	_chevron(tip + along * 2.0, along, lit, 6.0)


func _plus(at: Vector2) -> void:
	draw_line(at + Vector2(-8.0, 0.0), at + Vector2(8.0, 0.0), DIM_LINE, 3.0)
	draw_line(at + Vector2(0.0, -8.0), at + Vector2(0.0, 8.0), DIM_LINE, 3.0)


func _ripple(centre: Vector2, width: float, down: float) -> void:
	var colour := Color(LIT, 0.55 * down)
	for side: float in [-1.0, 1.0]:
		var corner := centre + Vector2(side * (width * 0.5 + 8.0), -CAP_HEIGHT * 0.5)
		draw_line(corner, corner + Vector2(side * 8.0, -8.0), colour, 3.0)
	draw_line(centre + Vector2(0.0, -CAP_HEIGHT * 0.5 - 8.0),
		centre + Vector2(0.0, -CAP_HEIGHT * 0.5 - 18.0), colour, 3.0)


## Bottom right: a small mouse with its left button blinking -- this goes when you click.
func _draw_continue() -> void:
	var blink := 0.5 + 0.5 * sin(_t * 6.0)
	_mouse(Vector2(SIZE.x - 14.0, SIZE.y - 22.0), blink, 0.0, 0.0, 0.36)


func _draw_tick() -> void:
	var grow := clampf(_done / 0.18, 0.0, 1.0)
	var centre := SIZE * 0.5
	draw_circle(centre, 46.0 * grow, Color(UISkin.PANEL, 0.86))
	var points := PackedVector2Array([centre + Vector2(-22.0, 2.0) * grow,
		centre + Vector2(-6.0, 18.0) * grow, centre + Vector2(24.0, -16.0) * grow])
	draw_polyline(points, UISkin.USE_LIT, 8.0)


# --- time --------------------------------------------------------------------------------

func _phase(cycle: float) -> float:
	return fmod(_t, cycle) / cycle


## 1 inside [start, start + length] with short ramps either side, 0 outside.
func _pulse(phase: float, start: float, length: float) -> float:
	if phase < start or phase > start + length:
		return 0.0
	var ramp := 0.05
	return clampf(minf(phase - start, start + length - phase) / ramp, 0.0, 1.0)


func _ease(u: float) -> float:
	var x := clampf(u, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## One box per shape, recoloured on every use. The colours change every frame (a button
## fading in), and keying the cache on them grew it by a box a frame for as long as a card
## was up. A StyleBox is read when it is drawn, so recolouring a shared one is safe.
func _box(key: String, fill: Color, edge: Color, border: float, radius: float,
		round_left := true, round_right := true) -> StyleBoxFlat:
	var shape_key := "%s|%s|%s" % [key, border, radius]
	var box := _boxes.get(shape_key) as StyleBoxFlat
	if box == null:
		box = StyleBoxFlat.new()
		box.set_border_width_all(int(round(border)))
		box.corner_radius_top_left = int(radius) if round_left else 2
		box.corner_radius_top_right = int(radius) if round_right else 2
		box.corner_radius_bottom_left = int(radius) if round_left and round_right else 2
		box.corner_radius_bottom_right = int(radius) if round_left and round_right else 2
		box.anti_aliasing = true
		_boxes[shape_key] = box
	box.bg_color = fill
	box.border_color = edge
	return box
