extends Node
## Entry point: shows the main menu and hosts a GameOrchestrator while a run is active.
const GAME_ORCHESTRATOR := preload("res://components/modules/game_orchestrator/GameOrchestrator.tscn")

@onready var main_menu: MainMenu = $MainMenu
var _orchestrator: GameOrchestrator

func _ready() -> void:
	main_menu.start_requested.connect(_start_run)
	main_menu.quit_requested.connect(get_tree().quit)

func _start_run(level_index: int) -> void:
	if _orchestrator != null:
		return
	main_menu.hide()
	_orchestrator = GAME_ORCHESTRATOR.instantiate()
	_orchestrator.exit_requested.connect(_end_run)
	add_child(_orchestrator)
	_orchestrator.start_run(level_index)

func _end_run() -> void:
	_orchestrator.queue_free()
	_orchestrator = null
	main_menu.open()
