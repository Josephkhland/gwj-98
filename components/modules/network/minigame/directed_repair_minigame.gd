extends CanvasLayer
## All nodes and animations are authored in DirectedRepairMinigame.tscn.
signal completed(success: bool)

@export_range(0.0, 2.0) var hand_approach_duration: float = 0.25
@export var hand_offscreen_margin: Vector2 = Vector2(60, 60)
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

func _ready() -> void:
	_bubble_fallback.visible = _bubble_texture.texture == null
	_bubble_tail.visible = _bubble_fallback.visible
	_image.visible = _image.texture != null
	_button.pivot_offset = _button.size / 2.0
	_on_ui_resized()
	_aim_at(_ui.get_local_mouse_position())
	_animations.play(&"idle")
	_button.grab_focus()

func _process(_delta: float) -> void:
	if not _pressing and not _finished:
		_aim_at(_ui.get_local_mouse_position())

func _aim_at(target: Vector2) -> void:
	var direction := target - _hand.position
	if not direction.is_zero_approx():
		# The authored hand points left along its local negative X axis.
		_aim.rotation = direction.angle() + PI

func _on_ui_resized() -> void:
	if not is_node_ready() or _pressing:
		return
	_hand.position = _ui.size + hand_offscreen_margin

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
		_button.texture_disabled = _button.texture_pressed if _button.texture_pressed != null else _button.texture_normal
		_animations.play(&"press")

func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"press" and _pressing:
		finish(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		finish(false)

func finish(success: bool) -> void:
	if _finished:
		return
	_finished = true
	_button.disabled = true
	set_process(false)
	if _approach != null and _approach.is_valid():
		_approach.kill()
	_animations.stop()
	completed.emit(success)
	queue_free()
