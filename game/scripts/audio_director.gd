extends Node
## The single owner of audio: bus volumes, and playing a sound by id.
##
## There are no sound files in the project yet, and this is built so that stays a
## content gap rather than a code one. Ids live in config/audio.json with empty
## paths; play_sfx and play_music resolve an id to nothing and return. Every call
## site can therefore be written now, and dropping an .ogg in beside its id makes it
## audible with no code change anywhere.
##
## Volumes are held LINEAR (0..1) because that is what a slider shows and what the
## profile stores. dB is derived here and never persisted -- linear_to_db(0.0) is
## -inf, a value that must never reach AudioServer or a save file.

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

var _sfx_paths: Dictionary = {}
var _music_paths: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer = null
var _next_voice: int = 0
var _music_id: StringName = &""


func _ready() -> void:
	# Audio must keep working while the tree is paused, or every menu this feeds is
	# silent at exactly the moment it is being used.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_catalog()
	_build_players()
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


## Play a one-shot by id. An id with no file behind it is silence, not an error --
## that is what lets the call sites exist before the sounds do.
func play_sfx(id: StringName) -> void:
	var stream := _stream_for(_sfx_paths, id)
	if stream == null or _sfx_players.is_empty():
		return
	var player := _sfx_players[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx_players.size()
	player.stream = stream
	player.play()


## Start a music track, ignoring a request for whatever is already playing so a
## scene rebuild does not restart the score.
func play_music(id: StringName) -> void:
	if _music_player == null or id == _music_id:
		return
	var stream := _stream_for(_music_paths, id)
	if stream == null:
		return
	_music_id = id
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	if _music_player == null:
		return
	_music_id = &""
	_music_player.stop()


# --- internals ---------------------------------------------------------------

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
	_music_paths = _resolved_section(document.get("music", {}))


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


func _build_players() -> void:
	for i in range(SFX_VOICES):
		var player := AudioStreamPlayer.new()
		player.name = "SfxVoice%d" % i
		player.bus = BUS_SFX
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_sfx_players.append(player)
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = BUS_MUSIC
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)
