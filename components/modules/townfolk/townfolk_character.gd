@tool
class_name TownfolkCharacter
extends Node2D
## Standalone presentation actor. External systems choose when and what to speak.
signal dialogue_started(chain: TownfolkDialogueChain)
signal dialogue_finished(chain: TownfolkDialogueChain)
signal dialogue_cancelled(chain: TownfolkDialogueChain)
signal syllable_heard(listener: Node2D, chain: TownfolkDialogueChain, line_index: int, syllable_index: int, syllable: String)
## Accuracy is 0..1. The enclosing level awards points; this actor displays the result.
signal reaction_resolved(listener: Node2D, accuracy: float)
enum ReactionPopupPlacement { ABOVE_BUBBLE, ABOVE_LISTENER }
const ConversationView = preload("res://components/ui/townfolk_conversation/townfolk_conversation.gd")

@export_group("Identity")
@export var character_profile: CharacterProfile:
	set(value):
		if character_profile != null and character_profile.changed.is_connected(_refresh_avatar):
			character_profile.changed.disconnect(_refresh_avatar)
		character_profile = value
		if character_profile != null:
			character_profile.changed.connect(_refresh_avatar)
		if is_node_ready():
			_refresh_avatar()
@export_group("Working Shift Dialogue")
@export var dialogue_chains: Array[TownfolkDialogueChain] = []
@export_group("Off-Shift Dialogue")
@export var off_shift_dialogue_chains: Array[TownfolkDialogueChain] = []
@export var interact_action: StringName = &"interact"
@export_group("Interaction")
@export var interaction_enabled: bool = true
@export_range(1, 1000, 1) var interaction_radius: float = 90
## Normally supplied by the enclosing GameLevel.
@export var progress_manager: ProgressManager
@export_group("Dialogue Phase")
## Defaults to the nearest enclosing GameLevel when unassigned.
@export var phase_source: GameLevel
## Used when there is no enclosing GameLevel.
@export var dialogue_phase: GameLevel.Phase = GameLevel.Phase.ON_SHIFT:
	set(value):
		dialogue_phase = value
		if is_node_ready() and not Engine.is_editor_hint():
			_on_phase_changed(get_dialogue_phase())
@export_group("Dialogue Playback")
@export var default_voice_bank: VoiceSoundBank
@export var autoplay: bool = false
@export_group("Hearing")
## Explicit listener, or nearest member of listener_group when unassigned.
@export var listener: Node2D
@export var listener_group: StringName = &"players"
@export_range(1, 2000, 1) var hearing_range: float = 220
@export var show_listening_tether: bool = true
@export_range(1, 64, 1) var heart_count: int = 20
@export_range(1, 16, 0.5) var heart_size: float = 4.0
@export_range(0, 60, 1) var heart_spread: float = 14.0
@export_range(0, 20, 0.5) var heart_wave_height: float = 4.0
@export_group("Reactions")
@export var reactions_enabled: bool = true
@export var reaction_action: StringName = &"townfolk_react"
## Seconds around a word becoming fully pink that can score.
@export_range(0.05, 1.0, 0.01) var reaction_window: float = 0.45
## Perfect starts when the whole word is pink; early presses cannot be perfect.
@export_range(0.01, 0.5, 0.005) var reaction_perfect_window: float = 0.18
@export_range(0, 10000, 1) var perfect_popup_points: int = 100
@export var reaction_popups_enabled: bool = true
@export var reaction_popup_placement: ReactionPopupPlacement = ReactionPopupPlacement.ABOVE_LISTENER
## World-space offset from the listener's origin, used for Above Listener.
@export var reaction_popup_offset := Vector2(0, -64)

var _spoken: Dictionary = {}
var _text: String = ""
var word_reactions: TownfolkWordReactions
var _current_listener: Node2D
var _bank: VoiceSoundBank
var _heart_time: float = 0.0
var _heart_seeds: Array[Vector4] = []
var _heart_shape := PackedVector2Array()
var _using_conversation: bool = false
var _locked_listener: Node2D
var _listener_process_mode: ProcessMode
var _local_progress: ProgressManager
var _fallback_profile: CharacterProfile
var _active_progress: ProgressManager
var _active_profile: CharacterProfile
var _active_chain: TownfolkDialogueChain
var _active_mode: ProgressManager.DialogueMode
@onready var playback: TownfolkDialoguePlayback = $DialoguePlayback
@onready var bubble: TownfolkDialogueBubble = $DialogueBubble
@onready var mouth: Marker2D = $MouthAnchor
@onready var bubble_anchor: Marker2D = $BubbleAnchor
@onready var voice: SoundBankPlayer2D = $Voice
@onready var conversation: ConversationView = $Conversation
@onready var world_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _fallback_avatar: SpriteFrames = world_sprite.sprite_frames
@onready var interaction_hint: InputHintLabel = $InteractionHint

func _ready() -> void:
	_refresh_avatar()
	if Engine.is_editor_hint():
		return
	var initial_voice := default_voice_bank
	if initial_voice == null and character_profile != null:
		initial_voice = character_profile.voice_bank
	if initial_voice != null:
		initial_voice.prepare()
	add_to_group(&"townfolk_speakers")
	word_reactions = TownfolkWordReactions.new()
	word_reactions.resolved.connect(_on_word_resolved)
	for index in 28:
		var angle := TAU * index / 28.0
		_heart_shape.append(Vector2(16 * pow(sin(angle), 3), -(13 * cos(angle) - 5 * cos(2 * angle) - 2 * cos(3 * angle) - cos(4 * angle))) / 18.0)
	for index in 64:
		# Fixed random seeds prevent offsets from jittering between frames.
		_heart_seeds.append(Vector4(randf(), randf_range(-1, 1), randf() * TAU, randf_range(0.8, 1.2)))
	bubble.hide()
	playback.line_started.connect(_on_line_started)
	playback.chunk_revealed.connect(_on_chunk)
	playback.chunk_highlighted.connect(_on_highlight)
	playback.finished.connect(_on_finished)
	playback.line_revealed.connect(_on_line_revealed)
	conversation.advance_requested.connect(playback.continue_dialogue)
	if phase_source == null:
		var ancestor := get_parent()
		while ancestor != null:
			if ancestor is GameLevel:
				phase_source = ancestor
				break
			ancestor = ancestor.get_parent()
	if phase_source != null:
		phase_source.phase_changed.connect(_on_phase_changed)
		phase_source.register_townfolk(self)
	if autoplay:
		var next := get_next_dialogue_chain()
		if next != null:
			start_dialogue(next, true)

func _refresh_avatar() -> void:
	if not is_instance_valid(world_sprite):
		return
	world_sprite.stop()
	world_sprite.sprite_frames = character_profile.in_game_avatar if character_profile != null and character_profile.in_game_avatar != null else _fallback_avatar
	var frames := world_sprite.sprite_frames
	var idle := character_profile.in_game_idle_animation if character_profile != null else &"idle"
	if not frames.has_animation(idle) or frames.get_frame_count(idle) == 0:
		idle = &""
		for candidate in frames.get_animation_names():
			if frames.get_frame_count(candidate) > 0:
				idle = candidate
				break
	world_sprite.visible = not idle.is_empty()
	if idle.is_empty():
		return
	world_sprite.animation = idle
	world_sprite.frame = 0
	if frames.get_frame_count(idle) > 1:
		world_sprite.play(idle)

func get_dialogue_phase() -> GameLevel.Phase:
	return phase_source.phase if is_instance_valid(phase_source) else dialogue_phase

func get_available_dialogue_chains() -> Array[TownfolkDialogueChain]:
	return dialogue_chains if get_dialogue_phase() == GameLevel.Phase.ON_SHIFT else off_shift_dialogue_chains

func get_next_dialogue_chain() -> TownfolkDialogueChain:
	return _get_progress_manager().get_next_dialogue(_get_progress_profile(), get_available_dialogue_chains(), _get_dialogue_mode())

func can_interact(candidate: Node2D) -> bool:
	return _in_interaction_range(candidate) and not playback.is_playing and not get_tree().has_group(ConversationView.SESSION_GROUP) and not get_tree().has_group(&"signal_network_repair_session") and get_next_dialogue_chain() != null

func interact(candidate: Node2D) -> bool:
	if not can_interact(candidate):
		return false
	# Only unfinished chains are selected, including retrying a cancelled presentation.
	return start_dialogue(get_next_dialogue_chain(), true)

func _get_progress_manager() -> ProgressManager:
	if is_instance_valid(progress_manager):
		return progress_manager
	if is_instance_valid(phase_source):
		if not is_instance_valid(phase_source.dialogue_progress):
			# The level adopts this node in its _ready, after child actors are ready.
			phase_source.dialogue_progress = ProgressManager.new()
		return phase_source.dialogue_progress
	if not is_instance_valid(_local_progress):
		_local_progress = ProgressManager.new()
		_local_progress.name = "DialogueProgress"
		add_child(_local_progress)
	return _local_progress

func _get_progress_profile() -> CharacterProfile:
	if character_profile != null:
		return character_profile
	if _fallback_profile == null:
		_fallback_profile = CharacterProfile.new()
	return _fallback_profile

func _get_dialogue_mode() -> ProgressManager.DialogueMode:
	return ProgressManager.DialogueMode.WORK_SHIFT if get_dialogue_phase() == GameLevel.Phase.ON_SHIFT else ProgressManager.DialogueMode.OFF_SHIFT

func _in_interaction_range(candidate: Node2D) -> bool:
	return interaction_enabled and is_visible_in_tree() and get_dialogue_phase() != GameLevel.Phase.COMPLETED and is_instance_valid(candidate) and global_position.distance_squared_to(candidate.global_position) <= interaction_radius * interaction_radius

func _owns_interaction_input(candidate: Node2D) -> bool:
	var distance := global_position.distance_squared_to(candidate.global_position)
	for other in get_tree().get_nodes_in_group(&"townfolk_speakers"):
		if other == self or not other is TownfolkCharacter or not other._in_interaction_range(candidate):
			continue
		var other_distance: float = other.global_position.distance_squared_to(candidate.global_position)
		if other_distance < distance or (is_equal_approx(other_distance, distance) and other.get_instance_id() < get_instance_id()):
			return false
	return true

func _refresh_interaction_hint(candidate: Node2D) -> void:
	interaction_hint.visible = not playback.is_playing and _in_interaction_range(candidate) and not get_tree().has_group(ConversationView.SESSION_GROUP) and not get_tree().has_group(&"signal_network_repair_session") and _owns_interaction_input(candidate)
	if not interaction_hint.visible:
		return
	var speaker := character_profile.display_name if character_profile != null and not character_profile.display_name.is_empty() else String(name)
	if get_next_dialogue_chain() == null:
		interaction_hint.set_hint("%s is busy" % speaker)
		return
	interaction_hint.set_hint("[action:%s] Talk to %s" % [interact_action, speaker])

## Returns false for an invalid, already started, or busy request. No implicit interruption.
func start_dialogue(chain: TownfolkDialogueChain, allow_replay: bool = false) -> bool:
	if not is_node_ready() or Engine.is_editor_hint() or playback.is_playing or chain == null:
		return false
	if get_dialogue_phase() == GameLevel.Phase.COMPLETED or get_tree().has_group(ConversationView.SESSION_GROUP) or get_tree().has_group(&"signal_network_repair_session"):
		return false
	_using_conversation = get_dialogue_phase() != GameLevel.Phase.ON_SHIFT
	var key := _chain_key(chain)
	if not allow_replay and _spoken.has(key):
		return false
	var manager := _get_progress_manager()
	var profile := _get_progress_profile()
	var mode := _get_dialogue_mode()
	if not manager.begin_dialogue(profile, chain, mode, allow_replay):
		return false
	_active_progress = manager
	_active_profile = profile
	_active_chain = chain
	_active_mode = mode
	_bank = chain.voice_bank if chain.voice_bank != null else default_voice_bank
	if _bank == null and character_profile != null:
		_bank = character_profile.voice_bank
	voice.bank = _bank
	if _bank != null:
		_bank.prepare()
	voice.max_distance = hearing_range
	bubble.reset()
	word_reactions.timing_window = reaction_window
	word_reactions.perfect_window = minf(reaction_perfect_window, reaction_window)
	playback.minimum_hold_seconds = reaction_window + 0.02 if reactions_enabled and chain.reactions_enabled else 0.0
	if not playback.start(chain, _using_conversation):
		_release_progress(false)
		return false
	if _using_conversation:
		conversation.interact_action = interact_action
		conversation.open(character_profile, String(name))
		_lock_listener()
	else:
		bubble.set_minimized(not can_hear(_find_listener()))
		bubble.show()
	_spoken[key] = true
	dialogue_started.emit(chain)
	return true

func start_dialogue_by_id(chain_id: StringName, allow_replay: bool = false) -> bool:
	for chain in get_available_dialogue_chains():
		if chain != null and chain.chain_id == chain_id:
			return start_dialogue(chain, allow_replay)
	return false

func stop_dialogue() -> void:
	if not playback.is_playing:
		return
	var cancelled := playback.chain
	playback.stop()
	_clear_presentation()
	_release_progress(false)
	dialogue_cancelled.emit(cancelled)

func can_hear(candidate: Node2D) -> bool:
	if not Engine.is_editor_hint() and get_tree().has_group(ConversationView.SESSION_GROUP):
		return false
	return is_instance_valid(candidate) and mouth.global_position.distance_squared_to(candidate.global_position) <= hearing_range * hearing_range

func _process(delta: float) -> void:
	bubble.global_position = bubble_anchor.global_position
	bubble.mouth_position = bubble.to_local(mouth.global_position)
	queue_redraw()
	if Engine.is_editor_hint():
		return
	_current_listener = _find_listener()
	_refresh_interaction_hint(_current_listener)
	if _using_conversation and playback.is_playing:
		return
	var hearing := can_hear(_current_listener)
	_heart_time += delta
	bubble.set_minimized(playback.is_playing and not hearing)
	if not hearing:
		voice.stop()
	if playback.is_playing and word_reactions.advance(playback.elapsed_seconds, hearing):
		_refresh_word_text()

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or event.is_echo():
		return
	if InputMap.has_action(interact_action) and event.is_action_pressed(interact_action):
		var target := _find_listener()
		if _in_interaction_range(target) and _owns_interaction_input(target) and interact(target):
			get_viewport().set_input_as_handled()
			return
	if not InputMap.has_action(reaction_action):
		return
	if not playback.is_playing or _using_conversation or not reactions_enabled or not playback.chain.reactions_enabled:
		return
	if get_tree().has_group(&"signal_network_repair_session") or not event.is_action_pressed(reaction_action):
		return
	_current_listener = _find_listener()
	if not can_hear(_current_listener) or not _owns_reaction_input():
		return
	word_reactions.advance(playback.elapsed_seconds, true)
	if word_reactions.react(playback.elapsed_seconds):
		get_viewport().set_input_as_handled()
		_refresh_word_text()

func _on_word_resolved(accuracy: float, pressed: bool) -> void:
	if pressed and accuracy > 0 and reaction_popups_enabled:
		var target: Node2D = _current_listener if reaction_popup_placement == ReactionPopupPlacement.ABOVE_LISTENER else null
		bubble.show_result(accuracy, perfect_popup_points, target, reaction_popup_offset)
	reaction_resolved.emit(_current_listener, accuracy)

func _on_line_started(index: int) -> void:
	_text = ""
	if _using_conversation:
		var last_line := true
		for next_index in range(index + 1, playback.chain.lines.size()):
			var line := playback.chain.lines[next_index]
			if line != null and not line.text.strip_edges().is_empty():
				last_line = false
		conversation.begin_line(playback.chain.lines[index], last_line)
		return
	word_reactions.begin_line(playback.chain.lines[index].get_chunks())
	bubble.randomize_shape()
	bubble.set_text(_text)

func _on_chunk(chunk: String, line_index: int, chunk_index: int) -> void:
	_text += chunk
	if _using_conversation:
		conversation.reveal_chunk(chunk, _bank)
		return
	var target := _find_listener()
	var enabled := reactions_enabled and playback.chain.reactions_enabled
	word_reactions.reveal(chunk_index, playback.elapsed_seconds + playback.seconds_until_next_event(), can_hear(target), enabled)
	_refresh_word_text()
	if not can_hear(target) or not TownfolkDialogueLine.is_spoken(chunk):
		return
	if _bank != null:
		voice.stop()
		var clip := _bank.clip_for_syllable(chunk)
		if get_parent() is CanvasLayer:
			# The tutorial guide is in screen space during repair instructions.
			var played := AudioManager.play_sound(clip, &"townfolk_voice", &"SFX", self)
			if played != null:
				played.pitch_scale = _bank.random_pitch()
		else:
			var played := voice.play_clip(clip)
			if played != null:
				played.pitch_scale = _bank.random_pitch()
	syllable_heard.emit(target, playback.chain, line_index, chunk_index, chunk.strip_edges())

func _on_highlight(index: int) -> void:
	word_reactions.highlight(index)
	_refresh_word_text()

func _refresh_word_text() -> void:
	if playback.is_playing and reactions_enabled and playback.chain.reactions_enabled:
		bubble.set_segments(word_reactions.segments())
	else:
		bubble.set_text(_text)

func _on_finished(chain: TownfolkDialogueChain) -> void:
	_clear_presentation()
	_release_progress(true)
	dialogue_finished.emit(chain)

func _release_progress(completed: bool) -> void:
	var manager := _active_progress
	var profile := _active_profile
	var chain := _active_chain
	var mode := _active_mode
	_active_progress = null
	_active_profile = null
	_active_chain = null
	if is_instance_valid(manager):
		if completed:
			manager.finish_dialogue(profile, chain, mode)
		else:
			manager.cancel_dialogue(profile, chain, mode)

func _on_line_revealed(_index: int) -> void:
	if _using_conversation:
		conversation.complete_line()

func _on_phase_changed(phase: GameLevel.Phase) -> void:
	if playback.is_playing and (phase == GameLevel.Phase.COMPLETED or _using_conversation != (phase != GameLevel.Phase.ON_SHIFT)):
		stop_dialogue()

func _lock_listener() -> void:
	_locked_listener = _find_listener()
	if is_instance_valid(_locked_listener):
		_listener_process_mode = _locked_listener.process_mode
		_locked_listener.process_mode = Node.PROCESS_MODE_DISABLED

func _release_listener() -> void:
	if is_instance_valid(_locked_listener):
		_locked_listener.process_mode = _listener_process_mode
	_locked_listener = null

func _exit_tree() -> void:
	_release_listener()
	_release_progress(false)

func _clear_presentation() -> void:
	conversation.close()
	_release_listener()
	_using_conversation = false
	voice.stop()
	word_reactions.begin_line(PackedStringArray())
	bubble.reset()
	bubble.hide()

func _find_listener() -> Node2D:
	if is_instance_valid(listener):
		return listener
	var nearest: Node2D
	var distance := INF
	for candidate in get_tree().get_nodes_in_group(listener_group):
		if candidate is Node2D:
			var candidate_distance := mouth.global_position.distance_squared_to(candidate.global_position)
			if candidate_distance < distance:
				distance = candidate_distance
				nearest = candidate
	return nearest

func _owns_reaction_input() -> bool:
	var distance := global_position.distance_squared_to(_current_listener.global_position)
	for other in get_tree().get_nodes_in_group(&"townfolk_speakers"):
		if other == self or not other is TownfolkCharacter or other.word_reactions == null or not other.playback.is_playing or not other.word_reactions.has_target():
			continue
		if other._find_listener() != _current_listener or not other.can_hear(_current_listener):
			continue
		var other_distance: float = other.global_position.distance_squared_to(_current_listener.global_position)
		if other_distance < distance or (is_equal_approx(other_distance, distance) and other.get_instance_id() < get_instance_id()):
			return false
	return true

func _chain_key(chain: TownfolkDialogueChain) -> String:
	var prefix := "conversation:" if _using_conversation else "shift:"
	if not chain.chain_id.is_empty():
		return prefix + String(chain.chain_id)
	return prefix + (chain.resource_path if not chain.resource_path.is_empty() else str(chain.get_instance_id()))

func _draw() -> void:
	if Engine.is_editor_hint():
		return
	if not _using_conversation and show_listening_tether and is_instance_valid(_current_listener) and playback.is_revealing and can_hear(_current_listener):
		var end := to_local(_current_listener.global_position)
		var normal := (end - mouth.position).normalized().orthogonal()
		draw_line(mouth.position, end, Color(1, 0.6, 0.75, 0.12), 1, true)
		for index in mini(heart_count, _heart_seeds.size()):
			var seed := _heart_seeds[index]
			var progress := fposmod(seed.x + _heart_time * 0.3 * seed.w, 1.0)
			var center := mouth.position.lerp(end, progress)
			center += normal * seed.y * heart_spread
			center.y += sin(_heart_time * 3 + seed.z) * heart_wave_height
			var points := PackedVector2Array()
			for point in _heart_shape:
				points.append(center + point * heart_size * seed.w)
			var color := Color("ed8099")
			color.a = sin(progress * PI) * 0.85
			draw_colored_polygon(points, color)
