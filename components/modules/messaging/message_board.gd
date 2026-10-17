class_name MessageBoard
extends Node
## Tracks scheduled messages after DayCycleManager announces them: warning, delivery,
## late delivery once the route is repaired, expiry, and score. One per level.
signal message_changed(message: NetworkMessage)
signal score_changed(total: int, delta: int)

const WARNING_KEYWORD := &"message_warning"
@export var scoring_rule: MessageScoringRule
var total_score: int = 0
var _graph: SignalNetworkGraph
var _clock: DayCycleManager
var _messages: Array[NetworkMessage] = []

## Copy of source with a WARNING_KEYWORD entry added before every MessageNotification.
## Warnings that would fall before the day starts fire at the start instead.
static func build_schedule(source: DayCycleSchedule, clock: DayCycleManager) -> DayCycleSchedule:
	var result := DayCycleSchedule.new()
	if source == null:
		return result
	var start := clock.get_day_start_seconds()
	for entry in source.notifications:
		var message := entry as MessageNotification
		if message == null:
			continue
		var send := message.get_game_seconds(clock.real_seconds_per_day, start, clock.get_game_seconds_per_day())
		var at := fposmod(maxf(send - message.warning_minutes * 60.0, start), DayCycleManager.GAME_DAY_SECONDS)
		var warning := DayCycleNotification.new()
		warning.keyword = WARNING_KEYWORD
		warning.values = {"message": message}
		warning.time_basis = DayCycleNotification.TimeBasis.GAME_CLOCK
		warning.hour = int(at / 3600.0)
		warning.minute = int(fposmod(at, 3600.0) / 60.0)
		warning.second = fposmod(at, 60.0)
		warning.fire_on_skip = message.fire_on_skip
		result.notifications.append(warning)
	# Warnings go first so a zero-minute warning still precedes its message.
	result.notifications.append_array(source.notifications)
	return result

func setup(graph: SignalNetworkGraph, clock: DayCycleManager) -> void:
	_graph = graph
	_clock = clock
	if scoring_rule == null:
		scoring_rule = MessageScoringRule.new()
	_graph.connectivity_changed.connect(_on_connectivity_changed)
	_clock.time_changed.connect(_on_time_changed)

func get_messages() -> Array[NetworkMessage]:
	return _messages.duplicate()

func announce(definition: MessageNotification) -> void:
	var message := _get_or_create(definition)
	if message.state == NetworkMessage.State.UPCOMING:
		message_changed.emit(message)

## The sender transmits now: delivered at full score if the houses are connected, otherwise
## pending until a route appears or the deadline passes.
func transmit(definition: MessageNotification) -> void:
	var message := _get_or_create(definition)
	if message.state != NetworkMessage.State.UPCOMING:
		return
	_set_times(message, _clock.get_elapsed_game_seconds())
	message.state = NetworkMessage.State.PENDING
	if not _try_deliver(message):
		message_changed.emit(message)

## Every message still upcoming or pending expires, e.g. when the day ends.
func expire_open() -> void:
	for message in _messages:
		if message.is_open():
			_expire(message)

func fill_report(report: DayReport) -> void:
	report.score = total_score
	for message in _messages:
		if message.state == NetworkMessage.State.EXPIRED:
			report.expired += 1
		elif message.is_on_time():
			report.delivered_on_time += 1
		elif message.state == NetworkMessage.State.DELIVERED:
			report.delivered_late += 1

func _get_or_create(definition: MessageNotification) -> NetworkMessage:
	for message in _messages:
		if message.definition == definition:
			return message
	var message := NetworkMessage.new()
	message.definition = definition
	# Lookups log their own errors; unknown houses simply never connect.
	if definition.route != MessageNotification.Route.FROM_INTERNET:
		message.from_house = _graph.get_house_by_key(definition.from_house)
	if definition.route != MessageNotification.Route.TO_INTERNET:
		message.to_house = _graph.get_house_by_key(definition.to_house)
	message.from_label = message.from_house.get_label() if message.from_house != null else str(definition.from_house)
	message.to_label = message.to_house.get_label() if message.to_house != null else str(definition.to_house)
	if definition.route == MessageNotification.Route.FROM_INTERNET:
		message.from_label = definition.sender.display_name if definition.sender != null else "Internet"
	elif definition.route == MessageNotification.Route.TO_INTERNET:
		message.to_label = definition.recipient.display_name if definition.recipient != null else "Internet"
	var send_clock := definition.get_game_seconds(_clock.real_seconds_per_day, _clock.get_day_start_seconds(), _clock.get_game_seconds_per_day())
	_set_times(message, send_clock - _clock.get_day_start_seconds())
	_messages.append(message)
	return message

func _set_times(message: NetworkMessage, send_seconds: float) -> void:
	message.send_seconds = send_seconds
	message.deadline_seconds = minf(send_seconds + message.definition.expire_minutes * 60.0, _clock.get_game_seconds_per_day())
	message.send_text = _format_clock(message.send_seconds)
	message.deadline_text = _format_clock(message.deadline_seconds)

func _try_deliver(message: NetworkMessage) -> bool:
	if message.state != NetworkMessage.State.PENDING:
		return false
	if not _has_delivery_route(message):
		return false
	# A lazy graph rebuild may already have delivered this through connectivity_changed.
	if message.state != NetworkMessage.State.PENDING:
		return message.state == NetworkMessage.State.DELIVERED
	var now := _clock.get_elapsed_game_seconds()
	message.delivered_seconds = now
	message.score = scoring_rule.score(message.definition.points, (now - message.send_seconds) / 60.0, message.definition.expire_minutes)
	message.state = NetworkMessage.State.DELIVERED
	total_score += message.score
	message_changed.emit(message)
	score_changed.emit(total_score, message.score)
	return true

func _has_delivery_route(message: NetworkMessage) -> bool:
	if message.definition.route == MessageNotification.Route.HOUSE_TO_HOUSE:
		return message.from_house != null and message.to_house != null and _graph.are_houses_connected(message.from_house, message.to_house)
	var outbound := message.definition.route == MessageNotification.Route.TO_INTERNET
	var local_house := message.from_house if outbound else message.to_house
	if local_house == null:
		return false
	for vertex in _graph.get_vertices():
		var gateway := vertex as SignalNetworkHouse
		if gateway != null and gateway.is_internet_gateway() and _graph.are_houses_connected(local_house, gateway):
			if outbound:
				message.to_house = gateway
			else:
				message.from_house = gateway
			return true
	return false

func _expire(message: NetworkMessage) -> void:
	message.state = NetworkMessage.State.EXPIRED
	message.score = 0
	message_changed.emit(message)

func _on_connectivity_changed(_connected_pairs: int, _total_pairs: int) -> void:
	for message in _messages:
		_try_deliver(message)

func _on_time_changed(_day: int, _game_seconds: float) -> void:
	var now := _clock.get_elapsed_game_seconds()
	for message in _messages:
		if message.state == NetworkMessage.State.PENDING and now >= message.deadline_seconds:
			_expire(message)

func _format_clock(elapsed_seconds: float) -> String:
	var seconds := int(fposmod(_clock.get_day_start_seconds() + elapsed_seconds, DayCycleManager.GAME_DAY_SECONDS))
	return "%02d:%02d" % [seconds / 3600, (seconds % 3600) / 60]
