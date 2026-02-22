shader_type canvas_item;

// Subtle motion blur for frame blending at reduced framerates
uniform float blur_strength: hint_range(0.0, 1.0) = 0.12;

void fragment() {
	vec4 color = texture(TEXTURE, UV);

	// Convert to grayscale (luminance weights)
	float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));

	// Apply sepia tone on top of B&W
	vec3 sepia = vec3(
		gray * 1.2,
		gray * 1.0,
		gray * 0.8
	);

	vec4 final_color = vec4(clamp(sepia, 0.0, 1.0), color.a);

	// Subtle motion blur for smoother frame transitions
	vec4 blur1 = texture(TEXTURE, UV + vec2(0.001, 0.0));
	vec4 blur2 = texture(TEXTURE, UV - vec2(0.001, 0.0));
	vec4 blur3 = texture(TEXTURE, UV + vec2(0.0, 0.001));
	vec4 blur4 = texture(TEXTURE, UV - vec2(0.0, 0.001));

	// Apply B&W+sepia to blur samples
	for (int i = 0; i < 4; i++) {
		vec4 blur_sample = blur1;
		if (i == 1) blur_sample = blur2;
		if (i == 2) blur_sample = blur3;
		if (i == 3) blur_sample = blur4;

		float blur_gray = dot(blur_sample.rgb, vec3(0.299, 0.587, 0.114));
		vec3 blur_sepia = vec3(
			blur_gray * 1.2,
			blur_gray * 1.0,
			blur_gray * 0.8
		);
		blur_sample = vec4(clamp(blur_sepia, 0.0, 1.0), blur_sample.a);
	}

	vec4 blurred = (final_color + blur1 + blur2 + blur3 + blur4) / 5.0;

	// Mix original with blurred based on strength
	COLOR = mix(final_color, blurred, blur_strength);
}
