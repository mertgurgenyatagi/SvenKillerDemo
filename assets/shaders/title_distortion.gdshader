shader_type canvas_item;

uniform float distortion_intensity : hint_range(0.0, 0.05) = 0.015;
uniform float line_angle : hint_range(0.0, 90.0) = 10.0;
uniform float line_width : hint_range(0.01, 0.3) = 0.08;
uniform float animation_speed : hint_range(0.0, 2.0) = 0.3;

void fragment() {
	vec2 uv = UV;

	// Convert angle to radians
	float angle_rad = radians(line_angle);

	// Calculate distance from diagonal line
	// Line equation: rotating coordinate system
	float cos_a = cos(angle_rad);
	float sin_a = sin(angle_rad);

	// Rotate UV coordinates
	vec2 rotated = vec2(
		uv.x * cos_a - (uv.y - 0.5) * sin_a,
		uv.x * sin_a + (uv.y - 0.5) * cos_a
	);

	// Animated position for traveling distortion
	float travel_offset = fract(TIME * animation_speed);

	// Distance from the traveling diagonal line
	float dist_from_line = abs(rotated.y - travel_offset + 0.5);

	// Create distortion band with smooth falloff
	float distortion_mask = smoothstep(line_width, 0.0, dist_from_line);

	// Apply displacement perpendicular to the line
	vec2 distorted_uv = uv;
	distorted_uv.x += sin(uv.y * 20.0 + TIME) * distortion_intensity * distortion_mask;
	distorted_uv.y += cos(uv.x * 20.0 + TIME) * distortion_intensity * distortion_mask * 0.5;

	// Clamp to prevent edge artifacts
	distorted_uv = clamp(distorted_uv, vec2(0.0), vec2(1.0));

	// Sample texture with distortion
	vec4 color = texture(TEXTURE, distorted_uv);

	// Subtle chromatic aberration along the line
	if (distortion_mask > 0.1) {
		float r = texture(TEXTURE, distorted_uv + vec2(0.002, 0.0) * distortion_mask).r;
		float b = texture(TEXTURE, distorted_uv - vec2(0.002, 0.0) * distortion_mask).b;
		color.r = r;
		color.b = b;
	}

	COLOR = color;
}
