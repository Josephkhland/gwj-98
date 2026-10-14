class_name GameplaySettings
extends Resource
## Game-wide rules that are still being decided; tweak on the GameOrchestrator.
## Nodes in this group (and their children) freeze during repairs; audio keeps playing.
@export var repair_pause_group: StringName = &"pause_during_repairs"
