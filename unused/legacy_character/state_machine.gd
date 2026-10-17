extends Node
## Character calls initialize/update; child nodes never process independently.
const LegacyCharacterState = preload("res://unused/legacy_character/states/character_state.gd")
var current: LegacyCharacterState
var elapsed: float = 0.0
var character
var _states: Dictionary = {}

func initialize(actor, initial_state: int) -> void:
	character = actor
	for child in get_children():
		assert(child is LegacyCharacterState, "StateMachine children must extend character_state.gd")
		assert(not _states.has(child.state_id), "State IDs must be unique")
		_states[child.state_id] = child
		child.setup(actor, self)
	assert(_states.has(initial_state), "Initial state is missing")
	current = _states[initial_state]
	character.visual.play(current.animation)
	current.enter()

func transition(next: int, restart: bool = false) -> void:
	assert(_states.has(next), "Requested state is missing")
	if current.state_id == next and not restart:
		return
	var previous: int = current.state_id
	current.exit()
	current = _states[next]
	if not current.allows_spit:
		character._cancel_spit_charge()
	elapsed = 0.0
	character.visual.play(current.animation)
	current.enter()
	if previous != next:
		character.state_changed.emit(previous, next)

func physics_update(delta: float, charge_started: bool, attack_started: bool,
		spit_started: bool = false, slam_started: bool = false) -> void:
	elapsed += delta
	current.handle_actions(charge_started, attack_started, spit_started, slam_started)
	# Input can transition; update the new active state in this same tick.
	current.physics_update(delta)

func should_move() -> bool:
	return current.should_move()

func after_move(incoming: Vector2) -> void:
	current.after_move(incoming)
