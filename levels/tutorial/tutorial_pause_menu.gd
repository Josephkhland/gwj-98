extends PauseMenu

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"pause") and not event.is_echo():
		get_viewport().set_input_as_handled()
		resume_requested.emit()
