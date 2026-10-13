extends LegacyCharacterState
## Dive and brief impact window. Slam contacts never attach to walls/ceilings.
var impacted: bool = false
var _impact_time: float = 0.0

func enter() -> void:
	impacted = false
	_impact_time = 0.0
	character._cancel_spit_charge()
	character._detach()
	character.velocity = Vector2(0.0, character.settings.slam_speed)

func exit() -> void:
	character.slam_hitbox.end_swing()

func physics_update(delta: float) -> void:
	character.velocity.x = 0.0
	if not impacted:
		# Deliberately independent of ordinary gravity and terminal speed.
		character.velocity.y = character.settings.slam_speed
		return
	character._apply_gravity(delta)
	_impact_time += delta
	if _impact_time >= character.settings.slam_impact_time:
		machine.transition(character.State.IDLE if character.is_on_floor() else character.State.IN_AIR)

func after_move(incoming: Vector2) -> void:
	if impacted:
		return
	for index in character.get_slide_collision_count():
		var contact: KinematicCollision2D = character.get_slide_collision(index)
		if incoming.dot(contact.get_normal()) >= -1.0:
			continue
		impacted = true
		character.velocity = Vector2.ZERO
		character.slam_hitbox.global_position = contact.get_position()
		if character.settings.slam_hitbox_enabled:
			character.slam_hitbox.begin_swing(character.settings.slam_damage,
				Vector2.DOWN * character.settings.slam_hit_knockback, character)
		character.slam_impacted.emit(contact.get_collider() as Node, contact.get_position(), contact.get_normal())
		return
