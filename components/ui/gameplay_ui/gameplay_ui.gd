class_name GameplayUI
extends CanvasLayer
## HUD built from optional HudWidgets. The game decides which widgets show; widgets that
## aren't in the scene are simply skipped by whoever asks for them.
var _widgets: Dictionary[StringName, HudWidget] = {}

func _ready() -> void:
	_collect(self)
	$Root.resized.connect(_layout_message_feed)
	_layout_message_feed()

func _layout_message_feed() -> void:
	var prompt := get_widget(&"prompt")
	if prompt != null:
		var width := minf(800, maxf(240, $Root.size.x - 32))
		prompt.offset_left = -width / 2
		prompt.offset_right = width / 2
	var feed := get_widget(&"message_feed")
	if feed == null:
		return
	var narrow: bool = $Root.size.x < 1000
	feed.offset_left = 16 if narrow else 316
	feed.offset_right = -16 if narrow else -272
	feed.offset_top = 212 if narrow else 16

func get_widget(widget_id: StringName) -> HudWidget:
	return _widgets.get(widget_id)

func set_widget_visible(widget_id: StringName, shown: bool) -> void:
	var widget := get_widget(widget_id)
	if widget != null:
		widget.visible = shown

## Shows the listed widgets and hides every other one.
func show_only(widget_ids: Array) -> void:
	for widget_id in _widgets:
		_widgets[widget_id].visible = widget_ids.has(widget_id)

func apply_snapshot(snapshot: Dictionary) -> void:
	for widget in _widgets.values():
		widget.apply_snapshot(snapshot)

func reset() -> void:
	for widget in _widgets.values():
		widget.reset()

func _collect(node: Node) -> void:
	for child in node.get_children():
		var widget := child as HudWidget
		if widget != null and not widget.widget_id.is_empty():
			_widgets[widget.widget_id] = widget
		_collect(child)
