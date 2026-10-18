class_name DilimFinale2D
extends Node2D
## Dilim's last clearing: last until morning (Kent: the finale ends at DAWN, a survival clock, not
## a kill count).
##
## THREE WAVES ON THE NIGHT'S CLOCK (Kent's design: "W1 two aswang (dog / pig) · W2 + manananggal
## and wakwak (fliers) · W3 the TIK-TIK"). Each opens at its time in WAVES: its aswang on the ground
## -- never more of them alive than the wave says, one back REPLACE_SECONDS after one falls -- and
## its fliers, once each, from the clearing's edges. The manananggal comes back for the night the
## segment drove her off, and is driven off sooner (MANANANGGAL_DRIVE_OFF). Morning at DAWN_SECONDS.
##
## It starts itself once she is in the clearing (her hurtbox past `arena_west`), so a knockout
## that puts her back at the clearing's edge starts it again from nothing. At dawn whatever is
## still after her fades and `dawned` is said: the level takes the dark away and ends.

signal began
## A wave opening, 0 to 2: the level's cue to say what has come.
signal wave_opened(index: int)
signal dawned

const GROUP := &"dilim_encounters"
const DAWN_SECONDS := 150.0
## When each wave opens, how many aswang it keeps on her, and what flies in with it.
const WAVES := [
	{"at": 0.0, "aswang": 2, "fliers": []},
	{"at": 45.0, "aswang": 1, "fliers": ["manananggal_upper", "wakwak"]},
	{"at": 100.0, "aswang": 1, "fliers": ["tiktik"]},
]
## The first wave's aswang, in the forms they take in turn.
const WAVE_KIND := "aswang_dog"
const ASWANG_FORMS := ["aswang_dog", "aswang_pig"]
const WAVE_SIZE := 2
const REPLACE_SECONDS := 6.0
const MANANANGGAL_DRIVE_OFF := 8
## A sun she draws brings the morning this much closer -- once a wave (Kent's design).
const SUN_HURRIES := 15.0
## THE DEAD TREE (Kent's design: "felling it crushes ground enemies (8 dmg), and the log wall blocks
## one side"). A DeadTree2D child of the finale, felled by anything that cuts. It falls east, across
## the clearing's east side: every walker under the trunk takes TREE_CRUSH, the trunk lying there is
## a wall no walker crosses, and from then on the night's aswang come only from the west. A felled
## tree stays down through a restore -- it cannot stand back up -- so the side stays shut.
const TREE_CRUSH := 8
## How far above the trunk's foot a walker still counts as under it.
const TREE_REACH_UP := 120.0
## How high over the ground the fliers come in.
const FLIER_HEIGHT := 260.0
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
var _wave := -1
var _forms := 0
## The wave a sun last hurried, so each wave takes only one.
var _hurried := -1
var tree: DeadTree2D


func _ready() -> void:
	add_to_group(GROUP)
	for child in get_children():
		if child is DeadTree2D:
			tree = child
			tree.felled.connect(_on_tree_felled)


## Whether the felled trunk lies across the east side.
func east_closed() -> bool:
	return tree != null and tree.is_open()


func _on_tree_felled() -> void:
	var foot := tree.global_position
	for foe in alive():
		if not (foe is GroundEnemy2D):
			continue
		var half := foe.body_size.x * 0.5
		if foe.global_position.x >= foot.x - half and foe.global_position.x <= foot.x + tree.span_length + half \
				and foot.y - foe.global_position.y <= TREE_REACH_UP:
			foe.crush(TREE_CRUSH)


func _physics_process(delta: float) -> void:
	if _done:
		return
	if not _running:
		var hurtbox := _her_hurtbox()
		if hurtbox != null and hurtbox.middle().x >= arena_west:
			_begin()
		return
	elapsed += delta
	_open_waves()
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


## A sun drawn in the night: the clock jumps SUN_HURRIES on, if this wave has not had one. Whether
## it did is the answer.
func hurry_dawn() -> bool:
	if not _running or _hurried == _wave:
		return false
	_hurried = _wave
	elapsed += SUN_HURRIES
	return true


## The third wave's tik-tik while it is about, for the level to listen to; null otherwise.
func tiktik() -> Tiktik2D:
	for foe in alive():
		if foe is Tiktik2D:
			return foe
	return null


## Which wave the night is in, 0 to 2, or -1 before it begins.
func current_wave() -> int:
	return _wave


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
	_wave = -1
	_forms = 0
	_hurried = -1


func _begin() -> void:
	_running = true
	elapsed = 0.0
	_wave = -1
	_open_waves()
	began.emit()


## Every wave whose time has come opens: its aswang up to its number, and its fliers.
func _open_waves() -> void:
	while _wave + 1 < WAVES.size() and elapsed >= float((WAVES[_wave + 1] as Dictionary)["at"]):
		_wave += 1
		var wave: Dictionary = WAVES[_wave]
		for _i in range(int(wave["aswang"])):
			_send_one()
		for kind: String in wave["fliers"]:
			_send_flier(kind)
		wave_opened.emit(_wave)


## How many aswang the night keeps on her now.
func _aswang_wanted() -> int:
	return int((WAVES[maxi(_wave, 0)] as Dictionary)["aswang"])


func _aswang_alive() -> int:
	var count := 0
	for foe in alive():
		if foe is GroundEnemy2D:
			count += 1
	return count


func _send_one() -> void:
	if not _running or _aswang_alive() >= _aswang_wanted():
		return
	var foe := GroundEnemy2D.new()
	foe.kind = String(ASWANG_FORMS[_forms % ASWANG_FORMS.size()])
	_forms += 1
	var side := -1.0 if east_closed() else _next_side
	_enter(foe, Vector2(ENTRY_OFFSET * side, -40.0))


func _send_flier(kind: String) -> void:
	var foe: Enemy2D
	match kind:
		"manananggal_upper":
			foe = ManananggalUpper2D.new()
		"tiktik":
			foe = Tiktik2D.new()
		_:
			foe = FlyingEnemy2D.new()
	foe.kind = kind
	_enter(foe, Vector2(ENTRY_OFFSET * _next_side, -FLIER_HEIGHT))
	if foe is ManananggalUpper2D:
		foe.max_hp = MANANANGGAL_DRIVE_OFF
		foe.hp = MANANANGGAL_DRIVE_OFF


func _enter(foe: Enemy2D, at: Vector2) -> void:
	foe.position = at
	_next_side = -_next_side
	add_child(foe)
	foe.reset_home()
	# The finale keeps its own: not reset with the encounters, it is reset with the finale.
	foe.remove_from_group(Enemy2D.GROUP)
	foe.died.connect(_on_foe_died)
	_foes.append(foe)


## An aswang that falls is replaced; a flier is not -- each wave's fliers come once.
func _on_foe_died(foe: Enemy2D) -> void:
	if foe is GroundEnemy2D:
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
