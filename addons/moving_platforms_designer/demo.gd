extends Node2D
@onready var ping_pong = $PingPong
@onready var wrap = $Wrap
@onready var instructions: Label = $CanvasLayer/Instructions

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#172632"))

func _process(_delta: float) -> void:
	instructions.text = "Moving platforms: edit MovementPath, Sprite2D and CollisionShape2D
Top: ping-pong   Bottom: disappear/wrap
R: reverse both   Space: pause/resume
Direction: %s / %s" % [
		"reversed" if ping_pong.reversed else "forward",
		"reversed" if wrap.reversed else "forward"
	]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_R:
		ping_pong.reverse_direction()
		wrap.reverse_direction()
	elif event.physical_keycode == KEY_SPACE:
		ping_pong.running = not ping_pong.running
		wrap.running = not wrap.running
