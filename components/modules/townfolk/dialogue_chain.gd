class_name TownfolkDialogueChain
extends Resource
## Ordered dialogue lines for shift bubbles or off-shift conversations.
@export var chain_id: StringName
@export var lines: Array[TownfolkDialogueLine] = []
@export var voice_bank: VoiceSoundBank
@export var reactions_enabled: bool = true
