class_name MessagePanel
extends PanelContainer
## View of one NetworkMessage. The owner supplies game time and grants present().
## This component never delivers a message, awards points, or frees itself.
signal presentation_requested
signal presentation_started
signal reply_revealed(index: int)
signal presentation_finished
signal ready_to_dismiss
signal presentation_cancelled

enum PresentationPhase { IDLE, REVEALING, BETWEEN_REPLIES, READING, COMPLETE, INITIAL_MESSAGE, BUFFERING, DELIVERY_RESULT }
const BubbleScene := preload("res://components/ui/message_panel/MessageBubble.tscn")
@export_range(0.05, 2.0, 0.05) var reveal_seconds: float = 0.35
@export_range(0.0, 10.0, 0.1) var reply_spacing_seconds: float = 1.5
@export_range(0.0, 60.0, 0.5) var minimum_reading_seconds: float = 6.0
@export_range(1.0, 60.0, 1.0) var reading_characters_per_second: float = 16.0
@export_range(0.2, 3.0, 0.05) var delivery_buffer_seconds: float = 1.0
@export_range(0.2, 3.0, 0.05) var delivery_confirmation_seconds: float = 0.7

var message: NetworkMessage
var phase: PresentationPhase = PresentationPhase.IDLE
var is_expanded: bool = false
var _state: int = -1
var _game_seconds: float = 0.0
var _replies: Array[MessageReply] = []
var _rows: Array[Control] = []
var _heights: Array[float] = []
var _reply_index: int = -1
var _remaining: float = 0.0
var _generation: int = 0
var _compact: bool = false
var _queue_caption: String = ""
var _column_layout: bool = false

@onready var _route: Label = %Route
@onready var _status: Label = %Status
@onready var _timing: Label = %Timing
@onready var _initial: MessagePanelBubble = %InitialMessage
@onready var _buffering: HBoxContainer = %Buffering
@onready var _deadline: Label = %Deadline
@onready var _responses: VBoxContainer = %Responses
@onready var _footer: Label = %Footer

func _ready() -> void:
	resized.connect(_layout_rows)
	_buffering.hide()
	_responses.hide()
	_footer.hide()
	if message == null:
		hide()

## Bind a new runtime message. Rebinding cancels old reveals and reading deadlines.
func bind_message(value: NetworkMessage, game_seconds: float = 0.0) -> bool:
	if not is_node_ready() or value == null or value.definition == null:
		return false
	_generation += 1
	cancel_presentation()
	_clear_rows()
	message = value
	_state = -1
	phase = PresentationPhase.IDLE
	_reply_index = -1
	_remaining = 0.0
	_initial.modulate.a = 1
	_deadline.show()
	_game_seconds = game_seconds
	for reply in message.definition.replies:
		if reply != null and not reply.text.strip_edges().is_empty():
			_replies.append(reply)
	var sender := _name_for(true)
	var recipient := _name_for(false)
	_route.text = "%s  →  %s" % [sender, recipient]
	_initial.configure(message.definition.sender, sender, message.definition.text, true)
	is_expanded = false
	_responses.hide()
	show()
	_layout_rows()
	_apply_state()
	return true

## Connect through the owner to MessageBoard.message_changed. Duplicate updates are safe.
func update_message(value: NetworkMessage, game_seconds: float = -1.0) -> void:
	if value != message:
		bind_message(value, maxf(0, game_seconds))
		return
	if game_seconds >= 0:
		_game_seconds = game_seconds
	_apply_state()

## Seconds since this game day began, matching NetworkMessage's deadline_seconds.
## Countdown is informational: only MessageBoard can expire the message.
func set_game_time(value: float) -> void:
	_game_seconds = value
	_refresh_times()

## Compact status views never run present(); the board owns the expanded playback view.
func set_compact(value: bool) -> void:
	_compact = value
	custom_minimum_size.x = 176 if value else 420
	_initial.set_compact(value)
	for edge in ["left", "top", "right", "bottom"]:
		$Margin.add_theme_constant_override("margin_" + edge, 10 if value else 16)
	$Margin/Content.add_theme_constant_override("separation", 8 if value else 12)
	$Margin/Content/Header.add_theme_constant_override("separation", 6 if value else 12)
	_route.add_theme_font_size_override("font_size", 12 if value else 15)
	_status.add_theme_font_size_override("font_size", 10 if value else 13)
	_timing.add_theme_font_size_override("font_size", 12 if value else 15)
	_deadline.add_theme_font_size_override("font_size", 12 if value else 14)
	_footer.add_theme_font_size_override("font_size", 12 if value else 16)
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Margin/Content/Buffering/LoadingBubble/Margin/Row/Waiting.visible = not value
	_refresh_times()
	_refresh_footer()
	_layout_rows()

func set_queue_caption(value: String) -> void:
	_queue_caption = value
	_refresh_footer()

## Full, untruncated text in a column the same width as an icon slot.
func set_column_layout(width: float) -> void:
	_column_layout = true
	custom_minimum_size.x = width
	size.x = width
	_initial.set_narrow(true)
	for edge in ["left", "top", "right", "bottom"]:
		$Margin.add_theme_constant_override("margin_" + edge, 10)
	$Margin/Content.add_theme_constant_override("separation", 8)
	$Margin/Content/Header.add_theme_constant_override("separation", 6)
	_route.add_theme_font_size_override("font_size", 12)
	_status.add_theme_font_size_override("font_size", 10)
	_timing.add_theme_font_size_override("font_size", 12)
	_timing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_deadline.add_theme_font_size_override("font_size", 12)
	_footer.add_theme_font_size_override("font_size", 13)
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Margin/Content/Buffering/LoadingBubble/Margin/Row/Waiting.hide()
	_layout_rows()

func needs_presentation() -> bool:
	return message != null and not message.is_open() and phase == PresentationPhase.IDLE

func is_presenting() -> bool:
	return phase in [PresentationPhase.REVEALING, PresentationPhase.BETWEEN_REPLIES, PresentationPhase.READING, PresentationPhase.INITIAL_MESSAGE, PresentationPhase.BUFFERING, PresentationPhase.DELIVERY_RESULT]

## Visual replay of an already delivered message; never delays its actual score award.
func present_delivery() -> bool:
	if not needs_presentation() or message.state != NetworkMessage.State.DELIVERED:
		return false
	is_expanded = true
	phase = PresentationPhase.INITIAL_MESSAGE
	_remaining = maxf(0.05, reveal_seconds)
	_initial.modulate.a = 0
	_buffering.hide()
	_responses.hide()
	_footer.hide()
	_deadline.hide()
	_status.text = "SENDING"
	_status.modulate = Color("f5c374")
	_refresh_times()
	presentation_started.emit()
	return true

## The future board calls this only when it grants this panel the presentation slot.
## Completed threads cannot replay unless rebound explicitly.
func present() -> bool:
	if not needs_presentation():
		return false
	var generation := _generation
	_remaining = 0.0
	is_expanded = true
	_responses.visible = message.state == NetworkMessage.State.DELIVERED and not _replies.is_empty()
	phase = PresentationPhase.READING
	presentation_started.emit()
	if generation != _generation:
		return true
	if message.state == NetworkMessage.State.DELIVERED and not _replies.is_empty():
		_begin_reply()
	else:
		_begin_reading()
	_refresh_footer()
	return true

## Collapse is explicit; this panel leaves slide-in/out and queue policy to its owner.
func collapse() -> void:
	cancel_presentation()
	is_expanded = false
	_responses.hide()

func cancel_presentation() -> void:
	if is_presenting():
		_generation += 1
		phase = PresentationPhase.COMPLETE
		presentation_cancelled.emit()

func _process(delta: float) -> void:
	advance_presentation(delta)

## Deterministic presentation time. Normal processing inherits the game's pause mode.
func advance_presentation(delta: float) -> void:
	if not is_presenting():
		return
	_remaining -= maxf(0, delta)
	var generation := _generation
	var steps := 0
	while is_presenting() and _remaining <= 0 and steps < 256:
		steps += 1
		match phase:
			PresentationPhase.INITIAL_MESSAGE:
				_initial.modulate.a = 1
				phase = PresentationPhase.BUFFERING
				_remaining += maxf(0.2, delivery_buffer_seconds)
				_buffering.show()
				_status.text = "BUFFERING"
				_refresh_times()
			PresentationPhase.BUFFERING:
				phase = PresentationPhase.DELIVERY_RESULT
				_remaining += maxf(0.2, delivery_confirmation_seconds)
				_buffering.hide()
				_footer.show()
				_status.text = "DELIVERED"
				_status.modulate = Color("9be2c2")
				_refresh_times()
				_refresh_footer()
			PresentationPhase.DELIVERY_RESULT:
				_responses.visible = not _replies.is_empty()
				if not _replies.is_empty():
					_begin_reply()
				else:
					_begin_reading()
			PresentationPhase.REVEALING:
				_set_row_progress(_reply_index, 1.0)
				reply_revealed.emit(_reply_index)
				if generation != _generation:
					return
				if _reply_index + 1 < _replies.size():
					phase = PresentationPhase.BETWEEN_REPLIES
					_remaining += maxf(0, reply_spacing_seconds)
				else:
					_begin_reading()
			PresentationPhase.BETWEEN_REPLIES:
				_begin_reply()
			PresentationPhase.READING:
				phase = PresentationPhase.COMPLETE
				ready_to_dismiss.emit()
		if generation != _generation:
			return
	if phase == PresentationPhase.REVEALING:
		_set_row_progress(_reply_index, 1.0 - _remaining / maxf(0.05, reveal_seconds))
	elif phase == PresentationPhase.INITIAL_MESSAGE:
		_initial.modulate.a = clampf(1.0 - _remaining / maxf(0.05, reveal_seconds), 0, 1)

func _apply_state() -> void:
	if message == null:
		return
	_refresh_times()
	if _state == message.state:
		_refresh_footer()
		return
	_generation += 1
	cancel_presentation()
	phase = PresentationPhase.IDLE
	_state = message.state
	_buffering.visible = _state == NetworkMessage.State.PENDING
	_footer.visible = not message.is_open()
	match message.state:
		NetworkMessage.State.UPCOMING:
			_status.text = "UPCOMING"
			_status.modulate = Color("f5c374")
		NetworkMessage.State.PENDING:
			_status.text = "BUFFERING"
			_status.modulate = Color("f5c374")
		NetworkMessage.State.DELIVERED:
			_status.text = "DELIVERED"
			_status.modulate = Color("9be2c2")
		NetworkMessage.State.EXPIRED:
			_status.text = "EXPIRED"
			_status.modulate = Color("edaaa1")
	_refresh_footer()
	if not message.is_open():
		presentation_requested.emit()

func _refresh_times() -> void:
	if message == null:
		return
	if phase in [PresentationPhase.INITIAL_MESSAGE, PresentationPhase.BUFFERING, PresentationPhase.DELIVERY_RESULT]:
		_timing.text = "Sending message" if phase == PresentationPhase.INITIAL_MESSAGE else ("Message in transit" if phase == PresentationPhase.BUFFERING else "Message delivered")
		return
	var send := message.send_text if not message.send_text.is_empty() else "—"
	var deadline := message.deadline_text if not message.deadline_text.is_empty() else "—"
	_route.text = "→ %s" % _name_for(false) if _compact else "%s  →  %s" % [_name_for(true), _name_for(false)]
	if message.state == NetworkMessage.State.UPCOMING:
		_timing.text = ("Send %s · %s" if _compact else "Sends at %s  ·  in %s") % [send, _format_duration(message.send_seconds - _game_seconds)]
	elif message.state == NetworkMessage.State.PENDING:
		_timing.text = "Waiting for a route" if _compact else "Waiting for a network route"
	else:
		_timing.text = "Sent %s" % send if _compact else "Sent at %s  ·  deadline %s" % [send, deadline]
	_deadline.text = ("By %s\n%s" if _compact else "Deliver by %s\n%s remaining") % [deadline, _format_duration(message.deadline_seconds - _game_seconds)]

func _refresh_footer() -> void:
	if message == null:
		return
	if message.state == NetworkMessage.State.DELIVERED:
		var caption := _queue_caption if not _queue_caption.is_empty() else ("Replies ready" if needs_presentation() and not _replies.is_empty() else "Delivered")
		_footer.text = "+%d · %s" % [message.score, caption] if _compact else "+%d points  ·  Delivered%s" % [message.score, "  ·  Replies ready" if needs_presentation() and not _replies.is_empty() else ""]
		_footer.modulate = Color("9be2c2")
	elif message.state == NetworkMessage.State.EXPIRED:
		_footer.text = "Expired  ·  No points awarded"
		_footer.modulate = Color("edaaa1")

func _begin_reply() -> void:
	_reply_index += 1
	var reply := _replies[_reply_index]
	var from_sender := reply.speaker == MessageReply.Speaker.SENDER
	var wrapper := Control.new()
	wrapper.clip_contents = true
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_responses.add_child(wrapper)
	var row := BubbleScene.instantiate() as MessagePanelBubble
	wrapper.add_child(row)
	row.configure(message.definition.sender if from_sender else message.definition.recipient, _name_for(from_sender), reply.text, from_sender, reply.action_before, reply.action_after)
	row.set_narrow(_column_layout)
	_rows.append(wrapper)
	_heights.append(row.measure_for_width(_content_width()))
	phase = PresentationPhase.REVEALING
	_remaining += maxf(0.05, reveal_seconds)
	_set_row_progress(_reply_index, 0)

func _begin_reading() -> void:
	phase = PresentationPhase.READING
	var characters := message.definition.text.length()
	if message.state == NetworkMessage.State.DELIVERED:
		for reply in _replies:
			characters += reply.text.length() + reply.action_before.length() + reply.action_after.length()
	_remaining += maxf(minimum_reading_seconds, characters / maxf(1, reading_characters_per_second))
	presentation_finished.emit()

func _set_row_progress(index: int, progress: float) -> void:
	var amount := smoothstep(0, 1, clampf(progress, 0, 1))
	var wrapper := _rows[index]
	wrapper.custom_minimum_size.y = _heights[index] * amount
	var row := wrapper.get_child(0) as Control
	row.modulate.a = amount
	row.position = Vector2(0, -8 * (1 - amount))

func _layout_rows() -> void:
	if not is_node_ready():
		return
	_initial.measure_for_width(_content_width())
	for index in _rows.size():
		var row := _rows[index].get_child(0) as MessagePanelBubble
		_heights[index] = row.measure_for_width(_content_width())
		if index != _reply_index or phase != PresentationPhase.REVEALING:
			_set_row_progress(index, 1)
		else:
			_set_row_progress(index, 1.0 - _remaining / maxf(0.05, reveal_seconds))

func _clear_rows() -> void:
	for row in _rows:
		row.get_parent().remove_child(row)
		row.queue_free()
	_rows.clear()
	_heights.clear()
	_replies.clear()

func _content_width() -> float:
	return maxf(100 if _compact or _column_layout else 160, size.x - (20 if _compact or _column_layout else 32))

func _name_for(sender: bool) -> String:
	var profile := message.definition.sender if sender else message.definition.recipient
	if profile != null and not profile.display_name.is_empty():
		return profile.display_name
	var fallback := message.from_label if sender else message.to_label
	if not fallback.is_empty():
		return fallback
	return "Sender" if sender else "Recipient"

static func _format_duration(seconds: float) -> String:
	var total := maxi(0, ceili(seconds))
	if total >= 3600:
		return "%02d:%02d:%02d" % [total / 3600, (total % 3600) / 60, total % 60]
	return "%02d:%02d" % [total / 60, total % 60]
