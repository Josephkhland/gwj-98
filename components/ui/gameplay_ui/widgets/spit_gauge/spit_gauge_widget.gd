extends HudWidget
## Spit ammo as a round flask of lime liquid. Whole charges plus recharge progress set the level,
## spending drains it smoothly with a slosh, and while a charged spit is held the slice that
## firing would spend pulses. The level is read from the player each frame; charge counts arrive
## through set_charges (the player's spit_charges_changed signal).
@export var drain_speed: float = 1.5
@export var slosh_decay: float = 1.5
@onready var _flask: ColorRect = %Flask
@onready var _count: Label = %CountLabel
var _material: ShaderMaterial
var _player: Object
var _maximum: int = 1
var _shown_fill: float = 1.0
var _slosh: float = 0.0

func _ready() -> void:
	_material = _flask.material as ShaderMaterial

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_shown_fill = move_toward(_shown_fill, _player.call(&"get_spit_fill_ratio"), drain_speed * delta)
	_slosh = move_toward(_slosh, 0.0, slosh_decay * delta)
	var drain := float(_player.call(&"get_pending_spit_cost")) / float(_maximum)
	_material.set_shader_parameter(&"fill", _shown_fill)
	_material.set_shader_parameter(&"drain", minf(drain, _shown_fill))
	_material.set_shader_parameter(&"slosh", _slosh)

func set_charges(current: int, maximum: int) -> void:
	_maximum = maxi(maximum, 1)
	_count.text = "%d/%d" % [current, maximum]
	_material.set_shader_parameter(&"segments", _maximum)
	_slosh = 1.0

func apply_snapshot(snapshot: Dictionary) -> void:
	var player: Object = snapshot.get("player")
	if player == null or not player.has_method(&"get_spit_fill_ratio"):
		_player = null
		return
	_player = player
	set_charges(player.get(&"spit_charges"), player.call(&"get_spit_maximum_charges"))
	_shown_fill = player.call(&"get_spit_fill_ratio")
	_slosh = 0.0

func reset() -> void:
	_player = null
