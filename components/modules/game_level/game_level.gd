class_name GameLevel
extends Node2D
## Base script for a playable day. Owns the day's rules (clock-in, shift, bed) and turns
## module signals into a few gameplay signals for whoever runs the level (GameOrchestrator).
## Running the scene directly (F6) begins the day by itself.

enum Phase { WAKING, ON_SHIFT, AFTER_HOURS, COMPLETED }

signal phase_changed(phase: Phase)
signal prompt_changed(text: String)
signal clock_changed(time_text: String, shift_end_text: String, progress: float)
signal score_changed(total: int, delta: int)
signal message_changed(message: NetworkMessage)
## The host must open router.minigame_scene and call router.resolve_repair(success).
signal minigame_requested(router: SignalNetworkRouter)
signal level_completed(report: DayReport)

const MARKER_BED := &"bed"
const MARKER_CLOCK_IN := &"clock_in"

@export var level_title: String = ""
@export_group("Prompts")
@export var waking_prompt: String = "Head outside and clock in."
@export var on_shift_prompt: String = ""
@export var after_hours_prompt: String = "Shift's over. Head home to bed."
@export_group("Nodes (default to conventional child names)")
@export var day_cycle: DayCycleManager
@export var lighting: DayCycleLighting2D
@export var network_graph: SignalNetworkGraph
@export var message_board: MessageBoard
@export var player: CharacterBody2D
@export var player_spawn: Marker2D
@export var bed: InteractionZone
@export var clock_in_point: InteractionZone
@export var music_manager: MusicManager

var phase: Phase = Phase.WAKING
var routers_repaired: int = 0
var _handlers: Dictionary[StringName, Callable] = {}
var _begun: bool = false
var _clock_text: String = ""
var _minimap_feed: MinimapFeed

func _ready() -> void:
	if music_manager == null:
		music_manager = get_node_or_null(^"MusicManager") as MusicManager
	if music_manager == null:
		music_manager = MusicManager.new()
		music_manager.name = "MusicManager"
		add_child(music_manager)
	if not _resolve_nodes():
		return
	register_handler(&"sunrise", _on_sunrise)
	register_handler(&"sunset", _on_sunset)
	register_handler(&"lighting", _on_lighting)
	register_handler(MessageBoard.WARNING_KEYWORD, _on_message_warning)
	register_handler(MessageNotification.KEYWORD, _on_message_transmit)
	register_handler(&"router_break", _on_router_break)
	_setup_clock()
	message_board.setup(network_graph, day_cycle)
	message_board.message_changed.connect(message_changed.emit)
	message_board.score_changed.connect(score_changed.emit)
	for router in _get_routers():
		router.repair_finished.connect(_on_repair_finished)
	clock_in_point.interacted.connect(_on_clock_in)
	bed.interacted.connect(_on_bed_used)
	if player_spawn != null:
		player.global_position = player_spawn.global_position
	_refresh_zones()
	if get_tree().current_scene == self:
		begin.call_deferred()

## Starts the day in the WAKING phase. Call after connecting to this level's signals.
func begin() -> void:
	if _begun:
		return
	_begun = true
	# Hand repairs to a host only if one listens; otherwise routers open their own minigame.
	if not minigame_requested.get_connections().is_empty():
		for router in _get_routers():
			router.repair_requested.connect(_on_repair_requested.bind(router))
	_set_phase(Phase.WAKING)

## Subclasses add or replace day-cycle notification handlers; values is the notification payload.
func register_handler(keyword: StringName, handler: Callable) -> void:
	_handlers[keyword] = handler

## Optional clock/music override for full-tree pauses; repairs leave the tree running.
func set_clock_runs_while_paused(runs: bool) -> void:
	day_cycle.process_mode = Node.PROCESS_MODE_ALWAYS if runs else Node.PROCESS_MODE_INHERIT
	if music_manager != null:
		music_manager.process_mode = day_cycle.process_mode

func get_player() -> CharacterBody2D:
	return player

func get_prompt() -> String:
	match phase:
		Phase.WAKING:
			return waking_prompt
		Phase.ON_SHIFT:
			return on_shift_prompt
		Phase.AFTER_HOURS:
			return after_hours_prompt
	return ""

func get_clock_text() -> String:
	var clock := day_cycle.get_time()
	return "%02d:%02d" % [clock.hour, clock.minute]

func get_shift_end_text() -> String:
	return day_cycle.day_end_time.substr(0, 5)

## Everything the HUD needs on its first frame; signals carry later changes.
func get_hud_snapshot() -> Dictionary:
	return {
		"title": level_title,
		"phase": phase,
		"prompt": get_prompt(),
		"time": get_clock_text(),
		"game_seconds": day_cycle.get_elapsed_game_seconds(),
		"day_cycle": day_cycle,
		"shift_end": get_shift_end_text(),
		"progress": day_cycle.get_day_progress(),
		"score": message_board.total_score,
		"messages": message_board.get_messages(),
		"minimap": get_minimap_feed(),
		"player": player,
	}

func get_minimap_feed() -> MinimapFeed:
	if _minimap_feed == null:
		_minimap_feed = MinimapFeed.new()
		_minimap_feed.player = player
		_minimap_feed.network_graph = network_graph
		_minimap_feed.markers[MARKER_BED] = bed
		_minimap_feed.markers[MARKER_CLOCK_IN] = clock_in_point
		_collect_solids(self, _minimap_feed.solids)
	return _minimap_feed

func build_report() -> DayReport:
	var report := DayReport.new()
	report.title = level_title
	report.routers_repaired = routers_repaired
	message_board.fill_report(report)
	return report

func _resolve_nodes() -> bool:
	# Fall back to conventional node names so levels only set non-standard paths.
	if day_cycle == null:
		day_cycle = get_node_or_null(^"DayCycleManager") as DayCycleManager
	if lighting == null:
		lighting = get_node_or_null(^"DayCycleLighting2D") as DayCycleLighting2D
	if network_graph == null:
		network_graph = get_node_or_null(^"NetworkGraph") as SignalNetworkGraph
	if message_board == null:
		message_board = get_node_or_null(^"MessageBoard") as MessageBoard
	if player == null:
		player = get_node_or_null(^"PlatformerCharacter") as CharacterBody2D
	if player_spawn == null:
		player_spawn = get_node_or_null(^"PlayerSpawn") as Marker2D
	if bed == null:
		bed = get_node_or_null(^"Bed") as InteractionZone
	if clock_in_point == null:
		clock_in_point = get_node_or_null(^"ClockInPoint") as InteractionZone
	var missing: Array[String] = []
	for entry in [["day_cycle", day_cycle], ["network_graph", network_graph], ["message_board", message_board], ["player", player], ["bed", bed], ["clock_in_point", clock_in_point]]:
		if entry[1] == null:
			missing.append(entry[0])
	if not missing.is_empty():
		push_error("GameLevel '%s' is missing: %s" % [name, ", ".join(missing)])
	return missing.is_empty()

func _setup_clock() -> void:
	# The level decides when time runs: clock-in starts it, and it never rolls into a second day.
	day_cycle.stop()
	day_cycle.repeat_days = false
	day_cycle.reset()
	day_cycle.load_schedule(MessageBoard.build_schedule(day_cycle.schedule, day_cycle))
	# Connect by name: "notification" would otherwise resolve to Object.notification().
	day_cycle.connect(&"notification", _on_day_cycle_notification)
	day_cycle.time_changed.connect(_on_time_changed)
	day_cycle.day_ended.connect(_on_day_ended)

func _set_phase(value: Phase) -> void:
	phase = value
	_refresh_zones()
	phase_changed.emit(phase)
	prompt_changed.emit(get_prompt())

func _refresh_zones() -> void:
	clock_in_point.enabled = phase == Phase.WAKING
	bed.enabled = phase == Phase.AFTER_HOURS

func _get_routers() -> Array[SignalNetworkRouter]:
	var routers: Array[SignalNetworkRouter] = []
	for vertex in network_graph.get_vertices():
		if vertex is SignalNetworkRouter:
			routers.append(vertex)
	return routers

func _collect_solids(node: Node, result: Array[Node]) -> void:
	for child in node.get_children():
		var tiles := child as TileMapLayer
		if tiles != null:
			if tiles.collision_enabled and tiles.tile_set != null:
				result.append(tiles)
		elif (child is CollisionShape2D or child is CollisionPolygon2D) and child.get_parent() is StaticBody2D:
			result.append(child)
		_collect_solids(child, result)

func _on_day_cycle_notification(keyword: StringName, values: Dictionary) -> void:
	var handler: Callable = _handlers.get(keyword, Callable())
	if handler.is_valid():
		handler.call(values)
	else:
		push_warning("GameLevel '%s' has no handler for day-cycle notification '%s'." % [name, keyword])

func _on_time_changed(_day: int, _game_seconds: float) -> void:
	var text := get_clock_text()
	if text != _clock_text:
		_clock_text = text
		clock_changed.emit(text, get_shift_end_text(), day_cycle.get_day_progress())

func _on_clock_in(_player: Node2D) -> void:
	if phase != Phase.WAKING:
		return
	_set_phase(Phase.ON_SHIFT)
	day_cycle.start()
	_clock_text = ""
	_on_time_changed(day_cycle.day, day_cycle.get_game_seconds())

func _on_day_ended(_day: int) -> void:
	message_board.expire_open()
	_set_phase(Phase.AFTER_HOURS)

func _on_bed_used(_player: Node2D) -> void:
	if phase != Phase.AFTER_HOURS:
		return
	_set_phase(Phase.COMPLETED)
	var report := build_report()
	if level_completed.get_connections().is_empty():
		print("Day complete: %s, score %d" % [level_title, report.score])
	level_completed.emit(report)

func _on_repair_requested(_player: Node2D, router: SignalNetworkRouter) -> void:
	minigame_requested.emit(router)

func _on_repair_finished(success: bool) -> void:
	if success:
		routers_repaired += 1

func _on_sunrise(values: Dictionary) -> void:
	if lighting != null:
		lighting.sunrise(float(values.get("seconds", -1.0)))

func _on_sunset(values: Dictionary) -> void:
	if lighting != null:
		lighting.sunset(float(values.get("seconds", -1.0)))

func _on_lighting(values: Dictionary) -> void:
	if lighting != null:
		lighting.handle_notification(&"lighting", values)

func _on_message_warning(values: Dictionary) -> void:
	message_board.announce(values["message"])

func _on_message_transmit(values: Dictionary) -> void:
	message_board.transmit(values["message"])

## Payload {"router": &"key"} breaks that router; {"random": n} breaks n working routers.
func _on_router_break(values: Dictionary) -> void:
	var key := StringName(values.get("router", ""))
	if not key.is_empty():
		var router := network_graph.get_router_by_key(key)
		if router != null:
			router.state = SignalNetworkRouter.State.BROKEN
		return
	var working: Array[SignalNetworkRouter] = []
	for router in _get_routers():
		if router.state == SignalNetworkRouter.State.OK:
			working.append(router)
	working.shuffle()
	for index in mini(int(values.get("random", 1)), working.size()):
		working[index].state = SignalNetworkRouter.State.BROKEN
