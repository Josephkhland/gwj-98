class_name SoundBank
extends Resource

@export var stream: AudioStream
@export_range(0.001, 60.0, 0.001) var segment_length: float = 2.0
@export_range(0, 1024) var segment_count: int = 0
@export_range(0.0, 60.0, 0.001) var offset: float = 0.0
@export_range(0.0, 60.0, 0.001) var correction_trim: float = 0.0

var _clips: Array[AudioStreamWAV] = []
var _signature: Array = []
var _decoded: AudioStreamWAV
var _decoded_source: AudioStream

func prepare() -> void:
	if stream == null or _decoded_source == stream:
		return
	_decoded_source = stream
	if stream is AudioStreamWAV:
		_decoded = stream
		return
	# Decode the supplied recording once; cached slices contain only its samples.
	var source := stream.duplicate() as AudioStream
	if source is AudioStreamMP3 or source is AudioStreamOggVorbis:
		source.loop = false
	var playback := source.instantiate_playback()
	playback.start()
	var rate := int(AudioServer.get_mix_rate())
	var frames := int(ceil(source.get_length() * rate))
	var data := PackedByteArray()
	data.resize(frames * 4)
	var written := 0
	while written < frames:
		var samples := playback.mix_audio(1.0, mini(4096, frames - written))
		if samples.is_empty():
			break
		for sample in samples:
			data.encode_s16(written * 4, int(clampf(sample.x, -1.0, 1.0) * 32767.0))
			data.encode_s16(written * 4 + 2, int(clampf(sample.y, -1.0, 1.0) * 32767.0))
			written += 1
	playback.stop()
	# Keep any decoder end-rounding gap silent so the last segment retains its duration.
	_decoded = AudioStreamWAV.new()
	_decoded.format = AudioStreamWAV.FORMAT_16_BITS
	_decoded.stereo = true
	_decoded.mix_rate = rate
	_decoded.data = data

func clear_cache() -> void:
	_clips.clear()
	_signature.clear()
	_decoded = null
	_decoded_source = null

func get_segment_count() -> int:
	if stream == null or not is_finite(segment_length) or segment_length <= 0.0:
		return 0
	if not is_finite(offset) or offset < 0.0 or not is_finite(correction_trim) or correction_trim < 0.0 or correction_trim >= segment_length:
		return 0
	var count := maxi(0, int(floor((stream.get_length() - offset + 0.000001) / segment_length)))
	return mini(count, segment_count) if segment_count > 0 else count

func get_clip(index: int) -> AudioStreamWAV:
	if index < 0 or index >= get_segment_count():
		return null
	prepare()
	var stream := _decoded
	if stream == null:
		return null
	if stream.format != AudioStreamWAV.FORMAT_8_BITS and stream.format != AudioStreamWAV.FORMAT_16_BITS:
		push_error("Sound banks require uncompressed 8-bit or 16-bit PCM WAV imports.")
		return null
	var signature := [stream, stream.format, stream.mix_rate, stream.stereo, segment_length, segment_count, offset, correction_trim]
	if signature != _signature:
		_clips.clear()
		_clips.resize(get_segment_count())
		_signature = signature
	if _clips[index] == null:
		var frame_bytes := (2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if stream.stereo else 1)
		var first_frame := int(round((offset + index * segment_length) * stream.mix_rate))
		var end_frame := int(round((offset + (index + 1) * segment_length - correction_trim) * stream.mix_rate))
		var clip := AudioStreamWAV.new()
		clip.format = stream.format
		clip.mix_rate = stream.mix_rate
		clip.stereo = stream.stereo
		clip.data = stream.data.slice(first_frame * frame_bytes, end_frame * frame_bytes)
		_clips[index] = clip
	return _clips[index]

func random_clip() -> AudioStreamWAV:
	var count := get_segment_count()
	return get_clip(randi_range(0, count - 1)) if count > 0 else null
