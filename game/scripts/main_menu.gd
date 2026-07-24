extends Node2D

const PANEL_SNAP := 8.0

@onready var backdrop: Control = $Backdrop
@onready var sky: TextureRect = $Backdrop/Sky
@onready var far_mountains: TextureRect = $Backdrop/FarMountains
@onready var green_mountains: TextureRect = $Backdrop/GreenMountains
@onready var terraces: TextureRect = $Backdrop/Terraces
@onready var morph_panel: PanelContainer = $MenuLayer/MenuRoot/MorphPanel
@onready var play_button: Button = $MenuLayer/MenuRoot/MorphPanel/PlayButton
@onready var selector: Control = $MenuLayer/MenuRoot/MorphPanel/Selector
@onready var selector_title: Label = $MenuLayer/MenuRoot/MorphPanel/Selector/SelectorTitle
@onready var cards: Array[Button] = [
	$MenuLayer/MenuRoot/MorphPanel/Selector/Level1,
	$MenuLayer/MenuRoot/MorphPanel/Selector/Level2,
	$MenuLayer/MenuRoot/MorphPanel/Selector/Level3,
	$MenuLayer/MenuRoot/MorphPanel/Selector/Level4,
	$MenuLayer/MenuRoot/MorphPanel/Selector/Level5,
]

var _selector_open := false
var _animating := false
var _panel_tween: Tween
var _parallax_target := Vector2.ZERO
var _sky_base := Vector2.ZERO
var _far_base := Vector2.ZERO
var _green_base := Vector2.ZERO
var _terraces_base := Vector2.ZERO
var _backdrop_bases_ready := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	play_button.pressed.connect(_show_selector)
	for index in range(cards.size()):
		var level_id := "level_%d" % (index + 1)
		cards[index].pressed.connect(_open_level.bind(level_id))
	_refresh_cards()
	selector.visible = false
	play_button.visible = true
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_apply_current_layout()
	_capture_backdrop_bases.call_deferred()
	if LevelManager.consume_selector_request():
		_show_selector.call_deferred()
	else:
		play_button.grab_focus()


func _process(delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	if not _backdrop_bases_ready:
		return
	var mouse_offset := get_viewport().get_mouse_position() - viewport_size * 0.5
	_parallax_target = mouse_offset / viewport_size
	var weight := 1.0 - exp(-4.0 * delta)
	sky.position = sky.position.lerp(_sky_base + _parallax_target * -4.0, weight)
	far_mountains.position = far_mountains.position.lerp(_far_base + _parallax_target * -10.0, weight)
	green_mountains.position = green_mountains.position.lerp(_green_base + _parallax_target * -18.0, weight)
	terraces.position = terraces.position.lerp(_terraces_base + _parallax_target * -28.0, weight)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _selector_open and not _animating:
		get_viewport().set_input_as_handled()
		_hide_selector()


func is_selector_open() -> bool:
	return _selector_open


func _show_selector() -> void:
	if _animating or _selector_open:
		return
	_animating = true
	_selector_open = true
	play_button.disabled = true
	var from_rect := morph_panel.get_rect()
	var to_rect := _selector_panel_rect()
	_start_panel_tween(from_rect, to_rect, true)


func _hide_selector() -> void:
	if _animating or not _selector_open:
		return
	_animating = true
	for card in cards:
		card.visible = false
	selector_title.visible = false
	var from_rect := morph_panel.get_rect()
	var to_rect := _play_panel_rect()
	_start_panel_tween(from_rect, to_rect, false)


func _start_panel_tween(from_rect: Rect2, to_rect: Rect2, opening: bool) -> void:
	if _panel_tween != null:
		_panel_tween.kill()
	_panel_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_panel_tween.tween_method(func(weight: float) -> void:
		_set_panel_rect(Rect2(
			from_rect.position.lerp(to_rect.position, weight),
			from_rect.size.lerp(to_rect.size, weight)
		))
	, 0.0, 1.0, 0.38)
	_panel_tween.tween_callback(func() -> void:
		_set_panel_rect(to_rect)
		if opening:
			_reveal_selector()
		else:
			selector.visible = false
			play_button.visible = true
			play_button.disabled = false
			play_button.grab_focus()
			_selector_open = false
			_animating = false
	)


func _reveal_selector() -> void:
	play_button.visible = false
	selector.visible = true
	selector_title.visible = true
	_layout_cards()
	_refresh_cards()
	for card in cards:
		card.visible = false
		card.modulate.a = 0.0
	var reveal := create_tween()
	for card in cards:
		reveal.tween_callback(func() -> void: card.visible = true)
		reveal.tween_property(card, "modulate:a", 1.0, 0.055)
	reveal.tween_callback(func() -> void:
		_animating = false
		cards[0].grab_focus()
	)


func _open_level(level_id: String) -> void:
	if _animating or LevelManager.is_transitioning():
		return
	if LevelManager.open_level(level_id):
		_animating = true


## Reflect the persisted profile in the level cards: lock levels the player has not
## reached yet, and tint completed ones.
func _refresh_cards() -> void:
	var profile := get_node_or_null(^"/root/PlayerProfile")
	for index in range(cards.size()):
		var level_id := "level_%d" % (index + 1)
		var card := cards[index]
		var unlocked := LevelManager.is_unlocked(level_id)
		card.disabled = not unlocked
		var completed: bool = profile != null and profile.is_level_completed(level_id)
		# Tint completed cards green while preserving the alpha the reveal tween drives.
		var rgb := Color(0.66, 0.94, 0.70) if completed else Color.WHITE
		card.modulate = Color(rgb.r, rgb.g, rgb.b, card.modulate.a)
		var entry := LevelManager.get_level(level_id)
		var title := String(entry.get("title", level_id))
		if not unlocked:
			card.tooltip_text = "%s — locked" % title
		elif completed:
			card.tooltip_text = "%s — completed" % title
		else:
			card.tooltip_text = title


func _apply_current_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		backdrop.position = Vector2.ZERO
		backdrop.size = viewport_size
	_set_panel_rect(_selector_panel_rect() if _selector_open else _play_panel_rect())
	if _selector_open:
		_layout_cards()


func _on_viewport_size_changed() -> void:
	_backdrop_bases_ready = false
	_apply_current_layout()
	_capture_backdrop_bases.call_deferred()


func _capture_backdrop_bases() -> void:
	_sky_base = sky.position
	_far_base = far_mountains.position
	_green_base = green_mountains.position
	_terraces_base = terraces.position
	_backdrop_bases_ready = true


func _play_panel_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	return Rect2(Vector2(viewport_size.x * 0.5 - 170.0, viewport_size.y - 190.0), Vector2(340.0, 84.0))


func _selector_panel_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	return Rect2(Vector2(90.0, 190.0), Vector2(viewport_size.x - 180.0, viewport_size.y - 260.0))


func _set_panel_rect(rect: Rect2) -> void:
	var snapped_position := Vector2(
		roundf(rect.position.x / PANEL_SNAP) * PANEL_SNAP,
		roundf(rect.position.y / PANEL_SNAP) * PANEL_SNAP
	)
	var snapped_size := Vector2(
		roundf(rect.size.x / PANEL_SNAP) * PANEL_SNAP,
		roundf(rect.size.y / PANEL_SNAP) * PANEL_SNAP
	)
	morph_panel.position = snapped_position
	morph_panel.size = snapped_size


func _layout_cards() -> void:
	var available_width := maxf(300.0, morph_panel.size.x - 64.0)
	var separation := 14.0
	var card_width := (available_width - separation * 4.0) / 5.0
	var base_y := 154.0
	for index in range(cards.size()):
		var card := cards[index]
		card.position = Vector2(32.0 + float(index) * (card_width + separation), base_y - float(index) * 18.0)
		card.size = Vector2(card_width, minf(300.0, morph_panel.size.y - card.position.y - 34.0))
