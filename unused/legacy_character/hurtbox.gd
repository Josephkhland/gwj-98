extends Area2D
## Combat receivers live on layer 3. Override receive_hit for other actors.
func receive_hit(damage: int, impulse: Vector2 = Vector2.ZERO, source: Node = null) -> void:
	if get_parent().has_method("receive_hit"):
		get_parent().receive_hit(damage, impulse, source)
