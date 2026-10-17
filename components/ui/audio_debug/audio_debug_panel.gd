extends CanvasLayer

const BUSES := [&"SFX", &"Music", &"Ambience"]
const REFRESH_SECONDS := 0.1
@onready var _sounds: Tree = %Sounds
@onready var _count: Label = %SoundCount
@onready var _waveforms: Array[Control] = [%SFXWaveform, %MusicWaveform, %AmbienceWaveform]
@onready var _meters: Array[Label] = [%SFXMeter, %MusicMeter, %AmbienceMeter]
var _captures: Dictionary = {}
var _refresh_elapsed: float = 0.0
var active_sounds: Array[Dictionary] = []
var _root_item: TreeItem
var _rows: Dictionary = {}

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	%CloseButton.pressed.connect(func(): set_open(false))
	for column in 5:
		_sounds.set_column_title(column, ["Sound / segment", "Bus", "Time / length", "dB", "State"][column])
		_sounds.set_column_expand(column, column == 0)
		_sounds.set_column_custom_minimum_width(column, [180, 65, 105, 55, 75][column])
	_root_item = _sounds.create_item()
	set_open(false)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		set_open(not visible)
		get_viewport().set_input_as_handled()

func set_open(open: bool) -> void:
	visible = open
	set_process(open)
	if open:
		_attach_captures()
		_refresh_sounds()
	else:
		_detach_captures()
		active_sounds.clear()
		for waveform in _waveforms:
			waveform.clear()

func _attach_captures() -> void:
	for bus in BUSES:
		if _captures.has(bus):
			continue
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		var capture := AudioEffectCapture.new()
		capture.buffer_length = 0.3
		AudioServer.add_bus_effect(index, capture)
		_captures[bus] = capture

func _detach_captures() -> void:
	for bus in _captures:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		for effect in range(AudioServer.get_bus_effect_count(index) - 1, -1, -1):
			if AudioServer.get_bus_effect(index, effect) == _captures[bus]:
				AudioServer.remove_bus_effect(index, effect)
	_captures.clear()

func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed < REFRESH_SECONDS:
		return
	_refresh_elapsed = 0.0
	for at in BUSES.size():
		var bus: StringName = BUSES[at]
		var index := AudioServer.get_bus_index(bus)
		if index < 0 or not _captures.has(bus):
			_meters[at].text = "%s: unavailable" % bus
			continue
		var capture: AudioEffectCapture = _captures[bus]
		_waveforms[at].push_samples(capture.get_buffer(capture.get_frames_available()))
		var peak: float = _waveforms[at].peak
		var peak_text := "silent" if peak <= 0.00001 else "%.1f dB peak" % linear_to_db(peak)
		_meters[at].text = "%s  |  %s  |  bus %.1f dB  |  display x%.1f%s" % [bus, peak_text, AudioServer.get_bus_volume_db(index), _waveforms[at].display_gain, "  |  MUTED" if AudioServer.is_bus_mute(index) else ""]
	_refresh_sounds()

func _refresh_sounds() -> void:
	active_sounds.clear()
	_collect_players(get_tree().root)
	active_sounds.sort_custom(func(a: Dictionary, b: Dictionary):
		return a["path"] < b["path"])
	var live_ids: Array = []
	for sound in active_sounds:
		live_ids.append(sound["id"])
	for id in _rows.keys():
		if id not in live_ids:
			_rows[id].free()
			_rows.erase(id)
	for sound in active_sounds:
		if not _rows.has(sound["id"]):
			_rows[sound["id"]] = _sounds.create_item(_root_item)
		var item: TreeItem = _rows[sound["id"]]
		item.set_text(0, sound["sound"])
		item.set_text(1, sound["bus"])
		item.set_text(2, "%.1f / %.1fs" % [sound["position"], sound["length"]])
		item.set_text(3, "%.1f" % sound["volume_db"])
		item.set_text(4, sound["state"])
		for column in 5:
			item.set_tooltip_text(column, sound["path"])
	_count.text = "Active sounds: %d" % active_sounds.size()

func _collect_players(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		if node.stream != null and (node.playing or node.stream_paused):
			var stream: AudioStream = node.stream
			var title := stream.resource_name
			if title.is_empty():
				title = stream.resource_path.get_file()
			if title.is_empty():
				title = String(node.name)
			var bus := AudioServer.get_bus_index(node.bus)
			var state := "Playing"
			if node.stream_paused or not node.can_process():
				state = "Paused"
			elif node.volume_linear == 0.0 or (bus >= 0 and AudioServer.is_bus_mute(bus)):
				state = "Muted"
			active_sounds.append({"id": node.get_instance_id(), "sound": title, "bus": String(node.bus), "position": node.get_playback_position(), "length": stream.get_length(), "volume_db": node.volume_db, "state": state, "path": String(node.get_path())})
	for child in node.get_children():
		_collect_players(child)

func _exit_tree() -> void:
	_detach_captures()
