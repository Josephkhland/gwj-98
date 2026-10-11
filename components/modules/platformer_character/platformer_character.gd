extends CharacterBody2D
## Shared services; StateMachine child nodes own state-specific behavior.
signal state_changed(previous: State, current: State)
signal health_changed(current: int, maximum: int)
signal died
signal squeezed
signal spit_fired(projectile: Node2D, charge_ratio: float)
signal spit_charges_changed(current: int, maximum: int)
signal slam_impacted(collider: Node, point: Vector2, normal: Vector2)
enum State { IDLE, WALKING, CHARGING, JUMPING, IN_AIR, ON_WALL, ATTACKING, GETTING_HIT, SQUEEZED, SLAMMING, ROLLING_BACK, CHARGING_SPIT }
const Settings = preload("res://components/modules/platformer_character/character_settings.gd")
const SpitProjectile = preload("res://components/modules/platformer_character/spit_projectile.gd")
const ANIMATIONS: Array[StringName] = [
	&"idle", &"walking", &"charging", &"jumping", &"in_air",
	&"on_wall", &"attacking", &"getting_hit", &"squeezed", &"slamming",
	&"rolling_back", &"charging_spit"
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
@export var heighten_action: StringName = &""
@export var spit_action: StringName = &""
@export var slam_action: StringName = &""
@onready var visual: Node2D = $Visual
@onready var hitbox: Area2D = $AttackPivot/Hitbox
@onready var attack_pivot: Node2D = $AttackPivot
@onready var slam_hitbox: Area2D = $SlamHitbox
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
var _heighten_held: bool = false
var _spit_held: bool = false
var _slam_held: bool = false
var _was_spit: bool = false
var _was_slam: bool = false
var spit_charges: int = 0
var _spit_charging: bool = false
var _spit_charge_time: float = 0.0
var _spit_charge_grounded: bool = false
var _spit_aim_angle: float = 0.0
var _spit_recharge_progress: float = 0.0
var _spit_recharge_ready: bool = false
var _landing_sliding: bool = false
var _floor_slide_collider: WeakRef

func _ready() -> void:
	health = settings.maximum_health
	spit_charges = settings.spit_maximum_charges
	slam_hitbox.get_node("CollisionShape2D").shape = CircleShape2D.new()
	slam_hitbox.get_node("CollisionShape2D").shape.radius = settings.slam_hitbox_radius
	slam_hitbox.collision_mask = settings.slam_hitbox_mask
	physics_safety.initialize(self)
	surface_anchor.initialize(self)
	state_machine.initialize(self, State.IN_AIR)
	health_changed.emit(health, settings.maximum_health)
	spit_charges_changed.emit(spit_charges, settings.spit_maximum_charges)
	if player_controlled:
		add_to_group("players")

## Call each physics tick with player_controlled=false to drive AI or custom input.
func set_controls(move_axis: float, charge_held: bool, attack_held: bool,
		heighten_held: bool = false, spit_held: bool = false, slam_held: bool = false) -> void:
	_move_axis = clampf(move_axis, -1.0, 1.0)
	_charge_held = charge_held
	_attack_held = attack_held
	_heighten_held = heighten_held
	_spit_held = spit_held
	_slam_held = slam_held

func _pressed(action: StringName) -> bool:
	return action != &"" and InputMap.has_action(action) and Input.is_action_pressed(action)
func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	if player_controlled:
		set_controls(
			float(_pressed(move_right_action)) - float(_pressed(move_left_action)),
			_pressed(charge_action), _pressed(attack_action),
			_pressed(heighten_action), _pressed(spit_action), _pressed(slam_action))
	_reattach_time = maxf(0.0, _reattach_time - delta)
	_invulnerability = maxf(0.0, _invulnerability - delta)
	var charge_started := _charge_held and not _was_charge
	var attack_started := _attack_held and not _was_attack
	var spit_started := _spit_held and not _was_spit
	var slam_started := _slam_held and not _was_slam
	_was_charge = _charge_held
	_was_attack = _attack_held
	_was_spit = _spit_held
	_was_slam = _slam_held
	physics_safety.begin_tick()
	if not state_machine.should_move() and not physics_safety.movement_locked():
		surface_anchor.follow()
		if not state_machine.should_move():
			physics_safety.recover_held(delta)
	state_machine.physics_update(delta, charge_started, attack_started, spit_started, slam_started)
	if health <= 0:
		return
	visual.facing = facing
	if state_machine.should_move() and not physics_safety.movement_locked():
		var incoming_velocity := velocity
		var previously_grounded := is_on_floor()
		move_and_slide()
		_update_landing_slide(previously_grounded)
		state_machine.after_move(incoming_velocity)
	if is_grounded():
		_spit_recharge_ready = true
	_update_spit_recharge(delta)
	physics_safety.finish_tick(delta)

func _apply_gravity(delta: float) -> void:
	velocity.y = minf(velocity.y + settings.gravity * delta, settings.terminal_speed)

## Shared surface collision service used by airborne state nodes.
func _resolve_air_contacts(incoming: Vector2, settle_floor: bool = true) -> void:
	if is_on_floor():
		if settle_floor:
			visual.rotation = 0.0
			_change_state(State.IDLE)
		return
	var bounced := incoming
	var did_bounce := false
	for index in get_slide_collision_count():
		var contact := get_slide_collision(index)
		var normal := contact.get_normal()
		var surface_velocity := contact.get_collider_velocity()
		if normal.dot(Vector2.UP) >= cos(floor_max_angle) or (bounced - surface_velocity).dot(normal) >= -1.0:
			continue
		if _reattach_time <= 0.0 and surface_has_sticky_layer(contact.get_collider() as Node2D, contact.get_collider_rid()):
			surface_anchor.capture(contact.get_collider() as Node2D, normal)
			_surface_normal = normal
			_attached = true
			velocity = Vector2.ZERO
			visual.rotation = Vector2.UP.angle_to(normal)
			_change_state(State.ON_WALL)
			return
		bounced = bounce_velocity(bounced, normal, surface_velocity)
		did_bounce = true
	if did_bounce:
		velocity = bounced

func surface_has_sticky_layer(surface: Node2D, body_rid: RID = RID()) -> bool:
	var layers: int = 0
	if body_rid.is_valid():
		layers = PhysicsServer2D.body_get_collision_layer(body_rid)
	elif surface is CollisionObject2D:
		layers = surface.collision_layer
	return (layers & settings.sticky_surface_mask) != 0

func bounce_velocity(incoming: Vector2, normal: Vector2, surface_velocity: Vector2 = Vector2.ZERO) -> Vector2:
	var relative := incoming - surface_velocity
	var normal_speed := relative.dot(normal)
	if normal_speed >= 0.0:
		return incoming
	var retention := settings.surface_bounce_retention if settings.surface_bounce_enabled else 0.0
	return incoming - (1.0 + retention) * normal_speed * normal

func _update_landing_slide(previously_grounded: bool) -> void:
	_floor_slide_collider = null
	if not is_on_floor():
		_landing_sliding = false
		return
	for index in get_slide_collision_count():
		var contact := get_slide_collision(index)
		if contact.get_normal().dot(Vector2.UP) >= cos(floor_max_angle):
			_floor_slide_collider = weakref(contact.get_collider())
			break
	if not previously_grounded:
		_landing_sliding = not is_zero_approx(velocity.x)

## Optional environment hook: get_landing_slide_friction(character), or metadata.
func get_landing_slide_friction() -> float:
	var surface = _floor_slide_collider.get_ref() if _floor_slide_collider != null else null
	if is_instance_valid(surface):
		var value = surface.call("get_landing_slide_friction", self) if surface.has_method("get_landing_slide_friction") else surface.get_meta("landing_slide_friction", settings.landing_slide_friction)
		if (value is float or value is int) and is_finite(float(value)) and float(value) >= 0.0:
			return float(value)
	return settings.landing_slide_friction

func _apply_ground_horizontal(delta: float, speed_multiplier: float = 1.0) -> void:
	var target := _move_axis * settings.walk_speed * speed_multiplier
	if _landing_sliding:
		velocity.x = move_toward(velocity.x, target, get_landing_slide_friction() * delta)
		_landing_sliding = not is_equal_approx(velocity.x, target)
	else:
		velocity.x = target

func _begin_charge() -> void:
	_landing_sliding = false
	state_machine.transition(State.CHARGING, true)
## Ceiling-facing normals invert the tilt to retain screen-left/right launches.
func _aim_control_sign() -> float:
	return -1.0 if _surface_normal.y > 0.0 else 1.0

func _update_facing() -> void:
	if not is_zero_approx(_move_axis):
		facing = signf(_move_axis)

func is_grounded() -> bool:
	# Floor flags survive a launch until the next movement; exclude flying states.
	if state == State.CHARGING_SPIT:
		return state_machine.current.grounded and is_on_floor() and not _attached
	return is_on_floor() and not _attached and state not in [State.JUMPING, State.IN_AIR, State.ON_WALL, State.SQUEEZED] and not (state == State.SLAMMING and not state_machine.current.impacted)

func _can_spit() -> bool:
	return settings.spit_enabled and state_machine.current.allows_spit and (settings.ground_spit_enabled or not is_grounded())

func _begin_spit() -> void:
	if not _can_spit() or spit_charges <= 0:
		return
	if settings.spit_charge_enabled:
		_spit_charge_grounded = is_grounded()
		_change_state(State.CHARGING_SPIT)
	else:
		_fire_spit(0.0)

func _cancel_spit_charge() -> void:
	_spit_charging = false
	_spit_charge_time = 0.0

func _update_spit_charge(delta: float) -> void:
	if not _spit_charging:
		return
	if not _can_spit():
		_cancel_spit_charge()
		_end_spit_charge_state()
		return
	var duration := maxf(settings.spit_max_charge_time, 0.001)
	var affordable_ratio := minf(1.0, float(spit_charges) / float(_maximum_spit_cost()))
	_spit_charge_time = minf(_spit_charge_time + delta, duration * affordable_ratio)
	if not _spit_held or _spit_charge_time >= duration * affordable_ratio:
		var ratio := get_spit_charge_ratio()
		_fire_spit(ratio)
		_cancel_spit_charge()
		_end_spit_charge_state()

func _end_spit_charge_state() -> void:
	if state == State.CHARGING_SPIT and health > 0:
		_change_state(State.IDLE if is_grounded() else State.IN_AIR)

func _maximum_spit_cost() -> int:
	return maxi(1, mini(settings.spit_max_charges_per_shot, settings.spit_maximum_charges))

func get_spit_charge_ratio() -> float:
	return clampf(_spit_charge_time / maxf(settings.spit_max_charge_time, 0.001), 0.0, 1.0)

## Cost rises at evenly spaced charge tiers; ammo is spent only when firing.
func get_spit_charge_cost(charge_ratio: float = -1.0) -> int:
	var ratio := get_spit_charge_ratio() if charge_ratio < 0.0 else clampf(charge_ratio, 0.0, 1.0)
	var maximum := _maximum_spit_cost()
	return mini(spit_charges, mini(maximum, 1 + floori(ratio * maximum)))

func _fire_spit(charge_ratio: float) -> void:
	if not _can_spit() or spit_charges <= 0:
		return
	charge_ratio = clampf(charge_ratio, 0.0, minf(1.0, float(spit_charges) / float(_maximum_spit_cost())))
	var cost := get_spit_charge_cost(charge_ratio)
	var grounded := is_grounded()
	var direction := Vector2(facing, 0.0)
	var projectile := SpitProjectile.new()
	projectile.configure(self, settings, direction, charge_ratio)
	projectile.velocity = get_spit_launch_velocity(charge_ratio)
	projectile.charges_spent = cost
	projectile.top_level = true
	projectile.position = global_position + Vector2(settings.spit_spawn_offset.x * facing, settings.spit_spawn_offset.y)
	get_parent().add_child(projectile)
	spit_charges -= cost
	_spit_recharge_progress = 0.0
	_spit_recharge_ready = grounded
	if not grounded:
		var recoil := settings.spit_recoil * lerpf(1.0, settings.spit_charged_recoil_multiplier, charge_ratio)
		if settings.spit_recoil_sets_backward_speed:
			velocity.x = -facing * recoil
		else:
			velocity.x -= facing * recoil
	spit_charges_changed.emit(spit_charges, settings.spit_maximum_charges)
	spit_fired.emit(projectile, charge_ratio)

func _update_spit_recharge(delta: float) -> void:
	if not settings.spit_enabled or spit_charges >= settings.spit_maximum_charges:
		return
	if not _spit_recharge_ready or not settings.allows_spit_recharge(state_machine.current.animation):
		return
	_spit_recharge_progress += delta
	var interval := maxf(settings.spit_recharge_time, 0.001)
	while _spit_recharge_progress >= interval and spit_charges < settings.spit_maximum_charges:
		_spit_recharge_progress -= interval
		spit_charges += 1
		spit_charges_changed.emit(spit_charges, settings.spit_maximum_charges)
	if spit_charges >= settings.spit_maximum_charges:
		_spit_recharge_progress = 0.0

func get_launch_velocity() -> Vector2:
	var launch_speed := minf(settings.minimum_jump_speed + _charge_time * settings.jump_charge_rate, settings.maximum_jump_speed)
	return _surface_normal.rotated(_aim_angle) * launch_speed

func get_spit_launch_velocity(charge_ratio: float = -1.0) -> Vector2:
	var ratio := get_spit_charge_ratio() if charge_ratio < 0.0 else charge_ratio
	var angle := _spit_aim_angle if _spit_charging else deg_to_rad(settings.spit_launch_angle_degrees)
	return Vector2(facing * cos(angle), -sin(angle)) * settings.spit_speed * lerpf(1.0, settings.spit_charged_speed_multiplier, clampf(ratio, 0.0, 1.0))

func _launch() -> void:
	if physics_safety.is_trapped():
		return
	velocity = get_launch_velocity()
	_detach()
	_change_state(State.JUMPING)

func _detach() -> void:
	_landing_sliding = false
	_floor_slide_collider = null
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
		_cancel_spit_charge()
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
	slam_hitbox.end_swing()
	_cancel_spit_charge()
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
