class_name SoundBankPlayer2D
extends Node2D

@export var bank: SoundBank
@export var sound_id: StringName
@export var bus: StringName = &"SFX"
@export var volume_db: float = 0.0
@export var max_distance: float = 2000.0
@export var attenuation: float = 1.0
@export_range(1, 32) var max_voices: int = 8
var _voices: Array[AudioStreamPlayer2D] = []

func play() -> AudioStreamPlayer2D:
	if bank == null:
		return null
	var clip := bank.random_clip()
	if clip == null:
		return null
	while _voices.size() >= maxi(1, max_voices):
		var oldest := _voices.pop_front() as AudioStreamPlayer2D
		oldest.stop()
		oldest.queue_free()
	var voice := AudioStreamPlayer2D.new()
	voice.stream = clip
	voice.bus = bus
	voice.volume_db = volume_db + AudioConfig.volume_db(sound_id)
	voice.max_distance = max_distance
	voice.attenuation = attenuation
	add_child(voice)
	_voices.append(voice)
	voice.finished.connect(func():
		_voices.erase(voice)
		voice.queue_free())
	voice.play()
	return voice

func stop() -> void:
	for voice in _voices:
		voice.stop()
		voice.queue_free()
	_voices.clear()
