class_name VoiceSoundBank
extends SoundBank
## A segmented recording of short voice blips, using the existing SoundBank slicing.
@export_range(0.25, 3.0, 0.01) var pitch_min: float = 0.95
@export_range(0.25, 3.0, 0.01) var pitch_max: float = 1.05

func random_pitch() -> float:
	return randf_range(minf(pitch_min, pitch_max), maxf(pitch_min, pitch_max))
