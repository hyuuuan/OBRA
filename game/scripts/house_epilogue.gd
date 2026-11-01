class_name HouseEpilogue
extends Node
## THE HOUSE, AFTER THE RUN (DIARY.md; Kent, 2026-11-01). Mayon ends with the apo saying "Lolo.
## Let's go home." and the house is where she comes home to -- the real room the run was always
## going to end in. It replaced the frame's return, which was a separate painted room.
##
## Every painting on the wall has Lolo in it now, alive and ageing across them, from Kent's own
## sheets of him (tools/build_house_lolo.py): Lola painted him into every one so he would always
## be somewhere, and the apo has brought the places back.
## Lola is in the room. The first time, she sees the apo and takes her for him:
##
##     "Mahal! You look so young!" -- "Lola, I'm your apo. I'm not Lolo." -- "Where is he, then?"
##     -- "He's right here. In all your works." -- "Oh."
##
## and walks the length of the house, past every one of them, to an empty easel at the far end,
## and asks the apo who she is, and whether she will watch her paint. Then the house is the
## player's again, and stays this way for the save: Lolo in the paintings, Lola at her easel.
##
## A level's furniture in a scene that is not a level: the house is not LevelBase, so this brings
## its own dialogue box and reads Mayon's dialogue file, where the end of Mayon's lines belong.

## The scene has played; the house can be walked again.
signal finished()

const DIALOGUE := "res://config/dialogue_l5.json"
## Remembered on the profile, the way a conversation heard is: it plays once, whatever happens
## between Mayon's end and the house (a quit included).
const HEARD := "house_epilogue"
const LOLO_ART := "res://assets/hub/paintings/%s_lolo.png"
## The empty easel, in the bay at the far end from Mayon's painting: "the other side of the room".
## Clear of Payyo's frame, which begins at 236.
const EASEL_X := 150.0
## She stands this far left of it, the canvas at her right hand, as she stands at Mayon's.
const AT_EASEL := 62.0
## The house's own scale, not Mayon's: a canvas no bigger than the paintings on the wall (128 x 72),
## on legs that stand it at her shoulder.
const CANVAS_SIZE := Vector2(96.0, 56.0)
const CANVAS_TOP := 112.0
const LEGS := 122.0
## Where she waits for the apo: this far to the right of where the apo comes home.
const BESIDE := 150.0
## An old woman's walk, the length of the house.
const WALK_SPEED := 170.0
## How long the camera stays on her at the easel before it goes back to the apo.
const HOLD_ON_HER := 1.5
const WOOD := Color(0.36, 0.24, 0.15)
const CANVAS := Color(0.96, 0.94, 0.89)
const CANVAS_EDGE := Color(0.78, 0.74, 0.66)

var lola: Lola2D
var easel: Node2D
## Every line said, {speaker, text, x, facing} -- where Lola stood as it was said, and whether she
## was facing the apo -- in order: an
## unattended run drops them unread, and a probe reads them here.
var said: Array[Dictionary] = []
var _box: DialogueBox
var _script: DialogueScript
var _hub: Node
var _following := false


## Whether the run has ended: the house is the one after Mayon.
static func after_the_run() -> bool:
	var profile := _profile()
	return profile != null and bool(profile.call(&"is_level_completed", "level_5"))


static func has_played() -> bool:
	var profile := _profile()
	return profile != null and int(profile.call(&"dialogue_heard_count", HEARD)) > 0


## Hang Lolo in the paintings, stand the easel and Lola in the room, and bring a dialogue box.
## `before` is the node Lola is put in front of in the tree (the apo, so the apo is drawn over
## her); `apo_x` is where the apo comes home.
func build(hub: Node, paintings: Array, ground_y: float, apo_x: float, before: Node) -> void:
	_hub = hub
	for node: Variant in paintings:
		var painting := node as Node2D
		var path := LOLO_ART % String(painting.get("level_id"))
		if ResourceLoader.exists(path):
			painting.set("art", load(path))
			painting.queue_redraw()
	easel = Node2D.new()
	easel.name = "EmptyEasel"
	easel.position = Vector2(EASEL_X, ground_y)
	easel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	easel.draw.connect(_draw_easel)
	hub.add_child(easel)
	lola = Lola2D.new()
	lola.name = "Lola"
	lola.with_easel = false
	hub.add_child(lola)
	if before != null and before.get_parent() == hub:
		hub.move_child(easel, before.get_index())
		hub.move_child(lola, before.get_index())
	if has_played():
		lola.position = Vector2(EASEL_X - AT_EASEL, ground_y)
	else:
		lola.position = Vector2(apo_x + BESIDE, ground_y)
		lola.greet.call_deferred()
	var layer := CanvasLayer.new()
	layer.name = "DialogueLayer"
	layer.layer = 8
	add_child(layer)
	_box = DialogueBox.new()
	_box.name = "DialogueBox"
	layer.add_child(_box)
	_script = DialogueScript.new()
	_script.load_from(DIALOGUE)


## The scene, once. Returns when the house is the player's again.
func play() -> void:
	# ⚠ NOT ON THE FIRST FRAME. The first line stops the tree, and a camera that has not yet had a
	# frame to place itself is stopped looking at the corner of the world.
	await get_tree().process_frame
	await get_tree().process_frame
	# The two of them in the frame together while they talk.
	var apo := _hub.get_node_or_null(^"Apo") as Node2D
	if apo != null:
		_hub.call(&"look_at_x", (apo.global_position.x + lola.global_position.x) * 0.5)
	await _say("HOUSE.home")
	_following = true
	await lola.walk_to(EASEL_X - AT_EASEL, WALK_SPEED)
	_following = false
	_hub.call(&"look_at_x", lola.global_position.x)
	lola.greet()
	await _say("HOUSE.easel")
	lola.face_the_painting()
	var profile := _profile()
	if profile != null:
		profile.call(&"note_dialogue_heard", HEARD)
	await get_tree().create_timer(HOLD_ON_HER).timeout
	_hub.call(&"look_back")
	finished.emit()


func _process(_delta: float) -> void:
	if _following and is_instance_valid(lola):
		_hub.call(&"look_at_x", lola.global_position.x)


func _say(hook: String) -> void:
	var beat: Array = []
	for line_value: Variant in _script.fire(hook):
		var line: Dictionary = line_value
		var text := _script.display_text(line)
		var speaker := String(line.get("speaker", "lola"))
		said.append({"speaker": speaker, "text": text, "x": lola.global_position.x,
			"facing": lola.is_turned()})
		beat.append({"text": text, "speaker": "Apo" if speaker == "apo" else speaker.capitalize(),
			"at": speaker})
	if beat.is_empty():
		return
	_box.speak(beat)
	if _box.is_open():
		await _box.conversation_finished


## An easel with nothing on it yet: Lola's own easel's shape (Lola2D), and a bare canvas.
func _draw_easel() -> void:
	easel.draw_line(Vector2(-22, 0), Vector2(0, -LEGS), WOOD, 4)
	easel.draw_line(Vector2(22, 0), Vector2(0, -LEGS), WOOD, 4)
	easel.draw_line(Vector2(0, -LEGS), Vector2(8, 0), WOOD, 3)
	var canvas := Rect2(Vector2(-CANVAS_SIZE.x * 0.5, -CANVAS_TOP), CANVAS_SIZE)
	easel.draw_rect(Rect2(canvas.position.x - 6.0, canvas.end.y, canvas.size.x + 12.0, 4.0), WOOD)
	easel.draw_rect(canvas.grow(3.0), WOOD)
	easel.draw_rect(canvas, CANVAS)
	easel.draw_rect(canvas, CANVAS_EDGE, false, 2.0)



static func _profile() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(^"PlayerProfile") if tree != null and tree.root != null else null
