class_name DayCycleManager
extends Node
## Independent clock. Lighting and gameplay systems consume notification signals.
signal notification(keyword: StringName, values: Dictionary)
signal day_started(day: int)
signal day_ended(day: int)
signal time_changed(day: int, game_seconds: float)
signal running_changed(running: bool)

const GAME_DAY_SECONDS := 86400.0
var real_seconds_per_day: float = 1200.0:
	set(value):
		if is_finite(value) and value > 0.0:
			real_seconds_per_day = value
@export_group("Measured Day")
## HH:MM or HH:MM:SS. Equal start/end means a full 24-hour day.
@export var day_start_time: String = "00:00":
	set(value):
		if _parse_clock(value) >= 0.0:
			day_start_time = value
		else:
			push_warning("Day start must be HH:MM or HH:MM:SS (00:00 through 23:59:59).")
@export var day_end_time: String = "00:00":
	set(value):
		if _parse_clock(value) >= 0.0:
			day_end_time = value
		else:
			push_warning("Day end must be HH:MM or HH:MM:SS (00:00 through 23:59:59).")
## Real minutes allocated to the entire configured start-to-end span.
@export_range(0.001, 1440.0, 0.1, "or_greater") var real_minutes_per_day: float = 20.0:
	get:
		return real_seconds_per_day / 60.0
	set(value):
		real_seconds_per_day = value * 60.0
@export_group("Playback")
@export var schedule: DayCycleSchedule
@export var autostart: bool = false
@export var repeat_days: bool = true
# Compatibility for earlier scenes/scripts; new scenes use day_start_time.
var initial_game_seconds: float = -1.0

var day: int = 1
var running: bool = false
var _time: float = 0.0
var _last_ticks: int = 0
var _advancing: bool = false
var _include_current: bool = true
var _schedule_version: int = 0

func _ready() -> void:
	_time = _start_seconds() if initial_game_seconds < 0.0 else _clamp_clock(initial_game_seconds)
	_last_ticks = Time.get_ticks_usec()
	if autostart:
		start()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		_last_ticks = Time.get_ticks_usec()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var elapsed := (now - _last_ticks) / 1000000.0
	_last_ticks = now
	if running:
		advance_real_seconds(elapsed)

## Start resumes; stop freezes both clock and real-time schedule.
func start() -> void:
	if running or (not repeat_days and _time >= _end_seconds()):
		return
	_last_ticks = Time.get_ticks_usec()
	running = true
	running_changed.emit(true)

func stop() -> void:
	if running:
		running = false
		running_changed.emit(false)

func get_game_seconds() -> float:
	return fposmod(_time, GAME_DAY_SECONDS)

func get_time() -> Dictionary:
	var whole := int(_time) % int(GAME_DAY_SECONDS)
	return {"day": day, "hour": whole / 3600, "minute": (whole % 3600) / 60, "second": whole % 60}

func get_time_string() -> String:
	var clock := get_time()
	return "%02d:%02d:%02d" % [clock.hour, clock.minute, clock.second]

func get_game_seconds_until_day_end() -> float:
	return maxf(0.0, _end_seconds() - _time)

## Active real seconds required at the current rate, excluding pauses.
func get_real_seconds_until_day_end() -> float:
	return get_game_seconds_until_day_end() * real_seconds_per_day / get_game_seconds_per_day()

func get_day_progress() -> float:
	return clampf((_time - _start_seconds()) / get_game_seconds_per_day(), 0.0, 1.0)

## Loading does not rewind. Past entries are ignored; entries at now are eligible.
## Edit a Resource then reload it to apply changes reliably.
func load_schedule(value: DayCycleSchedule) -> void:
	schedule = value
	_schedule_version += 1
	_include_current = true

func clear_schedule() -> void:
	load_schedule(null)

## Reset is silent: no crossed notifications. Call start separately to resume.
func reset(game_seconds: float = -1.0, day_number: int = 1) -> void:
	if _advancing or not is_finite(game_seconds):
		return
	stop()
	day = maxi(1, day_number)
	_time = _start_seconds() if game_seconds < 0.0 else _clamp_clock(game_seconds)
	_include_current = true
	time_changed.emit(day, get_game_seconds())

## Deterministic manual tick for simulations; requires start().
func advance_real_seconds(seconds: float) -> void:
	if running:
		_advance(seconds * get_game_seconds_per_day() / real_seconds_per_day, false)

## Forward-only skips work while stopped and preserve running state.
func skip_game_seconds(seconds: float) -> void:
	_advance(seconds, true)

func skip_real_seconds(seconds: float) -> void:
	skip_game_seconds(seconds * get_game_seconds_per_day() / real_seconds_per_day)

func _advance(amount: float, skipped: bool) -> void:
	if _advancing or not is_finite(amount) or amount < 0.0 or (not repeat_days and _time >= _end_seconds()):
		return
	_advancing = true
	var remaining := amount
	while true:
		var target := minf(_time + remaining, _end_seconds())
		var previous := _time
		var include_start := _include_current
		_include_current = false
		var version := _schedule_version
		var entries: Array[Dictionary] = []
		if schedule != null:
			for entry in schedule.notifications:
				if entry == null:
					continue
				var at := entry.get_game_seconds(real_seconds_per_day, _start_seconds(), get_game_seconds_per_day())
				if at < _start_seconds() or at > _end_seconds() or not is_finite(at):
					continue
				if (at > previous or (include_start and at == previous)) and at <= target:
					entries.append({"at": at, "keyword": entry.keyword, "values": entry.get_payload(), "fire": entry.fire_on_skip, "order": entries.size()})
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a.at == b.at:
				return a.order < b.order
			return a.at < b.at)
		for entry in entries:
			if version != _schedule_version:
				break
			_time = entry.at
			if not skipped or entry.fire:
				notification.emit(entry.keyword, entry.values)
			if not skipped and not running:
				break
		if not skipped and not running:
			break
		_time = target
		remaining -= target - previous
		if _time < _end_seconds():
			break
		day_ended.emit(day)
		if not repeat_days:
			stop()
			break
		day += 1
		_time = _start_seconds()
		_include_current = true
		day_started.emit(day)
		if not skipped and not running:
			break
		# Visit the next start time even when no time remains, so zero-time entries fire once.
		if remaining < 0.0:
			break
	time_changed.emit(day, get_game_seconds())
	_advancing = false

## Length of the measured span in game seconds (supports overnight spans).
func get_game_seconds_per_day() -> float:
	var span := fposmod(_parse_clock(day_end_time) - _start_seconds(), GAME_DAY_SECONDS)
	return GAME_DAY_SECONDS if span == 0.0 else span

## Clock time (seconds after midnight) at which the measured day begins.
func get_day_start_seconds() -> float:
	return _start_seconds()

## Game seconds elapsed since the measured day began; never wraps within a day.
func get_elapsed_game_seconds() -> float:
	return _time - _start_seconds()

func _start_seconds() -> float:
	return _parse_clock(day_start_time)

func _end_seconds() -> float:
	return _start_seconds() + get_game_seconds_per_day()

func _clamp_clock(seconds: float) -> float:
	var offset := fposmod(seconds - _start_seconds(), GAME_DAY_SECONDS)
	return _start_seconds() + minf(offset, get_game_seconds_per_day())

## Returns false for invalid clock text, without changing the current clock.
func reset_to_time(clock_time: String, day_number: int = 1) -> bool:
	var seconds := _parse_clock(clock_time)
	if seconds < 0.0 or _advancing:
		return false
	reset(seconds, day_number)
	return true

static func _parse_clock(value: String) -> float:
	var parts := value.split(":")
	if parts.size() != 2 and parts.size() != 3:
		return -1.0
	for part in parts:
		if part.length() != 2 or not part.is_valid_int():
			return -1.0
		for character in part:
			if character < "0" or character > "9":
				return -1.0
	var hour := int(parts[0])
	var minute := int(parts[1])
	var second := int(parts[2]) if parts.size() == 3 else 0
	if hour > 23 or minute > 59 or second > 59:
		return -1.0
	return hour * 3600.0 + minute * 60.0 + second
