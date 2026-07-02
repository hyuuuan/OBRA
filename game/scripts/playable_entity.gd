extends CharacterBody2D
## Shared skinning behavior for playable O.B.R.A. entities.

@export var body_node_path: NodePath = NodePath("Body")
@export var punch_white_background: bool = true
@export_range(0.0, 1.0) var paper_threshold: float = 0.92


func apply_drawing(drawing: Image) -> void:
	var sprite := get_node_or_null(body_node_path) as Sprite2D
	if sprite == null:
		push_warning("%s has no Body Sprite2D to skin" % name)
		return

	var image := drawing.duplicate()
	image.convert(Image.FORMAT_RGBA8)
	if punch_white_background:
		_make_paper_transparent(image)
	sprite.texture = ImageTexture.create_from_image(image)


func _make_paper_transparent(image: Image) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.r >= paper_threshold and color.g >= paper_threshold and color.b >= paper_threshold:
				color.a = 0.0
			else:
				color.a = 1.0
			image.set_pixel(x, y, color)

