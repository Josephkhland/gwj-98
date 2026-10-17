extends RefCounted

var boost: float = 0.0

func decay(delta: float, decay_coefficient: float) -> void:
	# Decay in boost units per second, including while airborne.
	boost = maxf(0.0, boost - decay_coefficient * delta)

func register_impact(entry_velocity: Vector2, normal: Vector2, surface_velocity: Vector2, boost_coefficient: float) -> void:
	# Use velocity BEFORE collision response; afterwards the impact component
	# may already be zero. Motion away from the surface contributes no boost.
	var impact_speed := maxf(0.0, -(entry_velocity - surface_velocity).dot(normal))
	# Boost is dimensionless; the coefficient converts impact speed to a boost.
	boost = maxf(boost, boost_coefficient * impact_speed)

func apply(velocity: Vector2, normal: Vector2, surface_velocity: Vector2, delta: float, friction_coefficient: float) -> Vector2:
	# A ground-state tick can run after floor contact is lost. No surface means no friction.
	if normal.is_zero_approx():
		return velocity
	# Damp relative sliding speed without damping the carrier's own movement.
	var tangent_velocity := (velocity - surface_velocity).slide(normal.normalized())
	# Friction is a rate in inverse seconds; boost scales that rate.
	var effective_friction := friction_coefficient * (1.0 + boost)
	# With nonnegative tuning and delta, damping stays between zero and one.
	var damping := 1.0 - exp(-effective_friction * delta)
	# Subtract only the lost tangent speed, preserving normal velocity.
	return velocity - tangent_velocity * damping
