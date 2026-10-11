@tool
class_name CameraManager2D
extends Node2D
## Owns direct Camera2D children. Ordinary requests coalesce; forced actions use FIFO.

## Private inbox entry. Only the manager creates and timestamps requests.
class ChangeRequest:
	extends RefCounted

	var camera_name: StringName
	var created_at_usec: int
	var transition: CameraTransition
	var hold_seconds: float = -1.0
	var return_transition: CameraTransition
	var force: bool = false

signal camera_changed(previous: Camera2D, current: Camera2D)
signal transition_started(destination: Camera2D)
signal transition_finished(destination: Camera2D)
signal request_rejected(camera_name: StringName, reason: String)

@export var initial_camera: StringName = &""
@export var default_transition: CameraTransition
@export var wait_for_transition: bool = false

var active_camera: Camera2D:
	get:
		return _active if is_instance_valid(_active) else null
var is_transitioning: bool:
	get:
		return is_instance_valid(_destination)

var _cameras: Dictionary[StringName, Camera2D] = {}
var _active: Camera2D
var _bridge: Camera2D
var _destination: Camera2D
var _inbox: Array[ChangeRequest] = []
var _running: ChangeRequest
var _latest_timestamp: int = -1
var _force_in_progress: bool = false
var _elapsed: float = 0.0
var _settings: CameraTransition
var _start_position: Vector2
var _start_zoom: Vector2
var _start_rotation: float
var _return_camera: Camera2D
var _return_settings: CameraTransition
var _hold_remaining: float = -1.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Follow cameras update before this manager samples their positions.
	process_priority = 100
	refresh_cameras()
	for camera: Camera2D in _cameras.values():
		camera.enabled = false
	var first := get_camera(initial_camera)
	if first == null and not _cameras.is_empty():
		first = _cameras.values()[0]
	if first != null:
		_activate(first)


## Rebuild after adding/removing/renaming cameras at runtime.
func refresh_cameras() -> void:
	_cameras.clear()
	for child in get_children():
		if child is Camera2D and child != _bridge:
			var camera := child as Camera2D
			var key := StringName(camera.name)
			if camera is ManagedCamera2D and camera.camera_name != &"":
				key = camera.camera_name
			if _cameras.has(key):
				push_warning("CameraManager2D: duplicate camera name '%s'; first child wins." % key)
				continue
			if camera.custom_viewport != null and camera.custom_viewport != get_viewport():
				push_warning("CameraManager2D: cameras must use the manager's viewport.")
				continue
			_cameras[key] = camera


## Returns a copy so consumers cannot mutate the manager's registry.
func get_cameras() -> Dictionary[StringName, Camera2D]:
	return _cameras.duplicate()


func get_camera(key: StringName) -> Camera2D:
	# A typed Camera2D assignment rejects freed references before we can test them.
	var camera: Variant = _cameras.get(key)
	return camera if is_instance_valid(camera) and camera.get_parent() == self else null


func switch_camera(key: StringName, settings: CameraTransition = null,
		force: bool = false) -> bool:
	return _enqueue_request(key, settings, -1.0, null, force)


func switch_to_camera(camera: Camera2D, settings: CameraTransition = null,
		force: bool = false) -> bool:
	refresh_cameras()
	for key: StringName in _cameras:
		if _cameras[key] == camera:
			return switch_camera(key, settings, force)
	return false


## Index follows direct-child order in the registry.
func switch_camera_by_index(index: int, settings: CameraTransition = null,
		force: bool = false) -> bool:
	refresh_cameras()
	if index < 0 or index >= _cameras.size():
		return false
	return switch_camera(_cameras.keys()[index], settings, force)


func switch_camera_for(key: StringName, seconds: float,
		settings: CameraTransition = null, return_settings: CameraTransition = null,
		force: bool = false) -> bool:
	if seconds < 0.0 or not is_finite(seconds):
		return false
	return _enqueue_request(key, settings, seconds, return_settings, force)


## Validate, timestamp and snapshot all public switch commands in one place.
func _enqueue_request(key: StringName, settings: CameraTransition,
		hold: float, return_settings: CameraTransition, force: bool) -> bool:
	if Engine.is_editor_hint():
		return false
	refresh_cameras()
	if get_camera(key) == null:
		request_rejected.emit(key, "Unknown or removed camera")
		return false
	if not is_finite(hold):
		return false
	var request := _create_request(key, settings, hold, return_settings, force)
	if not force:
		# Drop superseded ordinary entries while preserving every forced entry.
		for index in range(_inbox.size() - 1, -1, -1):
			if not _inbox[index].force:
				_inbox.remove_at(index)
	_inbox.append(request)
	if not _force_in_progress:
		_hold_remaining = -1.0
	return true


func _create_request(key: StringName, settings: CameraTransition,
		hold: float, return_settings: CameraTransition, force: bool) -> ChangeRequest:
	var request := ChangeRequest.new()
	request.camera_name = key
	# Strict monotonic order also resolves calls within one clock microsecond.
	_latest_timestamp = maxi(Time.get_ticks_usec(), _latest_timestamp + 1)
	request.created_at_usec = _latest_timestamp
	request.transition = _copy_settings(settings if settings != null else default_transition)
	request.return_transition = _copy_settings(return_settings if return_settings != null else default_transition)
	request.hold_seconds = hold
	request.force = force
	return request


func _take_next_request() -> ChangeRequest:
	# Appending with manager-owned timestamps keeps forced entries in FIFO order.
	for index in _inbox.size():
		if _inbox[index].force:
			var request := _inbox[index]
			_inbox.remove_at(index)
			return request
	return _inbox.pop_back()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if is_instance_valid(_bridge) and (not is_instance_valid(_destination) or _destination.get_parent() != self):
		_cancel_transition()
		if active_camera != null:
			_activate(_active)
	var started_request := false
	if not _inbox.is_empty() and not _force_in_progress and (not is_transitioning or not wait_for_transition):
		_start_request(_take_next_request())
		started_request = true
	if is_transitioning:
		_elapsed += delta
		_blend(_settings.weight(minf(_elapsed / _settings.duration, 1.0)))
		if _elapsed >= _settings.duration:
			var destination := _destination
			_destination = null
			_activate(destination)
			_free_bridge()
			_begin_hold()
			transition_finished.emit(destination)
		return
	# A new instant hold begins counting on the following process update.
	if not started_request and _hold_remaining >= 0.0:
		_hold_remaining -= delta
		if _hold_remaining <= 0.0:
			_hold_remaining = -1.0
			if is_instance_valid(_return_camera) and _return_camera.get_parent() == self:
				if _force_in_progress:
					# A forced timed return is part of the current action, not another
					# FIFO entry that could be delayed behind queued forced actions.
					refresh_cameras()
					for key: StringName in _cameras:
						if _cameras[key] == _return_camera:
							_start_request(_create_request(key, _return_settings, -1.0, null, true))
							return
				else:
					switch_to_camera(_return_camera, _return_settings)
			_force_in_progress = false


func _start_request(request: ChangeRequest) -> void:
	var target := get_camera(request.camera_name)
	if target == null:
		request_rejected.emit(request.camera_name, "Camera removed before execution")
		return
	var source := _bridge if is_instance_valid(_bridge) else active_camera
	_return_camera = active_camera
	_return_settings = request.return_transition
	_running = request
	_force_in_progress = request.force
	_hold_remaining = -1.0
	_settings = request.transition
	if _settings == null:
		_settings = CameraTransition.new()
	_elapsed = 0.0
	_destination = null
	if source == null or target == source or _settings.mode == CameraTransition.Mode.INSTANT or _settings.duration <= 0.0:
		_activate(target)
		_free_bridge()
		_begin_hold()
		return
	# Snapshot the rendered view, rather than the source node's position: Godot
	# may have applied limits, offset, drag margins, or smoothing to the view.
	source.force_update_scroll()
	_start_position = source.get_screen_center_position()
	_start_rotation = source.get_screen_rotation()
	_start_zoom = source.zoom
	if not is_instance_valid(_bridge):
		_bridge = Camera2D.new()
		_bridge.name = "_TransitionCamera"
		add_child(_bridge, false, Node.INTERNAL_MODE_BACK)
		_bridge.top_level = true
		_bridge.ignore_rotation = false
	_bridge.global_position = _start_position
	_bridge.global_rotation = _start_rotation
	_bridge.zoom = _start_zoom
	_bridge.enabled = true
	_bridge.make_current()
	_destination = target
	transition_started.emit(target)


func _blend(weight: float) -> void:
	# Sample the destination each frame so a FollowCamera remains a moving endpoint.
	var target_position := _destination.global_position
	var half_size := get_viewport_rect().size / (2.0 * _destination.zoom)
	if _destination.anchor_mode == Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT:
		target_position += half_size
	if _destination.limit_right - _destination.limit_left >= half_size.x * 2.0:
		target_position.x = clampf(target_position.x,
			_destination.limit_left + half_size.x, _destination.limit_right - half_size.x)
	if _destination.limit_bottom - _destination.limit_top >= half_size.y * 2.0:
		target_position.y = clampf(target_position.y,
			_destination.limit_top + half_size.y, _destination.limit_bottom - half_size.y)
	# Godot applies camera offset after limits; offsets can intentionally exceed them.
	target_position += _destination.offset
	_bridge.global_position = _start_position.lerp(target_position, weight)
	_bridge.zoom = _start_zoom.lerp(_destination.zoom, weight)
	var _rotation := 0.0 if _destination.ignore_rotation else _destination.global_rotation
	_bridge.global_rotation = lerp_angle(_start_rotation, _rotation, weight)
	_bridge.force_update_scroll()


func _activate(camera: Camera2D) -> void:
	var previous := active_camera
	if previous != null and previous != camera:
		previous.enabled = false
	_active = camera
	camera.enabled = true
	camera.make_current()
	camera.reset_smoothing()
	camera.force_update_scroll()
	if previous != camera:
		camera_changed.emit(previous, camera)


func _begin_hold() -> void:
	if _running != null and (_running.force or _inbox.is_empty()):
		_hold_remaining = _running.hold_seconds
	if _hold_remaining < 0.0:
		_force_in_progress = false
	_running = null


func _cancel_transition() -> void:
	_destination = null
	_running = null
	_force_in_progress = false
	_hold_remaining = -1.0
	_free_bridge()


func _free_bridge() -> void:
	if is_instance_valid(_bridge):
		_bridge.enabled = false
		_bridge.queue_free()
	_bridge = null


func _copy_settings(settings: CameraTransition) -> CameraTransition:
	return settings.duplicate(true) as CameraTransition if settings != null else null


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var names: Array[StringName] = []
	for child in get_children():
		if child is Camera2D:
			var key := StringName(child.name)
			if child is ManagedCamera2D and child.camera_name != &"":
				key = child.camera_name
			if key in names:
				warnings.append("Duplicate camera name: %s" % key)
			names.append(key)
	if names.is_empty():
		warnings.append("Add Camera2D, ManagedCamera2D or FollowCamera2D children.")
	if initial_camera != &"" and initial_camera not in names:
		warnings.append("Initial Camera does not match a child camera name.")
	return warnings
