@tool
class_name SignalNetworkRouter
extends SignalNetworkVertex

enum State { OK, BROKEN }
## Off and faulty routers both use BROKEN in the network; retain power for inspection.
@export var powered: bool = true
signal state_changed(previous_state: State, new_state: State)
signal repair_started(player: Node2D)
signal repair_finished(success: bool)
## When connected, the receiver hosts the minigame and must call resolve_repair().
## Without a connection the router opens minigame_scene itself.
signal repair_requested(player: Node2D)
@export var state: State = State.BROKEN:
	set(value):
		if state == value:
			return
		var previous := state
		state = value
		if state == State.OK:
			powered = true
		_refresh_visuals()
		state_changed.emit(previous, state)
		availability_changed.emit()
@export_range(1.0, 1000.0) var interaction_radius: float = 80.0
@export var player_group: StringName = &"players"
@export var interact_action: StringName = &"interact"
@export var inspect_working_routers: bool = true
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

func _ready() -> void:
	if not powered:
		state = State.BROKEN
	_refresh_visuals()
	set_process_unhandled_input(not Engine.is_editor_hint())
	set_process(not Engine.is_editor_hint())

func _process(_delta: float) -> void:
	_refresh_hint()

func is_available() -> bool:
	return state == State.OK

func can_interact(player: Node2D) -> bool:
	return is_instance_valid(player) and player.is_in_group(player_group) and (state == State.BROKEN or inspect_working_routers) and not is_instance_valid(_minigame) and not _awaiting_external_repair and global_position.distance_to(player.global_position) <= interaction_radius

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
				visual.visible = (path == ok_visual and state == State.OK) or (path == broken_visual and state == State.BROKEN)
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
		draw_circle(Vector2.ZERO, 16.0, Color.LIME_GREEN if state == State.OK else Color.INDIAN_RED)
