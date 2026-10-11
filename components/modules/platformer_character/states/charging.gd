extends CharacterState

func enter() -> void:
	character._landing_sliding = false
	if not character._attached:
		character.surface_anchor.capture_floor()
		character._surface_normal = character.get_floor_normal()
		if character._surface_normal.is_zero_approx():
			character._surface_normal = Vector2.UP
	character._charge_time = 0.0
	character._aim_angle = deg_to_rad(character.settings.maximum_aim_angle_degrees) * character.facing * character._aim_control_sign()
	character.preview.visible = true
	character.preview.default_color = character.settings.jump_preview_color

func exit() -> void:
	character.preview.visible = false

func physics_update(delta: float) -> void:
	character.velocity = Vector2.ZERO
	character._charge_time = minf(character._charge_time + delta, character.settings.max_charge_time)
	character._update_facing()
	var limit: float = deg_to_rad(character.settings.maximum_aim_angle_degrees)
	var minimum: float = deg_to_rad(minf(character.settings.minimum_aim_angle_degrees, character.settings.maximum_aim_angle_degrees))
	var target: float = minimum if character._heighten_held else limit
	var rate: float = character.settings.aim_speed_degrees if character._heighten_held else character.settings.verticality_decay_degrees
	var previous: float = absf(character._aim_angle)
	var magnitude: float = move_toward(previous, target, deg_to_rad(rate) * delta)
	character._aim_angle = magnitude * character.facing * character._aim_control_sign()
	if not character._charge_held:
		character._launch()
		return
	if character._charge_time >= character.settings.max_charge_time:
		var on_ground: bool = character._surface_normal.dot(Vector2.UP) >= cos(character.floor_max_angle)
		character._detach()
		machine.transition(character.State.ROLLING_BACK if on_ground else character.State.IN_AIR)
		return
	character.preview.update_arc(character.global_position, character.get_launch_velocity(), character.settings.gravity, character.collision_mask)

func should_move() -> bool:
	return false
