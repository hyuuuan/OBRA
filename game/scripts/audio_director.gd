extends Node
## The single owner of audio: bus volumes, and playing a sound by id.
##
## Ids live in config/audio.json. An id whose path is empty resolves to nothing and returns, so a
## call site can be written before its sound exists; the files are rendered from FamiTracker
## modules (audio/README.md) and named beside their ids, with no code change anywhere.
##
## Music, and the ambience bed under it, each loop on a PAIR of players, so a change of track is a
## crossfade rather than a cut: the outgoing fades out on one while the incoming fades in on the
## other. One-shots share SFX_VOICES players, and an id may be spaced (audio.json `spacing`) so a
## sound made constantly -- a footstep -- cannot take every voice from the ones that carry
## information.
##
## Volumes are held LINEAR (0..1) because that is what a slider shows and what the
## profile stores. dB is derived here and never persisted -- linear_to_db(0.0) is
## -inf, a value that must never reach AudioServer or a save file.

## Every play_sfx, with or without a file behind it: the id and the loudness asked for.
signal sfx_requested(id: StringName, loudness: float)

const CATALOG_PATH := "res://config/audio.json"

const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"

## Which profile setting drives which bus.
const BUS_FOR_SETTING := {
	"master_volume": BUS_MASTER,
	"music_volume": BUS_MUSIC,
	"sfx_volume": BUS_SFX,
}

## Below this, mute the bus outright instead of pushing the volume toward -inf dB.
const SILENCE_LINEAR := 0.001

## Simultaneous one-shot sounds. Beyond this the oldest is reused, so a burst of UI
## clicks can never grow the node count without bound.
const SFX_VOICES := 8

## How long a change of music or ambience takes, out and in at once.
const LOOP_FADE_S := 0.6
## A fade's floor. linear_to_db(0) is -inf, which must never reach a player.
const FADE_FLOOR := 0.001

## A one-shot listed in audio.json `duck` lowers the music and the ambience under it for its own
## length -- the level-complete jingle over the level's loop -- then brings them back. On the Music
## bus, through an Amplify effect of its own, so it touches neither the player's slider (the bus
## volume) nor a crossfade in progress (the players' volumes).
const DUCK_DB := -12.0
const DUCK_DOWN_S := 0.12
const DUCK_UP_S := 0.6


## A looping channel -- the music, or the ambience under it -- on a pair of players.
class _Loop:
	var players: Array[AudioStreamPlayer] = []
	## Which of the pair carries the current track.
	var active: int = 0
	var id: StringName = &""
	var paths: Dictionary = {}
	## player -> the Tween fading it, so a new fade replaces an old one instead of fighting it.
	var fades: Dictionary = {}


var _sfx_paths: Dictionary = {}
## id -> the least time, in seconds, between two plays of it.
var _sfx_spacing: Dictionary = {}
## id -> Time.get_ticks_msec() of its last play.
var _sfx_last_ms: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _music := _Loop.new()
var _ambience := _Loop.new()
## The ids that duck the music (audio.json `duck`), and the effect and tween that do it.
var _sfx_duck: Dictionary = {}
var _duck: AudioEffectAmplify
var _duck_tween: Tween


func _ready() -> void:
	# Audio must keep working while the tree is paused, or every menu this feeds is
	# silent at exactly the moment it is being used.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_catalog()
	_build_players()
	_build_duck()
	var profile := get_node_or_null(^"/root/PlayerProfile")
	if profile != null:
		profile.settings_changed.connect(_on_setting_changed)
	apply_saved_settings()
	# Every button in the game, including the ones built at runtime -- the six inventory
	# slots and the three answers to Lolo's question are made in code, so connecting at
	# each authored call site would have missed exactly the buttons a player presses most.
	get_tree().node_added.connect(_on_node_added)


## `ui_click` was defined in the catalogue and called from nowhere, so no button in the
## game made a sound. Silence plus no press animation beyond the theme's stylebox is a
## large part of why the UI was reported as not responding at all.
func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button == null or button.pressed.is_connected(_on_any_button_pressed):
		return
	button.pressed.connect(_on_any_button_pressed)


func _on_any_button_pressed() -> void:
	play_sfx(&"ui_click")


## Push every saved volume onto its bus. Called on launch, so the player's choice is
## in effect before anything can be heard rather than after the first slider move.
func apply_saved_settings() -> void:
	var profile := get_node_or_null(^"/root/PlayerProfile")
	if profile == null:
		return
	for setting_key: Variant in BUS_FOR_SETTING.keys():
		var value: Variant = profile.get_setting(String(setting_key))
		if value != null:
			set_bus_linear(BUS_FOR_SETTING[setting_key], float(value))


## Set a bus from a linear 0..1 level. Out-of-range input is clamped rather than
## refused: this is reached from a save file as well as from a slider.
func set_bus_linear(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		# A stripped bus layout must leave the game playable and silent, not broken.
		push_warning("AudioDirector: no '%s' bus; volume ignored" % bus)
		return
	var level := clampf(linear, 0.0, 1.0)
	if level <= SILENCE_LINEAR:
		AudioServer.set_bus_mute(index, true)
		return
	AudioServer.set_bus_mute(index, false)
	AudioServer.set_bus_volume_db(index, linear_to_db(level))


## The bus's level back as linear 0..1, with a muted bus reading as zero.
func bus_linear(bus: StringName) -> float:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return 0.0
	if AudioServer.is_bus_mute(index):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(index)), 0.0, 1.0)


## Play a one-shot by id, at `loudness` 0..1 of the SFX bus (a call the level means quieter or
## louder -- the tik-tik's call, louder the further off it is). An id with no file behind it is
## silence, not an error -- that is what lets the call sites exist before the sounds do -- but
## the request is still announced (`sfx_requested`), so a probe can hear what would have played.
## Nothing at or under zero is played: linear_to_db(0) is -inf. Returns whether it sounded: an id
## asked for again inside its `spacing` is announced and not played.
func play_sfx(id: StringName, loudness: float = 1.0) -> bool:
	var level := clampf(loudness, 0.0, 1.0)
	sfx_requested.emit(id, level)
	var stream := _stream_for(_sfx_paths, id)
	if stream == null or _sfx_players.is_empty() or level <= 0.0:
		return false
	var now := Time.get_ticks_msec()
	var key := String(id)
	if _sfx_last_ms.has(key) and now - int(_sfx_last_ms[key]) < float(_sfx_spacing.get(key, 0.0)) * 1000.0:
		return false
	_sfx_last_ms[key] = now
	var player := _sfx_players[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx_players.size()
	player.stream = stream
	player.volume_db = linear_to_db(level)
	player.play()
	if _sfx_duck.has(key):
		duck_music(stream.get_length())
	return true


## Lower the music and ambience for `seconds`, then bring them back. A second duck while one runs
## starts again from where the first had got to.
func duck_music(seconds: float) -> void:
	if _duck == null:
		return
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	# ⚠ PAUSE_PROCESS: the level-complete panel pauses the tree as the jingle starts.
	_duck_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_duck_tween.tween_property(_duck, "volume_db", DUCK_DB, DUCK_DOWN_S)
	_duck_tween.tween_interval(maxf(0.0, seconds - DUCK_DOWN_S))
	_duck_tween.tween_property(_duck, "volume_db", 0.0, DUCK_UP_S)


## How far the music is ducked now, in dB (0 when it is not). For probes.
func music_duck_db() -> float:
	return _duck.volume_db if _duck != null else 0.0


## Start a music track, crossfading from whatever played before. A request for the track already
## playing is ignored, so a scene rebuild does not restart the score.
##
## `keep_position`: the incoming track starts where the outgoing one is, not at its top. It is for
## two ARRANGEMENTS OF ONE PIECE trading places mid-bar -- Dagat's surface and its deep, the
## night's three waves -- so a dive or a new wave sounds like the same music changing, not a new
## song starting. ⚠ They only line up if both are written to the same length TO THE ROW: the same
## frames, rows and per-row speeds in famitext, so every bar falls at the same second in both.
func play_music(id: StringName, fade: float = LOOP_FADE_S, keep_position: bool = false) -> void:
	_loop_play(_music, id, fade, keep_position)


## The id of the track playing, or &"" when none is.
func current_music() -> StringName:
	return _music.id


## Fade the music out. current_music() is &"" at once; the player stops when the fade ends.
func stop_music(fade: float = LOOP_FADE_S) -> void:
	_loop_stop(_music, fade)


## The player carrying the current (or last) music track. For probes.
func music_player() -> AudioStreamPlayer:
	return _music.players[_music.active] if not _music.players.is_empty() else null


## The ambience bed under the music (audio.json `ambience`): the same crossfade, its own pair.
func play_ambience(id: StringName, fade: float = LOOP_FADE_S) -> void:
	_loop_play(_ambience, id, fade)


func current_ambience() -> StringName:
	return _ambience.id


func stop_ambience(fade: float = LOOP_FADE_S) -> void:
	_loop_stop(_ambience, fade)


func ambience_player() -> AudioStreamPlayer:
	return _ambience.players[_ambience.active] if not _ambience.players.is_empty() else null


# --- internals ---------------------------------------------------------------

func _loop_play(loop: _Loop, id: StringName, fade: float, keep_position := false) -> void:
	if loop.players.is_empty() or id == loop.id:
		return
	var stream := _stream_for(loop.paths, id)
	if stream == null:
		return
	loop.id = id
	var outgoing := loop.players[loop.active]
	# Read before the fade: a fade to nothing in no time stops the player, and a stopped one
	# reads 0. Past the incoming file's end means the two were not written alike: start at the top.
	var at := outgoing.get_playback_position() if keep_position and outgoing.playing else 0.0
	if at >= stream.get_length():
		at = 0.0
	_fade(loop, outgoing, 0.0, fade)
	loop.active = 1 - loop.active
	var incoming := loop.players[loop.active]
	_kill_fade(loop, incoming)
	incoming.stream = stream
	incoming.volume_db = linear_to_db(FADE_FLOOR) if fade > 0.0 else 0.0
	incoming.play(at)
	_fade(loop, incoming, 1.0, fade)


func _loop_stop(loop: _Loop, fade: float) -> void:
	loop.id = &""
	for player in loop.players:
		_fade(loop, player, 0.0, fade)


## Take `player` to `level` (linear) over `seconds`, and stop it there if that is silence.
## ⚠ PAUSE_PROCESS: the menus that pause the tree are where a fade most often happens, and a
## tween that pauses with the tree would hold the old track at half volume under them.
func _fade(loop: _Loop, player: AudioStreamPlayer, level: float, seconds: float) -> void:
	_kill_fade(loop, player)
	if not player.playing:
		return
	if seconds <= 0.0:
		if level <= 0.0:
			player.stop()
		else:
			player.volume_db = linear_to_db(level)
		return
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	loop.fades[player] = tween
	tween.tween_method(_set_along.bind(player, db_to_linear(player.volume_db), maxf(level, FADE_FLOOR)),
		0.0, 1.0, seconds)
	if level <= 0.0:
		tween.tween_callback(player.stop)


func _kill_fade(loop: _Loop, player: AudioStreamPlayer) -> void:
	var running: Tween = loop.fades.get(player)
	if running != null and running.is_valid():
		running.kill()
	loop.fades.erase(player)


## A fade's level at `progress` (0..1) from `from` to `to`, linear amplitudes. ⚠ EQUAL POWER, on a
## quarter sine: rising as sin, falling as cos, so two tracks crossing hold their summed loudness. A
## straight line dips both to half (-6 dB each, -3 dB together) at the middle, which is heard as
## the music sagging between two places.
func _set_along(progress: float, player: AudioStreamPlayer, from: float, to: float) -> void:
	var shaped := sin(progress * PI * 0.5) if to > from else 1.0 - cos(progress * PI * 0.5)
	player.volume_db = linear_to_db(maxf(from + (to - from) * shaped, FADE_FLOOR))


func _on_setting_changed(key: String, value: Variant) -> void:
	if BUS_FOR_SETTING.has(key):
		set_bus_linear(BUS_FOR_SETTING[key], float(value))


## Resolve an id to a stream, warning once per id rather than once per play -- a
## missing footstep must not be able to fill the log.
func _stream_for(paths: Dictionary, id: StringName) -> AudioStream:
	var key := String(id)
	if not paths.has(key):
		return null
	var path := String(paths[key])
	if path.is_empty():
		return null
	var resource: Variant = ResourceLoader.load(path)
	if resource is AudioStream:
		return resource as AudioStream
	push_warning("AudioDirector: '%s' -> '%s' is not an audio stream" % [key, path])
	paths[key] = ""  # stop retrying a path that will not resolve
	return null


func _load_catalog() -> void:
	var text := FileAccess.get_file_as_string(CATALOG_PATH)
	if text.is_empty():
		push_warning("AudioDirector: could not read %s" % CATALOG_PATH)
		return
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("AudioDirector: %s is not a JSON object" % CATALOG_PATH)
		return
	var document := parsed as Dictionary
	_sfx_paths = _resolved_section(document.get("sfx", {}))
	_music.paths = _resolved_section(document.get("music", {}))
	_ambience.paths = _resolved_section(document.get("ambience", {}))
	var ducking: Variant = document.get("duck", [])
	if ducking is Array:
		for id: Variant in ducking:
			_sfx_duck[String(id)] = true
	var spacing: Variant = document.get("spacing", {})
	if spacing is Dictionary:
		for key: Variant in (spacing as Dictionary).keys():
			var seconds: Variant = (spacing as Dictionary)[key]
			if (seconds is float or seconds is int) and float(seconds) > 0.0:
				_sfx_spacing[String(key)] = float(seconds)


## Drop paths that do not exist, once, at load. An id whose file is missing behaves
## exactly like an id whose path is still blank.
func _resolved_section(section: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (section is Dictionary):
		return out
	for key: Variant in (section as Dictionary).keys():
		var path := String((section as Dictionary)[key])
		if not path.is_empty() and not ResourceLoader.exists(path):
			push_warning("AudioDirector: '%s' points at a missing file (%s)" % [key, path])
			path = ""
		out[String(key)] = path
	return out


func _build_duck() -> void:
	var bus := AudioServer.get_bus_index(BUS_MUSIC)
	if bus < 0:
		return
	_duck = AudioEffectAmplify.new()
	_duck.volume_db = 0.0
	AudioServer.add_bus_effect(bus, _duck)


func _build_players() -> void:
	for i in range(SFX_VOICES):
		var player := AudioStreamPlayer.new()
		player.name = "SfxVoice%d" % i
		player.bus = BUS_SFX
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_sfx_players.append(player)
	# The ambience is background, like the music, and carries nothing a player must hear, so it
	# follows the Music slider rather than the Sound effects one.
	for pair: Array in [[_music, "Music"], [_ambience, "Ambience"]]:
		var loop: _Loop = pair[0]
		for side in ["A", "B"]:
			var player := AudioStreamPlayer.new()
			player.name = "%s%s" % [pair[1], side]
			player.bus = BUS_MUSIC
			player.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(player)
			loop.players.append(player)
