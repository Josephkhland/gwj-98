extends ExperimentalCharacterState
var _direction := Vector2.RIGHT

func enter() -> void:
	_direction = Vector2(character.facing, 0.0).rotated(character.visual.rotation)
	character.attack_pivot.rotation = _direction.angle()

func exit() -> void:
	character.hitbox.end_swing()

func physics_update(delta: float) -> void:
	if character._attached:
		character.velocity = Vector2.ZERO
	else:
		if character.is_on_floor() and character._landing_sliding:
			character._apply_ground_horizontal(delta, 0.0)
		character._apply_gravity(delta)
	var active_end: float = character.settings.attack_windup + character.settings.attack_active_time
	if machine.elapsed >= character.settings.attack_windup and machine.elapsed < active_end:
		if not character.hitbox.active:
			character.hitbox.begin_swing(character.settings.attack_damage, _direction * character.settings.attack_knockback, character)
	else:
		character.hitbox.end_swing()
	if machine.elapsed >= active_end + character.settings.attack_recovery:
		if character._attached:
			machine.transition(character.State.ON_WALL)
		else:
			machine.transition(character.State.IDLE if character.is_on_floor() else character.State.IN_AIR)

func should_move() -> bool:
	return not character._attached
