@tool
extends EditorPlugin
## Native Path2D/CollisionShape2D editors provide handles and geometry undo.
const PlatformScript = preload("../moving_platform.gd")
var _toolbar: HBoxContainer
var _platform: Node2D
var _path_button: Button
var _collision_button: Button

func _enter_tree() -> void:
	_toolbar = HBoxContainer.new()
	var label := Label.new()
	label.text = "Moving Platform"
	_toolbar.add_child(label)
	_path_button = _button("Edit Path", _edit_path)
	_collision_button = _button("Edit Collision", _edit_collision)
	_button("Select Platform", _select_platform)
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, _toolbar)
	_toolbar.hide()
	EditorInterface.get_selection().selection_changed.connect(_selection_changed)

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	_toolbar.add_child(button)
	return button

func _exit_tree() -> void:
	var selection := EditorInterface.get_selection()
	if selection.selection_changed.is_connected(_selection_changed):
		selection.selection_changed.disconnect(_selection_changed)
	if is_instance_valid(_toolbar):
		remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, _toolbar)
		_toolbar.queue_free()
	_platform = null

func _handles(object: Object) -> bool:
	return _find_platform(object) != null

func _edit(_object: Object) -> void:
	_refresh_selection()

func _make_visible(_visible: bool) -> void:
	# Editing a Shape2D resource in the Inspector must not hide our toolbar.
	_refresh_selection()

func _selection_changed() -> void:
	# Selection changes twice when clear() is followed by add_node().
	call_deferred("_refresh_selection")

func _find_platform(object: Object) -> Node2D:
	if not object is Node:
		return null
	var node := object as Node
	while node != null:
		var script := node.get_script() as Script
		while script != null:
			if script == PlatformScript:
				return node as Node2D
			script = script.get_base_script()
		node = node.get_parent()
	# Preserve controls when editing an already assigned external route.
	if is_instance_valid(_platform) and object == _platform.get("movement_path"):
		return _platform
	return null

func _refresh_selection() -> void:
	if not is_instance_valid(_toolbar):
		return
	var selected := EditorInterface.get_selection().get_selected_nodes()
	var found: Node2D
	if selected.size() == 1:
		found = _find_platform(selected[0])
	_platform = found
	_toolbar.visible = is_instance_valid(_platform)
	if _toolbar.visible:
		_path_button.tooltip_text = "Edit the assigned route, or the built-in Path2D. No extra nodes are needed."
		_collision_button.tooltip_text = "Edit the platform's CollisionShape2D with native handles and Inspector."

func _edit_path() -> void:
	if not is_instance_valid(_platform):
		return
	var route := _platform.get("movement_path") as Path2D
	var internal := not is_instance_valid(route)
	if internal:
		route = _platform.get_node("MovementPath") as Path2D
	_prepare_child(route, "curve", internal)
	_focus.call_deferred(route)

func _edit_collision() -> void:
	if not is_instance_valid(_platform):
		return
	var collider := _platform.get_node("Body/CollisionShape2D") as CollisionShape2D
	_prepare_child(collider, "shape", true)
	_focus.call_deferred(collider)

func _prepare_child(target: Node, property: StringName, isolate: bool) -> void:
	var scene := EditorInterface.get_edited_scene_root()
	if scene == null:
		return
	var instances: Array[Node] = []
	var ancestor: Node = target.get_parent()
	while ancestor != null and ancestor != scene:
		if not ancestor.scene_file_path.is_empty() and not scene.is_editable_instance(ancestor):
			instances.append(ancestor)
		ancestor = ancestor.get_parent()
	var resource := target.get(property) as Resource
	var replacement: Resource
	if isolate and resource != null and not resource.resource_local_to_scene:
		replacement = resource.duplicate(true)
		replacement.resource_local_to_scene = true
	if instances.is_empty() and replacement == null:
		return
	var undo := get_undo_redo()
	undo.create_action("Prepare moving platform geometry", UndoRedo.MERGE_DISABLE, scene)
	for instance in instances:
		undo.add_do_method(scene, "set_editable_instance", instance, true)
		undo.add_undo_method(scene, "set_editable_instance", instance, false)
	if replacement != null:
		undo.add_do_property(target, property, replacement)
		undo.add_undo_property(target, property, resource)
	undo.commit_action()
	EditorInterface.mark_scene_as_unsaved()

func _focus(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	var selection := EditorInterface.get_selection()
	selection.clear()
	selection.add_node(node)
	EditorInterface.edit_node(node)
	EditorInterface.set_main_screen_editor("2D")

func _select_platform() -> void:
	if is_instance_valid(_platform):
		_focus(_platform)
