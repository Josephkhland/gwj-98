class_name InteractionZone
extends Area2D
## A spot the player uses with the interact action (bed, clock-in point). Reacts only while enabled.
signal interacted(player: Node2D)
@export var enabled: bool = true:
	set(value):
		enabled = value
		_refresh_hint()
@export var player_group: StringName = &"players"
@export var interact_action: StringName = &"interact"
## Optional hint shown while a player can interact. Defaults to a direct child named HintLabel.
@export_node_path("CanvasItem") var hint_label: NodePath = ^"HintLabel"
var _players: Array[Node2D] = []

func _ready() -> void:
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_refresh_hint()

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or _players.is_empty() or not InputMap.has_action(interact_action):
		return
	if not event.is_action_pressed(interact_action) or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	interacted.emit(_players[0])

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(player_group) and not _players.has(body):
		_players.append(body)
		_refresh_hint()

func _on_body_exited(body: Node2D) -> void:
	_players.erase(body)
	_refresh_hint()

func _refresh_hint() -> void:
	if not is_inside_tree() or hint_label.is_empty():
		return
	var hint := get_node_or_null(hint_label) as CanvasItem
	if hint != null:
		hint.visible = enabled and not _players.is_empty()
