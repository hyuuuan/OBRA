class_name Tikbalang2D
extends Node2D
## The tikbalang: horse-headed, it leads travellers off the path (Kent's design -- "Appears at
## forks, and whichever path the player takes arrives back at the same place.").
##
## It stands by its landmark rock. The leading-back is the level's (it knows where the paths go);
## this is the creature: it races her when she asks -- from its own spot, RACE_LENGTH px east, it at
## RUN_SPEED and she at her own, so a player who runs the whole way wins by a hair and one who
## stops does not -- and it stands aside once she has answered it, any way.

signal race_finished(she_won: bool)

const RACE_LENGTH := 1100.0
const RUN_SPEED := 245.0
const COUNTDOWN := 1.0
const ASIDE_SECONDS := 0.8
const HIDE := Color(0.09, 0.07, 0.06)
const EYE := Color(1.0, 0.74, 0.24)

var _home := Vector2.ZERO
var _countdown := 0.0
var _racing := false
var _finish_x := 0.0
var _aside := false
var _clock := 0.0


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
	add_to_group(Enemy2D.GROUP)
	_home = global_position
	z_index = 4
	_make_art("tikbalang", ["idle", "run"], false, Vector2.ZERO)


func _physics_process(delta: float) -> void:
	_clock += delta
	if art != null and art.has_art():
		art.play("run" if _racing else "idle")
		art.advance(delta)
	if _countdown > 0.0:
		_countdown -= delta
		if _countdown <= 0.0:
			_racing = true
	elif _racing:
		global_position.x += RUN_SPEED * delta
		var hurtbox := _her_hurtbox()
		if hurtbox != null and hurtbox.middle().x >= _finish_x:
			_end_race(true)
		elif global_position.x >= _finish_x:
			_end_race(false)
	queue_redraw()


## From its own spot to RACE_LENGTH px east, after a beat to get ready. Returns the start line.
func start_race() -> float:
	if _racing or _countdown > 0.0 or _aside:
		return global_position.x
	global_position = _home
	_finish_x = _home.x + RACE_LENGTH
	_countdown = COUNTDOWN
	return _home.x


func is_racing() -> bool:
	return _racing or _countdown > 0.0


func finish_x() -> float:
	return _finish_x


func home() -> Vector2:
	return _home


## Answered: it steps off the path and is gone from it.
func stand_aside() -> void:
	if _aside:
		return
	_aside = true
	_racing = false
	_countdown = 0.0
	var away := create_tween()
	away.tween_property(self, "modulate:a", 0.0, ASIDE_SECONDS)
	away.tween_callback(func() -> void: visible = false)


func is_aside() -> bool:
	return _aside


func reset_for_restore() -> void:
	if _aside:
		return
	_racing = false
	_countdown = 0.0
	global_position = _home


func _end_race(she_won: bool) -> void:
	_racing = false
	if not she_won:
		global_position = _home
	race_finished.emit(she_won)


func _her_hurtbox() -> PlayerHurtbox2D:
	for node in get_tree().get_nodes_in_group(PlayerHurtbox2D.GROUP):
		var hurtbox := node as PlayerHurtbox2D
		if hurtbox != null and hurtbox.is_inside_tree():
			return hurtbox
	return null


## PLACEHOLDER until it has art: a tall dark figure, long-headed, its eyes catching the light.
func _draw() -> void:
	if art != null and art.has_art():
		return
	var stride := sin(_clock * TAU * 3.0) * 4.0 if _racing else 0.0
	draw_rect(Rect2(-14.0, -120.0, 28.0, 86.0), HIDE)
	draw_line(Vector2(-8.0, -34.0), Vector2(-8.0 + stride, 0.0), HIDE, 7.0)
	draw_line(Vector2(8.0, -34.0), Vector2(8.0 - stride, 0.0), HIDE, 7.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -120), Vector2(12, -124), Vector2(30, -150),
		Vector2(26, -162), Vector2(4, -158), Vector2(-12, -140)]), HIDE)
	draw_circle(Vector2(20.0, -150.0), 2.5, EYE)
