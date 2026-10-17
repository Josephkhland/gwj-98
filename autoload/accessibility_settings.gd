extends Node
signal network_colors_changed
var settings_path: String = "user://accessibility_settings.cfg"
var alternate_network_colors: bool = false

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		alternate_network_colors = bool(config.get_value("network", "alternate_colors", false))

func set_alternate_network_colors(value: bool, persist: bool = true) -> void:
	alternate_network_colors = value
	if persist and not settings_path.is_empty():
		var config := ConfigFile.new()
		config.set_value("network", "alternate_colors", value)
		config.save(settings_path)
	network_colors_changed.emit()
