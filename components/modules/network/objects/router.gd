@tool
class_name SignalNetworkRouter
extends SignalNetworkVertex

enum State { OK, BROKEN, BEING_ATTACKED, ATTACK_INTERRUPTED }
enum AttackOutcome { RANDOM, BROKEN, POWERED_DOWN }
const ATTACKED_ROUTERS_GROUP := &"attacked_network_routers"
## Off and faulty routers both use BROKEN in the network; retain power for inspection.
@export var powered: bool = true
signal state_changed(previous_state: State, new_state: State)
signal repair_started(player: Node2D)
signal repair_finished(success: bool)
signal attack_started
signal attack_interrupted
signal attack_completed(powered_down: bool)
## When connected, the receiver hosts the minigame and must call resolve_repair().
## Without a connection the router opens minigame_scene itself.
signal repair_requested(player: Node2D)
@export var state: State = State.BROKEN:
	set(value):
		if state == value:
			return
		var previous := state
		state = value
		if state != State.BROKEN:
			powered = true
		if state == State.BEING_ATTACKED:
			_initialize_attack()
		elif state == State.ATTACK_INTERRUPTED:
			_recovery_from = clampf(_attack_left / maxf(0.01, _attack_total), 0.0, 1.0)
			_recovery_elapsed = 0.0
		if is_inside_tree() and not Engine.is_editor_hint():
			if state == State.BEING_ATTACKED:
				add_to_group(ATTACKED_ROUTERS_GROUP)
			elif is_in_group(ATTACKED_ROUTERS_GROUP):
				remove_from_group(ATTACKED_ROUTERS_GROUP)
		_refresh_visuals()
		state_changed.emit(previous, state)
		availability_changed.emit()
@export_range(1.0, 1000.0) var interaction_radius: float = 80.0
@export var player_group: StringName = &"players"
@export var interact_action: StringName = &"interact"
@export var inspect_working_routers: bool = true
@export_group("Attacks")
## Real seconds. The outage generator can override this per attack.
@export_range(0.1, 60.0, 0.1, "or_greater") var default_attack_duration: float = 8.0
@export var default_attack_outcome: AttackOutcome = AttackOutcome.RANDOM
@export_range(1.0, 500.0, 1.0) var attack_player_radius: float = 150.0
@export_range(1.0, 500.0, 1.0) var attack_spit_radius: float = 100.0
@export_range(0.0, 2.0, 0.05) var interruption_pause_seconds: float = 0.15
@export_range(0.05, 3.0, 0.05) var recovery_seconds: float = 0.8
@export_range(0.0, 2.0, 0.05) var recovery_hold_seconds: float = 0.35
@export_group("State Animation")
@export_node_path("AnimatedSprite2D") var state_sprite: NodePath = ^"AnimatedSprite2D"
@export var operational_animation: StringName = &"operational"
@export var broken_animation: StringName = &"broken"
@export var powered_down_animation: StringName = &"powered_down"
@export var attacked_animation: StringName = &"being_attacked"
@export var interrupted_animation: StringName = &"attack_interrupted"
@export_group("Visuals")
## Optional interaction hint. Defaults to a direct child named HintLabel.
@export_node_path("CanvasItem") var hint_label: NodePath = ^"HintLabel"
## Nodes may be Sprite2D, AnimatedSprite2D, or any other CanvasItem.
@export_node_path("CanvasItem") var ok_visual: NodePath:
	set(value):
		ok_visual = value
		_refresh_visuals()
@export_node_path("CanvasItem") var broken_visual: NodePath:
	set(value):
		broken_visual = value
		_refresh_visuals()
## Supplied by Router.tscn or your own scene; the script has no fixed asset path.
@export var minigame_scene: PackedScene
var _minigame: Node
var _player: Node2D
var _awaiting_external_repair: bool = false
var _repair_suspension: RepairSuspension
var _attack_left: float = 0.0
var _attack_total: float = 0.0
var _attack_result: int = AttackOutcome.BROKEN
var _requested_duration: float = -1.0
var _requested_outcome: int = -1
var _recovery_elapsed: float = 0.0
var _recovery_from: float = 0.0

func _ready() -> void:
	if not powered:
		state = State.BROKEN
	if state == State.BEING_ATTACKED and not Engine.is_editor_hint():
		if _attack_total <= 0.0:
			_initialize_attack()
		add_to_group(ATTACKED_ROUTERS_GROUP)
	_refresh_visuals()
	set_process_unhandled_input(not Engine.is_editor_hint())
	set_process(not Engine.is_editor_hint())

func _process(delta: float) -> void:
	_update_attack(delta)
	_refresh_hint()

func is_available() -> bool:
	return powered and state != State.BROKEN

func start_attack(duration_seconds: float = -1.0, outcome: int = -1) -> bool:
	if state != State.OK or not powered or is_instance_valid(_minigame) or _awaiting_external_repair:
		return false
	_requested_duration = duration_seconds
	_requested_outcome = outcome
	state = State.BEING_ATTACKED
	attack_started.emit()
	return true

func _initialize_attack() -> void:
	_attack_total = maxf(0.01, _requested_duration if _requested_duration > 0.0 else default_attack_duration)
	_attack_left = _attack_total
	_attack_result = _requested_outcome if _requested_outcome >= 0 else int(default_attack_outcome)
	if _attack_result == AttackOutcome.RANDOM:
		_attack_result = AttackOutcome.BROKEN if randf() < 0.5 else AttackOutcome.POWERED_DOWN
	_requested_duration = -1.0
	_requested_outcome = -1

func interrupt_attack() -> bool:
	if state != State.BEING_ATTACKED:
		return false
	state = State.ATTACK_INTERRUPTED
	attack_interrupted.emit()
	return true

func _update_attack(delta: float) -> void:
	if state == State.BEING_ATTACKED:
		for candidate in get_tree().get_nodes_in_group(player_group):
			if candidate is Node2D and global_position.distance_to(candidate.global_position) <= attack_player_radius:
				interrupt_attack()
				return
		_attack_left = maxf(0.0, _attack_left - delta)
		if _attack_left <= 0.0:
			powered = _attack_result != AttackOutcome.POWERED_DOWN
			state = State.BROKEN
			attack_completed.emit(not powered)
	elif state == State.ATTACK_INTERRUPTED:
		_recovery_elapsed += delta
		if _recovery_elapsed >= interruption_pause_seconds + recovery_seconds + recovery_hold_seconds:
			state = State.OK

## Called for the actual swept segment, so fast spit cannot skip a nearby router.
func check_spit_pass(from: Vector2, to: Vector2, spit_radius: float, source: Node) -> void:
	if state != State.BEING_ATTACKED or not is_instance_valid(source) or not source.is_in_group(player_group):
		return
	var closest := Geometry2D.get_closest_point_to_segment(global_position, from, to)
	if closest.distance_to(global_position) <= attack_spit_radius + spit_radius:
		interrupt_attack()

func get_attack_elapsed() -> float:
	return maxf(0.0, _attack_total - _attack_left)

func get_attack_progress() -> float:
	if state == State.BEING_ATTACKED:
		return clampf(_attack_left / maxf(0.01, _attack_total), 0.0, 1.0)
	if state == State.ATTACK_INTERRUPTED:
		var progress := clampf((_recovery_elapsed - interruption_pause_seconds) / maxf(0.01, recovery_seconds), 0.0, 1.0)
		return lerpf(_recovery_from, 1.0, smoothstep(0.0, 1.0, progress))
	return 1.0

func can_interact(player: Node2D) -> bool:
	return state not in [State.BEING_ATTACKED, State.ATTACK_INTERRUPTED] and is_instance_valid(player) and player.is_in_group(player_group) and (state == State.BROKEN or inspect_working_routers) and not is_instance_valid(_minigame) and not _awaiting_external_repair and global_position.distance_to(player.global_position) <= interaction_radius

func _unhandled_input(event: InputEvent) -> void:
	if not InputMap.has_action(interact_action) or not event.is_action_pressed(interact_action) or event.is_echo():
		return
	var nearest: Node2D
	var distance := INF
	for candidate in get_tree().get_nodes_in_group(player_group):
		if candidate is Node2D and can_interact(candidate):
			var candidate_distance := global_position.distance_squared_to(candidate.global_position)
			if candidate_distance < distance:
				nearest = candidate
				distance = candidate_distance
	if nearest != null and interact(nearest):
		get_viewport().set_input_as_handled()

## Call directly from a project's own interaction system if preferred.
func interact(player: Node2D) -> bool:
	if not can_interact(player) or minigame_scene == null or get_tree().get_nodes_in_group(&"signal_network_repair_session").size() > 0:
		return false
	if repair_requested.get_connections().is_empty():
		return open_local_minigame(player)
	_awaiting_external_repair = true
	_player = player
	repair_started.emit(player)
	repair_requested.emit(player)
	return true

## Completes a repair session handed out through repair_requested.
func resolve_repair(success: bool, final_power: Variant = null) -> void:
	if not _awaiting_external_repair:
		return
	_awaiting_external_repair = false
	var repaired := success and is_instance_valid(_player) and state == State.BROKEN
	if final_power != null and is_instance_valid(_player):
		powered = bool(final_power)
		state = State.OK if success and powered else State.BROKEN
	elif repaired:
		state = State.OK
	_player = null
	repair_finished.emit(repaired)

## Opens minigame_scene under the scene root; used when nobody hosts repairs.
func open_local_minigame(player: Node2D) -> bool:
	var instance := minigame_scene.instantiate()
	if not instance.has_signal("completed"):
		push_error("Router minigame root must expose completed(success: bool).")
		instance.free()
		return false
	_minigame = instance
	_player = player
	configure_minigame(instance)
	instance.add_to_group(&"signal_network_repair_session")
	instance.connect("completed", _complete_repair, CONNECT_ONE_SHOT)
	instance.tree_exiting.connect(_minigame_closed, CONNECT_ONE_SHOT)
	_repair_suspension = RepairSuspension.new()
	instance.add_child(_repair_suspension)
	get_tree().root.add_child(instance)
	if is_instance_valid(_minigame):
		repair_started.emit(player)
	return true

func configure_minigame(instance: Node) -> void:
	if instance.has_method(&"configure_router"):
		instance.call(&"configure_router", powered, state == State.BROKEN)

func _complete_repair(success: bool) -> void:
	if not is_instance_valid(_minigame):
		return
	var instance := _minigame
	_minigame = null
	_release_suspension()
	var repaired := success and is_instance_valid(_player) and state == State.BROKEN
	if instance.has_method(&"configure_router") and is_instance_valid(_player):
		powered = bool(instance.get("powered"))
		state = State.OK if success and powered else State.BROKEN
	elif repaired:
		state = State.OK
	instance.queue_free()
	_player = null
	repair_finished.emit(repaired)

func _minigame_closed() -> void:
	_release_suspension()
	if is_instance_valid(_minigame):
		_minigame = null
		_player = null
		repair_finished.emit(false)

func _exit_tree() -> void:
	_release_suspension()
	if is_instance_valid(_minigame):
		_minigame.queue_free()
		_minigame = null

func _release_suspension() -> void:
	if is_instance_valid(_repair_suspension):
		_repair_suspension.release()
	_repair_suspension = null

func _refresh_visuals() -> void:
	if not is_inside_tree():
		return
	for path in [ok_visual, broken_visual]:
		if not path.is_empty():
			var visual := get_node_or_null(path) as CanvasItem
			if visual != null:
				visual.visible = (path == ok_visual and state != State.BROKEN) or (path == broken_visual and state == State.BROKEN)
	var sprite := get_node_or_null(state_sprite) as AnimatedSprite2D if not state_sprite.is_empty() else null
	if sprite != null:
		sprite.visible = ok_visual.is_empty() and broken_visual.is_empty()
		var animation := operational_animation
		match state:
			State.BROKEN:
				animation = broken_animation if powered else powered_down_animation
			State.BEING_ATTACKED:
				animation = attacked_animation
			State.ATTACK_INTERRUPTED:
				animation = interrupted_animation
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation):
			sprite.play(animation)
	_refresh_hint()
	queue_redraw()

func _refresh_hint() -> void:
	if not is_inside_tree() or hint_label.is_empty():
		return
	var hint := get_node_or_null(hint_label) as CanvasItem
	if hint == null:
		return
	var show_hint := false
	if not Engine.is_editor_hint() and InputMap.has_action(interact_action) and not get_tree().has_group(&"signal_network_repair_session"):
		for candidate in get_tree().get_nodes_in_group(player_group):
			if candidate is Node2D and can_interact(candidate):
				show_hint = true
				break
	hint.visible = show_hint

func _draw() -> void:
	if ok_visual.is_empty() and broken_visual.is_empty():
		var sprite := get_node_or_null(state_sprite) as AnimatedSprite2D if not state_sprite.is_empty() else null
		if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(sprite.animation) and sprite.sprite_frames.get_frame_count(sprite.animation) > 0:
			return
		draw_circle(Vector2.ZERO, 16.0, Color.LIME_GREEN if state != State.BROKEN else Color.INDIAN_RED)
