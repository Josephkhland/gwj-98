class_name RandomMessageGenerator
extends Node
## Optional work-shift mail. Uses the same board entry points as scheduled mail.
signal message_generated(message: MessageNotification)

@export var enabled: bool = true
## Defaults to the enclosing GameLevel and its modules.
@export var level: GameLevel
@export var network_graph: SignalNetworkGraph
@export var day_cycle: DayCycleManager
@export var message_board: MessageBoard
@export_group("Pacing (game minutes)")
## First announcement is one interval after clock-in; no messages outside the shift.
@export_range(1.0, 720.0, 1.0, "or_greater") var interval_minutes: float = 60.0
@export_range(0.0, 720.0, 1.0, "or_greater") var warning_minutes: float = 30.0
## Time after transmission, capped by the end of the day like scheduled messages.
@export_range(1.0, 1440.0, 1.0, "or_greater") var expiration_minutes: float = 60.0
@export_range(0, 10000, 10, "or_greater") var points: int = 100
@export_group("Content")
## Only profiles with a house in this graph participate. Empty allows all local profiles.
@export var participants: Array[CharacterProfile] = []
@export var topics: Array[RandomMessageTopic] = _default_topics()

var _active: bool = false
var _next_announcement: float = INF
var _pending: Array[Dictionary] = []
var _serial: int = 0
var _rng := RandomNumberGenerator.new()

static func _default_topics() -> Array[RandomMessageTopic]:
	var result: Array[RandomMessageTopic] = []
	for title in [
		"Tea, no prophecies",
		"Foxlist: slightly haunted kettle",
		"Sandwich inspection",
		"Silkworm on the loose",
		"Suspiciously good weather",
		"Whose scarf is this?",
		"Please stop forwarding this",
		"Router teeth marks",
		"A very local delivery",
		"Refund in store credit",
		"Bring an umbrella",
		"Borrowing a screwdriver",
		"The stars are buffering",
		"Community picnic",
		"Premium invisible parcel",
		"Tiny woolly traffic jam",
		"Strange noises outside",
		"Password advice",
		"Too much pie",
		"See you after the shift"
	]:
		var topic := RandomMessageTopic.new()
		topic.title = title
		result.append(topic)
	return result

func _ready() -> void:
	_rng.randomize()
	if level == null:
		var ancestor := get_parent()
		while ancestor != null:
			if ancestor is GameLevel:
				level = ancestor
				break
			ancestor = ancestor.get_parent()
	_bind_level.call_deferred()

func _bind_level() -> void:
	if level != null:
		if network_graph == null:
			network_graph = level.network_graph
		if day_cycle == null:
			day_cycle = level.day_cycle
		if message_board == null:
			message_board = level.message_board
	if level == null or network_graph == null or day_cycle == null or message_board == null:
		push_warning("RandomMessageGenerator needs a GameLevel, NetworkGraph, DayCycleManager and MessageBoard.")
		return
	level.phase_changed.connect(_on_phase_changed)
	day_cycle.time_changed.connect(_on_time_changed)
	_on_phase_changed(level.phase)

func _on_phase_changed(phase: GameLevel.Phase) -> void:
	if phase != GameLevel.Phase.ON_SHIFT:
		_active = false
		_pending.clear()
		return
	if not _active:
		_active = true
		_next_announcement = day_cycle.get_elapsed_game_seconds() + maxf(1.0, interval_minutes) * 60.0

func _on_time_changed(_day: int, _seconds: float) -> void:
	if not _active or level.phase != GameLevel.Phase.ON_SHIFT:
		return
	var now := day_cycle.get_elapsed_game_seconds()
	# Disabling generation still lets already announced mail transmit normally.
	for index in range(_pending.size() - 1, -1, -1):
		if now >= float(_pending[index].send_at):
			var message: MessageNotification = _pending[index].message
			_pending.remove_at(index)
			message_board.transmit(message)
	if now < _next_announcement:
		return
	# Clock skips make at most one new announcement, without a burst of backlog mail.
	_next_announcement = now + maxf(1.0, interval_minutes) * 60.0
	if enabled:
		_generate_message(now)

func _generate_message(now: float) -> void:
	var houses: Array[SignalNetworkHouse] = []
	var identities: Array[StringName] = []
	for vertex in network_graph.get_vertices():
		var house := vertex as SignalNetworkHouse
		if house == null or house.is_internet_gateway() or house.key_identifier == &"" or house.character_profile == null:
			continue
		var profile := house.character_profile
		if not participants.is_empty() and profile not in participants:
			continue
		if profile.character_id in identities:
			continue
		identities.append(profile.character_id)
		houses.append(house)
	var available: Array[RandomMessageTopic] = []
	for topic in topics:
		if topic != null and not topic.title.strip_edges().is_empty():
			available.append(topic)
	var send_at := now + maxf(0.0, warning_minutes) * 60.0
	# Avoid announcing mail that will never get a turn before the shift finishes.
	if houses.size() < 2 or available.is_empty() or send_at >= day_cycle.get_game_seconds_per_day():
		return
	var sender_index := _rng.randi_range(0, houses.size() - 1)
	var recipient_index := _rng.randi_range(0, houses.size() - 2)
	if recipient_index >= sender_index:
		recipient_index += 1
	var sender := houses[sender_index]
	var recipient := houses[recipient_index]
	var topic := available[_rng.randi_range(0, available.size() - 1)]
	var message := MessageNotification.new()
	_serial += 1
	message.message_id = StringName("random_%s_%s" % [get_instance_id(), _serial])
	message.from_house = sender.key_identifier
	message.to_house = recipient.key_identifier
	message.sender = sender.character_profile
	message.recipient = recipient.character_profile
	var names := {"sender": message.sender.display_name, "recipient": message.recipient.display_name}
	message.title = topic.title.format(names)
	message.text = "+%d points" % points
	message.points = points
	message.fixed_score = true
	message.warning_minutes = warning_minutes
	message.expire_minutes = expiration_minutes
	message.time_basis = DayCycleNotification.TimeBasis.GAME_CLOCK
	var clock_time := fposmod(day_cycle.get_day_start_seconds() + send_at, DayCycleManager.GAME_DAY_SECONDS)
	message.hour = int(clock_time / 3600.0)
	message.minute = int(fposmod(clock_time, 3600.0) / 60.0)
	message.second = fposmod(clock_time, 60.0)
	message_board.announce(message)
	message_generated.emit(message)
	if warning_minutes <= 0.0:
		message_board.transmit(message)
	else:
		_pending.append({"message": message, "send_at": send_at})
