class_name CharacterState
extends Node
## State nodes are driven explicitly by StateMachine, never by engine callbacks.
@export var state_id: int = 0
@export var animation: StringName = &"idle"
@export var allows_charge: bool = true
@export var allows_attack: bool = true
var character
var machine

func setup(actor, state_machine) -> void:
	character = actor
	machine = state_machine

func enter() -> void:
	pass

func exit() -> void:
	pass

func handle_actions(charge_started: bool, attack_started: bool) -> void:
	if allows_charge and charge_started and (character.is_on_floor() or character._attached):
		machine.transition(character.State.CHARGING)
	elif allows_attack and attack_started:
		machine.transition(character.State.ATTACKING)

func physics_update(_delta: float) -> void:
	pass

func should_move() -> bool:
	return true

func after_move(_incoming: Vector2) -> void:
	pass
