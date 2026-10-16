extends CanvasLayer
## Screen-space, player-paced dialogue. Does not award hearing or reaction rewards.
signal advance_requested
const SESSION_GROUP := &"townfolk_conversation_session"
var interact_action: StringName = &"interact"
var _complete: bool = false
var _last_line: bool = false
@onready var _art_area: Control = $Root/ArtArea
@onready var _portrait: TextureRect = $Root/ArtArea/Portrait
@onready var _name: Label = $Root/NameFrame/Margin/Name
@onready var _text: RichTextLabel = $Root/TextFrame/Margin/Content/Text
@onready var _continue: Button = $Root/TextFrame/Margin/Content/Footer/Continue
@onready var _hint: Label = $Root/TextFrame/Margin/Content/Footer/Hint
@onready var _voice: AudioStreamPlayer = $Voice

func _ready() -> void:
	hide()
	_continue.pressed.connect(advance_requested.emit)
	_art_area.resized.connect(_layout_portrait)

func open(profile: CharacterProfile, fallback_name: String) -> void:
	_name.text = profile.display_name if profile != null and not profile.display_name.is_empty() else fallback_name
	_portrait.texture = profile.full_body_portrait if profile != null else null
	_portrait.visible = _portrait.texture != null
	_layout_portrait()
	add_to_group(SESSION_GROUP)
	show()
	_update_prompt()

func close() -> void:
	_voice.stop()
	remove_from_group(SESSION_GROUP)
	hide()

func _layout_portrait() -> void:
	if _portrait.texture == null:
		return
	var texture_size := _portrait.texture.get_size()
	if texture_size.x <= 0 or texture_size.y <= 0:
		return
	var fit := minf(_art_area.size.x / texture_size.x, _art_area.size.y / texture_size.y)
	_portrait.size = texture_size * fit
	_portrait.position = Vector2(0, _art_area.size.y - _portrait.size.y)

func begin_line(line: TownfolkDialogueLine, last_line: bool) -> void:
	_text.text = "".join(line.get_chunks())
	_text.visible_characters = 0
	_text.scroll_to_line(0)
	_complete = false
	_last_line = last_line
	_update_prompt()

func reveal_chunk(chunk: String, bank: VoiceSoundBank) -> void:
	_text.visible_characters += chunk.length()
	if bank == null or not TownfolkDialogueLine.is_spoken(chunk):
		return
	var clip := bank.random_clip()
	if clip == null:
		return
	_voice.stream = clip
	_voice.pitch_scale = bank.random_pitch()
	_voice.volume_db = AudioConfig.volume_db(&"townfolk_voice")
	_voice.play()

func complete_line() -> void:
	_voice.stop()
	_text.visible_characters = -1
	_complete = true
	_update_prompt()

func _input(event: InputEvent) -> void:
	if not visible or not InputMap.has_action(interact_action):
		return
	if event.is_action(interact_action):
		get_viewport().set_input_as_handled()
		if event.is_action_pressed(interact_action) and not event.is_echo():
			advance_requested.emit()

func _update_prompt() -> void:
	_continue.text = ("Finish" if _last_line else "Continue") if _complete else "Reveal text"
	var binding := "Interact"
	var events := InputMap.action_get_events(interact_action) if InputMap.has_action(interact_action) else []
	for event in events:
		if event is InputEventKey:
			binding = event.as_text_physical_keycode() if event.physical_keycode != 0 else event.as_text_keycode()
			break
	_hint.text = "%s to %s" % [binding, _continue.text.to_lower()]
