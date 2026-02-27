shader_type canvas_item;

// Applied to a SubViewportContainer — TEXTURE is the SubViewport's rendered output,
// UV is 0..1 within the container rect. No screen sampling needed.

uniform vec2 blur_direction = vec2(0.01, 0.04);
uniform float intensity : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 offset = blur_direction * intensity;

	vec4 acc    = vec4(0.0, 0.0, 0.0, 0.0);
	float total = 0.0;

	for (int i = 0; i < 12; i++) {
		float t = float(i) / 11.0 - 0.5;
		float w = clamp(1.0 - abs(t) * 1.8, 0.05, 1.0);
		vec2 uv = clamp(UV + offset * t, vec2(0.0, 0.0), vec2(1.0, 1.0));
		acc   += texture(TEXTURE, uv) * w;
		total += w;
	}

	COLOR = acc / total;
}
