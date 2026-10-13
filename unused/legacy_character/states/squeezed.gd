extends LegacyCharacterState
## Non-lethal recovery uses a saved position and full-size clearance checks.
var _retry_time: float = 0.0
var _recovered: bool = false

func enter() -> void:
	_retry_time = 0.0
	_recovered = false
	character.physics_safety.begin_squeeze()
	character._detach()
	character.physics_safety._apply_squash(1.0)
	character._play_squeeze_sound()
	character.squeezed.emit()

func physics_update(delta: float) -> void:
	character.velocity = Vector2.ZERO
	if character.settings.die_when_squeezed:
		character._die()
		return
	var flatten_time: float = maxf(0.0, character.settings.squeeze_flatten_time)
	var hold_time: float = maxf(0.0, character.settings.squeeze_flat_hold_time)
	var progress: float = clampf(machine.elapsed / flatten_time, 0.0, 1.0) if flatten_time > 0.0 else 1.0
	character.physics_safety.apply_squeeze_flatten(progress)
	character.visual.visible = machine.elapsed < flatten_time + hold_time
	character._invulnerability = maxf(character._invulnerability, delta * 2.0)
	_retry_time += delta
	if machine.elapsed < flatten_time + hold_time or _retry_time < character.settings.squeeze_recovery_time:
		return
	# Bound the search frequency while all candidate positions remain blocked.
	_retry_time = maxf(0.0, character.settings.squeeze_recovery_time - 0.1)
	if character.physics_safety.try_recover_position():
		_recovered = true
		machine.transition(character.State.IN_AIR)

func should_move() -> bool:
	return false

func exit() -> void:
	character.physics_safety.stop_recovery_blink()
	if character.health > 0:
		character.physics_safety._apply_squash(0.0)
		character.physics_safety.end_squeeze()
		character._reattach_time = maxf(character._reattach_time, character.settings.squeeze_cooldown)
		if _recovered:
			character.physics_safety.start_recovery_blink()
