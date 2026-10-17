extends Node2D
signal closed
const BlockScene = preload("res://components/ui/credits/CreditBlock.tscn")
@export_file("*.txt") var attribution_file: String = "res://attribution.txt"
@export_range(5, 100, 1) var scroll_speed: float = 28
@export_range(20, 150, 1) var block_gap: float = 62
@export_range(600, 1600, 20) var playfield_width: float = 1160
@export_group("Final Thank You")
@export_range(1, 20, 0.5) var ending_hold_seconds: float = 5
@export_range(0.2, 5, 0.1) var ending_shake_seconds: float = 1.2
@export_range(100, 2000, 50) var ending_fall_gravity: float = 900
enum Ending { SCROLLING, HOLDING, SHAKING, FALLING }
@onready var _room: Control = $Playfield
@onready var player: CharacterBody2D = $Playfield/PlatformerCharacter
@onready var _blocks: Node2D = $Playfield/Blocks
var entries: Array[Dictionary] = []
var scroll_paused: bool = false
var _final_block: Node
var _ending: Ending = Ending.SCROLLING
var _ending_elapsed: float = 0
var _fall_speed: float = 0
var _loop_count: int = 0
var _standing_block: Node
var _previous_fall_speed: float = 0
var _closing: bool = false
var _background: StyleBoxFlat

func _ready() -> void:
	player.settings = player.settings.duplicate()
	player.settings.die_when_squeezed = false
	_background = StyleBoxFlat.new()
	_background.bg_color = Color("17323b")
	_background.set_corner_radius_all(28)
	_background.border_color = Color("365953")
	_background.set_border_width_all(2)
	_layout()
	_load_entries()
	_build_blocks()
	_reset_player()
	$UI/Back.pressed.connect(close)
	$UI/PauseScroll.toggled.connect(func(value):
		scroll_paused = value
		$UI/PauseScroll.text = "Resume scroll" if value else "Pause scroll")
	get_viewport().size_changed.connect(_layout)

func _load_entries() -> void:
	entries = [{"role": "CREDITS", "name": ProjectSettings.get_setting("application/config/name", "") }]
	if not FileAccess.file_exists(attribution_file):
		push_error("Credits attribution file is missing: " + attribution_file)
		return
	for source in FileAccess.get_file_as_string(attribution_file).split("\n"):
		var line := source.strip_edges()
		if line.is_empty() or line.begins_with("|Role|"):
			continue
		if line.begins_with("|"):
			var cells := line.split("|", false)
			if cells.size() >= 3 and not cells[0].strip_edges().begins_with("-"):
				entries.append({"role": cells[0].strip_edges(), "name": cells[1].strip_edges(), "quote": cells[2].strip_edges()})
		elif line.begins_with("#"):
			entries.append({"role": "WITH THANKS", "name": line.trim_prefix("#").strip_edges()})
		elif line.contains(" - "):
			var parts := line.split(" - ", false, 2)
			entries.append({"role": parts[0], "name": parts[1] if parts.size() > 1 else "", "link": parts[2] if parts.size() > 2 else ""})
		else:
			entries.append({"name": line})
	entries.append({"name": "Made for Godot Wild Jam 98"})
	entries.append({"name": "Thank you for playing!"})

func _build_blocks() -> void:
	var next_y := _room.size.y - 230
	for index in entries.size():
		var block = BlockScene.instantiate()
		_blocks.add_child(block)
		block.configure(entries[index], index, minf(720, _room.size.x - 96))
		block.base_y = next_y
		block.base_x = _block_x(index, block.card_size.x)
		var spacing: float = block.card_size.y + block_gap
		next_y -= spacing
		block.advance(0, 0, false, _room.size.y)
	_final_block = _blocks.get_child(_blocks.get_child_count() - 1)
	_final_block.base_x = _room.size.x * 0.5
	_final_block.advance(0, 0, false, _room.size.y)

func _block_x(index: int, width: float) -> float:
	var sway := minf(150, maxf(0, (_room.size.x - width) * 0.5 - 28))
	return _room.size.x * 0.5 + sin(index * 2.1) * sway

func _layout() -> void:
	var viewport_size := get_viewport_rect().size
	$UI.size = viewport_size
	var width := minf(playfield_width, viewport_size.x - 64)
	var old_height := _room.size.y
	_room.position = Vector2((viewport_size.x - width) * 0.5, 140)
	_room.size = Vector2(width, maxf(260, viewport_size.y - 280))
	_set_boundary("Floor", Vector2(width * 0.5, _room.size.y - 16), Vector2(width, 32))
	_set_boundary("Ceiling", Vector2(width * 0.5, -20), Vector2(width + 80, 40))
	_set_boundary("Left", Vector2(-20, _room.size.y * 0.5), Vector2(40, _room.size.y + 80))
	_set_boundary("Right", Vector2(width + 20, _room.size.y * 0.5), Vector2(40, _room.size.y + 80))
	for index in _blocks.get_child_count():
		var block = _blocks.get_child(index)
		block.set_width(minf(720, width - 96), index)
		block.base_x = width * 0.5 if block == _final_block else _block_x(index, block.card_size.x)
		block.base_y += _room.size.y - old_height
	if _final_block != null and _ending in [Ending.HOLDING, Ending.SHAKING]:
		_final_block.base_y = _room.size.y * 0.5
	queue_redraw()

func _set_boundary(path: String, center: Vector2, dimensions: Vector2) -> void:
	var collision: CollisionShape2D = _room.get_node("Bounds/" + path)
	collision.position = center
	var shape := RectangleShape2D.new()
	shape.size = dimensions
	collision.shape = shape

func _physics_process(delta: float) -> void:
	if _closing:
		return
	var occupied: Node
	if player.is_on_floor():
		for index in player.get_slide_collision_count():
			var collision := player.get_slide_collision(index)
			var collider := collision.get_collider() as Node
			if collider != null and collider.get_parent() == _blocks and collision.get_normal().dot(Vector2.UP) > 0.65:
				occupied = collider
				break
	if occupied != null and occupied != _standing_block:
		occupied.land(_previous_fall_speed)
	_standing_block = occupied
	_previous_fall_speed = maxf(0, player.velocity.y)
	_advance_ending(0.0 if scroll_paused else delta)
	for block in _blocks.get_children():
		var speed := 0.0 if scroll_paused or (block == _final_block and _ending != Ending.SCROLLING) else scroll_speed
		block.advance(delta, speed, block == occupied, _room.size.y)
		block.visible = block.base_y - block.card_size.y * 0.5 <= _room.size.y + 40
	var local_player := _room.get_global_transform().affine_inverse() * player.global_position
	if not Rect2(Vector2(-24, -24), _room.size + Vector2(48, 48)).has_point(local_player) or player.health <= 0:
		_reset_player()

func _advance_ending(delta: float) -> void:
	if _final_block == null or delta <= 0:
		return
	match _ending:
		Ending.SCROLLING:
			if _final_block.base_y + scroll_speed * delta >= _room.size.y * 0.5:
				_final_block.base_y = _room.size.y * 0.5
				_final_block.base_x = _room.size.x * 0.5
				_ending = Ending.HOLDING
				_ending_elapsed = 0
		Ending.HOLDING:
			_ending_elapsed += delta
			if _ending_elapsed >= ending_hold_seconds:
				_ending = Ending.SHAKING
				_ending_elapsed = 0
		Ending.SHAKING:
			_ending_elapsed += delta
			var strength := lerpf(2, 9, clampf(_ending_elapsed / ending_shake_seconds, 0, 1))
			_final_block.base_x = _room.size.x * 0.5 + sin(_ending_elapsed * 55) * strength
			if _ending_elapsed >= ending_shake_seconds:
				_ending = Ending.FALLING
				_fall_speed = 0
		Ending.FALLING:
			_fall_speed += ending_fall_gravity * delta
			_final_block.base_y += _fall_speed * delta
			if _final_block.base_y - _final_block.card_size.y * 0.5 > _room.size.y + 40:
				_restart_roll()

func _restart_roll() -> void:
	_loop_count += 1
	_ending = Ending.SCROLLING
	_ending_elapsed = 0
	_fall_speed = 0
	_standing_block = null
	var next_y := _room.size.y * 0.5
	for index in _blocks.get_child_count():
		var block = _blocks.get_child(index)
		if index == 0:
			block.configure({"name": "Here we go again..."}, index, minf(720, _room.size.x - 96))
		block.base_x = _room.size.x * 0.5 if block == _final_block else _block_x(index, block.card_size.x)
		block.base_y = next_y
		block.dip = 0
		block.dip_velocity = 0
		block.visible = true
		block.advance(0, 0, false, _room.size.y)
		block.reset_physics_interpolation()
		next_y -= block.card_size.y + block_gap

func _reset_player() -> void:
	player._cancel_spit_charge()
	player._detach()
	player.position = Vector2(_room.size.x * 0.5, _room.size.y - 56)
	player.velocity = Vector2.ZERO
	player.health = player.settings.maximum_health
	player.state_machine.transition(player.State.IN_AIR, true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	if _closing:
		return
	_closing = true
	if closed.get_connections().is_empty():
		get_tree().change_scene_to_file("res://main.tscn")
	else:
		closed.emit()

func _draw() -> void:
	draw_rect(get_viewport_rect(), Color("0d1c24"))
	if _background != null:
		_background.draw(get_canvas_item(), Rect2(_room.position - Vector2(2, 2), _room.size + Vector2(4, 4)))
		draw_rect(Rect2(_room.position + Vector2(0, _room.size.y - 32), Vector2(_room.size.x, 32)), Color("294b48"))
