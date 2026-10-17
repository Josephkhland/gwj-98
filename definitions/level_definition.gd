class_name LevelDefinition
extends Resource
## One entry of the run's level sequence. Day-cycle settings stay on the level's own DayCycleManager.
enum SceneKind { GAME_LEVEL, CREDITS }
@export var scene_kind: SceneKind = SceneKind.GAME_LEVEL
@export var id: StringName = &""
## Shown in the HUD and day summary; falls back to the level's own level_title when empty.
@export var title: String = ""
@export_file("*.tscn") var scene_path: String = ""
