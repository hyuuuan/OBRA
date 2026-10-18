extends SceneTree
## Look at Dilim's creatures as a player meets them: in the dark, in her lantern's light, at play
## framing -- the placeholder bodies (ART_PLACEHOLDERS.md) side by side, for a person to judge.
##
##   godot -t --resolution 1600x900 --path game --script res://tests/run_visual_dilim_creatures.gd
##
## Windowed (headless draws nothing). Writes /tmp/obra_dilim_<subject>.png for each and
## /tmp/obra_dilim_creatures.png, the sheet, four across, in the order the level meets them:
##   santelmo · nuno's mound · sigbin · tikbalang
##   kapre · tiyanak · bungisngis · the manananggal (both halves)
##   the aswang (dog, pig) · the wakwak and the tik-tik (ashed, so it shows)
## Those the scene places are found where they stand and she is put beside them; the night's are
## sent in beside her. She is in a long grace, and anything sent is blinded so it holds still.
##
## AN EMPTY-LOOKING CELL IS NOT ALWAYS A FAULT. The sigbin shows only as much as the light on it
## (it is a glint in the dark, by design), so out of her circle its cell shows her alone.

const GROUND_Y := 600.0
## Each subject: a name, where she stands, and what to send in beside her.
const SUBJECTS := [
	{"name": "santelmo", "at": 1580.0},
	{"name": "nuno", "at": 3230.0},
	{"name": "sigbin", "at": 7060.0},
	{"name": "tikbalang", "at": 8300.0},
	{"name": "kapre", "at": 13640.0},
	{"name": "tiyanak", "at": 16980.0},
	{"name": "bungisngis", "at": 19060.0},
	{"name": "manananggal", "at": 20720.0},
	{"name": "aswang", "at": 21000.0, "send": [["aswang_dog", Vector2(130.0, 0.0)], ["aswang_pig", Vector2(-140.0, 0.0)]]},
	{"name": "fliers", "at": 21000.0, "send": [["wakwak", Vector2(-130.0, -110.0)], ["tiktik", Vector2(130.0, -90.0)]]},
]
## What is cut out round her, in screen px at 1600 x 900, and where she sits in it.
const CROP := Vector2(720.0, 480.0)
const HER_IN_CROP := Vector2(360.0, 330.0)
## How big each one is on the sheet, and how many across.
const CELL := Vector2i(540, 360)
const ACROSS := 4

var level: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	level = (load("res://level_4.tscn") as PackedScene).instantiate()
	(level.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(level)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(40)
	var cells: Array[Image] = []
	var sent: Array[Node] = []
	for subject: Dictionary in SUBJECTS:
		for node in sent:
			if is_instance_valid(node):
				node.queue_free()
		sent.clear()
		await _put_her(float(subject["at"]))
		for row: Array in subject.get("send", []):
			sent.append(_send(String(row[0]), row[1]))
		await _frames(50)
		var cell := await _capture()
		cell.save_png("/tmp/obra_dilim_%s.png" % subject["name"])
		cells.append(cell)
	var rows := ceili(float(cells.size()) / ACROSS)
	var sheet := Image.create(CELL.x * ACROSS, CELL.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.03, 0.03, 0.04))
	for index in range(cells.size()):
		sheet.blit_rect(cells[index], Rect2i(Vector2i.ZERO, CELL),
			Vector2i((index % ACROSS) * CELL.x, (index / ACROSS) * CELL.y))
	sheet.save_png("/tmp/obra_dilim_creatures.png")
	print("OBRA_VISUAL_DILIM_CREATURES_DONE")
	quit(0)


## One of the night's, sent in beside her and blinded so it holds still -- the tik-tik ashed, so it
## shows.
func _send(kind: String, offset: Vector2) -> Node:
	var foe: Enemy2D
	match kind:
		"wakwak":
			foe = Wakwak2D.new()
		"tiktik":
			foe = Tiktik2D.new()
		_:
			foe = GroundEnemy2D.new()
	foe.kind = kind
	level.get_node(^"EnvironmentBaseplate/GameplayPlane").add_child(foe)
	foe.global_position = PlayerHurtbox2D.middle_of(level.get("player") as Node2D) + offset
	foe.reset_home()
	if foe is Tiktik2D:
		(foe as Tiktik2D).reveal(600.0)
	foe.stun(600.0)
	return foe


## What is round her now, cut out at CROP and scaled to a sheet's cell.
func _capture() -> Image:
	await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	var scale := float(shot.get_width()) / 1600.0
	var her := (level.get("player") as Node2D)
	var on_screen := her.get_viewport().get_canvas_transform() * PlayerHurtbox2D.middle_of(her)
	var corner := ((on_screen - HER_IN_CROP) * scale).round()
	var size := (CROP * scale).round()
	corner.x = clampf(corner.x, 0.0, shot.get_width() - size.x)
	corner.y = clampf(corner.y, 0.0, shot.get_height() - size.y)
	var cell := shot.get_region(Rect2i(Vector2i(corner), Vector2i(size)))
	cell.resize(CELL.x, CELL.y, Image.INTERPOLATE_NEAREST)
	# The sheet's format: blit_rect refuses anything else, and the window's shot is RGB.
	cell.convert(Image.FORMAT_RGBA8)
	return cell


func _put_her(x: float) -> void:
	var player := level.get("player") as Node2D
	(level.get("player_health") as PlayerHealth).call("_start_grace", 600.0)
	player.call("apply_morph_state", {"position": Vector2(x, GROUND_Y - 4.0), "linear_velocity": Vector2.ZERO})
	await _frames(20)


func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		if paused:
			call_group(DialogueBox.GROUP, &"hide_line")
			paused = false
