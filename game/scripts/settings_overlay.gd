extends ModalOverlay
## Display and motion settings, shared by the main menu and the pause menu. "Reduce motion" keeps
## every slide, pop and shake in the game still, a short fade in their place (motion.gd).
##
## ⚠ NO VOLUME SLIDERS (Kent, 2026-10-20: "remove the sound/music in settings since its not
## implemented yet"). The game has no sound yet -- every id in config/audio.json is empty -- so the
## Master, Music and Sound effects sliders moved nothing anyone could hear. The profile still keeps
## the three volumes and AudioDirector still applies them at boot, so when sound arrives the rows go
## back into ui/settings_overlay.tscn and their slider code back in here (git has both).

@onready var _fullscreen: CheckButton = $Root/Center/Panel/VBox/FullscreenToggle
@onready var _reduce_motion: CheckButton = $Root/Center/Panel/VBox/ReduceMotionToggle
@onready var _back_button: Button = $Root/Center/Panel/VBox/BackButton

var _profile: Node = null


func _ready() -> void:
	super()
	_profile = get_node_or_null(^"/root/PlayerProfile")
	_skin_controls()
	_fullscreen.toggled.connect(_on_fullscreen_toggled)
	_reduce_motion.toggled.connect(func(pressed: bool) -> void: _persist("reduce_motion", pressed))
	_back_button.pressed.connect(close)
	_pull_from_profile()
	_apply_fullscreen(bool(_setting("fullscreen", false)))


## The one control on this screen that Godot draws from a TEXTURE rather than a StyleBox: a
## CheckButton's two states. Built here at load instead of living in the theme, because an
## ImageTexture saved into a .tres keeps its header and loses its pixels -- the file would load
## with an invisible switch and nothing to say why.
func _skin_controls() -> void:
	for toggle: CheckButton in [_fullscreen, _reduce_motion]:
		toggle.add_theme_icon_override(&"checked", UISkin.switch_texture(true))
		toggle.add_theme_icon_override(&"unchecked", UISkin.switch_texture(false))
		toggle.add_theme_icon_override(&"checked_disabled", UISkin.switch_texture(true))
		toggle.add_theme_icon_override(&"unchecked_disabled", UISkin.switch_texture(false))


func _on_opened() -> void:
	# Re-read on every open: the other instance of this screen may have changed
	# something since, and both write to the same profile.
	_pull_from_profile()


func _on_closed() -> void:
	_persist("fullscreen", _fullscreen.button_pressed)
	_persist("reduce_motion", _reduce_motion.button_pressed)


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
		DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_MAXIMIZED
	)


func _pull_from_profile() -> void:
	_fullscreen.set_pressed_no_signal(bool(_setting("fullscreen", false)))
	_reduce_motion.set_pressed_no_signal(bool(_setting("reduce_motion", false)))


func _persist(key: String, value: Variant) -> void:
	if _profile != null:
		_profile.set_setting(key, value)


func _setting(key: String, fallback: Variant) -> Variant:
	if _profile == null:
		return fallback
	var value: Variant = _profile.get_setting(key)
	return fallback if value == null else value
