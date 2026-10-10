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

func clear() -> void:
	_surface = null

func follow() -> void:
	if _surface == null:
		return
	var surface := _surface.get_ref() as Node2D
	if not is_instance_valid(surface) or not surface.is_inside_tree():
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
		_release()
		return
	character._surface_normal = normal
	character.visual.rotation = Vector2.UP.angle_to(normal)

func _release() -> void:
	character._detach()
	character._change_state(character.State.IN_AIR)
