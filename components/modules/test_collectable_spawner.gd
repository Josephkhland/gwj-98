extends Node2D

@export var test_collectable: PackedScene

@export var spawn_amount: int = 2
@export var markerA: Marker2D
@export var markerB: Marker2D


func _physics_process(_delta: float) -> void:
	if get_child_count() - 2 < spawn_amount:
		_spawn()


func _spawn() -> void:
	var tc = test_collectable.instantiate() as Node2D
	add_child(tc)

	var rect = Rect2(markerA.position, markerB.position - markerA.position).abs()
	tc.position = Vector2(
		randf_range(rect.position.x, rect.end.x), randf_range(rect.position.y, rect.end.y)
	)
