class_name GroundState
extends CharacterState
## Shared floor motion for IDLE and WALKING.
func physics_update(delta: float) -> void:
	character.velocity.x = character._move_axis * character.settings.walk_speed
	character.velocity.y += character.settings.gravity * delta
	if not is_zero_approx(character._move_axis):
		character.facing = signf(character._move_axis)
	machine.transition(character.State.IDLE if is_zero_approx(character._move_axis) else character.State.WALKING)

func after_move(_incoming: Vector2) -> void:
	if not character.is_on_floor():
		machine.transition(character.State.IN_AIR)
