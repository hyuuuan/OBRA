class_name MorphLife
extends Node
## How long a drawing stays alive once the player becomes it.
##
## A DRAWING IS NOT PERMANENT. Ink buys the transformation; this is what the transformation
## costs to KEEP. Until now a morph lasted until the player drew over it or pressed Q, which
## made the twelve units of ink the only pressure in a level and made the right play always
## "become the strongest thing early and stay in it". A creature that is running out gives
## the level a second clock, and it is the clock that makes ink worth hoarding.
##
## IT IS THE DRAWING'S LIFE, not a cooldown. The HUD reads it as a health bar over the
## creature's name, the way a battle screen shows what you are currently fielding -- so the
## number here is "how much of this animal is left", and when it reaches zero the drawing
## dies and the apo is themselves again. That framing is why this is drained by seconds
## rather than by use: it is alive, and being alive is what spends it.
##
## THE WANDERER HAS NO LIFE. The apo is not a drawing, so `is_alive()` is false whenever the
## player is themselves and the HUD hides the whole plate. Every guard below is written so
## that a level which never calls `begin` behaves exactly as it did before this existed.

## Emitted every time the clock moves, and once with a full bar when a drawing is adopted.
signal life_changed(remaining: float, capacity: float)
## The drawing has run out. GameLevel listens and puts the apo back.
signal life_expired
## A drawing was adopted, or the player went back to being themselves (`form_name` empty).
signal form_changed(form_name: String, form_id: String)

## How long a drawing lives, in seconds.
##
## THE ONE NUMBER TO TUNE. Ten, which is short on purpose: a drawing is a burst, not a
## costume. At this length being a creature is something you spend on one obstacle -- get
## across, get up, get through -- rather than a state you travel the level in, and the
## twelve units of ink stop being a budget for the whole run and start being a count of how
## many bursts you have.
##
## IT MAKES POSITION MATTER MORE THAN ROUTE. Ten seconds is not long enough to cross Payyo
## in one body, so the question at every obstacle stops being "which animal is best here"
## and becomes "where do I want to be standing when this one runs out". Anything built on
## the old forty-five -- a stretch that assumed one morph carried you the whole way -- is
## where to look first if a section stops working.
##
## Exported rather than const because it is balance, not architecture: it belongs in the
## scene where a designer can reach it without opening a script.
@export var seconds: float = 10.0
## Below this fraction the HUD turns the bar red and the level says so once. A quarter of
## ten is the last two and a half seconds -- time to land somewhere survivable, not time to
## cross anything, which is the right amount of notice for a life this short.
@export var warning_ratio: float = 0.25

var _remaining := 0.0
var _capacity := 0.0
var _form_name := ""
var _form_id := ""
var _warned := false


func _ready() -> void:
	set_process(false)


## Adopt a drawing. Restarts the clock at full whatever was running before -- drawing a
## second creature over the first is a NEW life, not the remains of the old one.
func begin(form_name: String, form_id: String) -> void:
	_form_name = form_name
	_form_id = form_id
	_capacity = maxf(0.001, seconds)
	_remaining = _capacity
	_warned = false
	set_process(true)
	form_changed.emit(_form_name, _form_id)
	life_changed.emit(_remaining, _capacity)


## Back to being the apo, by any route -- Q, expiry, or a level ending. Idempotent, because
## expiry calls it through GameLevel's revert and Q calls it directly.
func clear() -> void:
	set_process(false)
	_remaining = 0.0
	_capacity = 0.0
	_warned = false
	if _form_name.is_empty() and _form_id.is_empty():
		return
	_form_name = ""
	_form_id = ""
	form_changed.emit("", "")
	life_changed.emit(0.0, 0.0)


func is_alive() -> bool:
	return _capacity > 0.0 and _remaining > 0.0


func remaining() -> float:
	return maxf(0.0, _remaining)


func capacity() -> float:
	return _capacity


func remaining_ratio() -> float:
	if _capacity <= 0.0:
		return 0.0
	return clampf(_remaining / _capacity, 0.0, 1.0)


func form_name() -> String:
	return _form_name


func form_id() -> String:
	return _form_id


## Whether the drawing is close enough to gone that the level should say so. Latches, so
## the warning is said once rather than on every frame under the line.
func consume_warning() -> bool:
	if _warned or not is_alive():
		return false
	if remaining_ratio() > warning_ratio:
		return false
	_warned = true
	return true


func _process(delta: float) -> void:
	if _capacity <= 0.0:
		set_process(false)
		return
	_remaining = maxf(0.0, _remaining - delta)
	life_changed.emit(_remaining, _capacity)
	if _remaining > 0.0:
		return
	# Stop the clock before announcing. GameLevel answers this by reverting, which calls
	# clear() -- and a timer still running into that would emit a second expiry against a
	# body that has already been replaced.
	set_process(false)
	life_expired.emit()
