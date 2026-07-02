extends "res://scripts/playable_entity.gd"
## Frog movement: hold jump to charge, release to hop. Clone this pattern for the
## other classes (fish = swim/float with no gravity, spider = stick to walls).
##
## Expects an input action named "jump" (Project Settings -> Input Map, e.g. Space)
## and "move_left" / "move_right" (e.g. A / D or the arrow keys).

@export var min_hop_velocity: float = 250.0
@export var max_hop_velocity: float = 650.0
@export var charge_time: float = 0.8       # seconds of holding for a full-power hop
@export var horizontal_speed: float = 180.0
@export var gravity: float = 1200.0

var _charge: float = 0.0


func _physics_process(delta: float) -> void:
	var was_on_floor := is_on_floor()
	var horizontal := Input.get_axis("move_left", "move_right")

	if not was_on_floor:
		velocity.y += gravity * delta
	else:
		velocity.x = 0.0  # frogs land and stop; they don't glide around

		if Input.is_action_pressed("jump"):
			_charge = minf(_charge + delta, charge_time)
		elif Input.is_action_just_released("jump"):
			_hop()

	move_and_slide()
	_update_rig_state(was_on_floor, horizontal)


func _hop() -> void:
	var power := _charge / charge_time
	_charge = 0.0
	velocity.y = -lerpf(min_hop_velocity, max_hop_velocity, power)
	velocity.x = Input.get_axis("move_left", "move_right") * horizontal_speed


func _update_rig_state(was_on_floor: bool, horizontal: float) -> void:
	var grounded := is_on_floor()
	var params := {
		"direction": horizontal,
		"charge_ratio": _charge / charge_time
	}

	if grounded and not was_on_floor:
		set_rig_state("landed", params)
	elif grounded and Input.is_action_pressed("jump"):
		set_rig_state("charge", params)
	elif grounded:
		set_rig_state("idle", params)
	elif velocity.y < 0.0:
		set_rig_state("jump", params)
	else:
		set_rig_state("fall", params)
