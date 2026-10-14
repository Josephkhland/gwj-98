extends VBoxContainer

var _sliders: Dictionary = {}

func _ready() -> void:
	var title := Label.new()
	title.text = "Sound volume"
	add_child(title)
	for bus in AudioManager.BUSES:
		var row := HBoxContainer.new()
		add_child(row)
		var label := Label.new()
		label.text = String(bus)
		label.custom_minimum_size.x = 85.0
		row.add_child(label)
		var slider := HSlider.new()
		slider.max_value = 100.0
		slider.step = 1.0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.x = 140.0
		slider.value = AudioManager.get_volume(bus) * 100.0
		slider.tooltip_text = String(bus) + " volume"
		row.add_child(slider)
		_sliders[bus] = slider
		slider.value_changed.connect(func(value: float): AudioManager.set_volume(bus, value / 100.0))
	AudioManager.volume_changed.connect(_on_volume_changed)

func _on_volume_changed(bus: StringName, value: float) -> void:
	if _sliders.has(bus):
		_sliders[bus].set_value_no_signal(value * 100.0)
