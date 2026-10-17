// Round flask of liquid for UI. Drive `fill` (0..1) for the level, `drain` for the slice
// at the top of the liquid that is about to be spent, and `slosh` for a short wave burst.
shader_type canvas_item;

uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform float drain : hint_range(0.0, 1.0) = 0.0;
uniform float slosh : hint_range(0.0, 1.0) = 0.0;
uniform int segments = 3;
uniform vec4 liquid_color : source_color = vec4(0.6, 1.0, 0.15, 1.0);
uniform vec4 drain_color : source_color = vec4(1.0, 1.0, 0.65, 1.0);
uniform vec4 glass_color : source_color = vec4(0.06, 0.1, 0.08, 0.85);
uniform vec4 rim_color : source_color = vec4(0.85, 1.0, 0.85, 0.95);
uniform float rim_width : hint_range(0.0, 0.3) = 0.07;
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.02;
uniform float wave_speed = 2.2;

float hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float radius = length(centered);
	float aa = fwidth(radius);
	float outer = 1.0 - smoothstep(1.0 - aa, 1.0, radius);
	float inner = 1.0 - smoothstep(1.0 - rim_width - aa, 1.0 - rim_width, radius);

	// Waves fade out when the flask is empty or full so the surface doesn't poke past the rim.
	float amplitude = wave_amplitude * (1.0 + slosh * 3.0) * sin(3.14159 * clamp(fill, 0.0, 1.0));
	float wave = sin(UV.x * 9.0 + TIME * wave_speed) * amplitude
		+ sin(UV.x * 15.0 - TIME * wave_speed * 1.3) * amplitude * 0.5;
	float surface = 1.0 - fill + wave;
	float liquid = smoothstep(surface - 0.01, surface + 0.01, UV.y);
	float drain_top = 1.0 - (fill - drain) + wave;
	float draining = liquid * (1.0 - smoothstep(drain_top - 0.01, drain_top + 0.01, UV.y)) * step(0.001, drain);

	vec3 color = glass_color.rgb;
	vec3 body = liquid_color.rgb * mix(1.1, 0.65, UV.y);
	color = mix(color, body, liquid);

	// Rising bubbles inside the liquid.
	vec2 grid = vec2(UV.x * 7.0, UV.y * 7.0 + TIME * 0.9);
	vec2 cell = floor(grid);
	float seed = hash(cell);
	vec2 local = fract(grid) - vec2(0.5 + (seed - 0.5) * 0.5, 0.5);
	float bubble = (1.0 - smoothstep(0.05, 0.1, length(local))) * step(0.72, seed) * liquid;
	color += bubble * 0.25;

	// Pulsing slice that firing would spend.
	color = mix(color, drain_color.rgb, draining * (0.45 + 0.35 * sin(TIME * 10.0)));

	// Bright meniscus right under the surface.
	color += liquid * (1.0 - smoothstep(0.0, 0.04, UV.y - surface)) * 0.3;

	// Faint marks at every whole charge.
	float level = (1.0 - UV.y) * float(max(segments, 1));
	float tick = 1.0 - smoothstep(0.0, 0.03 * float(max(segments, 1)), abs(level - round(level)));
	color = mix(color, color * 0.6, tick * 0.6);

	// Glass highlight.
	color += (1.0 - smoothstep(0.0, 0.35, length(centered - vec2(-0.4, -0.45)))) * 0.25;

	vec4 result = vec4(color, mix(glass_color.a, 1.0, liquid));
	result = mix(rim_color, result, inner);
	result.a *= outer;
	COLOR = result;
}
