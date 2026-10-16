class_name MessageFeedWidget
extends HudWidget
## One presentation column on the left; compact icon slots wait in a grid to its right.
signal thread_started(message: NetworkMessage)
signal thread_finished(message: NetworkMessage)
enum Stage { IDLE, TRANSFERRING, ENTERING, PRESENTING, LEAVING }
const RibbonScene := preload("res://components/ui/gameplay_ui/widgets/message_feed/MessageRibbonEntry.tscn")
const Ribbon = preload("res://components/ui/gameplay_ui/widgets/message_feed/message_ribbon_entry.gd")
@export_range(200, 320, 1) var slot_width: float = 220
@export_range(1, 3, 0.1) var presentation_width_multiplier: float = 2
@export_range(60, 90, 1) var slot_height: float = 64
@export_range(1, 5, 1) var pending_max_rows: int = 3
@export_range(1, 6, 0.1) var failure_linger_seconds: float = 2.5
@export_range(0.05, 1, 0.05) var slide_seconds: float = 0.3
@export_range(0.2, 2, 0.05) var transfer_seconds: float = 0.7
@export_range(0, 60, 0.5) var minimum_reading_seconds: float = 6
@export_range(0, 10, 0.1) var reply_spacing_seconds: float = 1.5
@export_range(1, 60, 1) var reading_characters_per_second: float = 16
var _cards: Dictionary = {}
var _retired: Dictionary = {}
var _queue: Array[NetworkMessage] = []
var _active: NetworkMessage
var _stage: Stage = Stage.IDLE
var _stage_elapsed: float = 0
var _game_seconds: float = 0
var _clock: DayCycleManager
var _layout_dirty: bool = true
var _next_order: int = 0
var _expansion_elapsed: float = 0
var _moving_ribbon: Ribbon
var _transfer_origin: Vector2
var _transfer_size: Vector2
@onready var _overview_scroll: ScrollContainer = %OverviewScroll
@onready var _overview: GridContainer = %Overview
@onready var _presentation_column: VBoxContainer = %PresentationColumn
@onready var _active_ribbon: Ribbon = %ActiveRibbon
@onready var _detail_slot: Control = %DetailSlot
@onready var _detail_scroll: ScrollContainer = %DetailScroll
@onready var _detail: MessagePanel = %Conversation
@onready var _layout_root: HBoxContainer = $Layout

func _ready() -> void:
	resized.connect(_request_layout)
	_overview.minimum_size_changed.connect(_request_layout)
	_detail.minimum_size_changed.connect(_request_layout)
	# Drive only this panel from the manager, so hiding the HUD freezes reading/reveals.
	_detail.set_process(false)
	_detail.set_column_layout(_presentation_width() - 14)
	_detail.ready_to_dismiss.connect(_start_exit)
	_detail.reply_revealed.connect(func(_index): _scroll_to_latest.call_deferred())
	_detail_slot.hide()
	_refresh_summary()

func update_message(message: NetworkMessage) -> void:
	if message == null or message.definition == null or _retired.has(message):
		return
	if is_instance_valid(_clock):
		_game_seconds = _clock.get_elapsed_game_seconds()
	if not _cards.has(message):
		var wrapper := Control.new()
		wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overview.add_child(wrapper)
		var card := RibbonScene.instantiate() as Ribbon
		wrapper.add_child(card)
		card.modulate.a = 0
		_cards[message] = {"wrapper": wrapper, "panel": card, "age": 0.0, "order": _next_order, "state": message.state, "failure_age": 0.0}
		_next_order += 1
		card.minimum_size_changed.connect(_request_layout)
		card.bind_message(message, _game_seconds)
	else:
		var card: Ribbon = _cards[message].panel
		card.update_message(message, _game_seconds)
		if _cards[message].state != message.state:
			_cards[message].state = message.state
			_cards[message].failure_age = 0.0
	if message.state == NetworkMessage.State.DELIVERED:
		_enqueue(message)
	elif message.state == NetworkMessage.State.EXPIRED:
		_queue.erase(message)
	if _active == message:
		_detail.update_message(message, _game_seconds)
		_active_ribbon.update_message(message, _game_seconds)
	_sort_cards()
	_request_layout()
	_refresh_summary()

func apply_snapshot(snapshot: Dictionary) -> void:
	_clock = snapshot.get("day_cycle") as DayCycleManager
	set_game_time(snapshot.get("game_seconds", _clock.get_elapsed_game_seconds() if is_instance_valid(_clock) else 0.0))
	# Include resolved messages: they may have delivered before this HUD was connected.
	for message: NetworkMessage in snapshot.get("messages", []):
		update_message(message)

func set_game_time(seconds: float) -> void:
	_game_seconds = seconds
	for entry in _cards.values():
		entry.panel.set_game_time(seconds)
	if _active != null:
		_detail.set_game_time(seconds)
		_active_ribbon.set_game_time(seconds)
	if is_instance_valid(_moving_ribbon):
		_moving_ribbon.set_game_time(seconds)

func reset() -> void:
	_clear_transfer()
	_clock = null
	_queue.clear()
	_active = null
	_stage = Stage.IDLE
	_stage_elapsed = 0
	_game_seconds = 0
	_next_order = 0
	_detail.collapse()
	_detail_slot.hide()
	_presentation_column.hide()
	for entry in _cards.values():
		_overview.remove_child(entry.wrapper)
		entry.wrapper.queue_free()
	_cards.clear()
	_retired.clear()
	_refresh_summary()
	_request_layout()

func get_active_message() -> NetworkMessage:
	return _active

func get_ribbon_entry(message: NetworkMessage) -> Ribbon:
	return _cards[message].panel if _cards.has(message) else null

func get_waiting_count() -> int:
	return _queue.size()

func _process(delta: float) -> void:
	advance_feed(delta)

## Deterministic UI time; no timers can outlive reset or remove the wrong level's cards.
func advance_feed(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if is_instance_valid(_clock):
		set_game_time(_clock.get_elapsed_game_seconds())
	var expired_to_remove: Array[NetworkMessage] = []
	for message in _cards:
		var entry: Dictionary = _cards[message]
		entry.age += maxf(0, delta)
		var amount := smoothstep(0, 1, minf(1, entry.age / maxf(0.05, slide_seconds)))
		if message == _active and _stage == Stage.LEAVING:
			amount = 1 - smoothstep(0, 1, minf(1, _stage_elapsed / maxf(0.05, slide_seconds)))
		var card: Ribbon = entry.panel
		card.advance_visual(delta)
		if message.state == NetworkMessage.State.EXPIRED:
			entry.failure_age += maxf(0, delta)
			amount *= 1 - clampf((entry.failure_age - failure_linger_seconds) / maxf(0.05, slide_seconds), 0, 1)
			if entry.failure_age >= failure_linger_seconds + slide_seconds:
				expired_to_remove.append(message)
		card.modulate.a = amount
		card.position = Vector2(0, -10 * (1 - amount))
	if _active == null:
		_start_next()
	if _active != null and _stage != Stage.TRANSFERRING:
		_active_ribbon.advance_visual(delta)
	match _stage:
		Stage.TRANSFERRING:
			_stage_elapsed += maxf(0, delta)
			var progress := clampf(_stage_elapsed / transfer_seconds, 0, 1)
			var eased := smoothstep(0, 1, progress)
			var destination := get_global_transform().affine_inverse() * _active_ribbon.global_position
			_moving_ribbon.position = _transfer_origin.lerp(destination, eased) - Vector2(0, sin(progress * PI) * 12)
			_moving_ribbon.size = _transfer_size.lerp(Vector2(_presentation_width(), slot_height), eased)
			_moving_ribbon.advance_visual(delta)
			if progress >= 1:
				_clear_transfer()
				_active_ribbon.modulate.a = 1
				_active_ribbon.begin_presentation()
				_stage = Stage.ENTERING
				_stage_elapsed = 0
		Stage.ENTERING:
			_stage_elapsed += maxf(0, delta)
			if _active_ribbon.document_is_visible():
				_stage = Stage.PRESENTING
				_expansion_elapsed = 0
				_detail_slot.show()
				_request_layout()
				if _detail.present_delivery():
					thread_started.emit(_active)
				else:
					_start_exit()
		Stage.PRESENTING:
			_expansion_elapsed += maxf(0, delta)
			if _expansion_elapsed <= _detail.reveal_seconds + delta:
				_request_layout()
			_detail.advance_presentation(delta)
		Stage.LEAVING:
			_stage_elapsed += maxf(0, delta)
			_set_detail_progress(1 - _stage_elapsed / maxf(0.05, slide_seconds))
			if _stage_elapsed >= slide_seconds:
				_finish_active()
	for message in expired_to_remove:
		_remove_entry(message)
	if not expired_to_remove.is_empty():
		_refresh_summary()
		_request_layout()
	if _layout_dirty:
		_refresh_layout()

func _enqueue(message: NetworkMessage) -> void:
	if _retired.has(message) or _active == message or _queue.has(message):
		return
	_queue.append(message)
	_refresh_summary()

func _start_next() -> void:
	while not _queue.is_empty():
		var message: NetworkMessage = _queue.pop_front()
		if not _cards.has(message) or _retired.has(message) or message.state != NetworkMessage.State.DELIVERED:
			continue
		_active = message
		_stage = Stage.TRANSFERRING
		_stage_elapsed = 0
		_detail.minimum_reading_seconds = minimum_reading_seconds
		_detail.reply_spacing_seconds = reply_spacing_seconds
		_detail.reading_characters_per_second = reading_characters_per_second
		_detail.set_column_layout(_presentation_width() - 14)
		_detail.bind_message(message, _game_seconds)
		_active_ribbon.bind_message(message, _game_seconds)
		_active_ribbon.modulate.a = 0
		var source: Ribbon = _cards[message].panel
		_transfer_origin = get_global_transform().affine_inverse() * source.global_position
		_transfer_size = source.size
		_moving_ribbon = RibbonScene.instantiate() as Ribbon
		add_child(_moving_ribbon)
		_moving_ribbon.z_index = 100
		_moving_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_moving_ribbon.bind_message(message, _game_seconds)
		_moving_ribbon.highlighted = true
		_moving_ribbon._elapsed = source._elapsed
		_moving_ribbon.position = _transfer_origin
		_moving_ribbon.size = _transfer_size
		_moving_ribbon.advance_visual(0)
		# The expanded panel replaces its ribbon entry instead of duplicating it.
		_cards[message].wrapper.hide()
		_presentation_column.show()
		_detail_slot.hide()
		_detail_scroll.scroll_vertical = 0
		_set_detail_progress(1)
		_refresh_summary()
		_request_layout()
		return

func _clear_transfer() -> void:
	if is_instance_valid(_moving_ribbon):
		_moving_ribbon.hide()
		_moving_ribbon.queue_free()
	_moving_ribbon = null

func _start_exit() -> void:
	if _active == null:
		return
	_stage = Stage.LEAVING
	_stage_elapsed = 0

func _finish_active() -> void:
	var completed := _active
	_detail.collapse()
	_detail_slot.hide()
	_remove_entry(completed)
	_active = null
	_stage = Stage.IDLE
	_refresh_summary()
	_request_layout()
	thread_finished.emit(completed)

func _set_detail_progress(progress: float) -> void:
	var amount := smoothstep(0, 1, clampf(progress, 0, 1))
	_presentation_column.modulate.a = amount
	_detail_scroll.position.y = -12 * (1 - amount)

func _remove_entry(message: NetworkMessage) -> void:
	if _cards.has(message):
		var wrapper: Control = _cards[message].wrapper
		_overview.remove_child(wrapper)
		wrapper.queue_free()
		_cards.erase(message)
	_queue.erase(message)
	_retired[message] = true

func _refresh_summary() -> void:
	if not is_node_ready():
		return
	_overview_scroll.visible = _cards.size() > (1 if _active != null else 0)
	_presentation_column.visible = _active != null

func _request_layout() -> void:
	_layout_dirty = true

func _presentation_width() -> float:
	# Leave room for at least one pending slot on smaller viewports.
	return clampf(slot_width * presentation_width_multiplier, slot_width, maxf(slot_width, size.x - slot_width - 24))

func _refresh_layout() -> void:
	_layout_dirty = false
	_layout_root.size.x = size.x
	var width := slot_width
	for entry in _cards.values():
		var card: Ribbon = entry.panel
		card.custom_minimum_size.x = width
		card.size.x = width
		card.custom_minimum_size.y = slot_height
		card.size.y = slot_height
		entry.wrapper.custom_minimum_size = card.size
	var presentation_width := _presentation_width()
	_presentation_column.custom_minimum_size.x = presentation_width
	_active_ribbon.custom_minimum_size = Vector2(presentation_width, slot_height)
	_active_ribbon.size = Vector2(presentation_width, slot_height)
	if not is_equal_approx(_detail.custom_minimum_size.x, presentation_width - 14):
		_detail.set_column_layout(presentation_width - 14)
	var pending_width := maxf(width, size.x - (presentation_width + 8 if _active != null else 0))
	_overview.columns = maxi(1, int(floor((pending_width - 16 + 8) / (width + 8))))
	_overview_scroll.custom_minimum_size.y = minf(pending_max_rows * (slot_height + 8) - 8, _overview.get_combined_minimum_size().y)
	var available_height := maxf(120, get_viewport_rect().size.y - global_position.y - slot_height - 48)
	var expand := clampf(_expansion_elapsed / maxf(0.05, _detail.reveal_seconds), 0, 1) if _stage == Stage.PRESENTING else 1.0
	_detail_slot.custom_minimum_size.y = minf(available_height, _detail.get_combined_minimum_size().y) * smoothstep(0, 1, expand)
	_detail_scroll.size = Vector2(presentation_width, _detail_slot.custom_minimum_size.y)
	offset_bottom = offset_top + _layout_root.get_combined_minimum_size().y

func _scroll_to_latest() -> void:
	if _active != null:
		_detail_scroll.scroll_vertical = int(_detail_scroll.get_v_scroll_bar().max_value)

func _sort_cards() -> void:
	# Keep urgent undelivered work ahead of resolved conversations awaiting their turn.
	var messages := _cards.keys()
	messages.sort_custom(func(a: NetworkMessage, b: NetworkMessage) -> bool:
		var priority_a := 0 if a.state == NetworkMessage.State.PENDING else (1 if a.state == NetworkMessage.State.UPCOMING else 2)
		var priority_b := 0 if b.state == NetworkMessage.State.PENDING else (1 if b.state == NetworkMessage.State.UPCOMING else 2)
		if priority_a != priority_b:
			return priority_a < priority_b
		var time_a := a.deadline_seconds if priority_a == 0 else a.send_seconds
		var time_b := b.deadline_seconds if priority_b == 0 else b.send_seconds
		if not is_equal_approx(time_a, time_b):
			return time_a < time_b
		return _cards[a].order < _cards[b].order)
	for index in messages.size():
		_overview.move_child(_cards[messages[index]].wrapper, index)
