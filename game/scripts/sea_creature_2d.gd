extends Node2D
## ONE OF DAGAT'S SEA CREATURES: a bangus, a pawikan, a dikya or a pugita (Kent, 2026-10-05).
##
## They swim the open water between the first beach and the bakunawa's stretch, and three things
## can happen to one:
##   * it is CAUGHT -- it swims into the hook's reach, is held by the line while the player reels,
##     and is landed or gets away (see level_3.gd, the fishing);
##   * it is FOUGHT -- a strike drawing hits it (`apply_tool_hit`, the same contract Bakunawa2D and
##     Destructible2D publish, so every drawn weapon works without this file knowing what a sword
##     is), and five blows kill it;
##   * it FIGHTS BACK -- once the player has struck any of them, every one but the bangus turns on
##     them (`set_hostile`), chases them through the water and bites.
##
## ⚠ NOT A DRAWABLE CLASS, AND NAMED IN FILIPINO. The roster has a fish, an octopus and a sea turtle
## the player can draw; these are the sea's own creatures, and naming them pawikan, pugita, dikya
## and bangus keeps Lolo's lines about them clear of the rule that no line names a class.
##
## ⚠ PRELOADED BY PATH, NOT BY class_name: a `--script` run does not register class names, and the
## probes are exactly that.

signal struck(creature: Node2D)
signal died(creature: Node2D)
signal bit_player(creature: Node2D)

const FOLDER := "res://assets/Level3/creatures/"
const FRAME := 48
## Everything about a kind: how big it is drawn, how fast it swims, whether it turns on a player
## who fights, and how it fights a line (FishingLine2D): `pull` is how hard it runs, `run` and `rest`
## how long it runs and tires for, `strength` how fast winding against a run strains the line. The
## bangus darts, often and briefly; the pawikan is heavy and slow and long; the dikya barely fights;
## the pugita pulls hardest of all.
const KINDS := {
	"bangus": {"name": "Bangus", "scale": 0.55, "speed": 95.0, "hostile": false,
		"pull": 150.0, "run": 0.9, "rest": 1.0, "strength": 0.9, "radius": 26.0},
	"pawikan": {"name": "Pawikan", "scale": 2.4, "speed": 45.0, "hostile": true,
		"pull": 120.0, "run": 2.2, "rest": 1.4, "strength": 1.1, "radius": 40.0},
	"dikya": {"name": "Dikya", "scale": 2.0, "speed": 32.0, "hostile": true,
		"pull": 70.0, "run": 1.0, "rest": 1.8, "strength": 0.6, "radius": 30.0},
	"pugita": {"name": "Pugita", "scale": 2.2, "speed": 65.0, "hostile": true,
		"pull": 210.0, "run": 1.1, "rest": 1.2, "strength": 1.4, "radius": 38.0},
}
## Kent: "5 hits for the sea creatures to die".
const HIT_POINTS := 5
## What hurts it: the Strike drawings.
const WEAPONS := ["cannon", "anvil", "axe", "sword", "boomerang", "scissors"]
const ANIM_FPS := {"idle": 5.0, "swim": 8.0, "attack": 12.0, "death": 9.0}
const BITE_COOLDOWN := 1.3

enum State { SWIM, HOOKED, DEAD, LANDED }

var kind := "bangus"
## Where it wanders, and the water it may never leave.
var wander := Rect2()
var bounds := Rect2()
## Who it chases once it is angry, and whether they can be reached (in the water, not aboard).
var target: Callable
var target_reachable: Callable

var _state := State.SWIM
var _hp := HIT_POINTS
var _hostile := false
var _skin: Sprite2D
var _anims: Dictionary = {}
var _anim := "idle"
var _frame := 0
var _clock := 0.0
var _goal := Vector2.ZERO
var _rest := 0.0
var _facing := 1.0
var _hurt := 0.0
var _bite_cooldown := 0.0
var _attacking := 0.0
var _hook: Node2D
var _hurtbox: Area2D
var _wobble := 0.0
var _thrashing := false


func _ready() -> void:
	add_to_group(&"sea_creatures")
	z_index = 3
	_load_anims()
	_skin = Sprite2D.new()
	_skin.name = "Skin"
	_skin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_skin.scale = Vector2.ONE * float(spec()["scale"])
	add_child(_skin)
	# ⚠ collision_layer 1, AND AN AREA -- UtilityObject._reachable_targets queries areas on layer 1
	# and walks up to whatever has apply_tool_hit. On any other layer a sword swings through it.
	_hurtbox = Area2D.new()
	_hurtbox.name = "Hurtbox"
	_hurtbox.collision_layer = 1
	_hurtbox.collision_mask = 0
	_hurtbox.monitoring = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius()
	shape.shape = circle
	_hurtbox.add_child(shape)
	add_child(_hurtbox)
	_wobble = randf() * TAU
	_choose_a_goal()
	_play("idle")


func spec() -> Dictionary:
	return KINDS.get(kind, KINDS["bangus"])


func display_name() -> String:
	return String(spec()["name"])


func radius() -> float:
	return float(spec()["radius"])


## How it fights a line. See KINDS.
func fight() -> Dictionary:
	return {"pull": spec()["pull"], "run": spec()["run"], "rest": spec()["rest"],
		"strength": spec()["strength"]}


## Told every frame of a fight by the line: whether it is making a run, and which way.
func pulled(running: bool, direction_x: float) -> void:
	_thrashing = running
	if absf(direction_x) > 0.05:
		_facing = signf(direction_x)


## A picture of it, for the reel and the cards.
func portrait() -> Texture2D:
	var frames: Array = _anims.get("idle", _anims.get("swim", []))
	return frames[0] if not frames.is_empty() else null


func is_alive() -> bool:
	return _state != State.DEAD and _state != State.LANDED


func is_hooked() -> bool:
	return _state == State.HOOKED


func is_hostile() -> bool:
	return _hostile


func hit_points() -> int:
	return _hp


# --- What the level tells it -------------------------------------------------------------------

## Angry or calm. The bangus never is (Kent: "everything except bangus attacks them").
func set_hostile(on: bool) -> void:
	_hostile = on and bool(spec()["hostile"]) and is_alive()


func hook_onto(hook: Node2D) -> void:
	if not is_alive():
		return
	_state = State.HOOKED
	_hook = hook


## Off the hook and away, fast.
func release_from_hook() -> void:
	if _state != State.HOOKED:
		return
	_state = State.SWIM
	_hook = null
	_goal = global_position + Vector2(randf_range(-1.0, 1.0) * 400.0, randf_range(-60.0, 60.0))
	_goal = _clamp(_goal)
	_rest = 0.0


## Landed: lifted out of the water to `to`, and gone.
func land(to: Vector2) -> void:
	_state = State.LANDED
	_hook = null
	_hurtbox.collision_layer = 0
	var lift := create_tween()
	lift.tween_property(self, "global_position", to, 0.7).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	lift.parallel().tween_property(self, "rotation", -0.6 * _facing, 0.7)
	lift.tween_interval(0.5)
	lift.tween_property(self, "modulate:a", 0.0, 0.4)
	lift.tween_callback(queue_free)


# --- The fight ---------------------------------------------------------------------------------

func accepts_tool(tool: String) -> bool:
	return is_alive() and WEAPONS.has(tool)


func apply_tool_hit(tool: String, _impulse: float, actor: Node2D) -> bool:
	if not accepts_tool(tool):
		return false
	_hp -= 1
	_hurt = 0.3
	# Knocked back, away from whatever hit it.
	var away := Vector2(1.0, 0.0)
	if actor != null and is_instance_valid(actor):
		away = (global_position - actor.global_position).normalized()
		if away == Vector2.ZERO:
			away = Vector2(1.0, 0.0)
	var knock := create_tween()
	knock.tween_property(self, "global_position", _clamp(global_position + away * 45.0), 0.18) \
		.set_ease(Tween.EASE_OUT)
	if _state == State.HOOKED:
		release_from_hook()
	struck.emit(self)
	if _hp <= 0:
		_die()
	return true


func _die() -> void:
	_state = State.DEAD
	_hostile = false
	_hook = null
	_hurtbox.collision_layer = 0
	died.emit(self)
	if _anims.has("death"):
		_play("death")
		var hold := create_tween()
		hold.tween_interval(float((_anims["death"] as Array).size()) / float(ANIM_FPS["death"]) + 0.4)
		hold.tween_property(self, "modulate:a", 0.0, 0.6)
		hold.tween_callback(queue_free)
	else:
		# The bangus has one picture: it goes pale, turns over and sinks.
		var sink := create_tween()
		sink.tween_property(_skin, "modulate", Color(1.4, 0.5, 0.5, 1.0), 0.15)
		sink.tween_property(self, "rotation", PI * 0.9 * _facing, 0.8)
		sink.parallel().tween_property(self, "global_position:y", global_position.y + 90.0, 1.6)
		sink.parallel().tween_property(self, "modulate:a", 0.0, 1.6)
		sink.tween_callback(queue_free)


# --- Per frame ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_hurt = maxf(0.0, _hurt - delta)
	_bite_cooldown = maxf(0.0, _bite_cooldown - delta)
	_wobble += delta
	match _state:
		State.SWIM:
			if _hostile and _can_reach_target():
				_chase(delta)
			else:
				_wander(delta)
		State.HOOKED:
			if _hook != null and is_instance_valid(_hook):
				# On the line: thrashing on a run, sagging when it tires.
				var shake := 9.0 if _thrashing else 3.0
				var rate := 16.0 if _thrashing else 6.0
				global_position = _hook.global_position + Vector2(sin(_wobble * rate) * shake,
					radius() * 0.4)
				_play("swim" if _thrashing else "idle")
	_animate(delta)


func _wander(delta: float) -> void:
	if _rest > 0.0:
		_rest -= delta
		_play("idle")
		return
	var to := _goal - global_position
	if to.length() < 12.0:
		_rest = randf_range(0.4, 2.2) if kind != "bangus" else randf_range(0.0, 0.5)
		_choose_a_goal()
		return
	var step := minf(to.length(), float(spec()["speed"]) * delta)
	global_position += to.normalized() * step
	if absf(to.x) > 2.0:
		_facing = signf(to.x)
	_play("swim")


func _chase(delta: float) -> void:
	var at: Vector2 = target.call()
	var to := at - global_position
	var reach := radius() + 34.0
	if absf(to.x) > 2.0:
		_facing = signf(to.x)
	if _attacking > 0.0:
		_attacking -= delta
		if _attacking <= 0.0 and to.length() <= reach + 20.0:
			bit_player.emit(self)
		return
	if to.length() > reach:
		var speed := maxf(110.0, float(spec()["speed"]) * 2.2)
		global_position = _clamp(global_position + to.normalized() * minf(to.length(), speed * delta))
		_play("swim")
	elif _bite_cooldown <= 0.0:
		_bite_cooldown = BITE_COOLDOWN
		_attacking = 0.28
		_play("attack", true)


func _can_reach_target() -> bool:
	if not target.is_valid():
		return false
	return not target_reachable.is_valid() or bool(target_reachable.call())


func _choose_a_goal() -> void:
	var area := wander if wander.size != Vector2.ZERO else Rect2(global_position - Vector2(200, 80),
		Vector2(400, 160))
	_goal = _clamp(Vector2(randf_range(area.position.x, area.end.x),
		randf_range(area.position.y, area.end.y)))


func _clamp(at: Vector2) -> Vector2:
	if bounds.size == Vector2.ZERO:
		return at
	return Vector2(clampf(at.x, bounds.position.x, bounds.end.x),
		clampf(at.y, bounds.position.y, bounds.end.y))


# --- How it looks ------------------------------------------------------------------------------

func _load_anims() -> void:
	if kind == "bangus":
		var picture := load(FOLDER + ("bangus_big.png" if randf() < 0.35 else "bangus_small.png")) \
			as Texture2D
		if picture != null:
			_anims["idle"] = [picture]
			_anims["swim"] = [picture]
		return
	for anim in ["idle", "swim", "attack", "death", "hurt"]:
		var sheet := load("%s%s_%s.png" % [FOLDER, kind, anim]) as Texture2D
		if sheet == null:
			continue
		var frames: Array[Texture2D] = []
		for index in range(int(sheet.get_width() / FRAME)):
			var cut := AtlasTexture.new()
			cut.atlas = sheet
			cut.region = Rect2(index * FRAME, 0, FRAME, FRAME)
			frames.append(cut)
		_anims[anim] = frames


func _play(anim: String, restart: bool = false) -> void:
	if not _anims.has(anim):
		anim = "swim" if _anims.has("swim") else "idle"
	if anim == _anim and not restart:
		return
	_anim = anim
	_frame = 0
	_clock = 0.0


func _animate(delta: float) -> void:
	if _skin == null:
		return
	var frames: Array = _anims.get(_anim, [])
	if frames.is_empty():
		return
	_clock += delta
	var step := 1.0 / float(ANIM_FPS.get(_anim, 6.0))
	while _clock >= step:
		_clock -= step
		if _anim == "death" or _anim == "attack":
			_frame = mini(_frame + 1, frames.size() - 1)
		else:
			_frame = (_frame + 1) % frames.size()
	if _anim == "attack" and _frame >= frames.size() - 1 and _attacking <= 0.0 and _state == State.SWIM:
		_play("swim")
		frames = _anims.get(_anim, [])
	var texture: Texture2D = frames[mini(_frame, frames.size() - 1)]
	# A blow shows: the sheet's own red frame where it has one, a red flash where it does not.
	if _hurt > 0.0 and _anims.has("hurt") and (_anims["hurt"] as Array).size() > 1:
		texture = (_anims["hurt"] as Array)[1]
	_skin.texture = texture
	_skin.modulate = Color(2.0, 0.4, 0.4) if _hurt > 0.0 and not _anims.has("hurt") else Color.WHITE
	if kind == "bangus":
		# Drawn swimming up and to the right: turned level, and mirrored the other way.
		_skin.flip_h = _facing < 0.0
		_skin.rotation = (PI * 0.25 if _facing > 0.0 else -PI * 0.25) + sin(_wobble * 6.0) * 0.08
	else:
		# The pawikan and the pugita are drawn facing right; the dikya is the same either way.
		_skin.flip_h = _facing < 0.0
		if kind == "dikya":
			_skin.position.y = sin(_wobble * 2.2) * 4.0
