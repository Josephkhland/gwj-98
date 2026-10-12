class_name MinimapFeed
extends RefCounted
## World references a minimap draws from. Built once by GameLevel; positions are read live.
var player: Node2D
var network_graph: SignalNetworkGraph
## CollisionShape2D / CollisionPolygon2D children of static and moving bodies, plus TileMapLayers.
var solids: Array[Node] = []
## Points of interest by marker id (GameLevel.MARKER_BED, GameLevel.MARKER_CLOCK_IN, ...).
var markers: Dictionary[StringName, Node2D] = {}
