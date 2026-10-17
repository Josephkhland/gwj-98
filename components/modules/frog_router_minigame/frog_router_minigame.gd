extends CanvasLayer
## Frog-engineer router repair. Like the router_minigame scenes, the root only
## exposes completed(success: bool), so it can be a router's Minigame Scene.
## All nodes are authored in FrogRouterMinigame.tscn; this script drives them
## and creates no nodes.
signal completed(success: bool)

enum Fault { POWER_OFF = 1, NEEDS_RESTART = 2, FREQUENCY = 4, AMPLITUDE = 8, ENCODING = 16, ANTENNA = 32 }
enum Encoding { OK, CORRUPT, STRIPPED }
const SERIAL_LETTERS := "ABCDEFGHJKLMNPRSTUVWXYZ"

@export_group("Faults")
@export_flags("Power Off", "Needs Restart", "Frequency", "Amplitude", "Encoding", "Antenna") var possible_faults: int = 63
## When non-zero, exactly these faults are used instead of a random pick.
@export_flags("Power Off", "Needs Restart", "Frequency", "Amplitude", "Encoding", "Antenna") var forced_faults: int = 0
@export_range(0, 6) var min_faults: int = 1
@export_range(0, 6) var max_faults: int = 3
## 0 picks a new random seed every session.
@export var random_seed: int = 0
@export_range(2, 12) var serial_book_size: int = 6
@export_group("Tuning")
@export_range(0.005, 0.2, 0.005) var slider_tolerance: float = 0.04
## How far a faulty slider starts from its target (0..1 slider units).
@export_range(0.1, 0.5, 0.01) var min_slider_offset: float = 0.2
@export_range(1.0, 30.0) var antenna_tolerance_degrees: float = 8.0
## Misalignment beyond the tolerance at which the trace reaches full noise.
@export_range(5.0, 90.0) var antenna_noise_range_degrees: float = 40.0
@export_range(0.0, 5.0) var boot_duration: float = 1.2
@export_range(0.0, 3.0) var sync_hold_time: float = 0.8
@export_range(0.0, 3.0) var success_delay: float = 1.0
@export_group("Hands")
## The arm is anchored this far beyond the viewport's bottom-right corner.
@export var shoulder_margin: Vector2 = Vector2(180, 160)
@export var hover_offset: Vector2 = Vector2(14, 20)
@export_range(1.0, 60.0) var follow_sharpness: float = 12.0
@export_range(1.0, 60.0) var drag_sharpness: float = 30.0
## Motion scale while hovering (closer to the camera) and while pressing.
@export_range(0.5, 1.5) var hover_scale: float = 1.06
@export_range(0.5, 1.5) var press_scale: float = 0.94
@export_range(0.01, 1.0) var reach_duration: float = 0.12
@export_range(0.01, 1.0) var press_duration: float = 0.14
@export_range(0.01, 2.0) var notes_slide_duration: float = 0.25
@export var notes_margin_left: float = 40.0
@export var notes_hidden_drop: float = 640.0

## Generated each session; readable by hosts and tests.
var serial_number: String
var pin: String
var active_faults: int
var target_frequency: float
var target_amplitude: float
var target_antenna_angle: float

@onready var _ui: Control = $UI
@onready var _body_panels: Control = get_node_or_null(^"UI/Device/Body/Panels")
@onready var _body_texture: TextureRect = get_node_or_null(^"UI/Device/Body/Texture")
@onready var _scope: Control = $UI/Device/Screen
@onready var _freq: VSlider = $UI/Device/FreqSlider
@onready var _amp: VSlider = $UI/Device/AmpSlider
@onready var _power: Button = $UI/Device/PowerButton
@onready var _keypad: GridContainer = $UI/Device/Keypad
@onready var _lcd: Label = $UI/Device/Lcd/Text
@onready var _serial_label: Label = $UI/Device/SerialPlate/Text
@onready var _antenna: Control = $UI/Device/Antenna
@onready var _led_power: Control = $UI/Device/Leds/Power
@onready var _led_sync: Control = $UI/Device/Leds/Sync
@onready var _led_enc: Control = $UI/Device/Leds/Encoding
@onready var _led_err: Control = $UI/Device/Leds/Error
@onready var _notes_button: Button = $UI/NotesButton
@onready var _notes: Node2D = $UI/NoteHand
@onready var _notes_list: Label = $UI/NoteHand/List
@onready var _hand: Node2D = $UI/Hand
@onready var _hand_motion: Node2D = $UI/Hand/Motion
@onready var _tip: Marker2D = $UI/Hand/Motion/Fingertip

var _rng := RandomNumberGenerator.new()
var _book: Array = []
var _bits: int
var _powered: bool = true
var _boot_left: float = 0.0
var _frozen: bool = false
var _encoding: Encoding = Encoding.OK
var _pin_entry: String = ""
var _lcd_flash: String = ""
var _lcd_flash_left: float = 0.0
var _scope_time: float = 0.0
var _sync_time: float = 0.0
var _won: bool = false
var _finished: bool = false
var _queue: Array = []
var _busy: bool = false
var _press_tween: Tween
var _notes_tween: Tween
var _win_tween: Tween
var _notes_shown: bool = false
var _drag_source: Control
var _tip_point: Vector2

func _ready() -> void:
	# An assigned body texture replaces the flat panel casing.
	if _body_panels != null and _body_texture != null:
		_body_panels.visible = _body_texture.texture == null
	_generate()
	_serial_label.text = "S/N  " + serial_number
	_notes_list.text = "\n".join(_book.map(func(entry): return "%s   %s" % entry))
	for key in _keypad.get_children():
		if key is Button:
			key.pressed.connect(_on_key_pressed.bind(key))
	_power.pressed.connect(func(): _queue_press(_power, _toggle_power))
	for slider: VSlider in [_freq, _amp]:
		slider.drag_started.connect(_begin_drag.bind(slider))
		slider.drag_ended.connect(func(_changed): _end_drag(slider))
		slider.value_changed.connect(func(_value): _on_slider_nudged(slider))
	_antenna.drag_started.connect(_begin_drag.bind(_antenna))
	_antenna.drag_ended.connect(func(): _end_drag(_antenna))
	_notes_button.pressed.connect(toggle_notes)
	_ui.resized.connect(_on_ui_resized)
	_hand_motion.scale = Vector2.ONE * hover_scale
	_place_hand(_ui.get_local_mouse_position() + hover_offset)
	_notes.position = _notes_position(false)
	_update_router(0.0)

func _generate() -> void:
	_rng.seed = random_seed if random_seed != 0 else randi()
	var used := {}
	while _book.size() < serial_book_size:
		var serial := "FRG-%04d-%s" % [_rng.randi_range(1000, 9999), SERIAL_LETTERS[_rng.randi_range(0, SERIAL_LETTERS.length() - 1)]]
		if not used.has(serial):
			used[serial] = true
			_book.append([serial, "%04d" % _rng.randi_range(0, 9999)])
	var entry: Array = _book[_rng.randi_range(0, _book.size() - 1)]
	serial_number = entry[0]
	pin = entry[1]
	_bits = (int(pin) * 37 + 91) % 254 + 1
	active_faults = forced_faults if forced_faults != 0 else _pick_faults()
	if active_faults & Fault.POWER_OFF:
		active_faults &= ~Fault.NEEDS_RESTART
	target_frequency = _rng.randf_range(0.15, 0.85)
	target_amplitude = _rng.randf_range(0.15, 0.85)
	target_antenna_angle = deg_to_rad(_rng.randf_range(-35.0, 35.0))
	_freq.value = _offset_from(target_frequency, 0.0, 1.0, min_slider_offset) if active_faults & Fault.FREQUENCY else target_frequency
	_amp.value = _offset_from(target_amplitude, 0.0, 1.0, min_slider_offset) if active_faults & Fault.AMPLITUDE else target_amplitude
	_antenna.angle = _offset_from(target_antenna_angle, _antenna.min_angle, _antenna.max_angle, deg_to_rad(25.0)) if active_faults & Fault.ANTENNA else target_antenna_angle
	_powered = (active_faults & Fault.POWER_OFF) == 0
	_frozen = (active_faults & Fault.NEEDS_RESTART) != 0
	_encoding = Encoding.CORRUPT if active_faults & Fault.ENCODING else Encoding.OK

func _pick_faults() -> int:
	var pool: Array = []
	for bit in Fault.values():
		if possible_faults & bit:
			pool.append(bit)
	for i in range(pool.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	var count := _rng.randi_range(mini(min_faults, pool.size()), mini(maxi(min_faults, max_faults), pool.size()))
	var result := 0
	for bit in pool:
		if count <= 0:
			break
		# Power off and a hung router are the same symptom family; never combine them.
		if (bit == Fault.NEEDS_RESTART and result & Fault.POWER_OFF) or (bit == Fault.POWER_OFF and result & Fault.NEEDS_RESTART):
			continue
		result |= bit
		count -= 1
	return result

func _offset_from(target: float, low: float, high: float, gap: float) -> float:
	var options: Array[float] = []
	if target - gap > low:
		options.append(_rng.randf_range(low, target - gap))
	if target + gap < high:
		options.append(_rng.randf_range(target + gap, high))
	if options.is_empty():
		return high if target < (low + high) / 2.0 else low
	return options[_rng.randi_range(0, options.size() - 1)]

func _process(delta: float) -> void:
	_update_router(delta)
	_update_hand(delta)

func _is_running() -> bool:
	return _powered and _boot_left <= 0.0 and not _frozen

func _update_router(delta: float) -> void:
	_boot_left = maxf(0.0, _boot_left - delta)
	_lcd_flash_left -= delta
	var running := _is_running()
	if running:
		_scope_time += delta
	var antenna_error := absf(_antenna.angle - target_antenna_angle)
	var antenna_tolerance := deg_to_rad(antenna_tolerance_degrees)
	_scope.powered = _powered
	_scope.boot_progress = 1.0 - _boot_left / boot_duration if boot_duration > 0.0 else 1.0
	_scope.target_freq = target_frequency
	_scope.target_amp = target_amplitude
	_scope.bits = _bits
	_scope.locked = _won
	# A hung router keeps showing its last frame no matter what the controls do.
	if not _frozen:
		_scope.actual_freq = _freq.value
		_scope.actual_amp = _amp.value
		_scope.noise = clampf((antenna_error - antenna_tolerance) / deg_to_rad(antenna_noise_range_degrees), 0.0, 1.0)
		_scope.encoding = _encoding
		_scope.time = _scope_time
	_scope.queue_redraw()
	var synced := running and absf(_freq.value - target_frequency) <= slider_tolerance \
		and absf(_amp.value - target_amplitude) <= slider_tolerance \
		and _encoding == Encoding.OK and antenna_error <= antenna_tolerance
	_sync_time = _sync_time + delta if synced and _drag_source == null else 0.0
	if synced and not _won and _sync_time >= sync_hold_time:
		_win()
	_led_power.on = _powered
	_led_power.blinking = _boot_left > 0.0
	_led_sync.on = synced
	_led_enc.on = _powered and _encoding != Encoding.OK
	_led_enc.blinking = _encoding == Encoding.CORRUPT
	_led_err.on = _powered and _frozen
	_lcd.text = _lcd_text()

func _lcd_text() -> String:
	if not _powered:
		return ""
	if _boot_left > 0.0:
		return "BOOT.."
	if _frozen:
		return "E-07"
	if _lcd_flash_left > 0.0:
		return _lcd_flash
	match _encoding:
		Encoding.OK:
			return "ENC OK"
		Encoding.CORRUPT:
			return "ENC ERR"
	return "PIN " + _pin_entry.rpad(4, "_")

func _flash(text: String) -> void:
	_lcd_flash = text
	_lcd_flash_left = 0.7

func _toggle_power() -> void:
	if _powered:
		# Cutting power is the first half of a restart: it clears a hang.
		_powered = false
		_frozen = false
		_boot_left = 0.0
		_pin_entry = ""
	else:
		_powered = true
		_boot_left = boot_duration

func _on_key_pressed(key: Button) -> void:
	_queue_press(key, _apply_key.bind(String(key.name).trim_prefix("Key")))

func _apply_key(key: String) -> void:
	if not _is_running():
		return
	match key:
		"Dec":
			_encoding = Encoding.STRIPPED
			_pin_entry = ""
			_lcd_flash_left = 0.0
		"Clr":
			_pin_entry = ""
		_:
			if _encoding != Encoding.STRIPPED:
				_flash("DEC 1ST")
				return
			_pin_entry += key
			if _pin_entry.length() >= 4:
				if _pin_entry == pin:
					_encoding = Encoding.OK
					_flash("PIN OK")
				else:
					_flash("BAD PIN")
				_pin_entry = ""

func _on_slider_nudged(slider: Slider) -> void:
	# Mouse presses become drags; this covers wheel/keyboard changes.
	if _drag_source != slider and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_queue_press(slider, func(): pass)

func _begin_drag(source: Control) -> void:
	_drag_source = source

func _end_drag(source: Control) -> void:
	if _drag_source == source:
		_drag_source = null

func _queue_press(control: Control, action: Callable) -> void:
	if _won or _finished:
		return
	_queue.append([control, action])
	if not _busy:
		_next_press()

## Moves the fingertip onto the control, pushes, runs the action at contact,
## then lifts and continues with the next queued press.
func _next_press() -> void:
	if _queue.is_empty() or _finished:
		_busy = false
		return
	_busy = true
	var item: Array = _queue.pop_front()
	var control: Control = item[0]
	var contact := _drag_point(control)
	_press_tween = create_tween()
	_press_tween.tween_method(_place_hand, _tip_point, contact, reach_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_press_tween.tween_property(_hand_motion, "scale", Vector2.ONE * press_scale, press_duration / 2.0)
	_press_tween.parallel().tween_property(control, "modulate", Color(0.78, 0.78, 0.78), press_duration / 2.0)
	_press_tween.tween_callback(item[1])
	_press_tween.tween_property(_hand_motion, "scale", Vector2.ONE * hover_scale, press_duration / 2.0)
	_press_tween.parallel().tween_property(control, "modulate", Color.WHITE, press_duration / 2.0)
	_press_tween.tween_callback(_next_press)

func _update_hand(delta: float) -> void:
	if _busy:
		return
	var goal := _ui.get_local_mouse_position() + hover_offset
	var sharpness := follow_sharpness
	if is_instance_valid(_drag_source):
		goal = _drag_point(_drag_source)
		sharpness = drag_sharpness
	var weight := 1.0 - exp(-sharpness * delta)
	_place_hand(_tip_point.lerp(goal.clamp(Vector2.ZERO, _ui.size), weight))
	var depth := press_scale if is_instance_valid(_drag_source) else hover_scale
	_hand_motion.scale = _hand_motion.scale.lerp(Vector2.ONE * depth, weight)

## Point the fingertip should touch on a control, in UI coordinates.
func _drag_point(control: Control) -> Vector2:
	var local := control.size / 2.0
	if control is Slider:
		local = _grabber_center(control)
	elif control.has_method(&"tip_position"):
		local = control.tip_position()
	return _ui.get_global_transform().affine_inverse() * (control.get_global_transform() * local)

func _grabber_center(slider: Slider) -> Vector2:
	var icon := slider.get_theme_icon(&"grabber")
	var grab := icon.get_size() if icon != null else Vector2.ZERO
	if slider is VSlider:
		return Vector2(slider.size.x / 2.0, slider.size.y - slider.ratio * (slider.size.y - grab.y) - grab.y / 2.0)
	return Vector2(slider.ratio * (slider.size.x - grab.x) + grab.x / 2.0, slider.size.y / 2.0)

## Rotates the arm toward its off-screen shoulder and puts Fingertip on point.
func _place_hand(point: Vector2) -> void:
	_tip_point = point
	var to_shoulder := _ui.size + shoulder_margin - point
	if not to_shoulder.is_zero_approx():
		_hand.rotation = to_shoulder.angle()
	_hand.position = point - (_tip.position * _hand.scale).rotated(_hand.rotation)

func toggle_notes() -> void:
	_notes_shown = not _notes_shown
	if _notes_tween != null and _notes_tween.is_valid():
		_notes_tween.kill()
	_notes_tween = create_tween()
	_notes_tween.tween_property(_notes, "position", _notes_position(_notes_shown), notes_slide_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _notes_position(shown: bool) -> Vector2:
	return Vector2(notes_margin_left, _ui.size.y + (0.0 if shown else notes_hidden_drop))

func _on_ui_resized() -> void:
	if _notes_tween == null or not _notes_tween.is_running():
		_notes.position = _notes_position(_notes_shown)

func _input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		finish(false)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		toggle_notes()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var button := _button_for_key(event.keycode)
		if event.keycode == KEY_TAB:
			toggle_notes()
		elif button != null:
			button.pressed.emit()
		else:
			return
		get_viewport().set_input_as_handled()

func _button_for_key(keycode: Key) -> Button:
	var key := ""
	if keycode >= KEY_0 and keycode <= KEY_9:
		key = str(keycode - KEY_0)
	elif keycode >= KEY_KP_0 and keycode <= KEY_KP_9:
		key = str(keycode - KEY_KP_0)
	elif keycode == KEY_D or keycode == KEY_KP_MULTIPLY:
		key = "Dec"
	elif keycode == KEY_BACKSPACE or keycode == KEY_DELETE:
		key = "Clr"
	elif keycode == KEY_P:
		return _power
	return _keypad.get_node_or_null("Key" + key) as Button if key != "" else null

func _win() -> void:
	_won = true
	_queue.clear()
	_win_tween = create_tween()
	_win_tween.tween_interval(success_delay)
	_win_tween.tween_callback(finish.bind(true))

func finish(success: bool) -> void:
	if _finished:
		return
	_finished = true
	set_process(false)
	set_process_input(false)
	for tween: Tween in [_press_tween, _notes_tween, _win_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	completed.emit(success)
	queue_free()
