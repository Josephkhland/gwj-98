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
	$Townfolk.dialogue_started.connect(_on_townfolk_dialogue_started)
	$Townfolk.dialogue_finished.connect(_on_townfolk_dialogue_ended)
	$Townfolk.dialogue_cancelled.connect(_on_townfolk_dialogue_ended)

func _on_townfolk_interacted(_listener: Node2D) -> void:
	var chain_id := &"sandbox_shift" if phase == Phase.ON_SHIFT else &"sandbox_off_shift"
	# Replay is useful here so both modes can be tried repeatedly in the sandbox.
	$Townfolk.start_dialogue_by_id(chain_id, true)

func _on_townfolk_dialogue_started(_chain: TownfolkDialogueChain) -> void:
	$Townfolk/InteractionZone.enabled = false

func _on_townfolk_dialogue_ended(_chain: TownfolkDialogueChain) -> void:
	$Townfolk/InteractionZone.enabled = phase != Phase.COMPLETED
