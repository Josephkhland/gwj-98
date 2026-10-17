@tool
class_name CharacterProfile
extends Resource
const ANONYMOUS_PORTRAIT: Texture2D = preload("res://assets/josephkhland/anonymous_portrait_prototype.png")
## Shared identity and artwork for messages and townfolk conversations.
@export var character_id: StringName
@export var display_name: String = ""
@export var portrait: Texture2D

## Full-body artwork displayed behind the off-shift conversation frames.
@export var full_body_portrait: Texture2D
@export_group("Voice")
@export var voice_bank: VoiceSoundBank
@export_group("World Appearance")
## One-frame animations support static artwork; add more frames to animate later.
@export var in_game_avatar: SpriteFrames:
	set(value):
		if in_game_avatar != null and in_game_avatar.changed.is_connected(emit_changed):
			in_game_avatar.changed.disconnect(emit_changed)
		in_game_avatar = value
		if in_game_avatar != null:
			in_game_avatar.changed.connect(emit_changed)
		emit_changed()
@export var in_game_idle_animation: StringName = &"idle":
	set(value):
		in_game_idle_animation = value
		emit_changed()

static func get_message_portrait(profile: CharacterProfile) -> Texture2D:
	return profile.portrait if profile != null and profile.portrait != null else ANONYMOUS_PORTRAIT
