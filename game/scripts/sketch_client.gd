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

@export var backend_url: String = "http://127.0.0.1:8000/predict"
@export var canvas_viewport: SubViewport
## Below this confidence the game should ask the player to try drawing again.
@export_range(0.0, 1.0) var confidence_threshold: float = 0.6
## Below this top-1 vs top-2 probability gap, the result is too ambiguous.
@export_range(0.0, 1.0) var margin_threshold: float = 0.15
@export var debug_timing_logs: bool = false

var _http: HTTPRequest
var _last_drawing: Image
var _request_started_usec: int = 0


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


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
