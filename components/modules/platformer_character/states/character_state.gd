class_name CharacterState
extends Node
## State nodes are driven explicitly by StateMachine, never by engine callbacks.
@export var state_id: int = 0
@export var animation: StringName = &"idle"
@export var allows_charge: bool = true
@export var allows_attack: bool = true
@export var allows_spit: bool = false
@export var allows_slam: bool = false
var character
var machine

func setup(actor, state_machine) -> void:
	character = actor
	machine = state_machine

func enter() -> void:
	pass

func exit() -> void:
	pass

func handle_actions(charge_started: bool, attack_started: bool,
		spit_started: bool = false, slam_started: bool = false) -> void:
	if allows_spit or allows_slam:
		character._update_facing()
	if allows_slam and slam_started and character.settings.slam_enabled and not character.is_grounded() and not character._attached:
		machine.transition(character.State.SLAMMING)
	elif allows_charge and charge_started and (character.is_grounded() or character._attached):
		machine.transition(character.State.CHARGING)
	elif allows_attack and attack_started:
		machine.transition(character.State.ATTACKING)
	elif allows_spit and spit_started:
		character._begin_spit()

func physics_update(_delta: float) -> void:
	pass

func should_move() -> bool:
	return true

func after_move(_incoming: Vector2) -> void:
	pass
