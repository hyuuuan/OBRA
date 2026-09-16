extends RefCounted
## WHAT THE HUD ACTUALLY PAINTS, AND WHAT STANDS ON WHAT.
##
## Shared by run_hud_layout_probe, which raises everything at once, and the play bots, which
## ask the same question every few frames while the game is really being played -- because
## the overlaps a player sees are the ones that happen mid-beat, not the ones anybody thought
## to stage.
##
## It measures what is DRAWN rather than the layout containers around it: panels that carry a
## stylebox, plus labels that are not inside one of those panels. A wrapper that fills the
## screen and paints nothing is not an overlap; a caption across somebody else's panel is.

## How much two painted rectangles may share before it counts.
const SLACK := 3.0


static func painted(level: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var panels: Array[Control] = []
	for layer in level.get_children():
		if layer is CanvasLayer and (layer as CanvasLayer).visible:
			_collect_panels(layer, panels)
	for panel in panels:
		out.append({"name": trail(panel, level), "rect": panel.get_global_rect()})
	for layer in level.get_children():
		if layer is CanvasLayer and (layer as CanvasLayer).visible:
			_collect_loose_labels(layer, panels, out, level)
	return out


## Every pair that overlaps by more than the slack, as "a over b".
static func clashes(pieces: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for first in range(pieces.size()):
		for second in range(first + 1, pieces.size()):
			var a: Dictionary = pieces[first]
			var b: Dictionary = pieces[second]
			var shared := (a["rect"] as Rect2).intersection(b["rect"] as Rect2)
			if shared.size.x > SLACK and shared.size.y > SLACK:
				out.append("%s over %s" % [a["name"], b["name"]])
	return out


## Faded out is not on screen. The letterbox fades the HUD to nothing and `visible` stays true.
static func shows(node: CanvasItem) -> bool:
	var alpha := 1.0
	var cursor: Node = node
	while cursor != null:
		var item := cursor as CanvasItem
		if item != null:
			alpha *= item.modulate.a * item.self_modulate.a
		cursor = cursor.get_parent()
	return alpha > 0.05


static func _collect_panels(node: Node, into: Array[Control]) -> void:
	var panel := node as PanelContainer
	if panel != null and panel.is_visible_in_tree() and shows(panel) and panel.size.x > 8.0 \
			and panel.size.y > 8.0 and panel.has_theme_stylebox_override(&"panel"):
		into.append(panel)
		return
	for child in node.get_children():
		_collect_panels(child, into)


static func _collect_loose_labels(node: Node, panels: Array[Control],
		into: Array[Dictionary], level: Node) -> void:
	var label := node as Label
	if label != null:
		if not label.is_visible_in_tree() or not shows(label) \
				or label.text.strip_edges().is_empty():
			return
		for panel in panels:
			if label.is_ancestor_of(panel) or panel.is_ancestor_of(label):
				return
		into.append({"name": trail(label, level), "rect": label.get_global_rect()})
		return
	for child in node.get_children():
		_collect_loose_labels(child, panels, into, level)


## The path, with the script's own class where a node was never named.
static func trail(node: Node, level: Node) -> String:
	var parts := PackedStringArray([_label_of(node)])
	var cursor := node.get_parent()
	while cursor != null and cursor != level:
		parts.insert(0, _label_of(cursor))
		cursor = cursor.get_parent()
	return "/".join(parts)


static func _label_of(node: Node) -> String:
	var named := String(node.name)
	if not named.begins_with("@"):
		return named
	var script := node.get_script() as Script
	if script != null and not String(script.get_global_name()).is_empty():
		return String(script.get_global_name())
	return node.get_class()
