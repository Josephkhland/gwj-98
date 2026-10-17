@tool
extends Control
## Draggable antenna. The art is authored as child nodes: Pivot rotates and holds
## the Rod sprite plus a Tip marker; Base is a static sprite over the rod's foot.
## angle 0 points straight up, positive leans right. Only the rod is clickable.

signal drag_started
signal drag_ended
signal angle_changed(angle: float)

@export_range(-90.0, 90.0, 0.1, "radians_as_degrees") var angle: float = 0.0:
	set(value):
		angle = clampf(value, min_angle, max_angle)
		_apply_angle()
@export_range(-90.0, 0.0, 0.1, "radians_as_degrees") var min_angle: float = deg_to_rad(-60.0)
@export_range(0.0, 90.0, 0.1, "radians_as_degrees") var max_angle: float = deg_to_rad(60.0)
@export var grab_radius: float = 26.0
var dragging: bool = false

func _ready() -> void:
	_apply_angle()

func _apply_angle() -> void:
	var rotating := get_node_or_null(^"Pivot") as Node2D
	if rotating != null:
		rotating.rotation = angle

func pivot() -> Vector2:
	var rotating := get_node_or_null(^"Pivot") as Node2D
	return rotating.position if rotating != null else size / 2.0

## Grab point at the end of the rod, in this control's coordinates.
func tip_position() -> Vector2:
	var rotating := get_node_or_null(^"Pivot") as Node2D
	var tip := get_node_or_null(^"Pivot/Tip") as Node2D
	if rotating == null or tip == null:
		return pivot()
	return rotating.transform * tip.position

func _has_point(point: Vector2) -> bool:
	return Geometry2D.get_closest_point_to_segment(point, pivot(), tip_position()).distance_to(point) <= grab_radius

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not dragging:
			dragging = true
			drag_started.emit()
			_drag_to(event.position)
		elif not event.pressed and dragging:
			dragging = false
			drag_ended.emit()
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		_drag_to(event.position)
		accept_event()

func _drag_to(point: Vector2) -> void:
	var offset := point - pivot()
	if offset.length() < 8.0:
		return
	var previous := angle
	angle = atan2(offset.x, -offset.y)
	if not is_equal_approx(previous, angle):
		angle_changed.emit(angle)
