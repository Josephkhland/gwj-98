class_name HudWidget
extends Control
## Base for optional HUD pieces. GameplayUI finds widgets by widget_id and shows or hides them;
## each widget fills itself from the level snapshot and then from its own setter methods.
@export var widget_id: StringName = &""

## First-frame state from GameLevel.get_hud_snapshot(); ignore keys the widget doesn't use.
func apply_snapshot(_snapshot: Dictionary) -> void:
	pass

## Clears per-level state before a new level is shown.
func reset() -> void:
	pass
