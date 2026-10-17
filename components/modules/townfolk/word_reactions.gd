class_name TownfolkWordReactions
extends RefCounted
## Word timing follows the playback clock, including the final syllable's pink step.
signal resolved(accuracy: float, pressed: bool)
var timing_window: float = 0.45
var perfect_window: float = 0.18
var words: Array[Dictionary] = []
var text: String = ""
var revealed: int = 0
var highlighted: int = 0
var _ends: Array[int] = []

func begin_line(chunks: PackedStringArray) -> void:
	words.clear()
	_ends.clear()
	text = "".join(chunks)
	revealed = 0
	highlighted = 0
	var offset := 0
	for chunk in chunks:
		offset += chunk.length()
		_ends.append(offset)
	var regex := RegEx.new()
	regex.compile("\\[[^\\]\\r\\n]+\\]|[^\\s\\[]+|\\[")
	for found in regex.search_all(text):
		if not TownfolkDialogueLine.is_spoken(found.get_string()):
			continue
		var last_chunk := 0
		while last_chunk < _ends.size() - 1 and _ends[last_chunk] < found.get_end():
			last_chunk += 1
		words.append({"start": found.get_start(), "end": found.get_end(), "last_chunk": last_chunk, "target": INF, "heard": true, "closed": false, "accuracy": -1.0})

func reveal(index: int, target_time: float, heard: bool, enabled: bool) -> void:
	var start := revealed
	revealed = _ends[index]
	for word in words:
		if word.start < revealed and word.end > start:
			word.heard = word.heard and heard and enabled
		if word.last_chunk == index:
			word.target = target_time
			if not word.heard:
				word.closed = true
				word.accuracy = 0.0

func highlight(index: int) -> void:
	highlighted = _ends[index]

func advance(now: float, hearing: bool) -> bool:
	var changed := false
	for word in words:
		if word.closed or not is_finite(word.target):
			continue
		if not hearing:
			changed = true
			word.closed = true
			word.accuracy = 0.0
		elif now > word.target + timing_window:
			changed = true
			word.closed = true
			word.accuracy = 0.0
			resolved.emit(0.0, false)
	return changed

func has_target() -> bool:
	return not _candidate().is_empty()

func react(now: float) -> bool:
	var word := _candidate()
	if word.is_empty():
		return false
	var error: float = now - word.target
	var accuracy := 1.0 if error >= -0.00001 and error <= perfect_window else clampf(1.0 - maxf(0, absf(error) - perfect_window) / maxf(0.01, timing_window - perfect_window), 0, 0.89)
	word.closed = true
	word.accuracy = accuracy
	resolved.emit(accuracy, true)
	return true

func _candidate() -> Dictionary:
	for word in words:
		if not word.closed and word.heard and is_finite(word.target):
			return word
	return {}

func segments() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var cursor := 0
	for word in words:
		if word.start >= revealed:
			break
		if cursor < word.start:
			result.append({"text": text.substr(cursor, word.start - cursor), "color": Color.BLACK, "gold": false})
		var end: int = mini(word.end, revealed)
		if word.closed:
			var accuracy: float = word.accuracy
			var color := Color("996000") if accuracy >= 0.9 else (Color("246e85") if accuracy >= 0.6 else (Color("97502d") if accuracy > 0 else Color.BLACK))
			result.append({"text": text.substr(word.start, end - word.start), "color": color, "gold": accuracy >= 0.9})
		else:
			var pink_end: int = clampi(highlighted, word.start, end)
			if pink_end > word.start:
				result.append({"text": text.substr(word.start, pink_end - word.start), "color": Color("c51b70"), "gold": false})
			if end > pink_end:
				result.append({"text": text.substr(pink_end, end - pink_end), "color": Color.BLACK, "gold": false})
		cursor = end
	if cursor < revealed:
		result.append({"text": text.substr(cursor, revealed - cursor), "color": Color.BLACK, "gold": false})
	return result
