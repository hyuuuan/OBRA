extends ModalOverlay
## Volume and display settings, shared by the main menu and the pause menu.
##
## Applying and persisting are deliberately separate. A dragged slider emits
## value_changed once per pixel and PlayerProfile.set_setting writes the whole profile
## atomically, so the slider applies live through AudioDirector -- which the player
## hears immediately -- and only commits when the drag ends or the screen closes.
## Dragging a slider across its track is one disk write, not two hundred.

const SETTING_FOR_BUS := {
	"master_volume": AudioDirector.BUS_MASTER,
	"music_volume": AudioDirector.BUS_MUSIC,
	"sfx_volume": AudioDirector.BUS_SFX,
}

@onready var _sliders: Dictionary = {
	"master_volume": $Root/Panel/VBox/MasterRow/Slider,
	"music_volume": $Root/Panel/VBox/MusicRow/Slider,
	"sfx_volume": $Root/Panel/VBox/SfxRow/Slider,
}
@onready var _readouts: Dictionary = {
	"master_volume": $Root/Panel/VBox/MasterRow/Value,
	"music_volume": $Root/Panel/VBox/MusicRow/Value,
	"sfx_volume": $Root/Panel/VBox/SfxRow/Value,
}
@onready var _fullscreen: CheckButton = $Root/Panel/VBox/FullscreenToggle
@onready var _back_button: Button = $Root/Panel/VBox/BackButton

var _profile: Node = null
var _director: Node = null


func _ready() -> void:
	super()
	_profile = get_node_or_null(^"/root/PlayerProfile")
	_director = get_node_or_null(^"/root/AudioDirector")
	for key: Variant in _sliders.keys():
		var slider: HSlider = _sliders[key]
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value_changed.connect(_on_slider_changed.bind(String(key)))
		slider.drag_ended.connect(_on_drag_ended.bind(String(key)))
	_fullscreen.toggled.connect(_on_fullscreen_toggled)
	_back_button.pressed.connect(close)
	_pull_from_profile()
	_apply_fullscreen(bool(_setting("fullscreen", false)))


func _on_opened() -> void:
	# Re-read on every open: the other instance of this screen may have changed
	# something since, and both write to the same profile.
	_pull_from_profile()


func _on_closed() -> void:
	# Commit whatever the sliders ended on, in case the screen was closed mid-drag.
	_persist_all()


## Live only. The player hears this immediately; the disk write waits for drag_ended.
func _on_slider_changed(value: float, key: String) -> void:
	_readouts[key].text = "%d%%" % int(round(value * 100.0))
	if _director != null and SETTING_FOR_BUS.has(key):
		_director.set_bus_linear(SETTING_FOR_BUS[key], value)


func _on_drag_ended(changed: bool, key: String) -> void:
	if changed:
		_persist(key, float((_sliders[key] as HSlider).value))


func _on_fullscreen_toggled(pressed: bool) -> void:
	_apply_fullscreen(pressed)
	_persist("fullscreen", pressed)


## Skipped under the headless display server, which has no window to resize and logs
## an error per call. The setting is still read, stored and shown -- only the display
## change is inapplicable -- so the headless suite exercises everything except the
## one line it cannot.
func _apply_fullscreen(enabled: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _pull_from_profile() -> void:
	for key: Variant in _sliders.keys():
		var value := float(_setting(String(key), 1.0))
		var slider: HSlider = _sliders[key]
		# set_value_no_signal, or seeding the UI would re-apply and re-persist a value
		# that came from the profile in the first place.
		slider.set_value_no_signal(value)
		_readouts[key].text = "%d%%" % int(round(value * 100.0))
	_fullscreen.set_pressed_no_signal(bool(_setting("fullscreen", false)))


func _persist_all() -> void:
	for key: Variant in _sliders.keys():
		_persist(String(key), float((_sliders[key] as HSlider).value))
	_persist("fullscreen", _fullscreen.button_pressed)


func _persist(key: String, value: Variant) -> void:
	if _profile != null:
		_profile.set_setting(key, value)


func _setting(key: String, fallback: Variant) -> Variant:
	if _profile == null:
		return fallback
	var value: Variant = _profile.get_setting(key)
	return fallback if value == null else value
