extends Node
## Keeps frozen states at a local point on a translating/rotating collider.
var character: CharacterBody2D
var _surface: WeakRef
var _local_position := Vector2.ZERO
var _local_normal := Vector2.UP

func initialize(actor: CharacterBody2D) -> void:
	character = actor

func capture(surface: Node2D, normal: Vector2) -> void:
	clear()
	if not is_instance_valid(surface):
		return
	_surface = weakref(surface)
	_local_position = surface.to_local(character.global_position)
	_local_normal = surface.global_transform.basis_xform_inv(normal).normalized()

func capture_floor() -> void:
	for index in character.get_slide_collision_count():
		var contact := character.get_slide_collision(index)
		if contact.get_normal().dot(Vector2.UP) >= cos(character.floor_max_angle):
			var surface := contact.get_collider() as Node2D
			if surface != null:
				capture(surface, contact.get_normal())
				return

func is_immobile(surface: Node2D) -> bool:
	if surface is AnimatableBody2D:
		return false
	if surface is StaticBody2D:
		return surface.constant_linear_velocity.is_zero_approx() and is_zero_approx(surface.constant_angular_velocity)
	return surface is TileMapLayer and not surface.use_kinematic_bodies

func prefer_immobile(surface: Node2D, normal: Vector2) -> void:
	var current := _surface.get_ref() as Node2D if _surface != null else null
	if is_instance_valid(current) and is_immobile(current):
		return
	if is_instance_valid(surface) and is_immobile(surface):
		capture(surface, normal)
		character._attached = true
		character._surface_normal = normal
		character.visual.rotation = Vector2.UP.angle_to(normal)

func rebase_position() -> void:
	# External pushes move along the current support without changing aim axes.
	var surface := _surface.get_ref() as Node2D if _surface != null else null
	if is_instance_valid(surface):
		_local_position = surface.to_local(character.global_position)

func clear() -> void:
	_surface = null

func follow() -> void:
	if _surface == null:
		return
	var surface := _surface.get_ref() as Node2D
	if not is_instance_valid(surface) or not surface.is_inside_tree():
		_release()
		return
	# A wrapping/disappearing platform can remain in-tree but leave physics.
	if surface is PhysicsBody2D and not PhysicsServer2D.body_get_space(surface.get_rid()).is_valid():
		_release()
		return
	var normal := surface.global_transform.basis_xform(_local_normal).normalized()
	var target := surface.to_global(_local_position)
	var motion := target - character.global_position
	# Ignore only our carrier during the sweep; other solids still block us.
	var carrier := surface as PhysicsBody2D
	var added_exception := false
	if carrier != null and not character.get_collision_exceptions().has(carrier):
		character.add_collision_exception_with(carrier)
		added_exception = true
	var collision: KinematicCollision2D
	if not motion.is_zero_approx():
		collision = character.move_and_collide(motion)
	if added_exception:
		character.remove_collision_exception_with(carrier)
	if collision != null:
		if character.physics_safety.note_blocked(collision.get_normal(), normal):
			prefer_immobile(collision.get_collider() as Node2D, collision.get_normal())
		else:
			if character.state == character.State.CHARGING:
				# Keep charge and aim; slide the anchor to the reachable position.
				# Opposing pressure retains its original anchor for crush detection.
				capture(surface, normal)
			else:
				_release()
		return
	character._surface_normal = normal
	character.visual.rotation = Vector2.UP.angle_to(normal)

func _release() -> void:
	character._detach()
	if character.state != character.State.SQUEEZED:
		character._change_state(character.State.IN_AIR)
