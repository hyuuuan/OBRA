class_name DarknessLayer
extends CanvasLayer
## The dark over a level that has it: one full-screen rect, with every light in LightField.GROUP
## cut out of it, each frame.
##
## Layer 3: over the world and its backdrops, under the HUD (5), the cinematic bars (9), the
## drawing panel (10) and every overlay -- the dark is in the world, never on the controls.

const LAYER := 3
const SHADER := preload("res://shaders/darkness.gdshader")
const MAX_HOLES := 16
const MAX_CONES := 4

## How dark the dark is, 0 (none) to 1 (black), outside every light.
var darkness := 0.9:
	set(value):
		darkness = clampf(value, 0.0, 1.0)
		if _material != null:
			_material.set_shader_parameter(&"darkness", darkness)

var _rect: ColorRect
var _material: ShaderMaterial
var _hole_count := 0
var _cone_count := 0


func _ready() -> void:
	layer = LAYER
	# Drawn while a line of dialogue has the tree stopped: the camera can still move then.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter(&"soft_edge", LightField.SOFT_EDGE)
	_material.set_shader_parameter(&"darkness", darkness)
	_rect = ColorRect.new()
	_rect.name = "Dark"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.material = _material
	add_child(_rect)


func _process(_delta: float) -> void:
	refresh()


## Cut this frame's lights out of the dark, in screen px through the camera.
func refresh() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	_material.set_shader_parameter(&"rect_size", viewport.get_visible_rect().size)
	var canvas := viewport.get_canvas_transform()
	var zoom := canvas.get_scale().x
	var holes: Array[Vector4] = []
	var cones: Array[Vector4] = []
	var dirs: Array[Vector4] = []
	for hole: Dictionary in LightField.holes_in(get_tree()):
		var at: Vector2 = canvas * (hole.get("position", Vector2.ZERO) as Vector2)
		var packed := Vector4(at.x, at.y, float(hole.get("radius", 0.0)) * zoom,
			clampf(float(hole.get("strength", 1.0)), 0.0, 1.0))
		if hole.has("direction"):
			if cones.size() < MAX_CONES:
				var direction := (hole["direction"] as Vector2).normalized()
				cones.append(packed)
				dirs.append(Vector4(direction.x, direction.y, float(hole.get("half_angle", 0.5)), 0.0))
		elif holes.size() < MAX_HOLES:
			holes.append(packed)
	_hole_count = holes.size()
	_cone_count = cones.size()
	while holes.size() < MAX_HOLES:
		holes.append(Vector4.ZERO)
	while cones.size() < MAX_CONES:
		cones.append(Vector4.ZERO)
		dirs.append(Vector4.ZERO)
	_material.set_shader_parameter(&"holes", holes)
	_material.set_shader_parameter(&"hole_count", _hole_count)
	_material.set_shader_parameter(&"cones", cones)
	_material.set_shader_parameter(&"cone_dirs", dirs)
	_material.set_shader_parameter(&"cone_count", _cone_count)


## How many radial lights and cones the dark is showing this frame, for a probe.
func shown() -> Vector2i:
	return Vector2i(_hole_count, _cone_count)


## The first radial hole as the shader has it, screen px, for a probe.
func first_hole() -> Vector4:
	var holes: Variant = _material.get_shader_parameter(&"holes")
	return (holes as Array)[0] if holes is Array and not (holes as Array).is_empty() else Vector4.ZERO
