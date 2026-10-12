class_name ProgressManager
extends Node
## Runtime progression for the current run: the active level, what comes next, and the
## reports of finished days. Nothing here is written to disk.
signal level_changed(index: int, definition: LevelDefinition)
@export var level_sequence: Array[LevelDefinition] = []
var current_index: int = -1
var reports: Array[DayReport] = []

func start_run(start_index: int = 0) -> void:
	reports.clear()
	_set_index(clampi(start_index, 0, maxi(level_sequence.size() - 1, 0)))

func get_current_level() -> LevelDefinition:
	if current_index < 0 or current_index >= level_sequence.size():
		return null
	return level_sequence[current_index]

func has_next() -> bool:
	return current_index + 1 < level_sequence.size()

func advance() -> bool:
	if not has_next():
		return false
	_set_index(current_index + 1)
	return true

func add_report(report: DayReport) -> void:
	reports.append(report)

func get_run_score() -> int:
	var total := 0
	for report in reports:
		total += report.score
	return total

func _set_index(index: int) -> void:
	current_index = index
	level_changed.emit(index, get_current_level())
