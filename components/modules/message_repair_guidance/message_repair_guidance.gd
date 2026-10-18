extends Node2D
## World-space counterparts of the minimap's repair guidance. Added by GameLevel.
const RIBBON = preload("res://components/ui/gameplay_ui/widgets/message_feed/MessageRibbonEntry.tscn")
const WARNING_ICON: Texture2D = preload("res://assets/nicoichu/Software_Warning_Sign_Triangle_Exclaimation_Mark_Error.png")
@export_range(60.0, 600.0, 10.0) var ripple_radius: float = 500.0
@export_range(0.5, 10.0, 0.1) var ripple_duration: float = 5
var message_board: MessageBoard
var day_cycle: DayCycleManager
var _stacks: Dictionary = {}
var _ribbons: Array[Control] = []
var _time: float = 0.0

func _ready() -> void:
	z_index = 25
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	message_board.repair_guidance_changed.connect(_rebuild)
	AccessibilitySettings.router_message_hints_changed.connect(_refresh_visibility)
	_rebuild()

func _rebuild() -> void:
	for stack: Control in _stacks.values():
		stack.hide()
		stack.queue_free()
	_stacks.clear()
	_ribbons.clear()
	for message in message_board.get_repair_messages():
		for router in message.get_repair_routers():
			var stack: VBoxContainer = _stacks.get(router)
			if stack == null:
				stack = VBoxContainer.new()
				stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
				stack.add_theme_constant_override("separation", 4)
				add_child(stack)
				_stacks[router] = stack
			var ribbon := RIBBON.instantiate() as Control
			ribbon.repair_hint = true
			ribbon.custom_minimum_size = Vector2(128, 36)
			stack.add_child(ribbon)
			_make_unshaded_and_passive(ribbon)
			ribbon.bind_message(message, day_cycle.get_elapsed_game_seconds())
			_ribbons.append(ribbon)
	_refresh_visibility()
	_position_stacks()
	queue_redraw()

func _make_unshaded_and_passive(node: Node) -> void:
	if node is CanvasItem:
		node.material = material
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_make_unshaded_and_passive(child)

func _refresh_visibility() -> void:
	for stack: Control in _stacks.values():
		stack.visible = AccessibilitySettings.show_router_message_hints

func _position_stacks() -> void:
	for router: SignalNetworkRouter in _stacks:
		var stack: VBoxContainer = _stacks[router]
		if not is_instance_valid(router):
			stack.hide()
			continue
		var extent := stack.get_combined_minimum_size()
		stack.size = extent
		stack.position = to_local(router.global_position) - Vector2(extent.x / 2.0, 58.0 + extent.y)

func _process(delta: float) -> void:
	_time += delta
	_position_stacks()
	if AccessibilitySettings.show_router_message_hints:
		for ribbon in _ribbons:
			ribbon.set_game_time(day_cycle.get_elapsed_game_seconds())
			ribbon.advance_visual(delta)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(message_board):
		return
	var marks := message_board.get_repair_marks()
	for router in marks:
		if not is_instance_valid(router) or not router is SignalNetworkRouter:
			continue
		var message: NetworkMessage = marks[router]
		for ring in 3:
			var progress := fposmod(_time / maxf(0.1, ripple_duration) + ring / 3.0, 1.0)
			var color := message.get_guidance_color()
			color.a = sqrt(1.0 - progress) * 0.85
			draw_arc(to_local(router.global_position), lerpf(24.0, ripple_radius, progress), 0, TAU, 80, color, 3.0, true)
	var senders: Dictionary = {}
	for message in message_board.get_repair_messages():
		if message.state != NetworkMessage.State.PENDING:
			continue
		var sender: SignalNetworkVertex = message.repair_path.front()
		var previous: NetworkMessage = senders.get(sender)
		if previous == null or message.deadline_seconds < previous.deadline_seconds:
			senders[sender] = message
	for sender in senders:
		if not is_instance_valid(sender):
			continue
		var message: NetworkMessage = senders[sender]
		var alpha := message.get_warning_alpha()
		var point := to_local(sender.global_position) + Vector2(20, -42)
		draw_texture_rect(WARNING_ICON, Rect2(point, Vector2(28, 28)), false, Color(message.get_guidance_color(), alpha))
