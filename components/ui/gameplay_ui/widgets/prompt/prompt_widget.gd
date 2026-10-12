extends HudWidget
## One line of guidance for the current phase ("Head outside and clock in."). Hidden when empty.
@onready var _panel: Control = %PromptPanel
@onready var _label: Label = %PromptLabel

func set_prompt(text: String) -> void:
	_label.text = text
	_panel.visible = not text.is_empty()

func apply_snapshot(snapshot: Dictionary) -> void:
	set_prompt(snapshot.get("prompt", ""))
