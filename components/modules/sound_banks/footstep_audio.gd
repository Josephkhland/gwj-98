class_name FootstepAudio
extends Node2D

@export var left_bank: SoundBank
@export var right_bank: SoundBank
@export var left_slide_bank: SoundBank
@export var right_slide_bank: SoundBank
@export_range(0.0, 100.0, 0.1) var slide_chance_percent: float = 15.0
var _left: SoundBankPlayer2D
var _right: SoundBankPlayer2D

func _ready() -> void:
	for bank in [left_bank, right_bank, left_slide_bank, right_slide_bank]:
		if bank != null:
			bank.prepare()
	_left = SoundBankPlayer2D.new()
	_left.sound_id = &"footstep_left"
	add_child(_left)
	_right = SoundBankPlayer2D.new()
	_right.sound_id = &"footstep_right"
	add_child(_right)
	var visual := get_parent().get_node_or_null("Visual")
	if visual != null and visual.has_signal(&"foot_contact"):
		visual.connect(&"foot_contact", _on_foot_contact)

func _can_step() -> bool:
	var character := get_parent() as CharacterBody2D
	if character == null or not character.has_method(&"is_grounded"):
		return false
	var visual := character.get_node_or_null("Visual")
	return bool(character.call(&"is_grounded")) and visual != null and visual.get("animation") == &"walking" and not is_zero_approx(character.velocity.x)

func play_left() -> void:
	if _can_step():
		var slide := left_slide_bank != null and randf() * 100.0 < slide_chance_percent
		_left.bank = left_slide_bank if slide else left_bank
		_left.sound_id = &"footstep_left_slide" if slide else &"footstep_left"
		_left.play()

func play_right() -> void:
	if _can_step():
		var slide := right_slide_bank != null and randf() * 100.0 < slide_chance_percent
		_right.bank = right_slide_bank if slide else right_bank
		_right.sound_id = &"footstep_right_slide" if slide else &"footstep_right"
		_right.play()

func _on_foot_contact(left: bool) -> void:
	if left:
		play_left()
	else:
		play_right()
