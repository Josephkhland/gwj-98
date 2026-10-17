extends Sprite2D

var target: Node2D
var camera: Camera2D

var edge_margin := 48.0
var offscreen_padding := 8.0
var min_scale := 0.1
var max_scale := 0.3
var near_distance := 256.0
var far_distance := 2048.0


func _ready() -> void:
	camera = get_parent() as Camera2D


func _process(_delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	if not camera:
		return

	var to_screen := camera.get_global_transform_with_canvas()
	var camera_center := camera.get_screen_center_position()

	var viewport_size := camera.get_viewport_rect().size
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	var screen_center := viewport_size * 0.5
	var edge_rect := viewport_rect.grow(-edge_margin)

	var screen_pos := to_screen * camera.to_local(target.global_position)
	var distance := target.global_position.distance_to(camera_center)

	if viewport_rect.grow(offscreen_padding).has_point(screen_pos):
		visible = false
		return

	var edge_point := _edge_position(screen_center, screen_pos, edge_rect)

	visible = true
	position = to_screen.affine_inverse() * edge_point
	rotation = (screen_pos - screen_center).angle() - to_screen.get_rotation()
	scale = Vector2.ONE * _scale_for_distance(distance) / to_screen.get_scale()


func _edge_position(center: Vector2, target_pos: Vector2, rect: Rect2) -> Vector2:
	var direction := target_pos - center
	if direction == Vector2.ZERO:
		return center
	var half := rect.size * 0.5
	var tx := half.x / absf(direction.x) if direction.x != 0.0 else INF
	var ty := half.y / absf(direction.y) if direction.y != 0.0 else INF
	return (center + direction * minf(tx, ty)).clamp(rect.position, rect.end)


func _scale_for_distance(distance: float) -> float:
	if is_equal_approx(near_distance, far_distance):
		return max_scale
	var t := clampf(inverse_lerp(near_distance, far_distance, distance), 0.0, 1.0)
	return lerpf(max_scale, min_scale, t)
