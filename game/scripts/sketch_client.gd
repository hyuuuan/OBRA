extends Node
## Captures the drawing SubViewport, sends it to the Python backend, and emits
## the recognized creature. Connect the signals from your main scene.

signal prediction_received(creature: String, confidence: float, drawing: Image)
signal prediction_failed(message: String)

@export var backend_url: String = "http://127.0.0.1:8000/predict"
@export var canvas_viewport: SubViewport
## Below this confidence the game should ask the player to try drawing again.
@export_range(0.0, 1.0) var confidence_threshold: float = 0.6

var _http: HTTPRequest
var _last_drawing: Image


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


## Call this from your "Transform!" button.
func send_drawing() -> void:
	await RenderingServer.frame_post_draw  # make sure the strokes are rendered
	_last_drawing = canvas_viewport.get_texture().get_image()
	var png_base64 := Marshalls.raw_to_base64(_last_drawing.save_png_to_buffer())
	var body := JSON.stringify({"image_data": png_base64})
	var error := _http.request(
		backend_url,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)
	if error != OK:
		prediction_failed.emit("could not start the request (is another one running?)")


func _on_request_completed(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		prediction_failed.emit("backend unreachable — is the Python server running?")
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if response_code != 200 or parsed == null:
		var detail: String = parsed.get("detail", "unknown error") if parsed is Dictionary else "bad response"
		prediction_failed.emit(detail)
		return
	var confidence: float = parsed["confidence"]
	if confidence < confidence_threshold:
		prediction_failed.emit("not sure what that is — try drawing it more clearly!")
		return
	prediction_received.emit(parsed["creature"], confidence, _last_drawing)
