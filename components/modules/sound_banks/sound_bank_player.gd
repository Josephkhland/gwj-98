class_name SoundBankPlayer
extends Node

@export var bank: SoundBank
@export var sound_id: StringName
@export var bus: StringName = &"SFX"

func play() -> AudioStreamPlayer:
	return AudioManager.play_bank(bank, sound_id, bus, self)
