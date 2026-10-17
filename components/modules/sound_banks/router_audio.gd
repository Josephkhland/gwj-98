extends Node2D
## World emitters are spatial. Inspection emitters play directly while other routers mute.
@export var spatial: bool = true
@export var working_stream: AudioStream = preload("res://assets/cabalcrow/working-router.ogg")
@export var broken_stream: AudioStream = preload("res://assets/cabalcrow/broken-router.ogg")
@export_range(50, 1500, 10) var hearing_distance: float = 360
var _player: Node
var _working_loop: AudioStream
var _broken_loop: AudioStream

func _ready() -> void:
	_working_loop = AudioConfig.looped_stream(working_stream)
	_broken_loop = AudioConfig.looped_stream(broken_stream)
	_player = AudioStreamPlayer2D.new() if spatial else AudioStreamPlayer.new()
	_player.bus = &"Ambience"
	if spatial:
		_player.max_distance = hearing_distance
		_player.attenuation = 1.4
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
	if stream != null and not _player.playing:
		_player.play()

func stop() -> void:
	if _player != null:
		_player.stop()
