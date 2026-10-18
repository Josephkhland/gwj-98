extends Control
signal close_requested
@export var embedded: bool = false
const Icons = preload("res://components/ui/input_icons/input_icon_text.gd")
var _capture_action: StringName = &""
var _capture_index: int = -1
var _return_focus: Control
@onready var _rows: VBoxContainer = %Rows
@onready var _status: Label = %Status
@onready var _back: Button = %Back
@onready var _cancel_capture: Button = %CancelCapture

func _ready() -> void:
	if embedded:
		$Dim.hide()
		$Margin/Column/Title.hide()
		_back.hide()
	else:
		hide()
	_back.pressed.connect(close)
	_cancel_capture.pressed.connect(_cancel_binding)
	get_viewport().size_changed.connect(_layout)
	_layout()
	%Reset.pressed.connect(func():
		_capture_action = &""
		InputBindings.reset_defaults()
		_status.text = "Default bindings restored.")
	InputBindings.bindings_changed.connect(_refresh)
	_refresh()

func open(launcher: Control = null) -> void:
	_return_focus = launcher
	_capture_action = &""
	_status.text = "Select a binding, then press a key or mouse button. Escape cancels capture."
	_refresh()
	show()
	_back.grab_focus()

func close() -> void:
	_capture_action = &""
	if embedded:
		close_requested.emit()
		return
	hide()
	if is_instance_valid(_return_focus):
		_return_focus.grab_focus()

func _layout() -> void:
	if embedded:
		$Margin.offset_left = 0
		$Margin.offset_right = 0
		$Margin.offset_top = 0
		$Margin.offset_bottom = 0
		return
	var side := maxf(24, (get_viewport().get_visible_rect().size.x - 1160) / 2)
	$Margin.offset_left = side
	$Margin.offset_right = -side

func _refresh() -> void:
	if not is_node_ready() or not is_inside_tree():
		return
	_cancel_capture.visible = not _capture_action.is_empty()
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for action in InputBindings.ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_rows.add_child(row)
		var name_label := Label.new()
		name_label.text = InputBindings.ACTIONS[action]
		name_label.custom_minimum_size.x = 360
		row.add_child(name_label)
		var events := InputBindings.get_bindings(action)
		var editable := 0
		for event in events:
			if event is InputEventKey or event is InputEventMouseButton:
				editable += 1
		for index in events.size():
			var event: InputEvent = events[index]
			if not (event is InputEventKey or event is InputEventMouseButton):
				continue
			var button := Button.new()
			button.custom_minimum_size = Vector2(135, 36)
			button.text = "Press input…" if action == _capture_action and index == _capture_index else Icons.event_label(event)
			button.pressed.connect(_begin_capture.bind(action, index))
			row.add_child(button)
			var remove := Button.new()
			remove.text = "×"
			remove.tooltip_text = "Remove this binding"
			remove.disabled = editable <= 1
			remove.pressed.connect(func():
				var remaining := InputBindings.get_bindings(action)
				remaining.remove_at(index)
				InputBindings.set_bindings(action, remaining))
			row.add_child(remove)
		var add := Button.new()
		add.text = "+"
		add.tooltip_text = "Add another binding"
		add.disabled = editable >= 3
		add.pressed.connect(_begin_capture.bind(action, -1))
		row.add_child(add)

func _begin_capture(action: StringName, index: int) -> void:
	_capture_action = action
	_capture_index = index
	_status.text = "Binding %s — press a key or mouse button. Escape cancels." % InputBindings.ACTIONS[action]
	if action in [&"ui_cancel", &"pause"]:
		_status.text = "Binding %s — press a key or mouse button, including Escape. Use Cancel to stop." % InputBindings.ACTIONS[action]
	_refresh()

func _cancel_binding() -> void:
	_capture_action = &""
	_status.text = "Binding unchanged."
	_refresh()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if not _capture_action.is_empty():
		if event is InputEventKey or event is InputEventMouseButton:
			if embedded and event is InputEventMouseButton and not get_global_rect().has_point(event.position):
				return
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and _cancel_capture.get_global_rect().has_point(event.position):
				return
			get_viewport().set_input_as_handled()
			if not event.is_pressed() or event.is_echo():
				return
			if event is InputEventKey and event.keycode == KEY_ESCAPE and _capture_action not in [&"ui_cancel", &"pause"]:
				_cancel_binding()
				return
			_accept_binding(event)
		return
	if (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")) and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready() and not is_visible_in_tree() and not _capture_action.is_empty():
		_cancel_binding.call_deferred()

func _accept_binding(event: InputEvent) -> void:
	var binding: InputEvent
	if event is InputEventKey:
		var key := InputEventKey.new()
		# Logical keys follow the user's keyboard labels, including AZERTY layouts.
		key.keycode = Icons.keycode_for_event(event)
		binding = key
	else:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = event.button_index
		binding = mouse
	var action := _capture_action
	var events := InputBindings.get_bindings(action)
	var duplicate := false
	for index in events.size():
		if index != _capture_index and Icons.event_label(events[index]) == Icons.event_label(binding):
			duplicate = true
	if duplicate:
		_status.text = "That input is already assigned to this action."
		_capture_action = &""
		_refresh()
		return
	if _capture_index < 0:
		events.append(binding)
	else:
		events[_capture_index] = binding
	_capture_action = &""
	InputBindings.set_bindings(action, events)
	var shared := PackedStringArray()
	for other in InputBindings.ACTIONS:
		if other == action:
			continue
		for existing in InputBindings.get_bindings(other):
			if Icons.event_label(existing) == Icons.event_label(binding):
				shared.append(InputBindings.ACTIONS[other])
				break
	_status.text = "Saved. Also used by: " + ", ".join(shared) if not shared.is_empty() else "Binding saved."
	(%Reset if embedded else _back).grab_focus()
