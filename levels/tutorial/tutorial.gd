extends GameLevel
## Scripted onboarding; all tutorial exceptions live under levels/tutorial.
const RepairScene = preload("res://levels/tutorial/TutorialRepair.tscn")
const IconHint = preload("res://components/ui/input_icons/input_hint_label.gd")
@export var script_lines: TownfolkDialogueChain
@export var practice_schedule: DayCycleSchedule
@export_range(10, 120, 1) var practice_shift_seconds: float = 40
@export_range(0, 10, 0.5) var network_reading_pause_seconds: float = 2
@export_group("Stay Near the Guide")
@export var return_to_guide_enabled: bool = true
@export_range(200, 4000, 10) var guide_return_distance: float = 900
@onready var guide: TownfolkCharacter = $Squirrel
@onready var hud: GameplayUI = $GameplayUI
@onready var _pause_menu: PauseMenu = $PauseMenu
@onready var workbench: InteractionZone = $RouterWorkbench
var lesson: String = ""
var _flags: Dictionary = {}
var _presented: Dictionary = {}
var _network_unlocked: bool = false
var _practice_ready: bool = false
var _bridge_lowered: bool = false
var _wood_broken: bool = false
var _checkpoint := Vector2.ZERO
var _repair: CanvasLayer
var _repair_router: SignalNetworkRouter
var _suspension: RepairSuspension
var _guide_world_position := Vector2.ZERO
var _host: GameOrchestrator
var _callout: InputHintLabel
var _callout_on_map: bool = false
var _gateway_icon: TextureRect
var _feed_bottom_margin: float = 48
var _world_arrow: InputHintLabel
var _reveal_hint: InputHintLabel
var _arrow_time: float = 0
var _stopping: bool = false

func _ready() -> void:
	super._ready()
	_checkpoint = player_spawn.global_position
	guide.global_position = _marker_position(^"GuideStops/Introduction")
	clock_in_point.global_position = _marker_position(^"EndRoom/ClockIn")
	workbench.global_position = _marker_position(^"EndRoom/PracticeTable")
	bed.global_position = _marker_position(^"EndRoom/Bed")
	InputBindings.enter_tutorial()
	# Never mutate the shared settings used by real levels.
	player.settings = player.settings.duplicate()
	player.settings.die_when_squeezed = false
	guide.listener = player
	guide.hearing_range = 40000
	guide.interaction_enabled = false
	guide.reactions_enabled = false
	guide.show_listening_tether = false
	player.state_changed.connect(_on_player_state)
	player.spit_fired.connect(_on_spit_fired)
	player.slam_impacted.connect(_on_slam_impact)
	for router in _get_routers():
		router.interact_action = &""
		var router_hint := router.get_node_or_null("HintLabel") as CanvasItem
		if router_hint != null:
			router_hint.hide()
		router.hint_label = NodePath()
		router.repair_requested.connect(_open_tutorial_repair.bind(router))
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is GameOrchestrator:
			_host = ancestor
			break
		ancestor = ancestor.get_parent()
	if _host != null:
		hud.hide()
		hud = _host.gameplay_ui
	else:
		hud.apply_snapshot(get_hud_snapshot())
		prompt_changed.connect(hud.get_widget(&"prompt").set_prompt)
		clock_changed.connect(hud.get_widget(&"shift_clock").set_clock)
		score_changed.connect(hud.get_widget(&"score").set_score)
		message_changed.connect(hud.get_widget(&"message_feed").update_message)
		player.spit_charges_changed.connect(hud.get_widget(&"spit_gauge").set_charges)
		level_completed.connect(_show_completion)
	_pause_menu.hide()
	$DaySummary.hide()
	_pause_menu.resume_requested.connect(_resume)
	_pause_menu.quit_requested.connect(_quit_tutorial)
	$DaySummary.continue_requested.connect(_quit_tutorial)
	_world_arrow = IconHint.new()
	_world_arrow.z_index = 50
	_world_arrow.add_theme_font_size_override("normal_font_size", 24)
	add_child(_world_arrow)
	_world_arrow.hide()
	_callout = IconHint.new()
	_callout.add_theme_font_size_override("normal_font_size", 22)
	_callout.add_theme_color_override("default_color", Color("ffe69b"))
	_callout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_callout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$TutorialOverlay.add_child(_callout)
	_style_hint(_callout)
	_style_hint(_world_arrow)
	_style_hint(guide.interaction_hint)
	_reveal_hint = IconHint.new()
	_reveal_hint.add_theme_font_size_override("normal_font_size", 24)
	$TutorialOverlay.add_child(_reveal_hint)
	_style_hint(_reveal_hint)
	_reveal_hint.set_hint("[action:%s] Reveal dialogue" % guide.reveal_action)
	_reveal_hint.hide()
	_gateway_icon = $TutorialOverlay/GatewayIcon
	_gateway_icon.hide()
	_gateway_icon.reparent(_callout)
	_gateway_icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_gateway_icon.position = Vector2(12, 12)
	_gateway_icon.size = Vector2(48, 48)
	_feed_bottom_margin = hud.get_widget(&"message_feed").presentation_bottom_margin
	_callout.hide()
	hud.get_widget(&"message_feed").thread_finished.connect(func(message): _presented[message] = true)
	phase_changed.connect(func(_phase): _refresh_hud.call_deferred())
	_refresh_hud.call_deferred()

func begin() -> void:
	if _begun:
		return
	_begun = true
	_set_phase(Phase.WAKING)
	_run_script.call_deferred()

func _refresh_zones() -> void:
	super._refresh_zones()
	clock_in_point.enabled = _practice_ready and phase == Phase.WAKING
	clock_in_point.visible = clock_in_point.enabled
	bed.enabled = _flags.get("bed_ready", false) and phase == Phase.AFTER_HOURS
	bed.visible = bed.enabled
	_refresh_hud.call_deferred()

func _refresh_hud() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	hud.show_only([&"prompt", &"spit_gauge", &"score", &"message_feed", &"minimap", &"shift_clock"])
	hud.set_widget_visible(&"minimap", _network_unlocked)
	hud.set_widget_visible(&"shift_clock", phase == Phase.ON_SHIFT)
	var markers: Array = []
	if clock_in_point.enabled:
		markers.append(MARKER_CLOCK_IN)
	if bed.enabled:
		markers.append(MARKER_BED)
	hud.get_widget(&"minimap").set_layers(_network_unlocked, markers)

func _process(delta: float) -> void:
	_layout_callout()
	if is_instance_valid(_reveal_hint):
		_reveal_hint.visible = guide.can_reveal_dialogue() and phase != Phase.COMPLETED
		_reveal_hint.size = _reveal_hint.get_combined_minimum_size()
		_reveal_hint.position = get_viewport_rect().size - _reveal_hint.size - Vector2(32, 100)
	_arrow_time += delta
	if is_instance_valid(_world_arrow) and _world_arrow.visible:
		_world_arrow.modulate.a = 0.75 + sin(_arrow_time * 4) * 0.25
	if phase == Phase.COMPLETED or is_instance_valid(_repair):
		return
	if player.global_position.y > (1240 if not _wood_broken else 1700) or player.global_position.x < -100:
		_respawn()
		return
	if _begun and return_to_guide_enabled and guide.visible and player.global_position.distance_squared_to(guide.global_position) > guide_return_distance * guide_return_distance:
		_teleport_player(_guide_return_position())

func _respawn() -> void:
	_teleport_player(_checkpoint)

func _guide_return_position() -> Vector2:
	# Find solid ground beside the guide rather than dropping the player inside a wall
	# or over the bridge/recoil pit while the guide is moving between lessons.
	var space := get_world_2d().direct_space_state
	var shape: CollisionShape2D = player.get_node("CollisionShape2D")
	var half_height := shape.shape.get_rect().size.y * absf(shape.global_scale.y) * 0.5
	for offset in [-80.0, 80.0, -140.0, 140.0, 0.0]:
		var origin := guide.global_position + Vector2(offset, -80)
		var query := PhysicsRayQueryParameters2D.create(origin, origin + Vector2(0, 650), player.collision_mask, [player.get_rid()])
		var hit := space.intersect_ray(query)
		if hit.is_empty() or hit.normal.dot(Vector2.UP) < cos(player.floor_max_angle):
			continue
		var destination: Vector2 = hit.position + Vector2.UP * (half_height + player.safe_margin + 2)
		if player.physics_safety.position_is_clear(destination):
			return destination
	return _checkpoint

func _teleport_player(destination: Vector2) -> void:
	player._cancel_spit_charge()
	player._detach()
	player.global_position = destination
	player.velocity = Vector2.ZERO
	player.spit_charges = player.settings.spit_maximum_charges
	player.state_machine.transition(player.State.IN_AIR, true)
	player.spit_charges_changed.emit(player.spit_charges, player.settings.spit_maximum_charges)
	player.get_node("Camera2D").reset_smoothing()

func _hint(text: String) -> void:
	prompt_changed.emit(text)

func _point_at(position: Vector2, caption: String) -> void:
	_world_arrow.global_position = position + Vector2(-80, -110)
	_world_arrow.set_hint(caption + "\n        ↓")
	_world_arrow.show()

func _style_hint(label: RichTextLabel) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.025, 0.045, 0.07, 0.86)
	background.set_corner_radius_all(8)
	background.content_margin_left = 14
	background.content_margin_right = 14
	background.content_margin_top = 10
	background.content_margin_bottom = 10
	label.add_theme_stylebox_override("normal", background)
	label.add_theme_color_override("default_color", Color("fff0bd"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _set_gateway_visible(value: bool) -> void:
	_gateway_icon.visible = value
	var background := _callout.get_theme_stylebox("normal") as StyleBoxFlat
	background.content_margin_left = 72 if value else 14

func _layout_callout() -> void:
	if not is_instance_valid(_callout) or not is_instance_valid(hud):
		return
	var feed = hud.get_widget(&"message_feed")
	if not _callout.visible:
		if not is_equal_approx(feed.presentation_bottom_margin, _feed_bottom_margin):
			feed.presentation_bottom_margin = _feed_bottom_margin
		return
	var viewport_size := get_viewport_rect().size
	var width := minf(420 if _callout_on_map else 650, maxf(200, viewport_size.x - 32))
	_callout.size.x = width
	var height := maxf(_callout.get_combined_minimum_size().y, 72 if _gateway_icon.visible else 0)
	_callout.size.y = height
	var clearance := maxf(_feed_bottom_margin, height + 40)
	if not is_equal_approx(feed.presentation_bottom_margin, clearance):
		feed.presentation_bottom_margin = clearance
	var presentation: Rect2 = feed.get_presentation_rect()
	var top := maxf(230, presentation.end.y + 16 if presentation.has_area() else 230)
	var left := viewport_size.x - width - 24 if _callout_on_map else 330.0
	_callout.position = Vector2(clampf(left, 16, maxf(16, viewport_size.x - width - 16)), top)

func _point_ui(text: String, map: bool = false, gateway: bool = false) -> void:
	_callout_on_map = map
	_set_gateway_visible(gateway)
	_callout.set_hint("↑  " + text)
	_callout.show()
	_layout_callout()

func _wait_until(predicate: Callable) -> bool:
	if _stopping or not is_inside_tree() or is_queued_for_deletion():
		return false
	var tree := get_tree()
	while not _stopping and is_inside_tree() and not is_queued_for_deletion():
		if predicate.call():
			return true
		await tree.process_frame
	return false

func _delay(seconds: float) -> bool:
	if _stopping or not is_inside_tree() or is_queued_for_deletion():
		return false
	var timer := get_tree().create_timer(seconds, false)
	return await _wait_until(func(): return timer.time_left <= 0)

func _exit_tree() -> void:
	_stopping = true
	InputBindings.leave_tutorial()
	if is_instance_valid(hud):
		var feed = hud.get_widget(&"message_feed")
		if is_instance_valid(feed):
			feed.presentation_bottom_margin = _feed_bottom_margin

func _say(id: String) -> bool:
	lesson = id
	if not await _wait_until(func(): return not guide.playback.is_playing):
		return false
	var line: TownfolkDialogueLine
	for entry in script_lines.lines:
		if entry.resource_name == id:
			line = entry
			break
	assert(line != null, "Missing tutorial line " + id)
	line = line.duplicate()
	line.text = line.text.replace("[action:interact]", "[action:interact]").replace("[Icon used for Gateway]", "")
	var chain := TownfolkDialogueChain.new()
	chain.chain_id = StringName("tutorial_" + id)
	chain.lines.append(line)
	chain.reactions_enabled = false
	# Production actors reject new conversations during repairs. This scripted guide
	# is the sole exception; restore the repair lock immediately after starting speech.
	var repair = _repair
	if is_instance_valid(repair):
		repair.remove_from_group(&"signal_network_repair_session")
	var started := guide.start_dialogue(chain, true)
	if is_instance_valid(repair):
		repair.add_to_group(&"signal_network_repair_session")
	assert(started, "Tutorial guide failed to speak " + id)
	if not await _wait_until(func(): return not guide.playback.is_playing):
		return false
	return true

func _marker_position(path: NodePath) -> Vector2:
	return ($TutorialMarkers.get_node(path) as Marker2D).global_position

func _walk_guide(target: Vector2) -> bool:
	var tween := create_tween()
	tween.tween_property(guide, "global_position", target, 1.4).set_trans(Tween.TRANS_SINE)
	if not await _wait_until(func(): return not tween.is_valid()):
		return false
	_point_at(target, "Follow Mr. Pipsqueak")
	return true

func _reach(rectangle: Rect2, hint: String) -> bool:
	_hint(hint)
	if not await _wait_until(func(): return rectangle.has_point(player.global_position)):
		return false
	_world_arrow.hide()
	return true

func _reach_guide_stop(path: NodePath, offset: Vector2, size: Vector2, hint: String) -> bool:
	return await _reach(Rect2(_marker_position(path) + offset, size), hint)

func _run_script() -> void:
	_hint("Walk out of your house to meet Mr. Pipsqueak.")
	if not await _wait_until(func(): return player.global_position.x > _marker_position(^"WorldTargets/IntroductionTrigger").x):
		return
	guide.show()
	for id in ["1", "2", "3"]:
		if not await _say(id):
			return
	var start := player.position
	_hint("Move with [action:move_left] / [action:move_right].")
	if not await _say("4"):
		return
	if not await _wait_until(func(): return absf(player.position.x - start.x) > 45):
		return
	_flags.erase("charged")
	_flags.erase("launched")
	_hint("Hold [action:jump] to charge a jump.")
	if not await _say("5"):
		return
	if not await _wait_until(func(): return _flags.has("charged")):
		return
	_hint("Aim with the mouse, then release [action:jump]. Overcharging rolls you back.")
	if not await _say("6"):
		return
	if not await _wait_until(func(): return _flags.has("launched")):
		return
	if not await _say("7"):
		return
	if not await _walk_guide(_marker_position(^"GuideStops/FirstRouter")):
		return
	if not await _reach_guide_stop(^"GuideStops/FirstRouter", Vector2(-330, -330), Vector2(560, 400), "Charge a jump over the wall and follow Mr. Pipsqueak."):
		return
	_checkpoint = _marker_position(^"Checkpoints/FirstWall")
	if not await _say("8"):
		return
	$NetworkGraph/FirstRouter.interact_action = &"interact"
	_point_at($NetworkGraph/FirstRouter.global_position, "Inspect [action:interact]")
	if not await _say("9"):
		return
	if not await _wait_until(func(): return $NetworkGraph/FirstRouter.state == SignalNetworkRouter.State.OK and not is_instance_valid(_repair)):
		return
	_world_arrow.hide()
	if not await _say("11"):
		return
	if not await _walk_guide(_marker_position(^"GuideStops/NetworkInspector")):
		return
	if not await _reach_guide_stop(^"GuideStops/NetworkInspector", Vector2(-160, -330), Vector2(340, 400), "Follow Mr. Pipsqueak to the network inspector."):
		return
	if not await _say("12"):
		return
	_network_unlocked = true
	_refresh_hud()
	_point_ui("Network inspector: routers, house portraits and internet gateways.", true)
	for id in ["13", "14", "15", "16", "17"]:
		if not await _say(id):
			return
	_callout.hide()
	$NetworkGraph/SecondRouter.state = SignalNetworkRouter.State.BROKEN
	$NetworkGraph/SecondRouter.interact_action = &"interact"
	_point_at($NetworkGraph/SecondRouter.global_position, "Repair [action:interact]")
	if not await _say("18"):
		return
	if not await _wait_until(func(): return $NetworkGraph/SecondRouter.state == SignalNetworkRouter.State.OK and not is_instance_valid(_repair)):
		return
	if not await _walk_guide(_marker_position(^"GuideStops/OffRouter")):
		return
	if not await _reach_guide_stop(^"GuideStops/OffRouter", Vector2(-180, -330), Vector2(330, 400), "Follow Mr. Pipsqueak to the switched-off router."):
		return
	$NetworkGraph/OffRouter.interact_action = &"interact"
	_point_at($NetworkGraph/OffRouter.global_position, "Inspect [action:interact]")
	if not await _say("19"):
		return
	if not await _wait_until(func(): return $NetworkGraph/OffRouter.state == SignalNetworkRouter.State.OK and not is_instance_valid(_repair)):
		return
	_world_arrow.hide()
	for id in ["21", "22", "23", "24", "25"]:
		if not await _say(id):
			return
	if not await _walk_guide(_marker_position(^"GuideStops/Bridge")):
		return
	if not await _reach_guide_stop(^"GuideStops/Bridge", Vector2(-120, -280), Vector2(220, 350), "Meet Mr. Pipsqueak at the raised bridge."):
		return
	_checkpoint = _marker_position(^"Checkpoints/Bridge")
	_point_at($SpitButton.global_position, "Spit at the switch")
	if not await _say("26"):
		return
	_hint("Hold and release [action:spit]. Hit the switch across the gap with spit.")
	if not await _wait_until(func(): return _bridge_lowered):
		return
	_world_arrow.hide()
	if not await _say("27"):
		return
	if not await _walk_guide(_marker_position(^"GuideStops/Recoil")):
		return
	if not await _reach_guide_stop(^"GuideStops/Recoil", Vector2(-150, -280), Vector2(300, 350), "Cross the lowered bridge."):
		return
	_checkpoint = _marker_position(^"Checkpoints/Recoil")
	if not await _say("28"):
		return
	_point_at(_marker_position(^"WorldTargets/LowerPathHint"), "Reach the lower path")
	_hint("Jump over the wall, fall into the opening, then spit right while airborne to recoil left onto the path below. Falls reset this obstacle.")
	if not await _wait_until(func(): return _flags.has("air_spit") and Rect2(_marker_position(^"Checkpoints/LowerPath") + Vector2(-130, -110), Vector2(380, 145)).has_point(player.global_position)):
		return
	_world_arrow.hide()
	_checkpoint = _marker_position(^"Checkpoints/LowerPath")
	# A little burrow/fade makes the guide's otherwise impossible route explicit.
	var fade_out := create_tween()
	fade_out.tween_property(guide, "modulate:a", 0.0, 0.4)
	if not await _wait_until(func(): return not fade_out.is_valid()):
		return
	guide.global_position = _marker_position(^"GuideStops/LowerPath")
	create_tween().tween_property(guide, "modulate:a", 1.0, 0.4)
	if not await _say("29"):
		return
	_point_at(_marker_position(^"WorldTargets/SlamHint"), "Slam through the wood")
	_hint("Jump and press [action:slam] while airborne to slam through the wooden floor.")
	if not await _wait_until(func(): return _wood_broken):
		return
	if not await _reach(Rect2(_marker_position(^"Checkpoints/NetworkRoom") + Vector2(-700, -230), Vector2(1900, 300)), "Drop into the network room."):
		return
	_checkpoint = _marker_position(^"Checkpoints/NetworkRoom")
	guide.global_position = _marker_position(^"GuideStops/NetworkRoom")
	await _field_test()

func _field_test() -> void:
	for router in _get_routers():
		router.interact_action = &""
	$NetworkGraph/Centre.state = SignalNetworkRouter.State.BROKEN
	if not await _say("30"):
		return
	var healthy := _example("healthy", "A message needs a connected route from its sender's house to the recipient's house.")
	message_board.announce(healthy)
	_point_ui("Sender portrait → recipient portrait. The countdown shows when transmission starts.")
	if not await _say("31"):
		return
	message_board.transmit(healthy)
	_point_ui("The paper plane waits while the route is broken. Repair the red router before the deadline.")
	if not await _delay(2):
		return
	$NetworkGraph/Centre.state = SignalNetworkRouter.State.OK
	network_graph.rebuild()
	_point_ui("Delivered! The thread opens here, followed by replies and delivery points.")
	if not await _wait_for_presentation(healthy):
		return
	if not await _delay(network_reading_pause_seconds):
		return
	if not await _say("32"):
		return
	if not await _say("33"):
		return
	$NetworkGraph/Centre.state = SignalNetworkRouter.State.BROKEN
	network_graph.rebuild()
	var failed := _example("failed", "A broken central router blocks this route. This message will expire before delivery.")
	message_board.announce(failed)
	message_board.transmit(failed)
	day_cycle.skip_game_seconds(failed.expire_minutes * 60 + 1)
	_point_ui("Expired: the red cross means delivery failed. No delivery points are earned.")
	if not await _delay(3):
		return
	if not await _say("34"):
		return
	$NetworkGraph/Centre.state = SignalNetworkRouter.State.OK
	$NetworkGraph/GatewayRouter.state = SignalNetworkRouter.State.BROKEN
	network_graph.rebuild()
	var local := _example("local", "Our houses still have a working route between them. A broken gateway does not stop this local message.")
	message_board.announce(local)
	message_board.transmit(local)
	var outside := _example("outside", "This broadcast needs any reachable internet gateway. Local connections alone are not enough.", true)
	message_board.announce(outside)
	message_board.transmit(outside)
	_point_ui("Local delivery succeeds; the broadcast waits for an internet gateway.")
	if not await _wait_for_presentation(local):
		return
	if not await _delay(network_reading_pause_seconds):
		return
	_point_ui("This globe marks an internet gateway. Broadcasts and outside callers need any reachable gateway.", true, true)
	if not await _say("35"):
		return
	_set_gateway_visible(false)
	$NetworkGraph/GatewayRouter.state = SignalNetworkRouter.State.OK
	network_graph.rebuild()
	if not await _wait_for_presentation(outside):
		return
	if not await _delay(network_reading_pause_seconds):
		return
	_callout.hide()
	if not await _say("36"):
		return
	_practice_ready = true
	_refresh_zones()
	_point_at(clock_in_point.global_position, "Clock in [action:interact]")
	_hint("Clock in with [action:interact] for a 40-second practice shift. Fix red routers before messages expire.")
	if not await _wait_until(func(): return phase == Phase.ON_SHIFT):
		return
	_world_arrow.hide()
	if not await _wait_until(func(): return phase == Phase.AFTER_HOURS):
		return
	if not await _wait_until(func(): return not guide.playback.is_playing):
		return
	guide.interaction_enabled = false
	guide.global_position = _marker_position(^"GuideStops/EveningPractice")
	if not await _practice_lesson():
		return
	if not await _say("end"):
		return
	_flags["bed_ready"] = true
	bed.global_position = _marker_position(^"EndRoom/Bed")
	_refresh_zones()
	_point_at(bed.global_position, "Sleep [action:interact]")
	_hint("Your training is complete. Press [action:interact] beside the bed to finish the tutorial.")

## Spawns the practice workbench, has the guide explain the frog router, and waits for one solved attempt.
func _practice_lesson() -> bool:
	workbench.global_position = _marker_position(^"EndRoom/PracticeTable")
	workbench.show()
	_point_at(workbench.global_position, "Practice router")
	for id in ["40", "41", "42", "43", "44", "45"]:
		if not await _say(id):
			return false
	workbench.enabled = true
	_point_at(workbench.global_position, "Tinker [action:interact]")
	_hint("Press [action:interact] at the workbench and make the yellow wave match the blue one.")
	var solved := [false]
	var on_finished := func(success: bool): solved[0] = solved[0] or success
	workbench.minigame_finished.connect(on_finished)
	var finished := await _wait_until(func(): return solved[0] and not workbench.is_open())
	workbench.minigame_finished.disconnect(on_finished)
	_world_arrow.hide()
	return finished

func _example(id: String, text: String, broadcast: bool = false) -> MessageNotification:
	var message := MessageNotification.new()
	message.message_id = StringName("tutorial_demo_" + id)
	message.title = "Network lesson: " + id
	message.from_house = &"tutorial_a"
	message.to_house = &"tutorial_b"
	message.sender = $NetworkGraph/HouseA.character_profile
	message.recipient = $NetworkGraph/HouseB.character_profile
	message.text = text
	message.points = 0
	message.expire_minutes = 1
	var time := day_cycle.get_time()
	message.hour = time.hour
	message.minute = time.minute
	message.second = time.second
	if broadcast:
		message.route = MessageNotification.Route.TO_INTERNET
		message.recipient = load("res://resources/character_profiles/internet_character_profile.tres")
	else:
		var reply := MessageReply.new()
		reply.text = "Received! Match our portraits to the houses on your network map and check the routers along the route."
		message.replies.append(reply)
	return message

func _wait_for_presentation(definition: MessageNotification) -> bool:
	return await _wait_until(func():
		for message in message_board.get_messages():
			if message.definition == definition:
				return _presented.has(message)
		return false)

func _on_clock_in(candidate: Node2D) -> void:
	if not _practice_ready or phase != Phase.WAKING:
		return
	day_cycle.reset()
	day_cycle.real_seconds_per_day = practice_shift_seconds
	day_cycle.load_schedule(MessageBoard.build_schedule(practice_schedule, day_cycle))
	for router in _get_routers():
		router.state = SignalNetworkRouter.State.OK
		router.interact_action = &"interact"
	network_graph.rebuild()
	guide.global_position = _marker_position(^"GuideStops/WorkingShift")
	guide.interaction_enabled = true
	guide.reactions_enabled = true
	super._on_clock_in(candidate)
	_hint("Fix red routers with [action:interact]. Keep routes connected; chat with Mr. Pipsqueak when he is free.")

func _on_player_state(_previous: int, current: int) -> void:
	if current == player.State.CHARGING:
		_flags["charged"] = true
	if current in [player.State.JUMPING, player.State.ROLLING_BACK]:
		_flags["launched"] = true

func _on_day_ended(day_number: int) -> void:
	super._on_day_ended(day_number)
	for router in _get_routers():
		router.interact_action = &""
	if is_instance_valid(_repair):
		_repair.finish(false)

func _on_spit_fired(projectile: Node2D, _ratio: float) -> void:
	if lesson == "28" and not player.is_grounded() and _ratio > 0:
		_flags["air_spit"] = true
	projectile.impacted.connect(func(collider, _point, _normal):
		if collider != $SpitButton or _bridge_lowered:
			return
		_bridge_lowered = true
		var lower := create_tween().set_parallel()
		lower.tween_property($Geometry/Bridge, "rotation", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
		lower.tween_property($Geometry/Bridge, "global_position", _marker_position(^"WorldTargets/LoweredBridge"), 1.0).set_trans(Tween.TRANS_SINE))

func _on_slam_impact(collider: Node, _point: Vector2, _normal: Vector2) -> void:
	if lesson != "29" or collider != $Geometry/WoodFloor or _wood_broken:
		return
	_wood_broken = true
	$Geometry/WoodFloor/Collision.set_deferred("disabled", true)
	$Geometry/WoodFloor.hide()
	_checkpoint = _marker_position(^"Checkpoints/NetworkRoom")

func _open_tutorial_repair(_player: Node2D, router: SignalNetworkRouter) -> void:
	if is_instance_valid(_repair):
		router.resolve_repair(false)
		return
	_guide_world_position = guide.global_position
	_repair_router = router
	var instance = RepairScene.instantiate()
	instance.powered = router != $NetworkGraph/OffRouter
	instance.required_presses = 1 if router == $NetworkGraph/OffRouter else 2
	_repair = instance
	instance.add_to_group(&"signal_network_repair_session")
	instance.completed.connect(_finish_tutorial_repair, CONNECT_ONE_SHOT)
	_suspension = RepairSuspension.new()
	instance.add_child(_suspension)
	add_child(instance)
	guide.reparent($GuideOverlay)
	guide.position = Vector2(360, get_viewport_rect().size.y - 100)
	instance.power_toggled.connect(_on_power_toggled)
	_teach_repair(instance, router)

func _teach_repair(instance: CanvasLayer, router: SignalNetworkRouter) -> void:
	if phase != Phase.ON_SHIFT:
		if router == $NetworkGraph/FirstRouter:
			if not await _say("10"):
				return
		elif router == $NetworkGraph/OffRouter:
			if not await _say("20"):
				return
	if is_instance_valid(instance):
		instance.explanation_finished = true
		instance.refresh_power()

func _on_power_toggled(presses: int, _powered: bool) -> void:
	if _repair_router == $NetworkGraph/OffRouter and presses == 2 and phase != Phase.ON_SHIFT:
		_say("20.a")

func _finish_tutorial_repair(success: bool) -> void:
	if is_instance_valid(_suspension):
		_suspension.release()
	_suspension = null
	guide.reparent(self)
	guide.global_position = _guide_world_position
	_repair = null
	_repair_router.resolve_repair(success)
	_repair_router = null

func _unhandled_input(event: InputEvent) -> void:
	if _host != null or is_instance_valid(_repair) or not event.is_action_pressed(&"ui_cancel") or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if _pause_menu.visible:
		_resume()
	else:
		get_tree().paused = true
		_pause_menu.open()

func _resume() -> void:
	get_tree().paused = false
	_pause_menu.close()

func _show_completion(report: DayReport) -> void:
	get_tree().paused = true
	$DaySummary.show_report(report, report.score, false)

func _quit_tutorial() -> void:
	get_tree().paused = false
	if _host != null:
		_host._quit()
		return
	get_tree().change_scene_to_file("res://main.tscn")
