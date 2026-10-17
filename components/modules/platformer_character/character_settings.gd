extends Resource
@export_group("Sliding friction")
@export_range(0.0, 20.0) var slide_friction: float = 1.5
@export_range(0.0, 0.1) var landing_boost_coefficient: float = 0.01
@export_range(0.0, 20.0) var friction_boost_decay: float = 4.0
@export_group("Jump assistance")
@export_range(0.0, 0.5) var coyote_time: float = 0.15
@export_range(0.0, 15.0, 0.1) var minimum_wall_jump_angle_degrees: float = 2.0
@export_group("Wall attachment")
@export_range(0.0, 16.0, 0.5) var wall_attachment_snap_distance: float = 6.0
@export_range(0.0, 1.0, 0.05) var wall_attachment_gravity_multiplier: float = 0.25
## Per-instance movement and combat tuning. Duplicate to customize a character.
@export_group("Movement")
## Ground walking speed in pixels/second. Landing friction eases retained landing momentum toward this speed
## when moving.
@export_range(1.0, 1000.0) var walk_speed: float = 90.0
## Downward acceleration in pixels/second squared for ordinary movement and jump prediction. Spit projectiles
## use spit_gravity; a slam uses its own fixed dive speed.
@export_range(1.0, 4000.0) var gravity: float = 980.0
## Maximum downward speed in pixels/second during ordinary airborne movement. Does not limit the initial slam
## dive or spit projectile speed.
@export_range(1.0, 4000.0) var terminal_speed: float = 1200.0
@export_group("Surface contacts")
## Collision layers that tag walls/ceilings as attachable. A solid must also match the character's world
## collision mask. Floors work without this tag; untagged side/ceiling contacts use Stop/Bounce. For example,
## layer 4 plus world layer 1 makes a sticky solid.
@export_flags_2d_physics var sticky_surface_mask: int = 8
## Choose Bounce instead of Stop on non-attaching wall/ceiling contacts. Stop absorbs speed into the surface
## while keeping motion along it. Tagged sticky surfaces still attach when allowed.
@export var surface_bounce_enabled: bool = false
## Fraction of incoming speed into a wall/ceiling reflected in Bounce mode: 0 absorbs it, 0.1 reflects 10%,
## and 1 reflects all of it. Ignored in Stop mode. Motion along the surface is preserved; moving surfaces use
## relative velocity.
@export_range(0.0, 1.0) var surface_bounce_retention: float = 0.1
@export_group("Jump preview")
## Maximum flight time, in seconds, drawn by the jump trajectory. Prediction ends sooner at a floor or sticky
## attachment. A longer limit shows distant landings but needs more work; simulation is also capped at 3600
## steps.
@export_range(0.1, 30.0) var jump_preview_max_time: float = 10.0
## Maximum ordinary wall/ceiling contacts followed by the jump preview before ending the line. Counts contacts
## in both Stop and Bounce mode; zero ends at the first such contact.
@export_range(0, 32) var jump_preview_max_bounces: int = 8
## Color and opacity of the jump-charge trajectory. Use a different color from spit_preview_color so the two
## charging actions are easy to recognize.
@export var jump_preview_color: Color = Color(1.0, 0.87, 0.4, 0.85)
@export_group("Charged jump")
## Maximum continuous Jump hold time in seconds. Releasing launches; holding to this limit cancels the jump,
## rolls/stuns on a floor, or drops from a wall/ceiling. Heighten does not reset this timer. Independent of
## jump strength buildup.
@export_range(0.05, 5.0) var max_charge_time: float = 5.0
## Launch speed gained per second of Jump charging, in pixels/second squared. Speed starts at
## minimum_jump_speed and caps at maximum_jump_speed. Zero keeps the minimum speed; changing max_charge_time
## does not change this rate.
@export_range(0.0, 5000.0) var jump_charge_rate: float = 366.666667
## Launch speed in pixels/second before adding charge strength. This is the weakest released jump. Keep
## maximum_jump_speed at least this high.
@export_range(1.0, 3000.0) var minimum_jump_speed: float = 260.0
## Upper limit on charged jump launch speed in pixels/second. Reaching this strength does not auto-launch: the
## player can keep aiming until release or the Jump hold timeout.
@export_range(1.0, 3000.0) var maximum_jump_speed: float = 700.0
## Seconds the JUMPING animation/state normally lasts before becoming IN_AIR. Does not add lift or delay
## collision handling: contacts can settle or attach before it expires.
@export_range(0.0, 2.0) var minimum_jump_duration: float = 0.18
## Seconds an idle wall/ceiling attachment lasts before letting go and falling. Starting a jump charge
## switches to its separate max_charge_time timer.
@export_range(0.01, 3.0) var wall_hold_duration: float = 0.65
## Seconds after detaching during which wall/ceiling adhesion is blocked. Contacts during this interval use
## Stop/Bounce even on sticky surfaces. Helps prevent immediately sticking to the surface just left.
@export_range(0.0, 0.5) var reattach_delay: float = 0.12
## Jump angle away from the launch surface's outward normal without Heighten, in degrees. Larger angles aim
## farther along the surface and reduce the outward component. On floors, 0 is straight up. Left/right mirrors
## the angle.
@export_range(0.0, 85.0) var maximum_aim_angle_degrees: float = 75.0
## Smallest jump angle away from the surface normal, reached by holding Heighten. On floors, smaller angles
## give more vertical lift. Keep at or below maximum_aim_angle_degrees. Holding at this limit has no penalty.
@export_range(0.0, 85.0) var minimum_aim_angle_degrees: float = 5.0
## Aim change speed in degrees/second while Heighten is held. Moves jump aim toward the surface normal and
## spit elevation toward spit_maximum_aim_angle_degrees. Does not change accumulated charge strength.
@export_range(1.0, 360.0) var aim_speed_degrees: float = 120.0
## Aim change speed in degrees/second when Heighten is released. Restores jump aim toward
## maximum_aim_angle_degrees and spit aim toward spit_launch_angle_degrees. Zero preserves the selected
## elevation while charging.
@export_range(0.0, 360.0) var verticality_decay_degrees: float = 30.0
## Seconds the ground overcharged-jump roll locks controls before returning upright. Triggered by holding Jump
## to max_charge_time; Heighten itself never triggers a roll.
@export_range(0.01, 5.0) var back_roll_stun_time: float = 0.75
@export_group("Spit")
## Enables the entire spit ability, including firing and charge regeneration. Disable to prevent new spit
## attempts.
@export var spit_enabled: bool = true
## Allows spit attempts while grounded. Ground shots never push the character backward. Airborne spit remains
## available when this is disabled, provided spit_enabled is enabled.
@export var ground_spit_enabled: bool = true
## Maximum ammo capacity and charges available when the character spawns. A charged shot can spend several
## charges; regeneration stops at this capacity.
@export_range(1, 20) var spit_maximum_charges: int = 3
## Seconds needed to replenish one spent ammo charge. Each shot resets cooldown progress. Air shots require a
## later floor or wall contact to unlock regeneration; the current state's recharge permission must also be enabled.
## Separate from shot charging speed.
@export_range(0.01, 10.0) var spit_recharge_time: float = 0.8
## Base uncharged projectile launch speed in pixels/second. Charge increases it toward
## spit_charged_speed_multiplier times this value. The chosen elevation divides this speed into horizontal and
## upward components.
@export_range(1.0, 4000.0) var spit_speed: float = 500.0
## Downward projectile acceleration in pixels/second squared, also used by its preview. Larger values shorten
## the lob; zero gives straight travel. Projectiles have no timed lifetime and disappear on impact or level
## cleanup.
@export_range(0.0, 4000.0) var spit_gravity: float = 700.0
## Base projectile elevation above horizontal, in degrees, mirrored left/right by facing. Also the angle that
## charged spit returns toward when Heighten is released. Zero shoots horizontally.
@export_range(0.0, 85.0) var spit_launch_angle_degrees: float = 20.0
## Highest projectile elevation selected by holding Heighten while charging spit, in degrees above horizontal.
## Near 90 points nearly straight up. Treated as at least spit_launch_angle_degrees; staying at the cap has no
## penalty.
@export_range(0.0, 89.0) var spit_maximum_aim_angle_degrees: float = 85.0
## Show the pending projectile trajectory while charging spit. Uses its current power, radius, elevation,
## gravity, and collision mask. Turning this off affects only the indicator, not the shot.
@export var spit_preview_enabled: bool = true
## Color and opacity of the spit-charge trajectory. Keep it visually distinct from jump_preview_color.
@export var spit_preview_color: Color = Color(0.55, 1.0, 0.65, 0.9)
## Maximum projectile flight time, in seconds, drawn by the spit preview. Ends earlier at its first predicted
## solid or receiving-area impact. Does not remove the actual projectile after this time; prediction is capped
## at 3600 steps.
@export_range(0.1, 30.0) var spit_preview_max_time: float = 10.0
## Projectile muzzle offset from the character's center, in world-axis pixels. X is mirrored by facing;
## negative Y raises the muzzle. The first projectile sweep checks the path from the body center to this
## offset to prevent shooting through nearby obstacles.
@export var spit_spawn_offset: Vector2 = Vector2(20.0, -3.0)
## Base projectile radius in pixels, used for both its drawing and circular hit sweep. Charge scales both
## using spit_charged_size_multiplier; larger shots can hit obstacles or receivers that smaller shots miss.
@export_range(1.0, 32.0) var spit_visual_radius: float = 4.0
## Physics layers the projectile sweep can hit. The projectile has no own collision layer. World solids use
## layer 1 and receiving hurtboxes use layer 3; selecting both blocks shots at terrain and allows damage. The
## owner's body and hurtbox are excluded.
@export_flags_2d_physics var spit_collision_mask: int = 5
## Damage dealt by a base spit to a receiver with receive_hit(). Charged damage scales toward
## spit_charged_damage_multiplier times this amount. Each projectile impacts once.
@export_range(0, 1000) var spit_damage: int = 10
## Horizontal velocity impulse in pixels/second applied to a struck receiver, in the shooter's facing
## direction. Separate from the shooter's recoil and not scaled by the charged-recoil multiplier. Receiver hit
## thresholds can prevent interruption.
@export_range(0.0, 4000.0) var spit_hit_knockback: float = 100.0
## Base backward horizontal speed/impulse in pixels/second applied to the shooter when firing in the air.
## Charge scales it using spit_charged_recoil_multiplier. Ground shots have no shooter recoil; spit elevation
## does not rotate this horizontal push.
@export_range(0.0, 4000.0) var spit_recoil: float = 120.0
## True sets the shooter's airborne horizontal speed directly to the backward recoil speed, guaranteeing
## reversal. False adds a backward velocity impulse to existing momentum, so strong forward travel may
## continue.
@export var spit_recoil_sets_backward_speed: bool = true
## True enters CHARGING_SPIT and fires on release or the strongest affordable charge limit. False fires a base
## one-ammo shot immediately on a fresh press, without a charging state or charging preview.
@export var spit_charge_enabled: bool = true
## Seconds until a held spit fires automatically with enough ammo. Shorter times channel ammo into the shot
## faster. One tier takes this duration divided by the effective max charges per shot: with 3 tiers and 1
## second, costs rise to 2 at 0.33s and 3 at 0.67s, then the shot auto-fires at 1s. Tier mode grants each
## power bonus as its ammo cost rises; continuous mode builds power throughout the hold. Limited ammo caps
## power and auto-fires earlier. Not the ammo recharge cooldown.
@export_range(0.01, 5.0) var spit_max_charge_time: float = 6.0
## Maximum ammo charges one fully charged shot may consume, capped by spit_maximum_charges. Charge time is
## split into this many cost tiers, starting with a one-charge shot. Less available ammo limits power and
## causes earlier automatic firing.
@export_range(1, 20) var spit_max_charges_per_shot: int = 3
## True ties power bonuses to ammo actually spent: one charge uses base power, additional charges take evenly
## spaced steps toward the charged multipliers. With a 3-charge limit, two charges receive half the extra
## bonus and three receive all of it. False restores continuous scaling by hold time.
@export var spit_power_uses_ammo_tiers: bool = true
## Projectile speed multiplier for a maximum-ammo shot (or full hold in continuous mode). With 3 ammo tiers
## and a value of 2, spending 1/2/3 charges gives 1x/1.5x/2x speed. Limited ammo cannot grant a higher tier.
@export_range(1.0, 5.0) var spit_charged_speed_multiplier: float = 2.0
## Projectile visual and collision radius multiplier for a maximum-ammo shot (or full continuous hold). With 3
## ammo tiers and a value of 2.5, spending 1/2/3 charges gives 1x/1.75x/2.5x radius. Preview uses this same
## tier; a bigger projectile can hit receivers or obstacles a smaller shot misses.
@export_range(1.0, 5.0) var spit_charged_size_multiplier: float = 2.5
## Airborne shooter recoil multiplier for a maximum-ammo shot (or full continuous hold). With 3 ammo tiers and
## a value of 2.5, spending 1/2/3 charges gives 1x/1.75x/2.5x recoil. Ground shots still have no shooter
## recoil; this does not affect the struck target's knockback.
@export_range(1.0, 5.0) var spit_charged_recoil_multiplier: float = 2.5
## Damage multiplier for a maximum-ammo shot (or full continuous hold). With 3 ammo tiers and a value of 2,
## spending 1/2/3 charges gives 1x/1.5x/2x damage, rounded to an integer. Does not increase target knockback.
@export_range(1.0, 5.0) var spit_charged_damage_multiplier: float = 2.0
@export_group("Spit charging movement")
## Walking speed fraction while charging spit on the ground. 0 stops walking and 1 keeps normal walk_speed.
## Landing momentum still settles through landing_slide_friction.
@export_range(0.0, 1.0) var spit_charge_ground_speed_multiplier: float = 0.4
## Fraction of horizontal velocity kept once on entering airborne spit charging. 0 removes horizontal travel;
## 1 keeps it. Not multiplied again each tick. Does not alter the recoil applied when the shot fires.
@export_range(0.0, 1.0) var spit_charge_air_speed_multiplier: float = 0.6
## Fraction of normal downward speed used each tick while charging spit airborne. 0 suspends falling throughout the hold; 1 keeps normal falling. Normal gravity advances the underlying speed, then this multiplier scales the resulting movement. On release, the current movement speed is retained.
@export_range(0.0, 1.0) var spit_charge_downward_speed_multiplier: float = 0.1
## Fraction of normal upward speed used each tick while charging spit airborne. 0 stops ascent; 1 keeps normal ascent. Normal gravity still advances the underlying jump, so slowing ascent does not delay its apex. On release, the current movement speed is retained.
@export_range(0.0, 1.0) var spit_charge_upward_speed_multiplier: float = 1.0
## Maximum resulting downward speed in pixels/second during airborne spit charging, after the downward multiplier. Upward velocity is not capped by this value.
@export_range(1.0, 4000.0) var spit_charge_fall_speed_limit: float = 250.0
@export_group("Spit recharge by state")
## Allow ammo cooldown progress during IDLE (standing or landing slide). False pauses accumulated progress
## instead of resetting it. An airborne shot must still be followed by floor or wall contact to unlock regeneration;
## enabling this state cannot bypass that requirement.
@export var idle_spit_recharge: bool = true
## Allow ammo cooldown progress during WALKING. False pauses accumulated progress instead of resetting it. An
## airborne shot must still be followed by floor or wall contact to unlock regeneration; enabling this state cannot
## bypass that requirement.
@export var walking_spit_recharge: bool = true
## Allow ammo cooldown progress during CHARGING (holding Jump). False pauses accumulated progress instead of
## resetting it. An airborne shot must still be followed by floor or wall contact to unlock regeneration; enabling
## this state cannot bypass that requirement.
@export var charging_spit_recharge: bool = true
## Allow ammo cooldown progress during JUMPING (initial jump animation). False pauses accumulated progress
## instead of resetting it. An airborne shot must still be followed by floor or wall contact to unlock regeneration;
## enabling this state cannot bypass that requirement.
@export var jumping_spit_recharge: bool = false
## Allow ammo cooldown progress during IN_AIR. False pauses accumulated progress instead of resetting it. An
## airborne shot must still be followed by floor or wall contact to unlock regeneration; enabling this state cannot
## bypass that requirement.
@export var in_air_spit_recharge: bool = false
## Allow ammo cooldown progress during ON_WALL (wall/ceiling attachment). False pauses accumulated progress
## instead of resetting it. An airborne shot must still be followed by floor or wall contact to unlock regeneration;
## enabling this state cannot bypass that requirement.
@export var on_wall_spit_recharge: bool = true
## Allow ammo cooldown progress during ATTACKING (melee). False pauses accumulated progress instead of
## resetting it. An airborne shot must still be followed by floor or wall contact to unlock regeneration; enabling
## this state cannot bypass that requirement.
@export var attacking_spit_recharge: bool = true
## Allow ammo cooldown progress during GETTING_HIT (hit stun). False pauses accumulated progress instead of
## resetting it. An airborne shot must still be followed by floor or wall contact to unlock regeneration; enabling
## this state cannot bypass that requirement.
@export var getting_hit_spit_recharge: bool = false
## Allow ammo cooldown progress during SQUEEZED. False pauses accumulated progress instead of resetting it. An
## airborne shot must still be followed by floor or wall contact to unlock regeneration; enabling this state cannot
## bypass that requirement.
@export var squeezed_spit_recharge: bool = false
## Allow ammo cooldown progress during SLAMMING (dive and impact). False pauses accumulated progress instead
## of resetting it. An airborne shot must still be followed by floor or wall contact to unlock regeneration; enabling
## this state cannot bypass that requirement.
@export var slamming_spit_recharge: bool = false
## Allow ammo cooldown progress during ROLLING_BACK (overcharged-Jump stun). False pauses accumulated progress
## instead of resetting it. An airborne shot must still be followed by floor or wall contact to unlock regeneration;
## enabling this state cannot bypass that requirement.
@export var rolling_back_spit_recharge: bool = false
## Allow ammo cooldown progress during CHARGING_SPIT (holding Spit). False pauses accumulated progress instead
## of resetting it. An airborne shot must still be followed by floor or wall contact to unlock regeneration; enabling
## this state cannot bypass that requirement.
@export var spit_charging_recharge: bool = false
@export_group("Slam")
## Allows a fresh Slam press while airborne, including during spit charging. Starting a slam cancels pending
## spit charge and horizontal movement. Grounded or attached characters cannot start it.
@export var slam_enabled: bool = true
## Fixed downward dive speed in pixels/second before slam impact. Replaces normal gravity/terminal-speed
## movement and keeps horizontal speed zero. Higher values reach the surface sooner.
@export_range(1.0, 6000.0) var slam_speed: float = 1500.0
## Opens the slam's damage hitbox on its first opposing solid impact. Disable for movement-only slams or
## custom effects: slam_impacted still emits for platform breaking, switches, and other project logic.
@export var slam_hitbox_enabled: bool = true
## Circular slam damage radius in pixels, centered at the actual impact point. Affects the optional damage
## hitbox, not the character body's collision size.
@export_range(1.0, 256.0) var slam_hitbox_radius: float = 40.0
## Physics layers containing receiving areas that the slam hitbox can damage. Hurtboxes use layer 3. Separate
## from the character's world collision mask, which determines where the dive stops.
@export_flags_2d_physics var slam_hitbox_mask: int = 4
## Seconds spent in the slam impact window before returning to ground idle or air movement. The enabled damage
## hitbox stays active during this window and can hit each receiver once.
@export_range(0.01, 2.0) var slam_impact_time: float = 0.12
## Damage dealt once per receiving actor by the enabled slam impact hitbox. Does not define which platforms
## break; use slam_impacted for those rules.
@export_range(0, 1000) var slam_damage: int = 20
## Downward velocity impulse in pixels/second applied to actors hit by the slam damage area. Separate from
## slam_speed and subject to each receiver's interruption threshold.
@export_range(0.0, 4000.0) var slam_hit_knockback: float = 300.0
@export_group("Combat")
## Starting and maximum health for this character. Damage lowers health; reaching zero closes hitboxes,
## disables movement/collision, and emits died.
@export_range(1, 1000) var maximum_health: int = 100
## Damage dealt by one melee swing to each receiving actor. A receiver can be damaged only once during the
## same swing.
@export_range(0, 1000) var attack_damage: int = 10
## Velocity impulse magnitude in pixels/second applied by melee, along the attack direction selected at attack
## start. Attached attacks rotate that direction with the visual. Receiver hit thresholds determine
## interruption.
@export_range(0.0, 2000.0) var attack_knockback: float = 250.0
## Seconds from starting melee to opening its damage hitbox. The attack animation/state starts immediately,
## but cannot damage during this delay.
@export_range(0.01, 2.0) var attack_windup: float = 0.12
## Seconds the melee hitbox remains open after attack_windup. Longer values extend the opportunity to hit,
## without allowing repeated hits on the same receiver during that swing.
@export_range(0.01, 2.0) var attack_active_time: float = 0.10
## Seconds melee controls remain locked after the active hitbox closes. Total attack duration is windup plus
## active time plus recovery.
@export_range(0.01, 2.0) var attack_recovery: float = 0.18
## Seconds controls are locked in GETTING_HIT after a qualifying knockback impulse. Gravity continues; after
## the delay the character returns to ground idle or airborne movement. A qualifying later hit restarts this
## stun.
@export_range(0.01, 2.0) var hit_stun_time: float = 0.25
## Seconds incoming hits are ignored after receiving damage. This protects against both damage and impulse
## from repeated hits. Recovery blinking can extend invulnerability beyond this duration.
@export_range(0.0, 3.0) var invulnerability_time: float = 0.45

@export_group("Hit force thresholds (pixels/second)")
## Minimum incoming velocity-impulse magnitude in pixels/second that interrupts IDLE (standing or landing
## slide) and enters/restarts hit stun. Equal or greater qualifies; a weaker hit still damages without
## changing state. Zero allows any nonzero impulse to interrupt. Invulnerability rejects the whole hit.
@export_range(0.0, 4000.0) var idle_hit_threshold: float = 100.0
## Minimum incoming velocity-impulse magnitude in pixels/second that interrupts WALKING and enters/restarts
## hit stun. Equal or greater qualifies; a weaker hit still damages without changing state. Zero allows any
## nonzero impulse to interrupt. Invulnerability rejects the whole hit.
@export_range(0.0, 4000.0) var walking_hit_threshold: float = 100.0
## Minimum incoming velocity-impulse magnitude in pixels/second that interrupts CHARGING (holding Jump) and
## enters/restarts hit stun. Equal or greater qualifies; a weaker hit still damages without changing state.
## Zero allows any nonzero impulse to interrupt. Invulnerability rejects the whole hit.
@export_range(0.0, 4000.0) var charging_hit_threshold: float = 180.0
## Minimum incoming velocity-impulse magnitude in pixels/second that interrupts JUMPING (initial jump
## animation) and enters/restarts hit stun. Equal or greater qualifies; a weaker hit still damages without
## changing state. Zero allows any nonzero impulse to interrupt. Invulnerability rejects the whole hit.
@export_range(0.0, 4000.0) var jumping_hit_threshold: float = 80.0
## Minimum incoming velocity-impulse magnitude in pixels/second that interrupts IN_AIR and enters/restarts hit
## stun. Equal or greater qualifies; a weaker hit still damages without changing state. Zero allows any
## nonzero impulse to interrupt. Invulnerability rejects the whole hit.
@export_range(0.0, 4000.0) var in_air_hit_threshold: float = 80.0
## Minimum incoming velocity-impulse magnitude in pixels/second that interrupts ON_WALL (wall/ceiling
## attachment) and enters/restarts hit stun. Equal or greater qualifies; a weaker hit still damages without
## changing state. Zero allows any nonzero impulse to interrupt. Invulnerability rejects the whole hit.
@export_range(0.0, 4000.0) var on_wall_hit_threshold: float = 220.0
## Minimum incoming velocity-impulse magnitude in pixels/second that interrupts ATTACKING (melee) and
## enters/restarts hit stun. Equal or greater qualifies; a weaker hit still damages without changing state.
## Zero allows any nonzero impulse to interrupt. Invulnerability rejects the whole hit.
@export_range(0.0, 4000.0) var attacking_hit_threshold: float = 160.0
## Minimum incoming velocity-impulse magnitude in pixels/second that interrupts GETTING_HIT (hit stun) and
## enters/restarts hit stun. Equal or greater qualifies; a weaker hit still damages without changing state.
## Zero allows any nonzero impulse to interrupt. Invulnerability rejects the whole hit.
@export_range(0.0, 4000.0) var getting_hit_hit_threshold: float = 100.0
## Minimum incoming velocity-impulse magnitude in pixels/second that interrupts SQUEEZED and enters/restarts
## hit stun. Equal or greater qualifies; a weaker hit still damages without changing state. Zero allows any
## nonzero impulse to interrupt. Invulnerability rejects the whole hit.
@export_range(0.0, 4000.0) var squeezed_hit_threshold: float = 100.0
## Minimum incoming velocity-impulse magnitude in pixels/second that interrupts SLAMMING (dive and impact) and
## enters/restarts hit stun. Equal or greater qualifies; a weaker hit still damages without changing state.
## Zero allows any nonzero impulse to interrupt. Invulnerability rejects the whole hit.
@export_range(0.0, 4000.0) var slamming_hit_threshold: float = 300.0
## Minimum incoming velocity-impulse magnitude in pixels/second that interrupts ROLLING_BACK (overcharged-Jump
## stun) and enters/restarts hit stun. Equal or greater qualifies; a weaker hit still damages without changing
## state. Zero allows any nonzero impulse to interrupt. Invulnerability rejects the whole hit.
@export_range(0.0, 4000.0) var rolling_back_hit_threshold: float = 100.0
## Minimum incoming velocity-impulse magnitude in pixels/second that interrupts CHARGING_SPIT (holding Spit)
## and enters/restarts hit stun. Equal or greater qualifies; a weaker hit still damages without changing
## state. Zero allows any nonzero impulse to interrupt. Invulnerability rejects the whole hit.
@export_range(0.0, 4000.0) var charging_spit_hit_threshold: float = 180.0

@export_group("Crushing")
## Continuous seconds of opposing platform pressure required to enter SQUEEZED. The visual squashes during
## this grace period; removing pressure before it expires cancels the crush buildup.
@export_range(0.05, 3.0) var crush_grace_time: float = 0.35
## Allowed collision overlap/slop in pixels before the full-size body is considered penetrated. Larger values
## tolerate deeper overlap during safety/recovery checks; this does not make the collider smaller.
@export_range(0.05, 4.0) var crush_overlap_tolerance: float = 0.5
## True kills the character when sustained crushing enters SQUEEZED. False uses the flatten, disappearance,
## safe-position recovery and blinking sequence instead.
@export var die_when_squeezed: bool = true
## Optional sound played when crushing enters SQUEEZED, for both lethal and recoverable outcomes. Null falls
## back to the character's legacy splatter_sound override; if neither is assigned, squeezing is silent.
## Playback survives removal of the character.
@export var squeeze_sound: AudioStream
## Seconds before the first safe-position recovery attempt after entering a non-lethal squeeze. Recovery also
## waits for the flatten/hold visual phases to finish. Blocked recovery retries are throttled to roughly every
## 0.1 seconds; ignored for lethal squeezing.
@export_range(0.05, 3.0) var squeeze_recovery_time: float = 0.45
## Seconds after leaving SQUEEZED before new crush buildup is allowed. Also delays wall/ceiling reattachment
## after squeeze recovery, helping avoid immediately being trapped again.
@export_range(0.0, 3.0) var squeeze_cooldown: float = 0.5
## Seconds to shrink the visual toward a thin line during non-lethal squeezing. Zero makes flattening
## immediate. Collision geometry stays full-size; ignored for lethal squeezing.
@export_range(0.0, 1.0) var squeeze_flatten_time: float = 0.12
## Seconds the flattened visual remains visible before disappearing during a non-lethal squeeze. Added after
## squeeze_flatten_time; does not shorten the separate recovery delay.
@export_range(0.0, 1.0) var squeeze_flat_hold_time: float = 0.08
## Seconds of blinking and recovery invulnerability after a successful non-lethal relocation. Movement resumes
## during blinking. Zero disables this extra blinking/invulnerability period.
@export_range(0.0, 3.0) var squeeze_reappear_blink_time: float = 1.0
## Seconds between visible/hidden toggles during recovery blinking. Smaller values blink faster; one full
## on/off cycle takes twice this interval. Does not change the total blink duration.
@export_range(0.02, 0.5) var squeeze_blink_interval: float = 0.1
## Maximum distance in pixels searched around the saved pre-pressure position when non-lethal squeeze recovery
## needs free space. Zero tries only the saved position. Every candidate checks the unchanged full-size body.
@export_range(0.0, 256.0) var squeeze_recovery_search_radius: float = 64.0
## Spacing in pixels between candidate distance rings in the squeeze recovery search. Smaller values search
## more densely but require more collision checks; the outer ring is capped to the search radius.
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
