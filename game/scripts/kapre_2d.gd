class_name Kapre2D
extends Node2D
## The kapre: up its tree, smoking, keeping to itself -- and its smoke turns travellers round
## (Kent's design: "ground the loop in the smoke ... a visible cause the player can act on").
##
## What it is, the level asks about: the smoke bank west of its tree (SMOKE_WIDTH px, ending at the
## trunk) until it is cleared; its cigar, up the tree at CIGAR_TIP, which is a small light and a target --
## anything thrown that reaches it knocks it out of its hand (cigar_knocked); and its tree, which
## falls after CHOPS_TO_FELL chops. Which of those answers the encounter is the level's to judge.
## Answered any way, the smoke is gone; felled or knocked, the kapre leaves.

signal cigar_knocked

const SMOKE_WIDTH := 600.0
## Where its cigar's tip is drawn (tools/dilim_kapre.py CIGAR_TIP), in its teeth up the tree: the
## cigar's hit area and its light are there, so a click on the cigar is a click on the cigar.
const CIGAR_TIP := Vector2(-122.0, -280.0)
const CHOPS_TO_FELL := 3
const TRUNK := Vector2(70.0, 340.0)
const CIGAR_GLOW := 40.0
## Where its drawn strip stands in the tree (tools/dilim_kapre.py ART_AT): the bottom-centre of the
## frame, which is its hanging foot, sat on the balete's branch.
const ART_AT := Vector2(-68.0, -110.0)
const FADE_SECONDS := 1.0
const BARK := Color(0.16, 0.11, 0.08)
const HIDE := Color(0.08, 0.07, 0.06)
const SMOKE := Color(0.72, 0.72, 0.74)
const EMBER := Color(1.0, 0.55, 0.18)

var _smoke := 1.0
var _chops := 0
var _felled := false
var _cigar_lit := true
var _gone := false
var _clock := 0.0
var cigar: Area2D


## The balete it sits in, drawn (kapre_tree_idle / kapre_tree_felled); the code's tree below stands
## in only while there is none.
var tree_art: PixelStripAnimator

## Its strips (tools/build_dilim_creatures.py, or drawn art under the same names); the code-drawn
## body below stands in only while there are none.
var art: PixelStripAnimator


func _make_art(kind: String, anims: Array, centre: bool, at: Vector2) -> void:
	art = PixelStripAnimator.new()
	art.name = "Art"
	art.centre = centre
	art.position = at
	add_child(art)
	art.load_kind(Enemy2D.ART, kind, anims)
	art.play("idle")


func _ready() -> void:
	# Its balete first, behind the kapre and the smoke: standing, or felled once it is down.
	tree_art = PixelStripAnimator.new()
	tree_art.name = "TreeArt"
	tree_art.z_index = -1
	add_child(tree_art)
	tree_art.load_kind(Enemy2D.ART, "kapre_tree", ["idle", "felled"])
	tree_art.play("idle")
	_make_art("kapre", ["idle"], false, ART_AT)
	add_to_group(Enemy2D.GROUP)
	add_to_group(LightField.GROUP)
	z_index = 3
	cigar = Area2D.new()
	cigar.name = "Cigar"
	cigar.collision_layer = PhysicsLayers.WORLD | PhysicsLayers.ENEMY_HURTBOX
	cigar.collision_mask = 0
	cigar.monitoring = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	shape.shape = circle
	cigar.add_child(shape)
	cigar.position = CIGAR_TIP
	add_child(cigar)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


## A weapon's blow, as every weapon delivers it (the walk up from its shape to here). Only one that
## reaches the cigar counts -- a blade cannot, from the ground.
func apply_tool_hit(_tool: String, _impulse: float, _actor: Node2D) -> bool:
	if not _cigar_lit:
		return false
	_cigar_lit = false
	cigar.set_deferred(&"collision_layer", 0)
	cigar_knocked.emit()
	return true


## Whether the smoke still stands, and where it is in world x.
func smoke_stands() -> bool:
	return _smoke > 0.0


func smoke_span() -> Vector2:
	return Vector2(global_position.x - SMOKE_WIDTH, global_position.x)


func clear_smoke() -> void:
	if _smoke <= 0.0:
		return
	var thin := create_tween()
	thin.tween_property(self, "_smoke", 0.0, FADE_SECONDS)


## One chop at its tree. Returns whether that one felled it.
func chop() -> bool:
	if _felled:
		return false
	_chops += 1
	if _chops >= CHOPS_TO_FELL:
		_felled = true
		tree_art.play("felled")
		clear_smoke()
		leave()
		return true
	return false


func chops() -> int:
	return _chops


func is_felled() -> bool:
	return _felled


func cigar_is_lit() -> bool:
	return _cigar_lit


## Down from its tree and away into the dark.
func leave() -> void:
	if _gone:
		return
	_gone = true
	clear_smoke()


func is_gone() -> bool:
	return _gone


func light_hole() -> Dictionary:
	if not _cigar_lit or _gone:
		return {}
	return {"position": global_position + cigar.position, "radius": CIGAR_GLOW, "strength": 0.7}


## Back to before she came -- unless it was answered; a restore does not grow a tree back.
func reset_for_restore() -> void:
	if _gone or _felled or not _cigar_lit:
		return
	_chops = 0


## PLACEHOLDER until it has art: its tree, the kapre up it, the cigar's ember, and the smoke.
func _draw() -> void:
	if not tree_art.has_art() and not _felled:
		draw_rect(Rect2(-TRUNK.x * 0.5, -TRUNK.y, TRUNK.x, TRUNK.y), BARK)
		draw_circle(Vector2(0.0, -TRUNK.y - 40.0), 110.0, Color(0.07, 0.12, 0.07))
	elif not tree_art.has_art():
		draw_rect(Rect2(-TRUNK.y * 0.5, -TRUNK.x, TRUNK.y, TRUNK.x), BARK)
	var drawn := art != null and art.has_art()
	if drawn:
		art.visible = not _gone
		art.advance(get_process_delta_time())
	if not _gone and not drawn:
		draw_rect(Rect2(CIGAR_TIP + Vector2(40.0, -20.0), Vector2(50.0, 90.0)), HIDE)
		draw_circle(CIGAR_TIP + Vector2(56.0, -10.0), 18.0, HIDE)
	if _cigar_lit and not _gone and not drawn:
		draw_circle(cigar.position, 4.0, EMBER)
	if _smoke > 0.0:
		for index in range(18):
			var x := -SMOKE_WIDTH + fmod(index * 37.0 + _clock * 14.0, SMOKE_WIDTH)
			var y := -40.0 - fmod(index * 53.0, 240.0)
			draw_circle(Vector2(x, y), 46.0, Color(SMOKE, 0.16 * _smoke))
