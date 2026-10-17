class_name VoiceSoundBank
extends SoundBank
## A segmented recording of short voice blips, using the existing SoundBank slicing.
@export_range(0.25, 3.0, 0.01) var pitch_min: float = 0.95
@export_range(0.25, 3.0, 0.01) var pitch_max: float = 1.05
## Each vowel bank contains the one-second variations from its recording.
@export var vowel_banks: Dictionary[StringName, SoundBank] = {}
@export_range(0.03, 1.0, 0.01) var blip_seconds: float = 0.18
var _blips: Dictionary = {}

func prepare() -> void:
	super.prepare()
	for bank in vowel_banks.values():
		if bank != null:
			bank.prepare()

func clear_cache() -> void:
	super.clear_cache()
	_blips.clear()
	for bank in vowel_banks.values():
		if bank != null:
			bank.clear_cache()

func vowel_for_syllable(syllable: String) -> StringName:
	for letter in syllable.to_lower():
		if letter in "aeiou":
			return StringName(letter)
	return &"i" if syllable.to_lower().contains("y") else &""

func clip_for_syllable(syllable: String) -> AudioStreamWAV:
	if vowel_banks.is_empty():
		return random_clip()
	var vowel := vowel_for_syllable(syllable)
	if not vowel_banks.has(vowel):
		vowel = vowel_banks.keys().pick_random()
	var bank := vowel_banks[vowel] as SoundBank
	var clip := bank.random_clip() if bank != null else random_clip()
	return _trim_blip(clip)

func _trim_blip(clip: AudioStreamWAV) -> AudioStreamWAV:
	if clip == null or clip.format != AudioStreamWAV.FORMAT_16_BITS:
		return clip
	var key := "%s:%s" % [clip.get_instance_id(), blip_seconds]
	if _blips.has(key):
		return _blips[key]
	var channels := 2 if clip.stereo else 1
	var frame_bytes := channels * 2
	var frames := clip.data.size() / frame_bytes
	var first := 0
	# Remove padding before each variation, then fade short cut edges to avoid clicks.
	while first < frames:
		var audible := false
		for channel in channels:
			if absi(clip.data.decode_s16(first * frame_bytes + channel * 2)) > 180:
				audible = true
				break
		if audible:
			break
		first += 1
	var count := mini(frames - first, maxi(1, roundi(blip_seconds * clip.mix_rate)))
	if count <= 0:
		return null
	var data := clip.data.slice(first * frame_bytes, (first + count) * frame_bytes)
	var fade := maxi(1, roundi(clip.mix_rate * 0.004))
	for frame in count:
		var gain := minf(1, minf(float(frame) / fade, float(count - frame - 1) / fade))
		if gain >= 1:
			continue
		for channel in channels:
			var at := frame * frame_bytes + channel * 2
			data.encode_s16(at, roundi(data.decode_s16(at) * gain))
	var blip := AudioStreamWAV.new()
	blip.resource_name = clip.resource_name + " voice blip"
	blip.format = clip.format
	blip.stereo = clip.stereo
	blip.mix_rate = clip.mix_rate
	blip.data = data
	_blips[key] = blip
	return blip

func random_pitch() -> float:
	return randf_range(minf(pitch_min, pitch_max), maxf(pitch_min, pitch_max))
