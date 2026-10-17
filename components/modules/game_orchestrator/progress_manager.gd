class_name ProgressManager
extends Node
## Runtime progression for the current run: the active level, what comes next, and the
## reports of finished days. Nothing here is written to disk.
signal level_changed(index: int, definition: LevelDefinition)
signal dialogue_progress_changed(profile: CharacterProfile, mode: DialogueMode)
enum DialogueMode { OFF_SHIFT, WORK_SHIFT }
@export var level_sequence: Array[LevelDefinition] = []
var current_index: int = -1
var reports: Array[DayReport] = []
var _dialogue_states: Dictionary = {}
var _active_dialogues: Dictionary = {}

func start_run(start_index: int = 0) -> void:
	reports.clear()
	_dialogue_states.clear()
	_active_dialogues.clear()
	_set_index(clampi(start_index, 0, maxi(level_sequence.size() - 1, 0)))

func get_current_level() -> LevelDefinition:
	if current_index < 0 or current_index >= level_sequence.size():
		return null
	return level_sequence[current_index]

func has_next() -> bool:
	return current_index + 1 < level_sequence.size()

func advance() -> bool:
	if not has_next():
		return false
	_set_index(current_index + 1)
	return true

func add_report(report: DayReport) -> void:
	reports.append(report)

func get_run_score() -> int:
	var total := 0
	for report in reports:
		total += report.score
	return total

## Only the first unfinished chain is eligible. A locked entry blocks all later ones.
func get_next_dialogue(profile: CharacterProfile, chains: Array[TownfolkDialogueChain], mode: DialogueMode) -> TownfolkDialogueChain:
	if profile == null or _active_dialogues.has(_profile_key(profile)):
		return null
	var state := _dialogue_state(profile, mode)
	for chain in chains:
		if chain == null:
			continue
		var key := _chain_key(chain)
		if state.played.has(key):
			continue
		if not state.unlocked.get(key, chain.initially_unlocked):
			return null
		for line in chain.lines:
			if line != null and not line.text.strip_edges().is_empty():
				return chain
		return null
	return null

func unlock_dialogue(profile: CharacterProfile, chain_id: StringName, mode: DialogueMode) -> void:
	set_dialogue_unlocked(profile, chain_id, mode, true)

func set_dialogue_unlocked(profile: CharacterProfile, chain_id: StringName, mode: DialogueMode, unlocked: bool) -> void:
	if profile == null or chain_id.is_empty():
		return
	_dialogue_state(profile, mode).unlocked[String(chain_id)] = unlocked
	dialogue_progress_changed.emit(profile, mode)

func is_dialogue_played(profile: CharacterProfile, chain_id: StringName, mode: DialogueMode) -> bool:
	return profile != null and _dialogue_state(profile, mode).played.has(String(chain_id))

## Reserve the whole character, across both modes and all placed instances of its profile.
## Scripted starts can explicitly replay; proximity interaction uses get_next_dialogue().
func begin_dialogue(profile: CharacterProfile, chain: TownfolkDialogueChain, mode: DialogueMode, allow_replay: bool = false) -> bool:
	if profile == null or chain == null:
		return false
	var character := _profile_key(profile)
	var key := _chain_key(chain)
	if _active_dialogues.has(character) or (not allow_replay and _dialogue_state(profile, mode).played.has(key)):
		return false
	_active_dialogues[character] = {"chain": key, "mode": mode}
	dialogue_progress_changed.emit(profile, mode)
	return true

func finish_dialogue(profile: CharacterProfile, chain: TownfolkDialogueChain, mode: DialogueMode) -> void:
	_release_dialogue(profile, chain, mode, true)

func cancel_dialogue(profile: CharacterProfile, chain: TownfolkDialogueChain, mode: DialogueMode) -> void:
	_release_dialogue(profile, chain, mode, false)

func _release_dialogue(profile: CharacterProfile, chain: TownfolkDialogueChain, mode: DialogueMode, completed: bool) -> void:
	if profile == null or chain == null:
		return
	var character := _profile_key(profile)
	var active: Dictionary = _active_dialogues.get(character, {})
	if active.get("chain") != _chain_key(chain) or active.get("mode") != mode:
		return
	_active_dialogues.erase(character)
	if completed:
		_dialogue_state(profile, mode).played[_chain_key(chain)] = true
	dialogue_progress_changed.emit(profile, mode)

func _dialogue_state(profile: CharacterProfile, mode: DialogueMode) -> Dictionary:
	var character := _profile_key(profile)
	if not _dialogue_states.has(character):
		_dialogue_states[character] = {}
	var modes: Dictionary = _dialogue_states[character]
	if not modes.has(mode):
		modes[mode] = {"unlocked": {}, "played": {}}
	return modes[mode]

func _profile_key(profile: CharacterProfile) -> String:
	if not profile.character_id.is_empty():
		return String(profile.character_id)
	return profile.resource_path if not profile.resource_path.is_empty() else str(profile.get_instance_id())

func _chain_key(chain: TownfolkDialogueChain) -> String:
	if not chain.chain_id.is_empty():
		return String(chain.chain_id)
	return chain.resource_path if not chain.resource_path.is_empty() else str(chain.get_instance_id())

func _set_index(index: int) -> void:
	current_index = index
	level_changed.emit(index, get_current_level())
