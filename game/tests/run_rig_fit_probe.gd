extends SceneTree
## Does a creature drawn the way people draw it move the parts it should?
##
## Kent, 2026-10-24: "if i draw a bird, sometimes it does not recognize the wing to flap... its
## not just birds, some creatures as well when they are drawn differently." Every drawing in
## drawn_like_people_fixtures.gd labels its strokes; this builds each one exactly as the game
## does (EntityRegistry -> apply_drawing) and reads, per stroke, which kinds of bone carry its
## ink. A stroke drawn as a wing must be carried by the wings; a body, head or detail must not
## be carried by a limb, or the limb's swing throws it about.
##
## Run: godot --headless --path game --script res://tests/run_rig_fit_probe.gd

const Fixtures := preload("res://tests/drawn_like_people_fixtures.gd")

## The bones that may carry each moving part, and the least share of its ink they must hold.
const MOVERS := {
	"wing": ["wing"],
	"leg": ["leg"],
	"tail": ["tail", "chain"],
	"fin": ["fin", "chain"],
	"tentacle": ["tentacle", "leg", "arm", "chain", "fin"],
	"arm": ["arm", "wing", "leg"],
}
const MOVER_SHARE := 0.5
## The bones a still part may ride, and the most of it anything else may carry.
const STILL := {
	"body": ["body", "head"],
	"head": ["body", "head"],
	"detail": ["body", "head"],
}
## A swimmer's body IS what undulates, so its spine may carry the body outline.
const SWIMMER_BODY := ["body", "head", "chain", "tail"]
const STILL_SHARE := 0.25

var registry: EntityRegistry
var world: Node2D
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	world = Node2D.new()
	root.add_child(world)
	registry = EntityRegistry.new()
	world.add_child(registry)
	registry.load_manifest()
	var moving_ok := 0
	var moving := 0
	var still_ok := 0
	var still := 0
	for fixture_value in Fixtures.all():
		var fixture: Dictionary = fixture_value
		var result := _score(fixture)
		moving_ok += int(result["moving_ok"])
		moving += int(result["moving"])
		still_ok += int(result["still_ok"])
		still += int(result["still"])
	print("RIG_FIT moving parts carried by their bones %d of %d, still parts left still %d of %d" % [
		moving_ok, moving, still_ok, still])
	print("OBRA_RIG_FIT_OK" if failures == 0 else "OBRA_RIG_FIT_FAILED (%d of %d)" % [failures, checks])
	quit(0 if failures == 0 else 1)


func _score(fixture: Dictionary) -> Dictionary:
	var out := {"moving_ok": 0, "moving": 0, "still_ok": 0, "still": 0}
	var instance := registry.instantiate_entity(String(fixture["entity_id"])) as Node2D
	if instance == null:
		_check(false, "%s -- builds" % fixture["label"], "no entity %s" % fixture["entity_id"])
		return out
	world.add_child(instance)
	var strokes: Array = fixture["strokes"]
	instance.call("apply_drawing", _blank_image(), strokes)
	var skin := instance.get_node("DrawingSkin") as RuntimeRig2D
	var report := skin.debug_stroke_roles()
	var shares: Array = report["strokes"]
	var swimmer := String(report["archetype"]) == "swimmer"
	var wrong: Array[String] = []
	for index in range(mini(strokes.size(), shares.size())):
		var part := String((strokes[index] as Dictionary)["part"])
		var share: Dictionary = shares[index]
		if MOVERS.has(part):
			out["moving"] += 1
			var carried := _sum(share, MOVERS[part])
			if carried >= MOVER_SHARE:
				out["moving_ok"] += 1
			else:
				wrong.append("%s %d moved %.2f" % [part, index, carried])
		elif STILL.has(part):
			out["still"] += 1
			var allowed: Array = SWIMMER_BODY if swimmer and part == "body" else STILL[part]
			var thrown := 1.0 - _sum(share, allowed)
			if thrown <= STILL_SHARE:
				out["still_ok"] += 1
			else:
				wrong.append("%s %d swung %.2f by %s" % [part, index, thrown, _movers_of(share, allowed)])
	_check(wrong.is_empty() and shares.size() == strokes.size(),
		"%s (%s)" % [fixture["label"], report["archetype"]],
		"moving %d/%d still %d/%d%s" % [out["moving_ok"], out["moving"], out["still_ok"], out["still"],
			"" if wrong.is_empty() else " -- " + ", ".join(wrong)])
	instance.queue_free()
	return out


func _sum(share: Dictionary, roles: Array) -> float:
	var total := 0.0
	for role in roles:
		total += float(share.get(role, 0.0))
	return total


func _movers_of(share: Dictionary, allowed: Array) -> String:
	var names: Array[String] = []
	for role in share:
		if not allowed.has(role) and float(share[role]) > 0.05:
			names.append("%s %.2f" % [role, float(share[role])])
	return "/".join(names)


func _blank_image() -> Image:
	var image := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return image


func _check(ok: bool, what: String, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("  %s\t%s\t%s" % ["OK" if ok else "FAIL", what, detail])
