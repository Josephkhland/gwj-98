extends TownfolkCharacter
## The tutorial always teaches through world bubbles, including before clock-in.
@export_group("Tutorial Text Pace")
@export_range(0.02, 1, 0.01) var tutorial_syllable_seconds: float = 0.22
@export_range(0, 2, 0.05) var tutorial_punctuation_pause: float = 0.25
@export_range(0, 10, 0.1) var tutorial_reading_hold: float = 1.5
@export var reveal_action: StringName = &"tutorial_reveal"

func start_dialogue(chain: TownfolkDialogueChain, allow_replay: bool = false) -> bool:
	if chain == null:
		return false
	var paced := chain.duplicate() as TownfolkDialogueChain
	paced.lines = []
	for source in chain.lines:
		if source == null:
			continue
		var line := source.duplicate() as TownfolkDialogueLine
		line.syllable_seconds = tutorial_syllable_seconds
		line.punctuation_pause = tutorial_punctuation_pause
		line.hold_seconds = tutorial_reading_hold
		paced.lines.append(line)
	return super.start_dialogue(paced, allow_replay)

func can_reveal_dialogue() -> bool:
	return playback.is_playing and playback.is_revealing

func _input(event: InputEvent) -> void:
	if event.is_echo() or not InputMap.has_action(reveal_action) or not event.is_action_pressed(reveal_action):
		return
	if can_reveal_dialogue():
		get_viewport().set_input_as_handled()
		playback.reveal_current_line()

func _on_line_revealed(index: int) -> void:
	super._on_line_revealed(index)
	if _using_conversation:
		return
	_text = "".join(playback.chain.lines[index].get_chunks())
	word_reactions.revealed = word_reactions.text.length()
	# Skipped syllables produce no hearing rewards, voice burst or reaction targets.
	for word in word_reactions.words:
		if not word.closed:
			word.closed = true
			word.accuracy = 0.0
	_refresh_word_text()

func _ready() -> void:
	if default_voice_bank == null and character_profile != null:
		default_voice_bank = character_profile.voice_bank
	if default_voice_bank == null:
		# Temporary voice until the squirrel has a recording assigned in the Inspector.
		var clip := AudioStreamWAV.new()
		clip.format = AudioStreamWAV.FORMAT_16_BITS
		clip.mix_rate = 22050
		var samples := PackedByteArray()
		var count := 1764
		samples.resize(count * 2)
		for index in count:
			var time := float(index) / clip.mix_rate
			var envelope := sin(PI * float(index) / count)
			var sample := sin(TAU * (310 * time + 650 * time * time)) * envelope * 0.16
			samples.encode_s16(index * 2, roundi(sample * 32767))
		clip.data = samples
		default_voice_bank = VoiceSoundBank.new()
		default_voice_bank.stream = clip
		default_voice_bank.segment_length = 0.08
	super._ready()

func get_dialogue_phase() -> GameLevel.Phase:
	return GameLevel.Phase.COMPLETED if is_instance_valid(phase_source) and phase_source.phase == GameLevel.Phase.COMPLETED else GameLevel.Phase.ON_SHIFT

func _on_phase_changed(phase: GameLevel.Phase) -> void:
	if phase == GameLevel.Phase.COMPLETED:
		stop_dialogue()
