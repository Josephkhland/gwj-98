@static_unload
class_name InputIconText
extends RefCounted
## Plain text with bracketed controls. Unknown brackets remain literal text.
const KEY_ROOT := "res://assets/beamedeighth/Single PNGs/"
const MOUSE_SHEET := "res://assets/josephkhland/mouse_button_left_click.png"
static var _tokens: Dictionary = {}
static var _pattern: RegEx
static var _cleanup_connected: bool = false

static func _regex() -> RegEx:
	if _pattern == null:
		_pattern = RegEx.new()
		_pattern.compile("\\[([^\\]\\r\\n]+)\\]")
	return _pattern

static func _info(token: String) -> Dictionary:
	if not _cleanup_connected:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			var cleanup := Callable(load("res://components/ui/input_icons/input_icon_text.gd"), "_clear_cache")
			tree.root.tree_exiting.connect(cleanup, CONNECT_ONE_SHOT)
			_cleanup_connected = true
	var key := token.strip_edges().to_upper()
	if key.begins_with("ACTION:") or key in ["INTERACT", "INTERACT BUTTON", "JUMP", "SPIT", "REACT"]:
		var action: String = key.trim_prefix("ACTION:").to_lower() if key.begins_with("ACTION:") else {"INTERACT": "interact", "INTERACT BUTTON": "interact", "JUMP": "jump", "SPIT": "spit", "REACT": "townfolk_react"}[key]
		var tree := Engine.get_main_loop() as SceneTree
		var store := tree.root.get_node_or_null("InputBindings") if tree != null else null
		var events: Array = store.get_bindings(StringName(action)) if store != null and store.has_method("get_bindings") else (InputMap.action_get_events(action) if InputMap.has_action(action) else [])
		var bindings: Array[Dictionary] = []
		# Keyboard first so the jump lesson shows Space and its left-click alternative.
		for mouse in [false, true]:
			for event in events:
				if (not mouse and event is InputEventKey) or (mouse and event is InputEventMouseButton):
					var name := event_label(event)
					var info := _key_info(name.to_upper())
					bindings.append(info if not info.is_empty() else {"fallback": name})
		return {"bindings": bindings} if not bindings.is_empty() else {"fallback": "Unbound"}
	return _key_info(key)

static func event_label(event: InputEvent) -> String:
	if event is InputEventKey:
		return OS.get_keycode_string(keycode_for_event(event))
	if event is InputEventMouseButton:
		return {MOUSE_BUTTON_LEFT: "Left Click", MOUSE_BUTTON_RIGHT: "Right Click", MOUSE_BUTTON_MIDDLE: "Middle Click", MOUSE_BUTTON_WHEEL_UP: "Wheel Up", MOUSE_BUTTON_WHEEL_DOWN: "Wheel Down"}.get(event.button_index, "Mouse %d" % event.button_index)
	return event.as_text()

static func keycode_for_event(event: InputEventKey) -> int:
	if event.keycode != 0:
		return event.keycode
	if DisplayServer.get_name() == "headless":
		return event.physical_keycode
	var code := DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode)
	return code if code != 0 else event.physical_keycode

static func _key_info(key: String) -> Dictionary:
	if _tokens.has(key):
		return _tokens[key]
	var aliases := {"SPACEBAR": "SPACE", "ESCAPE": "ESC", "CONTROL": "CTRL", "CAPSLOCK": "CAPS", "UP": "ARROWUP", "DOWN": "ARROWDOWN", "LEFT": "ARROWLEFT", "RIGHT": "ARROWRIGHT", "SPACE": "SPACEALTERNATIVE", "LEFT MOUSE BUTTON": "LEFT CLICK", "RIGHT MOUSE BUTTON": "RIGHT CLICK", "LMB": "LEFT CLICK", "RMB": "RIGHT CLICK"}
	var name: String = aliases.get(key, key)
	var result: Dictionary = {}
	if name in ["LEFT CLICK", "RIGHT CLICK"]:
		var source: Texture2D = load(MOUSE_SHEET)
		var image := source.get_image()
		var frame_size := Vector2i(image.get_width() / 2, image.get_height())
		var animation := AnimatedTexture.new()
		animation.frames = 2
		for index in 2:
			var frame := image.get_region(Rect2i(Vector2i(index * frame_size.x, 0), frame_size))
			if name == "RIGHT CLICK":
				frame.flip_x()
			animation.set_frame_texture(index, ImageTexture.create_from_image(frame))
			animation.set_frame_duration(index, 0.4)
		result = {"texture": animation}
	elif ResourceLoader.exists(KEY_ROOT + name + ".png"):
		result = {"texture": load(KEY_ROOT + name + ".png")}
	elif name == "ESC" or (name.begins_with("F") and name.substr(1).is_valid_int()):
		# This art set has no Escape/function keys. Keep them readable as key badges.
		result = {"fallback": "Esc" if name == "ESC" else name}
	_tokens[key] = result
	return result

static func _clear_cache() -> void:
	_tokens.clear()
	_pattern = null
	_cleanup_connected = false

static func is_input_token(value: String) -> bool:
	var clean := value.strip_edges()
	return clean.begins_with("[") and clean.ends_with("]") and not _info(clean.substr(1, clean.length() - 2)).is_empty()

static func append_to(label: RichTextLabel, value: String) -> void:
	var cursor := 0
	for matched in _regex().search_all(value):
		var info := _info(matched.get_string(1))
		if info.is_empty():
			continue
		label.add_text(value.substr(cursor, matched.get_start() - cursor))
		var bindings: Array = info.get("bindings", [info])
		for index in bindings.size():
			if index > 0:
				label.add_text(" / ")
			var binding: Dictionary = bindings[index]
			if binding.has("texture"):
				var texture: Texture2D = binding.texture
				var height := roundi(label.get_theme_font_size("normal_font_size") * 1.4)
				var width := roundi(height * texture.get_width() / float(maxi(1, texture.get_height())))
				label.add_image(texture, width, height, Color.WHITE, INLINE_ALIGNMENT_CENTER, Rect2(), null, false, matched.get_string(1))
			else:
				label.push_bgcolor(Color("c4c3c8"))
				label.push_color(Color("25252a"))
				label.add_text(" " + binding.fallback + " ")
				label.pop()
				label.pop()
		cursor = matched.get_end()
	label.add_text(value.substr(cursor))

static func rendered_length(value: String) -> int:
	var count := value.length()
	for matched in _regex().search_all(value):
		var info := _info(matched.get_string(1))
		if not info.is_empty():
			var bindings: Array = info.get("bindings", [info])
			var length := maxi(0, bindings.size() - 1) * 3
			for binding in bindings:
				length += 1 if binding.has("texture") else String(binding.fallback).length() + 2
			count += length - matched.get_string().length()
	return count

static func set_text(label: RichTextLabel, value: String) -> void:
	label.clear()
	append_to(label, value)
