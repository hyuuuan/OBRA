extends RefCounted
## Creatures drawn the way people actually draw them, every stroke labelled with the part it is.
##
## Modelled on the Quick, Draw! training drawings in model/data (Kent, 2026-10-24: "some
## creatures act weird when they are drawn differently -- a bird's wing does not flap"). The
## roster fixtures draw each archetype the one way its skeleton was authored for; these draw
## the ways players do: birds and bees from the SIDE with the wings on the back, fish and
## horses facing LEFT as often as right, a pig or a monkey as just a face, an octopus with its
## arms hanging, a turtle seen from above, a crab or an ant with more legs than four.
##
## Parts: body / head / detail must stay with the body (a limb bone must not swing them);
## wing / leg / tail / fin / tentacle / arm must be carried by a bone that moves that kind of
## part; free is not scored (ears, a trunk, a stinger -- either is fine).

const CANVAS := 512.0


static func all() -> Array:
	var out: Array = []
	out.append(_named("bird from the side, facing right", "bird", _bird_side()))
	out.append(_named("bird from the side, facing left", "bird", mirrored(_bird_side())))
	out.append(_named("bird with its wing drawn on its side", "bird", _bird_inner_wing()))
	out.append(_named("bird as a seagull M", "bird", _bird_seagull()))
	out.append(_named("bee from the side", "bee", _bee_side()))
	out.append(_named("bat with its wings spread", "bat", _bat_front()))
	out.append(_named("butterfly", "butterfly", _butterfly()))
	out.append(_named("fish facing right", "fish", _fish()))
	out.append(_named("fish facing left", "fish", mirrored(_fish())))
	out.append(_named("horse facing right", "horse", _horse()))
	out.append(_named("horse facing left", "horse", mirrored(_horse())))
	out.append(_named("pig as just a face", "pig", _pig_face()))
	out.append(_named("pig from the side", "pig", _pig_side()))
	out.append(_named("monkey as just a face", "monkey", _monkey_face()))
	out.append(_named("octopus with its arms hanging", "octopus", _octopus()))
	out.append(_named("sea turtle seen from above", "sea_turtle", _turtle_top()))
	out.append(_named("frog sitting", "frog", _frog()))
	out.append(_named("elephant facing left", "elephant", _elephant_left()))
	out.append(_named("crab with six legs and two claws", "crab", _crab()))
	out.append(_named("ant from the side, six legs", "ant", _ant()))
	out.append(_named("penguin standing", "penguin", _penguin()))
	return out


## The same drawing facing the other way.
static func mirrored(strokes: Array) -> Array:
	var out: Array = []
	for value in strokes:
		var stroke: Dictionary = (value as Dictionary).duplicate()
		var points := PackedVector2Array()
		for point in stroke["points"] as PackedVector2Array:
			points.append(Vector2(CANVAS - point.x, point.y))
		stroke["points"] = points
		out.append(stroke)
	return out


static func _bird_side() -> Array:
	return [
		_part("body", oval(250, 270, 80, 46)),
		_part("head", oval(335, 218, 30, 28)),
		_part("detail", line([Vector2(362, 210), Vector2(394, 218), Vector2(362, 227)])),
		_part("detail", oval(342, 210, 4, 4)),
		_part("wing", line([Vector2(212, 238), Vector2(238, 176), Vector2(268, 148), Vector2(292, 232)])),
		_part("tail", line([Vector2(172, 262), Vector2(118, 236)])),
		_part("tail", line([Vector2(172, 280), Vector2(116, 284)])),
		_part("free", line([Vector2(236, 314), Vector2(232, 362)])),
		_part("free", line([Vector2(266, 314), Vector2(270, 362)])),
	]


static func _bird_inner_wing() -> Array:
	return [
		_part("body", oval(250, 272, 92, 54)),
		_part("head", oval(348, 222, 30, 28)),
		_part("detail", line([Vector2(375, 214), Vector2(404, 222), Vector2(375, 230)])),
		_part("detail", oval(354, 214, 4, 4)),
		_part("wing", line([Vector2(212, 262), Vector2(246, 236), Vector2(298, 252), Vector2(250, 292), Vector2(212, 262)])),
		_part("tail", line([Vector2(160, 262), Vector2(110, 240)])),
		_part("tail", line([Vector2(160, 280), Vector2(108, 288)])),
	]


static func _bird_seagull() -> Array:
	return [_part("wing", line([
		Vector2(100, 262), Vector2(140, 214), Vector2(186, 206), Vector2(226, 236), Vector2(256, 258),
		Vector2(286, 236), Vector2(326, 206), Vector2(372, 214), Vector2(412, 262),
	]))]


static func _bee_side() -> Array:
	return [
		_part("body", oval(250, 282, 82, 50)),
		_part("detail", line([Vector2(222, 236), Vector2(222, 328)])),
		_part("detail", line([Vector2(252, 232), Vector2(252, 332)])),
		_part("detail", line([Vector2(282, 236), Vector2(282, 328)])),
		_part("head", oval(350, 272, 24, 24)),
		_part("detail", line([Vector2(358, 250), Vector2(374, 214)])),
		_part("wing", oval(232, 196, 26, 40)),
		_part("wing", oval(276, 192, 24, 38)),
		_part("free", line([Vector2(168, 282), Vector2(142, 288)])),
	]


static func _bat_front() -> Array:
	var left := line([
		Vector2(228, 248), Vector2(176, 212), Vector2(112, 224), Vector2(128, 258), Vector2(150, 250),
		Vector2(162, 280), Vector2(190, 266), Vector2(228, 282),
	])
	var right := PackedVector2Array()
	for point in left:
		right.append(Vector2(CANVAS - point.x, point.y))
	return [
		_part("body", oval(256, 262, 28, 40)),
		_part("detail", line([Vector2(242, 226), Vector2(238, 200), Vector2(250, 222)])),
		_part("detail", line([Vector2(270, 226), Vector2(274, 200), Vector2(262, 222)])),
		_part("wing", left),
		_part("wing", right),
	]


static func _butterfly() -> Array:
	return [
		_part("body", oval(256, 256, 10, 62)),
		_part("wing", oval(198, 214, 50, 44)),
		_part("wing", oval(208, 300, 40, 36)),
		_part("wing", oval(314, 214, 50, 44)),
		_part("wing", oval(304, 300, 40, 36)),
		_part("detail", line([Vector2(250, 196), Vector2(232, 160)])),
		_part("detail", line([Vector2(262, 196), Vector2(280, 160)])),
	]


static func _fish() -> Array:
	return [
		_part("body", oval(272, 256, 96, 50)),
		_part("tail", line([Vector2(178, 256), Vector2(118, 214), Vector2(118, 298), Vector2(178, 256)])),
		_part("detail", oval(332, 246, 6, 6)),
		_part("fin", line([Vector2(246, 210), Vector2(272, 178), Vector2(300, 210)])),
	]


static func _horse() -> Array:
	return [
		_part("body", oval(250, 250, 92, 40)),
		_part("head", line([
			Vector2(318, 228), Vector2(350, 170), Vector2(386, 164), Vector2(394, 190), Vector2(356, 200), Vector2(336, 244),
		])),
		_part("detail", oval(374, 178, 3, 3)),
		_part("leg", line([Vector2(184, 280), Vector2(182, 372)])),
		_part("leg", line([Vector2(210, 286), Vector2(212, 372)])),
		_part("leg", line([Vector2(290, 286), Vector2(288, 372)])),
		_part("leg", line([Vector2(316, 280), Vector2(320, 372)])),
		_part("tail", line([Vector2(160, 240), Vector2(126, 268), Vector2(120, 302)])),
	]


static func _pig_face() -> Array:
	return [
		_part("body", oval(256, 260, 100, 90)),
		_part("free", line([Vector2(186, 192), Vector2(176, 134), Vector2(228, 172)])),
		_part("free", line([Vector2(326, 192), Vector2(336, 134), Vector2(284, 172)])),
		_part("detail", oval(256, 290, 36, 24)),
		_part("detail", oval(244, 290, 5, 7)),
		_part("detail", oval(268, 290, 5, 7)),
		_part("detail", oval(214, 238, 6, 6)),
		_part("detail", oval(298, 238, 6, 6)),
	]


static func _pig_side() -> Array:
	return [
		_part("body", oval(248, 262, 86, 52)),
		_part("head", oval(344, 246, 38, 36)),
		_part("detail", oval(382, 252, 12, 14)),
		_part("detail", oval(352, 236, 4, 4)),
		_part("leg", line([Vector2(196, 306), Vector2(196, 348)])),
		_part("leg", line([Vector2(222, 312), Vector2(222, 350)])),
		_part("leg", line([Vector2(278, 312), Vector2(278, 350)])),
		_part("leg", line([Vector2(304, 306), Vector2(304, 348)])),
		_part("tail", line([Vector2(162, 250), Vector2(140, 236), Vector2(132, 252), Vector2(146, 260), Vector2(140, 274)])),
	]


static func _monkey_face() -> Array:
	return [
		_part("body", oval(256, 256, 90, 95)),
		_part("free", oval(150, 252, 26, 30)),
		_part("free", oval(362, 252, 26, 30)),
		_part("detail", oval(256, 284, 56, 44)),
		_part("detail", oval(226, 236, 7, 7)),
		_part("detail", oval(286, 236, 7, 7)),
		_part("detail", line([Vector2(232, 300), Vector2(256, 312), Vector2(280, 300)])),
	]


static func _octopus() -> Array:
	var strokes: Array = [_part("body", line([
		Vector2(180, 262), Vector2(186, 196), Vector2(222, 152), Vector2(256, 142), Vector2(290, 152),
		Vector2(326, 196), Vector2(332, 262), Vector2(180, 262),
	]))]
	for index in range(6):
		var x := 192.0 + index * 25.6
		var points := PackedVector2Array()
		for step in range(7):
			points.append(Vector2(x + sin(float(step) * 1.1) * 8.0 + (x - 256.0) * 0.06 * step, 266.0 + step * 20.0))
		strokes.append(_part("tentacle", points))
	strokes.append(_part("detail", oval(232, 214, 6, 6)))
	strokes.append(_part("detail", oval(280, 214, 6, 6)))
	return strokes


static func _turtle_top() -> Array:
	return [
		_part("body", oval(256, 258, 70, 86)),
		_part("detail", oval(256, 258, 34, 44)),
		_part("head", oval(256, 150, 22, 26)),
		_part("leg", line([Vector2(198, 204), Vector2(150, 168), Vector2(138, 196), Vector2(192, 222)])),
		_part("leg", line([Vector2(314, 204), Vector2(362, 168), Vector2(374, 196), Vector2(320, 222)])),
		_part("leg", line([Vector2(202, 318), Vector2(160, 350), Vector2(178, 368), Vector2(214, 334)])),
		_part("leg", line([Vector2(310, 318), Vector2(352, 350), Vector2(334, 368), Vector2(298, 334)])),
		_part("tail", line([Vector2(256, 344), Vector2(256, 372)])),
	]


static func _frog() -> Array:
	return [
		_part("body", oval(256, 282, 92, 58)),
		_part("free", oval(214, 216, 20, 20)),
		_part("free", oval(298, 216, 20, 20)),
		_part("detail", line([Vector2(222, 290), Vector2(256, 304), Vector2(290, 290)])),
		_part("leg", line([Vector2(222, 334), Vector2(214, 376), Vector2(192, 382)])),
		_part("leg", line([Vector2(290, 334), Vector2(298, 376), Vector2(320, 382)])),
		_part("leg", line([Vector2(172, 300), Vector2(128, 330), Vector2(146, 372), Vector2(188, 372)])),
		_part("leg", line([Vector2(340, 300), Vector2(384, 330), Vector2(366, 372), Vector2(324, 372)])),
	]


static func _elephant_left() -> Array:
	return [
		_part("body", oval(284, 250, 96, 60)),
		_part("head", oval(184, 226, 46, 46)),
		_part("detail", oval(204, 226, 22, 30)),
		_part("detail", oval(170, 214, 4, 4)),
		_part("free", line([Vector2(146, 246), Vector2(138, 300), Vector2(150, 342), Vector2(166, 336)])),
		_part("leg", line([Vector2(222, 300), Vector2(222, 372)])),
		_part("leg", line([Vector2(250, 306), Vector2(250, 372)])),
		_part("leg", line([Vector2(318, 306), Vector2(318, 372)])),
		_part("leg", line([Vector2(346, 300), Vector2(346, 372)])),
		_part("tail", line([Vector2(378, 238), Vector2(398, 280)])),
	]


static func _crab() -> Array:
	var strokes: Array = [
		_part("body", oval(256, 270, 70, 44)),
		_part("detail", line([Vector2(238, 228), Vector2(234, 200)])),
		_part("detail", line([Vector2(274, 228), Vector2(278, 200)])),
		_part("free", line([Vector2(196, 248), Vector2(160, 200), Vector2(140, 168), Vector2(172, 162), Vector2(162, 198)])),
		_part("free", line([Vector2(316, 248), Vector2(352, 200), Vector2(372, 168), Vector2(340, 162), Vector2(350, 198)])),
	]
	for row in range(3):
		var y := 280.0 + row * 14.0
		var reach := 52.0 + row * 6.0
		strokes.append(_part("leg", line([Vector2(200, y), Vector2(200 - reach * 0.7, y + 16), Vector2(200 - reach, y + 48)])))
		strokes.append(_part("leg", line([Vector2(312, y), Vector2(312 + reach * 0.7, y + 16), Vector2(312 + reach, y + 48)])))
	return strokes


static func _ant() -> Array:
	var strokes: Array = [
		_part("head", oval(352, 250, 24, 22)),
		_part("body", oval(296, 258, 28, 20)),
		_part("body", oval(214, 264, 50, 32)),
		_part("detail", line([Vector2(364, 230), Vector2(384, 198)])),
		_part("detail", line([Vector2(352, 230), Vector2(356, 196)])),
	]
	for x in [272.0, 296.0, 320.0]:
		strokes.append(_part("leg", line([Vector2(x, 276), Vector2(x - 12.0, 304), Vector2(x - 20.0, 336)])))
	return strokes


static func _penguin() -> Array:
	return [
		_part("body", oval(256, 260, 56, 96)),
		_part("detail", oval(256, 284, 34, 64)),
		_part("detail", oval(240, 206, 5, 5)),
		_part("detail", oval(272, 206, 5, 5)),
		_part("detail", line([Vector2(248, 222), Vector2(256, 236), Vector2(264, 222)])),
		_part("arm", line([Vector2(204, 226), Vector2(170, 300), Vector2(198, 296)])),
		_part("arm", line([Vector2(308, 226), Vector2(342, 300), Vector2(314, 296)])),
		_part("leg", line([Vector2(232, 352), Vector2(212, 368), Vector2(246, 366)])),
		_part("leg", line([Vector2(280, 352), Vector2(300, 368), Vector2(266, 366)])),
	]


static func oval(cx: float, cy: float, rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := TAU * float(index) / 24.0
		points.append(Vector2(cx + cos(angle) * rx, cy + sin(angle) * ry))
	return points


static func line(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in points:
		out.append(point)
	return out


## Resampled to a point every few pixels, the way the drawing canvas records a stroke -- so a
## two-point tail is measured along its length, not as its two ends.
static func _part(part: String, points: PackedVector2Array) -> Dictionary:
	return {"points": dense(points), "width": 8.0, "color": Color.BLACK, "part": part}


static func dense(points: PackedVector2Array, spacing: float = 6.0) -> PackedVector2Array:
	if points.size() < 2:
		return points
	var out := PackedVector2Array([points[0]])
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var steps := maxi(1, int(ceil(a.distance_to(b) / spacing)))
		for k in range(1, steps + 1):
			out.append(a.lerp(b, float(k) / float(steps)))
	return out


static func _named(label: String, entity_id: String, strokes: Array) -> Dictionary:
	return {"label": label, "entity_id": entity_id, "strokes": strokes}
