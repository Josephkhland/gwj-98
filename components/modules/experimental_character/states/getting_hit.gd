extends ExperimentalCharacterState

func physics_update(delta: float) -> void:
	if character.is_on_floor() and character._landing_sliding:
		character._apply_ground_horizontal(delta, 0.0)
	character._apply_gravity(delta)
	if machine.elapsed >= character.settings.hit_stun_time:
		machine.transition(character.State.IDLE if character.is_on_floor() else character.State.IN_AIR)
