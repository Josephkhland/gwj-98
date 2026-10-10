extends CharacterState

func physics_update(delta: float) -> void:
	character._apply_gravity(delta)
	if machine.elapsed >= character.settings.hit_stun_time:
		machine.transition(character.State.IDLE if character.is_on_floor() else character.State.IN_AIR)
