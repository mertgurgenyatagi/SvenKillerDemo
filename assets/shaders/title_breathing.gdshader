shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.86, 0.86, 0.86, 1.0);
uniform float noise_strength : hint_range(0.0, 0.2) = 0.06;
uniform float breath_intensity : hint_range(0.0, 0.05) = 0.01;

// Simple hash-based noise
float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;

	// Very subtle breathing effect - almost imperceptible
	float breath = sin(TIME * 0.3) * breath_intensity;

	// Vertical gradient
	float gradient_t = uv.y;
	vec4 base = mix(top_color, bottom_color, gradient_t);

	// Procedural noise texture
	float noise_val = rand(uv * 200.0);
	base.rgb *= mix(1.0, 0.96, noise_val * noise_strength);

	// Apply breathing to brightness
	base.rgb *= (1.0 + breath);

	COLOR = texture(TEXTURE, uv) * base;
}
