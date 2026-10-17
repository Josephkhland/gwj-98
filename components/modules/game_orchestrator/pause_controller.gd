class_name PauseController
extends Node
## Keeps the tree paused while any reason is held, so overlapping pauses
## (pause menu, summary, loading) can't unpause each other.
signal paused_changed(paused: bool)
var _reasons: Dictionary[StringName, bool] = {}

func push(reason: StringName) -> void:
	_reasons[reason] = true
	_apply()

func pop(reason: StringName) -> void:
	_reasons.erase(reason)
	_apply()

func has(reason: StringName) -> bool:
	return _reasons.has(reason)

func clear() -> void:
	_reasons.clear()
	_apply()

func _exit_tree() -> void:
	if not _reasons.is_empty():
		clear()

func _apply() -> void:
	var paused := not _reasons.is_empty()
	if get_tree().paused != paused:
		get_tree().paused = paused
		paused_changed.emit(paused)
