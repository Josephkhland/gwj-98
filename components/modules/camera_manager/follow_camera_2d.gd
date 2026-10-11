@tool
class_name FollowCamera2D
extends ManagedCamera2D
## Tracks a scene node in world coordinates, including while inactive.

@export var follow_target: Node2D
@export var follow_offset: Vector2 = Vector2.ZERO
## Rotate the offset with the target (target scale does not affect it).
@export var offset_in_target_space: bool = false


func _ready() -> void:
	if not Engine.is_editor_hint():
		_follow()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() and process_callback == Camera2D.CAMERA2D_PROCESS_IDLE:
		_follow()


func _physics_process(_delta: float) -> void:
	if not Engine.is_editor_hint() and process_callback == Camera2D.CAMERA2D_PROCESS_PHYSICS:
		_follow()


func _follow() -> void:
	if is_instance_valid(follow_target) and follow_target != self and not is_ancestor_of(follow_target):
		var world_offset := follow_offset
		if offset_in_target_space:
			world_offset = world_offset.rotated(follow_target.global_rotation)
		global_position = follow_target.global_position + world_offset


func _get_configuration_warnings() -> PackedStringArray:
	if not is_instance_valid(follow_target):
		return PackedStringArray(["Assign a Follow Target to enable following."])
	if follow_target == self or is_ancestor_of(follow_target):
		return PackedStringArray(["Follow Target must not be this camera or its descendant."])
	return PackedStringArray()
