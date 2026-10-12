class_name DayReport
extends RefCounted
## Outcome of one completed level (day), shown in the day summary and kept for the run total.
var level_id: StringName = &""
var title: String = ""
var score: int = 0
var delivered_on_time: int = 0
var delivered_late: int = 0
var expired: int = 0
var routers_repaired: int = 0

func get_message_count() -> int:
	return delivered_on_time + delivered_late + expired
