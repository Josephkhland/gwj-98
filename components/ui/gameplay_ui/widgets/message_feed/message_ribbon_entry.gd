extends PanelContainer
## Icon-only slot. The board drives all animation time so hiding the HUD pauses it.
enum Visual { WARNING, FLYING, FAILURE, ARRIVAL, CLOSED, OPENED, DOCUMENT }
const FORWARD = preload("res://assets/nicoichu/Software_Email_Message_Forward_Send.png")
const PLANE = preload("res://assets/nicoichu/Software_Email_Message_Send_Paper_Plane.png")
const CROSS = preload("res://assets/nicoichu/Software_Email_Message_Delete_Cross.png")
const CLOSED = preload("res://assets/nicoichu/Software_Email_Message_Unread_Closed.png")
const OPENED = preload("res://assets/nicoichu/Software_Email_Message_Read_Opened.png")
const DOCUMENT = preload("res://assets/nicoichu/Software_Email_Message_Read_Opened_Document_Text.png")
@export_range(0.1, 2, 0.05) var arrival_seconds: float = 0.55
@export_range(0.1, 1, 0.05) var centering_seconds: float = 0.3
@export_range(0.1, 1, 0.05) var closed_seconds: float = 0.35
@export_range(0.1, 1, 0.05) var opened_seconds: float = 0.4
var message: NetworkMessage
var visual: Visual = Visual.WARNING
var _game_seconds: float = 0
var _elapsed: float = 0
var _state_elapsed: float = 0
var _last_state: int = -1
var _opening: bool = false
var _opening_elapsed: float = 0
var highlighted: bool = false
var _style: StyleBoxFlat
@onready var _sender: PanelContainer = $Stage/Sender
@onready var _recipient: PanelContainer = $Stage/Recipient
@onready var _icon: TextureRect = $Stage/Icon
@onready var _timer: Label = $Stage/Timer
@onready var _title: Label = $Stage/Title

func _ready() -> void:
	_style = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	add_theme_stylebox_override("panel", _style)
	resized.connect(_render)

func bind_message(value: NetworkMessage, game_seconds: float) -> void:
	_opening = false
	highlighted = false
	_opening_elapsed = 0
	_elapsed = 0
	_last_state = -1
	update_message(value, game_seconds)

func update_message(value: NetworkMessage, game_seconds: float) -> void:
	message = value
	_game_seconds = game_seconds
	if _last_state != message.state:
		_last_state = message.state
		_state_elapsed = 0
	_set_avatar(_sender, message.definition.sender, _participant_name(true))
	_set_avatar(_recipient, message.definition.recipient, _participant_name(false))
	_refresh_tooltip()
	_render()

func set_game_time(value: float) -> void:
	_game_seconds = value
	_refresh_tooltip()
	_render()

func begin_presentation() -> void:
	_opening = true
	highlighted = true
	_opening_elapsed = 0
	_render()

func opening_duration() -> float:
	return arrival_seconds + centering_seconds + closed_seconds + opened_seconds

func document_is_visible() -> bool:
	return _opening and _opening_elapsed >= opening_duration()

func advance_visual(delta: float) -> void:
	_elapsed += maxf(0, delta)
	_state_elapsed += maxf(0, delta)
	if _opening:
		_opening_elapsed += maxf(0, delta)
	_render()

func _set_avatar(avatar: PanelContainer, profile: CharacterProfile, name_text: String) -> void:
	var portrait := avatar.get_node("Portrait") as TextureRect
	var initial := avatar.get_node("Initial") as Label
	portrait.texture = profile.portrait if profile != null else null
	portrait.visible = portrait.texture != null
	initial.visible = portrait.texture == null
	initial.text = name_text.left(1).to_upper()
	avatar.tooltip_text = name_text

func _render() -> void:
	if not is_node_ready() or message == null:
		return
	var middle := size.x * 0.5
	var sender_x := 24.0
	var recipient_x := size.x - 24
	_sender.position = Vector2(8, 25)
	_recipient.position = Vector2(size.x - 40, 25)
	_sender.size = Vector2(32, 32)
	_recipient.size = Vector2(32, 32)
	_recipient.modulate = Color.WHITE
	_icon.size = Vector2(28, 28)
	_icon.pivot_offset = _icon.size * 0.5
	_icon.rotation = 0
	_icon.position = Vector2(middle - 14, 27)
	_icon.modulate = Color.WHITE
	_title.position = Vector2(8, 2)
	_title.size = Vector2(maxf(20, size.x - 88), 20)
	_title.text = message.definition.get_display_title()
	_title.tooltip_text = _title.text
	_timer.position = Vector2(size.x - 76, 3)
	_timer.size = Vector2(68, 20)
	_timer.visible = false
	var failed := message.state == NetworkMessage.State.EXPIRED
	var accent := Color("ff777c") if failed else Color("ffd382")
	var emphasized := failed or highlighted
	_style.set_border_width_all(2 if emphasized else 0)
	_style.border_color = accent
	_style.bg_color = Color("1b2930").lerp(accent.darkened(0.7), (0.35 + 0.15 * sin(_state_elapsed * 7)) if failed else (0.35 if highlighted else 0.0))
	_title.modulate = accent if emphasized else Color("dce7e8")
	if _opening:
		_render_opening(sender_x, recipient_x, middle)
	elif message.state == NetworkMessage.State.UPCOMING:
		visual = Visual.WARNING
		_icon.texture = FORWARD
		_timer.text = _duration(message.send_seconds - _game_seconds)
		_timer.show()
	elif message.state == NetworkMessage.State.EXPIRED:
		visual = Visual.FAILURE
		_icon.texture = CROSS
		var bump := clampf((_state_elapsed - 0.15) / 0.35, 0, 1)
		_recipient.position.x += 32 * smoothstep(0, 1, bump)
		_recipient.modulate.a = 1 - bump
		var impact := sin(PI * clampf(_state_elapsed / 0.7, 0, 1))
		_icon.position.x = lerpf(middle, recipient_x, impact) - 14
		_icon.modulate = Color(1, 0.25, 0.3, 0.4 + 0.6 * absf(sin(_state_elapsed * 8)))
		_timer.text = "EXPIRED"
		_timer.show()
	else:
		visual = Visual.FLYING
		_icon.texture = PLANE
		_icon.rotation_degrees = 45
		var travel := fposmod(_elapsed / 1.35, 1)
		_icon.position.x = lerpf(sender_x + 32, recipient_x - 32, travel) - 14
		_icon.modulate.a = (0.35 + 0.65 * absf(sin(_elapsed * 10))) * minf(1, (1 - travel) * 6)
		if message.state == NetworkMessage.State.PENDING:
			_timer.text = _duration(message.deadline_seconds - _game_seconds)
			_timer.show()
	if _opening or highlighted:
		_timer.text = "READING" if document_is_visible() else "OPENING"
		_timer.show()
	_timer.add_theme_color_override("font_color", accent if emphasized else Color("ffd382"))

func _render_opening(sender_x: float, recipient_x: float, middle: float) -> void:
	var travel_end := arrival_seconds + centering_seconds
	if _opening_elapsed < travel_end:
		visual = Visual.ARRIVAL
		_icon.texture = PLANE
		_icon.rotation_degrees = 45
		if _opening_elapsed < arrival_seconds:
			_icon.position.x = lerpf(sender_x + 32, recipient_x, smoothstep(0, 1, _opening_elapsed / arrival_seconds)) - 14
		else:
			var centering := clampf((_opening_elapsed - arrival_seconds) / centering_seconds, 0, 1)
			_icon.position.x = lerpf(recipient_x, middle, smoothstep(0, 1, centering)) - 14
			_recipient.position.x += sin(centering * PI) * 10
	elif _opening_elapsed < travel_end + closed_seconds:
		visual = Visual.CLOSED
		_icon.texture = CLOSED
	elif not document_is_visible():
		visual = Visual.OPENED
		_icon.texture = OPENED
	else:
		visual = Visual.DOCUMENT
		_icon.texture = DOCUMENT

func _participant_name(sender: bool) -> String:
	var profile := message.definition.sender if sender else message.definition.recipient
	if profile != null and not profile.display_name.is_empty():
		return profile.display_name
	var label := message.from_label if sender else message.to_label
	if not label.is_empty():
		return label
	var key := message.definition.from_house if sender else message.definition.to_house
	return String(key) if not key.is_empty() else ("Sender" if sender else "Target")

func _refresh_tooltip() -> void:
	if message == null:
		return
	var state_text := "Upcoming"
	match message.state:
		NetworkMessage.State.PENDING:
			state_text = "Buffering · %s remaining" % _duration(message.deadline_seconds - _game_seconds)
		NetworkMessage.State.DELIVERED:
			state_text = "Delivered +%d · Waiting to read" % message.score
		NetworkMessage.State.EXPIRED:
			state_text = "Expired"
	tooltip_text = "%s → %s\n%s\nDeliver by %s\n%s" % [_participant_name(true), _participant_name(false), state_text, message.deadline_text, message.definition.text]

func _duration(seconds: float) -> String:
	var total := maxi(0, ceili(seconds))
	return "%02d:%02d" % [total / 60, total % 60]
