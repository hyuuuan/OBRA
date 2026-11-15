class_name CreatureAbility
extends RefCounted
## What a drawn body can do besides move: its ConceptNet abilities, made to work in play.
##
## Kent, 2026-11-16: the study takes its abilities from ConceptNet, and a body only ever moved --
## the bird flew, but the bee could not sting, the elephant could not ram, the crab's shell took
## nothing. config/abilities.json has had them all along (built offline from ConceptNet 5.7); this
## is where they act. config/ability_effects.json says what each ability label DOES, and a class
## gets an effect only if ConceptNet gives it that ability -- ConceptNet only, his decision, so the
## shark (Swim, Circle, Rough Hide) takes a blow for her and does not bite.
##
## - Its F ACTION is its first strike (Sting, Venom, Tusk Ram: a blow through apply_tool_hit, the
##   numbers in config/weapons.json), else its first grab (Squeeze, Grapple, Grip, Tongue Grab,
##   Trunk Grab: what it catches is held still a moment). A blow lands on anything a drawn weapon
##   could: Dilim's creatures, Dagat's sea creatures and its bakunawa.
## - Its ARMOR (Armor, Shell, Rough Hide) takes one blow for her, then needs a moment to take
##   another (LevelBase hands it to PlayerHurtbox2D as its guard).
##
## Dilim answers its fights by deeds (a creature driven off, or felled), so a sting that drives off
## the sigbin answers the fight as a sword's blow does; no ability tag is borrowed for it.

const EFFECTS_PATH := "res://config/ability_effects.json"
const ABILITIES_PATH := "res://config/abilities.json"
## Which of a body's abilities is its F action: the first strike, else the first grab.
const ACTION_KINDS := ["strike", "grab"]
## What a blow costs her body: a lunge the way it faces, so a blow is felt as well as seen.
const LUNGE := Vector2(220.0, -60.0)

static var _effects: Dictionary = {}
static var _abilities: Dictionary = {}

var class_id := ""
## The F action's effect row and its ConceptNet label, or {} for a body with none.
var action: Dictionary = {}
## The armor's effect row and label, or {}.
var armor: Dictionary = {}
var _ready_at_msec := 0
var _armor_ready_at_msec := 0


## What `class_id`'s body can do, from its ConceptNet abilities in their file order.
static func for_class(id: String) -> CreatureAbility:
	var ability := CreatureAbility.new()
	ability.class_id = id
	for label in labels_of(id):
		var effect := effect_of(label)
		var kind := String(effect.get("kind", ""))
		if kind in ACTION_KINDS:
			var current := String(ability.action.get("kind", ""))
			if ability.action.is_empty() or ACTION_KINDS.find(kind) < ACTION_KINDS.find(current):
				ability.action = effect.merged({"label": label})
		elif kind == "armor" and ability.armor.is_empty():
			ability.armor = effect.merged({"label": label})
	return ability


## A class's ConceptNet ability labels, as config/abilities.json lists them.
static func labels_of(id: String) -> Array[String]:
	_load()
	var out: Array[String] = []
	var entry: Dictionary = _abilities.get(id, {})
	for row: Variant in entry.get("abilities", []):
		if row is Dictionary:
			out.append(String((row as Dictionary).get("label", "")))
	return out


## What an ability label does in play, or {} for one that does nothing here yet.
static func effect_of(label: String) -> Dictionary:
	_load()
	return (_effects.get(label, {}) as Dictionary).duplicate()


## Every effect row, by label -- for a probe.
static func effects() -> Dictionary:
	_load()
	return _effects.duplicate(true)


## Whether `tool` is a body's own blow (a strike's id), for whatever accepts named weapons.
static func is_strike(tool: String) -> bool:
	_load()
	for effect: Variant in _effects.values():
		if effect is Dictionary and String((effect as Dictionary).get("kind", "")) == "strike" \
				and String((effect as Dictionary).get("id", "")) == tool:
			return true
	return false


static func _load() -> void:
	if not _effects.is_empty():
		return
	var effects: Variant = JSON.parse_string(FileAccess.get_file_as_string(EFFECTS_PATH))
	if effects is Dictionary:
		_effects = (effects as Dictionary).get("effects", {})
	var abilities: Variant = JSON.parse_string(FileAccess.get_file_as_string(ABILITIES_PATH))
	if abilities is Dictionary:
		_abilities = (abilities as Dictionary).get("abilities", {})


func has_action() -> bool:
	return not action.is_empty()


## The word the F prompt shows: STING, RAM, SQUEEZE.
func verb() -> String:
	return String(action.get("verb", "USE"))


func is_ready() -> bool:
	return Time.get_ticks_msec() >= _ready_at_msec


func reach() -> float:
	if String(action.get("kind", "")) == "strike":
		return WeaponTable.reach(String(action.get("id", "")))
	return float(action.get("reach", 80.0))


## The F action from `actor`'s middle at `origin`, the way `facing` points. Returns what it landed
## on; empty for a miss, or while the last one is still under way.
func act(actor: Node2D, origin: Vector2, facing: float) -> Array[Node]:
	var landed: Array[Node] = []
	if not has_action() or not is_ready() or actor == null or not is_instance_valid(actor):
		return landed
	var kind := String(action["kind"])
	var id := String(action.get("id", ""))
	var cooldown := WeaponTable.cooldown_ms(id) if kind == "strike" else 900
	_ready_at_msec = Time.get_ticks_msec() + maxi(cooldown, 200)
	if actor.has_method("apply_external_impulse"):
		actor.call("apply_external_impulse", Vector2(LUNGE.x * facing, LUNGE.y))
	for target in _targets(actor, origin, facing):
		if kind == "strike":
			var answered: Variant = target.call("apply_tool_hit", id, 600.0, actor)
			if not (answered is bool and answered):
				continue
			var ticks := int(action.get("burn_ticks", 0))
			if ticks > 0 and target.has_method("apply_burn"):
				target.call("apply_burn", ticks, float(action.get("burn_seconds", 1.0)))
			landed.append(target)
		elif target.has_method("stun"):
			target.call("stun", float(action.get("hold_seconds", 1.0)))
			landed.append(target)
	var world := actor.get_parent()
	for target in landed:
		var at := (target as Node2D).global_position if target is Node2D else origin
		CannonShot2D.burst(world, at, CannonShot2D.Burst.STRUCK if kind == "strike"
			else CannonShot2D.Burst.LANDED)
	if landed.is_empty():
		CannonShot2D.burst(world, origin + Vector2(facing * reach() * 0.6, 0.0), CannonShot2D.Burst.MUZZLE)
	return landed


## Whether the armor takes this blow for her: ready, it does, and needs a moment before the next.
func absorbs_hit() -> bool:
	if armor.is_empty() or Time.get_ticks_msec() < _armor_ready_at_msec:
		return false
	_armor_ready_at_msec = Time.get_ticks_msec() + int(float(armor.get("ready_seconds", 3.0)) * 1000.0)
	return true


## What a blow from `origin` could reach the way `facing` points: anything that answers a drawn
## weapon (apply_tool_hit) for a strike, or can be held (stun) for a grab -- never her own body.
func _targets(actor: Node2D, origin: Vector2, facing: float) -> Array[Node]:
	var found: Array[Node] = []
	var space := actor.get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = reach()
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, origin)
	query.collision_mask = PhysicsLayers.WORLD
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var wants := "apply_tool_hit" if String(action.get("kind", "")) == "strike" else "stun"
	var arc := deg_to_rad(WeaponTable.arc_degrees(String(action.get("id", "")))) \
		if String(action.get("kind", "")) == "strike" else PI
	for hit: Dictionary in space.intersect_shape(query, 32):
		var target := _owner_of(hit.get("collider") as Node, wants)
		if target == null or found.has(target) or _is_her(target, actor):
			continue
		var at := (target as Node2D).global_position if target is Node2D else origin
		var offset := at - origin
		if offset.length() > 12.0 and absf(Vector2(facing, 0.0).angle_to(offset)) > arc * 0.5:
			continue
		found.append(target)
	return found


static func _owner_of(collider: Node, method: String) -> Node:
	var node := collider
	while node != null:
		if node.has_method(method):
			return node
		node = node.get_parent()
	return null


static func _is_her(target: Node, actor: Node) -> bool:
	return target == actor or actor.is_ancestor_of(target) or target.is_ancestor_of(actor) \
		or target.is_in_group(&"player_character") or target is ActiveRagdollMorph
