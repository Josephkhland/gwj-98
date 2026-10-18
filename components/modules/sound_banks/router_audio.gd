extends Node2D
## World emitters are spatial. Inspection emitters play directly while other routers mute.
@export var spatial: bool = true
@export var working_stream: AudioStream = preload("res://assets/cabalcrow/working-router.ogg")
@export var broken_stream: AudioStream = preload("res://assets/cabalcrow/broken-router.ogg")
@export_range(50, 1500, 10) var hearing_distance: float = 360
## Relative to the configured sound volume. Keep the hum audible at the outer edge.
@export_range(-40.0, 0.0, 1.0) var edge_volume_db: float = -12.0
## Supplied by GameLevel so all world routers follow its live ripple radius.
var ripple_radius_source: Node2D
var _player: Node
var _working_loop: AudioStream
var _broken_loop: AudioStream

func _ready() -> void:
	_working_loop = AudioConfig.looped_stream(working_stream)
	_broken_loop = AudioConfig.looped_stream(broken_stream)
	_player = AudioStreamPlayer2D.new() if spatial else AudioStreamPlayer.new()
	_player.bus = &"Ambience"
	if spatial:
		_player.max_distance = get_hearing_distance() + 1.0
		# Distance volume is applied below; built-in attenuation would mute the edge.
		_player.attenuation = 0.0
	add_child(_player)

func _process(_delta: float) -> void:
	if not spatial:
		return
	var router := get_parent()
	var inspecting := get_tree().has_group(&"signal_network_repair_session")
	set_status(router.powered and not inspecting, router.is_available())

func set_status(powered: bool, working: bool) -> void:
	if _player == null:
		return
	if not powered:
		stop()
		return
	var stream := _working_loop if working else _broken_loop
	if _player.stream != stream:
		_player.stream = stream
	_player.volume_db = AudioConfig.volume_db(&"router_working" if working else &"router_broken")
	if spatial:
		var radius := get_hearing_distance()
		_player.max_distance = radius + 1.0
		var viewport := get_viewport()
		var listener := viewport.get_audio_listener_2d()
		var listener_position := listener.global_position if listener != null else viewport.get_canvas_transform().affine_inverse() * (viewport.get_visible_rect().size / 2.0)
		var distance := global_position.distance_to(listener_position)
		if distance > radius:
			stop()
			return
		_player.volume_db += lerpf(0.0, edge_volume_db, clampf(distance / radius, 0.0, 1.0))
	if stream != null and not _player.playing:
		_player.play()

func get_hearing_distance() -> float:
	if is_instance_valid(ripple_radius_source):
		return maxf(1.0, float(ripple_radius_source.get("ripple_radius")))
	return maxf(1.0, hearing_distance)

func stop() -> void:
	if _player != null:
		_player.stop()
