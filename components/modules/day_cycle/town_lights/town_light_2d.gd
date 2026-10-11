class_name TownLight2D
extends Node2D
## Reusable town fixture. Root position is the lamp's emitter, not its base.
const RADIAL_TEXTURE: Texture2D = preload("res://assets/josephkhland/town_lights_prototype/light_radial.png")
const BEAM_TEXTURE: Texture2D = preload("res://assets/josephkhland/town_lights_prototype/light_beam.png")
const BASE_BEAM_ANGLE := 55.0

enum Fixture { LAMP_POST, WALL_LAMP, FLOODLIGHT, BOLLARD }
enum ControlMode { NIGHT_CYCLE, ALWAYS_ON, ALWAYS_OFF, EXTERNAL }

@export_group("Control")
@export var control_mode: ControlMode = ControlMode.NIGHT_CYCLE:
	set(value):
		control_mode = value
		if is_node_ready():
			_sync_control(false)
@export var night_group: StringName = &"night_lights":
	set(value):
		night_group = value
		if is_node_ready():
			_sync_control(false)
@export var external_initial_on: bool = false
@export_group("Light Appearance")
@export_range(0.0, 16.0, 0.05, "or_greater") var energy: float = 1.0:
	set(value):
		energy = maxf(0.0, value)
		var light := get_light()
		if light != null:
			light.energy = energy
@export var shadow_enabled: bool = false:
	set(value):
		shadow_enabled = value
		var light := get_light()
		if light != null:
			light.shadow_enabled = value
## Optional shared external asset; leave empty to use the preset's radial/beam asset.
@export var light_texture: Texture2D:
	set(value):
		light_texture = value
		if is_node_ready():
			_update_texture()
## 0 = cool blue-white, 0.5 = neutral white, 1 = warm amber.
@export_range(0.0, 1.0, 0.01) var warmth: float = 0.85:
	set(value):
		warmth = clampf(value, 0.0, 1.0)
		_apply_color()
## Multiplies the warmth color, for colored signs or custom bulbs.
@export_color_no_alpha var bulb_tint: Color = Color.WHITE:
	set(value):
		bulb_tint = value
		_apply_color()
@export_range(8.0, 1500.0, 1.0, "or_greater") var light_radius: float = 180.0:
	set(value):
		light_radius = maxf(8.0, value)
		if is_node_ready():
			_update_texture()
@export_range(5.0, 150.0, 1.0) var beam_angle_degrees: float = 55.0:
	set(value):
		beam_angle_degrees = clampf(value, 5.0, 150.0)
		if is_node_ready() and fixture == Fixture.FLOODLIGHT:
			_update_texture()
@export_group("Fixture")
@export var fixture: Fixture = Fixture.LAMP_POST:
	set(value):
		fixture = value
		if is_node_ready():
			_update_texture()
		_sync_fixture()
@export var show_fixture: bool = true:
	set(value):
		show_fixture = value
		_sync_fixture()
@export_color_no_alpha var fixture_color: Color = Color.WHITE:
	set(value):
		fixture_color = value
		_sync_fixture()

## Replace these textures with your own art; bulb texture is optional.
@export var fixture_texture: Texture2D:
	set(value):
		fixture_texture = value
		_sync_fixture()
@export var bulb_texture: Texture2D:
	set(value):
		bulb_texture = value
		_sync_fixture()
## Top-left image offset relative to the emitter; independent of light geometry.
@export var fixture_art_offset: Vector2 = Vector2(-20.0, -28.0):
	set(value):
		fixture_art_offset = value
		_sync_fixture()
@export var fixture_art_scale: Vector2 = Vector2.ONE:
	set(value):
		fixture_art_scale = value
		_sync_fixture()

## Forward common light access through the actual emitter child.
var enabled: bool:
	get:
		var light := get_light()
		return light.enabled if light != null else _initial_enabled
	set(value):
		_initial_enabled = value
		var light := get_light()
		if light != null:
			light.enabled = value
		_sync_fixture()
var color: Color:
	get:
		return _warmth_color() * bulb_tint
var texture: Texture2D:
	get:
		var light := get_light()
		return light.texture if light != null else null
	set(_value):
		# Ignore old root-level generated texture overrides; use light_texture instead.
		pass
var texture_scale: float:
	get:
		var light := get_light()
		return light.texture_scale if light != null else 1.0
	set(_value):
		pass # Legacy root override; light_radius controls the emitter at runtime.
var offset: Vector2:
	get:
		var light := get_light()
		return light.offset if light != null else Vector2.ZERO
	set(_value):
		pass # Legacy root override; the preset controls emitter offset.
var _initial_enabled: bool = false
var _owned_group: StringName = &""
var _last_enabled: bool = false

func _ready() -> void:
	_apply_color()
	_update_texture()
	_sync_control(true)
	_last_enabled = enabled

func _process(_delta: float) -> void:
	# Night-cycle flicker can change the native enabled property directly.
	if _last_enabled != enabled:
		_last_enabled = enabled
		_sync_fixture()

func turn_on() -> void:
	enabled = true
	_sync_fixture()

func turn_off() -> void:
	enabled = false
	_sync_fixture()

func set_lit(value: bool) -> void:
	enabled = value
	_sync_fixture()

func _sync_control(initializing: bool) -> void:
	var light := get_light()
	if light == null:
		return
	if _owned_group != &"" and light.is_in_group(_owned_group):
		light.remove_from_group(_owned_group)
	_owned_group = &""
	if control_mode != ControlMode.NIGHT_CYCLE and night_group != &"" and light.is_in_group(night_group):
		light.remove_from_group(night_group)
	match control_mode:
		ControlMode.NIGHT_CYCLE:
			if night_group != &"":
				if not light.is_in_group(night_group):
					light.add_to_group(night_group)
				_owned_group = night_group
			# The controller takes over after its next transition/refresh.
			enabled = false
		ControlMode.ALWAYS_ON:
			enabled = true
		ControlMode.ALWAYS_OFF:
			enabled = false
		ControlMode.EXTERNAL:
			if initializing:
				enabled = external_initial_on
	_sync_fixture()

func _warmth_color() -> Color:
	if warmth < 0.5:
		return Color(0.65, 0.8, 1.0).lerp(Color.WHITE, warmth * 2.0)
	return Color.WHITE.lerp(Color(1.0, 0.55, 0.25), (warmth - 0.5) * 2.0)

func _apply_color() -> void:
	var light := get_light()
	if light != null:
		light.color = color
	_sync_fixture()

## All instances reuse external assets. Geometry changes only alter scalar/transform data.
func _update_texture() -> void:
	var light := get_light()
	if light == null:
		return
	# Preserve resource lifetime if an old saved override needs replacement at runtime.
	var _previous_texture: Texture2D = light.texture
	light.texture = light_texture if light_texture != null else (BEAM_TEXTURE if fixture == Fixture.FLOODLIGHT else RADIAL_TEXTURE)
	light.energy = energy
	light.shadow_enabled = shadow_enabled
	if fixture == Fixture.FLOODLIGHT:
		light.texture_scale = light_radius / 256.0
		light.scale = Vector2(tan(deg_to_rad(beam_angle_degrees * 0.5)) / tan(deg_to_rad(BASE_BEAM_ANGLE * 0.5)), 1.0)
		light.offset = Vector2(0.0, light_radius * 0.5)
	else:
		light.texture_scale = light_radius / 128.0
		light.scale = Vector2.ONE
		light.offset = Vector2.ZERO

## Use for native light masks, shadow filters, and other PointLight2D settings.
func get_light() -> PointLight2D:
	return get_node_or_null("Light") as PointLight2D

func _sync_fixture() -> void:
	var art := get_node_or_null("FixtureArt") as Node2D
	if art == null:
		return
	art.visible = show_fixture
	art.position = fixture_art_offset * fixture_art_scale
	art.scale = fixture_art_scale
	var body := art.get_node("Body") as Sprite2D
	body.texture = fixture_texture
	body.modulate = fixture_color
	var bulb := art.get_node("Bulb") as Sprite2D
	bulb.texture = bulb_texture
	bulb.modulate = color if enabled else Color(0.3, 0.3, 0.28)
