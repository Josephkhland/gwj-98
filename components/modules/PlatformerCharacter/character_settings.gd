extends Resource
## Per-instance movement and combat tuning. Duplicate to customize a character.
@export_group("Movement")
@export_range(1.0, 1000.0) var walk_speed: float = 90.0
@export_range(1.0, 4000.0) var gravity: float = 980.0
@export_range(1.0, 4000.0) var terminal_speed: float = 1200.0
@export_group("Charged jump")
@export_range(0.05, 5.0) var max_charge_time: float = 5.0
@export_range(0.0, 5000.0) var jump_charge_rate: float = 366.666667
@export_range(1.0, 3000.0) var minimum_jump_speed: float = 260.0
@export_range(1.0, 3000.0) var maximum_jump_speed: float = 700.0
@export_range(0.0, 2.0) var minimum_jump_duration: float = 0.18
@export_range(0.01, 3.0) var wall_hold_duration: float = 0.65
@export_range(0.0, 0.5) var reattach_delay: float = 0.0
@export_range(0.0, 85.0) var maximum_aim_angle_degrees: float = 75.0
@export_range(1.0, 360.0) var aim_speed_degrees: float = 120.0
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
	return idle_hit_threshold
