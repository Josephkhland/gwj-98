class_name DaySummary
extends CanvasLayer
## End-of-day screen: the day's DayReport plus the run total. Runs while the tree is paused.
signal continue_requested
@onready var _title: Label = %TitleLabel
@onready var _stats: Label = %StatsLabel
@onready var _run_total: Label = %RunTotalLabel
@onready var _continue: Button = %ContinueButton

func _ready() -> void:
	_continue.pressed.connect(continue_requested.emit)

func show_report(report: DayReport, run_score: int, has_next: bool, continue_caption: String = "") -> void:
	_title.text = "%s complete" % (report.title if not report.title.is_empty() else "Day")
	_stats.text = "\n".join([
		"Delivered on time: %d" % report.delivered_on_time,
		"Delivered late: %d" % report.delivered_late,
		"Expired: %d" % report.expired,
		"Routers repaired: %d" % report.routers_repaired,
		"Day score: %d" % report.score,
	])
	_run_total.text = "Run total: %d" % run_score
	_continue.text = continue_caption if not continue_caption.is_empty() else ("Next day" if has_next else "Back to menu")
	show()
	_continue.grab_focus()
