extends Node
## Run-wide input preferences. Tutorial-only actions exist in InputMap only while scoped.
signal bindings_changed
const ACTIONS := {
	&"move_left": "Move left", &"move_right": "Move right", &"jump": "Charge / jump",
	&"spit": "Charge / spit", &"heighten": "Heighten aim", &"slam": "Slam",
	&"attack": "Attack", &"interact": "Interact / talk", &"townfolk_react": "React",
	&"pause": "Pause", &"ui_cancel": "Back", &"tutorial_reveal": "Reveal dialogue (tutorial only)"
}
var settings_path: String = "user://input_bindings.cfg"
var _defaults: Dictionary = {}
var _bindings: Dictionary = {}
var _scopes: Dictionary = {}

func _ready() -> void:
	for action in ACTIONS:
		if action == &"tutorial_reveal":
			var reveal := InputEventKey.new()
			reveal.keycode = KEY_SHIFT
			_defaults[action] = [reveal]
		else:
			_defaults[action] = InputMap.action_get_events(action)
		_bindings[action] = _defaults[action].duplicate(true)
	load_bindings()

func get_bindings(action: StringName) -> Array:
	return _bindings.get(action, InputMap.action_get_events(action) if InputMap.has_action(action) else []).duplicate(true)

func enter_tutorial() -> void:
	_scopes[&"tutorial_reveal"] = int(_scopes.get(&"tutorial_reveal", 0)) + 1
	_apply(&"tutorial_reveal")
	bindings_changed.emit()

func leave_tutorial() -> void:
	_scopes[&"tutorial_reveal"] = maxi(0, int(_scopes.get(&"tutorial_reveal", 0)) - 1)
	if _scopes[&"tutorial_reveal"] == 0 and InputMap.has_action(&"tutorial_reveal"):
		Input.action_release(&"tutorial_reveal")
		InputMap.erase_action(&"tutorial_reveal")
	bindings_changed.emit()

func set_bindings(action: StringName, events: Array, persist: bool = true) -> bool:
	if not ACTIONS.has(action):
		return false
	var valid: Array[InputEvent] = []
	for event in events:
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventJoypadMotion:
			valid.append(event.duplicate())
	if valid.is_empty():
		return false
	_bindings[action] = valid
	_apply(action)
	if persist:
		save_bindings()
	bindings_changed.emit()
	return true

func reset_defaults() -> void:
	for action in ACTIONS:
		_bindings[action] = _defaults[action].duplicate(true)
		_apply(action)
	save_bindings()
	bindings_changed.emit()

func _apply(action: StringName) -> void:
	if action == &"tutorial_reveal" and int(_scopes.get(action, 0)) == 0:
		return
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	Input.action_release(action)
	InputMap.action_erase_events(action)
	for event in _bindings[action]:
		InputMap.action_add_event(action, event)

func save_bindings() -> void:
	if settings_path.is_empty():
		return
	var config := ConfigFile.new()
	for action in ACTIONS:
		config.set_value("bindings", String(action), _bindings[action])
	var error := config.save(settings_path)
	if error != OK:
		push_warning("Could not save key bindings: %s" % error_string(error))

func load_bindings() -> void:
	var config := ConfigFile.new()
	if settings_path.is_empty() or config.load(settings_path) != OK:
		return
	for action in ACTIONS:
		var saved = config.get_value("bindings", String(action), [])
		if saved is Array and not saved.is_empty():
			set_bindings(action, saved, false)
