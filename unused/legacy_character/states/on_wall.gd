extends LegacyCharacterState

func physics_update(_delta: float) -> void:
	character.velocity = Vector2.ZERO
	if machine.elapsed >= character.settings.wall_hold_duration:
		character._detach()
		machine.transition(character.State.IN_AIR)

func should_move() -> bool:
	return false
