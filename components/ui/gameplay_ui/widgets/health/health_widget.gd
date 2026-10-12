extends HudWidget
## Player health bar. Not shown or wired while the player can't die; set_health matches
## the player's health_changed(current, maximum) signal.
@onready var _bar: ProgressBar = %HealthBar

func set_health(current: int, maximum: int) -> void:
	_bar.max_value = maxi(maximum, 1)
	_bar.value = current

func apply_snapshot(snapshot: Dictionary) -> void:
	if snapshot.has("health"):
		set_health(snapshot.health, snapshot.get("max_health", snapshot.health))
