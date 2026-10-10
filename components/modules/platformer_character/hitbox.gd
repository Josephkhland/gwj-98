extends Area2D
## One hit per receiving actor per swing, including actors entering mid-swing.
var active: bool = false
var damage: int = 0
var impulse: Vector2 = Vector2.ZERO
var source: Node
var _hit_receivers: Dictionary = {}

func _ready() -> void:
	area_entered.connect(_try_hit)

func begin_swing(new_damage: int, new_impulse: Vector2, attacker: Node) -> void:
	damage = new_damage
	impulse = new_impulse
	source = attacker
	_hit_receivers.clear()
	active = true

func end_swing() -> void:
	active = false

func _physics_process(_delta: float) -> void:
	if active:
		for area in get_overlapping_areas():
			_try_hit(area)

func _try_hit(area: Area2D) -> void:
	if not active or area.get_parent() == source or not area.has_method("receive_hit"):
		return
	var receiver: Node = area.get_parent()
	if _hit_receivers.has(receiver.get_instance_id()):
		return
	_hit_receivers[receiver.get_instance_id()] = true
	area.receive_hit(damage, impulse, source)
