extends SceneTree
## The audio files, headless: each id with a file resolves, music and ambience loop where Godot
## plays them, no sound effect loops, and every file has something that plays it. And the plumbing
## that plays them: a change of track crossfades, the ambience is its own channel, a spaced sound
## effect is not repeated inside its spacing, the Music slider moves the Music bus, and a level that
## has not opted in (LevelBase._level_music) leaves the music as it found it. The house plays its
## own loop and fades it when she leaves.
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

## A fade's length and then some: how long a probe waits for one to finish.
const FADE_WAIT_S := 2.0
## A spacing set for the probe's own id, long enough that two plays a frame apart fall inside it.
const PROBE_SPACING_S := 0.4

var failures := 0
var checked := 0
const CHECKS := 16
var director: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(240.0).timeout.connect(func() -> void:
		print("OBRA_AUDIO_FAILED=watchdog")
		quit(2))
	director = root.get_node(^"AudioDirector")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var music: Dictionary = _voiced(catalog.get("music", {}))
	var ambience: Dictionary = _voiced(catalog.get("ambience", {}))
	var sfx: Dictionary = _voiced(catalog.get("sfx", {}))
	# Music and ambience loop alike; labelled by section, since an id may be in both.
	var loops := {}
	for id: String in music:
		loops["music." + id] = music[id]
	for id: String in ambience:
		loops["ambience." + id] = ambience[id]
	_every_voiced_id_resolves(loops, sfx)
	_music_loops(loops)
	_no_sound_effect_loops(sfx)
	_every_voiced_id_has_a_caller(music, ambience, sfx)
	await _the_menu_plays_its_music()
	await _the_house_plays_its_music_and_fades_it_when_she_leaves()
	await _a_new_track_crossfades(music)
	await _the_ambience_is_its_own_channel(music)
	_a_spaced_sound_is_not_repeated_inside_its_spacing(music)
	_the_music_slider_moves_the_music_bus()
	await _a_level_that_has_not_opted_in_leaves_the_music_alone()
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


func _every_voiced_id_resolves(loops: Dictionary, sfx: Dictionary) -> void:
	# ⚠ Without this the rest passes on an empty catalogue: nothing voiced, nothing wrong.
	_check(loops.size() + sfx.size() > 0, "at least one id has a file",
		"%d music or ambience, %d sfx" % [loops.size(), sfx.size()])
	var broken: Array[String] = []
	for section: Dictionary in [loops, sfx]:
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
func _every_voiced_id_has_a_caller(music: Dictionary, ambience: Dictionary, sfx: Dictionary) -> void:
	var code := ""
	for folder: String in CODE_FOLDERS:
		code += _read_scripts(folder)
	var orphans: Array[String] = []
	for section: Dictionary in [music, ambience, sfx]:
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
	var player := director.call(&"music_player") as AudioStreamPlayer
	var playing := director.call(&"current_music") as StringName
	_check(playing == &"menu", "the main menu plays music.menu", "playing '%s'" % playing)
	var path := player.stream.resource_path if player.stream != null else ""
	_check(player.playing and path.ends_with("/menu.wav"), "the music player is sounding the menu's file",
		"playing %s, %s" % [player.playing, path])
	menu.queue_free()
	await _frames(3)
	playing = director.call(&"current_music") as StringName
	var faded := await _until(func() -> bool: return not player.playing, FADE_WAIT_S)
	_check(playing == &"" and faded, "leaving the menu fades its music out and stops it",
		"playing '%s', player stopped %s" % [playing, faded])


## The house's own loop while she is home, faded out when she leaves.
func _the_house_plays_its_music_and_fades_it_when_she_leaves() -> void:
	director.call(&"stop_music", 0.0)
	var hub := (load("res://levels/hub/hub.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	await _frames(5)
	var playing := director.call(&"current_music") as StringName
	var player := director.call(&"music_player") as AudioStreamPlayer
	var path := player.stream.resource_path if player.stream != null else ""
	hub.queue_free()
	await _frames(3)
	var left := director.call(&"current_music") as StringName
	var faded := await _until(func() -> bool: return not player.playing, FADE_WAIT_S)
	_check(playing == &"house" and path.ends_with("/house.wav") and left == &"" and faded,
		"the house plays music.house while she is home, and fades it when she leaves",
		"home '%s' (%s), after '%s', faded %s" % [playing, path.get_file(), left, faded])


## Two tracks overlap for the fade, the old falling and the new rising, and then only the new one
## plays, at full. The second track is the menu's own file under a probe id: what is checked is the
## crossfade, not a second piece of music.
func _a_new_track_crossfades(music: Dictionary) -> void:
	_music_paths()["_probe_second"] = music.get("menu", "")
	director.call(&"play_music", &"menu", 0.0)
	var first := director.call(&"music_player") as AudioStreamPlayer
	director.call(&"play_music", &"_probe_second")
	var second := director.call(&"music_player") as AudioStreamPlayer
	await create_timer(0.25).timeout
	var both := first != second and first.playing and second.playing
	var crossing := first.volume_db < -0.5 and second.volume_db < -0.5 and second.volume_db > -60.0
	var mid := "old %.1f dB, new %.1f dB" % [first.volume_db, second.volume_db]
	var done := await _until(func() -> bool: return not first.playing, FADE_WAIT_S)
	_check(both and crossing and done and second.playing and absf(second.volume_db) < 0.1,
		"a new track crossfades: both sound for the fade, then the new one alone at full",
		"%s; then old stopped %s, new %.1f dB" % [mid, done, second.volume_db])
	director.call(&"stop_music", 0.0)
	_music_paths().erase("_probe_second")


## The ambience plays on players of its own, so starting and stopping it leaves the music as it
## was. Its file here is the menu's, under a probe id.
func _the_ambience_is_its_own_channel(music: Dictionary) -> void:
	(director.get(&"_ambience").get(&"paths") as Dictionary)["_probe_bed"] = music.get("menu", "")
	director.call(&"play_music", &"menu", 0.0)
	director.call(&"play_ambience", &"_probe_bed")
	var bed := director.call(&"ambience_player") as AudioStreamPlayer
	var track := director.call(&"music_player") as AudioStreamPlayer
	await _frames(3)
	var together := bed != null and bed.playing and track.playing and bed != track
	director.call(&"stop_ambience")
	var gone := await _until(func() -> bool: return not bed.playing, FADE_WAIT_S)
	var music_on: bool = track.playing and director.call(&"current_music") == &"menu"
	_check(together and gone and music_on and director.call(&"current_ambience") == &"",
		"the ambience is its own channel: it starts and stops under the music without touching it",
		"together %s, faded %s, music still on %s" % [together, gone, music_on])
	director.call(&"stop_music", 0.0)
	(director.get(&"_ambience").get(&"paths") as Dictionary).erase("_probe_bed")


## Asked for again inside its spacing, a sound is announced but not played; after it, it plays.
func _a_spaced_sound_is_not_repeated_inside_its_spacing(music: Dictionary) -> void:
	var paths := director.get(&"_sfx_paths") as Dictionary
	var spacing := director.get(&"_sfx_spacing") as Dictionary
	paths["_probe_tick"] = music.get("menu", "")
	spacing["_probe_tick"] = PROBE_SPACING_S
	var announced := [0]
	var count := func(id: StringName, _loudness: float) -> void:
		if id == &"_probe_tick":
			announced[0] += 1
	director.connect(&"sfx_requested", count)
	var first := bool(director.call(&"play_sfx", &"_probe_tick"))
	var again := bool(director.call(&"play_sfx", &"_probe_tick"))
	(director.get(&"_sfx_last_ms") as Dictionary)["_probe_tick"] = Time.get_ticks_msec() - int(PROBE_SPACING_S * 1000.0) - 1
	var later := bool(director.call(&"play_sfx", &"_probe_tick"))
	director.disconnect(&"sfx_requested", count)
	for voice in director.get_children():
		if voice is AudioStreamPlayer and String(voice.name).begins_with("SfxVoice"):
			(voice as AudioStreamPlayer).stop()
	paths.erase("_probe_tick")
	spacing.erase("_probe_tick")
	_check(first and not again and later and announced[0] == 3,
		"a spaced sound effect is not repeated inside its spacing, but is still announced",
		"first %s, again %s, after the spacing %s, announced %d" % [first, again, later, announced[0]])


## Dragged, the Music slider is heard at once: the Music bus follows it live.
func _the_music_slider_moves_the_music_bus() -> void:
	var settings := (load("res://ui/settings_overlay.tscn") as PackedScene).instantiate()
	root.add_child(settings)
	var bus := AudioServer.get_bus_index(&"Music")
	var before := AudioServer.get_bus_volume_db(bus)
	var slider := settings.get_node(^"Root/Center/Panel/VBox/MusicRow/Slider") as HSlider
	slider.value = 0.5
	var heard := AudioServer.get_bus_volume_db(bus)
	var readout := (settings.get_node(^"Root/Center/Panel/VBox/MusicRow/Value") as Label).text
	director.call(&"set_bus_linear", &"Music", db_to_linear(before))
	settings.free()
	_check(absf(heard - linear_to_db(0.5)) < 0.1 and readout == "50%",
		"the Music slider moves the Music bus as it is dragged", "%.1f dB, reads %s" % [heard, readout])


## Levels opt in to music (LevelBase._level_music, off by default): one that has not, opened and
## closed, leaves the music that was playing as it was.
func _a_level_that_has_not_opted_in_leaves_the_music_alone() -> void:
	director.call(&"play_music", &"menu", 0.0)
	var scene := (load("res://game_level.tscn") as PackedScene).instantiate()
	(scene.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(scene)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(20)
	var during := director.call(&"current_music") as StringName
	scene.queue_free()
	await _frames(5)
	var after := director.call(&"current_music") as StringName
	var player := director.call(&"music_player") as AudioStreamPlayer
	_check(during == &"menu" and after == &"menu" and player.playing,
		"a level that has not opted in leaves the music alone, in and out",
		"in it '%s', after it '%s', sounding %s" % [during, after, player.playing])
	director.call(&"stop_music", 0.0)


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


func _music_paths() -> Dictionary:
	return director.get(&"_music").get(&"paths") as Dictionary


## Poll `condition` each frame for up to `seconds`; whether it came true.
func _until(condition: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	return bool(condition.call())


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
