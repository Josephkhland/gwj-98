class_name MessageReply
extends Resource
## An instant scripted response after the original message is delivered.
enum Speaker { SENDER, RECIPIENT }
@export var speaker: Speaker = Speaker.RECIPIENT
@export_multiline var text: String = ""
@export_multiline var action_before: String = ""
@export_multiline var action_after: String = ""
