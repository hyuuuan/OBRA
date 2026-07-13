class_name SpiderRigAnalyzer
extends RefCounted
## Pure geometry pass for spider drawings.
##
## The analyzer builds a small planar contact graph from the player's actual
## polylines.  The graph is used only to decide which ink is structural core and
## which ink runs from that core to a terminal endpoint.  Returned leg paths are
## slices of the input ink; the analyzer never fabricates a missing appendage.

const MIN_LEGS := 4
const MAX_LEGS := 8
const MAX_GRAPH_SEGMENTS := 720
const ARC_EPSILON := 0.01
const GEOMETRY_EPSILON := 0.0001


static func analyze(strokes: Array) -> Dictionary:
	var source_paths := _sanitize_strokes(strokes)
	if source_paths.is_empty():
		return _fallback_result(source_paths, "no usable stroke paths")

	var drawing_bounds := _bounds_for_infos(source_paths)
	var diagonal := maxf(1.0, drawing_bounds.size.length())
	var maximum_width := 1.0
	for info in source_paths:
		maximum_width = maxf(maximum_width, float((info as Dictionary).get("width", 1.0)))
	var weld_radius := clampf(maxf(maximum_width * 2.0, diagonal * 0.018), 2.5, 16.0)

	var graph_paths := _prepare_graph_paths(source_paths, diagonal)
	var graph := _build_contact_graph(graph_paths, weld_radius)
	var nodes: Array = graph.get("nodes", [])
	var edges: Array = graph.get("edges", [])
	var adjacency: Array = graph.get("adjacency", [])
	if nodes.is_empty() or edges.is_empty():
		return _fallback_result(source_paths, "stroke graph has no usable edges")

	var component := _select_structural_component(nodes, adjacency, drawing_bounds)
	if component.is_empty():
		return _fallback_result(source_paths, "no connected structural component")
	var component_set := _index_set(component)
	var core_set := _find_core_nodes(component, component_set, nodes, adjacency, drawing_bounds, weld_radius)
	if core_set.is_empty():
		return _fallback_result(source_paths, "no high-connectivity torso core")

	var core_center := _center_for_node_set(core_set, nodes)
	var leaves: Array[int] = []
	for node_index_value in component:
		var node_index := int(node_index_value)
		if _component_degree(node_index, component_set, adjacency) == 1 and not core_set.has(node_index):
			leaves.append(node_index)
	leaves.sort_custom(_node_index_geometry_less.bind(nodes))

	var candidates: Array[Dictionary] = []
	var minimum_leg_length := maxf(weld_radius * 1.65, diagonal * 0.065)
	for leaf in leaves:
		var route := _shortest_route_to_core(leaf, core_set, component_set, nodes, edges, adjacency)
		var candidate := _candidate_from_route(route, nodes, edges, graph_paths, core_center)
		if candidate.is_empty():
			continue
		var ink_length := float(candidate.get("ink_length", 0.0))
		var root := Vector2(candidate.get("root", Vector2.ZERO))
		var sole := Vector2(candidate.get("sole", Vector2.ZERO))
		var reach := root.distance_to(sole)
		var radial_gain := sole.distance_to(core_center) - root.distance_to(core_center)
		if ink_length < minimum_leg_length or reach < diagonal * 0.04:
			continue
		if radial_gain < -diagonal * 0.025:
			continue
		candidate["score"] = ink_length + maxf(0.0, radial_gain) * 0.35
		candidates.append(candidate)

	candidates = _deduplicate_candidates(candidates, weld_radius)
	if candidates.size() > MAX_LEGS:
		candidates.sort_custom(_candidate_score_less)
		candidates = candidates.slice(0, MAX_LEGS)
	_assign_sides_and_ranks(candidates, core_center, diagonal)
	candidates.sort_custom(_leg_order_less)
	_mark_support_candidates(candidates, diagonal)

	if candidates.size() < MIN_LEGS:
		return _fallback_result(
			source_paths,
			"only %d credible core-to-endpoint branches" % candidates.size()
		)

	var claims := _collect_claimed_ranges(candidates, graph_paths)
	var torso_data := _build_torso_paths(source_paths, claims, core_set, nodes, graph_paths)
	var torso_paths: Array = torso_data.get("paths", [])
	var torso_owners: Array = torso_data.get("owners", [])
	if torso_paths.is_empty():
		return _fallback_result(source_paths, "leg extraction left no torso ink")

	var structural_paths: Array = torso_data.get("structural_paths", [])
	var torso_center := _polyline_collection_center(structural_paths)
	if structural_paths.is_empty():
		torso_center = core_center
	var torso_bounds := _bounds_for_paths(torso_paths)
	var support_height := _support_height(candidates, torso_center)
	var source_indices: Array[int] = []
	for owner_value in torso_owners:
		var source_index := int((owner_value as Dictionary).get("source_index", -1))
		if source_index >= 0 and not source_indices.has(source_index):
			source_indices.append(source_index)
	source_indices.sort()

	# Strip analysis-only values while retaining geometric ownership for the rig
	# builder and deterministic probes.
	for candidate in candidates:
		candidate.erase("score")
		candidate.erase("ink_length")
		candidate.erase("graph_ranges")

	return {
		"valid": true,
		"reason": "",
		"torso_paths": torso_paths,
		"torso_stroke_indices": source_indices,
		"torso_path_owners": torso_owners,
		"decoration_paths": torso_data.get("decoration_paths", []),
		"decoration_path_owners": torso_data.get("decoration_owners", []),
		"torso_center": torso_center,
		"torso_bounds": torso_bounds,
		"support_height": support_height,
		"legs": candidates,
		"weld_radius": weld_radius,
	}


static func _fallback_result(source_paths: Array, reason: String) -> Dictionary:
	var paths: Array = []
	var owners: Array = []
	var source_indices: Array[int] = []
	for info_value in source_paths:
		var info := info_value as Dictionary
		var points := PackedVector2Array(info.get("points", PackedVector2Array()))
		if points.size() < 2:
			continue
		paths.append(points.duplicate())
		var source_index := int(info.get("source_index", -1))
		owners.append({
			"source_index": source_index,
			"from_arc": 0.0,
			"to_arc": float(info.get("length", 0.0)),
			"width": float(info.get("width", 5.0)),
			"color": Color(info.get("color", Color.BLACK)),
			"kind": "decoration",
		})
		if source_index >= 0:
			source_indices.append(source_index)
	var sorted := _sort_owned_paths(paths, owners)
	paths = sorted["paths"]
	owners = sorted["owners"]
	source_indices.sort()
	return {
		"valid": false,
		"reason": reason,
		"torso_paths": paths,
		"torso_stroke_indices": source_indices,
		"torso_path_owners": owners,
		"decoration_paths": paths.duplicate(),
		"decoration_path_owners": owners.duplicate(true),
		"torso_center": _polyline_collection_center(paths),
		"torso_bounds": _bounds_for_paths(paths),
		"support_height": 0.0,
		"legs": [],
		"weld_radius": 0.0,
	}


static func _sanitize_strokes(strokes: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source_index in range(strokes.size()):
		var stroke_value: Variant = strokes[source_index]
		if not (stroke_value is Dictionary):
			continue
		var stroke := stroke_value as Dictionary
		var value: Variant = stroke.get("points")
		if not (value is PackedVector2Array) and not (value is Array):
			continue
		var points := PackedVector2Array()
		for point_value in value:
			if not (point_value is Vector2):
				continue
			var point := Vector2(point_value)
			if not is_finite(point.x) or not is_finite(point.y):
				continue
			if points.is_empty() or points[points.size() - 1].distance_squared_to(point) > GEOMETRY_EPSILON:
				points.append(point)
		if points.size() < 2:
			continue
		var cumulative := _cumulative_lengths(points)
		var length := float(cumulative[cumulative.size() - 1])
		if length <= GEOMETRY_EPSILON:
			continue
		var width := 5.0
		var width_value: Variant = stroke.get("width", width)
		if typeof(width_value) in [TYPE_FLOAT, TYPE_INT]:
			width = clampf(float(width_value), 0.25, 128.0)
		var color := Color.BLACK
		if stroke.get("color") is Color:
			color = Color(stroke.get("color"))
		result.append({
			"points": points,
			"cumulative": cumulative,
			"length": length,
			"width": width,
			"color": color,
			"source_index": source_index,
		})
	return result


static func _prepare_graph_paths(source_paths: Array[Dictionary], diagonal: float) -> Array[Dictionary]:
	var segment_count := 0
	for info in source_paths:
		segment_count += (info.get("points", PackedVector2Array()) as PackedVector2Array).size() - 1
	if segment_count <= MAX_GRAPH_SEGMENTS:
		return source_paths.duplicate(true)

	var target_step := maxf(diagonal * 0.008, _total_path_length(source_paths) / float(MAX_GRAPH_SEGMENTS))
	var result: Array[Dictionary] = []
	for source_info in source_paths:
		var source_points := PackedVector2Array(source_info.get("points", PackedVector2Array()))
		var points := _resample_polyline(source_points, target_step)
		var cumulative := _cumulative_lengths(points)
		var copied := source_info.duplicate()
		copied["points"] = points
		copied["cumulative"] = cumulative
		copied["length"] = float(cumulative[cumulative.size() - 1])
		result.append(copied)
	return result


static func _build_contact_graph(paths: Array[Dictionary], weld_radius: float) -> Dictionary:
	var segments: Array[Dictionary] = []
	var events: Array = []
	for path_index in range(paths.size()):
		var info := paths[path_index]
		var points := PackedVector2Array(info.get("points", PackedVector2Array()))
		var cumulative: Array = info.get("cumulative", [])
		var path_events: Array[float] = []
		for arc_value in cumulative:
			path_events.append(float(arc_value))
		events.append(path_events)
		for segment_index in range(points.size() - 1):
			var length := points[segment_index].distance_to(points[segment_index + 1])
			if length <= GEOMETRY_EPSILON:
				continue
			segments.append({
				"path_index": path_index,
				"segment_index": segment_index,
				"a": points[segment_index],
				"b": points[segment_index + 1],
				"arc0": float(cumulative[segment_index]),
				"length": length,
			})

	var contacts: Array[Dictionary] = []
	for first_index in range(segments.size()):
		var first := segments[first_index]
		for second_index in range(first_index + 1, segments.size()):
			var second := segments[second_index]
			if _segments_are_neighbors(first, second, paths):
				continue
			if not _expanded_segments_overlap(first, second, weld_radius):
				continue
			var intersection := _segment_intersection(first, second)
			if not intersection.is_empty():
				_append_contact(contacts, events, first, float(intersection["t"]), second, float(intersection["u"]))
			# A continuous stroke may genuinely cross itself (for example, a leg
			# drawn through the hub), but nearby non-intersecting parts of that same
			# stroke must not be proximity-welded into a one-pixel graph shortcut.
			if int(first["path_index"]) == int(second["path_index"]):
				var arc_separation := absf(float(first.get("arc0", 0.0)) - float(second.get("arc0", 0.0)))
				if arc_separation >= weld_radius * 2.0:
					var exact_self_weld := minf(0.75, weld_radius * 0.1)
					_append_projected_contact(contacts, events, first, 0.0, second, exact_self_weld)
					_append_projected_contact(contacts, events, first, 1.0, second, exact_self_weld)
					_append_projected_contact(contacts, events, second, 0.0, first, exact_self_weld)
					_append_projected_contact(contacts, events, second, 1.0, first, exact_self_weld)
				continue
			_append_projected_contact(contacts, events, first, 0.0, second, weld_radius)
			_append_projected_contact(contacts, events, first, 1.0, second, weld_radius)
			_append_projected_contact(contacts, events, second, 0.0, first, weld_radius)
			_append_projected_contact(contacts, events, second, 1.0, first, weld_radius)

	contacts = _deduplicate_contacts(contacts)
	var nodes: Array[Dictionary] = []
	var path_node_ids: Array = []
	for path_index in range(paths.size()):
		var path_events: Array = events[path_index]
		path_events.sort()
		var unique_events: Array[float] = []
		for value in path_events:
			var arc := float(value)
			if unique_events.is_empty() or absf(arc - unique_events[unique_events.size() - 1]) > ARC_EPSILON:
				unique_events.append(arc)
		var ids: Array[int] = []
		for arc in unique_events:
			var node_index := nodes.size()
			nodes.append({
				"position": _point_at_arc(paths[path_index], arc),
				"path_index": path_index,
				"source_index": int(paths[path_index].get("source_index", -1)),
				"arc": arc,
			})
			ids.append(node_index)
		path_node_ids.append(ids)
		events[path_index] = unique_events

	var adjacency: Array = []
	adjacency.resize(nodes.size())
	for node_index in range(nodes.size()):
		adjacency[node_index] = []
	var edges: Array[Dictionary] = []
	var edge_keys := {}
	for path_index in range(paths.size()):
		var ids: Array = path_node_ids[path_index]
		var path_events: Array = events[path_index]
		for index in range(ids.size() - 1):
			var from_id := int(ids[index])
			var to_id := int(ids[index + 1])
			var from_arc := float(path_events[index])
			var to_arc := float(path_events[index + 1])
			_add_graph_edge(edges, adjacency, edge_keys, from_id, to_id, {
				"kind": "ink",
				"path_index": path_index,
				"source_index": int(paths[path_index].get("source_index", -1)),
				"from_arc": from_arc,
				"to_arc": to_arc,
				"length": maxf(ARC_EPSILON, to_arc - from_arc),
			})
	for contact in contacts:
		var path_a := int(contact["path_a"])
		var path_b := int(contact["path_b"])
		var node_a := _node_for_arc(events[path_a], path_node_ids[path_a], float(contact["arc_a"]))
		var node_b := _node_for_arc(events[path_b], path_node_ids[path_b], float(contact["arc_b"]))
		if node_a < 0 or node_b < 0 or node_a == node_b:
			continue
		var gap := Vector2(nodes[node_a]["position"]).distance_to(Vector2(nodes[node_b]["position"]))
		_add_graph_edge(edges, adjacency, edge_keys, node_a, node_b, {
			"kind": "weld",
			"path_index": -1,
			"source_index": -1,
			"from_arc": 0.0,
			"to_arc": 0.0,
			"length": maxf(0.05, gap * 0.25),
		})
	return {
		"nodes": nodes,
		"edges": edges,
		"adjacency": adjacency,
	}


static func _append_contact(
	contacts: Array[Dictionary],
	events: Array,
	first: Dictionary,
	first_t: float,
	second: Dictionary,
	second_t: float
) -> void:
	var path_a := int(first["path_index"])
	var path_b := int(second["path_index"])
	var arc_a := float(first["arc0"]) + clampf(first_t, 0.0, 1.0) * float(first["length"])
	var arc_b := float(second["arc0"]) + clampf(second_t, 0.0, 1.0) * float(second["length"])
	if path_a == path_b and absf(arc_a - arc_b) <= ARC_EPSILON:
		return
	(events[path_a] as Array).append(arc_a)
	(events[path_b] as Array).append(arc_b)
	contacts.append({"path_a": path_a, "arc_a": arc_a, "path_b": path_b, "arc_b": arc_b})


static func _append_projected_contact(
	contacts: Array[Dictionary],
	events: Array,
	endpoint_segment: Dictionary,
	endpoint_t: float,
	target_segment: Dictionary,
	weld_radius: float
) -> void:
	var point := Vector2(endpoint_segment["a"]).lerp(Vector2(endpoint_segment["b"]), endpoint_t)
	var target_a := Vector2(target_segment["a"])
	var target_b := Vector2(target_segment["b"])
	var target_delta := target_b - target_a
	var denominator := target_delta.length_squared()
	if denominator <= GEOMETRY_EPSILON:
		return
	var projection_t := clampf((point - target_a).dot(target_delta) / denominator, 0.0, 1.0)
	var projection := target_a.lerp(target_b, projection_t)
	if point.distance_squared_to(projection) > weld_radius * weld_radius:
		return
	_append_contact(contacts, events, endpoint_segment, endpoint_t, target_segment, projection_t)


static func _deduplicate_contacts(contacts: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var keys := {}
	for value in contacts:
		var contact := value as Dictionary
		var path_a := int(contact["path_a"])
		var path_b := int(contact["path_b"])
		var arc_a := float(contact["arc_a"])
		var arc_b := float(contact["arc_b"])
		if path_a > path_b or (path_a == path_b and arc_a > arc_b):
			var swap_path := path_a
			path_a = path_b
			path_b = swap_path
			var swap_arc := arc_a
			arc_a = arc_b
			arc_b = swap_arc
		var key := "%d:%d:%d:%d" % [path_a, roundi(arc_a * 100.0), path_b, roundi(arc_b * 100.0)]
		if keys.has(key):
			continue
		keys[key] = true
		result.append({"path_a": path_a, "arc_a": arc_a, "path_b": path_b, "arc_b": arc_b})
	return result


static func _add_graph_edge(
	edges: Array[Dictionary],
	adjacency: Array,
	edge_keys: Dictionary,
	from_id: int,
	to_id: int,
	data: Dictionary
) -> void:
	var low := mini(from_id, to_id)
	var high := maxi(from_id, to_id)
	var key := "%d:%d:%s:%d" % [low, high, String(data.get("kind", "")), int(data.get("path_index", -1))]
	if edge_keys.has(key):
		return
	edge_keys[key] = true
	var edge_index := edges.size()
	var edge := data.duplicate()
	edge["a"] = from_id
	edge["b"] = to_id
	edges.append(edge)
	(adjacency[from_id] as Array).append({"to": to_id, "edge": edge_index})
	(adjacency[to_id] as Array).append({"to": from_id, "edge": edge_index})


static func _select_structural_component(nodes: Array, adjacency: Array, drawing_bounds: Rect2) -> Array[int]:
	var visited := {}
	var best: Array[int] = []
	var best_score := -INF
	var drawing_center := drawing_bounds.get_center()
	var diagonal := maxf(1.0, drawing_bounds.size.length())
	for start in range(nodes.size()):
		if visited.has(start):
			continue
		var queue: Array[int] = [start]
		var component: Array[int] = []
		visited[start] = true
		while not queue.is_empty():
			var current: int = queue.pop_front()
			component.append(current)
			for link_value in adjacency[current]:
				var neighbor := int((link_value as Dictionary)["to"])
				if not visited.has(neighbor):
					visited[neighbor] = true
					queue.append(neighbor)
		var leaves := 0
		var branches := 0
		var center := Vector2.ZERO
		for node_index in component:
			var degree := (adjacency[node_index] as Array).size()
			leaves += 1 if degree == 1 else 0
			branches += 1 if degree >= 3 else 0
			center += Vector2(nodes[node_index]["position"])
		center /= maxf(1.0, float(component.size()))
		var centrality := 1.0 - minf(1.0, center.distance_to(drawing_center) / diagonal)
		var score := float(leaves * 1000 + branches * 180 + component.size()) + centrality * 40.0
		if score > best_score:
			best_score = score
			best = component
	return best


static func _find_core_nodes(
	component: Array[int],
	component_set: Dictionary,
	nodes: Array,
	adjacency: Array,
	drawing_bounds: Rect2,
	weld_radius: float
) -> Dictionary:
	var remaining := component_set.duplicate()
	var degrees := {}
	var queue: Array[int] = []
	for node_index in component:
		var degree := _component_degree(node_index, component_set, adjacency)
		degrees[node_index] = degree
		if degree <= 1:
			queue.append(node_index)
	while not queue.is_empty():
		var current: int = queue.pop_front()
		if not remaining.has(current):
			continue
		remaining.erase(current)
		for link_value in adjacency[current]:
			var neighbor := int((link_value as Dictionary)["to"])
			if not remaining.has(neighbor):
				continue
			degrees[neighbor] = int(degrees.get(neighbor, 0)) - 1
			if int(degrees[neighbor]) <= 1:
				queue.append(neighbor)

	var drawing_center := drawing_bounds.get_center()
	# A dense resampled drawing can create many tiny proximity cycles along a leg;
	# the raw 2-core therefore is not, by itself, a torso. Restrict it to the
	# central body band before extracting core-to-leaf routes. The band is wide
	# enough for a closed oval but shallow enough to reject distal leg arcs.
	var horizontal_limit := maxf(weld_radius * 2.5, drawing_bounds.size.x * 0.30)
	var vertical_limit := maxf(weld_radius * 2.5, drawing_bounds.size.y * 0.28)
	var core := {}
	for node_index_value in remaining:
		var node_index := int(node_index_value)
		var position := Vector2(nodes[node_index]["position"])
		if absf(position.x - drawing_center.x) <= horizontal_limit \
		and absf(position.y - drawing_center.y) <= vertical_limit:
			core[node_index] = true
	for node_index in component:
		var degree := _component_degree(node_index, component_set, adjacency)
		var position := Vector2(nodes[node_index]["position"])
		if degree >= 3 and absf(position.x - drawing_center.x) <= horizontal_limit \
		and absf(position.y - drawing_center.y) <= vertical_limit:
			core[node_index] = true
	if core.is_empty():
		var nearest := -1
		var nearest_distance := INF
		for node_index in component:
			var distance := Vector2(nodes[node_index]["position"]).distance_squared_to(drawing_center)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = node_index
		if nearest >= 0:
			core[nearest] = true
	return core


static func _shortest_route_to_core(
	start: int,
	core_set: Dictionary,
	component_set: Dictionary,
	nodes: Array,
	edges: Array,
	adjacency: Array
) -> Dictionary:
	var distances := {}
	var previous_node := {}
	var previous_edge := {}
	var pending := component_set.duplicate()
	for node_index in component_set:
		distances[node_index] = INF
	distances[start] = 0.0
	var destination := -1
	while not pending.is_empty():
		var current := -1
		var current_distance := INF
		for node_index_value in pending:
			var node_index := int(node_index_value)
			var distance := float(distances.get(node_index, INF))
			if distance < current_distance:
				current = node_index
				current_distance = distance
		if current < 0 or current_distance == INF:
			break
		pending.erase(current)
		if current != start and core_set.has(current):
			destination = current
			break
		for link_value in adjacency[current]:
			var link := link_value as Dictionary
			var neighbor := int(link["to"])
			if not pending.has(neighbor):
				continue
			var edge_index := int(link["edge"])
			var edge := edges[edge_index] as Dictionary
			var candidate_distance := current_distance + float(edge.get("length", 0.01))
			if candidate_distance < float(distances.get(neighbor, INF)):
				distances[neighbor] = candidate_distance
				previous_node[neighbor] = current
				previous_edge[neighbor] = edge_index
	if destination < 0:
		return {}

	var route_nodes: Array[int] = [destination]
	var route_edges: Array[int] = []
	var cursor := destination
	while cursor != start:
		if not previous_node.has(cursor):
			return {}
		route_edges.push_front(int(previous_edge[cursor]))
		cursor = int(previous_node[cursor])
		route_nodes.push_front(cursor)
	return {"nodes": route_nodes, "edges": route_edges}


static func _candidate_from_route(
	route: Dictionary,
	nodes: Array,
	edges: Array,
	paths: Array[Dictionary],
	core_center: Vector2
) -> Dictionary:
	if route.is_empty():
		return {}
	var route_nodes: Array = route.get("nodes", [])
	var route_edges: Array = route.get("edges", [])
	if route_nodes.size() < 2 or route_edges.is_empty():
		return {}

	# The final zero-length weld belongs to the attachment, not to the leg path.
	while not route_edges.is_empty() and String((edges[int(route_edges[route_edges.size() - 1])] as Dictionary).get("kind", "")) == "weld":
		route_edges.pop_back()
		route_nodes.pop_back()
	if route_nodes.size() < 2 or route_edges.is_empty():
		return {}

	var point_path := PackedVector2Array()
	for node_position_index in range(route_nodes.size() - 1, -1, -1):
		var point := Vector2(nodes[int(route_nodes[node_position_index])]["position"])
		if point_path.is_empty() or point_path[point_path.size() - 1].distance_squared_to(point) > GEOMETRY_EPSILON:
			point_path.append(point)
	if point_path.size() < 2:
		return {}

	var ink_length := 0.0
	var ranges: Array[Dictionary] = []
	var source_indices: Array[int] = []
	var primary_path := -1
	for edge_index_value in route_edges:
		var edge := edges[int(edge_index_value)] as Dictionary
		if String(edge.get("kind", "")) != "ink":
			continue
		ink_length += float(edge.get("length", 0.0))
		var path_index := int(edge.get("path_index", -1))
		if primary_path < 0:
			primary_path = path_index
		var source_index := int(edge.get("source_index", -1))
		if source_index >= 0 and not source_indices.has(source_index):
			source_indices.append(source_index)
		ranges.append({
			"path_index": path_index,
			"from_arc": minf(float(edge.get("from_arc", 0.0)), float(edge.get("to_arc", 0.0))),
			"to_arc": maxf(float(edge.get("from_arc", 0.0)), float(edge.get("to_arc", 0.0))),
		})
	if primary_path < 0 or ink_length <= GEOMETRY_EPSILON:
		return {}

	# A leg may be a single straight source segment. It is still valid anatomy:
	# insert the exact arc-length midpoint on that drawn segment so the runtime has
	# a real articulation point instead of silently dropping the leg.
	var articulation := _articulated_path(point_path)
	point_path = PackedVector2Array(articulation.get("path", point_path))
	var bend_index := int(articulation.get("bend_index", 0))
	var primary_info := paths[primary_path]
	var ink_paths := _ink_paths_from_route(route_nodes, route_edges, nodes, edges, paths)
	var owners: Array = []
	for range_value in _merge_ranges(ranges):
		var range_info := range_value as Dictionary
		var owner_path := int(range_info.get("path_index", primary_path))
		var owner_info := paths[owner_path]
		owners.append({
			"source_index": int(owner_info.get("source_index", -1)),
			"from_arc": float(range_info.get("from_arc", 0.0)),
			"to_arc": float(range_info.get("to_arc", 0.0)),
			"width": float(owner_info.get("width", 5.0)),
			"color": Color(owner_info.get("color", Color.BLACK)),
		})
	source_indices.sort()
	return {
		"path": point_path,
		"root": point_path[0],
		"sole": point_path[point_path.size() - 1],
		"side": 0,
		"side_rank": 0,
		"phase_group": 0,
		"support_candidate": false,
		"bend_index": bend_index,
		"source_index": int(primary_info.get("source_index", -1)),
		"source_indices": source_indices,
		"path_owners": owners,
		"ink_paths": ink_paths,
		"width": float(primary_info.get("width", 5.0)),
		"color": Color(primary_info.get("color", Color.BLACK)),
		"ink_length": ink_length,
		"graph_ranges": ranges,
		"radial_distance": point_path[point_path.size() - 1].distance_to(core_center),
	}


static func _ink_paths_from_route(
	route_nodes: Array,
	route_edges: Array,
	nodes: Array,
	edges: Array,
	paths: Array[Dictionary]
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var merge_with_previous := false
	# route_edges run leaf -> core; render pieces in the public leg direction,
	# core -> sole. Weld edges separate pieces and are never rendered/collided.
	for route_index in range(route_edges.size() - 1, -1, -1):
		var edge := edges[int(route_edges[route_index])] as Dictionary
		if String(edge.get("kind", "")) != "ink":
			merge_with_previous = false
			continue
		var path_index := int(edge.get("path_index", -1))
		if path_index < 0 or path_index >= paths.size():
			continue
		var from_node := nodes[int(route_nodes[route_index + 1])] as Dictionary
		var to_node := nodes[int(route_nodes[route_index])] as Dictionary
		if int(from_node.get("path_index", -1)) != path_index or int(to_node.get("path_index", -1)) != path_index:
			continue
		var from_arc := float(from_node.get("arc", 0.0))
		var to_arc := float(to_node.get("arc", 0.0))
		var info := paths[path_index]
		var piece := _slice_path(info, minf(from_arc, to_arc), maxf(from_arc, to_arc))
		if from_arc > to_arc:
			var reversed := PackedVector2Array()
			for point_index in range(piece.size() - 1, -1, -1):
				reversed.append(piece[point_index])
			piece = reversed
		if piece.size() < 2 or _polyline_length(piece) <= ARC_EPSILON:
			continue
		var source_index := int(info.get("source_index", -1))
		# Consecutive graph edges on the same source interval are one visible path.
		# A weld resets continuity because its gap is topology only, never player ink.
		if merge_with_previous and not result.is_empty():
			var previous := result[result.size() - 1]
			var previous_points := PackedVector2Array(previous.get("points", PackedVector2Array()))
			if int(previous.get("path_index", -1)) == path_index \
			and not previous_points.is_empty() \
			and previous_points[previous_points.size() - 1].distance_squared_to(piece[0]) <= GEOMETRY_EPSILON:
				for point_index in range(1, piece.size()):
					previous_points.append(piece[point_index])
				previous["points"] = previous_points
				previous["to_arc"] = to_arc
				merge_with_previous = true
				continue
		result.append({
			"points": piece,
			"path_index": path_index,
			"source_index": source_index,
			"from_arc": from_arc,
			"to_arc": to_arc,
			"width": float(info.get("width", 5.0)),
			"color": Color(info.get("color", Color.BLACK)),
		})
		merge_with_previous = true
	return result


static func _deduplicate_candidates(candidates: Array[Dictionary], weld_radius: float) -> Array[Dictionary]:
	candidates.sort_custom(_candidate_score_less)
	var result: Array[Dictionary] = []
	for candidate in candidates:
		var duplicate := false
		var root := Vector2(candidate.get("root", Vector2.ZERO))
		var sole := Vector2(candidate.get("sole", Vector2.ZERO))
		for accepted in result:
			if root.distance_to(Vector2(accepted.get("root", Vector2.ZERO))) <= weld_radius * 0.7 \
			and sole.distance_to(Vector2(accepted.get("sole", Vector2.ZERO))) <= weld_radius:
				duplicate = true
				break
		if not duplicate:
			result.append(candidate)
	return result


static func _assign_sides_and_ranks(legs: Array[Dictionary], center: Vector2, diagonal: float) -> void:
	var ambiguous: Array[Dictionary] = []
	var left: Array[Dictionary] = []
	var right: Array[Dictionary] = []
	var side_dead_zone := diagonal * 0.012
	for leg in legs:
		var root := Vector2(leg.get("root", center))
		var sole := Vector2(leg.get("sole", center))
		var side_value := ((sole.x - center.x) * 0.8) + ((root.x - center.x) * 0.2)
		if side_value < -side_dead_zone:
			leg["side"] = -1
			left.append(leg)
		elif side_value > side_dead_zone:
			leg["side"] = 1
			right.append(leg)
		else:
			leg["side_metric"] = side_value
			ambiguous.append(leg)
	ambiguous.sort_custom(_ambiguous_leg_less)
	for leg in ambiguous:
		if left.size() <= right.size():
			leg["side"] = -1
			left.append(leg)
		else:
			leg["side"] = 1
			right.append(leg)
		leg.erase("side_metric")
	left.sort_custom(_side_rank_less)
	right.sort_custom(_side_rank_less)
	for rank in range(left.size()):
		left[rank]["side_rank"] = rank
		left[rank]["phase_group"] = rank % 2
	for rank in range(right.size()):
		right[rank]["side_rank"] = rank
		right[rank]["phase_group"] = (rank + 1) % 2


static func _mark_support_candidates(legs: Array[Dictionary], diagonal: float) -> void:
	if legs.is_empty():
		return
	var lowest_y := -INF
	for leg in legs:
		lowest_y = maxf(lowest_y, Vector2(leg.get("sole", Vector2.ZERO)).y)
	var band := maxf(6.0, diagonal * 0.10)
	var support_count := 0
	for leg in legs:
		var supported := Vector2(leg.get("sole", Vector2.ZERO)).y >= lowest_y - band
		leg["support_candidate"] = supported
		support_count += 1 if supported else 0

	# A broad spider needs a useful polygon, not a single mathematically-lowest
	# pixel. Six- and eight-leg drawings reserve the four lowest real soles.
	var minimum_count := mini(legs.size(), 4 if legs.size() >= 6 else 2)
	if support_count < minimum_count:
		var by_height := legs.duplicate()
		by_height.sort_custom(_sole_height_less)
		for leg in by_height:
			if not bool((leg as Dictionary).get("support_candidate", false)):
				(leg as Dictionary)["support_candidate"] = true
				support_count += 1
				if support_count >= minimum_count:
					break

	for side in [-1, 1]:
		var lowest: Dictionary = {}
		for leg in legs:
			if int(leg.get("side", 0)) != side:
				continue
			if lowest.is_empty() or Vector2(leg.get("sole", Vector2.ZERO)).y > Vector2(lowest.get("sole", Vector2.ZERO)).y:
				lowest = leg
		if not lowest.is_empty():
			lowest["support_candidate"] = true

	# Uneven 4–8-leg drawings can place both side-lowest feet in one alternating
	# phase. Guarantee each phase has at least one actual low sole so the gait can
	# hand support across groups without inventing a limb.
	for phase_group in [0, 1]:
		var lowest: Dictionary = {}
		for leg in legs:
			if int(leg.get("phase_group", -1)) != phase_group:
				continue
			if lowest.is_empty() or Vector2(leg.get("sole", Vector2.ZERO)).y > Vector2(lowest.get("sole", Vector2.ZERO)).y:
				lowest = leg
		if not lowest.is_empty():
			lowest["support_candidate"] = true


static func _collect_claimed_ranges(candidates: Array[Dictionary], graph_paths: Array[Dictionary]) -> Dictionary:
	var result := {}
	for candidate in candidates:
		for range_value in candidate.get("graph_ranges", []):
			var range_info := range_value as Dictionary
			var path_index := int(range_info.get("path_index", -1))
			if path_index < 0 or path_index >= graph_paths.size():
				continue
			if not result.has(path_index):
				result[path_index] = []
			(result[path_index] as Array).append({
				"path_index": path_index,
				"from_arc": float(range_info.get("from_arc", 0.0)),
				"to_arc": float(range_info.get("to_arc", 0.0)),
			})
	for path_index in result:
		result[path_index] = _merge_ranges(result[path_index])
	return result


static func _build_torso_paths(
	source_paths: Array[Dictionary],
	claims: Dictionary,
	core_set: Dictionary,
	nodes: Array,
	graph_paths: Array[Dictionary]
) -> Dictionary:
	var structural_paths: Array = []
	var structural_owners: Array = []
	var decoration_paths: Array = []
	var decoration_owners: Array = []
	for path_index in range(source_paths.size()):
		var info := source_paths[path_index]
		var length := float(info.get("length", 0.0))
		var claimed: Array = claims.get(path_index, [])
		var cursor := 0.0
		var complements: Array[Vector2] = []
		for range_value in claimed:
			var range_info := range_value as Dictionary
			var from_arc := clampf(float(range_info.get("from_arc", 0.0)), 0.0, length)
			var to_arc := clampf(float(range_info.get("to_arc", 0.0)), 0.0, length)
			if from_arc > cursor + ARC_EPSILON:
				complements.append(Vector2(cursor, from_arc))
			cursor = maxf(cursor, to_arc)
		if cursor < length - ARC_EPSILON:
			complements.append(Vector2(cursor, length))
		if claimed.is_empty():
			complements = [Vector2(0.0, length)]

		for interval in complements:
			var path := _slice_path(info, interval.x, interval.y)
			if path.size() < 2 or _polyline_length(path) <= ARC_EPSILON:
				continue
			var structural := _interval_touches_core(path_index, interval.x, interval.y, core_set, nodes, graph_paths)
			var owner := {
				"source_index": int(info.get("source_index", -1)),
				"from_arc": interval.x,
				"to_arc": interval.y,
				"width": float(info.get("width", 5.0)),
				"color": Color(info.get("color", Color.BLACK)),
				"kind": "core" if structural else "decoration",
			}
			if structural:
				structural_paths.append(path)
				structural_owners.append(owner)
			else:
				decoration_paths.append(path)
				decoration_owners.append(owner)

	# Keep the two disjoint path sets and their ownership aligned. The runtime
	# welds both to one torso body, but decorations are not counted as core when
	# deriving its center and stance height.
	var structural_pairs := _sort_owned_paths(structural_paths, structural_owners)
	structural_paths = structural_pairs["paths"]
	structural_owners = structural_pairs["owners"]
	var decoration_pairs := _sort_owned_paths(decoration_paths, decoration_owners)
	decoration_paths = decoration_pairs["paths"]
	decoration_owners = decoration_pairs["owners"]
	return {
		"paths": structural_paths,
		"owners": structural_owners,
		"structural_paths": structural_paths,
		"decoration_paths": decoration_paths,
		"decoration_owners": decoration_owners,
	}


static func _sort_owned_paths(paths: Array, owners: Array) -> Dictionary:
	var paired: Array[Dictionary] = []
	for index in range(paths.size()):
		paired.append({"path": paths[index], "owner": owners[index]})
	paired.sort_custom(_owned_path_less)
	var sorted_paths: Array = []
	var sorted_owners: Array = []
	for pair in paired:
		sorted_paths.append(pair["path"])
		sorted_owners.append(pair["owner"])
	return {"paths": sorted_paths, "owners": sorted_owners}


static func _interval_touches_core(
	path_index: int,
	from_arc: float,
	to_arc: float,
	core_set: Dictionary,
	nodes: Array,
	graph_paths: Array[Dictionary]
) -> bool:
	if path_index < 0 or path_index >= graph_paths.size():
		return false
	for node_index_value in core_set:
		var node := nodes[int(node_index_value)] as Dictionary
		if int(node.get("path_index", -1)) != path_index:
			continue
		var arc := float(node.get("arc", -INF))
		if arc >= from_arc - ARC_EPSILON and arc <= to_arc + ARC_EPSILON:
			return true
	return false


static func _support_height(legs: Array[Dictionary], torso_center: Vector2) -> float:
	var sole_heights: Array[float] = []
	for leg in legs:
		if bool(leg.get("support_candidate", false)):
			sole_heights.append(Vector2(leg.get("sole", torso_center)).y)
	if sole_heights.is_empty():
		return 0.0
	sole_heights.sort()
	var middle := sole_heights.size() / 2
	var floor_y := sole_heights[middle]
	if sole_heights.size() % 2 == 0:
		floor_y = (sole_heights[middle - 1] + sole_heights[middle]) * 0.5
	return maxf(1.0, floor_y - torso_center.y)


static func _articulated_path(path: PackedVector2Array) -> Dictionary:
	if path.size() < 2:
		return {"path": path.duplicate(), "bend_index": 0}
	var best_index := -1
	var best_turn := 0.0
	for index in range(1, path.size() - 1):
		var incoming := path[index] - path[index - 1]
		var outgoing := path[index + 1] - path[index]
		if incoming.length_squared() <= GEOMETRY_EPSILON or outgoing.length_squared() <= GEOMETRY_EPSILON:
			continue
		var turn := absf(incoming.angle_to(outgoing))
		if turn > best_turn:
			best_turn = turn
			best_index = index
	if best_index >= 0 and best_turn >= deg_to_rad(18.0):
		return {"path": path.duplicate(), "bend_index": best_index}

	# No clear drawn bend: split at the exact half-distance. If the midpoint is
	# already a sample, reuse it; otherwise insert a point on the existing ink.
	var half_length := _polyline_length(path) * 0.5
	var traveled := 0.0
	for index in range(1, path.size()):
		var segment_length := path[index - 1].distance_to(path[index])
		if traveled + segment_length + ARC_EPSILON < half_length:
			traveled += segment_length
			continue
		if absf(traveled + segment_length - half_length) <= ARC_EPSILON and index < path.size() - 1:
			return {"path": path.duplicate(), "bend_index": index}
		var ratio := clampf((half_length - traveled) / maxf(segment_length, ARC_EPSILON), 0.0, 1.0)
		var midpoint := path[index - 1].lerp(path[index], ratio)
		var articulated := PackedVector2Array()
		for point_index in range(path.size()):
			if point_index == index:
				articulated.append(midpoint)
			articulated.append(path[point_index])
		return {"path": articulated, "bend_index": index}
	return {"path": path.duplicate(), "bend_index": maxi(1, path.size() / 2)}


static func _merge_ranges(ranges: Array) -> Array[Dictionary]:
	var grouped := {}
	for value in ranges:
		var range_info := value as Dictionary
		var path_index := int(range_info.get("path_index", -1))
		if not grouped.has(path_index):
			grouped[path_index] = []
		(grouped[path_index] as Array).append({
			"path_index": path_index,
			"from_arc": minf(float(range_info.get("from_arc", 0.0)), float(range_info.get("to_arc", 0.0))),
			"to_arc": maxf(float(range_info.get("from_arc", 0.0)), float(range_info.get("to_arc", 0.0))),
		})
	var result: Array[Dictionary] = []
	for path_index in grouped:
		var path_ranges: Array = grouped[path_index]
		path_ranges.sort_custom(_range_less)
		for range_info_value in path_ranges:
			var range_info := range_info_value as Dictionary
			if result.is_empty() or int(result[result.size() - 1].get("path_index", -2)) != int(path_index) \
			or float(range_info.get("from_arc", 0.0)) > float(result[result.size() - 1].get("to_arc", 0.0)) + ARC_EPSILON:
				result.append(range_info.duplicate())
			else:
				result[result.size() - 1]["to_arc"] = maxf(
					float(result[result.size() - 1].get("to_arc", 0.0)),
					float(range_info.get("to_arc", 0.0))
				)
	return result


static func _slice_path(info: Dictionary, from_arc: float, to_arc: float) -> PackedVector2Array:
	var points := PackedVector2Array(info.get("points", PackedVector2Array()))
	var cumulative: Array = info.get("cumulative", [])
	var result := PackedVector2Array([_point_at_arc(info, from_arc)])
	for index in range(1, points.size() - 1):
		var arc := float(cumulative[index])
		if arc > from_arc + ARC_EPSILON and arc < to_arc - ARC_EPSILON:
			result.append(points[index])
	var final_point := _point_at_arc(info, to_arc)
	if result[result.size() - 1].distance_squared_to(final_point) > GEOMETRY_EPSILON:
		result.append(final_point)
	return result


static func _point_at_arc(info: Dictionary, requested_arc: float) -> Vector2:
	var points := PackedVector2Array(info.get("points", PackedVector2Array()))
	var cumulative: Array = info.get("cumulative", [])
	if points.is_empty():
		return Vector2.ZERO
	var arc := clampf(requested_arc, 0.0, float(info.get("length", 0.0)))
	for index in range(points.size() - 1):
		var from_arc := float(cumulative[index])
		var to_arc := float(cumulative[index + 1])
		if arc <= to_arc + ARC_EPSILON:
			var span := maxf(GEOMETRY_EPSILON, to_arc - from_arc)
			return points[index].lerp(points[index + 1], clampf((arc - from_arc) / span, 0.0, 1.0))
	return points[points.size() - 1]


static func _node_for_arc(path_events: Array, node_ids: Array, arc: float) -> int:
	var best := -1
	var best_gap := INF
	for index in range(path_events.size()):
		var gap := absf(float(path_events[index]) - arc)
		if gap < best_gap:
			best_gap = gap
			best = int(node_ids[index])
	return best


static func _segments_are_neighbors(first: Dictionary, second: Dictionary, _paths: Array[Dictionary]) -> bool:
	if int(first["path_index"]) != int(second["path_index"]):
		return false
	# Consecutive segments already share their endpoint through the ink edge.
	# Non-adjacent segments are still checked for an exact self-intersection by the
	# caller, which preserves topology for a spider drawn as one continuous stroke.
	return absi(int(first["segment_index"]) - int(second["segment_index"])) <= 1


static func _expanded_segments_overlap(first: Dictionary, second: Dictionary, radius: float) -> bool:
	var first_a := Vector2(first["a"])
	var first_b := Vector2(first["b"])
	var second_a := Vector2(second["a"])
	var second_b := Vector2(second["b"])
	var first_min := first_a.min(first_b) - Vector2(radius, radius)
	var first_max := first_a.max(first_b) + Vector2(radius, radius)
	var second_min := second_a.min(second_b)
	var second_max := second_a.max(second_b)
	return first_max.x >= second_min.x and first_min.x <= second_max.x \
		and first_max.y >= second_min.y and first_min.y <= second_max.y


static func _segment_intersection(first: Dictionary, second: Dictionary) -> Dictionary:
	var a := Vector2(first["a"])
	var b := Vector2(first["b"])
	var c := Vector2(second["a"])
	var d := Vector2(second["b"])
	var r := b - a
	var s := d - c
	var denominator := _cross(r, s)
	if absf(denominator) <= GEOMETRY_EPSILON:
		return {}
	var t := _cross(c - a, s) / denominator
	var u := _cross(c - a, r) / denominator
	if t < -GEOMETRY_EPSILON or t > 1.0 + GEOMETRY_EPSILON \
	or u < -GEOMETRY_EPSILON or u > 1.0 + GEOMETRY_EPSILON:
		return {}
	return {"t": clampf(t, 0.0, 1.0), "u": clampf(u, 0.0, 1.0)}


static func _cross(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x


static func _component_degree(node_index: int, component_set: Dictionary, adjacency: Array) -> int:
	var degree := 0
	for link_value in adjacency[node_index]:
		if component_set.has(int((link_value as Dictionary)["to"])):
			degree += 1
	return degree


static func _index_set(values: Array) -> Dictionary:
	var result := {}
	for value in values:
		result[int(value)] = true
	return result


static func _center_for_node_set(node_set: Dictionary, nodes: Array) -> Vector2:
	var center := Vector2.ZERO
	for node_index in node_set:
		center += Vector2(nodes[int(node_index)]["position"])
	return center / maxf(1.0, float(node_set.size()))


static func _cumulative_lengths(points: PackedVector2Array) -> Array[float]:
	var result: Array[float] = [0.0]
	for index in range(1, points.size()):
		result.append(result[result.size() - 1] + points[index - 1].distance_to(points[index]))
	return result


static func _polyline_length(points: PackedVector2Array) -> float:
	var length := 0.0
	for index in range(1, points.size()):
		length += points[index - 1].distance_to(points[index])
	return length


static func _total_path_length(infos: Array[Dictionary]) -> float:
	var result := 0.0
	for info in infos:
		result += float(info.get("length", 0.0))
	return result


static func _resample_polyline(points: PackedVector2Array, step: float) -> PackedVector2Array:
	if points.size() < 2 or step <= GEOMETRY_EPSILON:
		return points.duplicate()
	var result := PackedVector2Array([points[0]])
	var distance_to_next := step
	for index in range(1, points.size()):
		var start := points[index - 1]
		var finish := points[index]
		var segment_length := start.distance_to(finish)
		while segment_length >= distance_to_next and segment_length > GEOMETRY_EPSILON:
			start = start.lerp(finish, distance_to_next / segment_length)
			result.append(start)
			segment_length = start.distance_to(finish)
			distance_to_next = step
		distance_to_next -= segment_length
	if result[result.size() - 1].distance_squared_to(points[points.size() - 1]) > GEOMETRY_EPSILON:
		result.append(points[points.size() - 1])
	return result


static func _bounds_for_infos(infos: Array[Dictionary]) -> Rect2:
	var paths: Array = []
	for info in infos:
		paths.append(info.get("points", PackedVector2Array()))
	return _bounds_for_paths(paths)


static func _bounds_for_paths(paths: Array) -> Rect2:
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	var found := false
	for path_value in paths:
		if not (path_value is PackedVector2Array):
			continue
		for point in path_value as PackedVector2Array:
			minimum = minimum.min(point)
			maximum = maximum.max(point)
			found = true
	if not found:
		return Rect2()
	return Rect2(minimum, maximum - minimum)


static func _polyline_collection_center(paths: Array) -> Vector2:
	var weighted_center := Vector2.ZERO
	var total_length := 0.0
	for path_value in paths:
		if not (path_value is PackedVector2Array):
			continue
		var path := path_value as PackedVector2Array
		for index in range(1, path.size()):
			var length := path[index - 1].distance_to(path[index])
			weighted_center += (path[index - 1] + path[index]) * 0.5 * length
			total_length += length
	if total_length <= GEOMETRY_EPSILON:
		return Vector2.ZERO
	return weighted_center / total_length


static func _range_less(a: Dictionary, b: Dictionary) -> bool:
	var a_path := int(a.get("path_index", -1))
	var b_path := int(b.get("path_index", -1))
	if a_path != b_path:
		return a_path < b_path
	return float(a.get("from_arc", 0.0)) < float(b.get("from_arc", 0.0))


static func _candidate_score_less(a: Dictionary, b: Dictionary) -> bool:
	var score_a := float(a.get("score", 0.0))
	var score_b := float(b.get("score", 0.0))
	if not is_equal_approx(score_a, score_b):
		return score_a > score_b
	return _candidate_geometry_less(a, b)


static func _candidate_geometry_less(a: Dictionary, b: Dictionary) -> bool:
	var a_sole := Vector2(a.get("sole", Vector2.ZERO))
	var b_sole := Vector2(b.get("sole", Vector2.ZERO))
	if not is_equal_approx(a_sole.x, b_sole.x):
		return a_sole.x < b_sole.x
	if not is_equal_approx(a_sole.y, b_sole.y):
		return a_sole.y < b_sole.y
	var a_root := Vector2(a.get("root", Vector2.ZERO))
	var b_root := Vector2(b.get("root", Vector2.ZERO))
	if not is_equal_approx(a_root.x, b_root.x):
		return a_root.x < b_root.x
	return a_root.y < b_root.y


static func _side_rank_less(a: Dictionary, b: Dictionary) -> bool:
	var a_root := Vector2(a.get("root", Vector2.ZERO))
	var b_root := Vector2(b.get("root", Vector2.ZERO))
	if not is_equal_approx(a_root.y, b_root.y):
		return a_root.y < b_root.y
	var a_sole := Vector2(a.get("sole", Vector2.ZERO))
	var b_sole := Vector2(b.get("sole", Vector2.ZERO))
	if not is_equal_approx(a_sole.y, b_sole.y):
		return a_sole.y < b_sole.y
	return a_sole.x < b_sole.x


static func _leg_order_less(a: Dictionary, b: Dictionary) -> bool:
	var a_side := int(a.get("side", 0))
	var b_side := int(b.get("side", 0))
	if a_side != b_side:
		return a_side < b_side
	return int(a.get("side_rank", 0)) < int(b.get("side_rank", 0))


static func _ambiguous_leg_less(a: Dictionary, b: Dictionary) -> bool:
	var a_metric := float(a.get("side_metric", 0.0))
	var b_metric := float(b.get("side_metric", 0.0))
	if not is_equal_approx(a_metric, b_metric):
		return a_metric < b_metric
	return _candidate_geometry_less(a, b)


static func _sole_height_less(a: Dictionary, b: Dictionary) -> bool:
	var a_sole := Vector2(a.get("sole", Vector2.ZERO))
	var b_sole := Vector2(b.get("sole", Vector2.ZERO))
	if not is_equal_approx(a_sole.y, b_sole.y):
		return a_sole.y > b_sole.y
	return a_sole.x < b_sole.x


static func _node_index_geometry_less(a: int, b: int, nodes: Array) -> bool:
	var point_a := Vector2(nodes[a]["position"])
	var point_b := Vector2(nodes[b]["position"])
	if not is_equal_approx(point_a.x, point_b.x):
		return point_a.x < point_b.x
	return point_a.y < point_b.y


static func _owned_path_less(a: Dictionary, b: Dictionary) -> bool:
	return _polyline_less(a.get("path", PackedVector2Array()), b.get("path", PackedVector2Array()))


static func _polyline_less(a_value: Variant, b_value: Variant) -> bool:
	var a := PackedVector2Array(a_value)
	var b := PackedVector2Array(b_value)
	if a.is_empty():
		return not b.is_empty()
	if b.is_empty():
		return false
	var a_min := _polyline_minimum(a)
	var b_min := _polyline_minimum(b)
	if not is_equal_approx(a_min.x, b_min.x):
		return a_min.x < b_min.x
	if not is_equal_approx(a_min.y, b_min.y):
		return a_min.y < b_min.y
	return _polyline_length(a) < _polyline_length(b)


static func _polyline_minimum(path: PackedVector2Array) -> Vector2:
	var result := Vector2(INF, INF)
	for point in path:
		if point.x < result.x or (is_equal_approx(point.x, result.x) and point.y < result.y):
			result = point
	return result
