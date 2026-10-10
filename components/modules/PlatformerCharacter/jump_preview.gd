extends Line2D
## Uses semi-implicit integration, matching the character's physics step.
@export_range(10, 180) var steps: int = 75
func update_arc(origin: Vector2, launch_velocity: Vector2, gravity: float, mask: int) -> void:
	clear_points()
	var point := origin
	var simulated_velocity := launch_velocity
	var step := 1.0 / float(Engine.physics_ticks_per_second)
	add_point(to_local(point))
	for index in steps:
		simulated_velocity.y += gravity * step
		var next := point + simulated_velocity * step
		var query := PhysicsRayQueryParameters2D.create(point, next, mask)
		var result := get_world_2d().direct_space_state.intersect_ray(query)
		if not result.is_empty():
			add_point(to_local(result.position))
			break
		add_point(to_local(next))
		point = next
