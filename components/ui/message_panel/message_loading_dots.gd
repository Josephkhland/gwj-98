@tool
extends Control
var _elapsed: float = 0.0

func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()

func _draw() -> void:
	for index in 3:
		var pulse := (sin(_elapsed * 5 - index * 0.8) + 1) * 0.5
		draw_circle(Vector2(7 + index * 12, size.y / 2), 2.5 + pulse, Color(0.97, 0.71, 0.35, 0.35 + pulse * 0.65))
