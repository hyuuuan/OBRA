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

@export var backend_url: String = "http://127.0.0.1:8000/predict"
@export var canvas_viewport: SubViewport
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


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_live_http = HTTPRequest.new()
	add_child(_live_http)
	_live_http.request_completed.connect(_on_live_request_completed)


## Call this from your "Transform!" button.
func send_drawing() -> void:
	var started := Time.get_ticks_usec()
	await RenderingServer.frame_post_draw  # make sure the strokes are rendered
	_last_drawing = canvas_viewport.get_texture().get_image()
	var png_base64 := Marshalls.raw_to_base64(_last_drawing.save_png_to_buffer())
	var body := JSON.stringify({"image_data": png_base64})
	_request_started_usec = Time.get_ticks_usec()
	var error := _http.request(
		backend_url,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)
	if debug_timing_logs:
		var capture_ms := float(_request_started_usec - started) / 1000.0
		print("SketchClient capture/encode %.2f ms" % capture_ms)
	if error != OK:
		prediction_failed.emit("could not start the request (is another one running?)")


## Asks what the drawing looks like SO FAR. Returns false when a poll is already in
## flight, which is how the caller paces itself: the next one goes out when this one
## lands, so a slow backend thins the guesses out instead of queueing them up.
func request_live_guess() -> bool:
	if _live_busy or canvas_viewport == null:
		return false
	_live_busy = true
	await RenderingServer.frame_post_draw
	var image := canvas_viewport.get_texture().get_image()
	var body := JSON.stringify({"image_data": Marshalls.raw_to_base64(image.save_png_to_buffer())})
	var error := _live_http.request(
		backend_url,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)
	if error != OK:
		_live_busy = false
		live_prediction_failed.emit("live guess could not be sent")
		return false
	return true


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
		prediction_failed.emit("backend unreachable — is the Python server running?")
		return
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
