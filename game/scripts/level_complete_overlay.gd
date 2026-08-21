extends ModalOverlay
## Shown when a level is finished, so that finishing it can be READ.
##
## Completion used to set a status label to "Level complete!" and transition to the
## menu on the same frame, which meant the one moment the game acknowledges the
## player lasted a single frame and was never seen.
##
## closes_on_cancel is false: this is a decision point, not something to dismiss.
## Cancelling out of it would leave the player standing in a finished level with no
## indication of what to do next.
##
## A view and nothing more. It renders the stats it is handed and reports which button
## was pressed; whether CONTINUE leads to an ending or back to the level select is the
## level's business, not this screen's.

signal continue_pressed
signal retry_pressed

@onready var _title: Label = $Root/Center/Panel/VBox/Title
@onready var _subtitle: Label = $Root/Center/Panel/VBox/Subtitle
@onready var _stats: VBoxContainer = $Root/Center/Panel/VBox/Stats
@onready var _continue_button: Button = $Root/Center/Panel/VBox/Buttons/ContinueButton
@onready var _retry_button: Button = $Root/Center/Panel/VBox/Buttons/RetryButton


func _ready() -> void:
	super()
	closes_on_cancel = false
	_continue_button.pressed.connect(_on_continue)
	_retry_button.pressed.connect(_on_retry)


## Render a run and show the screen. Keys are read defensively so adding a stat to
## run_stats() later cannot break this, and omitting one cannot blank the screen.
func present(stats: Dictionary) -> void:
	_subtitle.text = String(stats.get("level_title", "")).to_upper()
	for child in _stats.get_children():
		child.queue_free()
	_add_stat("Time", _format_duration(float(stats.get("elapsed_seconds", 0.0))))
	_add_stat("Ink used", "%.1f / %.1f" % [
		float(stats.get("ink_used", 0.0)), float(stats.get("ink_capacity", 0.0))
	])
	_add_stat("Things drawn", str(int(stats.get("classes_drawn", 0))))
	open()


func _add_stat(caption: String, value: String) -> void:
	var row := HBoxContainer.new()
	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption_label)
	var value_label := Label.new()
	value_label.text = value
	value_label.theme_type_variation = &"ScreenSubtitle"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	_stats.add_child(row)


func _on_opened() -> void:
	_continue_button.grab_focus()


func _on_continue() -> void:
	close()
	continue_pressed.emit()


func _on_retry() -> void:
	close()
	retry_pressed.emit()


static func _format_duration(seconds: float) -> String:
	var whole := int(maxf(0.0, seconds))
	return "%d:%02d" % [whole / 60, whole % 60]
