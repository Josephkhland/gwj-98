shader_type canvas_item;
render_mode unshaded;

uniform vec4 glow_color : source_color = vec4(0.45, 1.0, 0.8, 1.0);
uniform float glow_intensity : hint_range(0.0, 4.0) = 1.0;
uniform float outline_width = 10.0;
uniform float glow_radius = 60.0;
uniform float glow_density : hint_range(0.0, 1.0) = 0.25;
// Restrict sampling to the current frame, including trimmed AtlasTextures.
uniform vec4 frame_uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
varying vec4 vertex_tint;

float frame_alpha(sampler2D source, vec2 uv) {
	if (any(lessThan(uv, frame_uv_rect.xy)) || any(greaterThan(uv, frame_uv_rect.zw))) {
		return 0.0;
	}
	return texture(source, uv).a;
}

void vertex() {
	vertex_tint = COLOR;
	vec2 frame_uv = (UV - frame_uv_rect.xy) / (frame_uv_rect.zw - frame_uv_rect.xy);
	vec2 edge = frame_uv * 2.0 - 1.0;
	float margin = outline_width + glow_radius;
	VERTEX += edge * margin;
	UV += edge * margin * TEXTURE_PIXEL_SIZE;
}

void fragment() {
	vec4 tint = vertex_tint;
	float body = frame_alpha(TEXTURE, UV);
	if (body >= 0.999) {
		discard;
	}
	float coverage = 0.0;
	float falloff = mix(4.0, 0.15, glow_density);
	for (int direction = 0; direction < 32; direction++) {
		float angle = float(direction) * 6.28318530718 / 32.0;
		vec2 step_uv = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE;
		if (outline_width > 0.0) {
			coverage = max(coverage, frame_alpha(TEXTURE, UV + step_uv * outline_width));
		}
		for (int ring = 1; ring <= 8; ring++) {
			float fraction = float(ring) / 8.0;
			float weight = pow(1.0 - float(ring) / 9.0, falloff);
			float radius = outline_width + glow_radius * fraction;
			coverage = max(coverage, frame_alpha(TEXTURE, UV + step_uv * radius) * weight);
		}
	}
	// This layer draws behind the lit artwork and contributes only outside its alpha.
	float alpha = clamp(coverage * glow_intensity, 0.0, 1.0) * (1.0 - body);
	COLOR = vec4(glow_color.rgb * max(1.0, glow_intensity) * tint.rgb,
		alpha * glow_color.a * tint.a);
}
