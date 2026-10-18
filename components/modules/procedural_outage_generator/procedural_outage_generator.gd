class_name ProceduralOutageGenerator
extends Node
## Optional level component. Override get_interval_minutes() for another pacing variant.
signal router_broken(router: SignalNetworkRouter)
signal router_attacked(router: SignalNetworkRouter)

@export var enabled: bool = true
@export var network_graph: SignalNetworkGraph
## Defaults to the enclosing GameLevel and its clock.
@export var level: GameLevel
@export var day_cycle: DayCycleManager
@export_group("Outage Pacing (game minutes)")
@export_range(1.0, 240.0, 0.5, "or_greater") var quiet_interval_minutes: float = 30.0
@export_range(1.0, 240.0, 0.5, "or_greater") var peak_interval_minutes: float = 10.0
## X: work-shift progress (0–1). Y: density (0 = quiet interval, 1 = peak interval).
## An empty or unassigned curve uses the quiet interval throughout the shift.
@export var density_curve: Curve = _make_default_density_curve()
## Restarted on attack, interruption, or failure so a saved router is not spammed.
@export_range(0.0, 240.0, 0.5, "or_greater") var router_cooldown_minutes: float = 30.0
## Includes faults, powered-off routers, and active attacks. Zero means no cap.
@export_range(0, 100, 1, "or_greater") var maximum_broken_routers: int = 6
@export_group("Attack Warning")
## Real seconds to approach the router or intercept the attack with spit.
@export_range(0.1, 60.0, 0.1, "or_greater") var attack_duration_seconds: float = 8.0
@export var attack_outcome: SignalNetworkRouter.AttackOutcome = SignalNetworkRouter.AttackOutcome.RANDOM

var _active: bool = false
var _shift_start: float = 0.0
var _shift_duration: float = 1.0
var _next_outage: float = INF
var _last_broken: Dictionary[int, float] = {}
var _watched: Dictionary[SignalNetworkRouter, Callable] = {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	if level == null:
		var ancestor := get_parent()
		while ancestor != null:
			if ancestor is GameLevel:
				level = ancestor
				break
			ancestor = ancestor.get_parent()
	match AccessibilitySettings.difficulty:
		0:
			quiet_interval_minutes = 50.
			peak_interval_minutes = 15.

		1:
			quiet_interval_minutes = 40.
			peak_interval_minutes = 10.

		2:
			quiet_interval_minutes = 35.
			peak_interval_minutes = 5.

		3:
			quiet_interval_minutes = 20.
			peak_interval_minutes = 5.

		_:
			quiet_interval_minutes = 40.
			peak_interval_minutes = 5.
	print(quiet_interval_minutes)
	print(peak_interval_minutes)
	# Parent GameLevel resolves its conventional node references in its own _ready.
	_bind_level.call_deferred()

func _bind_level() -> void:
	if level == null:
		push_warning("ProceduralOutageGenerator needs a GameLevel to follow the work shift.")
		return
	if network_graph == null:
		network_graph = level.network_graph
	if day_cycle == null:
		day_cycle = level.day_cycle
	if network_graph == null or day_cycle == null:
		push_warning("ProceduralOutageGenerator needs a NetworkGraph and DayCycleManager.")
		return
	level.phase_changed.connect(_on_phase_changed)
	day_cycle.time_changed.connect(_on_time_changed)
	_on_phase_changed(level.phase)

func _on_phase_changed(phase: GameLevel.Phase) -> void:
	if phase != GameLevel.Phase.ON_SHIFT:
		_active = false
		return
	if _active:
		return
	_active = true
	_shift_start = day_cycle.get_elapsed_game_seconds()
	_shift_duration = maxf(1.0, day_cycle.get_game_seconds_until_day_end())
	_last_broken.clear()
	_watch_routers(_shift_start)
	for vertex in network_graph.get_vertices():
		if vertex is SignalNetworkRouter and (not vertex.is_available() or vertex.state in [SignalNetworkRouter.State.BEING_ATTACKED, SignalNetworkRouter.State.ATTACK_INTERRUPTED]):
			_last_broken[vertex.get_instance_id()] = _shift_start
	if enabled:
		_try_break_router(_shift_start)
	_next_outage = _shift_start + get_interval_minutes(0.0) * 60.0

static func _make_default_density_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.5, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	return curve

## The curve only changes pacing; cooldowns and the simultaneous-fault cap still apply.
func get_interval_minutes(progress: float) -> float:
	var intensity := 0.0
	if density_curve != null and density_curve.point_count > 0:
		intensity = clampf(density_curve.sample(clampf(progress, 0.0, 1.0)), 0.0, 1.0)
	return maxf(1.0, lerpf(quiet_interval_minutes, peak_interval_minutes, intensity))

func _on_time_changed(_day: int, _game_seconds: float) -> void:
	if not _active or level.phase != GameLevel.Phase.ON_SHIFT:
		return
	var now := day_cycle.get_elapsed_game_seconds()
	_watch_routers(now)
	if now < _next_outage:
		return
	if enabled:
		_try_break_router(now)
	# A clock skip performs at most one attempt, never a backlog of instant faults.
	var progress := (now - _shift_start) / _shift_duration
	_next_outage = now + get_interval_minutes(progress) * 60.0

func _watch_routers(now: float) -> void:
	for vertex in network_graph.get_vertices():
		if not vertex is SignalNetworkRouter or _watched.has(vertex):
			continue
		var router := vertex as SignalNetworkRouter
		var callback := _on_router_state_changed.bind(router)
		_watched[router] = callback
		router.state_changed.connect(callback)
		if not router.powered or router.state in [SignalNetworkRouter.State.BROKEN, SignalNetworkRouter.State.BEING_ATTACKED]:
			_last_broken[router.get_instance_id()] = now

func _on_router_state_changed(previous: SignalNetworkRouter.State, current: SignalNetworkRouter.State, router: SignalNetworkRouter) -> void:
	if _active and current in [SignalNetworkRouter.State.BROKEN, SignalNetworkRouter.State.BEING_ATTACKED, SignalNetworkRouter.State.ATTACK_INTERRUPTED]:
		_last_broken[router.get_instance_id()] = day_cycle.get_elapsed_game_seconds()
	if previous == SignalNetworkRouter.State.BEING_ATTACKED and current == SignalNetworkRouter.State.BROKEN:
		router_broken.emit(router)

func _try_break_router(now: float) -> void:
	var broken_count := 0
	var eligible: Array[SignalNetworkRouter] = []
	for vertex in network_graph.get_vertices():
		if not vertex is SignalNetworkRouter:
			continue
		var router := vertex as SignalNetworkRouter
		if not router.powered or router.state in [SignalNetworkRouter.State.BROKEN, SignalNetworkRouter.State.BEING_ATTACKED]:
			broken_count += 1
			continue
		if router.state != SignalNetworkRouter.State.OK:
			continue
		var last := float(_last_broken.get(router.get_instance_id(), -INF))
		if now - last >= router_cooldown_minutes * 60.0:
			# Avoid changing a router while its inspection UI shows its previous state.
			if not is_instance_valid(router._minigame) and not router._awaiting_external_repair:
				eligible.append(router)
	if maximum_broken_routers > 0 and broken_count >= maximum_broken_routers:
		return
	if eligible.is_empty():
		return
	var selected := eligible[_rng.randi_range(0, eligible.size() - 1)]
	if selected.start_attack(attack_duration_seconds, attack_outcome):
		router_attacked.emit(selected)

func _exit_tree() -> void:
	for router in _watched:
		if is_instance_valid(router) and router.state_changed.is_connected(_watched[router]):
			router.state_changed.disconnect(_watched[router])
