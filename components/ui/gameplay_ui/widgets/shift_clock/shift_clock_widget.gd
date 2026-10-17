extends HudWidget
## Workday clock: current time, when the shift ends, and how far through the shift it is.
@onready var _time: Label = %TimeLabel
@onready var _shift_end: Label = %ShiftEndLabel
@onready var _progress: ProgressBar = %ShiftProgress

func set_clock(time_text: String, shift_end_text: String, progress: float) -> void:
	_time.text = time_text
	_shift_end.text = "Shift ends %s" % shift_end_text
	_progress.value = progress

func apply_snapshot(snapshot: Dictionary) -> void:
	set_clock(snapshot.get("time", ""), snapshot.get("shift_end", ""), snapshot.get("progress", 0.0))
