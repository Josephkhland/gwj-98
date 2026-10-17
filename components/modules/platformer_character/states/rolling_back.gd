extends CharacterState
## Holding Jump too long cancels it and locks actions through a back roll.
var fall_until_landing: bool = false

func enter() -> void:
	fall_until_landing = character._attached
	character._detach()
	character._slide_normal = Vector2.ZERO
	character._coyote_remaining = 0.0
	character.velocity = Vector2.ZERO
	character.visual.rotation = -character.facing * PI * 0.15

func physics_update(delta: float) -> void:
	character.velocity.x = 0.0
	character._apply_gravity(delta)
	var duration: float = maxf(character.settings.back_roll_stun_time, 0.001)
	var progress: float = fmod(machine.elapsed / duration, 1.0) if fall_until_landing else clampf(machine.elapsed / duration, 0.0, 1.0)
	var tilt: float = lerpf(0.15, 1.0, minf(progress / 0.35, 1.0)) if progress < 0.75 else (1.0 - progress) / 0.25
	character.visual.rotation = -character.facing * PI * tilt
	if not fall_until_landing and progress >= 1.0:
		machine.transition(character.State.IDLE if character.is_on_floor() else character.State.IN_AIR)

func after_move(_incoming: Vector2) -> void:
	if fall_until_landing and character.is_on_floor():
		machine.transition(character.State.IDLE)

func exit() -> void:
	character.visual.rotation = 0.0
