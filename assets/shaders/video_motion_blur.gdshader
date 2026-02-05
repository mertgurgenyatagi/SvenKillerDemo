shader_type canvas_item;

// Subtle motion blur for frame blending at reduced framerates
// Creates smoother motion without excessive performance cost

uniform float blur_strength: hint_range(0.0, 1.0) = 0.15;

void fragment() {
	vec4 color = texture(TEXTURE, UV);

	// Sample neighboring pixels for motion blur effect
	vec4 blur1 = texture(TEXTURE, UV + vec2(0.001, 0.0));
	vec4 blur2 = texture(TEXTURE, UV - vec2(0.001, 0.0));
	vec4 blur3 = texture(TEXTURE, UV + vec2(0.0, 0.001));
	vec4 blur4 = texture(TEXTURE, UV - vec2(0.0, 0.001));

	// Blend with blurred samples
	vec4 blurred = (color + blur1 + blur2 + blur3 + blur4) / 5.0;

	// Mix original with blurred based on strength
	COLOR = mix(color, blurred, blur_strength);
}
