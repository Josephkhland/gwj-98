extends HudWidget
## Day score with a short "+points" flash when it changes.
@export var flash_seconds: float = 1.2
@onready var _score: Label = %ScoreLabel
@onready var _delta: Label = %DeltaLabel
var _flash: Tween

func set_score(total: int, delta: int = 0) -> void:
	_score.text = "Score: %d" % total
	if delta == 0:
		return
	_delta.text = "%+d" % delta
	if _flash != null:
		_flash.kill()
	_delta.modulate.a = 1.0
	_flash = create_tween()
	_flash.tween_property(_delta, ^"modulate:a", 0.0, flash_seconds).set_delay(flash_seconds * 0.5)

func apply_snapshot(snapshot: Dictionary) -> void:
	set_score(snapshot.get("score", 0))

func reset() -> void:
	if _flash != null:
		_flash.kill()
	_delta.modulate.a = 0.0
