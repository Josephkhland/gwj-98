class_name MessageScoringRule
extends Resource
## Points for a message delivered some game minutes after it was transmitted.
## The curve maps delay / expire_minutes (0..1) to the share of points kept;
## without a curve the share drops linearly to zero at expiry.
@export var decay: Curve

func score(points: int, delay_minutes: float, expire_minutes: float) -> int:
	if delay_minutes <= 0.0:
		return points
	if expire_minutes <= 0.0 or delay_minutes >= expire_minutes:
		return 0
	var ratio := delay_minutes / expire_minutes
	var share := decay.sample_baked(ratio) if decay != null else 1.0 - ratio
	return roundi(points * clampf(share, 0.0, 1.0))
