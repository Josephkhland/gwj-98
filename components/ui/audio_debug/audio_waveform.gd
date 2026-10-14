extends Control

var _samples := PackedVector2Array()
var peak: float = 0.0
var display_gain: float = 1.0
const HISTORY_SECONDS := 0.15
const LEFT_COLOR := Color("66d9ef")
const RIGHT_COLOR := Color("ffbe76")

func push_samples(samples: PackedVector2Array) -> void:
	_samples.append_array(samples)
	var limit := int(AudioServer.get_mix_rate() * HISTORY_SECONDS)
	if _samples.size() > limit:
		_samples = _samples.slice(_samples.size() - limit)
	peak = 0.0
	for sample in _samples:
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	display_gain = clampf(0.85 / maxf(peak, 0.0001), 1.0, 32.0)
	queue_redraw()

func clear() -> void:
	_samples.clear()
	peak = 0.0
	display_gain = 1.0
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("111b27"))
	var columns := maxi(1, int(size.x))
	for channel in 2:
		var center := size.y * (0.25 if channel == 0 else 0.75)
		var scale := size.y * 0.22
		draw_line(Vector2(0, center), Vector2(size.x, center), Color("324356"))
		if _samples.is_empty():
			continue
		for column in columns:
			var first := column * _samples.size() / columns
			var last := mini(_samples.size(), maxi(first + 1, (column + 1) * _samples.size() / columns))
			var low := 1.0
			var high := -1.0
			for at in range(first, last):
				var value := _samples[at][channel] * display_gain
				low = minf(low, value)
				high = maxf(high, value)
			draw_line(Vector2(column, center - clampf(high, -1.0, 1.0) * scale), Vector2(column, center - clampf(low, -1.0, 1.0) * scale + 1.0), LEFT_COLOR if channel == 0 else RIGHT_COLOR)
