extends Node2D
## Draw from live collision transforms so moving platforms and disabled shapes stay in sync.
var sources: Array[Node] = []

func _ready() -> void:
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded

func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()

func _draw() -> void:
	var to_local_space := global_transform.affine_inverse()
	for source in sources:
		if not is_instance_valid(source) or not source.is_inside_tree():
			continue
		var body := source.get_parent() as CanvasItem
		if body == null or not body.is_visible_in_tree():
			continue
		if source is CollisionShape2D:
			var collision := source as CollisionShape2D
			if not collision.disabled and collision.shape != null:
				draw_set_transform_matrix(to_local_space * collision.global_transform)
				collision.shape.draw(get_canvas_item(), Color.WHITE)
		elif source is CollisionPolygon2D:
			var collision := source as CollisionPolygon2D
			if not collision.disabled and collision.polygon.size() >= 3:
				draw_set_transform_matrix(to_local_space * collision.global_transform)
				if collision.build_mode == CollisionPolygon2D.BUILD_SOLIDS:
					draw_colored_polygon(collision.polygon, Color.WHITE)
				else:
					var outline := collision.polygon.duplicate()
					outline.append(outline[0])
					draw_polyline(outline, Color.WHITE, 2.0, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
