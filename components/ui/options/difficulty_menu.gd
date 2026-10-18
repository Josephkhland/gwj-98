extends CanvasLayer
var _return_focus: Control

var menu


func _ready() -> void:
	menu = get_parent()
	hide()
	%Back.pressed.connect(close)
	%EasyButton.pressed.connect(func(): start_game(0))
	%NormalButton.pressed.connect(func(): start_game(1))
	%HardButton.pressed.connect(func(): start_game(2))
	%ImpossibleButton.pressed.connect(func(): start_game(3))


func start_game(difficulty: int) -> void:
	close()
	menu.on_start_pressed(difficulty)


func open(launcher: Control = null) -> void:
	_return_focus = launcher
	show()


func close() -> void:
	hide()
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
