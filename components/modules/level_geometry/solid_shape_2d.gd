@tool
class_name SolidShape2D
extends StaticBody2D
## Level geometry drawn from its "Collision" CollisionPolygon2D child: a filled polygon with an
## outlined edge. Edit that child's polygon in the editor; the visuals follow.
## Sticky shapes also sit on the character's sticky layer, so their walls and undersides can be clung to.
const WORLD_LAYER := 1
const STICKY_LAYER := 8
@export var sticky: bool = false:
	set(value):
		sticky = value
		collision_layer = WORLD_LAYER | (STICKY_LAYER if sticky else 0)
		_refresh()
@export var fill_color: Color = Color(0.3, 0.33, 0.4):
	set(value):
		fill_color = value
		_refresh()
@export var outline_color: Color = Color(0.8, 0.84, 0.9):
	set(value):
		outline_color = value
		_refresh()
@export var sticky_outline_color: Color = Color(0.45, 0.95, 0.55):
	set(value):
		sticky_outline_color = value
		_refresh()
@export_range(0.0, 32.0, 0.5) var outline_width: float = 4.0:
	set(value):
		outline_width = value
		_refresh()
var _fill: Polygon2D
var _outline: Line2D
var _source: PackedVector2Array
var _source_transform := Transform2D.IDENTITY

func _ready() -> void:
	_fill = Polygon2D.new()
	add_child(_fill, false, Node.INTERNAL_MODE_FRONT)
	_outline = Line2D.new()
	_outline.closed = true
	_outline.joint_mode = Line2D.LINE_JOINT_ROUND
	add_child(_outline, false, Node.INTERNAL_MODE_FRONT)
	# Only the editor needs to follow polygon edits.
	set_process(Engine.is_editor_hint())
	_refresh()

func _process(_delta: float) -> void:
	var collision := _get_collision()
	if collision != null and (collision.polygon != _source or collision.transform != _source_transform):
		_refresh()

func _refresh() -> void:
	if _fill == null:
		return
	var collision := _get_collision()
	_source = collision.polygon if collision != null else PackedVector2Array()
	_source_transform = collision.transform if collision != null else Transform2D.IDENTITY
	_fill.transform = _source_transform
	_fill.polygon = _source
	_fill.color = fill_color
	_outline.transform = _source_transform
	_outline.points = _source
	_outline.width = outline_width
	_outline.default_color = sticky_outline_color if sticky else outline_color
	_outline.visible = outline_width > 0.0

func _get_collision() -> CollisionPolygon2D:
	return get_node_or_null(^"Collision") as CollisionPolygon2D
