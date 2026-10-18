extends Node
signal network_colors_changed
signal minimap_size_changed
const DEFAULT_MINIMAP_SIZE_PERCENT: float = 125.0
var settings_path: String = "user://accessibility_settings.cfg"
var alternate_network_colors: bool = false
var minimap_size_percent: float = DEFAULT_MINIMAP_SIZE_PERCENT

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		alternate_network_colors = bool(config.get_value("network", "alternate_colors", false))
		var size_percent := float(config.get_value("minimap", "size_percent", DEFAULT_MINIMAP_SIZE_PERCENT))
		minimap_size_percent = clampf(size_percent, 100.0, 200.0) if is_finite(size_percent) else DEFAULT_MINIMAP_SIZE_PERCENT

func set_alternate_network_colors(value: bool, persist: bool = true) -> void:
	alternate_network_colors = value
	if persist:
		_save()
	network_colors_changed.emit()

func set_minimap_size_percent(value: float, persist: bool = true) -> void:
	if not is_finite(value):
		return
	minimap_size_percent = clampf(value, 100.0, 200.0)
	if persist:
		_save()
	minimap_size_changed.emit()

func _save() -> void:
	if settings_path.is_empty():
		return
	var config := ConfigFile.new()
	config.load(settings_path)
	config.set_value("network", "alternate_colors", alternate_network_colors)
	config.set_value("minimap", "size_percent", minimap_size_percent)
	config.save(settings_path)
