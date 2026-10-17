class_name AudioConfig
extends RefCounted

# Add each new sound's StringName ID and default volume in dB here.
# Use the same ID in a bank player's sound_id or an AudioManager play_* call.
# MusicManager uses the layer IDs below; adding a music layer also requires wiring it there.
# FootstepAudio assigns footstep_left/right and their _slide IDs; splatter_audio.gd uses splatter.
# IDs identify sounds in code, not asset filenames or node names. Missing IDs default to 0 dB.
const VOLUMES_DB := {
	&"townfolk_voice": 0.0,
	&"router_working": -18.0,
	&"router_broken": -16.0,
	&"jump_charge": -6.0,
	&"jump": 0.0,
	&"falling": -12.0,
	&"land": 0.0,
	&"slam_land": 0.0,
	&"spit": 0.0,
	&"spit_charge": -6.0,
	&"footstep_left": footsteps_db,
	&"footstep_right": footsteps_db,
	&"footstep_left_slide": footsteps_db,
	&"footstep_right_slide": footsteps_db,
	&"splatter": 0.0,
	&"morning": 0.0,
	&"main": 0.0,
	&"base": 6.0,
	&"birds_1": 3.0,
	&"birds_2": 3.0,
	&"evening": 12.0,
}

const footsteps_db := 12.0


static func volume_db(sound_id: StringName) -> float:
	return float(VOLUMES_DB.get(sound_id, 0.0))

static func looped_stream(source: AudioStream) -> AudioStream:
	if source == null:
		return null
	var stream := source.duplicate() as AudioStream
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	return stream
