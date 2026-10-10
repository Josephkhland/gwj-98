class_name AirborneState
extends CharacterState
## Shared ballistic physics and contact response for Jumping and InAir.
func physics_update(delta: float) -> void:
	character._apply_gravity(delta)

func after_move(incoming: Vector2) -> void:
	character._resolve_air_contacts(incoming)
