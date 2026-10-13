extends AudioStreamPlayer2D
## Optional one-shot audio. No assigned stream means no playback or fallback.
## A separate player lets recovery play repeatedly and survive character deletion.
func play_independent(sound: AudioStream) -> AudioStreamPlayer2D:
	if sound == null:
		return null
	var player := AudioStreamPlayer2D.new()
	player.stream = sound
	player.bus = bus
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.max_distance = max_distance
	player.attenuation = attenuation
	player.panning_strength = panning_strength
	get_tree().root.add_child(player)
	player.global_position = global_position
	player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)
	player.play()
	return player
