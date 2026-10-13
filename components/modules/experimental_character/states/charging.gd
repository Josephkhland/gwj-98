extends ExperimentalCharacterState

var supported: bool = false
var support_velocity := Vector2.ZERO

func enter() -> void:
	supported = character._attached or character.is_on_floor()
	support_velocity = character._slide_surface_velocity if character._attached else character.get_platform_velocity()
	if character._attached:
		character.velocity -= support_velocity
	if not character._attached and character.is_on_floor():
		character.surface_anchor.capture_floor()
		character._surface_normal = character.get_floor_normal()
		if character._surface_normal.is_zero_approx():
			character._surface_normal = Vector2.UP
	character._charge_time = 0.0
	character.preview.visible = true
	character.preview.default_color = character.settings.jump_preview_color
	if supported:
		character.physics_safety.recover_held(1.0 / float(Engine.physics_ticks_per_second))

func exit() -> void:
	character.preview.visible = false

func physics_update(delta: float) -> void:
	if character.physics_safety.movement_locked():
		return
	character._charge_time = minf(character._charge_time + delta, character.settings.max_charge_time)
	character._update_facing()
	if not character._charge_held:
		character._launch()
		return
	if character._charge_time >= character.settings.max_charge_time:
		var on_ground: bool = supported and not character._attached
		character._detach()
		machine.transition(character.State.ROLLING_BACK if on_ground else character.State.IN_AIR)
		return
	if supported:
		var normal: Vector2 = character._surface_normal
		character.velocity = character.velocity.slide(normal)
		character.velocity += Vector2.DOWN.slide(normal) * character.settings.gravity * delta
		character._apply_surface_friction(delta, normal)
		var collision: KinematicCollision2D = character.move_and_collide(character.velocity * delta)
		if collision != null:
			character.velocity = character.velocity.slide(collision.get_normal())
		character.surface_anchor.rebase_position()
		var probe := KinematicCollision2D.new()
		var distance: float = character.safe_margin + character.floor_snap_length + support_velocity.length() * delta + 1.0
		if character.test_move(character.global_transform, -normal * distance, probe) and probe.get_normal().dot(normal) > 0.99:
			support_velocity = probe.get_collider_velocity()
		else:
			supported = false
			character.velocity += support_velocity
			character._suspend_platform_carry()
			character._detach()
	else:
		character._apply_gravity(delta)
	character.preview.update_arc(character.global_position, character.get_launch_velocity(), character.settings.gravity, character.collision_mask)

func should_move() -> bool:
	return not supported

func after_move(incoming: Vector2) -> void:
	character._resolve_air_contacts(incoming, false)
