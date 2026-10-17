@tool
extends Control
## Draws the router's scope: graticule, the target trace and the live trace.
## The minigame feeds it values every frame; it only draws and creates no nodes.

enum Encoding { OK, CORRUPT, STRIPPED }

@export var powered: bool = true
@export_range(0.0, 1.0) var boot_progress: float = 1.0
@export var locked: bool = false
@export_range(0.0, 1.0) var target_freq: float = 0.35
@export_range(0.0, 1.0) var target_amp: float = 0.6
@export_range(0.0, 1.0) var actual_freq: float = 0.5
@export_range(0.0, 1.0) var actual_amp: float = 0.4
## Antenna misalignment: jitters the live trace and empties the signal bars.
@export_range(0.0, 1.0) var noise: float = 0.0
@export var encoding: Encoding = Encoding.OK
## 8-bit pattern both traces carry when encoded (one bit per half cycle).
@export var bits: int = 0b10110010
@export var time: float = 0.0
@export_group("Look")
@export var divisions: Vector2i = Vector2i(10, 8)
@export var min_cycles: float = 1.0
@export var max_cycles: float = 5.0
@export var scroll_speed: float = 0.35
@export_range(32, 1024) var samples: int = 280
## Height of a 0-bit half cycle relative to a 1-bit one.
@export_range(0.1, 1.0) var low_bit_level: float = 0.7
@export var background_color: Color = Color(0.03, 0.07, 0.05)
@export var grid_color: Color = Color(0.2, 0.45, 0.3, 0.35)
@export var axis_color: Color = Color(0.4, 0.8, 0.55, 0.6)
@export var target_color: Color = Color(0.35, 0.85, 1.0, 0.5)
@export var actual_color: Color = Color(0.9, 1.0, 0.35)
@export var text_color: Color = Color(0.55, 0.95, 0.65)
@export var font_size: int = 14

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, background_color)
	if not powered:
		draw_rect(rect, Color(0, 0, 0, 0.65))
		draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.55, 0), Vector2(size.x * 0.75, 0), Vector2(size.x * 0.45, size.y), Vector2(size.x * 0.25, size.y)]), Color(1, 1, 1, 0.03))
		return
	_draw_graticule()
	if boot_progress < 1.0:
		var x := boot_progress * size.x
		draw_line(Vector2(x, 0), Vector2(x, size.y), actual_color, 3.0)
		_text("BOOTING %d%%" % roundi(boot_progress * 100.0), Vector2(12, size.y - 12))
		return
	draw_polyline(_trace(target_freq, target_amp, Encoding.OK, 0.0), target_color, 7.0, true)
	var live := _trace(actual_freq, actual_amp, encoding, noise)
	var glow := actual_color
	glow.a = 0.18
	draw_polyline(live, glow, 7.0, true)
	draw_polyline(live, actual_color, 2.5, true)
	_draw_hud()
	for y in range(0, int(size.y), 3):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0, 0, 0, 0.08))

func _draw_graticule() -> void:
	for i in range(1, divisions.x):
		var x := size.x * i / divisions.x
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color)
	for i in range(1, divisions.y):
		var y := size.y * i / divisions.y
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color)
	var center := size / 2.0
	draw_line(Vector2(0, center.y), Vector2(size.x, center.y), axis_color, 1.5)
	draw_line(Vector2(center.x, 0), Vector2(center.x, size.y), axis_color, 1.5)
	var step := size / Vector2(divisions * 5)
	for k in range(1, divisions.x * 5):
		var h := 8.0 if k % 5 == 0 else 4.0
		draw_line(Vector2(k * step.x, center.y - h), Vector2(k * step.x, center.y + h), axis_color)
	for k in range(1, divisions.y * 5):
		var h := 8.0 if k % 5 == 0 else 4.0
		draw_line(Vector2(center.x - h, k * step.y), Vector2(center.x + h, k * step.y), axis_color)
	draw_rect(Rect2(Vector2.ZERO, size), axis_color, false, 2.0)

func _draw_hud() -> void:
	var legend := target_color
	legend.a = 1.0
	draw_line(Vector2(12, 16), Vector2(36, 16), legend, 4.0)
	_text("TARGET", Vector2(42, 21))
	draw_line(Vector2(112, 16), Vector2(136, 16), actual_color, 3.0)
	_text("LIVE", Vector2(142, 21))
	_text("ANT", Vector2(size.x - 108, 21))
	var bars := ceili((1.0 - noise) * 4.0)
	for b in 4:
		var h := 6.0 + b * 5.0
		draw_rect(Rect2(size.x - 70 + b * 12, 24 - h, 8, h), text_color if b < bars else grid_color)
	if locked:
		draw_string(ThemeDB.fallback_font, Vector2(0, size.y - 16), "SIGNAL LOCKED", HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color.WHITE)

func _trace(freq: float, amp: float, mode: Encoding, jitter: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(samples + 1)
	var mid := size.y * 0.5
	var height := lerpf(0.12, 0.88, amp) * mid
	var cycles := lerpf(min_cycles, max_cycles, freq)
	# Noise and corruption are hashed from time, so a frozen router shows a still frame.
	var frame := floori(time * 30.0)
	var scramble := floori(time / 0.14)
	for i in samples + 1:
		var u := float(i) / samples
		var phase := u * cycles + time * scroll_speed
		var s := sin(phase * TAU)
		var half_cycle := floori(phase * 2.0)
		var level := 1.0
		match mode:
			Encoding.OK:
				level = 1.0 if (bits >> posmod(half_cycle, 8)) & 1 else low_bit_level
			Encoding.CORRUPT:
				var glitch := _hash(half_cycle, scramble)
				level = 1.0 if glitch > 0.5 else low_bit_level * 0.8
				if glitch > 0.82:
					s = signf(s) * 0.9
				elif glitch < 0.12:
					s = -s
		var y := s * level * height
		if jitter > 0.0:
			y += (_hash(i, frame) - 0.5) * jitter * mid * 0.3
		points[i] = Vector2(u * size.x, clampf(mid - y, 2.0, size.y - 2.0))
	return points

func _text(text: String, position: Vector2) -> void:
	draw_string(ThemeDB.fallback_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

static func _hash(a: int, b: int) -> float:
	var h := (a * 73856093) ^ (b * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float(h & 0xFFFF) / 65535.0
