class_name TownfolkDialoguePlayback
extends Node
## Presentation-independent playback. Keeps advancing when nobody is listening.
signal line_started(line_index: int)
signal chunk_revealed(chunk: String, line_index: int, chunk_index: int)
signal sentence_start(end: String)
signal chunk_highlighted(chunk_index: int)
signal finished(chain: TownfolkDialogueChain)
signal line_revealed(line_index: int)

var chain: TownfolkDialogueChain
var line_index: int = -1
var is_playing: bool = false
var is_revealing: bool = false
var _chunks := PackedStringArray()
var _chunk_index: int = 0
var _remaining: float = 0.0
var _generation: int = 0
var elapsed_seconds: float = 0.0
var minimum_hold_seconds: float = 0.0
var _pending_highlight: int = -1
var _holding: bool = false
var waits_for_input: bool = false

func seconds_until_next_event() -> float:
	return _remaining

func start(value: TownfolkDialogueChain, manual_advance: bool = false) -> bool:
	if value == null:
		return false
	var valid := false
	for line in value.lines:
		if line != null and not line.text.strip_edges().is_empty():
			valid = true
	if not valid:
		return false
	stop()
	waits_for_input = manual_advance
	chain = value
	is_playing = true
	line_index = -1
	elapsed_seconds = 0.0
	_next_line()
	sentence_start.emit(".")
	return true

func stop() -> void:
	_generation += 1
	is_playing = false
	is_revealing = false
	chain = null
	_chunks.clear()
	_remaining = 0.0
	_pending_highlight = -1
	_holding = false
	waits_for_input = false

## Finish only the current reveal, retaining the normal reading hold and line order.
func reveal_current_line() -> void:
	if not is_playing or not is_revealing:
		return
	_chunk_index = _chunks.size()
	is_revealing = false
	_pending_highlight = -1
	_holding = true
	_remaining = 0.0 if waits_for_input else maxf(chain.lines[line_index].hold_seconds, minimum_hold_seconds)
	line_revealed.emit(line_index)

## First press completes the current line silently; another advances or finishes.
func continue_dialogue() -> void:
	if not is_playing or not waits_for_input:
		return
	if is_revealing:
		_chunk_index = _chunks.size()
		is_revealing = false
		_remaining = 0
		_pending_highlight = -1
		line_revealed.emit(line_index)
	else:
		_next_line()

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not is_playing:
		return
	if waits_for_input and not is_revealing:
		return
	elapsed_seconds += delta
	_remaining -= delta
	var generation := _generation
	var steps := 0
	while is_playing and _remaining <= 0.0000001 and steps < 256:
		steps += 1
		if _pending_highlight >= 0:
			var highlighted := _pending_highlight
			_pending_highlight = -1
			chunk_highlighted.emit(highlighted)
			if generation != _generation:
				return
		if _chunk_index >= _chunks.size():
			if not _holding:
				_holding = true
				is_revealing = false
				_remaining += maxf(chain.lines[line_index].hold_seconds, minimum_hold_seconds)
				continue
			_next_line()
			if generation != _generation:
				return
			continue
		var chunk := _chunks[_chunk_index]
		var index := _chunk_index
		_chunk_index += 1
		var line := chain.lines[line_index]
		var delay := maxf(0.02, line.syllable_seconds)
		if chunk.strip_edges().ends_with(","):
			delay += maxf(0.0, line.punctuation_comma)
		elif chunk.strip_edges().ends_with(".") or chunk.strip_edges().ends_with("!") or chunk.strip_edges().ends_with("?"):
			delay += maxf(0.0, line.punctuation_pause)
			sentence_start.emit(".")
		_remaining += delay
		_pending_highlight = -1 if waits_for_input else index
		chunk_revealed.emit(chunk, line_index, index)
		if generation != _generation:
			return
		if waits_for_input and _chunk_index >= _chunks.size():
			is_revealing = false
			_remaining = 0
			line_revealed.emit(line_index)
			return

func _next_line() -> void:
	line_index += 1
	while line_index < chain.lines.size():
		var line := chain.lines[line_index]
		if line != null and not line.text.strip_edges().is_empty():
			_chunks = line.get_chunks()
			_chunk_index = 0
			_holding = false
			is_revealing = true
			if waits_for_input:
				_remaining = 0
			line_started.emit(line_index)
			return
		line_index += 1
	var completed := chain
	stop()
	finished.emit(completed)
