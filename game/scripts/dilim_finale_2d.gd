class_name DilimFinale2D
extends Node2D
## Dilim's last clearing: last until morning (Kent: the finale ends at DAWN, a survival clock, not
## a kill count).
##
## ⚠ THE SLICE'S FINALE, not the whole one. One wave on a short clock: two aswang in dog form on
## her, never more than two alive, one back REPLACE_SECONDS after one falls, until DAWN_SECONDS
## have passed. The full finale -- three waves on a longer clock, the wakwak and the manananggal,
## the tik-tik, the tree to fell -- builds on this.
##
## It starts itself once she is in the clearing (her hurtbox past `arena_west`), so a knockout
## that puts her back at the clearing's edge starts it again from nothing. At dawn whatever is
## still after her fades and `dawned` is said: the level takes the dark away and ends.

signal began
signal dawned

const GROUP := &"dilim_encounters"
const DAWN_SECONDS := 60.0
const WAVE_KIND := "aswang_dog"
const WAVE_SIZE := 2
const REPLACE_SECONDS := 6.0
## Where they come from: the clearing's edges, this far either side of its middle, on the ground.
const ENTRY_OFFSET := 460.0
const FLEE_FADE := 0.8

## The clearing's west edge in world x: past it, she is in the finale.
@export var arena_west := 21400.0

## Seconds of the night that have passed since it began.
var elapsed := 0.0
var _running := false
var _done := false
var _foes: Array[Enemy2D] = []
var _waiting: Array[float] = []
var _next_side := 1.0


func _ready() -> void:
	add_to_group(GROUP)


func _physics_process(delta: float) -> void:
	if _done:
		return
	if not _running:
		var hurtbox := _her_hurtbox()
		if hurtbox != null and hurtbox.middle().x >= arena_west:
			_begin()
		return
	elapsed += delta
	for index in range(_waiting.size() - 1, -1, -1):
		_waiting[index] -= delta
		if _waiting[index] <= 0.0:
			_waiting.remove_at(index)
			_send_one()
	if elapsed >= DAWN_SECONDS:
		_dawn()


func is_running() -> bool:
	return _running


func has_dawned() -> bool:
	return _done


## How far through the night, 0 to 1, for the clock on screen.
func progress() -> float:
	return clampf(elapsed / DAWN_SECONDS, 0.0, 1.0)


## The ones still after her.
func alive() -> Array[Enemy2D]:
	var out: Array[Enemy2D] = []
	for foe in _foes:
		if is_instance_valid(foe) and not foe.is_dead():
			out.append(foe)
	return out


## Back to before the night began: nothing after her, no clock -- the checkpoint is from then.
func reset_for_restore() -> void:
	for foe in _foes:
		if is_instance_valid(foe):
			foe.queue_free()
	_foes.clear()
	_waiting.clear()
	elapsed = 0.0
	_running = false
	_next_side = 1.0


func _begin() -> void:
	_running = true
	elapsed = 0.0
	for _i in range(WAVE_SIZE):
		_send_one()
	began.emit()


func _send_one() -> void:
	if not _running or alive().size() >= WAVE_SIZE:
		return
	var foe := GroundEnemy2D.new()
	foe.kind = WAVE_KIND
	foe.position = Vector2(ENTRY_OFFSET * _next_side, -40.0)
	_next_side = -_next_side
	add_child(foe)
	foe.reset_home()
	# The finale keeps its own: not reset with the encounters, it is reset with the finale.
	foe.remove_from_group(Enemy2D.GROUP)
	foe.died.connect(_on_foe_died)
	_foes.append(foe)


func _on_foe_died(foe: Enemy2D) -> void:
	_waiting.append(REPLACE_SECONDS)
	get_tree().create_timer(Enemy2D.DEATH_FADE + 0.1, false).timeout.connect(func() -> void:
		_foes.erase(foe)
		if is_instance_valid(foe):
			foe.queue_free())


## Morning. Whatever is still after her goes, and the night is over.
func _dawn() -> void:
	_done = true
	_running = false
	_waiting.clear()
	for foe in alive():
		foe.process_mode = Node.PROCESS_MODE_DISABLED
		# The finale's own tween: one bound to a stopped foe would never run.
		var fade := create_tween()
		fade.tween_property(foe, "modulate:a", 0.0, FLEE_FADE)
		fade.tween_callback(foe.queue_free)
	_foes.clear()
	dawned.emit()


func _her_hurtbox() -> PlayerHurtbox2D:
	for node in get_tree().get_nodes_in_group(PlayerHurtbox2D.GROUP):
		var hurtbox := node as PlayerHurtbox2D
		if hurtbox != null and hurtbox.is_inside_tree():
			return hurtbox
	return null
