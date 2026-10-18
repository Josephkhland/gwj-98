extends CanvasLayer
var _return_focus: Control
@onready var _tabs: TabContainer = %Tabs
@onready var _bindings: Control = %Bindings
@onready var _palette: OptionButton = %NetworkPalette
@onready var _minimap_size: HSlider = %MinimapSize

func _ready() -> void:
	hide()
	%Back.pressed.connect(close)
	_bindings.close_requested.connect(close)
	_tabs.set_tab_title(1, "Input Bindings")
	_tabs.set_tab_title(2, "Accessibility")
	_minimap_size.value_changed.connect(func(value): AccessibilitySettings.set_minimap_size_percent(value))
	AccessibilitySettings.minimap_size_changed.connect(_refresh_minimap_size)
	_refresh_minimap_size()
	%RouterMessageHints.toggled.connect(func(value): AccessibilitySettings.set_show_router_message_hints(value))
	AccessibilitySettings.router_message_hints_changed.connect(_refresh_router_message_hints)
	_refresh_router_message_hints()
	_palette.add_item("Green / red", 0)
	_palette.add_item("Cyan / orange", 1)
	_palette.item_selected.connect(func(index): AccessibilitySettings.set_alternate_network_colors(index == 1))
	AccessibilitySettings.network_colors_changed.connect(_refresh_palette)
	_refresh_palette()
	get_viewport().size_changed.connect(_layout)
	_layout()

func open(launcher: Control = null) -> void:
	_return_focus = launcher
	_bindings._cancel_binding()
	_tabs.current_tab = 0
	show()
	_tabs.get_tab_bar().grab_focus()

func close() -> void:
	_bindings._cancel_binding()
	hide()
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()

func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")) and not event.is_echo():
		# The embedded bindings panel handles Escape while capturing an input.
		if _bindings.is_visible_in_tree() and not _bindings._capture_action.is_empty():
			return
		get_viewport().set_input_as_handled()
		close()

func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var side := maxf(24, (viewport_size.x - 1200) / 2)
	var top := maxf(24, (viewport_size.y - 840) / 2)
	$Margin.offset_left = side
	$Margin.offset_right = -side
	$Margin.offset_top = top
	$Margin.offset_bottom = -top

func _refresh_palette() -> void:
	var alternate: bool = AccessibilitySettings.alternate_network_colors
	_palette.select(1 if alternate else 0)
	%ActivePreview.add_theme_color_override("font_color", Color("4dd9ff") if alternate else Color("66e680"))
	%BrokenPreview.add_theme_color_override("font_color", Color("ffb347") if alternate else Color("ff5950"))

func _refresh_minimap_size() -> void:
	_minimap_size.set_value_no_signal(AccessibilitySettings.minimap_size_percent)
	%MinimapSizeValue.text = "%d%%" % roundi(AccessibilitySettings.minimap_size_percent)

func _refresh_router_message_hints() -> void:
	%RouterMessageHints.set_pressed_no_signal(AccessibilitySettings.show_router_message_hints)
