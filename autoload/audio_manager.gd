extends Node

signal volume_changed(bus: StringName, volume: float)
const BUSES := [&"SFX", &"Music", &"Ambience"]
const SETTINGS_PATH := "user://audio_settings.cfg"
var _volumes: Dictionary = {}
var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
const MAX_VOICES := 32

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
		set_volume(bus, float(settings.get_value("volume", bus, 1.0)), false)
	if OS.is_debug_build():
		add_child(preload("res://components/ui/audio_debug/AudioDebugPanel.tscn").instantiate())

func get_volume(bus: StringName) -> float:
	return float(_volumes.get(bus, 1.0))

func set_volume(bus: StringName, value: float, persist: bool = true) -> void:
	if bus not in BUSES or not is_finite(value):
		return
	value = clampf(value, 0.0, 1.0)
	_volumes[bus] = value
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(index, value == 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))
	volume_changed.emit(bus, value)
	if persist:
		var settings := ConfigFile.new()
		for key in BUSES:
			settings.set_value("volume", key, get_volume(key))
		settings.save(SETTINGS_PATH)

func get_stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) as AudioStream
	return _streams[path]

func play_bank(bank: SoundBank, sound_id: StringName = &"", bus: StringName = &"SFX", parent: Node = null) -> AudioStreamPlayer:
	return play_sound(bank.random_clip() if bank != null else null, sound_id, bus, parent)

func play_sound(stream: AudioStream, sound_id: StringName = &"", bus: StringName = &"SFX", parent: Node = null) -> AudioStreamPlayer:
	if stream == null:
		return null
	while _voices.size() >= MAX_VOICES:
		var oldest := _voices.pop_front() as AudioStreamPlayer
		oldest.stop()
		oldest.queue_free()
	var voice := AudioStreamPlayer.new()
	voice.stream = stream
	voice.bus = bus
	voice.volume_db = AudioConfig.volume_db(sound_id)
	(self if parent == null else parent).add_child(voice)
	_voices.append(voice)
	voice.tree_exiting.connect(func(): _voices.erase(voice))
	voice.finished.connect(voice.queue_free, CONNECT_ONE_SHOT)
	voice.play()
	return voice

func play_bank_at(bank: SoundBank, position: Vector2, world_parent: Node2D, sound_id: StringName = &"") -> AudioStreamPlayer2D:
	if bank == null or world_parent == null:
		return null
	var emitter := SoundBankPlayer2D.new()
	emitter.bank = bank
	emitter.sound_id = sound_id
	world_parent.add_child(emitter)
	emitter.global_position = position
	var voice := emitter.play()
	if voice == null:
		emitter.queue_free()
	else:
		voice.finished.connect(emitter.queue_free, CONNECT_ONE_SHOT)
	return voice
