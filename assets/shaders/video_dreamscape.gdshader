shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float warp_intensity : hint_range(0.0, 0.02) = 0.003;
uniform float warp_speed : hint_range(0.1, 1.0) = 0.2;
uniform float warp_scale : hint_range(1.0, 10.0) = 3.0;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float vignette_softness : hint_range(0.1, 1.0) = 0.5;
uniform float color_shift_amount : hint_range(0.0, 0.01) = 0.0015;
uniform float desaturation : hint_range(0.0, 1.0) = 0.15;

void fragment() {
	vec2 uv = SCREEN_UV;

	// Breathing UV warp - organic, unsettling movement
	float warp_x = sin(uv.y * warp_scale + TIME * warp_speed) * warp_intensity;
	float warp_y = cos(uv.x * warp_scale * 1.3 + TIME * warp_speed * 0.8) * warp_intensity;
	vec2 warped_uv = uv + vec2(warp_x, warp_y);

	// Clamp to prevent edge artifacts
	warped_uv = clamp(warped_uv, vec2(0.001), vec2(0.999));

	// Sample the video texture with warp
	vec4 color = texture(SCREEN_TEXTURE, warped_uv);

	// Subtle color channel separation (dreamy chromatic)
	float r = texture(SCREEN_TEXTURE, warped_uv + vec2(color_shift_amount, 0.0)).r;
	float g = color.g;
	float b = texture(SCREEN_TEXTURE, warped_uv - vec2(color_shift_amount, 0.0)).b;
	color = vec4(r, g, b, color.a);

	// Slight desaturation for dreamy feel
	float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	color.rgb = mix(color.rgb, vec3(luminance), desaturation);

	// Vignette (dark edges)
	vec2 center_dist = uv - vec2(0.5);
	float vignette = 1.0 - smoothstep(vignette_softness, vignette_softness + 0.5, length(center_dist) * 1.5);
	vignette = mix(1.0, vignette, vignette_intensity);
	color.rgb *= vignette;

	COLOR = color;
}
