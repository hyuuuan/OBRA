extends SceneTree
## A drawn fan, switched on in her hand, blows a wind you can see and turns its own blades; off,
## both are gone. Kent: "when i draw a fan, there should be like a wind that comes out to it and
## it should like spin if its possible."
##
##   godot --headless --path game --script res://tests/run_fan_probe.gd
##
## Read back off what is on screen -- the gust sprites, the ink lines' transforms -- and off the
## bodies the wind moved, never off the fan's own idea of whether it is on.

## Every check this probe makes. A script error that skips some must not pass as quiet.
const CHECKS := 16
## The desk fan most people draw: a cage, three blades meeting at its middle, a pole, a base.
const CAGE := 0
const BLADES := [1, 2, 3]
const HUB := Vector2(256.0, 200.0)

var failures := 0
var checked := 0
var registry: EntityRegistry
var world: Node2D
var actor: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		print("OBRA_FAN_FAILED=watchdog")
		quit(2))
	world = Node2D.new()
	root.add_child(world)
	registry = EntityRegistry.new()
	world.add_child(registry)
	registry.load_manifest()
	actor = Node2D.new()
	actor.add_to_group(&"player_character")
	actor.global_position = Vector2(500.0, 300.0)
	world.add_child(actor)
	_the_blades_are_found_only_where_there_are_blades()
	await _on_it_blows_and_turns_off_it_stops()
	await _turned_round_the_wind_goes_the_other_way()
	await _without_blades_it_flutters_whole()
	await _with_reduced_motion_the_wind_stands_still()
	if checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_FAN_OK")
		quit(0)
	else:
		print("OBRA_FAN_FAILED=%d" % failures)
		quit(1)


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if not ok:
		failures += 1
	print("  %s\t%s\t%s" % ["OK  " if ok else "FAIL", what, detail])


# --- Which strokes are blades ------------------------------------------------------------------

func _the_blades_are_found_only_where_there_are_blades() -> void:
	var desk := FanBlades.find(_desk_fan())
	var hub: Vector2 = desk.get("hub", Vector2.INF)
	_check(Array(desk.get("blades", PackedInt32Array())) == BLADES and hub.distance_to(HUB) <= 6.0,
		"a desk fan's blades are the strokes inside its cage, turning on their hub",
		"blades %s, hub %s" % [desk.get("blades"), hub])
	var pinwheel := FanBlades.find(_pinwheel())
	_check(Array(pinwheel.get("blades", PackedInt32Array())) == [0, 1, 2, 3],
		"blades radiating all round, with no cage, turn -- and the pole they stand on does not",
		"blades %s" % pinwheel.get("blades"))
	var hand := FanBlades.find(_hand_fan())
	var ribs := FanBlades.find(_hand_fan().slice(0, 5))
	var one := FanBlades.find([_stroke([Vector2(0, 0), Vector2(40, 0)])])
	_check(hand.is_empty() and ribs.is_empty() and one.is_empty(),
		"a folding hand fan (with its edge or without), or a single stroke, has no blades to turn",
		"hand %s, ribs %s, one stroke %s" % [hand, ribs, one])


# --- On and off --------------------------------------------------------------------------------

func _on_it_blows_and_turns_off_it_stops() -> void:
	var fan := await _held_fan(_desk_fan())
	var skin := fan.get_node("DrawingSkin") as RuntimeRig2D
	var drawn := _ink_of(skin)
	var ahead := _loose_box(fan.wind_origin() + Vector2(110.0, -30.0))
	var behind := _loose_box(fan.wind_origin() + Vector2(-110.0, 0.0))
	await _seconds(0.3)
	_check(not fan.is_blowing() and (fan.wind() == null or fan.wind().gusts().is_empty())
		and is_zero_approx(fan.blade_turn()),
		"held and off, it shows no wind and does not turn", "wind %s, turn %.2f"
			% [fan.wind().gusts() if fan.wind() != null else [], fan.blade_turn()])
	fan.describe_use(actor)
	await _seconds(0.6)
	var gusts := fan.wind().gusts()
	var inside := true
	for gust in gusts:
		inside = inside and fan.in_the_wind(gust["position"]) and bool(gust["flip_h"])
	_check(gusts.size() >= 2 and inside, "on, gusts come out of its front, inside the stream it pushes",
		"%d gusts, all inside and blowing right: %s" % [gusts.size(), inside])
	var first := fan.blade_turn()
	await _seconds(0.2)
	var turns := skin.stroke_turns()
	var only_blades := not is_zero_approx(turns[BLADES[0]]) and is_zero_approx(turns[CAGE]) \
		and is_zero_approx(turns[4]) and is_zero_approx(turns[5])
	_check(not is_zero_approx(first) and not is_equal_approx(first, fan.blade_turn()) and only_blades,
		"on, its blades turn -- and the cage, pole and base stand still",
		"turn %.2f then %.2f; strokes %s" % [first, fan.blade_turn(), turns])
	_check(_ink_of(skin) == drawn and _blades_keep_their_hub(fan, skin),
		"turning, every line is still exactly the stroke she drew, about the hub it was drawn on",
		"ink unchanged %s" % (_ink_of(skin) == drawn))
	var changes := 0
	var last := fan.blade_turn()
	var until := Time.get_ticks_msec() + 1000
	var frames := 0
	while Time.get_ticks_msec() < until:
		await process_frame
		frames += 1
		if fan.blade_turn() != last:
			changes += 1
			last = fan.blade_turn()
	_check(changes >= 8 and changes <= int(Motion.PIXEL_FPS) + 2,
		"it turns in held frames, at the game's pixel rate", "%d changes in a second of %d frames" % [changes, frames])
	_check(ahead.linear_velocity.x > 20.0 and absf(behind.linear_velocity.x) < 1.0,
		"what is in the wind is blown along it; what is behind her is not",
		"ahead %.0f px/s, behind %.0f px/s" % [ahead.linear_velocity.x, behind.linear_velocity.x])
	fan.describe_use(actor)
	await process_frame
	await process_frame
	var coasting := not is_zero_approx(fan.blade_turn())
	await _seconds(0.3)
	_check(not fan.is_blowing() and fan.wind().gusts().is_empty() and is_zero_approx(fan.wind().shown()),
		"off, the wind is gone", "%d gusts, shown %.2f" % [fan.wind().gusts().size(), fan.wind().shown()])
	await _seconds(2.4)
	var still := true
	for turn in skin.stroke_turns():
		still = still and is_zero_approx(turn)
	_check(coasting and is_zero_approx(fan.blade_turn()) and still,
		"off, the blades coast down and stop exactly as they were drawn",
		"coasting %s, then %.3f, strokes %s" % [coasting, fan.blade_turn(), skin.stroke_turns()])
	for node in [fan, ahead, behind]:
		node.queue_free()
	await _seconds(0.1)


func _turned_round_the_wind_goes_the_other_way() -> void:
	var fan := await _held_fan(_desk_fan())
	Input.action_press(&"move_left")
	fan.describe_use(actor)
	await _seconds(0.5)
	var gusts := fan.wind().gusts()
	var left := gusts.size() >= 2
	for gust in gusts:
		left = left and (gust["position"] as Vector2).x < fan.wind_origin().x and not bool(gust["flip_h"])
	Input.action_release(&"move_left")
	_check(fan.wind_axis().x < 0.0 and left, "facing left, it blows left", "axis %s, %d gusts all left %s"
		% [fan.wind_axis(), gusts.size(), left])
	fan.queue_free()
	await _seconds(0.1)


func _without_blades_it_flutters_whole() -> void:
	var fan := await _held_fan(_hand_fan())
	var skin := fan.get_node("DrawingSkin") as RuntimeRig2D
	fan.describe_use(actor)
	var widest := 0.0
	var together := true
	var until := Time.get_ticks_msec() + 600
	while Time.get_ticks_msec() < until:
		await process_frame
		widest = maxf(widest, absf(fan.blade_turn()))
		var turns := skin.stroke_turns()
		for turn in turns:
			together = together and is_equal_approx(turn, turns[0])
	_check(not fan.turns_its_blades() and widest > 0.05 and together and not fan.wind().gusts().is_empty(),
		"with no blades to find it flutters whole, and still blows", "widest %.2f, together %s" % [widest, together])
	fan.describe_use(actor)
	await process_frame
	await process_frame
	_check(is_zero_approx(fan.blade_turn()), "off, the flutter stops at once", "turn %.3f" % fan.blade_turn())
	fan.queue_free()
	await _seconds(0.1)


func _with_reduced_motion_the_wind_stands_still() -> void:
	var profile := root.get_node("PlayerProfile")
	profile.call("set_setting", "reduce_motion", true)
	var fan := await _held_fan(_desk_fan())
	fan.describe_use(actor)
	await _seconds(0.4)
	var before := fan.wind().gusts()
	await _seconds(0.5)
	var after := fan.wind().gusts()
	var held := before.size() >= 2 and before.size() == after.size()
	for index in range(mini(before.size(), after.size())):
		held = held and before[index]["position"] == after[index]["position"]
	_check(held and is_zero_approx(fan.blade_turn()),
		"with reduced motion the gusts stand still and the blades stay as drawn",
		"%d then %d gusts, held %s, turn %.2f" % [before.size(), after.size(), held, fan.blade_turn()])
	fan.describe_use(actor)
	await _seconds(0.3)
	_check(fan.wind().gusts().is_empty(), "and off, the still wind goes too", "%d gusts" % fan.wind().gusts().size())
	profile.call("set_setting", "reduce_motion", false)
	fan.queue_free()
	await _seconds(0.1)


# --- Helpers -----------------------------------------------------------------------------------

func _held_fan(strokes: Array) -> UtilityObject:
	var entry := registry.get_entity("fan")
	var fan := registry.instantiate_entity("fan") as UtilityObject
	world.add_child(fan)
	fan.apply_item_data(DrawnItemData.from_prediction("fan", "Fan", _blank_image(), strokes, 0.9, entry))
	fan.global_position = actor.global_position
	await physics_frame
	fan.interact(actor)
	await _seconds(0.1)
	return fan


## A body standing loose in the air (no gravity), for the wind to move or not.
func _loose_box(at: Vector2) -> RigidBody2D:
	var box := RigidBody2D.new()
	box.gravity_scale = 0.0
	var shape := CollisionShape2D.new()
	var square := RectangleShape2D.new()
	square.size = Vector2(20.0, 20.0)
	shape.shape = square
	box.add_child(shape)
	world.add_child(box)
	box.global_position = at
	return box


## Every ink line's points, as drawn on screen in stroke space.
func _ink_of(skin: RuntimeRig2D) -> Array:
	var out: Array = []
	for points in skin.debug_skin_points():
		out.append(PackedVector2Array(points))
	return out


## Each blade line's transform leaves the hub where it is: they turn about it, not drift.
## ⚠ Asked of the rig's own strokes. Searching the skin for Line2D found none -- the lines hang off
## the rig's body, not under DrawingSkin -- and the check passed with nothing to check.
func _blades_keep_their_hub(fan: UtilityObject, skin: RuntimeRig2D) -> bool:
	var hub: Vector2 = fan.blades().get("hub", Vector2.INF)
	if hub == Vector2.INF:
		return false
	var turned := 0
	for turn in skin.stroke_transforms():
		if is_zero_approx(turn.get_rotation()):
			continue
		turned += 1
		if (turn * hub).distance_to(hub) > 0.01:
			return false
	return turned == BLADES.size()


func _desk_fan() -> Array:
	var cage := PackedVector2Array()
	for index in range(41):
		var angle := TAU * float(index) / 40.0
		cage.append(HUB + Vector2(cos(angle), sin(angle)) * 90.0)
	var strokes := [_stroke(cage)]
	for blade in range(3):
		var heading := -PI * 0.5 + TAU * float(blade) / 3.0
		var out := Vector2.from_angle(heading) * 70.0
		var side := Vector2.from_angle(heading + PI * 0.5) * 18.0
		strokes.append(_stroke([HUB, HUB + out * 0.5 + side, HUB + out, HUB + out * 0.5 - side, HUB]))
	strokes.append(_stroke([HUB + Vector2(0, 90), HUB + Vector2(0, 220)]))
	strokes.append(_stroke([HUB + Vector2(-70, 220), HUB + Vector2(70, 220)]))
	return strokes


## Four blades from a middle, on a pole down to a base.
func _pinwheel() -> Array:
	var middle := Vector2(256.0, 200.0)
	var strokes := []
	for blade in range(4):
		strokes.append(_stroke([middle, middle + Vector2.from_angle(TAU * float(blade) / 4.0 + 0.4) * 80.0]))
	strokes.append(_stroke([middle, middle + Vector2(0, 200)]))
	strokes.append(_stroke([middle + Vector2(-60, 200), middle + Vector2(60, 200)]))
	return strokes


## Ribs from a pivot over a third of a turn, and the leaf's edge across their tops.
func _hand_fan() -> Array:
	var pivot := Vector2(256.0, 400.0)
	var strokes := []
	var edge := PackedVector2Array()
	for rib in range(5):
		var heading := -PI * 0.5 + (float(rib) / 4.0 - 0.5) * TAU / 3.0
		strokes.append(_stroke([pivot, pivot + Vector2.from_angle(heading) * 200.0]))
	for step in range(17):
		edge.append(pivot + Vector2.from_angle(-PI * 0.5 + (float(step) / 16.0 - 0.5) * TAU / 3.0) * 200.0)
	strokes.append(_stroke(edge))
	return strokes


func _stroke(points: Variant) -> Dictionary:
	return {"points": PackedVector2Array(points), "width": 6.0, "color": Color.BLACK}


func _blank_image() -> Image:
	var image := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return image


func _seconds(duration: float) -> void:
	var until := Time.get_ticks_msec() + int(duration * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
