extends Node2D
## Ballistic projectile with a swept circular hit shape; lives until impact.
signal impacted(collider: Object, point: Vector2, normal: Vector2)
var velocity := Vector2.ZERO
var damage: int = 0
var hit_impulse := Vector2.ZERO
var radius: float = 4.0
var charges_spent: int = 1
var _source: WeakRef
var _exclude: Array[RID] = []
var _collision_mask: int = 5
var _gravity: float = 700.0
var _first_sweep: bool = true
var _spawn_origin := Vector2.ZERO
var _cast: ShapeCast2D

func configure(actor: CharacterBody2D, settings: Resource, direction: Vector2, charge_ratio: float, power_ratio: float = -1.0) -> void:
	if power_ratio < 0.0:
		power_ratio = actor.get_spit_power_ratio(charge_ratio) if actor.has_method("get_spit_power_ratio") else clampf(charge_ratio, 0.0, 1.0)
	_source = weakref(actor)
	_spawn_origin = actor.global_position
	_exclude = [actor.get_rid(), actor.get_node("Hurtbox").get_rid()]
	_collision_mask = settings.spit_collision_mask
	_gravity = settings.spit_gravity
	radius = settings.spit_visual_radius * lerpf(1.0, settings.spit_charged_size_multiplier, power_ratio)
	var angle: float = deg_to_rad(settings.spit_launch_angle_degrees)
	var launch_direction := Vector2(direction.x * cos(angle), -sin(angle))
	velocity = launch_direction * settings.spit_speed * lerpf(1.0, settings.spit_charged_speed_multiplier, power_ratio)
	damage = roundi(settings.spit_damage * lerpf(1.0, settings.spit_charged_damage_multiplier, power_ratio))
	hit_impulse = direction * settings.spit_hit_knockback

func _ready() -> void:
	_cast = ShapeCast2D.new()
	_cast.enabled = false
	_cast.collide_with_areas = true
	_cast.collision_mask = _collision_mask
	var shape := CircleShape2D.new()
	shape.radius = radius
	_cast.shape = shape
	for excluded in _exclude:
		_cast.add_exception_rid(excluded)
	add_child(_cast)

func _physics_process(delta: float) -> void:
	velocity.y += _gravity * delta
	var next := global_position + velocity * delta
	var origin := _spawn_origin if _first_sweep else global_position
	_first_sweep = false
	_cast.global_position = origin
	_cast.target_position = next - origin
	_cast.force_shapecast_update()
	if _cast.is_colliding():
		var receiver: Object = _cast.get_collider(0)
		var point := _cast.get_collision_point(0)
		var normal := _cast.get_collision_normal(0)
		global_position = origin.lerp(next, _cast.get_closest_collision_safe_fraction())
		_notify_routers(origin, global_position)
		# Stop before notifying consumers so only one impact can be delivered.
		set_physics_process(false)
		var actor: Node = _source.get_ref() as Node if _source != null else null
		if is_instance_valid(receiver) and receiver.has_method("receive_hit"):
			receiver.receive_hit(damage, hit_impulse, actor)
		impacted.emit(receiver, point, normal)
		queue_free()
		return
	global_position = next
	_notify_routers(origin, global_position)

func _notify_routers(from: Vector2, to: Vector2) -> void:
	var actor: Node = _source.get_ref() as Node if _source != null else null
	if is_instance_valid(actor):
		get_tree().call_group(&"attacked_network_routers", &"check_spit_pass", from, to, radius, actor)

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color("#b2eb91"))
	draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.3, Color.WHITE)
