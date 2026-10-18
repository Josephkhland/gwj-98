@tool
extends Node2D
## Unlit attack rays and countdown/recovery bar, independent of the state artwork.
const Flashes = preload("res://components/modules/network/objects/router_attack_flash_pattern.gd")
@export_range(64.0, 400.0, 8.0) var ray_radius: float = 128.0
@onready var _bar: ProgressBar = $ProgressBar

func _ready() -> void:
	_bar.add_theme_stylebox_override("fill", _bar.get_theme_stylebox("fill").duplicate())
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	var router := get_parent() as SignalNetworkRouter
	if router == null:
		return
	visible = router.state in [SignalNetworkRouter.State.BEING_ATTACKED, SignalNetworkRouter.State.ATTACK_INTERRUPTED]
	_bar.value = router.get_attack_progress()
	var fill := _bar.get_theme_stylebox("fill") as StyleBoxFlat
	fill.bg_color = Color("66e680") if router.state == SignalNetworkRouter.State.ATTACK_INTERRUPTED else Color("ffb347")
	queue_redraw()

func _draw() -> void:
	var router := get_parent() as SignalNetworkRouter
	if router == null or router.state != SignalNetworkRouter.State.BEING_ATTACKED:
		return
	var elapsed := 0.12 if Engine.is_editor_hint() else router.get_attack_elapsed()
	for flash in Flashes.get_flashes(elapsed, router.get_instance_id()):
		var points := Flashes.make_ray(float(flash.angle), ray_radius * 0.375, ray_radius)
		var color := Color("ffb347").lerp(Color("ff5950"), float(flash.heat))
		color.a = float(flash.alpha)
		draw_polyline(points, color, 3.0, true)
