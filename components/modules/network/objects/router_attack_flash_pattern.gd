@tool
extends RefCounted
## Deterministic short bursts shared by world and minimap, offset per router.
static func get_flashes(elapsed: float, router_id: int) -> Array[Dictionary]:
	var interval := 0.24
	var bucket := int(floor(elapsed / interval))
	var phase := fposmod(elapsed / interval, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([router_id, bucket])
	var sectors: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7]
	var flashes: Array[Dictionary] = []
	for index in rng.randi_range(2, 3):
		var selected := rng.randi_range(0, sectors.size() - 1)
		var angle := TAU * sectors[selected] / 8.0 + rng.randf_range(-0.15, 0.15)
		sectors.remove_at(selected)
		var start := rng.randf_range(0.0, 0.25)
		var lifetime := rng.randf_range(0.5, 0.75)
		var heat := rng.randf()
		var progress := (phase - start) / lifetime
		if progress > 0.0 and progress < 1.0:
			flashes.append({"angle": angle, "alpha": sin(progress * PI), "heat": heat})
	return flashes

static func make_ray(angle: float, inner_radius: float, outer_radius: float) -> PackedVector2Array:
	var direction := Vector2.RIGHT.rotated(angle)
	var side := direction.orthogonal()
	var length := outer_radius - inner_radius
	return PackedVector2Array([
		direction * inner_radius,
		direction * (inner_radius + length * 0.25) + side * length * 0.125,
		direction * (inner_radius + length * 0.45) - side * length * 0.125,
		direction * (inner_radius + length * 0.75) + side * length * 0.1,
		direction * outer_radius,
	])
