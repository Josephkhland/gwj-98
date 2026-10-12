class_name MessageNotification
extends DayCycleNotification
## A scheduled house-to-house message. The notification time is when the sender transmits;
## GameLevel adds a warning entry warning_minutes earlier. Times below are in game minutes.
const KEYWORD := &"message"
@export_group("Message")
@export var message_id: StringName = &""
## key_identifier of the sending house in the level's NetworkGraph.
@export var from_house: StringName = &""
## key_identifier of the receiving house.
@export var to_house: StringName = &""
@export_multiline var text: String = ""
@export var points: int = 100
@export_range(0.0, 720.0, 1.0, "or_greater") var warning_minutes: float = 30.0
## How long after transmission a late delivery still counts (capped by the end of shift).
@export_range(1.0, 1440.0, 1.0, "or_greater") var expire_minutes: float = 120.0

func _init() -> void:
	keyword = KEYWORD

func get_payload() -> Dictionary:
	return {"message": self}
