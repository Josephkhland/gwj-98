@tool
class_name InputHintLabel
extends RichTextLabel
const Icons = preload("res://components/ui/input_icons/input_icon_text.gd")
var source_text: String = ""
var _rendered_font_size: int = -1

func _init() -> void:
	fit_content = true
	scroll_active = false
	autowrap_mode = TextServer.AUTOWRAP_OFF
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _ready() -> void:
	set_hint(text)
	var store := get_node_or_null("/root/InputBindings")
	if store != null and store.has_signal("bindings_changed"):
		store.bindings_changed.connect(_refresh_bindings)

func set_hint(value: String, force: bool = false) -> void:
	var font_size := get_theme_font_size("normal_font_size")
	if not force and source_text == value and _rendered_font_size == font_size and get_total_character_count() > 0:
		return
	source_text = value
	_rendered_font_size = font_size
	Icons.set_text(self, value)

func _refresh_bindings() -> void:
	if is_inside_tree():
		set_hint(source_text, true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		set_hint(source_text)
