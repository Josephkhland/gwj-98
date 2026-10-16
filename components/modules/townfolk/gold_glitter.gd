@tool
extends RichTextEffect
## Per-letter glints remain attached to the word as text wraps.
var bbcode: String = "gold_glitter"

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var phase := char_fx.elapsed_time * 7.0 + char_fx.relative_index * 2.37
	var glint := pow(maxf(0.0, sin(phase)), 12)
	char_fx.color = Color("996000").lerp(Color("ffcc35"), glint)
	char_fx.offset.y += sin(phase * 0.5) * 0.35
	return true
