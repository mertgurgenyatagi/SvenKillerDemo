shader_type canvas_item;

uniform float distress_amount : hint_range(0.0, 1.0) = 0.15;
uniform float noise_scale : hint_range(1.0, 50.0) = 25.0;
uniform float chromatic_offset : hint_range(0.0, 0.01) = 0.001;

// Simple noise function
float noise(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;

	// Original text sample
	vec4 base_color = texture(TEXTURE, uv);

	// Edge detection (for distress application)
	float edge = base_color.a * (1.0 - base_color.a * 0.5);

	// Noise-based erosion at edges
	float noise_val = noise(uv * noise_scale);
	float erosion = step(noise_val, distress_amount * edge);

	// Chromatic aberration (very subtle red/cyan split)
	vec2 offset_r = vec2(chromatic_offset, 0.0);
	vec2 offset_b = vec2(-chromatic_offset, 0.0);

	float r = texture(TEXTURE, uv + offset_r).r;
	float g = base_color.g;
	float b = texture(TEXTURE, uv + offset_b).b;

	// Combine effects
	vec3 final_color = vec3(r, g, b) * base_color.rgb;
	float final_alpha = base_color.a * (1.0 - erosion * 0.3);

	COLOR = vec4(final_color, final_alpha);
}
