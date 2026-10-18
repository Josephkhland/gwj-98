@tool
class_name SignalNetworkGraph
extends Node
## Place vertices below this node. Nested graphs are independent.
signal connectivity_changed(connected_house_pairs: int, total_house_pairs: int)
## Also logged with push_error; allows game code to handle lookup failures.
signal lookup_failed(identifier: StringName, message: String)
var connected_house_pairs: int = 0
var total_house_pairs: int = 0
var _vertices: Array[SignalNetworkVertex] = []
var _components: Dictionary = {}
var _watched: Array[SignalNetworkVertex] = []
var _pending: bool = false
var _adjacency: Dictionary = {}
var _topology: Array = []
var _initialized: bool = false
var _identifier_index: Dictionary = {}
var _duplicate_identifiers: Dictionary = {}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	get_tree().tree_changed.connect(_schedule_rebuild)
	rebuild()

func _exit_tree() -> void:
	for vertex in _watched:
		if is_instance_valid(vertex) and vertex.availability_changed.is_connected(_schedule_rebuild):
			vertex.availability_changed.disconnect(_schedule_rebuild)
		if is_instance_valid(vertex) and vertex.identifier_changed.is_connected(_schedule_rebuild):
			vertex.identifier_changed.disconnect(_schedule_rebuild)

func _schedule_rebuild() -> void:
	if not _pending:
		_pending = true
		call_deferred("_flush_pending")

func _flush_pending() -> void:
	if _pending:
		rebuild()

func get_vertices() -> Array[SignalNetworkVertex]:
	var result: Array[SignalNetworkVertex] = []
	_collect(self, result)
	return result

func _collect(parent: Node, result: Array[SignalNetworkVertex]) -> void:
	for child in parent.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is SignalNetworkGraph:
			continue
		if child is SignalNetworkVertex:
			result.append(child)
		_collect(child, result)

func rebuild() -> void:
	_pending = false
	for vertex in _watched:
		if is_instance_valid(vertex) and vertex.availability_changed.is_connected(_schedule_rebuild):
			vertex.availability_changed.disconnect(_schedule_rebuild)
		if is_instance_valid(vertex) and vertex.identifier_changed.is_connected(_schedule_rebuild):
			vertex.identifier_changed.disconnect(_schedule_rebuild)
	_vertices = get_vertices()
	_watched = _vertices.duplicate()
	_components.clear()
	_adjacency.clear()
	_identifier_index.clear()
	_duplicate_identifiers.clear()
	var houses: int = 0
	for vertex in _vertices:
		vertex.availability_changed.connect(_schedule_rebuild)
		vertex.identifier_changed.connect(_schedule_rebuild)
		var key := vertex.key_identifier
		if not key.is_empty():
			if _identifier_index.has(key) or _duplicate_identifiers.has(key):
				_identifier_index.erase(key)
				_duplicate_identifiers[key] = true
			else:
				_identifier_index[key] = vertex
		_adjacency[vertex] = []
		if vertex.is_house():
			houses += 1
	for vertex in _vertices:
		for path in vertex.connections:
			var target := vertex.get_node_or_null(path)
			if target != vertex and _adjacency.has(target):
				_adjacency[vertex].append(target)
				_adjacency[target].append(vertex)
	connected_house_pairs = 0
	total_house_pairs = houses * (houses - 1) / 2
	var component: int = 0
	for vertex in _vertices:
		if not vertex.is_available() or _components.has(vertex):
			continue
		var queue: Array = [vertex]
		_components[vertex] = component
		var head: int = 0
		var house_count: int = 0
		while head < queue.size():
			var current: SignalNetworkVertex = queue[head]
			head += 1
			if current.is_house():
				house_count += 1
			for neighbor in _adjacency[current]:
				if neighbor.is_available() and not _components.has(neighbor):
					_components[neighbor] = component
					queue.append(neighbor)
		connected_house_pairs += house_count * (house_count - 1) / 2
		component += 1
	_topology = _capture_topology(_vertices)
	_initialized = true
	connectivity_changed.emit(connected_house_pairs, total_house_pairs)

## Also detect direct/in-place edits to exported connection arrays and changed paths.
func _capture_topology(vertices: Array[SignalNetworkVertex]) -> Array:
	var snapshot: Array = []
	for vertex in vertices:
		var targets: Array = []
		for path in vertex.connections:
			var target := vertex.get_node_or_null(path)
			targets.append(target.get_instance_id() if is_instance_valid(target) else 0)
		snapshot.append([vertex.get_instance_id(), vertex.key_identifier, vertex.is_available(), vertex.is_house(), vertex.connections.duplicate(), targets])
	return snapshot

func _ensure_current() -> void:
	if not _initialized or _pending or _capture_topology(get_vertices()) != _topology:
		rebuild()

func are_connected(a: SignalNetworkVertex, b: SignalNetworkVertex) -> bool:
	_ensure_current()
	return _connected_in_snapshot(a, b)

func _connected_in_snapshot(a: SignalNetworkVertex, b: SignalNetworkVertex) -> bool:
	return is_instance_valid(a) and is_instance_valid(b) and _components.has(a) and _components.has(b) and _components[a] == _components[b]

func are_houses_connected(source: SignalNetworkHouse, destination: SignalNetworkHouse) -> bool:
	return are_connected(source, destination)

## Eligible recipients now; this does not send or animate a message.
func get_broadcast_recipients(source: SignalNetworkHouse, include_source: bool = false) -> Array[SignalNetworkHouse]:
	_ensure_current()
	var recipients: Array[SignalNetworkHouse] = []
	if not is_instance_valid(source) or not _components.has(source):
		return recipients
	for vertex in _vertices:
		if vertex is SignalNetworkHouse and (include_source or vertex != source) and _connected_in_snapshot(source, vertex):
			recipients.append(vertex)
	return recipients

## Shortest route by edge count, including both endpoints. Empty means no route.
func get_house_path(source: SignalNetworkHouse, destination: SignalNetworkHouse) -> Array[SignalNetworkVertex]:
	_ensure_current()
	var path: Array[SignalNetworkVertex] = []
	if not _connected_in_snapshot(source, destination):
		return path
	var queue: Array[SignalNetworkVertex] = [source]
	var previous: Dictionary = {source: null}
	var head: int = 0
	while head < queue.size():
		var current := queue[head]
		head += 1
		if current == destination:
			break
		for neighbor in _adjacency[current]:
			if _components.has(neighbor) and not previous.has(neighbor):
				previous[neighbor] = current
				queue.append(neighbor)
	var step: SignalNetworkVertex = destination
	while step != null:
		path.append(step)
		step = previous[step]
	path.reverse()
	return path

## Minimum repair cost across any source/target pair. Broken routers cost one;
## healthy vertices cost zero. Equal repair costs prefer fewer links.
func get_minimum_repair_path(sources: Array[SignalNetworkHouse], targets: Array[SignalNetworkHouse]) -> Array[SignalNetworkVertex]:
	_ensure_current()
	var distances: Dictionary = {}
	var hops: Dictionary = {}
	var previous: Dictionary = {}
	var pending: Array[SignalNetworkVertex] = []
	for source in sources:
		if is_instance_valid(source) and _adjacency.has(source) and source.is_available() and not distances.has(source):
			distances[source] = 0
			hops[source] = 0
			previous[source] = null
			pending.append(source)
	while not pending.is_empty():
		var best := 0
		for index in range(1, pending.size()):
			var candidate := pending[index]
			var chosen := pending[best]
			if distances[candidate] < distances[chosen] or (distances[candidate] == distances[chosen] and hops[candidate] < hops[chosen]):
				best = index
		var current: SignalNetworkVertex = pending[best]
		pending.remove_at(best)
		if current is SignalNetworkHouse and current in targets:
			var path: Array[SignalNetworkVertex] = []
			var step: SignalNetworkVertex = current
			while step != null:
				path.append(step)
				step = previous[step]
			path.reverse()
			return path
		for neighbor: SignalNetworkVertex in _adjacency[current]:
			if not neighbor.is_available() and not neighbor is SignalNetworkRouter:
				continue
			var cost := int(distances[current]) + (1 if neighbor is SignalNetworkRouter and not neighbor.is_available() else 0)
			var length := int(hops[current]) + 1
			if not distances.has(neighbor) or cost < distances[neighbor] or (cost == distances[neighbor] and length < hops[neighbor]):
				distances[neighbor] = cost
				hops[neighbor] = length
				previous[neighbor] = current
				if neighbor not in pending:
					pending.append(neighbor)
	return []

## Ordered router subset of get_house_path(). Direct house links yield no routers.
func get_router_path(source: SignalNetworkHouse, destination: SignalNetworkHouse) -> Array[SignalNetworkRouter]:
	var routers: Array[SignalNetworkRouter] = []
	for vertex in get_house_path(source, destination):
		if vertex is SignalNetworkRouter:
			routers.append(vertex)
	return routers

## Keys never fall back to node names or display names. Ambiguous keys fail.
func get_vertex_by_key(identifier: StringName) -> SignalNetworkVertex:
	_ensure_current()
	return _resolve_vertex_key(identifier)

func _resolve_vertex_key(identifier: StringName) -> SignalNetworkVertex:
	if identifier.is_empty():
		_report_lookup_error(identifier, "Identifier must not be empty.")
		return null
	if _duplicate_identifiers.has(identifier):
		_report_lookup_error(identifier, "Duplicate identifier; assign unique keys within this graph.")
		return null
	if not _identifier_index.has(identifier):
		_report_lookup_error(identifier, "Unknown identifier in this graph.")
		return null
	return _identifier_index[identifier]

func get_house_by_key(identifier: StringName) -> SignalNetworkHouse:
	var vertex := get_vertex_by_key(identifier)
	if vertex == null:
		return null
	if not vertex is SignalNetworkHouse:
		_report_lookup_error(identifier, "Expected a house, but the identifier refers to another vertex type.")
		return null
	return vertex as SignalNetworkHouse

func get_router_by_key(identifier: StringName) -> SignalNetworkRouter:
	var vertex := get_vertex_by_key(identifier)
	if vertex == null:
		return null
	if not vertex is SignalNetworkRouter:
		_report_lookup_error(identifier, "Expected a router, but the identifier refers to another vertex type.")
		return null
	return vertex as SignalNetworkRouter

func are_houses_connected_by_key(source_key: StringName, destination_key: StringName) -> bool:
	var source := get_house_by_key(source_key)
	if source == null:
		return false
	var destination := get_house_by_key(destination_key)
	return destination != null and are_houses_connected(source, destination)

func get_broadcast_recipient_keys(source_key: StringName, include_source: bool = false) -> Array[StringName]:
	var source := get_house_by_key(source_key)
	if source == null:
		return []
	return _keys_for_vertices(get_broadcast_recipients(source, include_source))

func get_house_path_keys(source_key: StringName, destination_key: StringName) -> Array[StringName]:
	var source := get_house_by_key(source_key)
	if source == null:
		return []
	var destination := get_house_by_key(destination_key)
	if destination == null:
		return []
	return _keys_for_vertices(get_house_path(source, destination))

func get_router_path_keys(source_key: StringName, destination_key: StringName) -> Array[StringName]:
	var source := get_house_by_key(source_key)
	if source == null:
		return []
	var destination := get_house_by_key(destination_key)
	if destination == null:
		return []
	return _keys_for_vertices(get_router_path(source, destination))

func _keys_for_vertices(vertices: Array) -> Array[StringName]:
	var keys: Array[StringName] = []
	for vertex in vertices:
		var key: StringName = vertex.key_identifier
		if key.is_empty():
			_report_lookup_error(key, "Returned vertex '%s' has no key_identifier." % get_path_to(vertex))
			return []
		if _duplicate_identifiers.has(key):
			_report_lookup_error(key, "Returned vertex has a duplicate identifier; result cannot be addressed uniquely.")
			return []
		keys.append(key)
	return keys

func _report_lookup_error(identifier: StringName, message: String) -> void:
	var detail := "SignalNetworkGraph '%s', key '%s': %s" % [name, identifier, message]
	push_error(detail)
	lookup_failed.emit(identifier, detail)

## Authoring validation without logging; blank keys remain optional for node APIs.
func get_identifier_errors() -> Array[String]:
	var errors: Array[String] = []
	var seen: Dictionary = {}
	for vertex in get_vertices():
		var key := vertex.key_identifier
		if key.is_empty():
			continue
		if seen.has(key):
			errors.append("Duplicate key '%s': %s and %s" % [key, get_path_to(seen[key]), get_path_to(vertex)])
		else:
			seen[key] = vertex
	return errors
