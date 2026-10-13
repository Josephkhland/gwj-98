extends LegacyCharacterState
## Holding Jump too long cancels it and locks actions through a back roll.
func enter() -> void:
	character._detach()
	character.velocity = Vector2.ZERO
	character.visual.rotation = -character.facing * PI * 0.15

func physics_update(delta: float) -> void:
	character.velocity.x = 0.0
	character._apply_gravity(delta)
	var progress: float = clampf(machine.elapsed / maxf(character.settings.back_roll_stun_time, 0.001), 0.0, 1.0)
	var tilt: float = lerpf(0.15, 1.0, minf(progress / 0.35, 1.0)) if progress < 0.75 else (1.0 - progress) / 0.25
	character.visual.rotation = -character.facing * PI * tilt
	if progress >= 1.0:
		machine.transition(character.State.IDLE if character.is_on_floor() else character.State.IN_AIR)

func exit() -> void:
	character.visual.rotation = 0.0
