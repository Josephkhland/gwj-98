class_name AudioConfig
extends RefCounted

# Add each new sound's StringName ID and default volume in dB here.
# Use the same ID in a bank player's sound_id or an AudioManager play_* call.
# MusicManager uses the layer IDs below; adding a music layer also requires wiring it there.
# FootstepAudio assigns footstep_left/right and their _slide IDs; splatter_audio.gd uses splatter.
# IDs identify sounds in code, not asset filenames or node names. Missing IDs default to 0 dB.
const VOLUMES_DB := {
	&"footstep_left": -6.0,
	&"footstep_right": -6.0,
	&"footstep_left_slide": -6.0,
	&"footstep_right_slide": -6.0,
	&"splatter": 0.0,
	&"morning": 0.0,
	&"main": 0.0,
	&"base": 6.0,
	&"birds_1": 3.0,
	&"birds_2": 3.0,
	&"evening": 12.0,
}


static func volume_db(sound_id: StringName) -> float:
	return float(VOLUMES_DB.get(sound_id, 0.0))
