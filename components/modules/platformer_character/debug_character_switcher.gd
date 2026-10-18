extends Node
## Compare scene variants without replacing the player referenced by the level.
const ACTION: StringName = &"debug_toggle_character"
const PROTOTYPE := "res://components/modules/platformer_character/PlatformerCharacter.tscn"
const ANIMATED := "res://components/modules/platformer_character/FrogineerCharacter.tscn"
const COLLISIONS: Array[NodePath] = [^"CollisionShape2D", ^"Hurtbox/CollisionShape2D",
	^"AttackPivot/Hitbox/CollisionShape2D", ^"SlamHitbox/CollisionShape2D"]

var _character: CharacterBody2D
var _profiles: Array[Dictionary] = []
var _active: int = 0
var _switch_pending: bool = false

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	_character = get_parent() as CharacterBody2D
	if not InputMap.has_action(ACTION):
		InputMap.add_action(ACTION)
		var key := InputEventKey.new()
		key.physical_keycode = KEY_F9
		InputMap.action_add_event(ACTION, key)

func _unhandled_key_input(event: InputEvent) -> void:
	if OS.is_debug_build() and _character.player_controlled and not _switch_pending \
			and event.is_action_pressed(ACTION) and not event.is_echo():
		_switch_pending = true
		get_viewport().set_input_as_handled()
		_switch_character.call_deferred()

func _capture(actor: CharacterBody2D) -> Dictionary:
	var appearance: Node2D = actor.get_node(^"Visual")
	var collisions: Array[Dictionary] = []
	for path in COLLISIONS:
		var collider: CollisionShape2D = actor.get_node(path)
		collisions.append({"shape": collider.shape, "transform": collider.transform,
			"disabled": collider.disabled})
	return {"visual": appearance, "scale": appearance.scale,
		"visible": appearance.visible, "collisions": collisions}

func _switch_character() -> void:
	_switch_pending = false
	if not OS.is_debug_build() or not is_inside_tree():
		return
	if _profiles.is_empty():
		_profiles.append(_capture(_character))
		var animated: bool = _character.visual.has_node(^"Facing/AnimatedSprite2D")
		var scene: PackedScene = load(PROTOTYPE if animated else ANIMATED)
		var template: CharacterBody2D = scene.instantiate()
		var other := _capture(template)
		template.remove_child(other.visual)
		template.free()
		_profiles.append(other)
	var previous: Dictionary = _profiles[_active]
	var old_visual: Node2D = previous.visual
	var rotation := old_visual.rotation
	var squash: Vector2 = old_visual.scale / Vector2(previous.scale)
	var shown := old_visual.visible
	# A detached animated visual must not react to this player's spit signal.
	if old_visual.has_method(&"_on_spit_fired"):
		_character.spit_fired.disconnect(Callable(old_visual, &"_on_spit_fired"))
	_character.remove_child(old_visual)
	_active = 1 - _active
	var current: Dictionary = _profiles[_active]
	var new_visual: Node2D = current.visual
	var returning := new_visual.is_node_ready()
	_character.visual = new_visual
	new_visual.facing = _character.facing
	_character.add_child(new_visual)
	if returning and new_visual.has_method(&"_on_spit_fired"):
		_character.spit_fired.connect(Callable(new_visual, &"_on_spit_fired"))
	new_visual.rotation = rotation
	new_visual.scale = Vector2(current.scale) * squash
	new_visual.visible = shown
	new_visual.play(_character.state_machine.current.animation)
	_character.physics_safety._base_scale = current.scale
	_character.physics_safety._base_visible = current.visible
	for index in COLLISIONS.size():
		var collider: CollisionShape2D = _character.get_node(COLLISIONS[index])
		var data: Dictionary = current.collisions[index]
		collider.shape = data.shape
		collider.transform = data.transform
		collider.disabled = data.disabled
	var footsteps: FootstepAudio = _character.get_node(^"FootstepAudio")
	old_visual.foot_contact.disconnect(footsteps._on_foot_contact)
	footsteps.visual = new_visual
	new_visual.foot_contact.connect(footsteps._on_foot_contact)
	print("Debug character: ", "Frogineer" if new_visual.has_node(^"Facing/AnimatedSprite2D") else "Prototype")

func _exit_tree() -> void:
	for profile in _profiles:
		var appearance: Node2D = profile.visual
		if is_instance_valid(appearance) and appearance.get_parent() == null:
			appearance.free()
