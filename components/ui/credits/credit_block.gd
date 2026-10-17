extends AnimatableBody2D
## A credit card is also a one-way platform; its spring moves the whole card.
@export_range(0, 40, 1) var standing_dip: float = 9
@export_range(1, 300, 1) var spring_strength: float = 100
@export_range(1, 40, 1) var spring_damping: float = 16
var base_y: float = 0
var base_x: float = 0
var dip: float = 0
var dip_velocity: float = 0
var card_size := Vector2(680, 140)
var fill_color := Color("d9edd8")
var _silhouette := PackedVector2Array()
@onready var _collision: CollisionPolygon2D = $Collision
@onready var _column: VBoxContainer = $Content

func configure(entry: Dictionary, index: int, width: float) -> void:
	var palette := [Color("d9edd8"), Color("e5def4"), Color("f5dfc3"), Color("cde8e8")]
	fill_color = palette[index % palette.size()]
	$Content/Role.text = entry.get("role", "")
	$Content/Role.visible = not $Content/Role.text.is_empty()
	$Content/Name.text = entry.get("name", "")
	$Content/Quote.text = entry.get("quote", "")
	$Content/Quote.visible = not $Content/Quote.text.is_empty()
	$Content/Link.text = entry.get("link", "")
	$Content/Link.visible = not $Content/Link.text.is_empty()
	card_size.y = 148 if $Content/Quote.visible else (126 if $Content/Link.visible else 102)
	set_width(width, index)

func set_width(width: float, variation: int) -> void:
	card_size.x = width
	_column.position = Vector2(-width * 0.5 + 32, -card_size.y * 0.5 + 16)
	_column.size = Vector2(width - 64, card_size.y - 32)
	_silhouette.clear()
	for index in 64:
		var angle := TAU * index / 64.0
		var x := cos(angle)
		var y := sin(angle)
		var wobble := sin(angle * 3 + variation * 1.7)
		_silhouette.append(Vector2(signf(x) * pow(absf(x), 0.35) * width * 0.5 * (1 + wobble * 0.012), signf(y) * pow(absf(y), 0.55) * card_size.y * 0.5 * (1 + wobble * 0.025)))
	_collision.polygon = _silhouette
	queue_redraw()

func land(impact_speed: float) -> void:
	dip_velocity += clampf(impact_speed * 0.2, 45, 150)

func advance(delta: float, scroll: float, occupied: bool, room_height: float) -> void:
	base_y += scroll * delta
	# Substeps keep the spring stable if a rendered/physics frame is unusually long.
	var remaining := delta
	while remaining > 0:
		var step := minf(remaining, 1.0 / 120)
		dip_velocity += ((standing_dip if occupied else 0.0) - dip) * spring_strength * step - dip_velocity * spring_damping * step
		dip = clampf(dip + dip_velocity * step, -3, 22)
		remaining -= step
	var target_y := base_y + dip
	# AnimatableBody2D may defer/revert its transform until the next physics tick.
	# Write both axes from our home position rather than reading that stale transform.
	position = Vector2(base_x, target_y)
	var top := target_y - card_size.y * 0.5
	# Turn off collisions before the card could pin the frog against the floor.
	_collision.disabled = top < 12 or top > room_height - 76

func _draw() -> void:
	if _silhouette.is_empty():
		return
	draw_set_transform(Vector2(0, 6))
	draw_colored_polygon(_silhouette, Color(0.01, 0.035, 0.04, 0.3))
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(_silhouette, fill_color)
