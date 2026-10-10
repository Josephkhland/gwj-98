extends AirborneState

func physics_update(delta: float) -> void:
	super.physics_update(delta)
	if machine.elapsed >= character.settings.minimum_jump_duration:
		machine.transition(character.State.IN_AIR)
