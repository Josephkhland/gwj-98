class_name PauseMenu
extends CanvasLayer
## Pause overlay. Runs while the tree is paused; the orchestrator owns the actual pausing.
signal resume_requested
signal quit_requested
@onready var _resume: Button = %ResumeButton
@onready var _quit: Button = %QuitButton

func _ready() -> void:
	_resume.pressed.connect(resume_requested.emit)
	_quit.pressed.connect(quit_requested.emit)

func open() -> void:
	show()
	_resume.grab_focus()

func close() -> void:
	hide()
