@tool
class_name TownfolkDialogueBubble
extends Node2D
## Origin is the bubble anchor. Mouth is supplied in this node's local coordinates.
@export var bubble_size := Vector2(280, 100)
@export var fill_color := Color("fff5df")
@export var text_color := Color.BLACK
@export_range(0, 0.12, 0.005) var shape_quirk: float = 0.055
var mouth_position := Vector2(0, 95)
const GoldGlitter = preload("res://components/modules/townfolk/gold_glitter.gd")
const InputIcons = preload("res://components/ui/input_icons/input_icon_text.gd")
var _glitter := GoldGlitter.new()
var _shape_phases := Vector3(0.7, 2.4, 4.1)
var _tail_bend: float = 8.0
var _popup_time: float = 0.0
var _popup_target: Node2D
var _popup_offset := Vector2.ZERO
var _popup_rise: float = 0.0
var minimized: bool = false
var _collapse: float = 0.0
var _animation_time: float = 0.0
var _input_text: String = ""
var _input_segments: Array[Dictionary] = []

@onready var text_label: RichTextLabel = $Text
@onready var popup_label: Label = $Popup

func _ready() -> void:
	text_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	text_label.add_theme_color_override("default_color", text_color)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.fit_content = true
	text_label.scroll_active = false
	text_label.install_effect(_glitter)
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_label.hide()
	var store := get_node_or_null("/root/InputBindings")
	if store != null and store.has_signal("bindings_changed"):
		store.bindings_changed.connect(_refresh_input_icons)
	if Engine.is_editor_hint():
		set_text("Dialogue preview")

func set_text(value: String) -> void:
	_input_text = value
	_input_segments = []
	text_label.clear()
	InputIcons.append_to(text_label, value)
	_layout_text()

func set_segments(segments: Array[Dictionary]) -> void:
	_input_segments = segments.duplicate(true)
	text_label.clear()
	for segment in segments:
		text_label.push_color(segment.color)
		if segment.gold:
			text_label.push_customfx(_glitter, {})
		InputIcons.append_to(text_label, segment.text)
		if segment.gold:
			text_label.pop()
		text_label.pop()
	_layout_text()

func _refresh_input_icons() -> void:
	if not is_inside_tree():
		return
	if _input_segments.is_empty():
		set_text(_input_text)
	else:
		set_segments(_input_segments)

func _layout_text() -> void:
	text_label.position = Vector2(-bubble_size.x / 2.0 + 24, -bubble_size.y + 20)
	text_label.size = Vector2(maxf(1, bubble_size.x - 48), maxf(1, bubble_size.y - 40))
	queue_redraw()

func randomize_shape() -> void:
	_shape_phases = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	_tail_bend = randf_range(-14, 14)
	queue_redraw()

func show_result(accuracy: float, perfect_points: int, target: Node2D = null, offset: Vector2 = Vector2(0, -64)) -> void:
	var tier := "PERFECT" if accuracy >= 0.9 else ("GOOD" if accuracy >= 0.6 else ("OK" if accuracy > 0.0 else "MISS"))
	popup_label.text = "%s +%d" % [tier, roundi(accuracy * perfect_points)]
	popup_label.size = popup_label.get_minimum_size()
	_popup_target = target
	_popup_offset = offset
	_popup_rise = 0
	_position_popup()
	popup_label.modulate = Color("ffcc70") if accuracy > 0 else Color("d5c6bf")
	popup_label.show()
	_popup_time = 0.9

func reset() -> void:
	_popup_time = 0.0
	_popup_target = null
	popup_label.hide()
	set_text("")

func set_minimized(value: bool) -> void:
	if minimized and not value:
		randomize_shape()
	minimized = value
	text_label.visible = not minimized and _collapse < 0.05
	if minimized:
		popup_label.hide()
		_popup_time = 0.0

func _process(delta: float) -> void:
	_animation_time += delta
	_collapse = move_toward(_collapse, 1.0 if minimized else 0.0, delta * 7.0)
	text_label.visible = not minimized and _collapse < 0.05
	if _popup_time > 0:
		_popup_time -= delta
		_popup_rise += delta * 12
		_position_popup()
		popup_label.modulate.a = clampf(_popup_time * 3.0, 0, 1)
		popup_label.visible = _popup_time > 0
	queue_redraw()

func _position_popup() -> void:
	var centered := Vector2(-popup_label.size.x * 0.5, -_popup_rise)
	if is_instance_valid(_popup_target):
		popup_label.global_position = _popup_target.global_position + _popup_offset + centered
	else:
		var height := maxf(bubble_size.y, text_label.get_minimum_size().y + 40)
		popup_label.position = Vector2(0, -height - 40) + centered

func _draw() -> void:
	var height := bubble_size.y
	if is_instance_valid(text_label):
		height = maxf(height, text_label.get_minimum_size().y + 40)
		text_label.position.y = -height + 20
	var display_size := Vector2(bubble_size.x, height).lerp(Vector2(54, 32), smoothstep(0, 1, _collapse))
	var tail_width := lerpf(12, 5, _collapse)
	var tail := PackedVector2Array()
	var root := Vector2(-tail_width, -6)
	var control := mouth_position * 0.4 + Vector2(_tail_bend, 0)
	for index in 13:
		var t := index / 12.0
		tail.append(root * (1 - t) * (1 - t) + (control - Vector2(tail_width * 0.5, 0)) * 2 * (1 - t) * t + mouth_position * t * t)
	for index in range(11, -1, -1):
		var t := index / 12.0
		tail.append(Vector2(tail_width, -6) * (1 - t) * (1 - t) + (control + Vector2(tail_width * 0.5, 0)) * 2 * (1 - t) * t + mouth_position * t * t)
	draw_colored_polygon(tail, fill_color)
	var silhouette := PackedVector2Array()
	for index in 96:
		var angle := TAU * index / 96.0
		var x := cos(angle)
		var y := sin(angle)
		var wobble := 1 + shape_quirk * (sin(angle * 3 + _shape_phases.x) + 0.5 * sin(angle * 5 + _shape_phases.y))
		silhouette.append(Vector2(signf(x) * pow(absf(x), 0.35) * display_size.x * 0.5 * wobble, -display_size.y * 0.5 + signf(y) * pow(absf(y), 0.4) * display_size.y * 0.5 * (1 + shape_quirk * sin(angle * 4 + _shape_phases.z))))
	draw_colored_polygon(silhouette, fill_color)
	if _collapse > 0.5:
		for index in 3:
			var pulse := (sin(_animation_time * 6 - index * 0.9) + 1) * 0.5
			var color := text_color
			color.a = lerpf(0.3, 1, pulse) * _collapse
			draw_circle(Vector2((index - 1) * 11, -display_size.y / 2 - pulse * 2), 2.3, color)
