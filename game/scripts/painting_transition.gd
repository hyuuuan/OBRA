extends CanvasLayer
## A painting becomes the world in exactly one second. The incoming scene is prepared
## beneath a still of the hall BEFORE the clock starts, so loading cannot stretch the ease.

const SECONDS := 1.0
const EFFECT := preload("res://shaders/painting_transition.gdshader")
const PORTAL := preload("res://shaders/painting_portal.gdshader")
const UI_FADE_SECONDS := 0.28
## Distance behind the hall plane, in units of the initial camera-to-hall distance.
const LEVEL_DEPTH := 0.70

var _root: Control
var _hall: TextureRect
var _composite: ColorRect
var _portal: ShaderMaterial
var _effect: ShaderMaterial
var _from := Transform2D.IDENTITY
var _hall_zoom_end := 1.0
var _painting_center := Vector2(0.5, 0.5)
var _reduced := false
var _returning := false
var progress := 0.0
var _interface_layers: Array[CanvasLayer] = []
var _interface_scene: Node
var _interface_alpha := 1.0
var _interface_fade: Tween
var _departing_ui: Array[Dictionary] = []
var _departing_ui_alpha := 1.0


func _ready() -> void:
	layer = 1001
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "PaintingTransition"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	# Capture the live level before drawing the hall and its painting-shaped opening.
	var incoming_copy := BackBufferCopy.new()
	incoming_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_root.add_child(incoming_copy)
	_hall = TextureRect.new()
	_hall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hall)
	_composite = ColorRect.new()
	_composite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_composite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portal = ShaderMaterial.new()
	_portal.shader = PORTAL
	_composite.material = _portal
	_root.add_child(_composite)
	# Copy the two depth planes together for the shared blur, exposure and white cast.
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
	_composite.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	if _portal.get_shader_parameter(&"active") != true:
		visible = false
		_composite.visible = false
		_root.mouse_filter = Control.MOUSE_FILTER_STOP


func prepare(source: Dictionary, hall: Texture2D, returning: bool = false, scene: Texture2D = null) -> void:
	_returning = returning
	_reduced = Motion.reduced()
	_from = source["transform"]
	var view := get_viewport().get_visible_rect().size
	var art_size: Vector2 = source["art_size"]
	var painting_size := art_size * _from.get_scale()
	_painting_center = _from.origin / view
	_hall_zoom_end = maxf(view.x / painting_size.x, view.y / painting_size.y) * 1.22
	_portal.set_shader_parameter(&"active", true)
	_portal.set_shader_parameter(&"returning", returning)
	_portal.set_shader_parameter(&"hall_scene", hall)
	_portal.set_shader_parameter(&"scene_snapshot", scene)
	_portal.set_shader_parameter(&"painting_center", _painting_center)
	_portal.set_shader_parameter(&"painting_half_size", painting_size * 0.5 / view)
	_hall.texture = scene if returning else hall
	_hall.modulate.a = 1.0
	_hall.visible = _reduced
	_composite.visible = not _reduced
	visible = true
	apply_progress(0.0)


## Cover the scene swap with the departing world, with its UI already removed.
func cover_return(scene: Texture2D) -> void:
	_hall.texture = scene
	_hall.modulate.a = 1.0
	_hall.visible = true
	_composite.visible = false
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
		# A dolly toward the foreground plane. The background at z=LEVEL_DEPTH moves
		# by the same camera distance, so its apparent scale changes much less.
		var hall_zoom := pow(_hall_zoom_end, expansion)
		var camera_distance := 1.0 / hall_zoom
		var final_distance := 1.0 / _hall_zoom_end
		var level_scale := (LEVEL_DEPTH + final_distance) / (LEVEL_DEPTH + camera_distance)
		_portal.set_shader_parameter(&"hall_zoom", hall_zoom)
		_portal.set_shader_parameter(&"camera_travel", expansion)
		_portal.set_shader_parameter(&"aperture_reveal", entry_ease(expansion / 0.65))
		_portal.set_shader_parameter(&"level_scale", level_scale)
		_portal.set_shader_parameter(&"level_center",
			_painting_center.lerp(Vector2(0.5, 0.5), 0.62 + expansion * 0.38))
	_departing_ui_alpha = 1.0 - entry_ease(progress / 0.24)

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
	_composite.visible = false
	_portal.set_shader_parameter(&"active", false)
	_portal.set_shader_parameter(&"hall_scene", null)
	_portal.set_shader_parameter(&"scene_snapshot", null)
	_release_departing_ui()


## Borrow the hall's actual controls so they can fade in screen space while the
## world beneath them zooms. They survive the scene swap, then leave with the transition.
func take_hall_interface(scene: Node) -> void:
	_release_departing_ui()
	_departing_ui_alpha = 1.0
	for node in scene.find_children("*", "CanvasLayer", true, false):
		var canvas := node as CanvasLayer
		if canvas.layer < 5 or canvas.get_meta(&"transition_world", false):
			continue
		_departing_ui.append({"canvas": canvas, "parent": canvas.get_parent(),
			"index": canvas.get_index(), "layer": canvas.layer})
		canvas.reparent(get_parent())
		canvas.layer += layer + 1
	RenderingServer.frame_pre_draw.connect(_apply_departing_ui_alpha)


## Render a world-only still without presenting the temporary UI-hidden frame.
## No bitmap reconstruction: every wall, frame and player pixel is the real hall.
func capture_world() -> Texture2D:
	if DisplayServer.get_name() == "headless":
		return null
	var was_visible := visible
	visible = false
	var hidden: Array[Dictionary] = []
	for node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var canvas := node as CanvasLayer
		if canvas != self and canvas.layer >= 5 and not canvas.get_meta(&"transition_world", false) \
				and canvas.get_viewport() == get_viewport():
			hidden.append({"canvas": canvas, "visible": canvas.visible})
			canvas.visible = false
	RenderingServer.force_draw(false)
	var snapshot := ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	for entry in hidden:
		if is_instance_valid(entry["canvas"]):
			entry["canvas"].visible = bool(entry["visible"])
	visible = was_visible
	return snapshot


func _apply_departing_ui_alpha() -> void:
	for entry in _departing_ui:
		if is_instance_valid(entry["canvas"]):
			_modulate_interface_roots(entry["canvas"], _departing_ui_alpha)


func _release_departing_ui() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_apply_departing_ui_alpha):
		RenderingServer.frame_pre_draw.disconnect(_apply_departing_ui_alpha)
	for entry in _departing_ui:
		if not is_instance_valid(entry["canvas"]):
			continue
		var canvas := entry["canvas"] as CanvasLayer
		_modulate_interface_roots(canvas, 1.0)
		var original: Variant = entry["parent"]
		if is_instance_valid(original) and original.is_inside_tree():
			# A failed scene change returns the borrowed controls to the still-live hall.
			canvas.reparent(original)
			canvas.layer = int(entry["layer"])
			original.move_child(canvas, mini(int(entry["index"]), original.get_child_count() - 1))
		else:
			canvas.queue_free()
	_departing_ui.clear()


## The portal contains the world alone. Keep the level's UI out of every incoming frame,
## including dialogue, tooltips, and overlays created while the level is getting ready.
func hold_interface(scene: Node) -> void:
	if _interface_fade != null and _interface_fade.is_valid():
		_interface_fade.kill()
	_restore_interface()
	_interface_scene = scene
	_interface_alpha = 0.0
	for node in get_tree().root.find_children("*", "CanvasLayer", true, false):
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
			or get_parent().is_ancestor_of(node):
		return
	var canvas := node as CanvasLayer
	# Include global UI such as the dev indicator and backend notice: those must not
	# enter the background capture either. Our own transition/borrowed controls are exempt.
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
