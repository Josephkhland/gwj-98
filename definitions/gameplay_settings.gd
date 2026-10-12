class_name GameplaySettings
extends Resource
## Game-wide rules that are still being decided; tweak on the GameOrchestrator.
## When false, the level stays paused during repair minigames but its clock keeps running.
@export var freeze_clock_during_repairs: bool = true
