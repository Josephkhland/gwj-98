@tool
extends Node2D
signal foot_contact(left: bool)
## Visual-only animation sequencing; physics states remain in control of movement.
@export_range(0.01, 0.2, 0.005) var artwork_scale: float = 0.05
## Offset in character-space pixels, applied after the animation's source origin.
@export var artwork_offset: Vector2 = Vector2.ZERO
## Point the upright-corrected head along movement during airborne animations.
@export var orient_airborne_to_velocity: bool = true
@export_group("Editor Preview")
@export_enum("idle", "walking", "transition_to_charge_jump", "charging", "jumping", "falling", "spit_charge_ground", "spit_hold_ground", "spit_release_ground", "spit_charge_air", "spit_hold_air", "spit_release_air", "rolling_back") var preview_animation: String = "idle"
@export_range(0, 20, 1) var preview_frame: int = 0
@export var animate_preview: bool = false
## World-space movement direction for previewing airborne orientation. Zero keeps it upright.
@export var preview_velocity: Vector2 = Vector2.ZERO
@export_group("Artwork Origins (source pixels)")
@export var idle_origin: Vector2 = Vector2(393, 464)
@export var walking_origin: Vector2 = Vector2(375, 460)
@export var charge_origin: Vector2 = Vector2(374, 500)
@export var falling_origin: Vector2 = Vector2(650, 560)
@export var airborne_spit_origin: Vector2 = Vector2(650, 525)
@export var rollback_origin: Vector2 = Vector2(330, 525)
@export var jump_frame_origins: Array[Vector2] = [Vector2(330, 560), Vector2(480, 560), Vector2(650, 560), Vector2(650, 560)]
var animation: StringName = &"idle"
var facing: float = 1.0
var _actor: CharacterBody2D
var _release_active: bool = false
var _spit_airborne: bool = false
var _airborne_rotation: float = 0.0
@onready var _facing_node: Node2D = $Facing
@onready var _sprite: AnimatedSprite2D = $Facing/AnimatedSprite2D
func _ready() -> void:
	if Engine.is_editor_hint():
		_update_editor_preview()
		return
	_actor = get_parent() as CharacterBody2D
	_actor.spit_fired.connect(_on_spit_fired)
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.frame_changed.connect(_on_frame_changed)
	_select_state_clip(true)

func play(next_animation: StringName) -> void:
	if animation != next_animation:
		var previous := animation
		animation = next_animation
		if not is_node_ready():
			return
		if _release_active and next_animation in [&"idle", &"walking", &"in_air", &"jumping"]:
			return
		_release_active = false
		if next_animation == &"charging" and previous in [&"idle", &"walking", &"on_wall"]:
			_play_clip(&"transition_to_charge_jump", true)
		elif next_animation == &"charging_spit":
			_spit_airborne = not bool(_actor.get("_spit_charge_grounded"))
			_play_clip(&"spit_charge_air" if _spit_airborne else &"spit_charge_ground", true)
		else:
			_select_state_clip()

func _select_state_clip(force: bool = false) -> void:
	var clip: StringName = &"idle"
	match animation:
		&"walking": clip = &"walking"
		&"charging", &"on_wall":
			if not force and _sprite.animation == &"transition_to_charge_jump" and _sprite.is_playing():
				return
			clip = &"charging"
		&"jumping": clip = &"jumping"
		&"in_air":
			clip = &"jumping" if _actor.velocity.y < 0.0 else &"falling"
		&"slamming": clip = &"falling"
		&"rolling_back": clip = &"rolling_back"
		&"charging_spit":
			var airborne: bool = not _actor.is_grounded()
			if force or airborne != _spit_airborne:
				_spit_airborne = airborne
				_play_clip(&"spit_charge_air" if airborne else &"spit_charge_ground", true)
			return
	_play_clip(clip, force)

func _play_clip(clip: StringName, restart: bool = false) -> void:
	if _sprite.animation == clip and not restart:
		return
	_sprite.speed_scale = 1.0
	if clip == &"rolling_back":
		var duration: float = maxf(0.01, _actor.settings.back_roll_stun_time)
		_sprite.speed_scale = _sprite.sprite_frames.get_frame_count(clip) / _sprite.sprite_frames.get_animation_speed(clip) / duration
	_sprite.play(clip)
	if restart:
		_sprite.set_frame_and_progress(0, 0.0)
	_update_art_layout()

func _on_animation_finished() -> void:
	match _sprite.animation:
		&"transition_to_charge_jump":
			if animation == &"charging":
				_play_clip(&"charging")
		&"spit_charge_air":
			if animation == &"charging_spit":
				_play_clip(&"spit_hold_air")
		&"spit_charge_ground":
			if animation == &"charging_spit":
				_play_clip(&"spit_hold_ground")
		&"spit_release_air", &"spit_release_ground":
			_release_active = false
			_select_state_clip(true)

func _on_spit_fired(_projectile: Node2D, _ratio: float) -> void:
	_release_active = true
	_play_clip(&"spit_release_ground" if _actor.is_grounded() else &"spit_release_air", true)

func _on_frame_changed() -> void:
	_update_art_layout()
	if animation == &"walking" and _sprite.animation == &"walking" and _sprite.frame in [0, 5]:
		foot_contact.emit(_sprite.frame == 0)

func _update_art_layout() -> void:
	if not is_instance_valid(_sprite) or not is_instance_valid(_facing_node):
		return
	var origin := idle_origin
	var sideways := false
	match _sprite.animation:
		&"walking": origin = walking_origin
		&"charging", &"transition_to_charge_jump": origin = charge_origin
		&"jumping":
			origin = jump_frame_origins[mini(_sprite.frame, jump_frame_origins.size() - 1)] if not jump_frame_origins.is_empty() else falling_origin
			sideways = true
		&"falling":
			origin = falling_origin
			sideways = true
		&"rolling_back":
			origin = rollback_origin
			sideways = true
		&"spit_charge_air", &"spit_hold_air", &"spit_release_air":
			origin = airborne_spit_origin
			sideways = true
	# Atlas frames trim 18 pixels of canvas border without touching source images.
	_sprite.offset = -(origin - Vector2(18, 18) if sideways else origin)
	_sprite.rotation = -PI / 2.0 if sideways else 0.0
	_sprite.scale = Vector2.ONE * artwork_scale
	_facing_node.position = artwork_offset
	# Mirror after the art rotation; flipping the sideways texture would invert its feet.
	_facing_node.scale.x = -1.0 if facing < 0.0 else 1.0
	_update_airborne_orientation()

func _update_airborne_orientation() -> void:
	var follows_velocity: bool = orient_airborne_to_velocity and _sprite.animation in [
		&"jumping", &"falling", &"spit_charge_air", &"spit_hold_air", &"spit_release_air"]
	var direction := preview_velocity
	if not Engine.is_editor_hint():
		follows_velocity = follows_velocity and is_instance_valid(_actor) \
			and not _actor._attached and not _actor.is_grounded()
		if follows_velocity:
			direction = _actor.velocity
	if follows_velocity:
		# Keep the last direction at an apex or while spit charging suspends movement.
		if not direction.is_zero_approx():
			var local_direction := global_transform.affine_inverse().basis_xform(direction)
			_airborne_rotation = Vector2.UP.angle_to(local_direction)
		elif Engine.is_editor_hint():
			_airborne_rotation = 0.0
	else:
		_airborne_rotation = 0.0
	# Rotate the parent of the facing mirror so both facings keep their head forward.
	# The Visual root remains reserved for surface attachment and gameplay transforms.
	_facing_node.rotation = _airborne_rotation

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_update_editor_preview()
		return
	if not _release_active:
		_select_state_clip()
	_update_art_layout()

func _update_editor_preview() -> void:
	if not is_instance_valid(_sprite) or _sprite.sprite_frames == null:
		return
	var clip := StringName(preview_animation)
	if not _sprite.sprite_frames.has_animation(clip):
		return
	if animate_preview:
		_sprite.play(clip)
	else:
		_sprite.stop()
		_sprite.animation = clip
		_sprite.frame = clampi(preview_frame, 0, _sprite.sprite_frames.get_frame_count(clip) - 1)
	_update_art_layout()
