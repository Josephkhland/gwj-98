class_name LevelLoader
extends Node
## Loads level scenes in the background, adds them to the container and frees the previous one.
signal load_progress(ratio: float)
@export var container: Node
var current_level: GameLevel

## Frees the current level, then loads and adds the new one. Returns null on failure.
func load_level(definition: LevelDefinition) -> GameLevel:
	await unload_current()
	var path := definition.scene_path
	if ResourceLoader.load_threaded_request(path, "PackedScene") != OK:
		push_error("LevelLoader: could not start loading '%s'." % path)
		return null
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(path, progress)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		load_progress.emit(progress[0] if not progress.is_empty() else 0.0)
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(path, progress)
	var scene: PackedScene = null
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		scene = ResourceLoader.load_threaded_get(path) as PackedScene
	if scene == null:
		push_error("LevelLoader: failed to load '%s'." % path)
		return null
	load_progress.emit(1.0)
	var instance := scene.instantiate()
	var level := instance as GameLevel
	if level == null:
		push_error("LevelLoader: root of '%s' must extend GameLevel." % path)
		instance.free()
		return null
	current_level = level
	container.add_child(level)
	return level

func unload_current() -> void:
	if not is_instance_valid(current_level):
		current_level = null
		return
	var level := current_level
	current_level = null
	level.queue_free()
	await level.tree_exited
