extends CharacterState
## Brief slowed movement while building a shot; contacts still use real physics.
var grounded: bool = false

func enter() -> void:
	grounded = character._spit_charge_grounded
	character._spit_charging = true
	character._spit_charge_time = 0.0
	character._spit_aim_angle = deg_to_rad(character.settings.spit_launch_angle_degrees)
	character.preview.visible = character.settings.spit_preview_enabled
	character.preview.default_color = character.settings.spit_preview_color
	if not grounded:
		character.velocity.x *= character.settings.spit_charge_air_speed_multiplier
		if character.velocity.y > 0.0:
			character.velocity.y *= character.settings.spit_charge_fall_speed_multiplier

func exit() -> void:
	character.preview.visible = false
	character._cancel_spit_charge()

func physics_update(delta: float) -> void:
	character._update_facing()
	var base: float = deg_to_rad(character.settings.spit_launch_angle_degrees)
	var maximum: float = deg_to_rad(maxf(character.settings.spit_launch_angle_degrees, character.settings.spit_maximum_aim_angle_degrees))
	var target: float = maximum if character._heighten_held else base
	var rate: float = character.settings.aim_speed_degrees if character._heighten_held else character.settings.verticality_decay_degrees
	character._spit_aim_angle = move_toward(character._spit_aim_angle, target, deg_to_rad(rate) * delta)
	if grounded:
		character._apply_ground_horizontal(delta, character.settings.spit_charge_ground_speed_multiplier)
		character.velocity.y += character.settings.gravity * delta
	else:
		character.velocity.y = minf(character.velocity.y + character.settings.gravity * character.settings.spit_charge_gravity_multiplier * delta,
			character.settings.spit_charge_fall_speed_limit)
	character._update_spit_charge(delta)
	if character.state == character.State.CHARGING_SPIT and character.settings.spit_preview_enabled:
		_update_preview()

func _update_preview() -> void:
	var origin: Vector2 = character.global_position + Vector2(character.settings.spit_spawn_offset.x * character.facing, character.settings.spit_spawn_offset.y)
	var radius: float = character.settings.spit_visual_radius * lerpf(1.0, character.settings.spit_charged_size_multiplier, character.get_spit_power_ratio())
	character.preview.update_spit_arc(origin, character.get_spit_launch_velocity(), radius)

func after_move(incoming: Vector2) -> void:
	if not grounded:
		character._resolve_air_contacts(incoming, false)
	if character.state == character.State.CHARGING_SPIT:
		grounded = character.is_on_floor() and not character._attached
		if grounded:
			character.visual.rotation = 0.0
		if character.settings.spit_preview_enabled:
			_update_preview()
