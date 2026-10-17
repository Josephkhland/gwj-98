extends GameLevel
## Test day for the orchestrator loop: four houses linked by six routers with redundant routes,
## static and moving platforms, and sticky (green) surfaces to climb.

func _ready() -> void:
	super._ready()
	# A short placeholder voice makes both dialogue presentations audible in this level.
	var recording := AudioStreamWAV.new()
	recording.format = AudioStreamWAV.FORMAT_16_BITS
	recording.mix_rate = 22050
	var sample_count := 1323
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	for index in sample_count:
		var envelope := sin(PI * float(index) / sample_count)
		samples.encode_s16(index * 2, int(sin(TAU * 420 * float(index) / recording.mix_rate) * envelope * 6000))
	var bank := VoiceSoundBank.new()
	recording.data = samples
	bank.stream = recording
	bank.segment_length = 0.06
	$Townfolk.default_voice_bank = bank
