class_name MusicManager
extends Node

@export var morning: AudioStream
@export var main: AudioStream
@export var base: AudioStream
@export var birds_1: AudioStream
@export var birds_2: AudioStream
@export var evening: AudioStream
@export_range(0.0, 30.0, 0.1) var base_fade_seconds: float = 2.0
@export_range(0.0, 120.0, 0.1) var birds_fade_in_seconds: float = 40.0
@export_range(0.0, 120.0, 0.1) var transition_seconds: float = 5.0
@export_range(0.0, 10.0, 0.1) var morning_crossfade_seconds: float = 0.5
@export_range(0.0, 120.0, 0.1) var morning_ambience_delay_seconds: float = 25.0
@export_range(0.0, 120.0, 0.1) var evening_lead_seconds: float = 5.0
@export_range(0.0, 120.0, 0.1) var evening_fade_seconds: float = 30.0

var _players: Dictionary = {}
var _level: GameLevel
var _begun: bool = false
var _on_shift: bool = false
var _elapsed: float = 0.0
var _shift_elapsed: float = 0.0
var _birds_at_clock_in: float = 0.0
var _last_music_position: float = 0.0
var _main_finished: bool = false
var _evening_started: bool = false
var _morning_ambience_started: bool = false
var _evening_elapsed: float = 0.0


func _ready() -> void:
	_level = get_parent() as GameLevel
	for id in [&"morning", &"main", &"base", &"birds_1", &"birds_2", &"evening"]:
		var player := AudioStreamPlayer.new()
		player.name = String(id).to_pascal_case()
		player.bus = &"Music" if id in [&"morning", &"main"] else &"Ambience"
		add_child(player)
		_players[id] = player
	var main_player: AudioStreamPlayer = _players[&"main"]
	main_player.finished.connect(func(): _main_finished = true)
	if _level != null:
		_level.phase_changed.connect(_on_phase_changed)


func _start(id: StringName, stream: AudioStream, loop: bool) -> void:
	if stream == null:
		return
	var player: AudioStreamPlayer = _players[id]
	var local := stream.duplicate() as AudioStream
	local.resource_name = stream.resource_path.get_file() if not stream.resource_path.is_empty() else stream.resource_name
	if local is AudioStreamWAV:
		local.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		if loop and local.loop_end <= local.loop_begin:
			local.loop_begin = 0
			local.loop_end = int(local.get_length() * local.mix_rate)
	elif local is AudioStreamOggVorbis or local is AudioStreamMP3:
		local.loop = loop
	player.stream = local
	player.volume_linear = 0.0
	player.play()


func _on_phase_changed(phase: GameLevel.Phase) -> void:
	match phase:
		GameLevel.Phase.WAKING:
			if _begun:
				return
			_begun = true
			_start(&"morning", morning, false)
			if morning_ambience_delay_seconds <= 0.0:
				_start_morning_ambience()
		GameLevel.Phase.ON_SHIFT:
			if _on_shift:
				return
			_on_shift = true
			_birds_at_clock_in = (
				_fade(maxf(0.0, _elapsed - morning_ambience_delay_seconds), birds_fade_in_seconds)
				if _morning_ambience_started else 0.0
			)
			_start(&"main", main, false)
		GameLevel.Phase.COMPLETED:
			_begun = false
			for player: AudioStreamPlayer in _players.values():
				player.stop()


func _process(delta: float) -> void:
	if not _begun:
		return
	_elapsed += delta
	if not _on_shift and not _morning_ambience_started and _elapsed >= morning_ambience_delay_seconds:
		_start_morning_ambience()
	var ambience_elapsed := maxf(0.0, _elapsed - morning_ambience_delay_seconds)
	var birds_gain := _fade(ambience_elapsed, birds_fade_in_seconds) if _morning_ambience_started else 0.0
	var base_gain := _fade(ambience_elapsed, base_fade_seconds) if _morning_ambience_started else 0.0
	var evening_gain := 0.0
	var morning_gain := 1.0
	if _on_shift:
		_shift_elapsed += delta
		var music_time := _shift_elapsed
		var remaining := (
			_level.day_cycle.get_real_seconds_until_day_end() if _level != null else 0.0
		)
		var player: AudioStreamPlayer = _players[&"main"]
		if player.stream != null:
			if _main_finished:
				music_time = player.stream.get_length()
			else:
				music_time = maxf(
					_last_music_position,
					player.get_playback_position() + AudioServer.get_time_since_last_mix()
				)
			_last_music_position = music_time
			remaining = maxf(0.0, player.stream.get_length() - music_time)
		birds_gain = _birds_at_clock_in * (1.0 - _fade(music_time, transition_seconds))
		base_gain *= _fade(remaining, transition_seconds)
		morning_gain = 1.0 - _fade(_shift_elapsed, morning_crossfade_seconds)
		if _evening_started:
			_evening_elapsed += delta
		elif remaining <= evening_lead_seconds:
			_evening_started = true
			_evening_elapsed = minf(delta, maxf(0.0, evening_lead_seconds - remaining))
			_start(&"evening", evening, true)
		if _evening_started:
			evening_gain = _fade(_evening_elapsed, evening_fade_seconds)
		_gain(&"main", _fade(_shift_elapsed, morning_crossfade_seconds))
	_gain(&"morning", morning_gain)
	_gain(&"base", base_gain)
	_gain(&"birds_1", birds_gain)
	_gain(&"birds_2", birds_gain)
	_gain(&"evening", evening_gain)
	if morning_gain == 0.0 or _elapsed >= 30.0:
		_players[&"morning"].stop()
	if _on_shift and birds_gain == 0.0:
		_players[&"birds_1"].stop()
		_players[&"birds_2"].stop()
	if _on_shift and base_gain == 0.0:
		_players[&"base"].stop()


func _start_morning_ambience() -> void:
	_morning_ambience_started = true
	_start(&"base", base, true)
	_start(&"birds_1", birds_1, true)
	_start(&"birds_2", birds_2, true)


func _gain(id: StringName, gain: float) -> void:
	var player: AudioStreamPlayer = _players[id]
	player.volume_linear = gain * db_to_linear(AudioConfig.volume_db(id))


func _fade(seconds: float, duration: float) -> float:
	return (
		clampf(seconds / duration, 0.0, 1.0) if duration > 0.0 else (1.0 if seconds > 0.0 else 0.0)
	)
