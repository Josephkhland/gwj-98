class_name MinimapWidget
extends HudWidget
## Data-driven minimap centred on the player. Draws level solids (static/moving collision
## shapes and tile collisions), then either the signal network or the chosen markers.
## Markers outside the view stick to the edge so the player knows which way to go.
@export var world_units_per_pixel: float = 12.0
@export_group("Icons")
@export var gateway_icon: Texture2D = preload("res://assets/nicoichu/Software_Planet_Geography_Localization_Global_Language_Translation_1.png")
@export var router_icon: Texture2D = preload("res://assets/nicoichu/Software_Network_Router_WiFi_Wireless_Internet_Ethernet_Connection.png")
@export_range(8, 40, 1) var portrait_size: float = 20
@export_range(8, 32, 1) var network_icon_size: float = 16
@export_group("Colors")
@export var background_color: Color = Color(0.05, 0.07, 0.1, 0.8)
@export var border_color: Color = Color(1, 1, 1, 0.35)
@export var solid_color: Color = Color(0.55, 0.6, 0.68, 0.85)
@export var player_color: Color = Color(1.0, 0.9, 0.3)
@export var house_color: Color = Color(0.45, 0.75, 1.0)
@export var router_ok_color: Color = Color(0.4, 0.9, 0.5)
@export var router_broken_color: Color = Color(1.0, 0.35, 0.3)
@export var link_up_color: Color = Color(0.5, 0.85, 1.0, 0.9)
@export var link_down_color: Color = Color(1.0, 0.35, 0.3, 0.45)
@export var marker_colors: Dictionary[StringName, Color] = {&"bed": Color(0.75, 0.55, 1.0), &"clock_in": Color(1.0, 0.65, 0.25)}
var _feed: MinimapFeed
var _show_network: bool = false
var _markers: Array = []
var _tile_cache: Dictionary = {}

func _ready() -> void:
	clip_contents = true
	var settings := get_node("/root/AccessibilitySettings")
	settings.network_colors_changed.connect(_apply_network_colors)
	_apply_network_colors()

func _apply_network_colors() -> void:
	var alternate: bool = get_node("/root/AccessibilitySettings").alternate_network_colors
	router_ok_color = Color("4dd9ff") if alternate else Color("66e680")
	router_broken_color = Color("ffb347") if alternate else Color("ff5950")
	link_up_color = router_ok_color
	link_down_color = Color(router_broken_color, 0.45)
	queue_redraw()

func _process(_delta: float) -> void:
	if is_visible_in_tree() and _feed != null:
		queue_redraw()

func apply_snapshot(snapshot: Dictionary) -> void:
	_feed = snapshot.get("minimap")
	queue_redraw()

func reset() -> void:
	_feed = null
	_tile_cache.clear()
	queue_redraw()

## show_network draws routers, houses and their links; markers lists MinimapFeed marker ids.
func set_layers(show_network: bool, markers: Array) -> void:
	_show_network = show_network
	_markers = markers
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color)
	if _feed != null and is_instance_valid(_feed.player):
		var zoom := 1.0 / world_units_per_pixel
		var to_map := Transform2D(0.0, Vector2(zoom, zoom), 0.0, size / 2.0 - _feed.player.global_position * zoom)
		_draw_solids(to_map)
		if _show_network and is_instance_valid(_feed.network_graph):
			_draw_network(to_map)
		_draw_markers(to_map)
		draw_circle(size / 2.0, 4.0, player_color)
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, 1.0)

func _draw_solids(to_map: Transform2D) -> void:
	var view := Rect2(Vector2.ZERO, size)
	for solid in _feed.solids:
		if not is_instance_valid(solid) or not solid.is_inside_tree():
			continue
		var tiles := solid as TileMapLayer
		var shape := solid as CollisionShape2D
		var polygon := solid as CollisionPolygon2D
		if tiles != null:
			var layer_to_map := to_map * tiles.global_transform
			var visible_area := layer_to_map.affine_inverse() * view
			draw_set_transform_matrix(layer_to_map)
			for cell in _get_solid_cells(tiles):
				if visible_area.intersects(cell):
					draw_rect(cell, solid_color)
		elif shape != null:
			if not shape.disabled and shape.shape != null:
				draw_set_transform_matrix(to_map * shape.global_transform)
				_draw_shape(shape.shape)
		elif polygon != null:
			if not polygon.disabled and polygon.polygon.size() >= 3:
				draw_set_transform_matrix(to_map * polygon.global_transform)
				draw_colored_polygon(polygon.polygon, solid_color)
	draw_set_transform_matrix(Transform2D.IDENTITY)

## Draws in the shape's local space; the caller sets the transform.
func _draw_shape(shape: Shape2D) -> void:
	var line_width := 2.0 * world_units_per_pixel
	if shape is RectangleShape2D:
		var rectangle := shape as RectangleShape2D
		draw_rect(Rect2(-rectangle.size / 2.0, rectangle.size), solid_color)
	elif shape is CircleShape2D:
		draw_circle(Vector2.ZERO, (shape as CircleShape2D).radius, solid_color)
	elif shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		draw_rect(Rect2(-capsule.radius, -capsule.height / 2.0, capsule.radius * 2.0, capsule.height), solid_color)
	elif shape is ConvexPolygonShape2D:
		var points := (shape as ConvexPolygonShape2D).points
		if points.size() >= 3:
			draw_colored_polygon(points, solid_color)
	elif shape is ConcavePolygonShape2D:
		draw_multiline((shape as ConcavePolygonShape2D).segments, solid_color, line_width)
	elif shape is SegmentShape2D:
		var segment := shape as SegmentShape2D
		draw_line(segment.a, segment.b, solid_color, line_width)

func _draw_network(to_map: Transform2D) -> void:
	var vertices := _feed.network_graph.get_vertices()
	for vertex in vertices:
		for path in vertex.connections:
			var target := vertex.get_node_or_null(path) as SignalNetworkVertex
			if target == null or target == vertex or not vertices.has(target):
				continue
			var up := vertex.is_available() and target.is_available()
			draw_line(to_map * vertex.global_position, to_map * target.global_position, link_up_color if up else link_down_color, 2.0, true)
	for vertex in vertices:
		var point := to_map * vertex.global_position
		if vertex.is_house():
			var house := vertex as SignalNetworkHouse
			if house != null and house.is_internet_gateway() and gateway_icon != null:
				_draw_icon(gateway_icon, point, network_icon_size)
			elif house != null and house.character_profile != null and house.character_profile.portrait != null:
				_draw_icon(house.character_profile.portrait, point, portrait_size)
			else:
				draw_rect(Rect2(point - Vector2(5, 5), Vector2(10, 10)), house_color)
		else:
			var tint := router_ok_color if vertex.is_available() else router_broken_color
			if router_icon != null:
				_draw_icon(router_icon, point, network_icon_size, tint)
			else:
				draw_circle(point, 5.0, tint)

func _draw_icon(texture: Texture2D, point: Vector2, extent: float, tint: Color = Color.WHITE) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 0 or texture_size.y <= 0:
		return
	var icon_size := texture_size * (extent / maxf(texture_size.x, texture_size.y))
	draw_texture_rect(texture, Rect2(point - icon_size / 2, icon_size), false, tint)

func _draw_markers(to_map: Transform2D) -> void:
	var margin := Vector2(8, 8)
	for marker_id in _markers:
		var node: Node2D = _feed.markers.get(marker_id)
		if not is_instance_valid(node):
			continue
		var point := (to_map * node.global_position).clamp(margin, size - margin)
		draw_circle(point, 6.0, marker_colors.get(marker_id, Color.WHITE))
		draw_arc(point, 7.5, 0.0, TAU, 20, Color.WHITE, 1.5, true)

## Cells with any collision polygon, as rects in the layer's local space. Cached per layer.
func _get_solid_cells(layer: TileMapLayer) -> Array[Rect2]:
	if _tile_cache.has(layer):
		return _tile_cache[layer]
	var cells: Array[Rect2] = []
	var tile_size := Vector2(layer.tile_set.tile_size)
	for coords in layer.get_used_cells():
		var data := layer.get_cell_tile_data(coords)
		if data == null:
			continue
		for physics_layer in layer.tile_set.get_physics_layers_count():
			if data.get_collision_polygons_count(physics_layer) > 0:
				cells.append(Rect2(layer.map_to_local(coords) - tile_size / 2.0, tile_size))
				break
	_tile_cache[layer] = cells
	return cells
