extends Node2D

const PANEL_SNAP := 8.0

## THE HOME SCREEN IS THE TITLE CARD (title_card.gd): Kent's vista -- the apo looking out over
## the place the game is set -- with the logo and "DRAW ◆ BECOME ◆ DISCOVER" over it, the same
## card the loading screen shows, so loading fades onto this without the picture moving and
## the PLAY button stands where the loading bar was. It replaces the backdrop that wore the
## last level the apo was in (October 2026); that table is in git history if it comes back.
const TITLE_CARD := preload("res://scripts/title_card.gd")

@onready var morph_panel: PanelContainer = $MenuLayer/MenuRoot/MorphPanel
@onready var play_button: Button = $MenuLayer/MenuRoot/MorphPanel/PlayButton
@onready var selector: Control = $MenuLayer/MenuRoot/MorphPanel/Selector
@onready var selector_title: Label = $MenuLayer/MenuRoot/MorphPanel/Selector/SelectorTitle
@onready var settings_button: Button = $MenuLayer/MenuRoot/SideButtons/SettingsButton
@onready var controls_button: Button = $MenuLayer/MenuRoot/SideButtons/ControlsButton
@onready var quit_button: Button = $MenuLayer/MenuRoot/SideButtons/QuitButton
@onready var side_buttons: Control = $MenuLayer/MenuRoot/SideButtons
## Built here rather than in the scene: it only exists when there is a save to throw away.
var new_game_button: Button
## Which question the shared confirm box is asking -- "quit" or "new_game" -- so one
## `confirmed` handler answers both and a cancelled one cannot fire the other later.
var _pending_confirm := ""
## The vista, the logo and the tagline, behind the buttons.
var _card: Control
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


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# PLAY opens the HOUSE, not a grid of cards. Levels are chosen by walking up to the
	# painting of one, which is the whole reason the house exists.
	_build_new_game_button()
	_refresh_start_buttons()
	play_button.pressed.connect(_on_play_pressed)
	_card = TITLE_CARD.new()
	_card.name = "TitleCard"
	_card.set("drifts", true)
	var menu_root := $MenuLayer/MenuRoot as Control
	menu_root.add_child(_card)
	menu_root.move_child(_card, 0)
	settings_button.pressed.connect(_open_overlay.bind(&"SettingsOverlay"))
	controls_button.pressed.connect(_open_overlay.bind(&"ControlsOverlay"))
	quit_button.pressed.connect(_ask_quit)
	for index in range(cards.size()):
		var level_id := "level_%d" % (index + 1)
		cards[index].pressed.connect(_open_level.bind(level_id))
	_refresh_cards()
	selector.visible = false
	play_button.visible = true
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_apply_current_layout()
	if LevelManager.consume_selector_request():
		_show_selector.call_deferred()
	else:
		play_button.grab_focus()


## The shared overlays are siblings of this node, instanced into the menu scene.
func _open_overlay(overlay_name: StringName) -> void:
	var overlay := get_node_or_null(NodePath(overlay_name)) as ModalOverlay
	if overlay != null:
		overlay.open()


func _ask_quit() -> void:
	var confirm := get_node_or_null(^"ConfirmOverlay")
	if confirm == null:
		return
	_pending_confirm = "quit"
	_connect_confirm(confirm)
	confirm.call(&"ask", "QUIT TO DESKTOP?", "Your progress is saved.", "QUIT")


func _quit_to_desktop() -> void:
	# The backend is a child process, not a node: quitting the tree does not take it
	# with us, and the one it leaves behind holds the port the next launch needs. Called
	# statically, because a screen with no level in it has no supervisor to receive a group
	# call -- which is how quitting from here left the server running.
	BackendSupervisor.stop_owned_backend()
	get_tree().quit()


## Called by UIRouter. The menu declines while the morph tween is running, so cancel
## cannot interrupt an animation halfway and leave the panel between its two rects.
func handle_cancel() -> bool:
	if not _selector_open or _animating:
		return false
	_hide_selector()
	return true


func is_selector_open() -> bool:
	return _selector_open


func _show_selector() -> void:
	if _animating or _selector_open:
		return
	_animating = true
	_selector_open = true
	play_button.disabled = true
	_show_side_buttons(false)
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
			_show_side_buttons(true)
			_selector_open = false
			_animating = false
	)


## ⚠ THE LEVEL PANEL GROWS DOWN OVER THE BUTTON ROW, AND DOES NOT QUITE COVER IT. The panel
## ends a few units into SETTINGS / CONTROLS / QUIT, so while the levels were up the tops of
## three buttons stuck out from under its bottom edge, half-hidden and still clickable. The
## row belongs to the title screen; it steps out while the selector is open.
func _show_side_buttons(shown: bool) -> void:
	if side_buttons == null:
		return
	var fade := create_tween()
	if shown:
		side_buttons.visible = true
		fade.tween_property(side_buttons, "modulate:a", 1.0, 0.18)
	else:
		fade.tween_property(side_buttons, "modulate:a", 0.0, 0.12)
		fade.tween_callback(func() -> void: side_buttons.visible = false)


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


## Reflect the catalog and the persisted profile in the level cards.
##
## A card is offered only when the level is BOTH unlocked and playable, and those are
## different questions. Finishing level 1 unlocks level 2 in the profile, so
## is_unlocked started returning true for it -- and the card became enabled while its
## scene_path was still empty. Clicking it called open_level, which returned false, and
## nothing happened: an enabled button reading "COMING SOON" that silently did nothing.
## A button that lies is worse than one that is greyed out.
func _refresh_cards() -> void:
	var profile := get_node_or_null(^"/root/PlayerProfile")
	for index in range(cards.size()):
		var level_id := "level_%d" % (index + 1)
		var card := cards[index]
		var entry := LevelManager.get_level(level_id)
		var title := String(entry.get("title", level_id))
		var playable := LevelManager.is_playable(level_id)
		var unlocked := LevelManager.is_unlocked(level_id)
		# THREE QUESTIONS, and the card is only offered when all three answer yes. The
		# brush is the third: open_level refuses without it, so a card that ignored it
		# would be the same enabled-button-that-does-nothing the note below is about --
		# only worse, because the reason is a room the player has not been in yet.
		var armed := LevelManager.has_brush()
		card.disabled = not (unlocked and playable and armed)
		# ⚠ THE PADLOCK IS A CLAIM ABOUT WHETHER THE CARD CAN BE PRESSED, and nothing was
		# keeping it honest. Which cards carry a Lock is authored in the scene -- card one
		# has a thumbnail, cards two to five have a padlock and one line of text -- so the
		# lock was a fact about the SHAPE of the card, decided before the level existed.
		# Piyesta is built and playable now, and its card still wore a padlock while being
		# perfectly pressable. `disabled` is the same question the lock is drawing.
		var lock := card.get_node_or_null(^"Lock") as Control
		if lock != null:
			lock.visible = card.disabled
		var completed: bool = profile != null and profile.is_level_completed(level_id)
		# Tint completed cards green while preserving the alpha the reveal tween drives.
		var rgb := Color(0.66, 0.94, 0.70) if completed else Color.WHITE
		card.modulate = Color(rgb.r, rgb.g, rgb.b, card.modulate.a)
		_write_card_text(card, index + 1, entry, playable)
		if not playable:
			card.tooltip_text = "%s — not made yet" % title
		elif not unlocked:
			card.tooltip_text = "%s — locked" % title
		elif not armed:
			card.tooltip_text = "%s — take Lola's brush in the house first" % title
		elif completed:
			card.tooltip_text = "%s — completed" % title
		else:
			card.tooltip_text = title


## Fill whichever labels a card actually has. A playable card carries Number/Name/Theme
## over a thumbnail; a card with no level behind it carries a padlock and one Text
## label. Both are filled from the catalog rather than from strings typed into the
## scene, which is what let the level 1 card read "BANAUE RICE TERRACES" while
## levels.json was the thing everything else believed.
func _write_card_text(card: Button, number: int, entry: Dictionary, playable: bool) -> void:
	var title := String(entry.get("title", "")).to_upper()
	var flavour := String(entry.get("theme", "")).to_upper()
	var number_label := card.get_node_or_null(^"Number") as Label
	if number_label != null:
		number_label.text = "LEVEL %d" % number
	var name_label := card.get_node_or_null(^"Name") as Label
	if name_label != null:
		name_label.text = title
	var theme_label := card.get_node_or_null(^"Theme") as Label
	if theme_label != null:
		theme_label.text = flavour
	# ⚠ THE PICTURE COMES FROM THE CATALOGUE TOO. Level 1's was an atlas region wired into
	# the scene, so a card could show the terraces while levels.json said something else --
	# the same split that once had this card reading "BANAUE RICE TERRACES". Every level
	# entry already names a `thumbnail`; a card that has somewhere to put one uses it.
	var art := card.get_node_or_null(^"Thumbnail") as TextureRect
	if art != null:
		var path := String(entry.get("thumbnail", ""))
		art.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
		art.visible = art.texture != null
	var text_label := card.get_node_or_null(^"Text") as Label
	if text_label != null:
		text_label.text = "LEVEL %d\n%s" % [number, title if playable else "COMING SOON"]


func _apply_current_layout() -> void:
	_set_panel_rect(_selector_panel_rect() if _selector_open else _play_panel_rect())
	if _selector_open:
		_layout_cards()


func _on_viewport_size_changed() -> void:
	_apply_current_layout()


## NEW GAME and CONTINUE. With nothing saved the big button is NEW GAME and there is nothing
## to continue; with a save it CONTINUES -- back to the house, to pick a painting -- and
## NEW GAME moves to the row underneath, behind a confirmation.
func _refresh_start_buttons() -> void:
	var saved: bool = PlayerProfile.has_progress()
	# Just the word: Continue goes back to the house, which is where it always goes.
	play_button.text = "CONTINUE" if saved else "NEW GAME"
	new_game_button.visible = saved


func _build_new_game_button() -> void:
	new_game_button = Button.new()
	new_game_button.name = "NewGameButton"
	new_game_button.text = "NEW GAME"
	new_game_button.theme_type_variation = &"DialogButton"
	new_game_button.pressed.connect(_ask_new_game)
	side_buttons.add_child(new_game_button)
	side_buttons.move_child(new_game_button, 0)
	# Four buttons where there were three: the row is anchored to the middle and sized in
	# the scene for three, so it is widened here rather than letting it spill to the right.
	side_buttons.offset_left = -340.0
	side_buttons.offset_right = 340.0


## Both NEW GAME (on a fresh save) and CONTINUE go to the house, where the level is chosen.
func _on_play_pressed() -> void:
	LevelManager.open_house()


func _ask_new_game() -> void:
	var confirm := get_node_or_null(^"ConfirmOverlay")
	if confirm == null:
		return
	_pending_confirm = "new_game"
	_connect_confirm(confirm)
	confirm.call(&"ask", "START A NEW GAME?",
		"Everything you have found and drawn will be forgotten. Your settings are kept.",
		"NEW GAME")


func _connect_confirm(confirm: Node) -> void:
	if not confirm.is_connected(&"confirmed", _on_confirmed):
		confirm.connect(&"confirmed", _on_confirmed)


func _on_confirmed() -> void:
	var asked := _pending_confirm
	_pending_confirm = ""
	match asked:
		"quit":
			_quit_to_desktop()
		"new_game":
			PlayerProfile.reset_progress()
			LevelManager.open_house()


func _play_panel_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	# ⚠ WIDER THAN THE ROW BENEATH IT. The three secondary buttons are sized by their own
	# labels -- SETTINGS and CONTROLS are eight characters plus padding -- and come to about
	# 420 together. At 340 the hero button was NARROWER than the utilities under it, which
	# reads as the small print being the main event.
	return Rect2(Vector2(viewport_size.x * 0.5 - 260.0, viewport_size.y - 190.0), Vector2(520.0, 84.0))


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


## Cards are sized here, not in the scene: the panel is a morph target whose width depends
## on the window, so the five have to be divided out of whatever it turns out to be.
##
## THE HEIGHT CAP IS WHAT THE UNLOCKED CARD'S BLURB NEEDS. It was 300, which fitted the
## proportional font this menu was built with; the bitmap face is wider per character, so
## the same sentence went from two lines to four and the last one was clipped by the card's
## own clip_contents. Anything that changes the type scale has to come back here.
const CARD_HEIGHT := 372.0


func _layout_cards() -> void:
	var available_width := maxf(300.0, morph_panel.size.x - 64.0)
	var separation := 14.0
	var card_width := (available_width - separation * 4.0) / 5.0
	var base_y := 154.0
	for index in range(cards.size()):
		var card := cards[index]
		# ⚠ FLAT. Each card used to be lifted 18px above the one to its left, which fanned
		# the row upward and put five different bottom edges under a panel with one. Nothing
		# in this file said why, and it read as five cards that had failed to line up rather
		# than as a deliberate fan -- the heights all clamp to CARD_HEIGHT, so the stagger
		# was pure offset with no compensating shape.
		card.position = Vector2(32.0 + float(index) * (card_width + separation), base_y)
		card.size = Vector2(card_width,
			minf(CARD_HEIGHT, morph_panel.size.y - card.position.y - 34.0))
