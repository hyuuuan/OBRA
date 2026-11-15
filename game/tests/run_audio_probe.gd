extends SceneTree
## The audio files, headless: each id with a file resolves, music and ambience loop where Godot
## plays them, no sound effect loops, and every file has something that plays it. And the plumbing
## that plays them: a change of track crossfades (and can keep its place, for two arrangements of
## one piece), the ambience is its own channel, a spaced sound
## effect is not repeated inside its spacing, the Music slider moves the Music bus, and a level that
## has not opted in (LevelBase._level_music) leaves the music as it found it. The places that play
## their own: the boot loading screen starts the title's loop and the menu carries it on, and
## the house plays its loop and fades it when she leaves. And the levels that have opted in: each
## plays its music and ambience when it opens and fades both when it closes, Piyesta changes them
## by room, Dagat trades its surface music for its deep one at the waterline and has its fight,
## Dilim races and survives its night to its own, Mayon climbs, remembers and finds her, the
## jingle ducks the music, and the ending goes home.
##
##   godot --headless --path game --script res://tests/run_audio_probe.gd
##
## Music is rendered from FamiTracker modules by tools/build_music.py into WAVs whose loop is a
## `smpl` chunk (audio/README.md). The loop is checked the way a player hears it: Godot mixes
## across the loop's end, and what follows must be the loop's start, with no jump at the seam
## bigger than the music makes on its own.

const CATALOG := "res://config/audio.json"
## A loop shorter than this is a jingle on repeat, not a piece of music.
const SHORTEST_LOOP_S := 4.0
## Mixed on each side of a seam.
const AROUND_SEAM_S := 0.25
## What follows the seam must be the loop's start: the same samples, so all but identical. Music
## measures 0.99-1.00; an ambience bed of broadband noise 0.96, because QOA and the resampler cost
## noise a few hundredths; a track that does not loop, 0.
const SAME_AS_LOOP_START := 0.90
## Just before the seam, the track must already be the audio that leads into its loop's start,
## so that what follows the jump is its true continuation. famirender fades the loop's end into
## it (0.975-0.998 over the last 2 ms for music, 0.945 for the noise of an ambience bed); an unfaded
## end measures about 0.79 for music and near 0 for noise, a hard cut far less.
const SEAMLESS := 0.90
## The window it is measured over, ending a few samples short of the seam so the resampler's
## taps never reach across it.
const LEAD_IN_FRAMES := 88
const RESAMPLER_REACH := 8
## ⚠ A seam out of silence has nothing to compare. Terraces loops out of a rest (-101 dBFS) into a
## gong and drum struck on the loop's first step; the window before the loop's start is digital
## zero in the file but reads 0.018 played, because QOA smears the attack a little backward
## (pre-echo), so the two correlate at 0.03. A loop that ends in silence cannot click: what follows
## is an onset, exactly as on the first pass. Below this level (-60 dBFS) the end counts as silence.
const SILENT := 0.001
## Folders searched for the code that plays an id. Tests do not count.
const CODE_FOLDERS := ["res://scripts", "res://ui", "res://levels", "res://objects",
	"res://creatures", "res://environment"]

## A fade's length and then some: how long a probe waits for one to finish.
const FADE_WAIT_S := 2.0
## A spacing set for the probe's own id, long enough that two plays a frame apart fall inside it.
const PROBE_SPACING_S := 0.4
## keep_position: where the outgoing track is sought to (well past the menu's 7.5 s intro), how
## far apart the two may be (a mix chunk and a frame), and the crossfade used.
const SOUGHT_S := 12.0
const SAME_PLACE_S := 0.05
const LOOP_FADE_PROBE_S := 0.6
## The probe's own crossfade, for reading its middle.
const CROSS_S := 1.0

var failures := 0
var checked := 0
const CHECKS := 40
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
	await _the_loading_screen_starts_the_title_music_and_the_menu_carries_it()
	await _the_house_plays_its_music_and_fades_it_when_she_leaves()
	await _a_new_track_crossfades(music)
	await _an_arrangement_takes_over_where_the_other_is(music)
	await _the_ambience_is_its_own_channel(music)
	_a_spaced_sound_is_not_repeated_inside_its_spacing(music)
	_the_music_slider_moves_the_music_bus()
	await _a_level_that_has_not_opted_in_leaves_the_music_alone()
	await _terraces_plays_its_music_and_wind_and_fades_both()
	await _piyesta_plays_its_music_and_lets_the_dance_keep_its_own_time()
	await _piyestas_church_has_its_own_music_and_no_street()
	await _dagat_trades_its_music_at_the_waterline()
	await _the_bakunawa_has_its_own_music_until_it_is_answered()
	await _dilim_races_to_its_own_music()
	await _dilims_night_builds_wave_by_wave_and_breaks_off_at_dawn()
	await _mayon_climbs_remembers_and_finds_her()
	await _the_jingle_lowers_the_music_for_its_own_length()
	await _the_ending_screen_plays_the_ending()
	# Last: it finishes Mayon on the profile, and takes the tree to the house.
	await _the_ending_goes_home_with_her()
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
		var before_seam := across.slice(lead_from, half - RESAMPLER_REACH)
		var before_start := at_start.slice(lead_from, half - RESAMPLER_REACH)
		var silent := _loudest(before_seam) < SILENT
		var lead_in := 1.0 if silent else _likeness(before_seam, before_start)
		if lead_in < SEAMLESS:
			clicks.append("%s (%.3f)" % [id, lead_in])
		heard.append("%s %.1f-%.1f s, returns %.2f, lead-in %s" % [id, region.x, region.y, likeness,
			"silent" if silent else "%.3f" % lead_in])
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


## The title card loading at boot is the title card: its music starts there, and the menu that
## follows asks for the same track, so it carries on -- the same player, never restarted.
func _the_loading_screen_starts_the_title_music_and_the_menu_carries_it() -> void:
	director.call(&"stop_music", 0.0)
	var screen: Node = (load("res://scripts/loading_screen.gd") as GDScript).new()
	root.add_child(screen)
	await _frames(3)
	var started := director.call(&"current_music") as StringName
	var player := director.call(&"music_player") as AudioStreamPlayer
	await create_timer(0.3).timeout
	var before := player.get_playback_position()
	screen.free()
	var menu := (load("res://ui/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await _frames(5)
	var same: bool = director.call(&"music_player") == player and player.playing
	var after := player.get_playback_position()
	# ⚠ >=, not >: headless, the playback position moves in mix-sized steps and can read the same
	# five frames later. A restart is what this guards against, and that reads near zero.
	_check(started == &"menu" and same and after >= before,
		"the boot loading screen starts the title's music, and the menu carries it on unrestarted",
		"started '%s', same player %s, %.2f s -> %.2f s" % [started, same, before, after])
	menu.queue_free()
	await _frames(3)
	director.call(&"stop_music", 0.0)


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
## plays, at full. ⚠ Equal power: halfway through, each is near -3 dB (a straight-line crossfade had
## both at -6, and the music sagged between places). The second track is the menu's own file under
## a probe id: what is checked is the crossfade, not a second piece of music.
func _a_new_track_crossfades(music: Dictionary) -> void:
	_music_paths()["_probe_second"] = music.get("menu", "")
	director.call(&"play_music", &"menu", 0.0)
	var first := director.call(&"music_player") as AudioStreamPlayer
	director.call(&"play_music", &"_probe_second", CROSS_S)
	var second := director.call(&"music_player") as AudioStreamPlayer
	await create_timer(CROSS_S * 0.5).timeout
	var both := first != second and first.playing and second.playing
	var middle := absf(first.volume_db + 3.0) < 1.5 and absf(second.volume_db + 3.0) < 1.5
	var mid := "old %.1f dB, new %.1f dB" % [first.volume_db, second.volume_db]
	var done := await _until(func() -> bool: return not first.playing, FADE_WAIT_S)
	_check(both and middle and done and second.playing and absf(second.volume_db) < 0.1,
		"a new track crossfades at equal power: both near -3 dB halfway, then the new one alone at full",
		"halfway %s; then old stopped %s, new %.1f dB" % [mid, done, second.volume_db])
	director.call(&"stop_music", 0.0)
	_music_paths().erase("_probe_second")


## Two arrangements of one piece trade places mid-bar (keep_position): the incoming track starts
## where the outgoing one is, within a mix chunk. And a plain change still starts at the top. The
## twin is the menu's own file under a probe id, with the menu sought well into its loop.
func _an_arrangement_takes_over_where_the_other_is(music: Dictionary) -> void:
	_music_paths()["_probe_twin"] = music.get("menu", "")
	_music_paths()["_probe_new"] = music.get("menu", "")
	for keep: bool in [true, false]:
		director.call(&"stop_music", 0.0)
		director.call(&"play_music", &"menu", 0.0)
		var first := director.call(&"music_player") as AudioStreamPlayer
		first.seek(SOUGHT_S)
		await _frames(3)
		director.call(&"play_music", &"_probe_twin" if keep else &"_probe_new", LOOP_FADE_PROBE_S, keep)
		var second := director.call(&"music_player") as AudioStreamPlayer
		var apart := absf(second.get_playback_position() - first.get_playback_position())
		var detail := "outgoing %.3f s, incoming %.3f s" % [first.get_playback_position(), second.get_playback_position()]
		if keep:
			_check(first != second and first.playing and apart < SAME_PLACE_S,
				"keep_position: the incoming arrangement starts where the outgoing one is", detail)
		else:
			_check(first != second and second.get_playback_position() < SAME_PLACE_S,
				"without keep_position a new track starts at its top", detail)
	director.call(&"stop_music", 0.0)
	_music_paths().erase("_probe_twin")
	_music_paths().erase("_probe_new")


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


## Levels opt in to music (LevelBase._level_music, off by default): one that has not asks for no
## music and no ambience, so LevelBase plays nothing when it opens and stops nothing when it
## leaves (_start_the_place_audio, _exit_tree: both act only on a hook's id). Every level has opted
## in now, so the one that has not is LevelBase itself -- out of the tree, where its @onready
## furniture is never looked up.
func _a_level_that_has_not_opted_in_leaves_the_music_alone() -> void:
	var bare: Node = (load("res://scripts/level_base.gd") as GDScript).new()
	var music := bare.call(&"_level_music") as StringName
	var ambience := bare.call(&"_level_ambience") as StringName
	bare.free()
	_check(music == &"" and ambience == &"",
		"a level that has not opted in asks for no music and no ambience, so LevelBase leaves both alone",
		"music '%s', ambience '%s'" % [music, ambience])


## Terraces opts in: its music and its wind start as it opens, over whatever played before, and
## both fade when it closes.
func _terraces_plays_its_music_and_wind_and_fades_both() -> void:
	director.call(&"play_music", &"menu", 0.0)
	var scene := (load("res://game_level.tscn") as PackedScene).instantiate()
	(scene.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(scene)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(20)
	var music := director.call(&"current_music") as StringName
	var wind := director.call(&"current_ambience") as StringName
	var track := director.call(&"music_player") as AudioStreamPlayer
	var bed := director.call(&"ambience_player") as AudioStreamPlayer
	var files := "%s, %s" % [track.stream.resource_path.get_file() if track.stream else "-",
		bed.stream.resource_path.get_file() if bed.stream else "-"]
	var sounding := track.playing and bed.playing
	scene.queue_free()
	await _frames(5)
	var after := "%s/%s" % [director.call(&"current_music"), director.call(&"current_ambience")]
	var faded := await _until(func() -> bool: return not track.playing and not bed.playing, FADE_WAIT_S)
	_check(music == &"level_1" and wind == &"level_1" and sounding and files == "level_1.wav, level_1.wav"
		and after == "/" and faded,
		"Terraces plays its music and wind as it opens, and fades both when it closes",
		"in it '%s' + '%s' (%s), after '%s', faded %s" % [music, wind, files, after, faded])


## Piyesta plays its loop over the street; the dance, which keeps its own beat, brings its own
## music, started with the attempt; and the plaza's comes back when the dance is over. Driven
## through the level's own handlers for the Artist route.
func _piyesta_plays_its_music_and_lets_the_dance_keep_its_own_time() -> void:
	director.call(&"play_music", &"menu", 0.0)
	var scene := await _open("res://level_2.tscn")
	var opened := "%s/%s" % [director.call(&"current_music"), director.call(&"current_ambience")]
	scene.call(&"_on_route_committed_here", "L2_N1", "artist")
	var danced := await _until(func() -> bool: return director.call(&"current_music") == &"dance", 10.0)
	var overlay := scene.get(&"dance_screen") as Node
	if overlay != null and overlay.has_method(&"close"):
		overlay.call(&"close")
	scene.call(&"_on_dance_screen_finished", true, true)
	var back := await _until(func() -> bool: return director.call(&"current_music") == &"level_2", 5.0)
	scene.queue_free()
	await _frames(5)
	_check(opened == "level_2/level_2" and danced and back,
		"Piyesta plays its music over the street, the dance its own, and the plaza's returns after",
		"opened '%s', dance music %s, back after %s" % [opened, danced, back])
	director.call(&"stop_music", 0.0)
	director.call(&"stop_ambience", 0.0)


## Inside the church a slow hymn plays and the street falls away; out of it, both come back.
## Through the level's own doors (_enter_room / _leave_room).
func _piyestas_church_has_its_own_music_and_no_street() -> void:
	var scene := await _open("res://level_2.tscn")
	var church := scene.get(&"church") as Node2D
	var player := scene.get(&"player") as Node2D
	scene.call(&"_enter_room", church, player.global_position)
	var inside := await _until(func() -> bool: return director.call(&"current_music") == &"church", 3.0)
	var hushed: bool = director.call(&"current_ambience") == &""
	scene.call(&"_leave_room", church)
	var outside := await _until(func() -> bool:
		return director.call(&"current_music") == &"level_2" and director.call(&"current_ambience") == &"level_2", 3.0)
	scene.queue_free()
	await _frames(5)
	_check(inside and hushed and outside, "Piyesta's church has its own hymn and no street; outside, both return",
		"hymn inside %s, street hushed %s, plaza and street outside %s" % [inside, hushed, outside])
	director.call(&"stop_music", 0.0)
	director.call(&"stop_ambience", 0.0)


## Dagat: the rowing song and the waves at the surface; below it the same piece from under the
## water, with no waves, at the same place in the bar; up again, both back. A frame between the
## waterline's two edges changes nothing, either way, and leaving from below takes the deep's music
## too. Through the level's own _refresh_the_place_audio, with its physics off so her own body
## does not answer first.
func _dagat_trades_its_music_at_the_waterline() -> void:
	director.call(&"play_music", &"menu", 0.0)
	var scene := await _open("res://level_3.tscn")
	var opened := _now_playing()
	scene.set_physics_process(false)
	var deep_in := float(scene.get_script().get_script_constant_map()["DEEP_IN"])
	var line := float(scene.get(&"_waterline_y"))
	var x := (scene.get(&"player") as Node2D).global_position.x
	var surface := director.call(&"music_player") as AudioStreamPlayer
	surface.seek(SOUGHT_S)
	await _frames(3)
	scene.call(&"_refresh_the_place_audio", Vector2(x, line + deep_in + 40.0))
	var deep := director.call(&"music_player") as AudioStreamPlayer
	var apart := absf(deep.get_playback_position() - surface.get_playback_position())
	var below := _now_playing()
	var file := deep.stream.resource_path.get_file() if deep.stream != null else "-"
	_check(opened == "level_3/level_3" and below == "level_3_deep/" and file == "level_3_deep.wav"
		and surface != deep and apart < SAME_PLACE_S,
		"Dagat: the rowing song and waves at the surface; diving, the deep's music at the same place, no waves",
		"opened '%s', below '%s' (%s), %.3f s apart" % [opened, below, file, apart])
	scene.call(&"_refresh_the_place_audio", Vector2(x, line + deep_in * 0.5))
	var held_deep := _now_playing()
	scene.call(&"_refresh_the_place_audio", Vector2(x, line - 40.0))
	var up := _now_playing()
	scene.call(&"_refresh_the_place_audio", Vector2(x, line + deep_in * 0.5))
	var held_surface := _now_playing()
	_check(held_deep == "level_3_deep/" and up == "level_3/level_3" and held_surface == "level_3/level_3",
		"Dagat: between the waterline's two edges the music stays as it was; up again, both return",
		"bobbing below '%s', up '%s', bobbing above '%s'" % [held_deep, up, held_surface])
	scene.call(&"_refresh_the_place_audio", Vector2(x, line + deep_in + 200.0))
	var left_from := _now_playing()
	scene.queue_free()
	await _frames(5)
	var after := _now_playing()
	var stopped := await _until(func() -> bool: return not deep.playing, FADE_WAIT_S)
	_check(left_from == "level_3_deep/" and after == "/" and stopped,
		"Dagat: leaving from below the surface takes the deep's music with it",
		"left from '%s', after '%s', stopped %s" % [left_from, after, stopped])
	director.call(&"stop_music", 0.0)
	director.call(&"stop_ambience", 0.0)


## The Bakunawa's fight plays from the moment it is met until it is answered, on each of its three
## routes -- led home (_on_gift_offered), subdued (_on_bakunawa_quiet) and slipped past in the dark
## (the solve the level makes when she is through) -- and the sea's music comes back after. A lost
## stretch, restoring the encounter's own checkpoint, keeps it; a restore from before the meeting
## hands it back. Through the level's own handlers, with its physics off.
func _the_bakunawa_has_its_own_music_until_it_is_answered() -> void:
	var heard: Array[String] = []
	for route: String in ["artist", "protector", "pragmatist"]:
		var scene := await _open("res://level_3.tscn")
		scene.set_physics_process(false)
		var at := Vector2((scene.get(&"player") as Node2D).global_position.x, float(scene.get(&"_waterline_y")) - 40.0)
		scene.call(&"_on_obstacle_entered", "L3_N2")
		scene.call(&"_refresh_the_place_audio", at)
		var met := String(director.call(&"current_music"))
		scene.call(&"_on_route_committed_here", "L3_N2", route)
		await _frames(2)
		var level_director := scene.get(&"director") as Node
		match route:
			"artist":
				scene.call(&"_on_gift_offered")
			"protector":
				scene.call(&"_on_bakunawa_quiet", "FOUGHT")
			"pragmatist":
				level_director.call(&"solve_with_item", "L3_N2", "the dark")
		scene.call(&"_refresh_the_place_audio", at)
		heard.append("%s: %s, then %s" % [route, met, director.call(&"current_music")])
		scene.queue_free()
		await _frames(5)
	_check(heard == ["artist: bakunawa, then level_3", "protector: bakunawa, then level_3",
		"pragmatist: bakunawa, then level_3"],
		"the Bakunawa's own music from the moment it is met until it is answered, on each route",
		"; ".join(heard))
	# Inside the fight: a lost stretch restores the encounter's own checkpoint, written on the
	# commit, and the fight goes on.
	var scene := await _open("res://level_3.tscn")
	scene.set_physics_process(false)
	var at := Vector2((scene.get(&"player") as Node2D).global_position.x, float(scene.get(&"_waterline_y")) - 40.0)
	scene.call(&"_on_obstacle_entered", "L3_N2")
	# Through the director, as the choice does: the level answers its signal.
	(scene.get(&"director") as Node).call(&"commit_route", "L3_N2", "protector")
	# The checkpoint the commit writes (level_03.json: L3_N2 "checkpoint_on_commit": "CP3").
	scene.call(&"_write_checkpoint", "CP3")
	await _frames(2)
	scene.call(&"_lose_the_stretch", "hit")
	var restored := String((scene.get(&"checkpoints") as Node).call(&"latest_id"))
	scene.call(&"_refresh_the_place_audio", at)
	var lost := String(director.call(&"current_music"))
	scene.queue_free()
	await _frames(5)
	# Before it: a checkpoint written before the meeting, then the meeting, then that restore.
	scene = await _open("res://level_3.tscn")
	scene.set_physics_process(false)
	scene.call(&"_write_checkpoint", "CP2")
	scene.call(&"_on_obstacle_entered", "L3_N2")
	scene.call(&"_refresh_the_place_audio", at)
	var met := String(director.call(&"current_music"))
	scene.call(&"_restore_checkpoint")
	scene.call(&"_refresh_the_place_audio", at)
	var before := String(director.call(&"current_music"))
	scene.queue_free()
	await _frames(5)
	_check(restored == "CP3" and lost == "bakunawa" and met == "bakunawa" and before == "level_3",
		"a lost stretch keeps the Bakunawa's music; a restore from before the meeting hands it back",
		"after the lost stretch (restored %s) '%s'; met '%s', restored to before it '%s'" % [restored, lost, met, before])
	director.call(&"stop_music", 0.0)
	director.call(&"stop_ambience", 0.0)


## Dilim: its forest and its night as it opens; while the tikbalang races, the race's own music,
## and the forest's when the race is over. A checkpoint restore mid-race (which resets the
## tikbalang, Enemy2D.GROUP) puts the forest's back, and leaving mid-race takes the race's music.
func _dilim_races_to_its_own_music() -> void:
	director.call(&"play_music", &"menu", 0.0)
	var scene := await _open("res://level_4.tscn")
	scene.set_physics_process(false)
	var opened := _now_playing()
	var files := "%s, %s" % [(director.call(&"music_player") as AudioStreamPlayer).stream.resource_path.get_file(),
		(director.call(&"ambience_player") as AudioStreamPlayer).stream.resource_path.get_file()]
	var tikbalang := scene.get(&"_tikbalang") as Node
	tikbalang.call(&"start_race")
	scene.call(&"_refresh_the_place_audio")
	var racing := _now_playing()
	# Off the line, then lost -- so it stays to race again: a race won answers it, and it steps off
	# the path for good. (Ended in its countdown, the countdown would still be running.)
	var off := await _until(func() -> bool: return bool(tikbalang.get(&"_racing")), 6.0)
	tikbalang.call(&"_end_race", false)
	scene.call(&"_refresh_the_place_audio")
	var won := _now_playing()
	_check(opened == "level_4/level_4" and files == "level_4.wav, level_4.wav" and racing == "level_4_race/level_4"
		and off and won == "level_4/level_4",
		"Dilim: its forest and night as it opens; the race's own music while the tikbalang races, the forest's after",
		"opened '%s' (%s), racing '%s', off the line %s, after it '%s'" % [opened, files, racing, off, won])
	tikbalang.call(&"start_race")
	scene.call(&"_refresh_the_place_audio")
	scene.call(&"_restore_checkpoint")
	scene.call(&"_refresh_the_place_audio")
	var restored := _now_playing()
	tikbalang.call(&"start_race")
	scene.call(&"_refresh_the_place_audio")
	var left_from := _now_playing()
	var player := director.call(&"music_player") as AudioStreamPlayer
	scene.queue_free()
	await _frames(5)
	var after := _now_playing()
	var stopped := await _until(func() -> bool: return not player.playing, FADE_WAIT_S)
	_check(restored == "level_4/level_4" and left_from == "level_4_race/level_4" and after == "/" and stopped,
		"Dilim: a restore mid-race puts the forest's music back, and leaving mid-race takes the race's",
		"restored '%s', left from '%s', after '%s', stopped %s" % [restored, left_from, after, stopped])
	director.call(&"stop_music", 0.0)
	director.call(&"stop_ambience", 0.0)


## Dilim's night: its first arrangement as the night begins, each wave the next at the same place
## in the bar, and at dawn nothing -- stopped in that frame, beside the dawn's own sound. A retried
## night (DilimFinale2D.reset_for_restore) goes back to the forest's music. Through the finale's
## own clock (its elapsed time and _open_waves) and the level's own _on_dawn.
var _dawn_heard_at := -1


func _dilims_night_builds_wave_by_wave_and_breaks_off_at_dawn() -> void:
	director.call(&"play_music", &"menu", 0.0)
	var scene := await _open("res://level_4.tscn")
	scene.set_physics_process(false)
	var finale := scene.get(&"_finale") as Node
	finale.call(&"_begin")
	scene.call(&"_refresh_the_place_audio")
	var began := String(director.call(&"current_music"))
	var heard: Array[String] = []
	var apart: Array[String] = []
	for wave: int in [1, 2]:
		var before := director.call(&"music_player") as AudioStreamPlayer
		before.seek(SOUGHT_S + wave)
		await _frames(2)
		finale.set(&"elapsed", float((finale.get(&"WAVES") as Array)[wave]["at"]))
		finale.call(&"_open_waves")
		scene.call(&"_refresh_the_place_audio")
		var after := director.call(&"music_player") as AudioStreamPlayer
		heard.append(String(director.call(&"current_music")))
		apart.append("%.3f" % absf(after.get_playback_position() - before.get_playback_position()))
	_check(began == "dilim_night_1" and heard == ["dilim_night_2", "dilim_night_3"]
		and apart.all(func(s: String) -> bool: return float(s) < SAME_PLACE_S),
		"Dilim's night: the first arrangement as it begins, each wave the next at the same place in the bar",
		"began '%s', then %s, apart %s s" % [began, heard, apart])
	var last := director.call(&"music_player") as AudioStreamPlayer
	_dawn_heard_at = -1
	var listen := func(id: StringName, _loudness: float) -> void:
		if id == &"dawn":
			_dawn_heard_at = Engine.get_process_frames()
	director.connect(&"sfx_requested", listen)
	var frame := Engine.get_process_frames()
	scene.call(&"_on_dawn")
	var at_dawn := String(director.call(&"current_music"))
	var cut := not last.playing
	director.disconnect(&"sfx_requested", listen)
	_check(at_dawn == "" and cut and _dawn_heard_at == frame,
		"Dilim's night breaks off at dawn in the frame the dawn's sound plays",
		"music '%s', stopped at once %s, dawn heard in that frame %s" % [at_dawn, cut, _dawn_heard_at == frame])
	scene.queue_free()
	await _frames(5)
	scene = await _open("res://level_4.tscn")
	scene.set_physics_process(false)
	finale = scene.get(&"_finale") as Node
	finale.call(&"_begin")
	scene.call(&"_refresh_the_place_audio")
	var night := String(director.call(&"current_music"))
	finale.call(&"reset_for_restore")
	scene.call(&"_refresh_the_place_audio")
	var retried := String(director.call(&"current_music"))
	scene.queue_free()
	await _frames(5)
	_check(night == "dilim_night_1" and retried == "level_4",
		"a retried night goes back to the forest's music until it begins again",
		"night '%s', retried '%s'" % [night, retried])
	director.call(&"stop_music", 0.0)
	director.call(&"stop_ambience", 0.0)


## Mayon: the ascent plays her worn motif as it opens; the memory lane plays each earlier level's
## memory by the vignette she is in, crossfading slowly; the music stops in the frame Lolo
## vanishes; Lola's kundiman when the summit opens, the ending's from the bloom, and nothing again
## below the summit with him gone. A memory saved is heard as its line is shown. Through the
## level's own state and handlers, with its physics off.
var _brush_heard := false


func _mayon_climbs_remembers_and_finds_her() -> void:
	director.call(&"play_music", &"menu", 0.0)
	var scene := await _open("res://level_5.tscn")
	scene.set_physics_process(false)
	var ascent := String(director.call(&"current_music"))
	var file := (director.call(&"music_player") as AudioStreamPlayer).stream.resource_path.get_file()
	_check(ascent == "level_5" and file == "level_5.wav", "Mayon's ascent plays her motif, worn thin",
		"opened '%s' (%s)" % [ascent, file])
	scene.set(&"_phase", "memories")
	var lane: Array[String] = []
	var slow := true
	for vignette: String in ["payyo_terraces", "piyesta_plaza", "dagat_sea", "dilim_forest"]:
		var before := director.call(&"music_player") as AudioStreamPlayer
		scene.set(&"_active_cluster", vignette)
		scene.call(&"_refresh_the_place_audio")
		lane.append(String(director.call(&"current_music")))
		await create_timer(1.0).timeout
		# A second in, a 2 s crossfade still has the last memory sounding under the new one.
		slow = slow and before.playing and before.volume_db > -40.0
	_check(lane == ["memory_terraces", "memory_piyesta", "memory_dagat", "memory_dilim"] and slow,
		"the memory lane plays each level's memory by its vignette, crossfading slowly",
		"%s, still crossing a second in %s" % [lane, slow])
	var last := director.call(&"music_player") as AudioStreamPlayer
	scene.call(&"_vanish_lolo")
	var gone := String(director.call(&"current_music"))
	_check(gone == "" and not last.playing, "the music stops in the frame Lolo vanishes",
		"music '%s', still sounding %s" % [gone, last.playing])
	scene.set(&"_summit", "quiet")
	scene.call(&"_refresh_the_place_audio")
	var found := String(director.call(&"current_music"))
	scene.set(&"_summit", "blooming")
	scene.call(&"_refresh_the_place_audio")
	var bloom := String(director.call(&"current_music"))
	scene.set(&"_summit", "lowering")
	scene.call(&"_reset_summit")
	scene.call(&"_refresh_the_place_audio")
	var below := String(director.call(&"current_music"))
	_check(found == "lola" and bloom == "mayon_ending" and below == "",
		"the summit plays Lola's music when she is found, the ending's from the bloom; below it again, nothing",
		"found '%s', bloom '%s', back below '%s'" % [found, bloom, below])
	scene.queue_free()
	await _frames(5)
	scene = await _open("res://level_5.tscn")
	_brush_heard = false
	var listen := func(id: StringName, _loudness: float) -> void:
		if id == &"mayon_brush":
			_brush_heard = true
	director.connect(&"sfx_requested", listen)
	var fragments := scene.get(&"_fragments") as Array
	var fragment_id := String((fragments[0] as Node).get(&"fragment_id")) if not fragments.is_empty() else ""
	scene.call(&"_on_fragment_saved", fragment_id)
	var label := scene.get(&"status_label") as Label
	var shown := label != null and label.visible and not label.text.is_empty()
	director.disconnect(&"sfx_requested", listen)
	scene.queue_free()
	await _frames(5)
	_check(not fragment_id.is_empty() and _brush_heard and shown,
		"a memory saved is heard (mayon_brush) as its saved line is shown",
		"fragment '%s', heard %s, line shown %s" % [fragment_id, _brush_heard, shown])
	director.call(&"stop_music", 0.0)
	director.call(&"stop_ambience", 0.0)


## The level-complete jingle lowers the music and ambience for its own length and brings them back,
## on the Music bus: the music player's own level (a fade's) is left alone.
func _the_jingle_lowers_the_music_for_its_own_length() -> void:
	director.call(&"play_music", &"menu", 0.0)
	var track := director.call(&"music_player") as AudioStreamPlayer
	director.call(&"play_sfx", &"level_complete")
	var jingle := (load(String((director.get(&"_sfx_paths") as Dictionary)["level_complete"])) as AudioStream).get_length()
	await create_timer(0.5).timeout
	var under := float(director.call(&"music_duck_db"))
	var still := float(director.call(&"music_duck_db"))
	await create_timer(maxf(0.0, jingle - 0.9)).timeout
	still = float(director.call(&"music_duck_db"))
	await create_timer(1.5).timeout
	var back := float(director.call(&"music_duck_db"))
	_check(under < -10.0 and still < -10.0 and absf(back) < 0.1 and absf(track.volume_db) < 0.1 and track.playing,
		"the level-complete jingle lowers the music for its own length (%.1f s), then brings it back" % jingle,
		"%.1f dB under it, %.1f dB near its end, %.1f dB after; the track's own level %.1f dB"
		% [under, still, back, track.volume_db])
	director.call(&"stop_music", 0.0)


## The run's ending screen plays the ending's music.
func _the_ending_screen_plays_the_ending() -> void:
	director.call(&"stop_music", 0.0)
	var screen := (load("res://ui/ending_screen.tscn") as PackedScene).instantiate()
	root.add_child(screen)
	await _frames(3)
	var playing := String(director.call(&"current_music"))
	screen.queue_free()
	await _frames(3)
	_check(playing == "mayon_ending", "the ending screen plays Mayon's ending", "playing '%s'" % playing)
	director.call(&"stop_music", 0.0)


## Mayon's ending goes home with her: from the bloom's music, _play_own_ending takes her to the
## house, and the house after the run plays the same track on, unrestarted -- the same player,
## still sounding, still Mayon's ending.
func _the_ending_goes_home_with_her() -> void:
	var profile := root.get_node(^"PlayerProfile")
	profile.call(&"mark_level_completed", "level_5")
	var scene := await _open("res://level_5.tscn")
	scene.set_physics_process(false)
	director.call(&"play_music", &"mayon_ending", 0.0)
	var bloom := director.call(&"music_player") as AudioStreamPlayer
	scene.call(&"_play_own_ending")
	var home := await _until(func() -> bool:
		return current_scene != null and current_scene.scene_file_path.ends_with("hub.tscn"), 20.0)
	await _frames(10)
	var playing := String(director.call(&"current_music"))
	var same: bool = director.call(&"music_player") == bloom and bloom.playing and absf(bloom.volume_db) < 0.1
	if is_instance_valid(scene):
		scene.queue_free()
	_check(home and playing == "mayon_ending" and same,
		"Mayon's ending goes home with her, unrestarted, and is the house's music after the run",
		"home %s, playing '%s', the same track sounding on %s" % [home, playing, same])
	director.call(&"stop_music", 0.0)
	profile.call(&"reset_progress")


## "music/ambience", what AudioDirector is playing now.
func _now_playing() -> String:
	return "%s/%s" % [director.call(&"current_music"), director.call(&"current_ambience")]


func _open(path: String) -> Node:
	var scene := (load(path) as PackedScene).instantiate()
	(scene.get_node("BackendSupervisor") as BackendSupervisor).auto_start_backend = false
	root.add_child(scene)
	call_group(DialogueBox.GROUP, &"set_auto_dismiss", true)
	await _frames(20)
	return scene


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


func _loudest(samples: PackedFloat32Array) -> float:
	var top := 0.0
	for sample in samples:
		top = maxf(top, absf(sample))
	return top


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
