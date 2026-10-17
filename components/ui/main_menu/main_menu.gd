class_name MainMenu
extends CanvasLayer
## Title screen. Debug builds also show a day picker to start the run from any level.
signal start_requested(level_index: int)
signal quit_requested
@onready var _title: Label = %TitleLabel
@onready var _start: Button = %StartButton
@onready var _quit: Button = %QuitButton
@onready var _day_row: Control = %DayRow
@onready var _day_picker: SpinBox = %DayPicker

func _ready() -> void:
	_title.text = ProjectSettings.get_setting("application/config/name", "")
	_day_row.visible = OS.is_debug_build()
	_start.pressed.connect(_on_start_pressed)
	_quit.pressed.connect(quit_requested.emit)
	_start.grab_focus()

func open() -> void:
	show()
	_start.grab_focus()

func _on_start_pressed() -> void:
	start_requested.emit(int(_day_picker.value) - 1 if _day_row.visible else 0)
