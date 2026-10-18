extends Node2D
## Movement cues follow real state transitions and contacts, not raw button presses.
@export var jump_charge: AudioStream = preload("res://assets/cabalcrow/charge.mp3")
@export var jump: AudioStream = preload("res://assets/cabalcrow/jump.mp3")
@export var falling: AudioStream = preload("res://assets/cabalcrow/falling.ogg")
@export var land_bank: SoundBank = preload("res://resources/sound_banks/land_bank.tres")
@export var slam_land: AudioStream = preload("res://assets/cabalcrow/slam-land-layer.mp3")
@export var spit: AudioStream = preload("res://assets/cabalcrow/spit.mp3")
@export var spit_charge: AudioStream = preload("res://assets/cabalcrow/spit-charge.mp3")
var _character: CharacterBody2D
var _charge: AudioStreamPlayer2D
var _spit_charge: AudioStreamPlayer2D
var _fall: AudioStreamPlayer2D
var _was_grounded: bool = false
var _had_support: bool = false
var _falling: bool = false
var _slam_landed: bool = false

func _ready() -> void:
	process_physics_priority = 200
	_character = get_parent() as CharacterBody2D
	if land_bank != null:
		land_bank.prepare()
	_charge = _make_player(jump_charge, &"jump_charge", true)
	_spit_charge = _make_player(spit_charge, &"spit_charge", true)
	_fall = _make_player(falling, &"falling", false)
	_fall.play()
	_character.state_changed.connect(_on_state_changed)
	_character.spit_fired.connect(func(_projectile, _ratio): _play_one_shot(spit, &"spit", 0.05))
	_character.slam_impacted.connect(_on_slam_landed)
	_character.get_node("AudioListener2D").make_current()

func _make_player(stream: AudioStream, id: StringName, loop: bool) -> AudioStreamPlayer2D:
	var player := AudioStreamPlayer2D.new()
	player.name = String(id).to_pascal_case()
	player.stream = AudioConfig.looped_stream(stream) if loop else stream
	player.bus = &"SFX"
	player.volume_db = AudioConfig.volume_db(id)
	player.max_distance = 900
	add_child(player)
	return player

func _play_one_shot(stream: AudioStream, id: StringName, pitch_randomness := 0.0, db_change := 0.0) -> void:
	if stream == null:
		return
	var player := _make_player(stream, id, false)
	player.finished.connect(player.queue_free)
	if pitch_randomness != 0.0:
		player.pitch_scale *= 1 + randf_range(-pitch_randomness, 1 / (1 - pitch_randomness))
	player.volume_db += db_change
	player.play()

func _set_loop(player: AudioStreamPlayer2D, active: bool) -> void:
	if active and player.stream != null:
		if not player.playing:
			player.play()
	else:
		player.stop()

func _refresh_loops() -> void:
	var active := not get_tree().has_group(&"signal_network_repair_session")
	_set_loop(_charge, active and _character.state == _character.State.CHARGING)
	_set_loop(_spit_charge, active and _character.state == _character.State.CHARGING_SPIT)

func _on_state_changed(previous: int, current: int) -> void:
	_refresh_loops()
	if previous == _character.State.CHARGING and current == _character.State.JUMPING:
		_had_support = true
		_play_one_shot(jump, &"jump", 0.05)

func _physics_process(_delta: float) -> void:
	_refresh_loops()
	var grounded: bool = _character.is_grounded()
	_fall.volume_db = AudioConfig.volume_db("falling") + minf(abs(_character.velocity.y), 1000.0) * 0.1

	if grounded:
		if not _was_grounded and not _slam_landed:
			_play_landing()
		_had_support = true
		# _falling = false
		# _fall.stop()
	elif _character.state in [_character.State.ON_WALL, _character.State.SLAMMING] or _character.velocity.y < -20:
		pass
		# _falling = false
		# _fall.stop()
	elif _had_support and _character.velocity.y > 40 and not _falling:
		pass
		# _falling = true
		# if _fall.stream != null:
		# 	_fall.play()
	_was_grounded = grounded
	_slam_landed = false

func _on_slam_landed(_collider: Node, _point: Vector2, normal: Vector2) -> void:
	if normal.dot(Vector2.UP) < 0.65:
		return
	_slam_landed = true
	_play_landing()
	_play_one_shot(slam_land, &"slam_land")
	# _fall.stop()

func _play_landing() -> void:
	if land_bank != null:
		_play_one_shot(land_bank.random_clip(), &"land")

func _notification(what: int) -> void:
	if what == NOTIFICATION_DISABLED and is_node_ready():
		_charge.stop()
		_spit_charge.stop()
		# _fall.stop()
