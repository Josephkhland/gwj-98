@tool
class_name SignalNetworkHouse
extends SignalNetworkVertex

@export var character_profile: CharacterProfile
## Presentation marker; routing behavior is still owned by the network/message systems.
@export var internet_gateway: bool = false

func is_internet_gateway() -> bool:
	return internet_gateway or get_label().strip_edges().to_lower() == "internet" or String(key_identifier).to_lower() == "internet"

func is_house() -> bool:
	return true

func _draw() -> void:
	if get_child_count() == 0:
		draw_rect(Rect2(-16, -16, 32, 32), Color.SKY_BLUE)
