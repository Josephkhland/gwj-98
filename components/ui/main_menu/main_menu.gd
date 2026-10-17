class_name MainMenu
extends CanvasLayer
## Title screen. Shared settings are presented in the Options overlay.
signal start_requested(level_index: int)
signal tutorial_requested
signal credits_requested
signal quit_requested
@onready var _title: Label = %TitleLabel
@onready var _start: Button = %StartButton
@onready var _quit: Button = %QuitButton

func _ready() -> void:
	_title.text = ProjectSettings.get_setting("application/config/name", "")
	_start.pressed.connect(_on_start_pressed)
	_quit.pressed.connect(quit_requested.emit)
	%TutorialButton.pressed.connect(tutorial_requested.emit)
	%CreditsButton.pressed.connect(credits_requested.emit)
	%OptionsButton.pressed.connect(func(): $OptionsMenu.open(%OptionsButton))
	_start.grab_focus()

func open() -> void:
	$OptionsMenu.close()
	show()
	_start.grab_focus()

func _on_start_pressed() -> void:
	start_requested.emit(0)
