extends HudWidget
## Today's messages: upcoming warnings, pending deliveries (kept until delivered or expired),
## and resolved outcomes, which linger briefly before disappearing.
@export var resolved_linger_seconds: float = 4.0
@export var upcoming_color: Color = Color(0.95, 0.85, 0.4)
@export var pending_color: Color = Color(1.0, 0.45, 0.35)
@export var delivered_color: Color = Color(0.45, 0.9, 0.5)
@export var expired_color: Color = Color(0.6, 0.6, 0.6)
var _cards: Dictionary = {}

func update_message(message: NetworkMessage) -> void:
	var card: PanelContainer = _cards.get(message)
	if card == null:
		card = _make_card()
		add_child(card)
		_cards[message] = card
	var label := card.get_child(0) as Label
	label.text = _describe(message)
	label.add_theme_color_override(&"font_color", _color_for(message.state))
	if not message.is_open():
		get_tree().create_timer(resolved_linger_seconds, false).timeout.connect(_remove.bind(message))

func apply_snapshot(snapshot: Dictionary) -> void:
	for message: NetworkMessage in snapshot.get("messages", []):
		if message.is_open():
			update_message(message)

func reset() -> void:
	for card in _cards.values():
		card.queue_free()
	_cards.clear()

func _remove(message: NetworkMessage) -> void:
	var card: PanelContainer = _cards.get(message)
	if card != null:
		card.queue_free()
		_cards.erase(message)

func _make_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(label)
	return card

func _describe(message: NetworkMessage) -> String:
	var route := "%s -> %s" % [message.from_label, message.to_label]
	match message.state:
		NetworkMessage.State.UPCOMING:
			var text := message.definition.text
			return "%s\nSends at %s, deliver by %s%s" % [route, message.send_text, message.deadline_text, "" if text.is_empty() else "\n\"%s\"" % text]
		NetworkMessage.State.PENDING:
			return "%s\nNo route! Deliver by %s" % [route, message.deadline_text]
		NetworkMessage.State.DELIVERED:
			return "%s\nDelivered  +%d" % [route, message.score]
	return "%s\nExpired" % route

func _color_for(state: NetworkMessage.State) -> Color:
	match state:
		NetworkMessage.State.UPCOMING:
			return upcoming_color
		NetworkMessage.State.PENDING:
			return pending_color
		NetworkMessage.State.DELIVERED:
			return delivered_color
	return expired_color
