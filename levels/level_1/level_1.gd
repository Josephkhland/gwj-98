extends Node2D

@onready var day_cycle_lighting : DayCycleLighting2D = %DayCycleLighting2D
@onready var day_cycle_manager : DayCycleManager = $DayCycleManager

var redirect: Dictionary = {
	"sunrise": "on_sunrise_notification",
	"sunset": "on_sunset_notification"
}

func _on_day_cycle_manager_notification(keyword: StringName, values: Dictionary) -> void:
	# Routes notifications to the appropriate methods
	call(redirect[keyword], values)

func on_sunrise_notification(parameters:Dictionary):
	day_cycle_lighting.sunrise()
	pass

func on_sunset_notification(parameters:Dictionary):
	day_cycle_lighting.sunset()
	pass
