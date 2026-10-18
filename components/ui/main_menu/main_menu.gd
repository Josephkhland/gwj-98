class_name MainMenu
extends CanvasLayer
## Title screen. Shared settings are presented in the Options overlay.
signal start_requested(level_index: int)
signal tutorial_requested
signal credits_requested
signal quit_requested
@export_group("Artwork Slideshow")
@export var artwork_slides: Array[Texture2D] = []
@export_range(1.0, 60.0, 0.5) var artwork_hold_seconds: float = 8.0
@export_range(0.1, 5.0, 0.1) var artwork_fade_seconds: float = 1.2
@onready var _title: Label = %TitleLabel
@onready var _start: Button = %StartButton
@onready var _quit: Button = %QuitButton
@onready var _artwork_layers: Array[TextureRect] = [$FrogineerArtwork, $BurdArtwork]
var _artwork_elapsed: float = 0.0
var _artwork_layer: int = 0
var _artwork_slide: int = 0


func _ready() -> void:
	if not artwork_slides.is_empty():
		_artwork_layers[0].texture = artwork_slides[0]
		_artwork_layers[1].texture = artwork_slides[1 % artwork_slides.size()]
	_title.text = ProjectSettings.get_setting("application/config/name", "")
	# _start.pressed.connect(_on_start_pressed)
	_start.pressed.connect(func(): $DifficultyMenu.open(%OptionsButton))
	_quit.pressed.connect(quit_requested.emit)
	%TutorialButton.pressed.connect(tutorial_requested.emit)
	%CreditsButton.pressed.connect(credits_requested.emit)
	%OptionsButton.pressed.connect(func(): $OptionsMenu.open(%OptionsButton))
	_start.grab_focus()


func _process(delta: float) -> void:
	if not visible or artwork_slides.size() < 2:
		return
	_artwork_elapsed += delta
	if _artwork_elapsed < artwork_hold_seconds:
		return
	var progress := clampf((_artwork_elapsed - artwork_hold_seconds) / maxf(0.1, artwork_fade_seconds), 0.0, 1.0)
	var blend := smoothstep(0.0, 1.0, progress)
	_artwork_layers[_artwork_layer].modulate.a = 1.0 - blend
	_artwork_layers[1 - _artwork_layer].modulate.a = blend
	if progress >= 1.0:
		_artwork_layer = 1 - _artwork_layer
		_artwork_slide = (_artwork_slide + 1) % artwork_slides.size()
		_artwork_layers[1 - _artwork_layer].texture = artwork_slides[(_artwork_slide + 1) % artwork_slides.size()]
		_artwork_elapsed = 0.0


func open() -> void:
	$OptionsMenu.close()
	$DifficultyMenu.close()
	show()
	_start.grab_focus()


func on_start_pressed(difficulty: int) -> void:
	AccessibilitySettings.difficulty = difficulty
	start_requested.emit(0)
