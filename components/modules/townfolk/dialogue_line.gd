class_name TownfolkDialogueLine
extends Resource
const InputIcons = preload("res://components/ui/input_icons/input_icon_text.gd")
## Write normal text; syllable boundaries are estimated automatically.
## Optional | marks override a word's automatic split without appearing on screen.
@export_multiline var text: String = ""
@export_range(0.02, 2.0, 0.01) var syllable_seconds: float = 0.03
@export_range(0.0, 3.0, 0.05) var punctuation_comma: float = 0.2
@export_range(0.0, 3.0, 0.05) var punctuation_pause: float = 0.4
## Shift bubbles only. Off-shift conversations always wait for player input.
@export_range(0.0, 30.0, 0.1) var hold_seconds: float = 6.0

const ONSETS := ["str", "spr", "scr", "spl", "shr", "thr", "ch", "sh", "th", "ph", "wh", "qu", "bl", "br", "cl", "cr", "dr", "fl", "fr", "gl", "gr", "pl", "pr", "sc", "sk", "sl", "sm", "sn", "sp", "st", "sw", "tr", "tw"]

func get_chunks() -> PackedStringArray:
	var chars := PackedStringArray()
	for i in text.length():
		chars.append(text[i])
	return chars

	var chunks := PackedStringArray()
	var words := RegEx.new()
	words.compile("\\[[^\\]\\r\\n]+\\]|\\s+|[^\\s\\[]+|\\[")
	for match_result in words.search_all(text):
		var word := match_result.get_string()
		if word.strip_edges().is_empty():
			if chunks.is_empty():
				chunks.append(word)
			else:
				chunks[chunks.size() - 1] += word
		elif InputIcons.is_input_token(word):
			chunks.append(word)
		elif word.contains("|"):
			chunks.append_array(word.split("|", false))
		else:
			chunks.append_array(_split_word(word))
	return chunks

static func _split_word(word: String) -> PackedStringArray:
	var letters := RegEx.new()
	letters.compile("(?i)[a-z]+(?:['’][a-z]+)*")
	var lexical := letters.search(word)
	if lexical == null:
		return PackedStringArray([word])
	var lower := lexical.get_string().to_lower()
	var vowels := RegEx.new()
	vowels.compile("[aeiouy]+")
	var groups := vowels.search_all(lower)
	# Silent e and unstressed plural/past endings do not add a blip.
	if groups.size() > 1:
		var last = groups[groups.size() - 1]
		var consonant_le := lower.ends_with("le") and lower.length() > 2 and not "aeiouy".contains(lower[-3])
		var silent_e := lower.ends_with("e") and last.get_start() == lower.length() - 1 and not consonant_le
		var silent_ed := lower.ends_with("ed") and lower.length() > 2 and not "td".contains(lower[-3]) and last.get_start() == lower.length() - 2
		var sounded_es := lower.ends_with("ses") or lower.ends_with("xes") or lower.ends_with("zes") or lower.ends_with("ches") or lower.ends_with("shes") or lower.ends_with("ges")
		var silent_es := lower.ends_with("es") and not sounded_es and last.get_start() == lower.length() - 2
		if silent_e or silent_ed or silent_es:
			groups.pop_back()
	var chunks := PackedStringArray()
	var start := 0
	for index in range(1, groups.size()):
		var previous_end: int = groups[index - 1].get_end()
		var next_start: int = groups[index].get_start()
		var gap := lower.substr(previous_end, next_start - previous_end)
		var onset := mini(1, gap.length())
		for cluster in ONSETS:
			if gap.ends_with(cluster):
				onset = maxi(onset, cluster.length())
		var boundary := next_start - onset
		if index == groups.size() - 1 and lower.ends_with("le") and next_start == lower.length() - 1:
			boundary = maxi(previous_end, lower.length() - 3)
		boundary += lexical.get_start()
		if boundary > start:
			chunks.append(word.substr(start, boundary - start))
			start = boundary
	chunks.append(word.substr(start))
	return chunks

static func is_spoken(chunk: String) -> bool:
	if InputIcons.is_input_token(chunk):
		return false
	for character in chunk:
		if character.to_lower() != character.to_upper() or character.is_valid_int():
			return true
	return false
