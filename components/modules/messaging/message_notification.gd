class_name MessageNotification
extends DayCycleNotification
## A scheduled house-to-house message. The notification time is when the sender transmits;
## GameLevel adds a warning entry warning_minutes earlier. Times below are in game minutes.
const KEYWORD := &"message"
enum Route { HOUSE_TO_HOUSE, TO_INTERNET, FROM_INTERNET }
@export_group("Message")
@export var message_id: StringName = &""
## Short subject shown on compact ribbons and while the conversation opens.
@export var title: String = ""
## key_identifier of the sending house in the level's NetworkGraph.
@export var from_house: StringName = &""
## key_identifier of the receiving house.
@export var to_house: StringName = &""
## Broadcasts and outside participants need any reachable internet gateway.
@export var route: Route = Route.HOUSE_TO_HOUSE
@export_multiline var text: String = ""
@export_group("Conversation")
## Presentation identities; network routing still uses from_house and to_house.
@export var sender: CharacterProfile
@export var recipient: CharacterProfile
## Explicit speakers allow consecutive replies from the same participant.
@export var replies: Array[MessageReply] = []
@export_group("Delivery")
@export var points: int = 100
## Award the full configured points even when delivery is late. Expired mail still gives zero.
@export var fixed_score: bool = false
@export_range(0.0, 720.0, 1.0, "or_greater") var warning_minutes: float = 30.0
## How long after transmission a late delivery still counts (capped by the end of shift).
@export_range(1.0, 1440.0, 1.0, "or_greater") var expire_minutes: float = 120.0
@export_group("Dialogue Unlock on Delivery")
@export var unlock_character: CharacterProfile
@export var unlock_chain: TownfolkDialogueChain
@export var unlock_mode: ProgressManager.DialogueMode = ProgressManager.DialogueMode.WORK_SHIFT

func _init() -> void:
	keyword = KEYWORD

func get_payload() -> Dictionary:
	return {"message": self}

func get_display_title() -> String:
	return title.strip_edges() if not title.strip_edges().is_empty() else text.get_slice("\n", 0)
