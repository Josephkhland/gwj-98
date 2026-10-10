@tool
class_name SignalNetworkHouse
extends SignalNetworkVertex

func is_house() -> bool:
	return true

func _draw() -> void:
	if get_child_count() == 0:
		draw_rect(Rect2(-16, -16, 32, 32), Color.SKY_BLUE)
