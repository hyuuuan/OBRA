extends CanvasLayer
## A painting becomes the world in exactly one second. The incoming scene is prepared
## beneath a still of the hall BEFORE the clock starts, so loading cannot stretch the ease.

const SECONDS := 1.0
const EFFECT := preload("res://shaders/painting_transition.gdshader")
const PORTAL := preload("res://shaders/painting_portal.gdshader")
const Painting := preload("res://scripts/painting_2d.gd")
const UI_FADE_SECONDS := 0.28

class Frame extends Node2D:
	var source: Dictionary

	func _draw() -> void:
		if source.is_empty():
			return
		var art_size: Vector2 = source["art_size"]
		var picture := Rect2(-art_size * 0.5, art_size)
		var art := source["art"] as Texture2D
		if art != null:
			draw_texture_rect(art, picture, false,
				Color(0.42, 0.40, 0.44).lerp(Color.WHITE, float(source["light"])))
		Painting.draw_gilt(self, picture, float(source["moulding"]), float(source["light"]) < 0.5)

var _root: Control
var _hall: TextureRect
var _frame: Frame
var _incoming: ColorRect
var _portal: ShaderMaterial
var _effect: ShaderMaterial
var _from := Transform2D.IDENTITY
var _to_scale := Vector2.ONE
var _reduced := false
var _returning := false
var progress := 0.0
var _interface_layers: Array[CanvasLayer] = []
var _interface_scene: Node
var _interface_alpha := 1.0
var _interface_fade: Tween


func _ready() -> void:
	layer = 1001
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "PaintingTransition"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	# Keep a copy of the live level BEFORE drawing the hall. The portal samples this
	# copy into its own growing rectangle, rather than revealing a full-size level beneath.
	var incoming_copy := BackBufferCopy.new()
	incoming_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_root.add_child(incoming_copy)
	_hall = TextureRect.new()
	_hall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hall)
	_frame = Frame.new()
	_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frame.visible = false
	_root.add_child(_frame)
	_incoming = ColorRect.new()
	_incoming.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portal = ShaderMaterial.new()
	_portal.shader = PORTAL
	_incoming.material = _portal
	_frame.add_child(_incoming)
	# Other screen-reading materials may already have copied the level. Copy again HERE,
	# after the hall and enlarged frame, so both worlds receive the same blur and light.
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_root.add_child(copy)
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect = ShaderMaterial.new()
	_effect.shader = EFFECT
	veil.material = _effect
	_root.add_child(veil)
	visible = false


## Draw once during boot, with zero effects, to compile the shader before a real entry.
func warm() -> void:
	visible = true
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.visible = true
	_incoming.size = get_viewport().get_visible_rect().size
	await get_tree().process_frame
	await get_tree().process_frame
	if _hall.texture == null and _frame.source.is_empty():
		visible = false
		_frame.visible = false
		_root.mouse_filter = Control.MOUSE_FILTER_STOP


func prepare(source: Dictionary, hall: Texture2D, returning: bool = false, scene: Texture2D = null) -> void:
	_returning = returning
	_portal.set_shader_parameter(&"returning", returning)
	_portal.set_shader_parameter(&"scene_snapshot", scene)
	_hall.texture = hall
	_hall.modulate.a = 1.0
	_frame.source = source
	_from = source["transform"]
	_reduced = Motion.reduced()
	_frame.visible = not _reduced
	_frame.queue_redraw()
	var view := get_viewport().get_visible_rect().size
	var art_size: Vector2 = source["art_size"]
	_to_scale = view / art_size
	_incoming.position = -art_size * 0.5
	_incoming.size = art_size
	visible = true
	apply_progress(0.0)


## Cover the scene swap with the departing world, with its UI already removed.
func cover_return(scene: Texture2D) -> void:
	_hall.texture = scene
	_hall.modulate.a = 1.0
	_frame.visible = false
	visible = true
	_effect.set_shader_parameter(&"blur_pixels", 0.0)
	_effect.set_shader_parameter(&"exposure_stops", 0.0)
	_effect.set_shader_parameter(&"white_cast", 0.0)


## Integrated cosine velocity: zero speed at both ends, maximum speed at 40% of the
## clock, then a longer 60% deceleration. Continuous acceleration, no overshoot or bounce.
static func entry_ease(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	if t <= 0.4:
		return t - 0.4 / PI * sin(PI * t / 0.4)
	return t + 0.6 / PI * sin(PI * (t - 0.4) / 0.6)


func apply_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	var eased := entry_ease(progress)
	var expansion := 1.0 - eased if _returning else eased
	var pulse := entry_ease(progress / 0.44) if progress <= 0.44 \
		else 1.0 - entry_ease((progress - 0.44) / 0.56)
	if _reduced:
		_hall.modulate.a = 1.0 - eased
	else:
		_frame.position = _from.origin.lerp(get_viewport().get_visible_rect().size * 0.5, expansion)
		_frame.scale = _from.get_scale().lerp(_to_scale, expansion)
		_frame.rotation = lerp_angle(_from.get_rotation(), 0.0, expansion)
		# Both images occupy this same rectangle. Only the painting and its gilt fade;
		# self_modulate leaves the live-level child growing all the way to its true size.
		_frame.self_modulate.a = entry_ease((progress - 0.10) / 0.52) if _returning \
			else 1.0 - entry_ease((progress - 0.58) / 0.36)
		_incoming.modulate.a = 1.0 - entry_ease((progress - 0.30) / 0.58) if _returning \
			else entry_ease((progress - 0.12) / 0.60)
	_effect.set_shader_parameter(&"blur_pixels", 0.0 if _reduced else pulse * 5.0)
	_effect.set_shader_parameter(&"exposure_stops", 0.0 if _reduced else pulse * 1.05)
	_effect.set_shader_parameter(&"white_cast", pulse * (0.16 if _reduced else 0.82))


func play() -> void:
	# A Tween integrates engine delta, which is capped during a slow frame. Use elapsed
	# wall time so even a hitch cannot turn the requested second into a longer animation.
	var started := Time.get_ticks_usec()
	while true:
		var elapsed := (Time.get_ticks_usec() - started) / 1000000.0
		apply_progress(elapsed / SECONDS)
		if elapsed >= SECONDS:
			break
		await get_tree().process_frame
	clear()


func clear() -> void:
	visible = false
	_hall.texture = null
	_frame.source = {}
	_frame.visible = false
	_portal.set_shader_parameter(&"scene_snapshot", null)


## The portal contains the world alone. Keep the level's UI out of every incoming frame,
## including dialogue, tooltips, and overlays created while the level is getting ready.
func hold_interface(scene: Node) -> void:
	if _interface_fade != null and _interface_fade.is_valid():
		_interface_fade.kill()
	_restore_interface()
	_interface_scene = scene
	_interface_alpha = 0.0
	for node in scene.find_children("*", "CanvasLayer", true, false):
		_track_interface_layer(node)
	get_tree().node_added.connect(_on_interface_node_added)
	RenderingServer.frame_pre_draw.connect(_apply_interface_alpha)
	_apply_interface_alpha()


func reveal_interface() -> void:
	_interface_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_interface_fade.tween_property(self, "_interface_alpha", 1.0, UI_FADE_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_interface_fade.tween_callback(_restore_interface)


func _on_interface_node_added(node: Node) -> void:
	if node is CanvasLayer:
		# Its authored layer may be assigned in _ready, after node_added is emitted.
		_track_interface_layer.call_deferred(node)


func _track_interface_layer(node: Node) -> void:
	if not is_instance_valid(node) or not is_instance_valid(_interface_scene) \
			or not _interface_scene.is_ancestor_of(node):
		return
	var canvas := node as CanvasLayer
	# The world, darkness and moonlit terrain occupy layers 0..4. UI starts at 5.
	if canvas != null and canvas.layer >= 5 and not canvas.get_meta(&"transition_world", false) \
			and canvas.get_viewport() == get_viewport() \
			and canvas not in _interface_layers:
		_interface_layers.append(canvas)


func _apply_interface_alpha() -> void:
	for canvas in _interface_layers:
		if is_instance_valid(canvas):
			_modulate_interface_roots(canvas, _interface_alpha)


func _modulate_interface_roots(node: Node, alpha: float) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			continue
		if child is CanvasItem:
			var item := child as CanvasItem
			var colour := item.modulate
			colour.a *= alpha
			# Apply after UI scripts run, in the renderer only. Their own modulate values,
			# visibility and animations stay intact; this is an independent multiplier.
			RenderingServer.canvas_item_set_modulate(item.get_canvas_item(), colour)
		else:
			_modulate_interface_roots(child, alpha)


func _restore_interface() -> void:
	_interface_alpha = 1.0
	_apply_interface_alpha()
	if RenderingServer.frame_pre_draw.is_connected(_apply_interface_alpha):
		RenderingServer.frame_pre_draw.disconnect(_apply_interface_alpha)
	if get_tree().node_added.is_connected(_on_interface_node_added):
		get_tree().node_added.disconnect(_on_interface_node_added)
	_interface_layers.clear()
	_interface_scene = null
