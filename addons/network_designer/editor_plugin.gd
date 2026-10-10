@tool
extends EditorPlugin
var _panel: VBoxContainer
var _selected: SignalNetworkVertex
var _signature: String = ""
var _show_graph: bool = true

func _enter_tree() -> void:
	_panel = VBoxContainer.new()
	_panel.name = "Network Connections"
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _panel)
	set_force_draw_over_forwarding_enabled()
	get_editor_interface().get_selection().selection_changed.connect(_selection_changed)
	set_process(true)
	_selection_changed()

func _exit_tree() -> void:
	get_editor_interface().get_selection().selection_changed.disconnect(_selection_changed)
	remove_control_from_docks(_panel)
	_panel.queue_free()
	update_overlays()

func _handles(object: Object) -> bool:
	return object is SignalNetworkVertex

func _selection_changed() -> void:
	_selected = null
	for node in get_editor_interface().get_selection().get_selected_nodes():
		if node is SignalNetworkVertex:
			_selected = node
			break
	_signature = ""
	_refresh()

func _graph() -> SignalNetworkGraph:
	if not is_instance_valid(_selected):
		return null
	var parent := _selected.get_parent()
	while parent != null:
		if parent is SignalNetworkGraph:
			return parent
		parent = parent.get_parent()
	return null

func _process(_delta: float) -> void:
	var graph := _graph()
	var signature := ""
	if graph != null:
		for vertex in graph.get_vertices():
			signature += str(vertex.get_path(), vertex.get_label(), _read_identifier(vertex), vertex.connections)
	if signature != _signature:
		_signature = signature
		_refresh()
	if _show_graph:
		update_overlays()

func _refresh() -> void:
	for child in _panel.get_children():
		_panel.remove_child(child)
		child.queue_free()
	var visibility := CheckBox.new()
	visibility.text = "Show all network connections"
	visibility.button_pressed = _show_graph
	visibility.toggled.connect(_set_graph_visible)
	_panel.add_child(visibility)
	var label := Label.new()
	label.text = "Select a house or router under NetworkGraph."
	_panel.add_child(label)
	var graph := _graph()
	if graph == null:
		update_overlays()
		return
	label.text = "%s — undirected connections" % _selected.get_label()
	var vertices := graph.get_vertices()
	# Validate the editor property snapshot locally: a graph/vertex may still
	# be using a placeholder or the previous script version during hot reload.
	for error in _identifier_warnings(vertices):
		var warning := Label.new()
		warning.text = error
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warning.modulate = Color.ORANGE
		_panel.add_child(warning)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(250, 240)
	_panel.add_child(scroll)
	var list := VBoxContainer.new()
	scroll.add_child(list)
	for target in vertices:
		if target == _selected:
			continue
		var check := CheckBox.new()
		var identifier: Variant = _read_identifier(target)
		var key_label := "identifier unavailable" if identifier == null else ("no key" if str(identifier).is_empty() else str(identifier))
		check.text = "%s [%s] (%s)" % [target.get_label(), key_label, graph.get_path_to(target)]
		check.button_pressed = _linked(_selected, target)
		check.toggled.connect(_toggle.bind(_selected, target))
		list.add_child(check)
	for path in _selected.connections:
		if not vertices.has(_selected.get_node_or_null(path)):
			var warning := Label.new()
			warning.text = "Invalid link: %s (remove in Inspector)" % path
			list.add_child(warning)
	update_overlays()

static func _read_identifier(vertex: Object) -> Variant:
	if not is_instance_valid(vertex):
		return null
	# Do not bind directly to a script member on an editor placeholder.
	for property in vertex.get_property_list():
		if property["name"] == &"key_identifier":
			var value: Variant = vertex.get(&"key_identifier")
			if value is StringName or value is String:
				return StringName(value)
	return null

static func _identifier_warnings(vertices: Array) -> Array[String]:
	var warnings: Array[String] = []
	var seen: Dictionary = {}
	for vertex in vertices:
		if not is_instance_valid(vertex):
			continue
		var identifier: Variant = _read_identifier(vertex)
		if identifier == null:
			warnings.append("Identifier unavailable on '%s'. Update network_vertex.gd, keep @tool on derived scripts, and reopen the scene." % vertex.name)
			continue
		if str(identifier).is_empty():
			continue
		if seen.has(identifier):
			warnings.append("Duplicate key '%s': %s and %s" % [identifier, seen[identifier].name, vertex.name])
		else:
			seen[identifier] = vertex
	return warnings

func _linked(a: SignalNetworkVertex, b: SignalNetworkVertex) -> bool:
	return a.connections.has(a.get_path_to(b)) or b.connections.has(b.get_path_to(a))

func _toggle(enabled: bool, source: SignalNetworkVertex, target: SignalNetworkVertex) -> void:
	if not is_instance_valid(source) or not is_instance_valid(target):
		return
	var source_links: Array[NodePath] = source.connections.duplicate()
	var target_links: Array[NodePath] = target.connections.duplicate()
	var forward := source.get_path_to(target)
	var backward := target.get_path_to(source)
	source_links.erase(forward)
	target_links.erase(backward)
	if enabled:
		source_links.append(forward)
	var undo := get_undo_redo()
	undo.create_action("Change network connection", UndoRedo.MERGE_DISABLE, source)
	undo.add_do_property(source, &"connections", source_links)
	undo.add_undo_property(source, &"connections", source.connections.duplicate())
	undo.add_do_property(target, &"connections", target_links)
	undo.add_undo_property(target, &"connections", target.connections.duplicate())
	undo.commit_action()
	_signature = ""

func _set_graph_visible(enabled: bool) -> void:
	_show_graph = enabled
	update_overlays()

func _collect_graphs(node: Node, graphs: Array[SignalNetworkGraph]) -> void:
	if node is SignalNetworkGraph:
		graphs.append(node)
	for child in node.get_children():
		_collect_graphs(child, graphs)

static func _overlay_position(item: CanvasItem) -> Vector2:
	# The editor pans/zooms through the viewport's global canvas transform.
	# get_global_transform_with_canvas() omits that final viewport transform.
	return item.get_viewport_transform() * item.get_global_transform().origin

## Force forwarding keeps the overview visible without a selected network vertex.
func _forward_canvas_force_draw_over_viewport(overlay: Control) -> void:
	if not _show_graph:
		return
	var root := get_editor_interface().get_edited_scene_root()
	if root == null:
		return
	var graphs: Array[SignalNetworkGraph] = []
	_collect_graphs(root, graphs)
	var edges: Array = []
	var neighbors: Dictionary = {}
	for graph in graphs:
		var vertices := graph.get_vertices()
		var members: Dictionary = {}
		for vertex in vertices:
			members[vertex] = true
		var drawn: Dictionary = {}
		for source in vertices:
			for path in source.connections:
				var target := source.get_node_or_null(path) as SignalNetworkVertex
				if target == source or not members.has(target):
					continue
				var key := "%d:%d" % [mini(source.get_instance_id(), target.get_instance_id()), maxi(source.get_instance_id(), target.get_instance_id())]
				if drawn.has(key):
					continue
				drawn[key] = true
				var highlighted := source == _selected or target == _selected
				edges.append([_overlay_position(source), _overlay_position(target), highlighted])
				if highlighted:
					neighbors[target if source == _selected else source] = true
	# Draw highlighted edges last so background connections cannot cover them.
	for edge in edges:
		if not edge[2]:
			overlay.draw_line(edge[0], edge[1], Color(0.55, 0.65, 0.75, 0.55), 1.5, true)
	for edge in edges:
		if edge[2]:
			overlay.draw_line(edge[0], edge[1], Color.CYAN, 3.0, true)
	for neighbor in neighbors:
		overlay.draw_arc(_overlay_position(neighbor), 22.0, 0.0, TAU, 48, Color.CYAN, 2.5, true)
	if is_instance_valid(_selected):
		overlay.draw_arc(_overlay_position(_selected), 26.0, 0.0, TAU, 48, Color.GOLD, 3.0, true)
