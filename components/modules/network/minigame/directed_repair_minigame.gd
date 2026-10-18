extends CanvasLayer
## All nodes and animations are authored in DirectedRepairMinigame.tscn.
signal completed(success: bool)

@export_range(0.0, 2.0) var hand_approach_duration: float = 0.12
@export_range(0.01, 2.0) var press_duration: float = 0.18
@export var hand_offscreen_margin: Vector2 = Vector2(60, 60)
## Keep the resting fingertip clear of the cursor; presses still reach the button.
@export var hand_hover_offset: Vector2 = Vector2(90, 100)
@export_range(1.0, 60.0) var hand_follow_sharpness: float = 12.0
@export var powered: bool = true
@export var broken: bool = true
@export_range(0.0, 10.0, 0.1) var power_blink_seconds: float = 2.0
@onready var _power_light: Control = $UI/PowerPanel/Margin/Column/Light
@onready var _power_status: Label = $UI/PowerPanel/Margin/Column/Status
@onready var _ui: Control = $UI
@onready var _button: TextureButton = $UI/ActionButton
@onready var _hand: Node2D = $UI/Hand
@onready var _aim: Node2D = $UI/Hand/Aim
@onready var _motion: Node2D = $UI/Hand/Aim/Motion
@onready var _tip: Marker2D = $UI/Hand/Aim/Motion/Fingertip
@onready var _animations: AnimationPlayer = $AnimationPlayer
@onready var _bubble_texture: TextureRect = $UI/ThoughtBubble/Background
@onready var _bubble_fallback: Panel = $UI/ThoughtBubble/Fallback
@onready var _bubble_tail: Polygon2D = $UI/ThoughtBubble/Fallback/Tail
@onready var _image: TextureRect = $UI/ThoughtBubble/Content/Column/Image
var _approach: Tween
var _pressing: bool = false
var _finished: bool = false
var _power_blink_left: float = 0.0
var _pressed_texture: Texture2D
var _exit_armed: bool = false

func _ready() -> void:
	# Only the hand's contact animates the button, rather than also on mouse-down.
	_pressed_texture = _button.texture_pressed
	_button.texture_pressed = _button.texture_normal
	_bubble_fallback.visible = _bubble_texture.texture == null
	_bubble_tail.visible = _bubble_fallback.visible
	_image.visible = _image.texture != null
	_button.pivot_offset = _button.size / 2.0
	_on_ui_resized()
	_animations.play(&"idle")
	_button.grab_focus()
	_refresh_power_indicator()

func configure_router(is_powered: bool, is_broken: bool) -> void:
	powered = is_powered
	broken = is_broken
	_power_blink_left = 0
	if is_node_ready():
		_refresh_power_indicator()

func _refresh_power_indicator() -> void:
	$RouterAudio.set_status(powered, not broken)
	_power_light.on = powered
	_power_light.blinking = powered and not broken and _power_blink_left > 0
	_power_light.color_on = Color("ef665d") if broken else Color("66e680")
	_power_light.queue_redraw()
	_power_status.text = "POWER OFF" if not powered else ("BROKEN" if broken else "ONLINE")

func _process(delta: float) -> void:
	if not Input.is_action_pressed(&"interact"):
		_exit_armed = true
	if _power_blink_left > 0:
		_power_blink_left = maxf(0, _power_blink_left - delta)
		if _power_blink_left == 0:
			_refresh_power_indicator()
	if not _pressing and not _finished:
		var goal := (_ui.get_local_mouse_position() + hand_hover_offset).clamp(Vector2.ZERO, _ui.size)
		var tip_position := _ui.get_global_transform().affine_inverse() * _tip.global_position
		var weight := 1.0 - exp(-hand_follow_sharpness * delta)
		_place_hand(tip_position.lerp(goal, weight))

func _aim_at(target: Vector2) -> void:
	var direction := _ui.size + hand_offscreen_margin - target
	if not direction.is_zero_approx():
		# The fingertip is the origin; the arm extends toward its off-screen shoulder.
		_aim.rotation = direction.angle()

func _place_hand(point: Vector2) -> void:
	_aim_at(point)
	var tip_position := _ui.get_global_transform().affine_inverse() * _tip.global_position
	_hand.position += point - tip_position

func _on_ui_resized() -> void:
	if not is_node_ready() or _pressing:
		return
	_place_hand((_ui.get_local_mouse_position() + hand_hover_offset).clamp(Vector2.ZERO, _ui.size))

func _on_button_resized() -> void:
	if is_node_ready():
		_button.pivot_offset = _button.size / 2.0

func _on_action_pressed() -> void:
	if _pressing or _finished:
		return
	_pressing = true
	_button.disabled = true
	_animations.play(&"RESET")
	_animations.advance(0.0)
	_animations.stop()
	# Aim and translate the hand so the authored Fingertip marker touches
	# the button center. Scene transforms support resized/replaced hand art.
	var target := _ui.get_global_transform().affine_inverse() * (_button.get_global_transform() * (_button.size / 2.0))
	_aim_at(target)
	var tip_position := _ui.get_global_transform().affine_inverse() * _tip.global_position
	var contact_position := _hand.position + target - tip_position
	_approach = create_tween()
	_approach.tween_property(_hand, "position", contact_position, hand_approach_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_approach.tween_callback(_play_press)

func _play_press() -> void:
	if not _finished:
		_button.texture_disabled = _pressed_texture if _pressed_texture != null else _button.texture_normal
		var duration := _animations.get_animation(&"press").length
		_animations.play(&"press", -1.0, duration / maxf(0.01, press_duration))

func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"press" and _pressing:
		powered = not powered
		_power_blink_left = power_blink_seconds if powered else 0.0
		if powered:
			broken = false
		_pressing = false
		_button.disabled = false
		_button.texture_disabled = _button.texture_normal
		_animations.play(&"idle")
		_refresh_power_indicator()

func _unhandled_input(event: InputEvent) -> void:
	if _exit_armed and event.is_action_pressed(&"interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_exit_inspection()

func _exit_inspection() -> void:
	finish(powered and not broken)

func finish(success: bool) -> void:
	if _finished:
		return
	_finished = true
	$RouterAudio.stop()
	_button.disabled = true
	set_process(false)
	if _approach != null and _approach.is_valid():
		_approach.kill()
	_animations.stop()
	completed.emit(success)
	queue_free()
