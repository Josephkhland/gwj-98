class_name PauseMenu
extends CanvasLayer
## Pause overlay. Runs while the tree is paused; the orchestrator owns the actual pausing.
signal resume_requested
signal quit_requested
@onready var _options: Button = %OptionsButton
@onready var _quit: Button = %QuitButton

func _ready() -> void:
	_quit.pressed.connect(quit_requested.emit)
	_options.pressed.connect(func(): $OptionsMenu.open(_options))

func open() -> void:
	show()
	_options.grab_focus()

func close() -> void:
	$OptionsMenu.close()
	hide()
