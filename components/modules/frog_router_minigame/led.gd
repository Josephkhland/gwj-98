@tool
extends Control
## Status lamp with a caption underneath. Drawn, no child nodes.

@export var text: String = "PWR":
	set(value):
		text = value
		queue_redraw()
@export var color_on: Color = Color(0.35, 1.0, 0.45):
	set(value):
		color_on = value
		queue_redraw()
@export var color_off: Color = Color(0.1, 0.13, 0.12)
@export var on: bool = false:
	set(value):
		if on != value:
			on = value
			queue_redraw()
@export var blinking: bool = false
@export_range(0.05, 2.0) var blink_period: float = 0.5
@export var radius: float = 10.0
@export var caption_color: Color = Color(0.82, 0.88, 0.85)
@export var font_size: int = 14

func _process(_delta: float) -> void:
	if blinking and on:
		queue_redraw()

func _draw() -> void:
	var center := Vector2(size.x / 2.0, radius + 8.0)
	var lit := on and (not blinking or fmod(Time.get_ticks_msec() / 1000.0, blink_period) < blink_period / 2.0)
	if lit:
		var glow := color_on
		glow.a = 0.25
		draw_circle(center, radius * 1.8, glow)
	draw_circle(center, radius + 2.0, Color(0.05, 0.07, 0.06))
	draw_circle(center, radius, color_on if lit else color_off)
	draw_circle(center - Vector2(radius, radius) * 0.35, radius * 0.3, Color(1, 1, 1, 0.45 if lit else 0.1))
	draw_string(ThemeDB.fallback_font, Vector2(0, center.y + radius + 22.0), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, caption_color)
