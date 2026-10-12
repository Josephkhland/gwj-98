extends HudWidget
## Level title shown at the start of the day, fading out after a moment.
@export var hold_seconds: float = 3.0
@export var fade_seconds: float = 1.0
@onready var _label: Label = %TitleLabel
var _fade: Tween

func apply_snapshot(snapshot: Dictionary) -> void:
	_label.text = snapshot.get("title", "")
	if _fade != null:
		_fade.kill()
	_label.modulate.a = 1.0
	_fade = create_tween()
	_fade.tween_property(_label, ^"modulate:a", 0.0, fade_seconds).set_delay(hold_seconds)
