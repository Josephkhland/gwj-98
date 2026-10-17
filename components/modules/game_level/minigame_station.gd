extends InteractionZone
## An interaction spot that opens a minigame for its own sake, outside the router repair flow.
## The scene root must expose completed(success: bool), like any router minigame. The station
## follows its GameLevel's phase and is only usable during active_phases.
signal minigame_finished(success: bool)
signal attempt_finished(success: bool, elapsed_seconds: float)

@export var minigame_scene: PackedScene
@export var active_phases: Array[GameLevel.Phase] = [GameLevel.Phase.AFTER_HOURS]
@export var required_before_sleep: bool = true
## Nodes in this group (the player, moving platforms) freeze while the minigame is open.
@export var pause_group: StringName = &"pause_during_repairs"
var _minigame: Node
var _suspension: RepairSuspension
var _elapsed_seconds: float = 0

func _ready() -> void:
	super()
	interacted.connect(open_minigame)
	var level := _find_level()
	if level != null:
		if required_before_sleep:
			level.register_practice_station(self)
		level.phase_changed.connect(_on_phase_changed)
		_on_phase_changed(level.phase)

func is_open() -> bool:
	return is_instance_valid(_minigame)

func _process(delta: float) -> void:
	_refresh_hint()
	if is_open():
		_elapsed_seconds += delta

func _refresh_hint() -> void:
	if not is_inside_tree():
		return
	super._refresh_hint()
	var available := enabled and not is_open() and not get_tree().has_group(&"signal_network_repair_session")
	var icon := get_node_or_null("Router") as CanvasItem
	if icon != null:
		icon.visible = available
	if not available:
		var hint := get_node_or_null(hint_label) as CanvasItem if not hint_label.is_empty() else null
		if hint != null:
			hint.hide()

func open_minigame(_player: Node2D = null) -> void:
	if not enabled or is_open() or minigame_scene == null or get_tree().has_group(&"signal_network_repair_session"):
		return
	var instance := minigame_scene.instantiate()
	if not instance.has_signal(&"completed"):
		push_error("Minigame root must expose completed(success: bool).")
		instance.free()
		return
	_minigame = instance
	_elapsed_seconds = 0
	# The repair-session group blocks other interactions (zones, routers, townfolk) meanwhile.
	instance.add_to_group(&"signal_network_repair_session")
	instance.connect(&"completed", _close.bind(instance), CONNECT_ONE_SHOT)
	instance.tree_exiting.connect(_close.bind(false, instance), CONNECT_ONE_SHOT)
	_suspension = RepairSuspension.new()
	_suspension.group = pause_group
	instance.add_child(_suspension)
	add_child(instance)

func _close(success: bool, instance: Node) -> void:
	if _minigame != instance:
		return
	_minigame = null
	if is_instance_valid(_suspension):
		_suspension.release()
	_suspension = null
	attempt_finished.emit(success, _elapsed_seconds)
	minigame_finished.emit(success)

func _on_phase_changed(phase: GameLevel.Phase) -> void:
	enabled = phase in active_phases

func _find_level() -> GameLevel:
	var node := get_parent()
	while node != null and not node is GameLevel:
		node = node.get_parent()
	return node as GameLevel
