extends "res://components/modules/network/minigame/directed_repair_minigame.gd"
## Tutorial-only power cycling on the production repair scene and hand animation.
signal power_toggled(presses: int, powered: bool)
var presses: int = 0
var required_presses: int = 2
var explanation_finished: bool = false
var _power_label: Label
var _continue_button: Button

func _ready() -> void:
	super._ready()
	$UI/ThoughtBubble.hide()
	$UI/ExitButton.hide()
	$UI/ExitHint.set_hint("[action:ui_cancel] Cancel inspection")
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	column.position = Vector2(-220, 100)
	column.custom_minimum_size.x = 440
	_ui.add_child(column)
	_power_label = Label.new()
	_power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_power_label.add_theme_font_size_override("font_size", 26)
	column.add_child(_power_label)
	_continue_button = Button.new()
	_continue_button.text = "Finish inspection"
	_continue_button.pressed.connect(func(): finish(true))
	column.add_child(_continue_button)
	refresh_power()

func _exit_inspection() -> void:
	finish(false)

func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name != &"press" or not _pressing:
		return
	presses += 1
	super._on_animation_finished(animation_name)
	refresh_power()
	power_toggled.emit(presses, powered)

func refresh_power() -> void:
	if _power_label == null:
		return
	_power_label.text = "POWER: %s   |   Button presses: %d" % ["ON" if powered else "OFF", presses]
	_continue_button.disabled = not (explanation_finished and powered and presses >= required_presses)
