@tool
extends Node2D
## Fixed path + moving body. Editor preview never advances the simulation.
signal direction_changed(is_reversed: bool)
signal disappeared
signal reappeared
enum TravelMode { PING_PONG, WRAP }
## Per-instance artwork, editable without enabling Editable Children.
@export var texture: Texture2D:
	set(value):
		texture = value
		var sprite := get_node_or_null("Body/Sprite2D") as Sprite2D
		if sprite != null:
			sprite.texture = texture
## Assign a level-owned Path2D to edit the route without Editable Children.
## Leave empty to use the scene's built-in MovementPath.
@export var movement_path: Path2D:
	set(value):
		movement_path = value
		if is_node_ready():
			_select_path()
			_distance = start_progress * _length()
			_place()
			update_configuration_warnings()
@export var travel_mode: TravelMode = TravelMode.PING_PONG
@export_range(0.0, 2000.0, 1.0, "or_greater") var speed: float = 100.0
@export var running: bool = true
@export var reversed: bool = false:
	set(value):
		if reversed == value:
			return
		reversed = value
		direction_changed.emit(reversed)
@export_range(0.0, 1.0) var start_progress: float = 0.0:
	set(value):
		start_progress = clampf(value, 0.0, 1.0)
		if Engine.is_editor_hint() and is_node_ready():
			_preview()
@export_range(0.0, 5.0, 0.05) var disappear_duration: float = 0.2
@export var orient_to_path: bool = false
var path: Path2D
@onready var body: AnimatableBody2D = $Body
var _distance: float = 0.0
var _hidden_time: float = 0.0
var _hidden_ticks: int = 0
var _wrapping: bool = false
var _curve: Curve2D
var _base_rotation: float = 0.0
var _preview_path_transform := Transform2D.IDENTITY
var _preview_root_transform := Transform2D.IDENTITY

func _ready() -> void:
	get_node("Body/Sprite2D").texture = texture
	_base_rotation = body.rotation
	body.sync_to_physics = false
	_select_path()
	_distance = start_progress * _length()
	_place()
	set_physics_process(not Engine.is_editor_hint())

func _select_path() -> void:
	path = movement_path if is_instance_valid(movement_path) else get_node("MovementPath") as Path2D
	_watch_curve()

func _watch_curve() -> void:
	if is_instance_valid(_curve) and _curve.changed.is_connected(_preview):
		_curve.changed.disconnect(_preview)
	_curve = path.curve if is_instance_valid(path) else null
	if _curve != null:
		_curve.changed.connect(_preview)

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if not is_instance_valid(path):
		_select_path()
	if path.curve != _curve:
		_watch_curve()
		_preview()
	if path.global_transform != _preview_path_transform or global_transform != _preview_root_transform:
		_preview()
func _preview() -> void:
	if not Engine.is_editor_hint() or not is_node_ready():
		return
	_distance = start_progress * _length()
	_place()
	_preview_path_transform = path.global_transform
	_preview_root_transform = global_transform
	update_configuration_warnings()

func _get_configuration_warnings() -> PackedStringArray:
	var path_node := movement_path if is_instance_valid(movement_path) else get_node_or_null("MovementPath") as Path2D
	if path_node == null or path_node.curve == null or path_node.curve.get_baked_length() <= 0.0:
		return PackedStringArray(["The selected movement path needs a Curve2D with at least two distinct points."])
	return PackedStringArray()

func _length() -> float:
	return path.curve.get_baked_length() if is_instance_valid(path) and path.curve != null else 0.0

func _place() -> void:
	if not is_instance_valid(path) or path.curve == null or path.curve.point_count == 0:
		return
	if orient_to_path and _length() > 0.0:
		var pose := path.curve.sample_baked_with_rotation(_distance)
		body.global_position = path.to_global(pose.origin)
		body.global_rotation = path.global_rotation + pose.get_rotation() + _base_rotation
	else:
		body.global_position = path.to_global(path.curve.sample_baked(_distance))
		body.rotation = _base_rotation

func _physics_process(delta: float) -> void:
	if _wrapping:
		_hidden_time = maxf(0.0, _hidden_time - delta)
		_hidden_ticks += 1
		# Keep the reset body outside physics for at least two complete ticks.
		if _hidden_time <= 0.0 and _hidden_ticks >= 3:
			PhysicsServer2D.body_set_space(body.get_rid(), body.get_world_2d().space)
			body.show()
			_wrapping = false
			reappeared.emit()
		return
	if not running or speed <= 0.0:
		return
	var length := _length()
	if length <= 0.0:
		return
	var next := _distance + speed * delta * (-1.0 if reversed else 1.0)
	if travel_mode == TravelMode.PING_PONG:
		# Fold arbitrary travel distances, including multiple endpoint crossings.
		var phase := _distance if not reversed else 2.0 * length - _distance
		phase = fposmod(phase + speed * delta, 2.0 * length)
		reversed = phase >= length
		_distance = 2.0 * length - phase if reversed else phase
		_place()
	elif next >= length or next <= 0.0:
		_distance = 0.0 if not reversed else length
		_begin_wrap()
	else:
		_distance = next
		_place()

func _begin_wrap() -> void:
	if disappear_duration > 0.0:
		_wrapping = true
		_hidden_time = disappear_duration
		_hidden_ticks = 0
		body.hide()
		# Removing the carrier from physics prevents sweeping across the level.
		PhysicsServer2D.body_set_space(body.get_rid(), RID())
		disappeared.emit()
	_place()

func reverse_direction() -> void:
	reversed = not reversed

func set_reversed(value: bool) -> void:
	reversed = value

func start() -> void:
	running = true

func stop() -> void:
	running = false

func get_progress() -> float:
	var length := _length()
	return _distance / length if length > 0.0 else 0.0

func _exit_tree() -> void:
	if is_instance_valid(_curve) and _curve.changed.is_connected(_preview):
		_curve.changed.disconnect(_preview)
