class_name MessagePanelBubble
extends HBoxContainer
## One full-text bubble and portrait. Reveal is a panel animation, not a typewriter.
@onready var _portrait: TextureRect = $Portrait/Texture
@onready var _initial: Label = $Portrait/Initial
@onready var _name: Label = $Bubble/Margin/Content/Name
@onready var _text: Label = $Bubble/Margin/Content/Text
@onready var _bubble: PanelContainer = $Bubble
var _compact: bool = false
var _narrow: bool = false

func set_compact(value: bool) -> void:
	_compact = value
	_apply_layout()

func set_narrow(value: bool) -> void:
	_narrow = value
	_apply_layout()

func _apply_layout() -> void:
	var value := _compact or _narrow
	$Portrait.custom_minimum_size = Vector2(28, 28) if value else Vector2(44, 44)
	add_theme_constant_override("separation", 6 if value else 10)
	_name.add_theme_font_size_override("font_size", 12 if value else 14)
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_text.add_theme_font_size_override("font_size", 14 if _compact else (16 if _narrow else 18))
	_text.max_lines_visible = 2 if _compact else -1
	_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if _compact else TextServer.OVERRUN_NO_TRIMMING
	for edge in ["left", "top", "right", "bottom"]:
		$Bubble/Margin.add_theme_constant_override("margin_" + edge, 8 if value else 12)

func configure(profile: CharacterProfile, fallback_name: String, value: String, sender: bool) -> void:
	var speaker_name := profile.display_name if profile != null and not profile.display_name.is_empty() else fallback_name
	_name.text = speaker_name
	_text.text = value
	_portrait.texture = profile.portrait if profile != null else null
	_portrait.visible = _portrait.texture != null
	_initial.text = speaker_name.left(1).to_upper() if not speaker_name.is_empty() else "?"
	_initial.visible = _portrait.texture == null
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff3d9") if sender else Color("d9eee5")
	style.set_corner_radius_all(13)
	_bubble.add_theme_stylebox_override("panel", style)
	_name.add_theme_color_override("font_color", Color("765828") if sender else Color("33675c"))

func measure_for_width(width: float) -> float:
	# Establish wrap width before measuring so long replies never collapse or clip.
	var small := _compact or _narrow
	var portrait_size := 28 if small else 44
	var padding := 16 if small else 24
	_text.size.x = maxf(40, width - portrait_size - (6 if small else 10) - padding)
	var height := maxf(portrait_size, _text.get_minimum_size().y + _name.get_minimum_size().y + 4 + padding)
	custom_minimum_size.y = height
	size = Vector2(width, height)
	return height
