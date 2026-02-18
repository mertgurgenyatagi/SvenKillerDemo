shader_type canvas_item;

uniform float blur_amount: hint_range(0.0, 10.0) = 1.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV);

	// Gaussian blur using 9 samples
	vec2 pixel_size = blur_amount / vec2(textureSize(TEXTURE, 0));

	// Gaussian kernel weights (3x3)
	mat3 kernel = mat3(
		1.0, 2.0, 1.0,
		2.0, 4.0, 2.0,
		1.0, 2.0, 1.0
	) / 16.0;

	vec4 result = vec4(0.0);
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 offset = vec2(float(x), float(y)) * pixel_size;
			result += texture(TEXTURE, UV + offset) * kernel[x + 1][y + 1];
		}
	}

	// Blend between original and blurred based on blur_amount
	COLOR = mix(color, result, min(blur_amount / 10.0, 1.0));
}
