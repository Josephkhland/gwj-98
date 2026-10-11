class_name DayCycleNotification
extends Resource
## A daily notification. Real seconds are measured from the beginning of the day.
enum TimeBasis { GAME_CLOCK, REAL_SECONDS }
@export var keyword: StringName = &"event"
@export var values: Dictionary = {}
@export var time_basis: TimeBasis = TimeBasis.GAME_CLOCK
@export_range(0, 23, 1) var hour: int = 10
@export_range(0, 59, 1) var minute: int = 30
@export_range(0.0, 59.999) var second: float = 0.0
@export_range(0.0, 86400.0, 0.1, "or_greater") var real_seconds: float = 180.0
@export var fire_on_skip: bool = false

func get_game_seconds(day_duration: float, start_seconds: float = 0.0, span_seconds: float = 86400.0) -> float:
	if time_basis == TimeBasis.REAL_SECONDS:
		return start_seconds + real_seconds * span_seconds / day_duration
	return start_seconds + fposmod(hour * 3600.0 + minute * 60.0 + second - start_seconds, 86400.0)
