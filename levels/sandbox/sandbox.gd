extends GameLevel
## Test day for the orchestrator loop: four houses linked by six routers with redundant routes,
## static and moving platforms, and sticky (green) surfaces to climb.

signal player_changed(character: CharacterBody2D)

const ORIGINAL_CHARACTER = preload("res://components/modules/platformer_character/PlatformerCharacter.tscn")
const EXPERIMENTAL_CHARACTER = preload("res://components/modules/experimental_character/ExperimentalCharacter.tscn")

var _experimental_mode: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key != KEY_1 and key != KEY_2:
		return
	get_viewport().set_input_as_handled()
	_switch_character.call_deferred(key == KEY_2)

func _switch_character(experimental: bool) -> void:
	if experimental == _experimental_mode or not is_instance_valid(player) or player.health <= 0:
		return
	var previous = player
	var replacement = (EXPERIMENTAL_CHARACTER if experimental else ORIGINAL_CHARACTER).instantiate()
	var previous_position: Vector2 = previous.global_position
	replacement.name = previous.name
	replacement.z_index = previous.z_index
	replacement.position = to_local(previous_position)
	remove_child(previous)
	add_child(replacement)
	replacement.velocity = previous.velocity
	replacement.facing = previous.facing
	replacement.health = mini(previous.health, replacement.settings.maximum_health)
	replacement.spit_charges = mini(previous.spit_charges, replacement.settings.spit_maximum_charges)
	replacement._spit_recharge_progress = previous._spit_recharge_progress
	replacement._spit_recharge_ready = previous._spit_recharge_ready
	replacement._was_charge = previous._was_charge
	replacement._was_spit = previous._was_spit
	replacement._was_attack = previous._was_attack
	replacement._was_slam = previous._was_slam
	player = replacement
	_experimental_mode = experimental
	$CameraManager2D/FollowCamera2D.follow_target = player
	get_minimap_feed().player = player
	player_changed.emit(player)
	previous.queue_free()
