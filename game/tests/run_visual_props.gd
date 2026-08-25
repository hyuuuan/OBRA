extends SceneTree
## Photograph every prop in Level 1 that a developer drew in code, one file per prop, for
## whoever is going to draw them properly. Needs a REAL viewport, so no --headless:
##
##	 godot --path game --script res://tests/run_visual_props.gd
##
## Frames land in /tmp/obra_prop_*.png, cropped to the prop and with the HUD hidden. The
## point is not that these look good -- they are stand-ins, and they are listed as such in
## ART_PLACEHOLDERS.md. The point is that a replacement has to occupy the same space: every
## one of these has collision, a puzzle meaning, or both, and the shot is the box it lives
## in. Sizes here are the crop, not the prop; the document carries the real dimensions.

const OUTPUT_DIR := "/tmp"

## name, where the camera looks, how much of the world to keep, and any state to set first.
const SHOTS: Array = [
	{"name": "wanderer", "at": "player", "size": Vector2(300, 300)},
	{"name": "lolo", "at": "lolo", "size": Vector2(300, 300)},
	{"name": "hagdan_stair", "at": Vector2(836, 500), "size": Vector2(420, 320)},
	{"name": "floating_tread", "at": Vector2(440, 585), "size": Vector2(300, 220)},
	{"name": "ruined_bridge", "at": Vector2(2680, 180), "size": Vector2(700, 300)},
	{"name": "hidden_flower", "at": Vector2(2700, 578), "size": Vector2(260, 240), "do": "light_flower"},
	{"name": "stool_and_jar", "at": Vector2(2998, 227), "size": Vector2(130, 100)},
	{"name": "straw_1_intact", "at": Vector2(3150, 186), "size": Vector2(620, 270)},
	{"name": "straw_2_combed", "at": Vector2(3150, 186), "size": Vector2(620, 270), "do": "comb"},
	{"name": "straw_3_tunnelled", "at": Vector2(3150, 186), "size": Vector2(620, 270), "do": "tunnel"},
	{"name": "straw_4_scattered", "at": Vector2(3150, 186), "size": Vector2(620, 270), "do": "scatter"},
	{"name": "baul", "at": Vector2(3160, 202), "size": Vector2(260, 220), "do": "uncover"},
	{"name": "bale", "at": Vector2(3500, 116), "size": Vector2(540, 420)},
	{"name": "bulul", "at": Vector2(3474, 172), "size": Vector2(240, 190)},
	{"name": "dead_tree", "at": Vector2(2360, 90), "size": Vector2(480, 420), "do": "open_protector"},
	{"name": "crumbling_ledges", "at": Vector2(2795, 226), "size": Vector2(620, 240)},
]

var level: Node
var camera: Camera2D
var player: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://game_level.tscn") as PackedScene
	level = packed.instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	# The level opens on a line of dialogue, and a conversation stops the tree until the
	# player turns the page. Nobody is here to press a key, so dismiss it the way a skip
	# button would, and keep dismissing them -- otherwise the first obstacle the
	# walker reaches stops the world and it reports the level as a wall.
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _wait(1.2)

	player = level.get("player") as Node2D
	camera = level.get_node("EnvironmentBaseplate/WorldCamera") as Camera2D
	if player == null or camera == null:
		push_error("the level did not build a player or a camera")
		quit(1)
		return

	# No HUD over the props: the ink bar and the keybind row are UI, and they are not what
	# anyone is being asked to draw.
	var hud := level.get_node_or_null("CanvasLayer") as CanvasLayer
	if hud != null:
		hud.visible = false
	# The dialogue box is wide enough to cover whatever is being photographed. It used to
	# be a world-space bubble hanging off Lolo; it is now its own layer, so hiding the
	# HUD layer above does not take it with it.
	var dialogue := level.get_node_or_null("DialogueLayer") as CanvasLayer
	if dialogue != null:
		dialogue.visible = false

	# The camera clamps itself to the level's bounds, which would refuse to look at
	# anything within half a screen of either edge -- the bale among them.
	camera.set("target", null)
	camera.set("world_bounds", Rect2(-20000.0, -20000.0, 40000.0, 40000.0))

	var count := 0
	for shot_value: Variant in SHOTS:
		var shot: Dictionary = shot_value
		var name := String(shot["name"])
		_prepare(String(shot.get("do", "")))
		var focus: Vector2 = _focus(shot["at"])
		if name != "wanderer" and name != "lolo":
			# Out of shot, and above the fall line rather than below it: dropping the
			# player out of the world triggers a checkpoint restore, which would put him
			# back in the middle of the next photograph.
			player.global_position = Vector2(-3000.0, 0.0)
		camera.global_position = focus
		await _wait(0.35)
		await _capture(name, shot["size"])
		count += 1

	print("OBRA_VISUAL_PROPS_DONE (%d frames in %s)" % [count, OUTPUT_DIR])
	quit(0)


func _focus(at: Variant) -> Vector2:
	if at is Vector2:
		return at
	match String(at):
		"player":
			return player.global_position + Vector2(0.0, -40.0)
		"lolo":
			var lolo := level.get("lolo") as Node2D
			return lolo.global_position if lolo != null else player.global_position
	return Vector2.ZERO


## The states worth photographing, because a route that leaves a mark on the world is
## asking for two drawings of the same object rather than one.
func _prepare(what: String) -> void:
	match what:
		"comb", "tunnel", "scatter":
			# PUT IT BACK FIRST. comb() and tunnel() both refuse to run on a pile that is
			# not intact, and these four shots share one level -- so the frame labelled
			# "tunnelled" was a picture of the pile comb() had already left behind, every
			# run, for as long as this list has existed.
			for node in level.get_tree().get_nodes_in_group(&"straw_piles"):
				node.call("restore_intact")
				node.call(what)
		"uncover":
			for node in level.get_tree().get_nodes_in_group(&"baul"):
				node.call("reveal")
		"open_protector":
			# Every route branch starts inactive -- invisible AND intangible -- so that the
			# chasm reads as impassable until the player answers. The Protector branch is the
			# only one carrying drawn-in-code props, so opening it is enough to photograph
			# them, and the other two hold nothing but terrain.
			var routes := level.get_node_or_null(
				"EnvironmentBaseplate/GameplayPlane/Routes")
			if routes != null:
				routes.call("apply_route", "protector")
		"light_flower":
			# Unrevealed it is a grey bud by design: it sits behind a gate wanting a concept
			# from Level 4. Both states matter, but the lit one is the one to draw against.
			for node in level.get_tree().get_nodes_in_group(&"hidden_flowers"):
				node.call("reveal")


func _capture(name: String, size: Vector2) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var window := Vector2i(image.get_size()) / 2 - Vector2i(size) / 2
	var region := Rect2i(window, Vector2i(size)).intersection(
		Rect2i(Vector2i.ZERO, image.get_size()))
	image.get_region(region).save_png("%s/obra_prop_%s.png" % [OUTPUT_DIR, name])


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout
