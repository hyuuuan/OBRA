class_name FoeHealthBars
extends CanvasLayer
## A bar of pips over each creature in a fight, so a blow that lands can be seen to have landed.
##
## Kent, 2026-11-13: "show the like hp/life of the creatures in Dilim level". A creature only flashed
## when struck: a cannon shot that took three of a sigbin's four looked like one that missed, and in
## his playtest the cannon "seems to not work". One pip a blow, red while it is still in it, and the
## pips just lost light up for a moment so the blow that took them is the one you saw.
##
## WHEN IT SHOWS is Enemy2D.shows_health: once it is after her or has been hurt, never while it sleeps,
## never once it is dead, never while the tiyanak is still a crying child -- a bar over the bundle
## would give its ambush away.
##
## ⚠ OVER THE DARK, NOT IN THE WORLD. Drawn in the world, a bar sat under DarknessLayer (3) with its
## creature and was as hard to read as the creature. Layer 4 is over the dark and under the HUD (5),
## and the bar is placed through the camera every frame. Built only where a level asks
## (LevelBase._shows_foe_health).

const LAYER := 4
## Pips: wide where there are few, narrower for the bungisngis' fourteen, so no bar runs long.
const PIP_WIDE := 10.0
const PIP_NARROW := 6.0
const NARROW_ABOVE := 6
const PIP_GAP := 2.0
const PIP_TALL := 8.0
const PAD := 3.0
## How long a pip just lost stays lit.
const LOST_SECONDS := 0.3

var _bars: Node2D
## Foe instance id -> {"hp": last seen, "lost_at": msec, "lost": how many went then}.
var _seen: Dictionary = {}


func _ready() -> void:
	layer = LAYER
	# Drawn while a line of dialogue has the tree stopped: the camera can still move then.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bars = Node2D.new()
	_bars.name = "Bars"
	add_child(_bars)
	_bars.draw.connect(_draw_bars)


func _process(_delta: float) -> void:
	_bars.queue_redraw()


## The foes whose bars are up this frame -- for a probe.
func shown() -> Array[Enemy2D]:
	var out: Array[Enemy2D] = []
	for node in get_tree().get_nodes_in_group(Enemy2D.FOES):
		var foe := node as Enemy2D
		if foe != null and foe.shows_health():
			out.append(foe)
	return out


## The bar's rect for one foe, in screen px, whole pixels: centred over its head.
func bar_rect(foe: Enemy2D) -> Rect2:
	var pip := PIP_WIDE if foe.max_hp <= NARROW_ABOVE else PIP_NARROW
	var count := maxi(1, foe.max_hp)
	var size := Vector2(count * pip + (count - 1) * PIP_GAP + PAD * 2.0, PIP_TALL + PAD * 2.0)
	var at := get_viewport().get_canvas_transform() * foe.health_bar_anchor()
	return Rect2((at - Vector2(size.x * 0.5, size.y)).round(), size)


func _draw_bars() -> void:
	var now := Time.get_ticks_msec()
	var well := UISkin.well()
	for foe in shown():
		var id := foe.get_instance_id()
		var seen: Dictionary = _seen.get(id, {"hp": foe.hp, "lost_at": -100000, "lost": 0})
		if foe.hp < int(seen["hp"]):
			seen["lost"] = int(seen["hp"]) - foe.hp
			seen["lost_at"] = now
		seen["hp"] = foe.hp
		_seen[id] = seen
		var rect := bar_rect(foe)
		_bars.draw_style_box(well, rect)
		var pip := PIP_WIDE if foe.max_hp <= NARROW_ABOVE else PIP_NARROW
		var lit := now - int(seen["lost_at"]) < int(LOST_SECONDS * 1000.0)
		for i in range(maxi(1, foe.max_hp)):
			var cell := Rect2(rect.position + Vector2(PAD + i * (pip + PIP_GAP), PAD), Vector2(pip, PIP_TALL))
			if i < foe.hp:
				_bars.draw_rect(cell, UISkin.RED_FILL)
				_bars.draw_rect(Rect2(cell.position, Vector2(pip, 2.0)), UISkin.RED_LIT)
			elif lit and i < foe.hp + int(seen["lost"]):
				_bars.draw_rect(cell, UISkin.CREAM_TEXT)
			else:
				_bars.draw_rect(cell, Color(UISkin.RED_EDGE, 0.5))
