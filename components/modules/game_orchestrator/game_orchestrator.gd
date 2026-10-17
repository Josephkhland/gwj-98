class_name GameOrchestrator
extends Node
## Runs one playthrough: loads levels in order, wires level signals to the HUD, and hosts
## pausing, repair minigames and day summaries. Levels and UI never reference each other.
signal exit_requested

const PAUSE_LOADING := &"loading"
const PAUSE_MENU := &"menu"
const PAUSE_SUMMARY := &"summary"
## HUD widgets shown per level phase; every other widget is hidden.
const PHASE_WIDGETS := {
	GameLevel.Phase.WAKING: [&"day_title", &"prompt", &"minimap", &"spit_gauge"],
	GameLevel.Phase.ON_SHIFT: [&"shift_clock", &"score", &"message_feed", &"minimap", &"prompt", &"spit_gauge"],
	GameLevel.Phase.AFTER_HOURS: [&"score", &"message_feed", &"minimap", &"prompt", &"spit_gauge"],
	GameLevel.Phase.COMPLETED: [],
}
## Minimap markers per phase. The network (routers, houses, links) only shows on shift.
const PHASE_MAP_MARKERS := {
	GameLevel.Phase.WAKING: [GameLevel.MARKER_BED, GameLevel.MARKER_CLOCK_IN],
	GameLevel.Phase.ON_SHIFT: [],
	GameLevel.Phase.AFTER_HOURS: [GameLevel.MARKER_BED],
	GameLevel.Phase.COMPLETED: [],
}

@export var gameplay_settings: GameplaySettings = GameplaySettings.new()
@export_range(0.0, 2.0, 0.05) var fade_seconds: float = 0.4

@onready var progress: ProgressManager = $ProgressManager
@onready var loader: LevelLoader = $LevelLoader
@onready var pause: PauseController = $PauseController
@onready var gameplay_ui: GameplayUI = $GameplayUI
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var day_summary: DaySummary = $DaySummary
@onready var minigame_layer: Node = $MinigameLayer
@onready var fade: ColorRect = $TransitionLayer/Fade

var _level: GameLevel
var _credits: Node
var _minigame: Node
var _minigame_router: SignalNetworkRouter
var _repair_suspension: RepairSuspension

func _ready() -> void:
	loader.progress_manager = progress
	gameplay_ui.hide()
	pause_menu.hide()
	day_summary.hide()
	pause_menu.resume_requested.connect(_close_pause_menu)
	pause_menu.quit_requested.connect(_quit)
	day_summary.continue_requested.connect(_on_summary_continue)

func start_run(level_index: int = 0) -> void:
	progress.start_run(level_index)
	_load_current_level()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel") or event.is_echo():
		return
	if pause.has(PAUSE_MENU):
		_close_pause_menu()
	elif _level != null and _minigame == null and not pause.has(PAUSE_SUMMARY) and not pause.has(PAUSE_LOADING):
		pause.push(PAUSE_MENU)
		pause_menu.open()
	else:
		return
	get_viewport().set_input_as_handled()

func _load_current_level() -> void:
	var definition := progress.get_current_level()
	if definition == null:
		push_error("GameOrchestrator: no level to load.")
		_quit()
		return
	pause.push(PAUSE_LOADING)
	await _fade_to(1.0)
	pause.pop(PAUSE_SUMMARY)
	day_summary.hide()
	gameplay_ui.hide()
	_level = null
	if definition.scene_kind == LevelDefinition.SceneKind.CREDITS:
		await _load_credits(definition)
		return
	var level: GameLevel = await loader.load_level(definition)
	if level == null:
		_quit()
		return
	_level = level
	if not definition.title.is_empty():
		level.level_title = definition.title
	_wire_level(level)
	# Frame-1 state comes from a snapshot taken after wiring, so nothing emitted during
	# the level's _ready is missed and nothing needs to be re-emitted.
	gameplay_ui.reset()
	gameplay_ui.apply_snapshot(level.get_hud_snapshot())
	_apply_phase(level.phase)
	gameplay_ui.show()
	pause.pop(PAUSE_LOADING)
	level.begin()
	await _fade_to(0.0)

func _load_credits(definition: LevelDefinition) -> void:
	await loader.unload_current()
	gameplay_ui.reset()
	var scene := load(definition.scene_path) as PackedScene
	if scene == null:
		push_error("GameOrchestrator: could not load credits scene '%s'." % definition.scene_path)
		_quit()
		return
	_credits = scene.instantiate()
	if not _credits.has_signal(&"closed"):
		push_error("GameOrchestrator: credits scene must expose closed().")
		_credits.free()
		_credits = null
		_quit()
		return
	_credits.connect(&"closed", _quit)
	loader.container.add_child(_credits)
	pause.pop(PAUSE_LOADING)
	await _fade_to(0.0)

## Connections live on the level's signals, so they disappear when the level is freed.
func _wire_level(level: GameLevel) -> void:
	level.phase_changed.connect(_apply_phase)
	level.minigame_requested.connect(_open_minigame)
	level.level_completed.connect(_on_level_completed)
	_connect_widget(level.prompt_changed, &"prompt", &"set_prompt")
	_connect_widget(level.clock_changed, &"shift_clock", &"set_clock")
	_connect_widget(level.score_changed, &"score", &"set_score")
	_connect_widget(level.message_changed, &"message_feed", &"update_message")
	var player := level.get_player()
	if player.has_signal(&"spit_charges_changed"):
		_connect_widget(Signal(player, &"spit_charges_changed"), &"spit_gauge", &"set_charges")
	# Health stays unwired while the player can't die; HealthWidget.set_health
	# matches the player's health_changed signal when it's needed.

func _connect_widget(source: Signal, widget_id: StringName, method: StringName) -> void:
	var widget := gameplay_ui.get_widget(widget_id)
	if widget != null:
		source.connect(Callable(widget, method))

func _apply_phase(phase: GameLevel.Phase) -> void:
	gameplay_ui.show_only(PHASE_WIDGETS.get(phase, []))
	var minimap := gameplay_ui.get_widget(&"minimap") as MinimapWidget
	if minimap != null:
		minimap.set_layers(phase == GameLevel.Phase.ON_SHIFT, PHASE_MAP_MARKERS.get(phase, []))

func _open_minigame(router: SignalNetworkRouter) -> void:
	if _minigame != null or router.minigame_scene == null:
		router.resolve_repair(false)
		return
	var instance := router.minigame_scene.instantiate()
	if not instance.has_signal(&"completed"):
		push_error("Router minigame root must expose completed(success: bool).")
		instance.free()
		router.resolve_repair(false)
		return
	_minigame = instance
	_minigame_router = router
	router.configure_minigame(instance)
	instance.add_to_group(&"signal_network_repair_session")
	instance.connect(&"completed", _finish_minigame, CONNECT_ONE_SHOT)
	instance.tree_exiting.connect(_finish_minigame.bind(false), CONNECT_ONE_SHOT)
	_repair_suspension = RepairSuspension.new()
	_repair_suspension.group = gameplay_settings.repair_pause_group
	instance.add_child(_repair_suspension)
	gameplay_ui.hide()
	minigame_layer.add_child(instance)

func _finish_minigame(success: bool) -> void:
	if _minigame == null:
		return
	var router := _minigame_router
	var final_power: Variant = _minigame.get("powered") if _minigame.has_method(&"configure_router") else null
	_minigame = null
	_minigame_router = null
	if is_instance_valid(_repair_suspension):
		_repair_suspension.release()
	_repair_suspension = null
	gameplay_ui.show()
	if is_instance_valid(router):
		router.resolve_repair(success, final_power)

func _on_level_completed(report: DayReport) -> void:
	report.level_id = progress.get_current_level().id
	progress.add_report(report)
	pause.push(PAUSE_SUMMARY)
	gameplay_ui.hide()
	var caption := ""
	if progress.has_next() and progress.level_sequence[progress.current_index + 1].scene_kind == LevelDefinition.SceneKind.CREDITS:
		caption = "Credits"
	day_summary.show_report(report, progress.get_run_score(), progress.has_next(), caption)

func _on_summary_continue() -> void:
	if progress.advance():
		_load_current_level()
	else:
		_quit()

func _close_pause_menu() -> void:
	pause_menu.close()
	pause.pop(PAUSE_MENU)

func _quit() -> void:
	if is_instance_valid(_minigame):
		var instance := _minigame
		_finish_minigame(false)
		instance.queue_free()
	pause.clear()
	exit_requested.emit()

func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade, ^"color:a", alpha, fade_seconds)
	await tween.finished
