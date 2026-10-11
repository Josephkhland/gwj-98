class_name CameraTransition
extends Resource
## Reusable Inspector-editable transition settings.

enum Mode { INSTANT, PAN }

@export var mode: Mode = Mode.INSTANT
@export_range(0.0, 60.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.75
## Optional progress curve: X is normalized time, Y is interpolation weight.
## Endpoints are forced to 0 and 1; intermediate weights are clamped to [0, 1].
@export var curve: Curve
@export var easing: Tween.EaseType = Tween.EASE_IN_OUT
@export var transition: Tween.TransitionType = Tween.TRANS_SINE


func weight(progress: float) -> float:
	if progress <= 0.0 or progress >= 1.0:
		return clampf(progress, 0.0, 1.0)
	if curve != null:
		return clampf(curve.sample_baked(progress), 0.0, 1.0)
	return Tween.interpolate_value(0.0, 1.0, progress, 1.0, transition, easing)
