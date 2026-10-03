extends Node
## Captures the drawing SubViewport, sends it to the Python backend, and emits
## the recognized entity. The legacy prediction_received signal remains for old
## scenes that still call the result a "creature".

signal prediction_received(creature: String, confidence: float, drawing: Image)
signal entity_prediction_received(
	entity: String,
	display_name: String,
	confidence: float,
	drawing: Image,
	response: Dictionary
)
## Emitted when a prediction was returned but rejected by the confidence/margin
## gate — the "redraw" case. Distinct from prediction_failed, which signals a
## transport or backend error rather than a recognised-but-declined drawing.
signal entity_declined(
	entity: String,
	confidence: float,
	margin: float,
	response: Dictionary
)
signal prediction_failed(message: String)
## The running commentary the drawing panel shows while the player is still drawing:
## the model's current best guess, ungated, with the confidence that goes with it.
## Nothing is spent and nothing is spawned on these -- they only tell the player
## whether the game is seeing what they meant to draw.
signal live_prediction(
	entity: String,
	display_name: String,
	confidence: float,
	margin: float,
	response: Dictionary
)
## The live guess could not be formed: an empty canvas, or the backend being down.
## Separate from prediction_failed so a polling error never disturbs a real submission.
signal live_prediction_failed(message: String)
## The drawing was sent while the recogniser was still starting. It is being held and sent
## again until the recogniser answers -- the player does not have to press Transform twice.
signal prediction_waiting(message: String)

## Empty: wherever the game's own server is (BackendSupervisor.url), which is port 8000 unless
## something else held it. Set to send somewhere else.
@export var backend_url: String = ""
@export var canvas_viewport: SubViewport
## The on-screen SubViewport is transparent so its rectangular corners do not show outside
## the oval frame. Captures are flattened onto this paper colour before recognition and
## storage, preserving the opaque image contract used by thumbnails and bitmap fallbacks.
@export var paper_color: Color = Color(0.965, 0.95, 0.9, 1.0)
## Below this confidence the game should ask the player to try drawing again.
@export_range(0.0, 1.0) var confidence_threshold: float = 0.6
## Below this top-1 vs top-2 probability gap, the result is too ambiguous.
@export_range(0.0, 1.0) var margin_threshold: float = 0.15
@export var debug_timing_logs: bool = false

var _http: HTTPRequest
## Live guesses ride their own request so a poll in flight can never make the player's
## Transform press fail with "is another one running?".
var _live_http: HTTPRequest
var _live_busy := false
var _last_drawing: Image
var _request_started_usec: int = 0
## ⚠ A DRAWING SENT TOO EARLY WAITS INSTEAD OF FAILING. Kent's friend on Windows "had to wait
## minutes for a drawing to be recognized": the recogniser was still starting, every press
## of Transform failed with "backend unreachable", and the only thing to do was press it
## again. While the game's own server is starting (BackendSupervisor.is_waking) the drawing
## is kept and sent again every second, for up to fifteen minutes -- a first start that is
## installing the packages takes minutes -- and the panel says why.
const WAKE_RETRY_SEC := 1.0
const WAKE_PATIENCE_SEC := 900.0
var _pending_body := ""
var _waiting_since_msec := 0
var _waiting_said := ""
var _resend: Timer


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_live_http = HTTPRequest.new()
	add_child(_live_http)
	_live_http.request_completed.connect(_on_live_request_completed)
	_resend = Timer.new()
	_resend.one_shot = true
	add_child(_resend)
	_resend.timeout.connect(_send_pending)


func _predict_url() -> String:
	return backend_url if not backend_url.is_empty() else BackendSupervisor.url("/predict")


func _send_pending() -> void:
	if _pending_body.is_empty():
		return
	_request_started_usec = Time.get_ticks_usec()
	if _http.request(_predict_url(), ["Content-Type: application/json"], HTTPClient.METHOD_POST,
			_pending_body) != OK:
		_pending_body = ""
		prediction_failed.emit("could not start the request (is another one running?)")


## Call this from your "Transform!" button.
func send_drawing() -> void:
	var started := Time.get_ticks_usec()
	await RenderingServer.frame_post_draw  # make sure the strokes are rendered
	_last_drawing = _capture_drawing()
	var png_base64 := Marshalls.raw_to_base64(_last_drawing.save_png_to_buffer())
	_pending_body = JSON.stringify({"image_data": png_base64})
	_waiting_since_msec = 0
	if debug_timing_logs:
		var capture_ms := float(Time.get_ticks_usec() - started) / 1000.0
		print("SketchClient capture/encode %.2f ms" % capture_ms)
	_send_pending()


## Asks what the drawing looks like SO FAR. Returns false when a poll is already in
## flight, which is how the caller paces itself: the next one goes out when this one
## lands, so a slow backend thins the guesses out instead of queueing them up.
func request_live_guess() -> bool:
	if _live_busy or canvas_viewport == null:
		return false
	_live_busy = true
	await RenderingServer.frame_post_draw
	var image := _capture_drawing()
	var body := JSON.stringify({"image_data": Marshalls.raw_to_base64(image.save_png_to_buffer())})
	var error := _live_http.request(
		_predict_url(),
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)
	if error != OK:
		_live_busy = false
		live_prediction_failed.emit("live guess could not be sent")
		return false
	return true


func _capture_drawing() -> Image:
	var ink := canvas_viewport.get_texture().get_image()
	ink.convert(Image.FORMAT_RGBA8)
	var flattened := Image.create_empty(ink.get_width(), ink.get_height(), false, Image.FORMAT_RGBA8)
	flattened.fill(paper_color)
	flattened.blend_rect(ink, Rect2i(Vector2i.ZERO, ink.get_size()), Vector2i.ZERO)
	return flattened


func _on_live_request_completed(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	_live_busy = false
	if result != HTTPRequest.RESULT_SUCCESS:
		live_prediction_failed.emit("backend unreachable")
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if response_code != 200 or not (parsed is Dictionary):
		# 422 is the backend's "the canvas looks empty", which is a normal thing to
		# ask about mid-drawing and not worth a message.
		live_prediction_failed.emit("" if response_code == 422 else "no guess yet")
		return
	var entity := String(parsed.get("entity", parsed.get("creature", "")))
	if entity.is_empty():
		live_prediction_failed.emit("no guess yet")
		return
	live_prediction.emit(
		entity,
		String(parsed.get("display_name", entity.capitalize())),
		float(parsed.get("confidence", 0.0)),
		float(parsed.get("margin", 0.0)),
		parsed
	)


func _on_request_completed(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	if debug_timing_logs and _request_started_usec > 0:
		var request_ms := float(Time.get_ticks_usec() - _request_started_usec) / 1000.0
		print("SketchClient request %.2f ms" % request_ms)
	if result != HTTPRequest.RESULT_SUCCESS:
		var now := Time.get_ticks_msec()
		if BackendSupervisor.is_waking() and (_waiting_since_msec == 0
				or now - _waiting_since_msec < int(WAKE_PATIENCE_SEC * 1000.0)):
			var doing := BackendSupervisor.status()
			var message := "%s -- this drawing will go through by itself" % (doing
				if not doing.is_empty() else "The drawing recogniser is still waking up")
			if _waiting_since_msec == 0 or message != _waiting_said:
				if _waiting_since_msec == 0:
					_waiting_since_msec = now
				_waiting_said = message
				prediction_waiting.emit(message)
			_resend.start(WAKE_RETRY_SEC)
			return
		_pending_body = ""
		var why := BackendSupervisor.failure_reason()
		prediction_failed.emit(why if not why.is_empty()
			else "The drawing recogniser is not running -- close the game and start it again")
		return
	_pending_body = ""
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if response_code != 200 or parsed == null:
		var detail: String = parsed.get("detail", "unknown error") if parsed is Dictionary else "bad response"
		prediction_failed.emit(detail)
		return
	var confidence: float = parsed["confidence"]
	var margin: float = parsed.get("margin", 1.0)
	var entity := String(parsed.get("entity", parsed.get("creature", "")))
	var display_name := String(parsed.get("display_name", entity.capitalize()))
	if confidence < confidence_threshold or margin < margin_threshold:
		# A prediction came back but was rejected by the gate — surface it as a
		# decline (redraw) carrying its class/confidence/margin instead of dropping it.
		entity_declined.emit(entity, confidence, margin, parsed)
		return
	entity_prediction_received.emit(entity, display_name, confidence, _last_drawing, parsed)
	prediction_received.emit(entity, confidence, _last_drawing)
