extends Resource
## Per-instance movement and combat tuning. Duplicate to customize a character.
@export_group("Movement")
@export_range(1.0, 1000.0) var walk_speed: float = 90.0
@export_range(1.0, 4000.0) var gravity: float = 980.0
@export_range(1.0, 4000.0) var terminal_speed: float = 1200.0
## Pixels/second squared; zero preserves landing momentum.
@export_range(0.0, 10000.0) var landing_slide_friction: float = 2000.0
@export_group("Surface contacts")
## Tag solids with this layer in addition to their normal world collision layer.
@export_flags_2d_physics var sticky_surface_mask: int = 8
## Disabled: absorb motion into ordinary walls/ceilings, keeping tangent motion.
@export var surface_bounce_enabled: bool = false
## Fraction of incoming normal speed reflected when bouncing: 0 absorbs, 1 reflects fully.
@export_range(0.0, 1.0) var surface_bounce_retention: float = 0.1
@export_group("Jump preview")
@export_range(0.1, 30.0) var jump_preview_max_time: float = 10.0
@export_range(0, 32) var jump_preview_max_bounces: int = 8
@export var jump_preview_color: Color = Color(1.0, 0.87, 0.4, 0.85)
@export_group("Charged jump")
## Holding Jump to this duration rolls on the floor or drops from a wall/ceiling.
@export_range(0.05, 5.0) var max_charge_time: float = 5.0
@export_range(0.0, 5000.0) var jump_charge_rate: float = 366.666667
@export_range(1.0, 3000.0) var minimum_jump_speed: float = 260.0
@export_range(1.0, 3000.0) var maximum_jump_speed: float = 700.0
@export_range(0.0, 2.0) var minimum_jump_duration: float = 0.18
@export_range(0.01, 3.0) var wall_hold_duration: float = 0.65
@export_range(0.0, 0.5) var reattach_delay: float = 0.12
## Angles away from the surface normal: smaller angles give more altitude.
@export_range(0.0, 85.0) var maximum_aim_angle_degrees: float = 75.0
@export_range(0.0, 85.0) var minimum_aim_angle_degrees: float = 5.0
## Heighten moves toward the normal; releasing it restores the flatter arc.
@export_range(1.0, 360.0) var aim_speed_degrees: float = 120.0
@export_range(0.0, 360.0) var verticality_decay_degrees: float = 30.0
@export_range(0.01, 5.0) var back_roll_stun_time: float = 0.75
@export_group("Spit")
@export var spit_enabled: bool = true
@export var ground_spit_enabled: bool = true
@export_range(1, 20) var spit_maximum_charges: int = 3
## Seconds per restored charge. Progress starts only after ground contact.
@export_range(0.01, 10.0) var spit_recharge_time: float = 0.8
@export_range(1.0, 4000.0) var spit_speed: float = 500.0
@export_range(0.0, 4000.0) var spit_gravity: float = 700.0
## Elevation above horizontal, mirrored by facing. Projectiles expire on impact.
@export_range(0.0, 85.0) var spit_launch_angle_degrees: float = 20.0
@export_range(0.0, 89.0) var spit_maximum_aim_angle_degrees: float = 85.0
@export var spit_preview_enabled: bool = true
@export var spit_preview_color: Color = Color(0.55, 1.0, 0.65, 0.9)
@export_range(0.1, 30.0) var spit_preview_max_time: float = 10.0
@export var spit_spawn_offset: Vector2 = Vector2(20.0, -3.0)
@export_range(1.0, 32.0) var spit_visual_radius: float = 4.0
@export_flags_2d_physics var spit_collision_mask: int = 5
@export_range(0, 1000) var spit_damage: int = 10
@export_range(0.0, 4000.0) var spit_hit_knockback: float = 100.0
@export_range(0.0, 4000.0) var spit_recoil: float = 120.0
## True guarantees backward horizontal speed; false adds a momentum impulse.
@export var spit_recoil_sets_backward_speed: bool = true
## Disabled: fire on press. Enabled: fire on release or full charge.
@export var spit_charge_enabled: bool = true
@export_range(0.01, 5.0) var spit_max_charge_time: float = 6.0
@export_range(1, 20) var spit_max_charges_per_shot: int = 3
@export_range(1.0, 5.0) var spit_charged_speed_multiplier: float = 2.0
@export_range(1.0, 5.0) var spit_charged_size_multiplier: float = 2.5
@export_range(1.0, 5.0) var spit_charged_recoil_multiplier: float = 2.5
@export_range(1.0, 5.0) var spit_charged_damage_multiplier: float = 2.0
@export_group("Spit charging movement")
@export_range(0.0, 1.0) var spit_charge_ground_speed_multiplier: float = 0.4
## Applied once on entering the charging state, rather than every tick.
@export_range(0.0, 1.0) var spit_charge_air_speed_multiplier: float = 0.6
@export_range(0.0, 1.0) var spit_charge_fall_speed_multiplier: float = 0.35
@export_range(0.0, 1.0) var spit_charge_gravity_multiplier: float = 0.25
@export_range(1.0, 4000.0) var spit_charge_fall_speed_limit: float = 250.0
@export_group("Spit recharge by state")
@export var idle_spit_recharge: bool = true
@export var walking_spit_recharge: bool = true
@export var charging_spit_recharge: bool = true
@export var jumping_spit_recharge: bool = false
@export var in_air_spit_recharge: bool = false
@export var on_wall_spit_recharge: bool = false
@export var attacking_spit_recharge: bool = true
@export var getting_hit_spit_recharge: bool = false
@export var squeezed_spit_recharge: bool = false
@export var slamming_spit_recharge: bool = false
@export var rolling_back_spit_recharge: bool = false
@export var spit_charging_recharge: bool = false
@export_group("Slam")
@export var slam_enabled: bool = true
@export_range(1.0, 6000.0) var slam_speed: float = 1500.0
@export var slam_hitbox_enabled: bool = true
@export_range(1.0, 256.0) var slam_hitbox_radius: float = 40.0
@export_flags_2d_physics var slam_hitbox_mask: int = 4
@export_range(0.01, 2.0) var slam_impact_time: float = 0.12
@export_range(0, 1000) var slam_damage: int = 20
@export_range(0.0, 4000.0) var slam_hit_knockback: float = 300.0
@export_group("Combat")
@export_range(1, 1000) var maximum_health: int = 100
@export_range(0, 1000) var attack_damage: int = 10
@export_range(0.0, 2000.0) var attack_knockback: float = 250.0
@export_range(0.01, 2.0) var attack_windup: float = 0.12
@export_range(0.01, 2.0) var attack_active_time: float = 0.10
@export_range(0.01, 2.0) var attack_recovery: float = 0.18
@export_range(0.01, 2.0) var hit_stun_time: float = 0.25
@export_range(0.0, 3.0) var invulnerability_time: float = 0.45

@export_group("Hit force thresholds (pixels/second)")
## Hits below the current state's threshold deal damage without interruption.
@export_range(0.0, 4000.0) var idle_hit_threshold: float = 100.0
@export_range(0.0, 4000.0) var walking_hit_threshold: float = 100.0
@export_range(0.0, 4000.0) var charging_hit_threshold: float = 180.0
@export_range(0.0, 4000.0) var jumping_hit_threshold: float = 80.0
@export_range(0.0, 4000.0) var in_air_hit_threshold: float = 80.0
@export_range(0.0, 4000.0) var on_wall_hit_threshold: float = 220.0
@export_range(0.0, 4000.0) var attacking_hit_threshold: float = 160.0
@export_range(0.0, 4000.0) var getting_hit_hit_threshold: float = 100.0
@export_range(0.0, 4000.0) var squeezed_hit_threshold: float = 100.0
@export_range(0.0, 4000.0) var slamming_hit_threshold: float = 300.0
@export_range(0.0, 4000.0) var rolling_back_hit_threshold: float = 100.0
@export_range(0.0, 4000.0) var charging_spit_hit_threshold: float = 180.0

@export_group("Crushing")
## Continuous opposing platform pressure time before entering SQUEEZED.
@export_range(0.05, 3.0) var crush_grace_time: float = 0.35
## Ignore contact slop smaller than this many pixels.
@export_range(0.05, 4.0) var crush_overlap_tolerance: float = 0.5
## Preserve the previous lethal behavior by default; disable for recovery.
@export var die_when_squeezed: bool = true
## Optional sound for both outcomes; null means silence.
@export var squeeze_sound: AudioStream
@export_range(0.05, 3.0) var squeeze_recovery_time: float = 0.45
@export_range(0.0, 3.0) var squeeze_cooldown: float = 0.5
## Non-lethal visual phases; collision geometry stays unchanged.
@export_range(0.0, 1.0) var squeeze_flatten_time: float = 0.12
@export_range(0.0, 1.0) var squeeze_flat_hold_time: float = 0.08
@export_range(0.0, 3.0) var squeeze_reappear_blink_time: float = 1.0
@export_range(0.02, 0.5) var squeeze_blink_interval: float = 0.1
## Zero searches only the saved position. Search checks full-size geometry.
@export_range(0.0, 256.0) var squeeze_recovery_search_radius: float = 64.0
@export_range(1.0, 32.0) var squeeze_recovery_search_step: float = 8.0

func get_hit_threshold(state_name: StringName) -> float:
	match state_name:
		&"idle": return idle_hit_threshold
		&"walking": return walking_hit_threshold
		&"charging": return charging_hit_threshold
		&"jumping": return jumping_hit_threshold
		&"in_air": return in_air_hit_threshold
		&"on_wall": return on_wall_hit_threshold
		&"attacking": return attacking_hit_threshold
		&"getting_hit": return getting_hit_hit_threshold
		&"squeezed": return squeezed_hit_threshold
		&"slamming": return slamming_hit_threshold
		&"rolling_back": return rolling_back_hit_threshold
		&"charging_spit": return charging_spit_hit_threshold
	return idle_hit_threshold

func allows_spit_recharge(state_name: StringName) -> bool:
	match state_name:
		&"idle": return idle_spit_recharge
		&"walking": return walking_spit_recharge
		&"charging": return charging_spit_recharge
		&"jumping": return jumping_spit_recharge
		&"in_air": return in_air_spit_recharge
		&"on_wall": return on_wall_spit_recharge
		&"attacking": return attacking_spit_recharge
		&"getting_hit": return getting_hit_spit_recharge
		&"squeezed": return squeezed_spit_recharge
		&"slamming": return slamming_spit_recharge
		&"rolling_back": return rolling_back_spit_recharge
		&"charging_spit": return spit_charging_recharge
	return false
