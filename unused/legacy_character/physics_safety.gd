extends Node
## Detect opposing platform pressure and recover to a checked full-size position.
signal squash_changed(amount: float)
var character
var _shape_node: CollisionShape2D
var _base_scale := Vector2.ONE
var _blocked: bool = false
var _crush_time: float = 0.0
var _cooldown: float = 0.0
var _compression_normal := Vector2.RIGHT
var _pressure_active: bool = false
var _last_clear_position := Vector2.ZERO
var _squeeze_origin := Vector2.ZERO
var _has_clear_position: bool = false
var _base_visible: bool = true
var _blink_remaining: float = 0.0
var _blink_elapsed: float = 0.0

func initialize(actor) -> void:
	character = actor
	_shape_node = actor.get_node("CollisionShape2D")
	_base_scale = character.visual.scale
	_base_visible = character.visual.visible
	_last_clear_position = character.global_position
	_squeeze_origin = character.global_position

func begin_tick() -> void:
	_blocked = false
	if character.state == character.State.SQUEEZED:
		return
	if _pressure_active:
		var anchor = character.surface_anchor
		var support := anchor._surface.get_ref() as Node2D if anchor._surface != null else null
		var supported: bool = is_instance_valid(support) and support.is_inside_tree()
		if supported and support is PhysicsBody2D:
			supported = PhysicsServer2D.body_get_space(support.get_rid()).is_valid()
		_blocked = supported and _has_penetration()
		if not _blocked:
			_pressure_active = false
	if not _pressure_active and position_is_clear(character.global_position):
		_last_clear_position = character.global_position
		_has_clear_position = true

func movement_locked() -> bool:
	return _pressure_active or character.state == character.State.SQUEEZED

func note_blocked(normal: Vector2, pressure_normal: Vector2 = Vector2.ZERO) -> bool:
	if pressure_normal.is_zero_approx():
		pressure_normal = character._surface_normal
	var opposing := pressure_normal.dot(normal) < -0.6
	if opposing:
		if not _pressure_active:
			_squeeze_origin = _last_clear_position if _has_clear_position else character.global_position
		_pressure_active = true
		_blocked = true
		character.velocity = Vector2.ZERO
		_compression_normal = normal
	return opposing

func _query() -> PhysicsShapeQueryParameters2D:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape_node.shape
	query.transform = _shape_node.global_transform
	query.collision_mask = character.collision_mask
	# Clearance must include every world solid, including a previous carrier.
	query.exclude = [character.get_rid()]
	query.collide_with_areas = false
	return query

func position_is_clear(position: Vector2) -> bool:
	if _shape_node.shape == null:
		return false
	var query := _query()
	query.transform.origin += position - character.global_position
	var points: PackedVector2Array = character.get_world_2d().direct_space_state.collide_shape(query, 32)
	for index in range(0, points.size(), 2):
		if points[index].distance_to(points[index + 1]) > character.settings.crush_overlap_tolerance:
			return false
	return true

func _has_penetration() -> bool:
	return not position_is_clear(character.global_position)

func recover_held(delta: float) -> void:
	if movement_locked() or _shape_node.disabled or _shape_node.shape == null:
		return
	# Remember the incoming moving collider before resolving its penetration.
	var query := _query()
	var space: PhysicsDirectSpaceState2D = character.get_world_2d().direct_space_state
	var hits: Array[Dictionary] = space.intersect_shape(query, 16)
	var base_exclusions: Array[RID] = query.exclude
	var carrier: Node2D
	var carrier_normal := Vector2.ZERO
	var best_push: float = 0.01
	for hit in hits:
		var exclusions: Array[RID] = base_exclusions.duplicate()
		for other in hits:
			if other.rid != hit.rid:
				exclusions.append(other.rid)
		query.exclude = exclusions
		var rest: Dictionary = space.get_rest_info(query)
		if rest.is_empty():
			continue
		var push: float = rest.linear_velocity.dot(rest.normal)
		if push > best_push and hit.collider is PhysicsBody2D:
			best_push = push
			carrier = hit.collider
			carrier_normal = rest.normal
	var supported: bool = character._attached or character.is_on_floor() or character.surface_anchor._surface != null
	if supported and carrier != null and carrier_normal.dot(character._surface_normal) < -0.6:
		note_blocked(carrier_normal)
		character.surface_anchor.prefer_immobile(carrier, carrier_normal)
		return
	# This runs even with zero velocity: charging must still resolve collisions.
	for attempt in 4:
		character.move_and_collide(Vector2.ZERO, false, character.safe_margin, true)
		if not _has_penetration():
			break
	if character.state == character.State.CHARGING:
		character.surface_anchor.rebase_position()
	if carrier != null and not _has_penetration():
		# Leave one physics step of approach clearance when acquiring a carrier.
		# Animatable collider transforms can commit after user physics callbacks.
		var had_exception: bool = character.get_collision_exceptions().has(carrier)
		if not had_exception:
			character.add_collision_exception_with(carrier)
		var obstruction: KinematicCollision2D = character.move_and_collide(carrier_normal * (best_push * delta + character.safe_margin))
		if not had_exception:
			character.remove_collision_exception_with(carrier)
		if character.state == character.State.CHARGING:
			character.surface_anchor.rebase_position()
		if obstruction != null:
			if note_blocked(obstruction.get_normal(), carrier_normal):
				character.surface_anchor.prefer_immobile(obstruction.get_collider() as Node2D, obstruction.get_normal())
			return
		if character.state == character.State.CHARGING:
			# Resolve the push while retaining the original support and jump frame.
			# Never capture an incoming side platform as a charging surface.
			return
		if carrier_normal.dot(Vector2.UP) < cos(character.floor_max_angle) and not character.surface_has_sticky_layer(carrier):
			character._detach()
			character._change_state(character.State.IN_AIR)
			return
		character.surface_anchor.capture(carrier, carrier_normal)
		character._surface_normal = carrier_normal
		character._attached = true
		character.visual.rotation = Vector2.UP.angle_to(carrier_normal)
		# Preserve state, accumulated force, aim angle and the state clock.

func is_trapped() -> bool:
	return _blocked or _pressure_active or _has_penetration()

func begin_squeeze() -> void:
	stop_recovery_blink()
	if not _pressure_active:
		_squeeze_origin = _last_clear_position if _has_clear_position else character.global_position
	_pressure_active = true
	character.velocity = Vector2.ZERO

func try_recover_position() -> bool:
	# Prefer the position before pressure started, not the penetrated position.
	if _recover_at(_squeeze_origin):
		return true
	var radius: float = character.settings.squeeze_recovery_search_radius
	var step: float = maxf(1.0, character.settings.squeeze_recovery_search_step)
	var rings := ceili(radius / step)
	for ring in range(1, rings + 1):
		var distance := minf(float(ring) * step, radius)
		for direction in range(16):
			var offset := Vector2.UP.rotated(TAU * float(direction) / 16.0) * distance
			if _recover_at(_squeeze_origin + offset):
				return true
	return false

func _recover_at(position: Vector2) -> bool:
	if not position_is_clear(position):
		return false
	character._detach()
	character.global_position = position
	character.velocity = Vector2.ZERO
	_last_clear_position = position
	_has_clear_position = true
	_pressure_active = false
	_blocked = false
	return true

func end_squeeze() -> void:
	_pressure_active = false
	_blocked = false
	_crush_time = 0.0
	_cooldown = character.settings.squeeze_cooldown

func finish_tick(delta: float) -> void:
	if character.health <= 0 or character.state == character.State.SQUEEZED:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown > 0.0:
		_pressure_active = false
		_crush_time = 0.0
		_apply_squash(0.0)
		return
	# Ordinary floor penetration/slop is not evidence of opposing pressure.
	if _blocked:
		_crush_time += delta
	else:
		_crush_time = 0.0
	_apply_squash(clampf(_crush_time / character.settings.crush_grace_time, 0.0, 1.0))
	if _crush_time >= character.settings.crush_grace_time:
		character._change_state(character.State.SQUEEZED)
	elif not _pressure_active and position_is_clear(character.global_position):
		_last_clear_position = character.global_position
		_has_clear_position = true

func _apply_squash(amount: float) -> void:
	var local_normal: Vector2 = _compression_normal.rotated(-character.visual.global_rotation)
	var compressed := lerpf(1.0, 0.35, amount)
	var expanded := lerpf(1.0, 1.2, amount)
	var scale_factor := Vector2(compressed, expanded) if absf(local_normal.x) > absf(local_normal.y) else Vector2(expanded, compressed)
	character.visual.scale = _base_scale * scale_factor
	squash_changed.emit(amount)

## Presentation only: frame processing never moves the collider or changes state.
func _process(delta: float) -> void:
	if _blink_remaining <= 0.0:
		return
	if character.health <= 0:
		stop_recovery_blink()
		return
	_blink_remaining = maxf(0.0, _blink_remaining - delta)
	_blink_elapsed += delta
	if _blink_remaining <= 0.0:
		stop_recovery_blink()
		return
	var interval: float = maxf(0.02, character.settings.squeeze_blink_interval)
	character.visual.visible = _base_visible and int(_blink_elapsed / interval) % 2 == 0

func start_recovery_blink() -> void:
	stop_recovery_blink()
	_blink_remaining = maxf(0.0, character.settings.squeeze_reappear_blink_time)
	_blink_elapsed = 0.0
	# Blinking communicates the temporary recovery invulnerability.
	character._invulnerability = maxf(character._invulnerability, _blink_remaining)

func stop_recovery_blink() -> void:
	_blink_remaining = 0.0
	_blink_elapsed = 0.0
	character.visual.visible = _base_visible

func apply_squeeze_flatten(progress: float) -> void:
	var local_normal: Vector2 = _compression_normal.rotated(-character.visual.global_rotation)
	var compressed := lerpf(0.35, 0.01, clampf(progress, 0.0, 1.0))
	var expanded := lerpf(1.2, 1.5, clampf(progress, 0.0, 1.0))
	var factor := Vector2(compressed, expanded) if absf(local_normal.x) > absf(local_normal.y) else Vector2(expanded, compressed)
	character.visual.scale = _base_scale * factor
