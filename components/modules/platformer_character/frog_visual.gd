extends Node2D
signal foot_contact(left: bool)
const WALK_CONTACT_SECONDS := PI / 16.0
## Dependency-free placeholder animation. Replace with your AnimatedSprite2D.
var animation: StringName = &"idle"
var facing: float = 1.0
var _time: float = 0.0
const COLORS := {
	&"idle": Color("#7acb70"), &"walking": Color("#8ddd80"),
	&"charging": Color("#f4d56b"), &"jumping": Color("#55ddab"),
	&"in_air": Color("#71bceb"), &"on_wall": Color("#c59aef"),
	&"attacking": Color("#ffad65"), &"getting_hit": Color("#f27080"), &"squeezed": Color("#e5aa91"),
	&"slamming": Color("#ee9ad3"), &"rolling_back": Color("#e8a06e"),
	&"charging_spit": Color("#a0e6cc")
}
func play(next_animation: StringName) -> void:
	if animation != next_animation:
		animation = next_animation
		_time = 0.0

func _process(delta: float) -> void:
	var previous_contact := int(floor(_time / WALK_CONTACT_SECONDS))
	_time += delta
	if animation == &"walking":
		var contact := int(floor(_time / WALK_CONTACT_SECONDS))
		if contact > previous_contact:
			foot_contact.emit(contact % 2 == 0)
	queue_redraw()

func _draw() -> void:
	var squash := Vector2.ONE
	match animation:
		&"idle": squash.y = 1.0 + sin(_time * 3.0) * 0.035
		&"walking": squash.y = 1.0 + sin(_time * 16.0) * 0.10
		&"charging": squash = Vector2(1.18, 0.78 + sin(_time * 30.0) * 0.025)
		&"jumping": squash = Vector2(0.8, 1.2)
		&"in_air": squash = Vector2(1.05, 0.95 + sin(_time * 8.0) * 0.04)
		&"on_wall": squash = Vector2(1.12, 0.85)
		&"attacking": squash = Vector2(1.15, 0.9)
		&"getting_hit": squash = Vector2(0.9, 1.05)
		&"slamming": squash = Vector2(0.72, 1.28)
		&"rolling_back": squash = Vector2(1.12, 0.85)
		&"charging_spit": squash = Vector2(1.08 + sin(_time * 24.0) * 0.05, 0.9)
	draw_set_transform(Vector2.ZERO, 0.0, squash)
	draw_circle(Vector2.ZERO, 14.0, COLORS.get(animation, Color.WHITE))
	draw_circle(Vector2(-6, -10), 6.0, Color("#b2eb91"))
	draw_circle(Vector2(6, -10), 6.0, Color("#b2eb91"))
	draw_circle(Vector2(-6 + facing * 2, -11), 2.5, Color("#172c35"))
	draw_circle(Vector2(6 + facing * 2, -11), 2.5, Color("#172c35"))
	draw_line(Vector2(-11, 13), Vector2(11, 13), Color("#244f37"), 4.0)
	if animation == &"walking":
		var lift := sin(_time * 16.0)
		draw_circle(Vector2(-9, 15 - maxf(0.0, -lift) * 5.0), 4.0, Color("#244f37"))
		draw_circle(Vector2(9, 15 - maxf(0.0, lift) * 5.0), 4.0, Color("#244f37"))
	if animation == &"attacking":
		draw_line(Vector2(facing * 10, 0), Vector2(facing * 34, 0), Color("#ffddaa"), 4.0)
	if animation == &"charging_spit":
		draw_circle(Vector2(facing * 11, -1), 5.0 + sin(_time * 12.0), Color("#d6f4b5"))
