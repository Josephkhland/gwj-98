@tool
class_name SignalNetworkVertex
extends Node2D
## Connections are undirected and stored relative to this vertex.
signal availability_changed
signal identifier_changed
## Stable, case-sensitive key for game code. Unique within the owning graph.
@export var key_identifier: StringName = &"":
	set(value):
		if key_identifier == value:
			return
		key_identifier = value
		identifier_changed.emit()
@export var display_name: String = ""
@export var connections: Array[NodePath] = []

func is_available() -> bool:
	return true

func is_house() -> bool:
	return false

func get_label() -> String:
	return display_name if not display_name.is_empty() else str(name)
