class_name LegacyAirborneState
extends LegacyCharacterState
## Left/right turn the character without changing its ballistic velocity.
func physics_update(delta: float) -> void:
	character._update_facing()
	character._apply_gravity(delta)

func after_move(incoming: Vector2) -> void:
	character._resolve_air_contacts(incoming)
