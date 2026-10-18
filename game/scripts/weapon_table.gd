class_name WeaponTable
extends RefCounted
## What each drawn weapon does in a fight, per level: config/weapons.json, read once.
##
## A row is the default merged with the current level's override, field by field. Anything not
## in the table is not a weapon: it has no row, never wears, and does no damage.

const PATH := "res://config/weapons.json"

static var _data: Dictionary = {}


## The merged row for `weapon` in `level_id` (the current level when empty), or {} for a thing
## that is not a weapon.
static func row(weapon: String, level_id: String = "") -> Dictionary:
	_load()
	var base: Dictionary = (_data.get("default", {}) as Dictionary).get(weapon, {})
	if base.is_empty():
		return {}
	var level := level_id if not level_id.is_empty() else _current_level()
	var levels: Dictionary = _data.get("levels", {})
	var override: Dictionary = (levels.get(level, {}) as Dictionary).get(weapon, {})
	var merged := base.duplicate()
	merged.merge(override, true)
	return merged


static func is_weapon(weapon: String) -> bool:
	return not row(weapon).is_empty()


## Swings, throws or drops before it is spent; 0 is "never wears out".
static func uses(weapon: String, level_id: String = "") -> int:
	return int(row(weapon, level_id).get("uses", 0))


static func damage(weapon: String, level_id: String = "") -> int:
	return int(row(weapon, level_id).get("damage", 0))


static func reach(weapon: String, level_id: String = "") -> float:
	return float(row(weapon, level_id).get("reach", UtilityObject.TOOL_REACH))


## The swing's arc, in degrees, centred on her facing. 180 or more is the whole half she faces.
static func arc_degrees(weapon: String, level_id: String = "") -> float:
	return float(row(weapon, level_id).get("arc", 180.0))


static func cooldown_ms(weapon: String, level_id: String = "") -> int:
	return int(row(weapon, level_id).get("cooldown_ms", 0))


## The current level, asked of the LevelManager autoload through the tree rather than by name: a
## `--script` runner compiles this before any autoload exists, and the bare name will not compile.
static func _current_level() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return ""
	var manager := tree.root.get_node_or_null(^"LevelManager")
	return String(manager.get("current_level_id")) if manager != null else ""


static func _load() -> void:
	if not _data.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_data = parsed
	else:
		push_warning("WeaponTable: %s did not parse; no weapon has a row" % PATH)
