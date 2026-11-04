extends SceneTree
## Environment motion runs only in the mounted scenery pair and yields to drawing/settings.
const Fixture = preload("res://tests/level5_journey_fixture.gd")
var level: Node
var checked := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	level = load("res://level_5.tscn").instantiate()
	level.get_node("BackendSupervisor").auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP,"set_auto_dismiss",true)
	await create_timer(.3).timeout
	level.call("_on_backend_ready")
	level.set("_corridor_seen",true)
	level.get("lolo").vanish()
	level.set("_lolo_moment","gone")
	var journey: Node = level.get("_journey")
	var stages := 0
	var props := true
	var pure := true
	for scene in journey.scenes:
		var stage: Node = scene.get_node_or_null("RememberedLife")
		if stage == null: continue
		stages += 1
		props = props and stage.get("props").size()>=4
		pure = pure and stage.find_children("*","CollisionObject2D",true,false).is_empty()
	_check(stages==9 and props and pure,"nine authored memories contain scenery and wildlife without extra physics hosts")
	_check(journey.scenes[3].get_node_or_null("RememberedLife")==null
		and journey.scenes[4].get_node_or_null("RememberedLife")==null
		and journey.scenes[5].get_node_or_null("RememberedLife")==null,
		"Piyesta retains its existing plaza, nave and alley compositions")
	Fixture.prepare(level,Vector2(6650,-22))
	var field: Node = journey.scenes[0].get_node("RememberedLife")
	var remote: Node = journey.scenes[7].get_node("RememberedLife")
	var initial: float = field.get("clock")
	var waiting: float = remote.get("clock")
	await create_timer(.25).timeout
	_check(float(field.get("clock"))>initial and is_equal_approx(float(remote.get("clock")),waiting),
		"only visible scenery animates; distant memories keep their local clocks")
	Input.action_press("move_right")
	await create_timer(.8).timeout
	Input.action_release("move_right")
	_check(float(field.get("_scatter"))>0 and field.get("visitor").distance_to(level.get("player").global_position-journey.scenes[0].global_position)<10,
		"approaching the paddy with real movement lifts its perched birds")
	level.call("_open_the_page",true)
	initial=field.get("clock")
	await create_timer(.2,true).timeout
	_check(is_equal_approx(float(field.get("clock")),initial),"the drawing page pauses wildlife and water clocks")
	level.get("draw_panel").close_panel()
	var profile := root.get_node("PlayerProfile")
	profile.call("set_setting","reduce_motion",true)
	initial=field.get("clock")
	await create_timer(.2).timeout
	_check(is_equal_approx(float(field.get("clock")),initial),"Reduce Motion holds decorative water, wildlife and light motion")
	profile.call("set_setting","reduce_motion",false)
	Fixture.prepare(level,Vector2(15600,140))
	var bakunawa: Node = level.call("_fragment","bakunawa")
	var sprite: Sprite2D = bakunawa.get_node("Picture")
	var texture := sprite.texture
	var same_canvas := true
	for frame: Texture2D in bakunawa.get("_landmark_frames"):
		same_canvas = same_canvas and frame.get_size()==texture.get_size()
	await create_timer(.24).timeout
	_check(same_canvas and bakunawa.get("_landmark_frames").size()==13 and sprite.texture!=texture,
		"the remembered bakunawa swims through thirteen frames on one registered canvas")
	profile.call("set_setting","reduce_motion",true)
	await create_timer(.04).timeout
	texture=sprite.texture
	await create_timer(.24).timeout
	_check(sprite.texture==texture,"Reduce Motion holds the bakunawa's pose too")
	profile.call("set_setting","reduce_motion",false)
	level.queue_free()
	await process_frame
	print("OBRA_LEVEL5_STAGING_%s (%d checks)"%["OK" if failures==0 else "FAILED",checked])
	quit(0 if failures==0 else 1)

func _check(ok: bool, description: String) -> void:
	checked+=1
	failures+=int(not ok)
	print("  %s\t%s"%["OK" if ok else "FAIL",description])
