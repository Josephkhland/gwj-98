extends Line2D
## Uses semi-implicit integration, matching the character's physics step.
@export_range(10, 3600) var steps: int = 600
var _sweep: ShapeCast2D
func _ensure_sweep() -> void:
	var actor = get_parent()
	if _sweep == null:
		_sweep = ShapeCast2D.new()
		_sweep.enabled = false
		_sweep.collide_with_areas = false
		_sweep.margin = 0.0
		if actor is CharacterBody2D:
			_sweep.shape = actor.get_node("CollisionShape2D").shape
			_sweep.add_exception_rid(actor.get_rid())
		else:
			_sweep.shape = CircleShape2D.new()
		add_child(_sweep)

func update_arc(origin: Vector2, launch_velocity: Vector2, gravity: float, mask: int) -> void:
	clear_points()
	_ensure_sweep()
	var actor = get_parent()
	_sweep.margin = 0.0
	_sweep.collision_mask = mask
	_sweep.collide_with_areas = false
	if actor is CharacterBody2D:
		_sweep.shape = actor.get_node("CollisionShape2D").shape
	var point := origin
	var simulated_velocity := launch_velocity
	var step := 1.0 / float(Engine.physics_ticks_per_second)
	var count := steps
	var bounces := 0
	var motion := PhysicsTestMotionParameters2D.new()
	var result := PhysicsTestMotionResult2D.new()
	if actor is CharacterBody2D:
		count = mini(3600, ceili(actor.settings.jump_preview_max_time / step))
	add_point(to_local(point))
	# Start outside the supporting contact margin without excluding the platform.
	if actor is CharacterBody2D and (actor.is_on_floor() or actor._attached):
		point += actor._surface_normal * (actor.safe_margin + 0.2)
	for index in count:
		simulated_velocity.y += gravity * step
		if actor is CharacterBody2D:
			simulated_velocity.y = minf(simulated_velocity.y, actor.settings.terminal_speed)
		var next := point + simulated_velocity * step
		var hit: bool
		var fraction := 1.0
		var normal := Vector2.ZERO
		if actor is CharacterBody2D:
			# Body motion tests use the same one-way collision rules as move_and_slide.
			# A raw ShapeCast treats the underside of a one-way platform as solid.
			var from: Transform2D = actor.global_transform
			from.origin = point
			motion.from = from
			motion.motion = next - point
			motion.margin = actor.safe_margin
			hit = PhysicsServer2D.body_test_motion(actor.get_rid(), motion, result)
			if hit:
				fraction = result.get_collision_safe_fraction()
				normal = result.get_collision_normal()
		else:
			_sweep.global_position = point
			_sweep.target_position = _sweep.to_local(next)
			_sweep.force_shapecast_update()
			hit = _sweep.is_colliding()
			if hit:
				fraction = _sweep.get_closest_collision_safe_fraction()
				normal = _sweep.get_collision_normal(0)
		if hit:
			point = point.lerp(next, fraction)
			add_point(to_local(point))
			if not actor is CharacterBody2D:
				break
			if normal.dot(Vector2.UP) >= cos(actor.floor_max_angle):
				break
			if bounces >= actor.settings.jump_preview_max_bounces:
				break
			bounces += 1
			simulated_velocity = actor.bounce_velocity(simulated_velocity, normal)
			# Leave enough clearance for a tangent sweep after an absorbing contact.
			point += normal * 1.0
			continue
		add_point(to_local(next))
		point = next

func update_spit_arc(origin: Vector2, launch_velocity: Vector2, radius: float) -> void:
	_ensure_sweep()
	clear_points()
	var actor = get_parent()
	var shape := CircleShape2D.new()
	shape.radius = radius
	_sweep.shape = shape
	_sweep.margin = 0.08
	_sweep.collision_mask = actor.settings.spit_collision_mask
	_sweep.collide_with_areas = true
	_sweep.add_exception_rid(actor.get_node("Hurtbox").get_rid())
	var point := origin
	var simulated_velocity := launch_velocity
	var step := 1.0 / float(Engine.physics_ticks_per_second)
	var count := mini(3600, ceili(actor.settings.spit_preview_max_time / step))
	add_point(to_local(point))
	for index in count:
		simulated_velocity.y += actor.settings.spit_gravity * step
		var next := point + simulated_velocity * step
		# The projectile also sweeps from the body to its muzzle on its first tick.
		var start: Vector2 = actor.global_position if index == 0 else point
		_sweep.global_position = start
		_sweep.target_position = _sweep.to_local(next)
		_sweep.force_shapecast_update()
		if _sweep.is_colliding():
			add_point(to_local(start.lerp(next, _sweep.get_closest_collision_safe_fraction())))
			break
		add_point(to_local(next))
		point = next
