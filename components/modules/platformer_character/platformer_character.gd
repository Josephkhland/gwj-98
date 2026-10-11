extends CharacterBody2D
## Shared services; StateMachine child nodes own state-specific behavior.
signal state_changed(previous: State, current: State)
signal health_changed(current: int, maximum: int)
signal died
signal squeezed
enum State { IDLE, WALKING, CHARGING, JUMPING, IN_AIR, ON_WALL, ATTACKING, GETTING_HIT, SQUEEZED }
const Settings = preload("res://components/modules/platformer_character/character_settings.gd")
const ANIMATIONS: Array[StringName] = [
	&"idle", &"walking", &"charging", &"jumping", &"in_air",
	&"on_wall", &"attacking", &"getting_hit", &"squeezed"
]
@export var settings: Settings = Settings.new()
@export var player_controlled: bool = true
## Legacy sound override; prefer Settings.squeeze_sound for new configurations.
@export var splatter_sound: AudioStream
@export_group("Input Map actions (empty or missing disables input)")
@export var move_left_action: StringName = &""
@export var move_right_action: StringName = &""
@export var charge_action: StringName = &""
@export var attack_action: StringName = &""
@onready var visual: Node2D = $Visual
@onready var hitbox: Area2D = $AttackPivot/Hitbox
@onready var attack_pivot: Node2D = $AttackPivot
@onready var preview: Line2D = $JumpPreview
@onready var state_machine = $StateMachine
@onready var surface_anchor = $SurfaceAnchor
@onready var physics_safety = $PhysicsSafety
@onready var splatter_audio: AudioStreamPlayer2D = $SplatterAudio
var state: State:
	get:
		return state_machine.current.state_id if is_instance_valid(state_machine) and state_machine.current != null else State.IN_AIR
var health: int
var _death_emitted: bool = false
var _last_squeeze_audio: AudioStreamPlayer2D
var facing: float = 1.0
# Compatibility accessor; StateMachine owns the active-state clock.
var _state_time: float:
	get:
		return state_machine.elapsed
	set(value):
		state_machine.elapsed = value
var _charge_time: float = 0.0
var _aim_angle: float = 0.0
var _surface_normal := Vector2.UP
var _attached: bool = false
var _reattach_time: float = 0.0
var _invulnerability: float = 0.0
var _move_axis: float = 0.0
var _charge_held: bool = false
var _attack_held: bool = false
var _was_charge: bool = false
var _was_attack: bool = false

func _ready() -> void:
	health = settings.maximum_health
	physics_safety.initialize(self)
	surface_anchor.initialize(self)
	state_machine.initialize(self, State.IN_AIR)
	health_changed.emit(health, settings.maximum_health)
	if player_controlled:
		# To let interractibles detect it among other potential uses
		add_to_group("players") 

## Call each physics tick with player_controlled=false to drive AI or custom input.
func set_controls(move_axis: float, charge_held: bool, attack_held: bool) -> void:
	_move_axis = clampf(move_axis, -1.0, 1.0)
	_charge_held = charge_held
	_attack_held = attack_held

func _pressed(action: StringName) -> bool:
	return action != &"" and InputMap.has_action(action) and Input.is_action_pressed(action)
func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	if player_controlled:
		set_controls(
			float(_pressed(move_right_action)) - float(_pressed(move_left_action)),
			_pressed(charge_action), _pressed(attack_action))
	_reattach_time = maxf(0.0, _reattach_time - delta)
	_invulnerability = maxf(0.0, _invulnerability - delta)
	var charge_started := _charge_held and not _was_charge
	var attack_started := _attack_held and not _was_attack
	_was_charge = _charge_held
	_was_attack = _attack_held
	physics_safety.begin_tick()
	if not state_machine.should_move() and not physics_safety.movement_locked():
		surface_anchor.follow()
		if not state_machine.should_move():
			physics_safety.recover_held(delta)
	state_machine.physics_update(delta, charge_started, attack_started)
	if health <= 0:
		return
	visual.facing = facing
	if state_machine.should_move() and not physics_safety.movement_locked():
		var incoming_velocity := velocity
		move_and_slide()
		state_machine.after_move(incoming_velocity)
	physics_safety.finish_tick(delta)

func _apply_gravity(delta: float) -> void:
	velocity.y = minf(velocity.y + settings.gravity * delta, settings.terminal_speed)

## Shared surface collision service used by airborne state nodes.
func _resolve_air_contacts(incoming: Vector2) -> void:
	for index in get_slide_collision_count():
		var contact := get_slide_collision(index)
		var normal := contact.get_normal()
		if normal.dot(Vector2.UP) < cos(floor_max_angle) and _reattach_time <= 0.0 and incoming.dot(normal) < -1.0:
			surface_anchor.capture(contact.get_collider() as Node2D, normal)
			_surface_normal = normal
			_attached = true
			velocity = Vector2.ZERO
			visual.rotation = Vector2.UP.angle_to(normal)
			_change_state(State.ON_WALL)
			return
	if is_on_floor():
		visual.rotation = 0.0
		_change_state(State.IDLE)

func _begin_charge() -> void:
	state_machine.transition(State.CHARGING, true)
## Ceiling-facing normals invert angular input to retain screen-left/right aim.
func _aim_control_sign() -> float:
	return -1.0 if _surface_normal.y > 0.0 else 1.0

func get_launch_velocity() -> Vector2:
	var launch_speed := minf(settings.minimum_jump_speed + _charge_time * settings.jump_charge_rate, settings.maximum_jump_speed)
	return _surface_normal.rotated(_aim_angle) * launch_speed

func _launch() -> void:
	if physics_safety.is_trapped():
		return
	velocity = get_launch_velocity()
	_detach()
	_change_state(State.JUMPING)

func _detach() -> void:
	surface_anchor.clear()
	_attached = false
	_reattach_time = settings.reattach_delay
	visual.rotation = 0.0

func _begin_attack() -> void:
	_change_state(State.ATTACKING)

## Impulse is a velocity change in world pixels/second; damage cannot heal.
func receive_hit(damage: int, impulse: Vector2 = Vector2.ZERO, _source: Node = null) -> void:
	if health <= 0 or _invulnerability > 0.0:
		return
	health = maxi(0, health - maxi(0, damage))
	_invulnerability = settings.invulnerability_time
	var force := impulse.length()
	var threshold := settings.get_hit_threshold(state_machine.current.animation)
	if force > 0.0 and force >= threshold:
		_detach()
		velocity += impulse
		_change_state(State.GETTING_HIT)
		# A qualifying follow-up hit also restarts existing hit stun.
		_state_time = 0.0
	if health == 0:
		_die()
	else:
		health_changed.emit(health, settings.maximum_health)

func _play_squeeze_sound() -> void:
	var sound: AudioStream = settings.squeeze_sound if settings.squeeze_sound != null else splatter_sound
	_last_squeeze_audio = splatter_audio.play_independent(sound)

## One death path for damage and squeezing; SQUEEZED owns its optional sound.
func _die() -> void:
	if _death_emitted:
		return
	_death_emitted = true
	health = 0
	_detach()
	_change_state(State.GETTING_HIT)
	hitbox.end_swing()
	preview.visible = false
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	get_node("CollisionShape2D").set_deferred("disabled", true)
	get_node("Hurtbox").set_deferred("monitorable", false)
	health_changed.emit(health, settings.maximum_health)
	died.emit()
func _change_state(next: State) -> void:
	state_machine.transition(next)
