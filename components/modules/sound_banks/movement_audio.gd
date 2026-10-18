extends Node2D
## Movement cues follow real state transitions and contacts, not raw button presses.
@export var jump_charge: AudioStream = preload("res://assets/cabalcrow/charge.mp3")
@export var jump: AudioStream = preload("res://assets/cabalcrow/jump.mp3")
@export var falling: AudioStream = preload("res://assets/cabalcrow/falling.ogg")
@export var land_bank: SoundBank = preload("res://resources/sound_banks/land_bank.tres")
@export var slam_land: AudioStream = preload("res://assets/cabalcrow/slam-land-layer.mp3")
@export var spit: AudioStream = preload("res://assets/cabalcrow/spit.mp3")
@export var spit_charge: AudioStream = preload("res://assets/cabalcrow/spit-charge.mp3")
@export_group("Landing Volume")
## Speed toward the surface, in pixels/second, that reaches the configured base volume.
@export_range(1.0, 3000.0, 10.0, "or_greater") var landing_full_volume_speed: float = 900.0
## Volume adjustment for the gentlest landings; hard landings reach 0 dB adjustment.
@export_range(-60.0, 0.0, 1.0) var landing_minimum_volume_db: float = -24.0
var _character: CharacterBody2D
var _charge: AudioStreamPlayer2D
var _spit_charge: AudioStreamPlayer2D
var _fall: AudioStreamPlayer2D
var _had_support: bool = false
var _falling: bool = false

func _ready() -> void:
	process_physics_priority = 200
	_character = get_parent() as CharacterBody2D
	if land_bank != null:
		land_bank.prepare()
	_charge = _make_player(jump_charge, &"jump_charge", true)
	_spit_charge = _make_player(spit_charge, &"spit_charge", true)
	_fall = _make_player(falling, &"falling", false)
	_character.state_changed.connect(_on_state_changed)
	_character.spit_fired.connect(func(_projectile, _ratio): _play_one_shot(spit, &"spit"))
	_character.landed.connect(_on_landed)
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

func _play_one_shot(stream: AudioStream, id: StringName, volume_adjustment_db: float = 0.0) -> void:
	if stream == null:
		return
	var player := _make_player(stream, id, false)
	player.volume_db += volume_adjustment_db
	player.finished.connect(player.queue_free)
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
		_play_one_shot(jump, &"jump")

func _physics_process(_delta: float) -> void:
	_refresh_loops()
	var grounded: bool = _character.is_grounded()
	if grounded:
		_had_support = true
		_falling = false
		_fall.stop()
	elif _character.state in [_character.State.ON_WALL, _character.State.SLAMMING] or _character.velocity.y < -20:
		_falling = false
		_fall.stop()
	elif _had_support and _character.velocity.y > 40 and not _falling:
		_falling = true
		if _fall.stream != null:
			_fall.play()

func _on_landed(incoming_velocity: Vector2, normal: Vector2, was_slam: bool) -> void:
	var impact_speed := maxf(0.0, -incoming_velocity.dot(normal))
	var strength := clampf(impact_speed / maxf(1.0, landing_full_volume_speed), 0.0, 1.0)
	var volume_adjustment := lerpf(landing_minimum_volume_db, 0.0, strength)
	_play_landing(volume_adjustment)
	if was_slam:
		_play_one_shot(slam_land, &"slam_land", volume_adjustment)
	_fall.stop()

func _play_landing(volume_adjustment_db: float) -> void:
	if land_bank != null:
		_play_one_shot(land_bank.random_clip(), &"land", volume_adjustment_db)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DISABLED and is_node_ready():
		_charge.stop()
		_spit_charge.stop()
		_fall.stop()
