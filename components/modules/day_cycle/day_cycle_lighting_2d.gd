class_name DayCycleLighting2D
extends Node
## Instance once in a 2D level. Put HUD controls on a separate CanvasLayer.
signal transition_finished(transition: StringName)
enum Phase { DAY, NIGHT }
@export var initial_phase: Phase = Phase.DAY
@export_range(0.01, 60.0, 0.1, "or_greater") var transition_seconds: float = 3.0
@export_group("Lighting Colors")
## Tint used for daylight and the end of sunrise.
@export_color_no_alpha var day_color: Color = Color.WHITE
## Tint used for night and the end of sunset.
@export_color_no_alpha var night_color: Color = Color(0.22, 0.27, 0.45, 1.0)
## Warm midpoint of the sunrise transition.
@export_color_no_alpha var sunrise_color: Color = Color(1.0, 0.7, 0.5, 1.0)
## Warm midpoint of the sunset transition.
@export_color_no_alpha var sunset_color: Color = Color(1.0, 0.55, 0.35, 1.0)
@export_group("Night Lights")
@export var manage_night_lights: bool = true
@export var night_lights_group: StringName = &"night_lights"
## Each light independently chooses immediate or delayed activation.
@export_range(0.0, 1.0, 0.01) var instant_on_chance: float = 0.5
@export_range(0.0, 30.0, 0.05, "or_greater") var delay_min_seconds: float = 0.2
@export_range(0.0, 30.0, 0.05, "or_greater") var delay_max_seconds: float = 2.0
## Separate roll, applied after the optional delay; flicker ends with the light on.
@export_range(0.0, 1.0, 0.01) var flicker_chance: float = 0.1
@export_range(0.01, 1.0, 0.01, "or_greater") var flicker_min_seconds: float = 0.05
@export_range(0.01, 1.0, 0.01, "or_greater") var flicker_max_seconds: float = 0.15
var _night_lights_wanted: bool = false
var _light_tweens: Dictionary[int, Tween] = {}
var _light_rng := RandomNumberGenerator.new()
@onready var tint: CanvasModulate = $CanvasModulate
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	# Each instance owns its animation library; Resources remain designer-editable.
	var library := animation_player.get_animation_library(&"").duplicate(true) as AnimationLibrary
	animation_player.remove_animation_library(&"")
	animation_player.add_animation_library(&"", library)
	for name in [&"sunrise", &"sunset", &"day", &"night", &"RESET"]:
		_apply_palette(name)
	_light_rng.randomize()
	animation_player.animation_finished.connect(_on_transition_finished)
	set_night() if initial_phase == Phase.NIGHT else set_day()
	# Sibling lights may enter the tree after this controller during scene loading.
	call_deferred("refresh_night_lights")

func sunrise(seconds: float = -1.0) -> void:
	play_transition(&"sunrise", seconds)

func sunset(seconds: float = -1.0) -> void:
	play_transition(&"sunset", seconds)

func to_day(seconds: float = -1.0) -> void:
	play_transition(&"day", seconds)

func to_night(seconds: float = -1.0) -> void:
	play_transition(&"night", seconds)

## The first key is replaced with the current tint to prevent a visible jump.
func play_transition(name: StringName, seconds: float = -1.0) -> void:
	if not animation_player.has_animation(name) or name == &"RESET":
		push_warning("Unknown lighting transition: %s" % name)
		return
	var duration := transition_seconds if seconds < 0.0 else seconds
	if not is_finite(duration) or duration <= 0.0:
		push_warning("Lighting transition duration must be positive.")
		return
	_apply_palette(name)
	var animation := animation_player.get_animation(name)
	animation.track_set_key_value(0, 0, tint.color)
	animation_player.play(name, -1.0, animation.length / duration)
	animation_player.advance(0.0)
	if name == &"sunset" or name == &"night":
		_night_lights_wanted = true
		refresh_night_lights()

func set_day() -> void:
	_set_phase(&"day")

func set_night() -> void:
	_set_phase(&"night")

func _set_phase(name: StringName) -> void:
	animation_player.stop()
	_apply_palette(name)
	var animation := animation_player.get_animation(name)
	tint.color = animation.track_get_key_value(0, animation.track_get_key_count(0) - 1)
	_set_night_lights_immediately(name == &"night")

## Apply exported colors while preserving designer-edited key times and easing.
## Runtime color edits take effect on the next transition or instant state call.
func _apply_palette(name: StringName) -> void:
	var animation := animation_player.get_animation(name)
	var last := animation.track_get_key_count(0) - 1
	match name:
		&"sunrise":
			animation.track_set_key_value(0, 0, night_color)
			for index in range(1, last):
				animation.track_set_key_value(0, index, sunrise_color)
			animation.track_set_key_value(0, last, day_color)
		&"sunset":
			animation.track_set_key_value(0, 0, day_color)
			for index in range(1, last):
				animation.track_set_key_value(0, index, sunset_color)
			animation.track_set_key_value(0, last, night_color)
		&"day":
			animation.track_set_key_value(0, last, day_color)
		&"night":
			animation.track_set_key_value(0, last, night_color)
		&"RESET":
			animation.track_set_key_value(0, 0, day_color)

## Optional direct connection to DayCycleManager.notification.
## Payload: {"phase": "sunset", "duration": 5.0}, or {"animation": "sunrise"}.
func handle_notification(keyword: StringName, values: Dictionary) -> void:
	if keyword != &"lighting":
		return
	var name := StringName(values.get("phase", values.get("animation", "day")))
	if name == &"noon_to_sunset":
		name = &"sunset"
	elif name == &"sunset_to_night":
		name = &"night"
	play_transition(name, float(values.get("duration", transition_seconds)))

func _on_transition_finished(name: StringName) -> void:
	if name == &"sunrise" or name == &"day":
		_set_night_lights_immediately(false)
	transition_finished.emit(name)

## Call after spawning new grouped lights; existing activations are not restarted.
func refresh_night_lights() -> void:
	if not manage_night_lights or not is_inside_tree():
		return
	for light in _get_night_lights():
		if not _night_lights_wanted:
			light.enabled = false
		elif not light.enabled and not _light_tweens.has(light.get_instance_id()):
			_activate_night_light(light)

func _get_night_lights() -> Array[Light2D]:
	var lights: Array[Light2D] = []
	for node in get_tree().get_nodes_in_group(night_lights_group):
		if node is Light2D and not node.is_queued_for_deletion():
			lights.append(node)
	return lights

func _set_night_lights_immediately(enabled: bool) -> void:
	_night_lights_wanted = enabled
	_cancel_light_tweens()
	if manage_night_lights and is_inside_tree():
		for light in _get_night_lights():
			light.enabled = enabled

func _activate_night_light(light: Light2D) -> void:
	var delayed := _light_rng.randf() >= clampf(instant_on_chance, 0.0, 1.0)
	var flicker := _light_rng.randf() < clampf(flicker_chance, 0.0, 1.0)
	if not delayed and not flicker:
		light.enabled = true
		return
	var light_ref: WeakRef = weakref(light)
	var tween := create_tween()
	var id := light.get_instance_id()
	_light_tweens[id] = tween
	if delayed:
		tween.tween_interval(_random_interval(delay_min_seconds, delay_max_seconds, 0.001))
	# Three variations: one, two, or three blinks, with independently varied timing.
	if flicker:
		for blink in _light_rng.randi_range(1, 3):
			tween.tween_callback(_set_light_enabled.bind(light_ref, true))
			tween.tween_interval(_random_interval(flicker_min_seconds, flicker_max_seconds, 0.01))
			tween.tween_callback(_set_light_enabled.bind(light_ref, false))
			tween.tween_interval(_random_interval(flicker_min_seconds, flicker_max_seconds, 0.01))
	tween.tween_callback(_set_light_enabled.bind(light_ref, true))
	tween.finished.connect(func() -> void: _light_tweens.erase(id))

func _random_interval(first: float, second: float, minimum: float) -> float:
	return _light_rng.randf_range(maxf(minimum, minf(first, second)), maxf(minimum, maxf(first, second)))

func _set_light_enabled(light_ref: WeakRef, enabled: bool) -> void:
	var light := light_ref.get_ref() as Light2D
	if _night_lights_wanted and manage_night_lights and is_instance_valid(light) and light.is_inside_tree() and not light.is_queued_for_deletion() and light.is_in_group(night_lights_group):
		light.enabled = enabled

func _cancel_light_tweens() -> void:
	for tween in _light_tweens.values():
		tween.kill()
	_light_tweens.clear()

func _exit_tree() -> void:
	_cancel_light_tweens()
