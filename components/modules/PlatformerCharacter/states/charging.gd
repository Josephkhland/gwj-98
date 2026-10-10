extends CharacterState


func enter() -> void:
	if not character._attached:
		character.surface_anchor.capture_floor()
		character._surface_normal = character.get_floor_normal()
		if character._surface_normal.is_zero_approx():
			character._surface_normal = Vector2.UP
	character._charge_time = 0.0
	character._aim_angle = deg_to_rad(minf(30.0, character.settings.maximum_aim_angle_degrees)) * character.facing * character._aim_control_sign()
	character.preview.visible = true

func exit() -> void:
	character.preview.visible = false

func physics_update(delta: float) -> void:
	character.velocity = Vector2.ZERO
	character._charge_time = minf(character._charge_time + delta, character.settings.max_charge_time)
	var limit: float = deg_to_rad(character.settings.maximum_aim_angle_degrees)
	character._aim_angle = clampf(character._aim_angle + character._move_axis * character._aim_control_sign() * deg_to_rad(character.settings.aim_speed_degrees) * delta, -limit, limit)
	character.preview.update_arc(character.global_position, character.get_launch_velocity(), character.settings.gravity, character.collision_mask)
	if not character._charge_held or character._charge_time >= character.settings.max_charge_time:
		character._launch()

func should_move() -> bool:
	return false
