extends SceneTree
## godot --headless --path <project> -s res://components/modules/frog_router_minigame/frog_router_minigame_test.gd
const Scene := preload("FrogRouterMinigame.tscn")
const ALL_BUT_POWER_OFF := 2 | 4 | 8 | 16 | 32
var _failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

func _node_count(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _node_count(child)
	return count

func _fast(game: Node) -> void:
	game.reach_duration = 0.01
	game.press_duration = 0.02
	game.boot_duration = 0.05
	game.sync_hold_time = 0.05
	game.success_delay = 0.05

func _press(game: Node, path: String) -> void:
	game.get_node("UI/Device/" + path).pressed.emit()

func _run() -> void:
	# Full repair with every fault except "power off" (it excludes "needs restart").
	var game := Scene.instantiate()
	game.forced_faults = ALL_BUT_POWER_OFF
	game.random_seed = 42
	_fast(game)
	var authored := _node_count(game)
	var results: Array = []
	game.completed.connect(func(success): results.append(success))
	root.add_child(game)
	await process_frame
	_check(_node_count(game) == authored, "Runtime must not generate nodes")
	_check(game.get_node("UI/Device/Body/Panels").visible, "Panel casing shows when no body texture is set")
	_check(game.active_faults == ALL_BUT_POWER_OFF, "Forced faults must be used as-is")
	_check(game.get_node("UI/NoteHand/List").text.contains(game.serial_number + "   " + game.pin), "Notes must list this router's serial and PIN")
	_check(game.get_node("UI/Device/SerialPlate/Text").text.ends_with(game.serial_number), "Serial plate must show the serial")
	_check(game._frozen and game.get_node("UI/Device/Leds/Error").on, "Needs-restart router starts hung with ERR lit")
	var freq: VSlider = game.get_node("UI/Device/FreqSlider")
	var amp: VSlider = game.get_node("UI/Device/AmpSlider")
	var antenna: Control = game.get_node("UI/Device/Antenna")
	_check(absf(freq.value - game.target_frequency) > game.slider_tolerance, "Frequency fault must start off target")
	_check(absf(amp.value - game.target_amplitude) > game.slider_tolerance, "Amplitude fault must start off target")
	_check(absf(antenna.angle - game.target_antenna_angle) > deg_to_rad(game.antenna_tolerance_degrees), "Antenna fault must start misaligned")
	var antenna_tip: Marker2D = antenna.get_node("Pivot/Tip")
	_check(antenna_tip.global_position.distance_to(antenna.get_global_transform() * antenna.tip_position()) < 0.5, "Antenna grab point must follow the rotated Tip marker")
	_check(is_equal_approx(antenna.get_node("Pivot").rotation, antenna.angle), "Antenna Pivot must rotate to the angle")
	# Keys are dead while hung.
	_press(game, "Keypad/KeyDec")
	await create_timer(0.1).timeout
	_check(game._encoding == game.Encoding.CORRUPT, "Keypad must not work on a hung router")
	# Hand reaches the pressed control.
	_press(game, "PowerButton")
	# The action runs at the moment of contact; the hand holds there while lifting.
	for i in 120:
		if not game._powered:
			break
		await process_frame
	var tip: Marker2D = game.get_node("UI/Hand/Motion/Fingertip")
	var power: Button = game.get_node("UI/Device/PowerButton")
	_check(tip.global_position.distance_to(power.get_global_transform() * (power.size / 2.0)) < 20.0, "Fingertip must reach the power button")
	_check(not game._powered and not game._frozen, "First power press turns off and clears the hang")
	_press(game, "PowerButton")
	await create_timer(0.2).timeout
	_check(game._is_running(), "Second power press must boot the router")
	# Tune the physical controls.
	freq.value = game.target_frequency
	amp.value = game.target_amplitude
	antenna.angle = game.target_antenna_angle
	await create_timer(0.2).timeout
	_check(results.is_empty(), "Corrupt encoding must block success")
	# Wrong PIN then right PIN, queued like rapid typing.
	var wrong := str((int(game.pin) + 1) % 10000).pad_zeros(4)
	_press(game, "Keypad/KeyDec")
	for digit in wrong:
		_press(game, "Keypad/Key" + digit)
	await create_timer(0.4).timeout
	_check(game._encoding == game.Encoding.STRIPPED, "Wrong PIN keeps encoding stripped")
	for digit in game.pin:
		_press(game, "Keypad/Key" + digit)
	await create_timer(0.6).timeout
	_check(results == [true], "Repaired router must report success exactly once")
	_check(not is_instance_valid(game), "Scene must free itself after success")

	# Power-off fault, notes and cancel.
	var off := Scene.instantiate()
	off.forced_faults = 1
	off.random_seed = 7
	_fast(off)
	off.get_node("UI/Device/Body/Texture").texture = PlaceholderTexture2D.new()
	var cancels: Array = []
	off.completed.connect(func(success): cancels.append(success))
	root.add_child(off)
	await process_frame
	_check(not off.get_node("UI/Device/Body/Panels").visible, "Body texture must replace the panel casing")
	_check(not off._powered and off.get_node("UI/Device/Lcd/Text").text == "", "Power-off router starts dark")
	var notes: Node2D = off.get_node("UI/NoteHand")
	var hidden_y := notes.position.y
	off.toggle_notes()
	await create_timer(0.4).timeout
	_check(notes.position.y < hidden_y - 300.0, "Notes hand must slide into view")
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	off._input(escape)
	off.finish(true)
	await process_frame
	_check(cancels == [false], "Cancel must report failure once")

	# Random picks respect the exclusion rule.
	for i in 40:
		var probe := Scene.instantiate()
		probe.random_seed = i + 1
		root.add_child(probe)
		var faults: int = probe.active_faults
		_check(faults != 0 and not ((faults & 1) and (faults & 2)), "Random faults: non-empty and never power-off + restart")
		probe.free()
	print("Frog router minigame tests: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
