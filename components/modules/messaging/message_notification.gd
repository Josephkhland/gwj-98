class_name MessageNotification
extends DayCycleNotification
## A scheduled house-to-house message. The notification time is when the sender transmits;
## GameLevel adds a warning entry warning_minutes earlier. Times below are in game minutes.
const KEYWORD := &"message"
@export_group("Message")
@export var message_id: StringName = &""
## Short subject shown on compact ribbons and while the conversation opens.
@export var title: String = ""
## key_identifier of the sending house in the level's NetworkGraph.
@export var from_house: StringName = &""
## key_identifier of the receiving house.
@export var to_house: StringName = &""
@export_multiline var text: String = ""
@export_group("Conversation")
## Presentation identities; network routing still uses from_house and to_house.
@export var sender: CharacterProfile
@export var recipient: CharacterProfile
## Explicit speakers allow consecutive replies from the same participant.
@export var replies: Array[MessageReply] = []
@export_group("Delivery")
@export var points: int = 100
@export_range(0.0, 720.0, 1.0, "or_greater") var warning_minutes: float = 30.0
## How long after transmission a late delivery still counts (capped by the end of shift).
@export_range(1.0, 1440.0, 1.0, "or_greater") var expire_minutes: float = 120.0

func _init() -> void:
	keyword = KEYWORD

func get_payload() -> Dictionary:
	return {"message": self}

func get_display_title() -> String:
	return title.strip_edges() if not title.strip_edges().is_empty() else text.get_slice("\n", 0)
