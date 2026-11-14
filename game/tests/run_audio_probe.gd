extends SceneTree
## The audio files, headless: each id with a file resolves, music loops where Godot plays it,
## no sound effect loops, and every file has something that plays it.
##
##   godot --headless --path game --script res://tests/run_audio_probe.gd
##
## Music is rendered from FamiTracker modules by tools/build_music.py into WAVs whose loop is a
## `smpl` chunk (audio/README.md). The loop is checked the way a player hears it: Godot mixes
## across the loop's end, and what follows must be the loop's start, with no jump at the seam
## bigger than the music makes on its own. Mayon's ids stay silent; run_level5_audit owns that.

const CATALOG := "res://config/audio.json"
## A loop shorter than this is a jingle on repeat, not a piece of music.
const SHORTEST_LOOP_S := 4.0
## Mixed on each side of a seam.
const AROUND_SEAM_S := 0.25
## What follows the seam must be the loop's start: the same samples, so all but identical.
const SAME_AS_LOOP_START := 0.98
## Just before the seam, the track must already be the audio that leads into its loop's start,
## so that what follows the jump is its true continuation. famirender fades the loop's end into
## it (0.997 over the last 2 ms); an unfaded end measures about 0.79, a hard cut far less.
const SEAMLESS := 0.95
## The window it is measured over, ending a few samples short of the seam so the resampler's
## taps never reach across it.
const LEAD_IN_FRAMES := 88
const RESAMPLER_REACH := 8
## Folders searched for the code that plays an id. Tests do not count.
const CODE_FOLDERS := ["res://scripts", "res://ui", "res://levels", "res://objects",
	"res://creatures", "res://environment"]

var failures := 0
var checked := 0
const CHECKS := 10
var director: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		print("OBRA_AUDIO_FAILED=watchdog")
		quit(2))
	director = root.get_node(^"AudioDirector")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var music: Dictionary = _voiced(catalog.get("music", {}))
	var sfx: Dictionary = _voiced(catalog.get("sfx", {}))
	_every_voiced_id_resolves(music, sfx)
	_music_loops(music)
	_no_sound_effect_loops(sfx)
	_every_voiced_id_has_a_caller(music, sfx)
	await _the_menu_plays_its_music()
	if checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_AUDIO_OK")
		quit(0)
	else:
		print("OBRA_AUDIO_FAILED=%d" % failures)
		quit(1)


## The ids with a path, id -> path.
func _voiced(section: Dictionary) -> Dictionary:
	var out := {}
	for id: String in section:
		if not String(section[id]).is_empty():
			out[id] = String(section[id])
	return out


func _every_voiced_id_resolves(music: Dictionary, sfx: Dictionary) -> void:
	# ⚠ Without this the rest passes on an empty catalogue: nothing voiced, nothing wrong.
	_check(music.size() + sfx.size() > 0, "at least one id has a file", "%d music, %d sfx" % [music.size(), sfx.size()])
	var broken: Array[String] = []
	for section: Dictionary in [music, sfx]:
		for id: String in section:
			if not (ResourceLoader.exists(section[id]) and load(section[id]) is AudioStream):
				broken.append("%s -> %s" % [id, section[id]])
	_check(broken.is_empty(), "every id with a file resolves to an audio stream",
		"all resolve" if broken.is_empty() else ", ".join(broken))


func _music_loops(music: Dictionary) -> void:
	var unlooped: Array[String] = []
	var not_back: Array[String] = []
	var clicks: Array[String] = []
	var heard: Array[String] = []
	for id: String in music:
		var stream := load(music[id]) as AudioStream
		var region := _loop_region(stream)
		if region.y - region.x < SHORTEST_LOOP_S:
			unlooped.append("%s (%.1f-%.1f s)" % [id, region.x, region.y])
			continue
		var across := _mix(stream, region.y - AROUND_SEAM_S, 2.0 * AROUND_SEAM_S)
		var at_start := _mix(stream, region.x - AROUND_SEAM_S, 2.0 * AROUND_SEAM_S)
		var half := across.size() / 2
		# A few samples past the seam, so the resampler's window holds only the loop's start.
		var likeness := _likeness(across.slice(half + 64), at_start.slice(half + 64))
		if likeness < SAME_AS_LOOP_START:
			not_back.append("%s (%.2f)" % [id, likeness])
		var lead_from := half - RESAMPLER_REACH - LEAD_IN_FRAMES
		var lead_in := _likeness(across.slice(lead_from, half - RESAMPLER_REACH),
			at_start.slice(lead_from, half - RESAMPLER_REACH))
		if lead_in < SEAMLESS:
			clicks.append("%s (%.3f)" % [id, lead_in])
		heard.append("%s %.1f-%.1f s, returns %.2f, lead-in %.3f" % [id, region.x, region.y, likeness, lead_in])
	_check(unlooped.is_empty(), "every music file loops, over at least %.0f s" % SHORTEST_LOOP_S,
		"; ".join(heard) if unlooped.is_empty() else ", ".join(unlooped))
	_check(not_back.is_empty(), "past its loop's end, each track plays its loop's start again",
		"all return" if not_back.is_empty() else ", ".join(not_back))
	_check(clicks.is_empty(), "each seam is seamless: before it, the track already leads into its loop's start",
		"all seamless" if clicks.is_empty() else ", ".join(clicks))


## A one-shot that loops would hold one of AudioDirector's SFX voices for ever.
func _no_sound_effect_loops(sfx: Dictionary) -> void:
	var looping: Array[String] = []
	for id: String in sfx:
		var region := _loop_region(load(sfx[id]) as AudioStream)
		if region.y > region.x:
			looping.append(id)
	_check(looping.is_empty(), "no sound effect loops",
		"%d checked" % sfx.size() if looping.is_empty() else ", ".join(looping))


## A file nothing asks for is a sound nobody hears. The literal &"<id>" must be in the code.
func _every_voiced_id_has_a_caller(music: Dictionary, sfx: Dictionary) -> void:
	var code := ""
	for folder: String in CODE_FOLDERS:
		code += _read_scripts(folder)
	var orphans: Array[String] = []
	for section: Dictionary in [music, sfx]:
		for id: String in section:
			if not code.contains("&\"%s\"" % id):
				orphans.append(id)
	_check(orphans.is_empty(), "every id with a file is played by some code",
		"all called" if orphans.is_empty() else "no caller: " + ", ".join(orphans))


func _the_menu_plays_its_music() -> void:
	director.call(&"stop_music")
	var menu := (load("res://ui/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await _frames(10)
	var player := director.get_node(^"MusicPlayer") as AudioStreamPlayer
	var playing := director.call(&"current_music") as StringName
	_check(playing == &"menu", "the main menu plays music.menu", "playing '%s'" % playing)
	var path := player.stream.resource_path if player.stream != null else ""
	_check(player.playing and path.ends_with("/menu.wav"), "the music player is sounding the menu's file",
		"playing %s, %s" % [player.playing, path])
	menu.queue_free()
	await _frames(3)
	playing = director.call(&"current_music") as StringName
	_check(playing == &"" and not player.playing, "leaving the menu stops its music",
		"playing '%s', player %s" % [playing, player.playing])


# --- helpers ---------------------------------------------------------------------------------

## The loop as (begin, end) in seconds, or (0, 0) when the stream does not loop.
func _loop_region(stream: AudioStream) -> Vector2:
	var wav := stream as AudioStreamWAV
	if wav != null:
		if wav.loop_mode != AudioStreamWAV.LOOP_FORWARD:
			return Vector2.ZERO
		var end := wav.loop_end if wav.loop_end > 0 else int(wav.get_length() * wav.mix_rate)
		return Vector2(wav.loop_begin / float(wav.mix_rate), end / float(wav.mix_rate))
	if stream != null and bool(stream.get(&"loop")):
		return Vector2(float(stream.get(&"loop_offset")), stream.get_length())
	return Vector2.ZERO


func _mix(stream: AudioStream, from_s: float, seconds: float) -> PackedFloat32Array:
	var playback := stream.instantiate_playback()
	playback.start(maxf(from_s, 0.0))
	var frames := playback.mix_audio(1.0, int(seconds * AudioServer.get_mix_rate()))
	var out := PackedFloat32Array()
	for frame in frames:
		out.append(frame.x)
	return out


## Normalised correlation: 1 the same, 0 unrelated (or one of them silent).
func _likeness(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var ab := 0.0
	var aa := 0.0
	var bb := 0.0
	for i in range(mini(a.size(), b.size())):
		ab += a[i] * b[i]
		aa += a[i] * a[i]
		bb += b[i] * b[i]
	return ab / sqrt(aa * bb + 1e-12)


func _read_scripts(folder: String) -> String:
	var dir := DirAccess.open(folder)
	if dir == null:
		return ""
	var text := ""
	for file in dir.get_files():
		if file.ends_with(".gd"):
			text += FileAccess.get_file_as_string(folder.path_join(file))
	for sub in dir.get_directories():
		text += _read_scripts(folder.path_join(sub))
	return text


func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if ok:
		print("  OK\t%s\t%s" % [what, detail])
	else:
		failures += 1
		print("  FAIL\t%s\t%s" % [what, detail])
