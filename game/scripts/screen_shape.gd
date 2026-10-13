extends Node
## HOW THE GAME FILLS A SCREEN.
##
## project.godot stretches `expand`: the game is never shown smaller than 1600 x 900, and a
## screen of any other shape gives it more -- width on a wide one, height on a MacBook's
## 16:10 -- which the interface spreads into and the world camera answers by sitting further
## in (WorldCameraController.screen_fit), so nobody gets black bars. Kent: "yes make sure
## everything is visually appealing".
##
## ⚠ BUT NOT WITHOUT LIMIT. A screen squarer than 4:3 -- a monitor turned on its side, a window
## dragged tall and thin -- would hand the interface a page twice as tall as it is wide, and
## the camera would have to push in until the world was a sliver five hundred units across.
## Past 4:3 the game keeps its shape instead and letterboxes, which is what a player expects
## of a screen that shape. A headless test run's window is 64 x 64, the squarest of all, so
## it is shown 1600 x 900 the way every suite was written for.
##
## Only ever moves between the two it owns. A probe that sets another on purpose -- IGNORE, to
## lay the screens out at a shape the machine it runs on does not have -- is left alone.

## The squarest screen the game fills.
const SQUAREST := 4.0 / 3.0


func _ready() -> void:
	var root := get_tree().root
	root.size_changed.connect(_reshape)
	_reshape()


func _reshape() -> void:
	var root := get_tree().root
	if root.content_scale_aspect != Window.CONTENT_SCALE_ASPECT_EXPAND \
			and root.content_scale_aspect != Window.CONTENT_SCALE_ASPECT_KEEP:
		return
	var wanted := aspect_for(Vector2(root.size))
	if root.content_scale_aspect != wanted:
		root.content_scale_aspect = wanted


## Fill a window this shape, or keep the game's own shape inside it.
static func aspect_for(window: Vector2) -> Window.ContentScaleAspect:
	var fills := window.x / maxf(1.0, window.y) >= SQUAREST - 0.001
	return Window.CONTENT_SCALE_ASPECT_EXPAND if fills else Window.CONTENT_SCALE_ASPECT_KEEP
