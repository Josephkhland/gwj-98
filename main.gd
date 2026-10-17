extends Node
## Entry point: shows the main menu and hosts a GameOrchestrator while a run is active.
const GAME_ORCHESTRATOR := preload("res://components/modules/game_orchestrator/GameOrchestrator.tscn")
const CREDITS := preload("res://components/ui/credits/Credits.tscn")

@onready var main_menu: MainMenu = $MainMenu
var _orchestrator: GameOrchestrator
var _credits: Node2D

func _ready() -> void:
	main_menu.start_requested.connect(_start_run)
	main_menu.tutorial_requested.connect(_start_tutorial)
	main_menu.credits_requested.connect(_open_credits)
	main_menu.quit_requested.connect(get_tree().quit)

func _start_run(level_index: int) -> void:
	_launch_game(level_index, false)

func _start_tutorial() -> void:
	_launch_game(0, true)

func _launch_game(level_index: int, tutorial: bool) -> void:
	if _orchestrator != null or _credits != null:
		return
	main_menu.hide()
	_orchestrator = GAME_ORCHESTRATOR.instantiate()
	_orchestrator.exit_requested.connect(_end_run)
	add_child(_orchestrator)
	if tutorial:
		_orchestrator.progress.level_sequence.assign([load("res://resources/levels/tutorial.tres")])
	_orchestrator.start_run(level_index)

func _open_credits() -> void:
	if _orchestrator != null or _credits != null:
		return
	main_menu.hide()
	_credits = CREDITS.instantiate()
	_credits.closed.connect(_close_credits)
	add_child(_credits)

func _close_credits() -> void:
	_credits.queue_free()
	_credits = null
	main_menu.open()
	main_menu.get_node("%CreditsButton").grab_focus()

func _end_run() -> void:
	_orchestrator.queue_free()
	_orchestrator = null
	main_menu.open()
