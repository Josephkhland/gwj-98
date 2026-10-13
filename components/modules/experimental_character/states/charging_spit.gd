extends ExperimentalCharacterState
## Brief slowed movement while building a shot; contacts still use real physics.
var grounded: bool = false

func enter() -> void:
	grounded = character._spit_charge_grounded
	character._spit_charging = true
	character._spit_charge_time = 0.0
	character._spit_aim_angle = deg_to_rad(character.settings.spit_launch_angle_degrees)
	character.preview.visible = character.settings.spit_preview_enabled
	character.preview.default_color = character.settings.spit_preview_color

func exit() -> void:
	character.preview.visible = false
	character._cancel_spit_charge()

func physics_update(delta: float) -> void:
	character._update_facing()
	if grounded:
		character._apply_ground_horizontal(delta, character.settings.spit_charge_ground_speed_multiplier)
		character.velocity.y += character.settings.gravity * delta
	else:
		character._apply_gravity(delta)
	character._update_spit_charge(delta)
	if character.state == character.State.CHARGING_SPIT and character.settings.spit_preview_enabled:
		_update_preview()

func _update_preview() -> void:
	var origin: Vector2 = character.get_spit_origin()
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
